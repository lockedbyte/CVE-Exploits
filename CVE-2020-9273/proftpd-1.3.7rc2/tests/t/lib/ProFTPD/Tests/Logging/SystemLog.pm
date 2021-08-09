package ProFTPD::Tests::Logging::SystemLog;

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
  systemlog_default => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  systemlog_with_sysloglevel_crit => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  systemlog_with_debuglevel => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  systemlog_ifclass_matching_class_bug3832 => {
    order => ++$order,
    test_class => [qw(bug forking mod_ifsession)],
  },

  systemlog_ifclass_not_matching_class_bug3832 => {
    order => ++$order,
    test_class => [qw(bug forking mod_ifsession)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub systemlog_default {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/systemlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/systemlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/systemlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/systemlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/systemlog.group");

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    TransferLog => 'none',

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
    if (open(my $fh, "< $log_file")) {

      # We should see the following, in the order defined:
      #
      #  "FTP session opened"
      #  "USER proftpd: Login successful."
      #  "FTP session closed"

      my $saw_opened = 0;
      my $saw_login = 0;
      my $saw_closed = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if (!$saw_opened) {
          if ($line =~ /FTP session opened/) {
            $saw_opened = 1;
          }

        } else {
          if (!$saw_login) {
            if ($line =~ /USER $user: Login successful/) {
              $saw_login = 1;
            }

          } else {
            if (!$saw_closed) {
              if ($line =~ /FTP session closed/) {
                $saw_closed = 1;
                last;
              }
            }
          }
        }
      }

      close($fh);

      $self->assert($saw_opened, test_msg("Expected 'FTP session opened' message not seen"));
      $self->assert($saw_login, test_msg("Expected 'USER $user: Login successful' message not seen"));
      $self->assert($saw_closed, test_msg("Expected 'FTP session closed' message not seen"));

    } else {
      die("Can't read $log_file: $!");
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

sub systemlog_with_sysloglevel_crit {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/systemlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/systemlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/systemlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/systemlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/systemlog.group");

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    SyslogLevel => 'crit',
    TransferLog => 'none',

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
    if (open(my $fh, "< $log_file")) {

      # We should NOT see any of the following, due to the SyslogLevel
      # filtering:
      #
      #  "FTP session opened"
      #  "USER proftpd: Login successful."
      #  "FTP session closed"

      my $saw_opened = 0;
      my $saw_login = 0;
      my $saw_closed = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($line =~ /FTP session opened/) {
          $saw_opened = 1;
        }

        if (!$saw_login) {
          if ($line =~ /USER $user: Login successful/) {
            $saw_login = 1;
          }
        } 

        if (!$saw_closed) {
          if ($line =~ /FTP session closed/) {
            $saw_closed = 1;
          }
        }
      }

      close($fh);

      $self->assert(!$saw_opened, test_msg("Unexpectedly saw 'FTP session opened' message"));
      $self->assert(!$saw_login, test_msg("Unexpectedly saw 'USER $user: Login successful' message"));
      $self->assert(!$saw_closed, test_msg("Unexpectedly saw 'FTP session closed' message"));

    } else {
      die("Can't read $log_file: $!");
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

sub systemlog_with_debuglevel {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/systemlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/systemlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/systemlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/systemlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/systemlog.group");

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

  my $timeout_session = 60;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    DebugLevel => 4,

    # Use this to trigger a debug level 4 log message
    TimeoutSession => $timeout_session,
    TransferLog => 'none',

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
    if (open(my $fh, "< $log_file")) {

      # With a TimeoutSession set, and DebugLevel set to 4, we should see:
      #
      #  "setting TimeoutSession of 60 seconds"

      my $saw_mesg = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($line =~ /setting TimeoutSession of $timeout_session seconds/) {
          $saw_mesg = 1;
          last;
        }
      }

      close($fh);

      $self->assert($saw_mesg, test_msg("Did not see 'setting TimeoutSession of $timeout_session seconds' message as expected"));

    } else {
      die("Can't read $log_file: $!");
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

sub systemlog_ifclass_matching_class_bug3832 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/systemlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/systemlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/systemlog.scoreboard");

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/systemlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/systemlog.group");

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

  my $system_log = File::Spec->rel2abs("$tmpdir/system.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $system_log,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Append the mod_ifsession config to the end of the config file
  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Class local>
  From 127.0.0.1
</Class>

<IfClass local>
  SystemLog none
</IfClass>
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
      $client->login($user, $passwd);
      $client->type('ascii');

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 25);
      eval { $conn->close() };
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

  if (open(my $fh, "< $system_log")) {
    my $sess_nlines = 0;
    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /session (opened|closed)/) {
        $sess_nlines++;
      }
    }

    close($fh);

    $self->assert($sess_nlines == 0,
      test_msg("Expected no lines in $system_log, got $sess_nlines lines"));

  } else {
    die("Can't read $system_log: $!");
  }

  if ($ex) {
    test_append_logfile($system_log, $ex);
    unlink($system_log);

    die($ex);
  }

  unlink($system_log);
}

sub systemlog_ifclass_not_matching_class_bug3832 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/systemlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/systemlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/systemlog.scoreboard");

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/systemlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/systemlog.group");

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

  my $system_log = File::Spec->rel2abs("$tmpdir/system.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $system_log,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Append the mod_ifsession config to the end of the config file
  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Class local>
  From 127.0.0.1
</Class>

<IfClass !local>
  SystemLog none
</IfClass>
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
      $client->login($user, $passwd);
      $client->type('ascii');

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 25);
      eval { $conn->close() };
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

  if (open(my $fh, "< $system_log")) {
    my $sess_nlines = 0;
    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /session (opened|closed)/) {
        $sess_nlines++;
      }
    }

    close($fh);

    $self->assert($sess_nlines > 0,
      test_msg("Expected lines in $system_log, got none"));

  } else {
    die("Can't read $system_log: $!");
  }

  if ($ex) {
    test_append_logfile($system_log, $ex);
    unlink($system_log);

    die($ex);
  }

  unlink($system_log);
}

1;
