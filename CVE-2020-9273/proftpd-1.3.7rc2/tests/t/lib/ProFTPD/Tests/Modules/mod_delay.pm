package ProFTPD::Tests::Modules::mod_delay;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use File::Path qw(mkpath);
use File::Spec;
use IO::Handle;
use Time::HiRes qw(gettimeofday tv_interval);

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  delay_cold_table => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  delay_warm_table => {
    order => ++$order,
    test_class => [qw(forking slow)],
  },

  delay_extra_user_cmd_bug3622 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  delay_extra_pass_cmd_bug3622 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  delay_table_none_bug4020 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  delay_delayonevent_user_bug4020 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  delay_delayonevent_pass_bug4020 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  delay_delayonevent_failedlogin_bug4020 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  delay_delayonevent_user_pass_bug4020 => {
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

sub delay_cold_table {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/delay.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/delay.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/delay.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/delay.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/delay.group");

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

  my $delay_tab = File::Spec->rel2abs("$home_dir/delay.tab");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'delay:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayTable => $delay_tab,
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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub delay_warm_table {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/delay.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/delay.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/delay.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/delay.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/delay.group");

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

  my $delay_tab = File::Spec->rel2abs("$home_dir/delay.tab");

  # In order to warm up the DelayTable, we need to fill its columns,
  # which means more than 256 logins before the table is "warm".
  my $nlogins = 300;

  my $timeout = ($nlogins * 2);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'delay:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayTable => $delay_tab,
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
      my $max_elapsed = -1;

      for (my $i = 0; $i < $nlogins; $i++) {
        my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

        my $start = [gettimeofday()];        
        $client->login($user, $passwd);
        my $elapsed = tv_interval($start);
 
        $client->quit();

        if ($elapsed > $max_elapsed) {
          $max_elapsed = $elapsed;
        }

        if ($ENV{TEST_VERBOSE}) {
          if ($i % 50 == 0) {
            print STDERR " + login #", $i + 1, " (max elapsed = $max_elapsed)\n";
          }
        }
      }

      if ($ENV{TEST_VERBOSE}) {
        print STDERR " + max elapsed = $max_elapsed\n";
      }
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout) };
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

sub delay_extra_user_cmd_bug3622 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/delay.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/delay.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/delay.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/delay.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/delay.group");

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

  my $delay_tab = File::Spec->rel2abs("$home_dir/delay.tab");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'delay:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayTable => $delay_tab,
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

      eval { $client->user($user) };
      unless ($@) {
        die("Second USER command succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 500;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'Bad sequence of commands';
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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  # Examine the TraceLog, looking for "unable to load DelayTable" messages.
  # There shouldn't be any.

  if (open(my $fh, "< $log_file")) {
    my $ok = 1;

    while (my $line = <$fh>) {
      chomp($line);

      my $expected = '\[\d+\]\s+<(\S+):(\d+)>: (.*?)$';

      if ($line =~ /$expected/) {
        my $trace_channel = $1;
        my $trace_level = $2;
        my $trace_msg = $3;

        next unless $trace_channel eq 'delay';

        if ($trace_msg =~ /unable to load DelayTable/) {
          $ok = 0;
          last;
        }
      }
    }

    close($fh);

    $self->assert($ok, test_msg("Trace messages appeared unexpectedly"));

  } else {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die("Can't open $log_file: $!");
  }

  unlink($log_file);
}

sub delay_extra_pass_cmd_bug3622 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/delay.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/delay.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/delay.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/delay.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/delay.group");

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

  my $delay_tab = File::Spec->rel2abs("$home_dir/delay.tab");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'delay:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayTable => $delay_tab,
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

      eval { $client->pass($passwd) };
      unless ($@) {
        die("Second PASS command succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 503;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'You are already logged in';
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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  # Examine the TraceLog, looking for "unable to load DelayTable" messages.
  # There shouldn't be any.

  if (open(my $fh, "< $log_file")) {
    my $ok = 1;

    while (my $line = <$fh>) {
      chomp($line);

      my $expected = '\[\d+\]\s+<(\S+):(\d+)>: (.*?)$';

      if ($line =~ /$expected/) {
        my $trace_channel = $1;
        my $trace_level = $2;
        my $trace_msg = $3;

        next unless $trace_channel eq 'delay';

        if ($trace_msg =~ /unable to load DelayTable/) {
          $ok = 0;
          last;
        }
      }
    }

    close($fh);

    $self->assert($ok, test_msg("Trace messages appeared unexpectedly"));

  } else {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die("Can't open $log_file: $!");
  }

  unlink($log_file);
}

sub delay_table_none_bug4020 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/delay.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/delay.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/delay.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/delay.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/delay.group");

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
    TraceLog => $log_file,
    Trace => 'delay:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayTable => 'none',
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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  # Examine the TraceLog, looking for "unable to load DelayTable" messages.
  # There shouldn't be any.

  if (open(my $fh, "< $log_file")) {
    my $ok = 1;

    while (my $line = <$fh>) {
      chomp($line);

      my $expected = '\[\d+\]\s+<(\S+):(\d+)>: (.*?)$';

      if ($line =~ /$expected/) {
        my $trace_channel = $1;
        my $trace_level = $2;
        my $trace_msg = $3;

        next unless $trace_channel eq 'delay';

        if ($trace_msg =~ /(unable to load|error opening) DelayTable/) {
          $ok = 0;

          if ($ENV{TEST_VERBOSE}) {
            print STDERR " + unexpected TraceLog line: $line\n";
          }

          last;
        }
      }
    }

    close($fh);

    $self->assert($ok, test_msg("Trace messages appeared unexpectedly"));

  } else {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die("Can't open $log_file: $!");
  }

  unlink($log_file);
}

sub delay_delayonevent_user_bug4020 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/delay.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/delay.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/delay.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/delay.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/delay.group");

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

  my $user_delay_secs = 2;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'delay:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayTable => 'none',
        DelayOnEvent => 'USER 2000ms',
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

      my $start = [gettimeofday()];        
      $client->login($user, $passwd);
      my $elapsed = tv_interval($start);

      $client->quit();

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Elapsed login time: $elapsed secs\n";
      }

      if ($elapsed < $user_delay_secs) {
        die("Expected at least $user_delay_secs sec delay, got $elapsed");
      }
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

sub delay_delayonevent_pass_bug4020 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/delay.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/delay.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/delay.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/delay.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/delay.group");

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

  my $pass_delay_secs = 2;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'delay:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayTable => 'none',
        DelayOnEvent => 'PASS 2000',
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

      my $start = [gettimeofday()];        
      eval { $client->login($user, 'foobar') };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }
      my $elapsed = tv_interval($start);

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Elapsed login time: $elapsed secs\n";
      }

      if ($elapsed < $pass_delay_secs) {
        die("Expected at least $pass_delay_secs sec delay, got $elapsed");
      }

      $start = [gettimeofday()];        
      $client->login($user, $passwd);
      $elapsed = tv_interval($start);

      $client->quit();

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Elapsed login time: $elapsed secs\n";
      }

      if ($elapsed < $pass_delay_secs) {
        die("Expected at least $pass_delay_secs sec delay, got $elapsed");
      }
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

sub delay_delayonevent_failedlogin_bug4020 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/delay.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/delay.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/delay.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/delay.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/delay.group");

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

  my $failed_delay_secs = 2;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'delay:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayTable => 'none',
        DelayOnEvent => 'FailedLogin 2000',
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

      my $start = [gettimeofday()];        
      eval { $client->login($user, 'foobar') };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }
      my $elapsed = tv_interval($start);

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Elapsed login time: $elapsed secs\n";
      }

      if ($elapsed < $failed_delay_secs) {
        die("Expected at least $failed_delay_secs sec delay, got $elapsed");
      }

      $start = [gettimeofday()];
      $client->login($user, $passwd);
      $elapsed = tv_interval($start);

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Elapsed login time: $elapsed secs\n";
      }

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

sub delay_delayonevent_user_pass_bug4020 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/delay.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/delay.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/delay.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/delay.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/delay.group");

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

  my $login_delay_secs = 4;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'delay:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => [
        'DelayTable none',
        'DelayOnEvent USER 2sec',
        'DelayOnEvent PASS 2sec',
      ],
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

      my $start = [gettimeofday()];        
      $client->login($user, $passwd);
      my $elapsed = tv_interval($start);

      $client->quit();

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Elapsed login time: $elapsed secs\n";
      }

      if ($elapsed < $login_delay_secs) {
        die("Expected at least $login_delay_secs sec delay, got $elapsed");
      }
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

1;
