package ProFTPD::Tests::Config::FTPAccess::RETR;

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
  ftpaccess_retr_bug2038 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  ftpaccess_anon_retr_bug2038 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  ftpaccess_anon_retr_bug2461 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub ftpaccess_retr_bug2038 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ftpaccess.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ftpaccess.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ftpaccess.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/ftpaccess.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/ftpaccess.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $sub_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($sub_dir);

  my $fh;

  # Write a .ftpaccess file in the sub dir which denies all access 
  my $ftpaccess_file = File::Spec->rel2abs("$tmpdir/foo/.ftpaccess");
  if (open($fh, "> $ftpaccess_file")) {
    print $fh <<EOF;
<Limit RETR>
  DenyAll
</Limit>
EOF

    unless (close($fh)) {
      die("Can't write $ftpaccess_file: $!");
    }

  } else {
    die("Can't open $ftpaccess_file: $!");
  }

  # Next, write a test file in the sub dir.
  my $test_file = File::Spec->rel2abs("$tmpdir/foo/test.txt");
  if (open($fh, "> $test_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir, $sub_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
      die("Can't set owner of $home_dir, $sub_dir to $uid/$gid: $!");
    }
  }
 
  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

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

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

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
      $client->login($user, $passwd);
      $client->cwd($sub_dir);

      my ($resp_code, $resp_msg);

      my $conn = $client->retr_raw("test.txt");
      if ($conn) {
        die("RETR test.txt succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "test.txt: Operation not permitted";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      # Now download the file again, only this time using the full path
      $conn = $client->retr_raw($test_file);
      if ($conn) {
        die("RETR $test_file succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "$test_file: Operation not permitted";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      # Now prove that the failures are caused by the .ftpaccess file
      # by deleting that file.
      unlink($ftpaccess_file);

      $conn = $client->retr_raw("test.txt");
      unless ($conn) {
        die("Failed to RETR test.txt: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Transfer complete";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR $test_file: " . $client->response_code() . " " .
          $client->response_msg());
      }

      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Transfer complete";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));
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

sub ftpaccess_anon_retr_bug2038 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ftpaccess.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ftpaccess.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ftpaccess.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/ftpaccess.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/ftpaccess.group");

  my ($config_user, $config_group) = config_get_identity();

  my $anon_dir = File::Spec->rel2abs($tmpdir);

  my $sub_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($sub_dir);

  my $fh;

  # Write a .ftpaccess file in the sub dir which denies all access 
  my $ftpaccess_file = File::Spec->rel2abs("$tmpdir/foo/.ftpaccess");
  if (open($fh, "> $ftpaccess_file")) {
    print $fh <<EOF;
<Limit RETR>
  DenyAll
</Limit>
EOF

    unless (close($fh)) {
      die("Can't write $ftpaccess_file: $!");
    }

  } else {
    die("Can't open $ftpaccess_file: $!");
  }

  # Next, write a test file in the sub dir.
  my $test_file = File::Spec->rel2abs("$tmpdir/foo/test.txt");
  if (open($fh, "> $test_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  # Make a version of the path that the client would see.
  my $anon_test_file = "/foo/test.txt";

  auth_user_write($auth_user_file, $config_user, 'foo', 500, 500, '/tmp',
    '/bin/bash');
  auth_group_write($auth_group_file, $config_group, 500, $config_user);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    AllowOverride => 'on',

    Anonymous => {
      $anon_dir => {
        User => $config_user,
        Group => $config_group,
        UserAlias => "anonymous $config_user",
        RequireValidShell => 'off',
      },
    },

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my $port;
  ($port, $config_user, $config_group) = config_write($config_file, $config);

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
      $client->cwd("foo");

      my ($resp_code, $resp_msg);

      my $conn = $client->retr_raw("test.txt");
      if ($conn) {
        die("RETR test.txt succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "test.txt: Operation not permitted";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      # Now download the file again, only this time using a full path
      $conn = $client->retr_raw($anon_test_file);
      if ($conn) {
        die("RETR $anon_test_file succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "$anon_test_file: Operation not permitted";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      # Now prove that the failures are caused by the .ftpaccess file
      # by deleting that file.
      unlink($ftpaccess_file);

      $conn = $client->retr_raw("test.txt");
      unless ($conn) {
        die("Failed to RETR test.txt: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Transfer complete";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $conn = $client->retr_raw($anon_test_file);
      unless ($conn) {
        die("Failed to RETR $anon_test_file: " . $client->response_code() .
          " " .  $client->response_msg());
      }

      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Transfer complete";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));
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

sub ftpaccess_anon_retr_bug2461 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ftpaccess.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ftpaccess.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ftpaccess.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/ftpaccess.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/ftpaccess.group");

  my ($config_user, $config_group) = config_get_identity();

  my $anon_dir = File::Spec->rel2abs($tmpdir);

  my $fh;

  # Write a .ftpaccess file in the sub dir which denies all access 
  my $ftpaccess_file = File::Spec->rel2abs("$tmpdir/.ftpaccess");
  if (open($fh, "> $ftpaccess_file")) {
    print $fh <<EOF;
<Limit READ>
  Allow from 127.0.0.2
  DenyAll
</Limit>
EOF

    unless (close($fh)) {
      die("Can't write $ftpaccess_file: $!");
    }

  } else {
    die("Can't open $ftpaccess_file: $!");
  }

  # Next, write a test file in the anon dir.
  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open($fh, "> $test_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  # Make a version of the path that the client would see.
  my $anon_test_file = "/test.txt";

  auth_user_write($auth_user_file, $config_user, 'foo', 500, 500, '/tmp',
    '/bin/bash');
  auth_group_write($auth_group_file, $config_group, 500, $config_user);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    AllowOverride => 'on',

    Anonymous => {
      $anon_dir => {
        User => $config_user,
        Group => $config_group,
        UserAlias => "anonymous $config_user",
        RequireValidShell => 'off',
      },
    },

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my $port;
  ($port, $config_user, $config_group) = config_write($config_file, $config);

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

      my ($resp_code, $resp_msg);

      my $conn = $client->retr_raw("test.txt");
      if ($conn) {
        die("RETR test.txt succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "test.txt: Operation not permitted";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      # Now do a directory listing...
      $client->list();

      # ...then try the download again
      $conn = $client->retr_raw("test.txt");
      if ($conn) {
        die("RETR test.txt succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "test.txt: Operation not permitted";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      # Now prove that the failures are caused by the .ftpaccess file
      # by deleting that file.
      unlink($ftpaccess_file);

      $conn = $client->retr_raw("test.txt");
      unless ($conn) {
        die("Failed to RETR test.txt: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Transfer complete";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));
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
