package ProFTPD::Tests::Config::UseSendfile;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use File::Copy;
use File::Path qw(mkpath);
use File::Spec;
use IO::Handle;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  usesendfile_on_ascii => {
    order => ++$order,
    test_class => [qw(feat_sendfile forking)],
  },

  usesendfile_off_ascii => {
    order => ++$order,
    test_class => [qw(feat_sendfile forking)],
  },

  usesendfile_on_binary => {
    order => ++$order,
    test_class => [qw(feat_sendfile forking)],
  },

  usesendfile_off_binary => {
    order => ++$order,
    test_class => [qw(feat_sendfile forking)],
  },

  usesendfile_on_binary_dir_bug3310 => {
    order => ++$order,
    test_class => [qw(bug feat_sendfile forking)],
  },

  usesendfile_off_binary_dir_bug3310 => {
    order => ++$order,
    test_class => [qw(bug feat_sendfile forking)],
  },

  usesendfile_on_binary_ftpaccess_bug3310 => {
    order => ++$order,
    test_class => [qw(bug feat_sendfile forking)],
  },

  usesendfile_off_binary_ftpaccess_bug3310 => {
    order => ++$order,
    test_class => [qw(bug feat_sendfile forking)],
  },

  usesendfile_len_binary_dir_bug3310 => {
    order => ++$order,
    test_class => [qw(bug feat_sendfile forking)],
  },

  usesendfile_len_binary_ftpaccess_bug3310 => {
    order => ++$order,
    test_class => [qw(bug feat_sendfile forking)],
  },

  usesendfile_len_ascii_ftpaccess_bug3310 => {
    order => ++$order,
    test_class => [qw(bug feat_sendfile forking)],
  },

  usesendfile_pct_binary_dir_bug3310 => {
    order => ++$order,
    test_class => [qw(bug feat_sendfile forking)],
  },

  usesendfile_pct_binary_ftpaccess_bug3310 => {
    order => ++$order,
    test_class => [qw(bug feat_sendfile forking)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub usesendfile_on_ascii {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");
  
  my $user = 'proftpd';
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash'); 
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $test_file = File::Spec->rel2abs($config_file);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    # We explicitly use DebugLevel 10 here, to get the sendfile log
    # message emitted by mod_xfer.
    DebugLevel => 10,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    UseSendfile => 'on',

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

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("RETR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      while ($conn->read($buf, 8192, 30)) {
      }
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();
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

  if (open(my $fh, "< $log_file")) {
    my $ok = 0;

    my $expected = 'declining use of sendfile for ASCII data';

    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /$expected/) {
        $ok = 1;
        last;
      }
    }

    close($fh);

    $self->assert($ok,
      test_msg("Expected log message '$expected' did not appear in SystemLog"));

  } else {
    die("Can't read $log_file: $!");
  }

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub usesendfile_off_ascii {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");
  
  my $user = 'proftpd';
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash'); 
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $test_file = File::Spec->rel2abs($config_file);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    # We explicitly use DebugLevel 10 here, to get the sendfile log
    # message emitted by mod_xfer.
    DebugLevel => 10,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    UseSendfile => 'off',

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

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("RETR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      while ($conn->read($buf, 8192, 30)) {
      }
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();
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

  if (open(my $fh, "< $log_file")) {
    my $ok = 0;

    my $expected = 'declining use of sendfile due to UseSendfile configuration';

    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /$expected/) {
        $ok = 1;
        last;
      }
    }

    close($fh);

    $self->assert($ok,
      test_msg("Expected log message '$expected' did not appear in SystemLog"));

  } else {
    die("Can't read $log_file: $!");
  }

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub usesendfile_on_binary {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");
  
  my $user = 'proftpd';
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash'); 
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $test_file = File::Spec->rel2abs($config_file);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    # We explicitly use DebugLevel 10 here, to get the sendfile log
    # message emitted by mod_xfer.
    DebugLevel => 10,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    UseSendfile => 'on',

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
      $client->type('binary');

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("RETR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      while ($conn->read($buf, 8192, 30)) {
      }
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();
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

  if (open(my $fh, "< $log_file")) {
    my $ok = 0;

    my $expected = 'using sendfile capability for transmitting data';

    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /$expected/) {
        $ok = 1;
        last;
      }
    }

    close($fh);

    $self->assert($ok,
      test_msg("Expected log message '$expected' did not appear in SystemLog"));

  } else {
    die("Can't read $log_file: $!");
  }

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub usesendfile_off_binary {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");
  
  my $user = 'proftpd';
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash'); 
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $test_file = File::Spec->rel2abs($config_file);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    # We explicitly use DebugLevel 10 here, to get the sendfile log
    # message emitted by mod_xfer.
    DebugLevel => 10,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    UseSendfile => 'off',

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
      $client->type('binary');

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("RETR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      while ($conn->read($buf, 8192, 30)) {
      }
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();
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

  if (open(my $fh, "< $log_file")) {
    my $ok = 0;

    my $expected = 'declining use of sendfile due to UseSendfile configuration';

    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /$expected/) {
        $ok = 1;
        last;
      }
    }

    close($fh);

    $self->assert($ok,
      test_msg("Expected log message '$expected' did not appear in SystemLog"));

  } else {
    die("Can't read $log_file: $!");
  }

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub usesendfile_on_binary_dir_bug3310 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");
  
  my $user = 'proftpd';
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash'); 
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $sub_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($sub_dir);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    # We explicitly use DebugLevel 10 here, to get the sendfile log
    # message emitted by mod_xfer.
    DebugLevel => 10,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Directory ~>
  UseSendfile off
</Directory>

<Directory ~/foo>
  UseSendfile on
</Directory>
EOC

    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  my $path_without_sendfile = File::Spec->rel2abs($config_file);

  # We copy the config file here, *after* it has been written out.
  my $path_with_sendfile = File::Spec->rel2abs("$sub_dir/test.dat");
  unless (copy($config_file, $path_with_sendfile)) {
    die("Can't copy '$config_file' to '$path_with_sendfile': $!");
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
      $client->login($user, $passwd);
      $client->type('binary');

      my ($buf, $conn, $expected, $resp_code, $resp_msg);

      $conn = $client->retr_raw($path_without_sendfile);
      unless ($conn) {
        die("RETR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      while ($conn->read($buf, 8192, 30)) {
      }
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $conn = $client->retr_raw($path_with_sendfile);
      unless ($conn) {
        die("RETR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      while ($conn->read($buf, 8192, 30)) {
      }
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();
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

  if (open(my $fh, "< $log_file")) {
    my $with_sendfile_ok = 0;
    my $without_sendfile_ok = 0;

    my $expected_with_sendfile = 'using sendfile capability for transmitting data';
    my $expected_without_sendfile = 'declining use of sendfile due to UseSendfile configuration';

    while (my $line = <$fh>) {
      chomp($line);

      # Look for the "without sendfile" log message first; only if that
      # is found will we look for the "with sendfile" log message.
      if ($with_sendfile_ok == 0 &&
          $line =~ /$expected_without_sendfile/) {
        $without_sendfile_ok = 1;
      }

      if ($without_sendfile_ok == 1 &&
          $line =~ /$expected_with_sendfile/) {
        $with_sendfile_ok = 1;
        last;
      }
    }

    close($fh);

    $self->assert($without_sendfile_ok,
      test_msg("Expected log message '$expected_without_sendfile' did not appear in SystemLog"));

    $self->assert($with_sendfile_ok,
      test_msg("Expected log message '$expected_with_sendfile' did not appear in SystemLog"));

  } else {
    die("Can't read $log_file: $!");
  }

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub usesendfile_off_binary_dir_bug3310 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");
  
  my $user = 'proftpd';
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash'); 
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $sub_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($sub_dir);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    # We explicitly use DebugLevel 10 here, to get the sendfile log
    # message emitted by mod_xfer.
    DebugLevel => 10,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Directory ~>
  UseSendfile on
</Directory>

<Directory ~/foo>
  UseSendfile off
</Directory>
EOC

    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  my $path_with_sendfile = File::Spec->rel2abs($config_file);

  # We copy the config file here, *after* it has been written out.
  my $path_without_sendfile = File::Spec->rel2abs("$sub_dir/test.dat");
  unless (copy($config_file, $path_without_sendfile)) {
    die("Can't copy '$config_file' to '$path_without_sendfile': $!");
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
      $client->login($user, $passwd);
      $client->type('binary');

      my ($buf, $conn, $expected, $resp_code, $resp_msg);

      $conn = $client->retr_raw($path_with_sendfile);
      unless ($conn) {
        die("RETR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      while ($conn->read($buf, 8192, 30)) {
      }
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $conn = $client->retr_raw($path_without_sendfile);
      unless ($conn) {
        die("RETR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      while ($conn->read($buf, 8192, 30)) {
      }
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();
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

  if (open(my $fh, "< $log_file")) {
    my $with_sendfile_ok = 0;
    my $without_sendfile_ok = 0;

    my $expected_with_sendfile = 'using sendfile capability for transmitting data';
    my $expected_without_sendfile = 'declining use of sendfile due to UseSendfile configuration';

    while (my $line = <$fh>) {
      chomp($line);

      # Look for the "with sendfile" log message first; only if that
      # is found will we look for the "without sendfile" log message.
      if ($without_sendfile_ok == 0 &&
          $line =~ /$expected_with_sendfile/) {
        $with_sendfile_ok = 1;
      }

      if ($with_sendfile_ok == 1 &&
          $line =~ /$expected_without_sendfile/) {
        $without_sendfile_ok = 1;
        last;
      }
    }

    close($fh);

    $self->assert($with_sendfile_ok,
      test_msg("Expected log message '$expected_with_sendfile' did not appear in SystemLog"));

    $self->assert($without_sendfile_ok,
      test_msg("Expected log message '$expected_without_sendfile' did not appear in SystemLog"));

  } else {
    die("Can't read $log_file: $!");
  }

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub usesendfile_on_binary_ftpaccess_bug3310 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");
  
  my $user = 'proftpd';
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash'); 
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $sub_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($sub_dir);

  my $ftpaccess_file = File::Spec->rel2abs("$sub_dir/.ftpaccess");
  if (open(my $fh, "> $ftpaccess_file")) {
    print $fh "UseSendfile on\n";

    unless (close($fh)) {
      die("Can't write $ftpaccess_file: $!");
    }

  } else {
    die("Can't open $ftpaccess_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    # We explicitly use DebugLevel 10 here, to get the sendfile log
    # message emitted by mod_xfer.
    DebugLevel => 10,

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

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Directory ~>
  UseSendfile off
</Directory>
EOC

    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  my $path_without_sendfile = File::Spec->rel2abs($config_file);

  # We copy the config file here, *after* it has been written out.
  my $path_with_sendfile = File::Spec->rel2abs("$sub_dir/test.dat");
  unless (copy($config_file, $path_with_sendfile)) {
    die("Can't copy '$config_file' to '$path_with_sendfile': $!");
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
      $client->login($user, $passwd);
      $client->type('binary');

      my ($buf, $conn, $expected, $resp_code, $resp_msg);

      $conn = $client->retr_raw($path_without_sendfile);
      unless ($conn) {
        die("RETR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      while ($conn->read($buf, 8192, 30)) {
      }
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $conn = $client->retr_raw($path_with_sendfile);
      unless ($conn) {
        die("RETR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      while ($conn->read($buf, 8192, 30)) {
      }
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();
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

  if (open(my $fh, "< $log_file")) {
    my $with_sendfile_ok = 0;
    my $without_sendfile_ok = 0;

    my $expected_with_sendfile = 'using sendfile capability for transmitting data';
    my $expected_without_sendfile = 'declining use of sendfile due to UseSendfile configuration';

    while (my $line = <$fh>) {
      chomp($line);

      # Look for the "without sendfile" log message first; only if that
      # is found will we look for the "with sendfile" log message.
      if ($with_sendfile_ok == 0 &&
          $line =~ /$expected_without_sendfile/) {
        $without_sendfile_ok = 1;
      }

      if ($without_sendfile_ok == 1 &&
          $line =~ /$expected_with_sendfile/) {
        $with_sendfile_ok = 1;
        last;
      }
    }

    close($fh);

    $self->assert($without_sendfile_ok,
      test_msg("Expected log message '$expected_without_sendfile' did not appear in SystemLog"));

    $self->assert($with_sendfile_ok,
      test_msg("Expected log message '$expected_with_sendfile' did not appear in SystemLog"));

  } else {
    die("Can't read $log_file: $!");
  }

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub usesendfile_off_binary_ftpaccess_bug3310 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");
  
  my $user = 'proftpd';
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash'); 
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $sub_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($sub_dir);

  my $ftpaccess_file = File::Spec->rel2abs("$sub_dir/.ftpaccess");
  if (open(my $fh, "> $ftpaccess_file")) {
    print $fh "UseSendfile off\n";
    unless (close($fh)) {
      die("Can't write $ftpaccess_file: $!");
    }

  } else {
    die("Can't open $ftpaccess_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    # We explicitly use DebugLevel 10 here, to get the sendfile log
    # message emitted by mod_xfer.
    DebugLevel => 10,

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

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Directory ~>
  UseSendfile on
</Directory>
EOC

    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  my $path_with_sendfile = File::Spec->rel2abs($config_file);

  # We copy the config file here, *after* it has been written out.
  my $path_without_sendfile = File::Spec->rel2abs("$sub_dir/test.dat");
  unless (copy($config_file, $path_without_sendfile)) {
    die("Can't copy '$config_file' to '$path_without_sendfile': $!");
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
      $client->login($user, $passwd);
      $client->type('binary');

      my ($buf, $conn, $expected, $resp_code, $resp_msg);

      $conn = $client->retr_raw($path_with_sendfile);
      unless ($conn) {
        die("RETR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      while ($conn->read($buf, 8192, 30)) {
      }
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $conn = $client->retr_raw($path_without_sendfile);
      unless ($conn) {
        die("RETR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      while ($conn->read($buf, 8192, 30)) {
      }
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();
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

  if (open(my $fh, "< $log_file")) {
    my $with_sendfile_ok = 0;
    my $without_sendfile_ok = 0;

    my $expected_with_sendfile = 'using sendfile capability for transmitting data';
    my $expected_without_sendfile = 'declining use of sendfile due to UseSendfile configuration';

    while (my $line = <$fh>) {
      chomp($line);

      # Look for the "with sendfile" log message first; only if that
      # is found will we look for the "without sendfile" log message.
      if ($without_sendfile_ok == 0 &&
          $line =~ /$expected_with_sendfile/) {
        $with_sendfile_ok = 1;
      }

      if ($with_sendfile_ok == 1 &&
          $line =~ /$expected_without_sendfile/) {
        $without_sendfile_ok = 1;
        last;
      }
    }

    close($fh);

    $self->assert($with_sendfile_ok,
      test_msg("Expected log message '$expected_with_sendfile' did not appear in SystemLog"));

    $self->assert($without_sendfile_ok,
      test_msg("Expected log message '$expected_without_sendfile' did not appear in SystemLog"));

  } else {
    die("Can't read $log_file: $!");
  }

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub usesendfile_len_binary_dir_bug3310 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");
  
  my $user = 'proftpd';
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash'); 
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $sub_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($sub_dir);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    # We explicitly use DebugLevel 10 here, to get the sendfile log
    # message emitted by mod_xfer.
    DebugLevel => 10,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Directory ~>
  UseSendfile off
</Directory>

<Directory ~/foo>
  UseSendfile 256 b
</Directory>
EOC

    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  my $path_without_sendfile = File::Spec->rel2abs($config_file);

  # We copy the config file here, *after* it has been written out.
  my $path_with_sendfile = File::Spec->rel2abs("$sub_dir/test.dat");
  unless (copy($config_file, $path_with_sendfile)) {
    die("Can't copy '$config_file' to '$path_with_sendfile': $!");
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
      $client->login($user, $passwd);
      $client->type('binary');

      my ($buf, $conn, $expected, $resp_code, $resp_msg);

      $conn = $client->retr_raw($path_without_sendfile);
      unless ($conn) {
        die("RETR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      while ($conn->read($buf, 8192, 30)) {
      }
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $conn = $client->retr_raw($path_with_sendfile);
      unless ($conn) {
        die("RETR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      while ($conn->read($buf, 8192, 30)) {
      }
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();
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

  if (open(my $fh, "< $log_file")) {
    my $with_sendfile_ok = 0;
    my $with_sendfile_len_ok = 0;
    my $without_sendfile_ok = 0;

    my $expected_with_sendfile = 'using sendfile capability for transmitting data';
    my $expected_with_sendfile_len = 'using sendfile with configured UseSendfile length';
    my $expected_without_sendfile = 'declining use of sendfile due to UseSendfile configuration';

    while (my $line = <$fh>) {
      chomp($line);

      # Look for the "without sendfile" log message first; only if that
      # is found will we look for the "with sendfile" log message.
      if ($with_sendfile_ok == 0 &&
          $line =~ /$expected_without_sendfile/) {
        $without_sendfile_ok = 1;
      }

      if ($without_sendfile_ok == 1 &&
          $line =~ /$expected_with_sendfile/) {
        $with_sendfile_ok = 1;
      }

      if ($with_sendfile_ok == 1 &&
          $line =~ /$expected_with_sendfile_len/) {
        $with_sendfile_len_ok = 1;
        last;
      }
    }

    close($fh);

    $self->assert($without_sendfile_ok,
      test_msg("Expected log message '$expected_without_sendfile' did not appear in SystemLog"));

    $self->assert($with_sendfile_ok,
      test_msg("Expected log message '$expected_with_sendfile' did not appear in SystemLog"));

    $self->assert($with_sendfile_len_ok,
      test_msg("Expected log message '$expected_with_sendfile_len' did not appear in SystemLog"));

  } else {
    die("Can't read $log_file: $!");
  }

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub usesendfile_len_binary_ftpaccess_bug3310 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");
  
  my $user = 'proftpd';
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash'); 
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $sub_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($sub_dir);

  my $ftpaccess_file = File::Spec->rel2abs("$sub_dir/.ftpaccess");
  if (open(my $fh, "> $ftpaccess_file")) {
    print $fh "UseSendfile 256 b\n";
    unless (close($fh)) {
      die("Can't write $ftpaccess_file: $!");
    }

  } else {
    die("Can't open $ftpaccess_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    # We explicitly use DebugLevel 10 here, to get the sendfile log
    # message emitted by mod_xfer.
    DebugLevel => 10,

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

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Directory ~>
  UseSendfile off
</Directory>
EOC

    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  my $path_without_sendfile = File::Spec->rel2abs($config_file);

  # We copy the config file here, *after* it has been written out.
  my $path_with_sendfile = File::Spec->rel2abs("$sub_dir/test.dat");
  unless (copy($config_file, $path_with_sendfile)) {
    die("Can't copy '$config_file' to '$path_with_sendfile': $!");
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
      $client->login($user, $passwd);
      $client->type('binary');

      my ($buf, $conn, $expected, $resp_code, $resp_msg);

      $conn = $client->retr_raw($path_without_sendfile);
      unless ($conn) {
        die("RETR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      while ($conn->read($buf, 8192, 30)) {
      }
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $conn = $client->retr_raw($path_with_sendfile);
      unless ($conn) {
        die("RETR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      while ($conn->read($buf, 8192, 30)) {
      }
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();
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

  if (open(my $fh, "< $log_file")) {
    my $with_sendfile_ok = 0;
    my $with_sendfile_len_ok = 0;
    my $without_sendfile_ok = 0;

    my $expected_with_sendfile = 'using sendfile capability for transmitting data';
    my $expected_with_sendfile_len = 'using sendfile with configured UseSendfile length';
    my $expected_without_sendfile = 'declining use of sendfile due to UseSendfile configuration';

    while (my $line = <$fh>) {
      chomp($line);

      # Look for the "without sendfile" log message first; only if that
      # is found will we look for the "with sendfile" log message.
      if ($with_sendfile_ok == 0 &&
          $line =~ /$expected_without_sendfile/) {
        $without_sendfile_ok = 1;
      }

      if ($without_sendfile_ok == 1 &&
          $line =~ /$expected_with_sendfile/) {
        $with_sendfile_ok = 1;
      }

      if ($with_sendfile_ok == 1 &&
          $line =~ /$expected_with_sendfile_len/) {
        $with_sendfile_len_ok = 1;
        last;
      }
    }

    close($fh);

    $self->assert($without_sendfile_ok,
      test_msg("Expected log message '$expected_without_sendfile' did not appear in SystemLog"));

    $self->assert($with_sendfile_ok,
      test_msg("Expected log message '$expected_with_sendfile' did not appear in SystemLog"));

    $self->assert($with_sendfile_len_ok,
      test_msg("Expected log message '$expected_with_sendfile_len' did not appear in SystemLog"));

  } else {
    die("Can't read $log_file: $!");
  }

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub usesendfile_len_ascii_ftpaccess_bug3310 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");
  
  my $user = 'proftpd';
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash'); 
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $sub_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($sub_dir);

  my $ftpaccess_file = File::Spec->rel2abs("$sub_dir/.ftpaccess");
  if (open(my $fh, "> $ftpaccess_file")) {
    print $fh "UseSendfile 256 b\n";
    unless (close($fh)) {
      die("Can't write $ftpaccess_file: $!");
    }

  } else {
    die("Can't open $ftpaccess_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    # We explicitly use DebugLevel 10 here, to get the sendfile log
    # message emitted by mod_xfer.
    DebugLevel => 10,

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

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Directory ~>
  UseSendfile off
</Directory>
EOC

    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  my $path_without_sendfile = File::Spec->rel2abs($config_file);

  # We copy the config file here, *after* it has been written out.
  my $path_with_sendfile = File::Spec->rel2abs("$sub_dir/test.dat");
  unless (copy($config_file, $path_with_sendfile)) {
    die("Can't copy '$config_file' to '$path_with_sendfile': $!");
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
      $client->login($user, $passwd);
      $client->type('ascii');

      my ($buf, $conn, $expected, $resp_code, $resp_msg);

      $conn = $client->retr_raw($path_without_sendfile);
      unless ($conn) {
        die("RETR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      while ($conn->read($buf, 8192, 30)) {
      }
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $conn = $client->retr_raw($path_with_sendfile);
      unless ($conn) {
        die("RETR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      while ($conn->read($buf, 8192, 30)) {
      }
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();
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

  if (open(my $fh, "< $log_file")) {
    my $without_sendfile_config_ok = 0;
    my $without_sendfile_ascii_ok = 0;

    my $expected_without_sendfile_config = 'declining use of sendfile due to UseSendfile configuration';
    my $expected_without_sendfile_ascii = 'declining use of sendfile for ASCII data';

    while (my $line = <$fh>) {
      chomp($line);

      # Look for the "without sendfile" log message first; only if that
      # is found will we look for the "with sendfile" log message.
      if ($without_sendfile_config_ok == 0 &&
          $line =~ /$expected_without_sendfile_config/) {
        $without_sendfile_config_ok = 1;
      }

      if ($without_sendfile_config_ok == 1 &&
          $line =~ /$expected_without_sendfile_ascii/) {
        $without_sendfile_ascii_ok = 1;
        last;
      }
    }

    close($fh);

    $self->assert($without_sendfile_config_ok,
      test_msg("Expected log message '$expected_without_sendfile_config' did not appear in SystemLog"));

    $self->assert($without_sendfile_ascii_ok,
      test_msg("Expected log message '$expected_without_sendfile_ascii' did not appear in SystemLog"));

  } else {
    die("Can't read $log_file: $!");
  }

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub usesendfile_pct_binary_dir_bug3310 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");
  
  my $user = 'proftpd';
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash'); 
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $sub_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($sub_dir);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    # We explicitly use DebugLevel 10 here, to get the sendfile log
    # message emitted by mod_xfer.
    DebugLevel => 10,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Directory ~>
  UseSendfile off
</Directory>

<Directory ~/foo>
  UseSendfile 25%
</Directory>
EOC

    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  my $path_without_sendfile = File::Spec->rel2abs($config_file);

  # We copy the config file here, *after* it has been written out.
  my $path_with_sendfile = File::Spec->rel2abs("$sub_dir/test.dat");
  unless (copy($config_file, $path_with_sendfile)) {
    die("Can't copy '$config_file' to '$path_with_sendfile': $!");
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
      $client->login($user, $passwd);
      $client->type('binary');

      my ($buf, $conn, $expected, $resp_code, $resp_msg);

      $conn = $client->retr_raw($path_without_sendfile);
      unless ($conn) {
        die("RETR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      while ($conn->read($buf, 8192, 30)) {
      }
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $conn = $client->retr_raw($path_with_sendfile);
      unless ($conn) {
        die("RETR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      while ($conn->read($buf, 8192, 30)) {
      }
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();
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

  if (open(my $fh, "< $log_file")) {
    my $with_sendfile_ok = 0;
    my $with_sendfile_pct_ok = 0;
    my $without_sendfile_ok = 0;

    my $expected_with_sendfile = 'using sendfile capability for transmitting data';
    my $expected_with_sendfile_pct = 'using sendfile with configured UseSendfile percentage';
    my $expected_without_sendfile = 'declining use of sendfile due to UseSendfile configuration';

    while (my $line = <$fh>) {
      chomp($line);

      # Look for the "without sendfile" log message first; only if that
      # is found will we look for the "with sendfile" log message.
      if ($with_sendfile_ok == 0 &&
          $line =~ /$expected_without_sendfile/) {
        $without_sendfile_ok = 1;
      }

      if ($without_sendfile_ok == 1 &&
          $line =~ /$expected_with_sendfile/) {
        $with_sendfile_ok = 1;
      }

      if ($with_sendfile_ok == 1 &&
          $line =~ /$expected_with_sendfile_pct/) {
        $with_sendfile_pct_ok = 1;
        last;
      }
    }

    close($fh);

    $self->assert($without_sendfile_ok,
      test_msg("Expected log message '$expected_without_sendfile' did not appear in SystemLog"));

    $self->assert($with_sendfile_ok,
      test_msg("Expected log message '$expected_with_sendfile' did not appear in SystemLog"));

    $self->assert($with_sendfile_pct_ok,
      test_msg("Expected log message '$expected_with_sendfile_pct' did not appear in SystemLog"));

  } else {
    die("Can't read $log_file: $!");
  }

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub usesendfile_pct_binary_ftpaccess_bug3310 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");
  
  my $user = 'proftpd';
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash'); 
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $sub_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($sub_dir);

  my $ftpaccess_file = File::Spec->rel2abs("$sub_dir/.ftpaccess");
  if (open(my $fh, "> $ftpaccess_file")) {
    print $fh "UseSendfile 25%\n";
    unless (close($fh)) {
      die("Can't write $ftpaccess_file: $!");
    }

  } else {
    die("Can't open $ftpaccess_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    # We explicitly use DebugLevel 10 here, to get the sendfile log
    # message emitted by mod_xfer.
    DebugLevel => 10,

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

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Directory ~>
  UseSendfile off
</Directory>
EOC

    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  my $path_without_sendfile = File::Spec->rel2abs($config_file);

  # We copy the config file here, *after* it has been written out.
  my $path_with_sendfile = File::Spec->rel2abs("$sub_dir/test.dat");
  unless (copy($config_file, $path_with_sendfile)) {
    die("Can't copy '$config_file' to '$path_with_sendfile': $!");
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
      $client->login($user, $passwd);
      $client->type('binary');

      my ($buf, $conn, $expected, $resp_code, $resp_msg);

      $conn = $client->retr_raw($path_without_sendfile);
      unless ($conn) {
        die("RETR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      while ($conn->read($buf, 8192, 30)) {
      }
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $conn = $client->retr_raw($path_with_sendfile);
      unless ($conn) {
        die("RETR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      while ($conn->read($buf, 8192, 30)) {
      }
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();
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

  if (open(my $fh, "< $log_file")) {
    my $with_sendfile_ok = 0;
    my $with_sendfile_pct_ok = 0;
    my $without_sendfile_ok = 0;

    my $expected_with_sendfile = 'using sendfile capability for transmitting data';
    my $expected_with_sendfile_pct = 'using sendfile with configured UseSendfile percentage';
    my $expected_without_sendfile = 'declining use of sendfile due to UseSendfile configuration';

    while (my $line = <$fh>) {
      chomp($line);

      # Look for the "without sendfile" log message first; only if that
      # is found will we look for the "with sendfile" log message.
      if ($with_sendfile_ok == 0 &&
          $line =~ /$expected_without_sendfile/) {
        $without_sendfile_ok = 1;
      }

      if ($without_sendfile_ok == 1 &&
          $line =~ /$expected_with_sendfile/) {
        $with_sendfile_ok = 1;
      }

      if ($with_sendfile_ok == 1 &&
          $line =~ /$expected_with_sendfile_pct/) {
        $with_sendfile_pct_ok = 1;
        last;
      }
    }

    close($fh);

    $self->assert($without_sendfile_ok,
      test_msg("Expected log message '$expected_without_sendfile' did not appear in SystemLog"));

    $self->assert($with_sendfile_ok,
      test_msg("Expected log message '$expected_with_sendfile' did not appear in SystemLog"));

    $self->assert($with_sendfile_pct_ok,
      test_msg("Expected log message '$expected_with_sendfile_pct' did not appear in SystemLog"));

  } else {
    die("Can't read $log_file: $!");
  }

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

1;
