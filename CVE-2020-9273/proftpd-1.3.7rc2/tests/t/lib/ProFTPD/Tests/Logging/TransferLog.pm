package ProFTPD::Tests::Logging::TransferLog;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use File::Spec;
use IO::Handle;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  xferlog_retr_ascii_ok => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  xferlog_retr_binary_ok => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  xferlog_retr_aborted => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  xferlog_stor_ascii_ok => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  xferlog_stor_binary_ok => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  xferlog_stor_aborted => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  xferlog_stor_enospc_bug3895 => {
    order => ++$order,
    test_class => [qw(bug forking mod_enospc)],
  },

  xferlog_dele_ok => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  xferlog_device_full_for_log => {
    order => ++$order,
    test_class => [qw(forking os_linux)],
  },

  xferlog_device_full_for_upload => {
    order => ++$order,
    test_class => [qw(forking os_linux)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub xferlog_retr_ascii_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/xferlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/xferlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/xferlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/xferlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/xferlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
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
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $xfer_log = File::Spec->rel2abs("$tmpdir/xfer.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    TransferLog => $xfer_log,

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
      $client->type('ascii');

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
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

  if (open(my $fh, "< $xfer_log")) {
    my $line = <$fh>;
    chomp($line);
    close($fh);

    my $expected = '^\S+\s+\S+\s+\d+\s+\d+:\d+:\d+\s+\d+\s+\d+\s+(\S+)\s+(\d+)\s+(\S+)\s+(\S+)\s+_\s+o\s+r\s+(\S+)\s+ftp\s+0\s+\*\s+c$';

    $self->assert(qr/$expected/, $line,
      test_msg("Expected '$expected', got '$line'"));

    if ($line =~ /$expected/) {
      my $remote_host = $1;
      my $filesz = $2;
      my $filename = $3;
      my $xfer_type = $4;
      my $user_name = $5;

      $expected = '127.0.0.1';
      $self->assert($expected eq $remote_host,
        test_msg("Expected '$expected', got '$remote_host'"));

      $expected = -s $test_file;
      $self->assert($expected == $filesz,
        test_msg("Expected '$expected', got '$filesz'"));

      $expected = $test_file;
      $self->assert($expected eq $filename,
        test_msg("Expected '$expected', got '$filename'"));

      $expected = 'a';
      $self->assert($expected eq $xfer_type,
        test_msg("Expected '$expected', got '$xfer_type'"));

      $expected = $user;
      $self->assert($expected eq $user_name,
        test_msg("Expected '$expected', got '$user_name'"));
    }

  } else {
    die("Can't read $xfer_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub xferlog_retr_binary_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/xferlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/xferlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/xferlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/xferlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/xferlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
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
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $xfer_log = File::Spec->rel2abs("$tmpdir/xfer.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    TransferLog => $xfer_log,

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
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
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

  if (open(my $fh, "< $xfer_log")) {
    my $line = <$fh>;
    chomp($line);
    close($fh);

    my $expected = '^\S+\s+\S+\s+\d+\s+\d+:\d+:\d+\s+\d+\s+\d+\s+(\S+)\s+(\d+)\s+(\S+)\s+(\S+)\s+_\s+o\s+r\s+(\S+)\s+ftp\s+0\s+\*\s+c$';

    $self->assert(qr/$expected/, $line,
      test_msg("Expected '$expected', got '$line'"));

    if ($line =~ /$expected/) {
      my $remote_host = $1;
      my $filesz = $2;
      my $filename = $3;
      my $xfer_type = $4;
      my $user_name = $5;

      $expected = '127.0.0.1';
      $self->assert($expected eq $remote_host,
        test_msg("Expected '$expected', got '$remote_host'"));

      $expected = -s $test_file;
      $self->assert($expected == $filesz,
        test_msg("Expected '$expected', got '$filesz'"));

      $expected = $test_file;
      $self->assert($expected eq $filename,
        test_msg("Expected '$expected', got '$filename'"));

      $expected = 'b';
      $self->assert($expected eq $xfer_type,
        test_msg("Expected '$expected', got '$xfer_type'"));

      $expected = $user;
      $self->assert($expected eq $user_name,
        test_msg("Expected '$expected', got '$user_name'"));
    }

  } else {
    die("Can't read $xfer_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub xferlog_retr_aborted {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/xferlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/xferlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/xferlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/xferlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/xferlog.group");

  my $test_file = File::Spec->rel2abs("$tmpdir/foo");
  if (open(my $fh, "> $test_file")) {
    print $fh "ABCD" x 4096, "\n";

    unless(close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
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
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $xfer_log = File::Spec->rel2abs("$tmpdir/xfer.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    # Have the file being downloaded be sent in 1KB chunks, to slow the
    # download down
    SocketOptions => 'sndbuf 1024',

    # Make sure the download is throttled, so that the abort reaches the
    # server before the file being downloaded has been written out
    TransferRate => 'RETR 1',

    TransferLog => $xfer_log,

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
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 1, 30);
      $conn->abort();
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

  if (open(my $fh, "< $xfer_log")) {
    my $line = <$fh>;
    chomp($line);
    close($fh);

    my $expected = '^\S+\s+\S+\s+\d+\s+\d+:\d+:\d+\s+\d+\s+\d+\s+(\S+)\s+(\d+)\s+(\S+)\s+(\S+)\s+_\s+o\s+r\s+(\S+)\s+ftp\s+0\s+\*\s+i$';

    $self->assert(qr/$expected/, $line,
      test_msg("Expected '$expected', got '$line'"));

    if ($line =~ /$expected/) {
      my $remote_host = $1;
      my $filesz = $2;
      my $filename = $3;
      my $xfer_type = $4;
      my $user_name = $5;

      $expected = '127.0.0.1';
      $self->assert($expected eq $remote_host,
        test_msg("Expected '$expected', got '$remote_host'"));

      $expected = $test_file;
      $self->assert($expected eq $filename,
        test_msg("Expected '$expected', got '$filename'"));

      $expected = 'b';
      $self->assert($expected eq $xfer_type,
        test_msg("Expected '$expected', got '$xfer_type'"));

      $expected = $user;
      $self->assert($expected eq $user_name,
        test_msg("Expected '$expected', got '$user_name'"));
    }

  } else {
    die("Can't read $xfer_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub xferlog_stor_ascii_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/xferlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/xferlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/xferlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/xferlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/xferlog.group");

  my $test_file = File::Spec->rel2abs("$tmpdir/foo");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
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
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $xfer_log = File::Spec->rel2abs("$tmpdir/xfer.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    TransferLog => $xfer_log,

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
      $client->type('ascii');

      my $conn = $client->stor_raw('foo');
      unless ($conn) {
        die("Failed to STOR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Foo!\n";
      $conn->write($buf, length($buf));
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

  if (open(my $fh, "< $xfer_log")) {
    my $line = <$fh>;
    chomp($line);
    close($fh);

    my $expected = '^\S+\s+\S+\s+\d+\s+\d+:\d+:\d+\s+\d+\s+\d+\s+(\S+)\s+(\d+)\s+(\S+)\s+(\S+)\s+_\s+i\s+r\s+(\S+)\s+ftp\s+0\s+\*\s+c$';

    $self->assert(qr/$expected/, $line,
      test_msg("Expected '$expected', got '$line'"));

    if ($line =~ /$expected/) {
      my $remote_host = $1;
      my $filesz = $2;
      my $filename = $3;
      my $xfer_type = $4;
      my $user_name = $5;

      $expected = '127.0.0.1';
      $self->assert($expected eq $remote_host,
        test_msg("Expected '$expected', got '$remote_host'"));

      $expected = -s $test_file;
      $self->assert($expected == $filesz,
        test_msg("Expected '$expected', got '$filesz'"));

      $expected = $test_file;
      $self->assert($expected eq $filename,
        test_msg("Expected '$expected', got '$filename'"));

      $expected = 'a';
      $self->assert($expected eq $xfer_type,
        test_msg("Expected '$expected', got '$xfer_type'"));

      $expected = $user;
      $self->assert($expected eq $user_name,
        test_msg("Expected '$expected', got '$user_name'"));
    }

  } else {
    die("Can't read $xfer_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub xferlog_stor_binary_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/xferlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/xferlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/xferlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/xferlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/xferlog.group");

  my $test_file = File::Spec->rel2abs("$tmpdir/foo");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
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
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $xfer_log = File::Spec->rel2abs("$tmpdir/xfer.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    TransferLog => $xfer_log,

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

      my $conn = $client->stor_raw('foo');
      unless ($conn) {
        die("Failed to STOR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Foo!\n";
      $conn->write($buf, length($buf));
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

  if (open(my $fh, "< $xfer_log")) {
    my $line = <$fh>;
    chomp($line);
    close($fh);

    my $expected = '^\S+\s+\S+\s+\d+\s+\d+:\d+:\d+\s+\d+\s+\d+\s+(\S+)\s+(\d+)\s+(\S+)\s+(\S+)\s+_\s+i\s+r\s+(\S+)\s+ftp\s+0\s+\*\s+c$';

    $self->assert(qr/$expected/, $line,
      test_msg("Expected '$expected', got '$line'"));

    if ($line =~ /$expected/) {
      my $remote_host = $1;
      my $filesz = $2;
      my $filename = $3;
      my $xfer_type = $4;
      my $user_name = $5;

      $expected = '127.0.0.1';
      $self->assert($expected eq $remote_host,
        test_msg("Expected '$expected', got '$remote_host'"));

      $expected = -s $test_file;
      $self->assert($expected == $filesz,
        test_msg("Expected '$expected', got '$filesz'"));

      $expected = $test_file;
      $self->assert($expected eq $filename,
        test_msg("Expected '$expected', got '$filename'"));

      $expected = 'b';
      $self->assert($expected eq $xfer_type,
        test_msg("Expected '$expected', got '$xfer_type'"));

      $expected = $user;
      $self->assert($expected eq $user_name,
        test_msg("Expected '$expected', got '$user_name'"));
    }

  } else {
    die("Can't read $xfer_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub xferlog_stor_aborted {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/xferlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/xferlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/xferlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/xferlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/xferlog.group");

  my $test_file = File::Spec->rel2abs("$tmpdir/foo");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
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
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $xfer_log = File::Spec->rel2abs("$tmpdir/xfer.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    TransferLog => $xfer_log,

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

      my $conn = $client->stor_raw('foo');
      unless ($conn) {
        die("Failed to STOR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Foo!\n";
      $conn->write($buf, 3);
      $conn->abort();
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

  if (open(my $fh, "< $xfer_log")) {
    my $line = <$fh>;
    chomp($line);
    close($fh);

    my $expected = '^\S+\s+\S+\s+\d+\s+\d+:\d+:\d+\s+\d+\s+\d+\s+(\S+)\s+(\d+)\s+(\S+)\s+(\S+)\s+_\s+i\s+r\s+(\S+)\s+ftp\s+0\s+\*\s+i$';

    $self->assert(qr/$expected/, $line,
      test_msg("Expected '$expected', got '$line'"));

    if ($line =~ /$expected/) {
      my $remote_host = $1;
      my $filesz = $2;
      my $filename = $3;
      my $xfer_type = $4;
      my $user_name = $5;

      $expected = '127.0.0.1';
      $self->assert($expected eq $remote_host,
        test_msg("Expected '$expected', got '$remote_host'"));

      $expected = $test_file;
      $self->assert($expected eq $filename,
        test_msg("Expected '$expected', got '$filename'"));

      $expected = 'b';
      $self->assert($expected eq $xfer_type,
        test_msg("Expected '$expected', got '$xfer_type'"));

      $expected = $user;
      $self->assert($expected eq $user_name,
        test_msg("Expected '$expected', got '$user_name'"));
    }

  } else {
    die("Can't read $xfer_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub xferlog_stor_enospc_bug3895 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/xferlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/xferlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/xferlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/xferlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/xferlog.group");

  my $test_file = File::Spec->rel2abs("$tmpdir/foo");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
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
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $xfer_log = File::Spec->rel2abs("$tmpdir/xfer.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    TransferLog => $xfer_log,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_enospc.c' => {
        NoSpaceEngine => 'on',
        NoSpaceThreshold => '1',
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

      my $conn = $client->stor_raw('foo');
      unless ($conn) {
        die("Failed to STOR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Foo!\n";
      $conn->write($buf, 3, 5);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "foo: No space left on device";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

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

  eval {
    if (open(my $fh, "< $xfer_log")) {
      my $line = <$fh>;
      chomp($line);
      close($fh);

      my $expected = '^\S+\s+\S+\s+\d+\s+\d+:\d+:\d+\s+\d+\s+\d+\s+(\S+)\s+(\d+)\s+(\S+)\s+(\S+)\s+_\s+i\s+r\s+(\S+)\s+ftp\s+0\s+\*\s+i$';

      $self->assert(qr/$expected/, $line,
        test_msg("Expected '$expected', got '$line'"));

      if ($line =~ /$expected/) {
        my $remote_host = $1;
        my $filesz = $2;
        my $filename = $3;
        my $xfer_type = $4;
        my $user_name = $5;

        $expected = '127.0.0.1';
        $self->assert($expected eq $remote_host,
          test_msg("Expected '$expected', got '$remote_host'"));

        $expected = $test_file;
        $self->assert($expected eq $filename,
          test_msg("Expected '$expected', got '$filename'"));

        $expected = 'b';
        $self->assert($expected eq $xfer_type,
          test_msg("Expected '$expected', got '$xfer_type'"));

        $expected = $user;
        $self->assert($expected eq $user_name,
          test_msg("Expected '$expected', got '$user_name'"));
      }

    } else {
      die("Can't read $xfer_log: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub xferlog_dele_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/xferlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/xferlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/xferlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/xferlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/xferlog.group");

  my $test_file = File::Spec->rel2abs("$tmpdir/foo");
  if (open(my $fh, "> $test_file")) {
    print $fh "ABCD" x 4096, "\n";

    unless(close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $test_filesz = -s $test_file;

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
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
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $xfer_log = File::Spec->rel2abs("$tmpdir/xfer.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    TransferLog => $xfer_log,

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

      $client->dele($test_file);
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

  if (open(my $fh, "< $xfer_log")) {
    my $line = <$fh>;
    chomp($line);
    close($fh);

    my $expected = '^\S+\s+\S+\s+\d+\s+\d+:\d+:\d+\s+\d+\s+\d+\s+(\S+)\s+(\d+)\s+(\S+)\s+(\S+)\s+_\s+d\s+r\s+(\S+)\s+ftp\s+0\s+\*\s+c$';

    $self->assert(qr/$expected/, $line,
      test_msg("Expected '$expected', got '$line'"));

    if ($line =~ /$expected/) {
      my $remote_host = $1;
      my $filesz = $2;
      my $filename = $3;
      my $xfer_type = $4;
      my $user_name = $5;

      $expected = '127.0.0.1';
      $self->assert($expected eq $remote_host,
        test_msg("Expected '$expected', got '$remote_host'"));

      $expected = $test_filesz;
      $self->assert($expected == $filesz,
        test_msg("Expected '$expected', got '$test_filesz'"));

      $expected = $test_file;
      $expected = $test_file;
      $self->assert($expected eq $filename,
        test_msg("Expected '$expected', got '$filename'"));

      $expected = 'b';
      $self->assert($expected eq $xfer_type,
        test_msg("Expected '$expected', got '$xfer_type'"));

      $expected = $user;
      $self->assert($expected eq $user_name,
        test_msg("Expected '$expected', got '$user_name'"));
    }

  } else {
    die("Can't read $xfer_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub xferlog_device_full_for_log {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/xferlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/xferlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/xferlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/xferlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/xferlog.group");

  my $test_file = File::Spec->rel2abs("$tmpdir/foo");
  if (open(my $fh, "> $test_file")) {
    print $fh "ABCD" x 4096, "\n";

    unless(close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
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
  auth_group_write($auth_group_file, $group, $gid, $user);

  # XXX The /dev/full device only exists on Linux, as far as I know
  my $xfer_log = File::Spec->rel2abs('/dev/full');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    TransferLog => $xfer_log,

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

      $client->dele($test_file);
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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub xferlog_device_full_for_upload {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/xferlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/xferlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/xferlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/xferlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/xferlog.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
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
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $xfer_log = File::Spec->rel2abs("$tmpdir/xfer.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    AllowOverwrite => 'on',
    TransferLog => $xfer_log,

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

      my $conn = $client->stor_raw('/dev/full');
      unless ($conn) {
        die("Can't STOR /dev/full: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Hello, World!\n";
      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected = 452;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'Transfer aborted. No space left on device';
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

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

  eval {
    if (open(my $fh, "< $xfer_log")) {
      my $ok = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($line =~ /\/dev\/full b.*?i$/) {
          $ok = 1;
          last;
        }
      }

      close($fh);

      $self->assert($ok, test_msg("Did not see expected TransferLog line"));

    } else {
      die("Can't read $xfer_log: $!");
    }

  };
  if ($@) {
    $ex = $@;
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

1;
