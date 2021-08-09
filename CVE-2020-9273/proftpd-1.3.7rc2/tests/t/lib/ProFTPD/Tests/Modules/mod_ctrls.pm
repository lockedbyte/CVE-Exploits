package ProFTPD::Tests::Modules::mod_ctrls;

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
  ctrls_lsctrl_ok => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ctrls_lsctrl_system_user_ok => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ctrls_sighup_bug3756 => {
    order => ++$order,
    test_class => [qw(bug forking os_linux)],
  },

  ctrls_intvl_timeoutlogin_bug4298 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub ftpdctl {
  my $sock_file = shift;
  my $ctrl_cmd = shift;
  my $poll_interval = shift;
  $poll_interval = 3 unless defined($poll_interval);

  my $ftpdctl_bin;
  if ($ENV{PROFTPD_TEST_PATH}) {
    $ftpdctl_bin = "$ENV{PROFTPD_TEST_PATH}/ftpdctl";

  } else {
    $ftpdctl_bin = '../ftpdctl';
  }

  my $cmd = "$ftpdctl_bin -s $sock_file $ctrl_cmd";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing ftpdctl: $cmd\n";
  }

  my @lines = `$cmd`;
  return \@lines;
}

sub get_server_pid {
  my $pid_file = shift;

  my $pid;
  if (open(my $fh, "< $pid_file")) {
    $pid = <$fh>;
    chomp($pid);
    close($fh);

  } else {
    croak("Can't read $pid_file: $!");
  }

  return $pid;
}

sub server_open_fds {
  my $pid_file = shift;

  my $pid = get_server_pid($pid_file);

  my $proc_dir = "/proc/$pid/fd";
  if (opendir(my $dirh, $proc_dir)) {
    my $count = 0;

    # Only count entries whose names are numbers
    while (my $dent = readdir($dirh)) {
      if ($dent =~ /^\d+$/) {
        $count++;
      }
    }

    closedir($dirh);
    return $count;

  } else {
    croak("Can't open directory '$proc_dir': $!");
  }
}

sub server_restart {
  my $pid_file = shift;
  my $count = shift;
  $count = 1 unless defined($count);

  my $pid = get_server_pid($pid_file);

  for (my $i = 0; $i < $count; $i++) {
    unless (kill('HUP', $pid)) {
      print STDERR "Couldn't send SIGHUP to PID $pid: $!\n";

    } else {
      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Restart #", $i + 1, ": Sent SIGHUP to PID $pid\n";
      }
    }
  }
}

sub ctrls_lsctrl_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ctrls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ctrls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ctrls.scoreboard");

  my $log_file = test_get_logfile();

  my $ctrls_sock = File::Spec->rel2abs("$tmpdir/ctrls.sock");

  my ($user, $group) = config_get_identity();
  my $poll_interval = 2;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'ctrls:20 event:10',

    IfModules => {
      'mod_ctrls.c' => {
        ControlsEngine => 'on',
        ControlsLog => $log_file,
        ControlsSocket => $ctrls_sock,
        ControlsACLs => "all allow user *",
        ControlsSocketACL => "allow user *",
        ControlsInterval => $poll_interval,
      },

      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  my $ex;

  # Start server
  server_start($config_file);
  sleep(1);

  eval {
    my $lines = ftpdctl($ctrls_sock, 'lsctrl', $poll_interval);
    $lines = [grep { /mod_ctrls\.c/ } @$lines];

    my $expected = 4;

    my $matches = scalar(@$lines);
    $self->assert($expected == $matches,
      test_msg("Expected $expected, got $matches"));

    my $actions = '';
    foreach my $line (@$lines) {
      if ($line =~ /^ftpdctl: (\S+) \S+$/) {
        $actions .= "$1 ";
      }
    }

    $expected = 'help insctrl lsctrl rmctrl ';
    $self->assert($expected eq $actions,
      test_msg("Expected '$expected', got '$actions'"));
  }; 

  if ($@) {
    $ex = $@;
  }

  server_stop($pid_file);

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub ctrls_lsctrl_system_user_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ctrls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ctrls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ctrls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/ctrls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/ctrls.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $ctrls_sock = File::Spec->rel2abs("$tmpdir/ctrls.sock");

  my ($sys_user, $sys_group) = config_get_identity();

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    AuthOrder => 'mod_auth_file.c',

    IfModules => {
      'mod_ctrls.c' => {
        ControlsEngine => 'on',
        ControlsLog => $log_file,
        ControlsSocket => $ctrls_sock,
        ControlsACLs => "all allow user root,$sys_user",
        ControlsSocketACL => "allow user root,$sys_user",
      },

      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  my $ex;

  # Start server
  server_start($config_file);

  sleep(1);

  eval {
    my $lines = ftpdctl($ctrls_sock, 'lsctrl');
    $lines = [grep { /mod_ctrls\.c/ } @$lines];

    my $expected = 4;

    my $matches = scalar(@$lines);
    $self->assert($expected == $matches,
      test_msg("Expected $expected, got $matches"));

    my $actions = '';
    foreach my $line (@$lines) {
      if ($line =~ /^ftpdctl: (\S+) \S+$/) {
        $actions .= "$1 ";
      }
    }

    $expected = 'help insctrl lsctrl rmctrl ';
    $self->assert($expected eq $actions,
      test_msg("Expected '$expected', got '$actions'"));
  }; 

  if ($@) {
    $ex = $@;
  }

  server_stop($pid_file);

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub ctrls_sighup_bug3756 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ctrls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ctrls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ctrls.scoreboard");

  my $log_file = test_get_logfile();

  my $ctrls_sock = File::Spec->rel2abs("$tmpdir/ctrls.sock");

  my ($user, $group) = config_get_identity();

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    IfModules => {
      'mod_ctrls.c' => {
        ControlsEngine => 'on',
        ControlsLog => $log_file,
        ControlsSocket => $ctrls_sock,
        ControlsACLs => "all allow user root,$user",
        ControlsSocketACL => "allow user root,$user",
      },

      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  my $ex;

  # Start server
  server_start($config_file);

  sleep(1);

  eval {
    # Use proc(5) filesystem to count the number of open fds in the daemon
    my $orig_nfds = server_open_fds($pid_file);
    if ($ENV{TEST_VERBOSE}) {
      print STDERR "Found $orig_nfds open fds after server startup\n";
    }

    # Restart the server
    server_restart($pid_file);
    sleep(1);

    # Count the open fds again, make sure we haven't leaked any
    my $restart_nfds = server_open_fds($pid_file);
    if ($ENV{TEST_VERBOSE}) {
      print STDERR "Found $restart_nfds open fds after server restart #1\n";
    }

    $self->assert($orig_nfds == $restart_nfds,
      test_msg("Expected $orig_nfds open fds, found $restart_nfds"));

    # Restart the server
    server_restart($pid_file);
    sleep(1);

    # And count the open fds one more time, to make doubly sure we are not
    # leaking fds.
    $restart_nfds = server_open_fds($pid_file);
    if ($ENV{TEST_VERBOSE}) {
      print STDERR "Found $restart_nfds open fds after server restart #2\n";
    }

    $self->assert($orig_nfds == $restart_nfds,
      test_msg("Expected $orig_nfds open fds, found $restart_nfds"));
  }; 

  if ($@) {
    $ex = $@;
  }

  server_stop($pid_file);

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub ctrls_intvl_timeoutlogin_bug4298 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'ctrls');

  my $ctrls_sock = File::Spec->rel2abs("$tmpdir/ctrls.sock");

  my ($user, $group) = config_get_identity();
  my $poll_interval = 2;

  # Try to reproduce Bug#4298 by having the TimeoutLogin be a multiple of
  # the Controls Interval.
  my $timeout_login = ($poll_interval * 4);
  my $timeout_idle = 30;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'ctrls:20 event:10 timers:20',

    TimeoutIdle => $timeout_idle,
    TimeoutLogin => $timeout_login,

    IfModules => {
      'mod_ctrls.c' => {
        ControlsEngine => 'on',
        ControlsLog => $setup->{log_file},
        ControlsSocket => $ctrls_sock,
        ControlsACLs => "all allow user *",
        ControlsSocketACL => "allow user *",
        ControlsInterval => $poll_interval,
      },

      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($setup->{config_file},
    $config);

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

      # Wait for one second longer than the TimeoutLogin
      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Delaying for ", ($timeout_login + 1), " secs\n";
      }

      sleep($timeout_login + 1);

      eval { $client->login($setup->{user}, $setup->{passwd}) };
      unless ($@) {
        $client->quit();
        die("Login succeeded unexpectedly");
      }
    };
    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 3) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  # Stop server
  server_stop($setup->{pid_file});
  $self->assert_child_ok($pid);

  test_cleanup($setup->{log_file}, $ex);
}

1;
