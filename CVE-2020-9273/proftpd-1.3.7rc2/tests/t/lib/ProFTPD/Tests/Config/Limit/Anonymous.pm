package ProFTPD::Tests::Config::Limit::Anonymous;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use File::Path qw(mkpath);
use File::Spec;
use IO::Handle;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  anon_limit_write => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  anon_limit_write_changing_dirs => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  anon_limit_write_with_ftpaccess => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  anon_limit_login_dns_name => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  anon_limit_write_allow_stor_using_abs_path => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  anon_limit_write_allow_stor_using_rel_path => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub anon_limit_write {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/limit.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/limit.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/limit.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/limit.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/limit.group");

  my ($config_user, $config_group) = config_get_identity();

  my $anon_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $anon_dir)) {
      die("Can't set perms on $anon_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $anon_dir)) {
      die("Can't set owner of $anon_dir to $uid/$gid: $!");
    }
  }
 
  auth_user_write($auth_user_file, $config_user, 'test', $uid, $gid, '/tmp',
    '/bin/bash');
  auth_group_write($auth_group_file, $config_group, $gid, $config_user);

  # Test the config mentioned here:
  #
  #  http://forums.proftpd.org/smf/index.php/topic,4076.0.html
  #
  # Specifically this portion:
  #
  #  <Anonymous>
  #    <Directory *>
  #      <Limit WRITE>
  #        DenyAll
  #      </Limit>
  #    </Directory>
  #  </Anonymous>
  #
  # Does the use of '*' there allow creation of directories there?

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $user, $group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Anonymous $anon_dir>
  User $config_user
  Group $config_group
  UserAlias anonymous $config_user
  RequireValidShell off

  <Directory *>
    <Limit WRITE>
      DenyAll
    </Limit>
  </Directory>
</Anonymous>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  # Open pipes, for use between the parent and child processes.  Specifically,
  # the child will indicate when it's done with its test by writing a message
  # to the parent.
  my ($rfh, $wfh);
  unless (pipe($rfh, $wfh)) {
    die("Can't open pipe: $!");
  }

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login('anonymous', 'ftp@nospam.org');

      eval { $client->mkd('testdir') };
      unless ($@) {
        die("MKD testdir succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "testdir: Permission denied";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  # Stop server
  server_stop($pid_file);

  $self->assert_child_ok($pid);

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub anon_limit_write_changing_dirs {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/limit.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/limit.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/limit.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/limit.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/limit.group");

  my ($config_user, $config_group) = config_get_identity();

  my $anon_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $sub_dir = File::Spec->rel2abs("$tmpdir/subdir");
  mkpath($sub_dir);

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $anon_dir, $sub_dir)) {
      die("Can't set perms on $anon_dir, $sub_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $anon_dir, $sub_dir)) {
      die("Can't set owner of $anon_dir, $sub_dir to $uid/$gid: $!");
    }
  }
 
  auth_user_write($auth_user_file, $config_user, 'test', $uid, $gid, '/tmp',
    '/bin/bash');
  auth_group_write($auth_group_file, $config_group, $gid, $config_user);

  # Test the config mentioned here:
  #
  #  http://forums.proftpd.org/smf/index.php/topic,4076.0.html
  #
  # Specifically this portion:
  #
  #  <Anonymous>
  #    <Directory *>
  #      <Limit WRITE>
  #        DenyAll
  #      </Limit>
  #    </Directory>
  #  </Anonymous>
  #
  # Does the use of '*' there allow creation of directories there?

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $user, $group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Anonymous $anon_dir>
  User $config_user
  Group $config_group
  UserAlias anonymous $config_user
  RequireValidShell off

  <Directory *>
    <Limit WRITE>
      DenyAll
    </Limit>
  </Directory>
</Anonymous>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  # Open pipes, for use between the parent and child processes.  Specifically,
  # the child will indicate when it's done with its test by writing a message
  # to the parent.
  my ($rfh, $wfh);
  unless (pipe($rfh, $wfh)) {
    die("Can't open pipe: $!");
  }

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login('anonymous', 'ftp@nospam.org');
      $client->cwd('subdir');

      eval { $client->mkd('testdir') };
      unless ($@) {
        die("MKD testdir succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "testdir: Permission denied";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      # Now try to create a directory one level up from where we are
      eval { $client->mkd('../testdir') };
      unless ($@) {
        die("MKD ../testdir succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "../testdir: Permission denied";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  # Stop server
  server_stop($pid_file);

  $self->assert_child_ok($pid);

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub anon_limit_write_with_ftpaccess {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/limit.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/limit.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/limit.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/limit.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/limit.group");

  my ($config_user, $config_group) = config_get_identity();

  my $anon_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $sub_dir = File::Spec->rel2abs("$tmpdir/subdir");
  mkpath($sub_dir);

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $anon_dir, $sub_dir)) {
      die("Can't set perms on $anon_dir, $sub_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $anon_dir, $sub_dir)) {
      die("Can't set owner of $anon_dir, $sub_dir to $uid/$gid: $!");
    }
  }

  # Create a .ftpaccess file in the sub-directory.
  if (open(my $fh, "> $anon_dir/.ftpaccess")) {
    print $fh <<EOC;
DirFakeUser on foo
EOC
    unless (close($fh)) {
      die("Can't write $anon_dir/.ftpaccess: $!");
    }

  } else {
    die("Can't open $anon_dir/.ftpaccess: $!");
  }
 
  auth_user_write($auth_user_file, $config_user, 'test', $uid, $gid, '/tmp',
    '/bin/bash');
  auth_group_write($auth_group_file, $config_group, $gid, $config_user);

  # Test the config mentioned here:
  #
  #  http://forums.proftpd.org/smf/index.php/topic,4076.0.html
  #
  # Specifically this portion:
  #
  #  <Anonymous>
  #    <Directory *>
  #      <Limit WRITE>
  #        DenyAll
  #      </Limit>
  #    </Directory>
  #  </Anonymous>
  #
  # Does the use of '*' there allow creation of directories there?

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    AllowOverride => 'on',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $user, $group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Anonymous $anon_dir>
  User $config_user
  Group $config_group
  UserAlias anonymous $config_user
  RequireValidShell off

  <Directory *>
    <Limit WRITE>
      DenyAll
    </Limit>
  </Directory>
</Anonymous>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  # Open pipes, for use between the parent and child processes.  Specifically,
  # the child will indicate when it's done with its test by writing a message
  # to the parent.
  my ($rfh, $wfh);
  unless (pipe($rfh, $wfh)) {
    die("Can't open pipe: $!");
  }

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login('anonymous', 'ftp@nospam.org');
      $client->cwd('subdir');

      eval { $client->mkd('testdir') };
      unless ($@) {
        die("MKD testdir succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "testdir: Permission denied";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      # Now try to create a directory one level up from where we are
      eval { $client->mkd('../testdir') };
      unless ($@) {
        die("MKD ../testdir succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "../testdir: Permission denied";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      $client->cwd('/');

      eval { $client->mkd('testdir') };
      unless ($@) {
        die("MKD testdir succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "testdir: Permission denied";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  # Stop server
  server_stop($pid_file);

  $self->assert_child_ok($pid);

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub anon_limit_login_dns_name {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/limit.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/limit.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/limit.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/limit.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/limit.group");

  my ($config_user, $config_group) = config_get_identity();

  my $anon_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $anon_dir)) {
      die("Can't set perms on $anon_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $anon_dir)) {
      die("Can't set owner of $anon_dir to $uid/$gid: $!");
    }
  }
 
  auth_user_write($auth_user_file, $config_user, 'test', $uid, $gid, '/tmp',
    '/bin/bash');
  auth_group_write($auth_group_file, $config_group, $gid, $config_user);

  # Test the config mentioned here:
  #
  #  http://forums.proftpd.org/smf/index.php/topic,4436.0.html
  #
  # Specifically this portion:
  #
  #  <Anonymous>
  #    <Limit LOGIN>
  #      Allow from <dns-name>
  #      DenyAll
  #    </Limit>
  #  </Anonymous>

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 netacl:10 netaddr:10 dns:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    UseReverseDNS => 'on',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $user, $group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Anonymous $anon_dir>
  User $config_user
  Group $config_group
  UserAlias anonymous $config_user
  RequireValidShell off

  <Limit LOGIN>
    Allow from localhost
    DenyAll
  </Limit>
</Anonymous>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  # Open pipes, for use between the parent and child processes.  Specifically,
  # the child will indicate when it's done with its test by writing a message
  # to the parent.
  my ($rfh, $wfh);
  unless (pipe($rfh, $wfh)) {
    die("Can't open pipe: $!");
  }

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login('anonymous', 'ftp@nospam.org');
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  # Stop server
  server_stop($pid_file);

  $self->assert_child_ok($pid);

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub anon_limit_write_allow_stor_using_abs_path {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/limit.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/limit.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/limit.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/limit.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/limit.group");

  my ($config_user, $config_group) = config_get_identity();

  my $anon_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $uploads_dir = File::Spec->rel2abs("$anon_dir/uploads");
  mkpath($uploads_dir);

  my $test_file = File::Spec->rel2abs("$uploads_dir/test.txt");

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $anon_dir, $uploads_dir)) {
      die("Can't set perms on $anon_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $anon_dir, $uploads_dir)) {
      die("Can't set owner of $anon_dir to $uid/$gid: $!");
    }
  }
 
  auth_user_write($auth_user_file, $config_user, 'test', $uid, $gid, '/tmp',
    '/bin/bash');
  auth_group_write($auth_group_file, $config_group, $gid, $config_user);

  # Test this config:
  #
  #  <Anonymous>
  #    <Limit WRITE SITE_CHMOD>
  #      DenyAll
  #    </Limit>
  #
  #    <Directory uploads/*>
  #      <Limit STOR>
  #        AllowAll
  #      </Limit>
  #    </Directory>
  #  </Anonymous>

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $user, $group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Anonymous $anon_dir>
  User $config_user
  Group $config_group
  UserAlias anonymous $config_user
  RequireValidShell off

  <Limit WRITE SITE_CHMOD>
    DenyAll
  </Limit>

  <Directory uploads/*>
    <Limit STOR>
      AllowAll
    </Limit>
  </Directory>
</Anonymous>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  # Open pipes, for use between the parent and child processes.  Specifically,
  # the child will indicate when it's done with its test by writing a message
  # to the parent.
  my ($rfh, $wfh);
  unless (pipe($rfh, $wfh)) {
    die("Can't open pipe: $!");
  }

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login('anonymous', 'ftp@nospam.org');

      my $conn = $client->stor_raw('uploads/test.txt');
      unless ($conn) {
        die("STOR uploads/test.txt failed:" . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Hello, World!\n";
      $conn->write($buf, length($buf), 15);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();

      $self->assert(-f $test_file,
        test_msg("File $test_file does not exist as expected"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  # Stop server
  server_stop($pid_file);

  $self->assert_child_ok($pid);

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub anon_limit_write_allow_stor_using_rel_path {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/limit.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/limit.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/limit.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/limit.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/limit.group");

  my ($config_user, $config_group) = config_get_identity();

  my $anon_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $uploads_dir = File::Spec->rel2abs("$anon_dir/uploads");
  mkpath($uploads_dir);

  my $test_file = File::Spec->rel2abs("$uploads_dir/test.txt");

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $anon_dir, $uploads_dir)) {
      die("Can't set perms on $anon_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $anon_dir, $uploads_dir)) {
      die("Can't set owner of $anon_dir to $uid/$gid: $!");
    }
  }
 
  auth_user_write($auth_user_file, $config_user, 'test', $uid, $gid, '/tmp',
    '/bin/bash');
  auth_group_write($auth_group_file, $config_group, $gid, $config_user);

  # Test this config:
  #
  #  <Anonymous>
  #    <Limit WRITE SITE_CHMOD>
  #      DenyAll
  #    </Limit>
  #
  #    <Directory uploads/*>
  #      <Limit STOR>
  #        AllowAll
  #      </Limit>
  #    </Directory>
  #  </Anonymous>

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $user, $group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Anonymous $anon_dir>
  User $config_user
  Group $config_group
  UserAlias anonymous $config_user
  RequireValidShell off

  <Limit WRITE SITE_CHMOD>
    DenyAll
  </Limit>

  <Directory uploads/*>
    <Limit STOR>
      AllowAll
    </Limit>
  </Directory>
</Anonymous>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  # Open pipes, for use between the parent and child processes.  Specifically,
  # the child will indicate when it's done with its test by writing a message
  # to the parent.
  my ($rfh, $wfh);
  unless (pipe($rfh, $wfh)) {
    die("Can't open pipe: $!");
  }

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login('anonymous', 'ftp@nospam.org');
      $client->cwd('uploads');

      my $conn = $client->stor_raw('test.txt');
      unless ($conn) {
        die("STOR test.txt failed:" . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Hello, World!\n";
      $conn->write($buf, length($buf), 15);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();

      $self->assert(-f $test_file,
        test_msg("File $test_file does not exist as expected"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  # Stop server
  server_stop($pid_file);

  $self->assert_child_ok($pid);

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

1;
