package ProFTPD::Tests::Modules::mod_ban;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use Carp;
use File::Spec;
use IO::Handle;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  ban_on_event_max_login_attempts => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ban_message => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ban_ifclass_engine_on => {
    order => ++$order,
    test_class => [qw(forking mod_ifsession)],
  },

  ban_ifclass_engine_off => {
    order => ++$order,
    test_class => [qw(forking mod_ifsession)],
  },

  ban_max_logins_exceeded_bug3281 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  ban_timeout_login_exceeded_bug3281 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  ban_engine_vhost_bug3355 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  ban_unhandled_cmd => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ban_on_event_client_connect_rate => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ban_sighup_bug3751 => {
    order => ++$order,
    test_class => [qw(bug forking os_linux)],
  },

  ban_on_event_tlshandshake => {
    order => ++$order,
    test_class => [qw(forking mod_tls)],
  },

  ban_on_event_rootlogin => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ban_on_event_rootlogin_userdefined => {
    order => ++$order,
    test_class => [qw(forking)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
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

sub ban_on_event_max_login_attempts {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ban.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ban.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ban.scoreboard");

  my $log_file = test_get_logfile();

  my $ban_tab = File::Spec->rel2abs("$tmpdir/ban.tab");

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/ban.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/ban.group");

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
    Trace => 'event:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    MaxLoginAttempts => 2,

    IfModules => {
      'mod_ban.c' => {
        BanEngine => 'on',
        BanLog => $log_file,

        # This says to ban a client which exceeds the MaxLoginAttempts
        # limit once within the last 1 minute will be banned for 5 secs
        BanOnEvent => 'MaxLoginAttempts 1/00:01:00 00:00:05',

        BanTable => $ban_tab,
      },

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

      eval { $client->login($user, 'foo') };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Login incorrect.";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      eval { $client->login($user, 'foo') };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Login incorrect.";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      # Now try again with the correct info; we should be banned.  Note
      # that we have to create a separate connection for this.

      eval { $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port,
        undef, 0) };
      unless ($@) {
        die("Connect succeeded unexpectedly");
      }

      my $conn_ex = ProFTPD::TestSuite::FTP::get_connect_exception();

      $expected = "";
      $self->assert($expected eq $conn_ex,
        test_msg("Expected '$expected', got '$conn_ex'"));
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

sub ban_message {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ban.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ban.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ban.scoreboard");

  my $log_file = test_get_logfile();

  my $ban_tab = File::Spec->rel2abs("$tmpdir/ban.tab");

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/ban.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/ban.group");

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

    MaxLoginAttempts => 2,

    IfModules => {
      'mod_ban.c' => {
        BanEngine => 'on',
        BanLog => $log_file,

        # This says to ban a client which exceeds the MaxLoginAttempts
        # limit once within the last 1 minute will be banned for 5 secs
        BanOnEvent => 'MaxLoginAttempts 1/00:01:00 00:00:05',

        BanTable => $ban_tab,

        BanMessage => '"Go away %a (%c), or I shall taunt you (%u) a second time!"',
      },

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

      eval { $client->login($user, 'foo') };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Login incorrect.";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      eval { $client->login($user, 'foo') };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Login incorrect.";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      # Now try again with the correct info; we should be banned.
      eval { $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port,
        undef, 0) };
      unless ($@) {
        die("Connect succeeded unexpectedly");
      }

      my $conn_ex = ProFTPD::TestSuite::FTP::get_connect_exception();
      
      $expected = "Go away 127.0.0.1 ((none)), or I shall taunt you ((none)) a second time!";
      $self->assert($expected eq $conn_ex,
        test_msg("Expected '$expected', got '$conn_ex'"));
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

sub ban_ifclass_engine_on {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ban.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ban.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ban.scoreboard");

  my $log_file = test_get_logfile();

  my $ban_tab = File::Spec->rel2abs("$tmpdir/ban.tab");

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/ban.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/ban.group");

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

    MaxLoginAttempts => 2,

    Class => {
      test => {
        From => '127.0.0.1',
      },
    },

    IfModules => {
      'mod_ban.c' => {
        BanLog => $log_file,

        # This says to ban a client which exceeds the MaxLoginAttempts
        # limit once within the last 1 minute will be banned for 5 secs
        BanOnEvent => 'MaxLoginAttempts 1/00:01:00 00:00:05',

        BanTable => $ban_tab,
      },

      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOI;
<IfClass test>
  BanEngine on
</IfClass>
EOI
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

      my ($resp_code, $resp_msg);

      eval { $client->login($user, 'foo') };
      unless ($@) {
        die("Login succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Login incorrect.";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      eval { $client->login($user, 'foo') };
      unless ($@) {
        die("Login succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Login incorrect.";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      # Now try again with the correct info; we should be banned.  Note
      # that we have to create a separate connection for this.

      eval { $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port,
        undef, 0) };
      unless ($@) {
        die("Connect succeeded unexpectedly");
      }

      my $conn_ex = ProFTPD::TestSuite::FTP::get_connect_exception();

      $expected = "";
      $self->assert($expected eq $conn_ex,
        test_msg("Expected '$expected', got '$conn_ex'"));
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

sub ban_ifclass_engine_off {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ban.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ban.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ban.scoreboard");

  my $log_file = test_get_logfile();

  my $ban_tab = File::Spec->rel2abs("$tmpdir/ban.tab");

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/ban.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/ban.group");

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

    MaxLoginAttempts => 1,

    Class => {
      test => {
        From => '127.0.0.1',
      },
    },

    IfModules => {
      'mod_ban.c' => {
        BanEngine => 'on',
        BanLog => $log_file,

        # This says to ban a client which exceeds the MaxLoginAttempts
        # limit once within the last 1 minute will be banned for 5 secs
        BanOnEvent => 'MaxLoginAttempts 1/00:01:00 00:00:05',

        BanTable => $ban_tab,
      },

      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOI;
<IfClass test>
  BanEngine off
</IfClass>
EOI
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

      my ($resp_code, $resp_msg);

      eval { $client->login($user, 'foo') };
      unless ($@) {
        die("Login succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Login incorrect.";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      # Now try again with the correct info; we should NOT be banned.  Note
      # that we have to create a separate connection for this.

      eval { $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port,
        undef, 0) };
      if ($@) {
        die("Connect failed unexpectedly");
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

sub ban_max_logins_exceeded_bug3281 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ban.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ban.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ban.scoreboard");

  my $log_file = test_get_logfile();

  my $ban_tab = File::Spec->rel2abs("$tmpdir/ban.tab");

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/ban.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/ban.group");

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
    Trace => 'lock:10 scoreboard:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    MaxLoginAttempts => 2,

    IfModules => {
      'mod_ban.c' => {
        BanEngine => 'on',
        BanLog => $log_file,

        # This says to ban a client which exceeds the MaxLoginAttempts
        # limit once within the last 1 minute will be banned for 5 secs
        BanOnEvent => 'MaxLoginAttempts 1/00:01:00 00:00:05',

        BanTable => $ban_tab,
      },

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

      my ($resp_code, $resp_msg);

      eval { $client->login($user, 'foo') };
      unless ($@) {
        die("Login succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Login incorrect.";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      # Try the login again
      eval { $client->login($user, 'foo') };
      unless ($@) {
        die("Login succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Login incorrect.";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      # According to Bug#3281, the session process should be have closed/ended.
      # Make sure this is the case.  This QUIT command should fail.
      eval { $client->quit() };
      unless ($@) {
        die("QUIT succeeded unexpectedly");
      }

      # Now try again with the correct info; we should be banned.  Note
      # that we have to create a separate connection for this.

      eval { $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port,
        undef, 0) };
      unless ($@) {
        die("Connect succeeded unexpectedly");
      }

      my $conn_ex = ProFTPD::TestSuite::FTP::get_connect_exception();

      $expected = "";
      $self->assert($expected eq $conn_ex,
        test_msg("Expected '$expected', got '$conn_ex'"));
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

sub ban_timeout_login_exceeded_bug3281 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ban.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ban.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ban.scoreboard");

  my $log_file = test_get_logfile();

  my $ban_tab = File::Spec->rel2abs("$tmpdir/ban.tab");

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/ban.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/ban.group");

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

  my $timeout_login = 1;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'event:10 lock:10 scoreboard:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    TimeoutLogin => $timeout_login,

    IfModules => {
      'mod_ban.c' => {
        BanEngine => 'on',
        BanLog => $log_file,

        # This says to ban a client which exceeds the TimeoutLogin
        # limit once within the last 1 minute will be banned for 5 secs
        BanOnEvent => 'TimeoutLogin 1/00:01:00 00:00:05',

        BanTable => $ban_tab,
      },

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

      my ($resp_code, $resp_msg);

      # Wait more than the TimeoutLogin interval
      sleep($timeout_login + 1);

      eval { $client->user($user) };
      unless ($@) {
        die("USER succeeded unexpectedly");
      }

      # According to Bug#3281, the session process should be have closed/ended.
      # Make sure this is the case.  This QUIT command should fail.
      eval { $client->quit() };
      unless ($@) {
        die("QUIT succeeded unexpectedly");
      }

      # Connect again, and again let the TimeoutLogin be exceed.
      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # Wait more than the TimeoutLogin interval
      sleep($timeout_login + 1);

      eval { $client->user($user) };
      unless ($@) {
        die("USER succeeded unexpectedly");
      }

      # According to Bug#3281, the session process should be have closed/ended.
      # Make sure this is the case.  This QUIT command should fail.
      eval { $client->quit() };
      unless ($@) {
        die("QUIT succeeded unexpectedly");
      }

      # Now try to connect; we should be banned.
      eval { $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port,
        undef, 0) };
      unless ($@) {
        die("Connect succeeded unexpectedly");
      }

      my $conn_ex = ProFTPD::TestSuite::FTP::get_connect_exception();

      my $expected = "";
      $self->assert($expected eq $conn_ex,
        test_msg("Expected '$expected', got '$conn_ex'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, 15) };
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

sub ban_engine_vhost_bug3355 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ban.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ban.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ban.scoreboard");

  my $log_file = test_get_logfile();

  my $ban_tab = File::Spec->rel2abs("$tmpdir/ban.tab");

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/ban.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/ban.group");

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

  my $max_login_attempts = 2;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'event:10',
    DefaultServer => 'off',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    MaxLoginAttempts => $max_login_attempts,

    IfModules => {
      'mod_ban.c' => {
        BanLog => $log_file,

        # This says to ban a client which exceeds the MaxLoginAttempts
        # limit once within the last 1 minute will be banned for 5 secs
        BanOnEvent => 'MaxLoginAttempts 1/00:01:00 00:00:05',

        BanTable => $ban_tab,
      },

      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);
  my $vhost_port = $port + 21;
 
  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<VirtualHost 127.0.0.1>
  Port $vhost_port
  AuthUserFile $auth_user_file
  AuthGroupFile $auth_group_file
  MaxLoginAttempts $max_login_attempts
  <IfModule mod_ban.c>
    BanEngine off
  </IfModule>
</VirtualHost>
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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $vhost_port);

      my ($resp_code, $resp_msg);

      eval { $client->login($user, 'foo') };
      unless ($@) {
        die("Login succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Login incorrect.";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      eval { $client->login($user, 'foo') };
      unless ($@) {
        die("Login succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Login incorrect.";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      # Now try again with the correct info; we should be banned, except
      # that we are connecting to the <VirtualHost> which has mod_ban disabled.
      # Note that we have to create a separate connection for this.

      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $vhost_port);
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

sub ban_unhandled_cmd {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ban.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ban.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ban.scoreboard");

  my $log_file = test_get_logfile();

  my $ban_tab = File::Spec->rel2abs("$tmpdir/ban.tab");

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/ban.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/ban.group");

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
    Trace => 'event:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    MaxLoginAttempts => 1,

    IfModules => {
      'mod_ban.c' => {
        BanEngine => 'on',
        BanLog => $log_file,

        # This says to ban a client which sends unhandled commands
        # three times within the last 1 minute will be banned for 5 secs
        BanOnEvent => 'UnhandledCommand 3/00:01:00 00:00:05',

        BanTable => $ban_tab,
      },

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

      eval { $client->quote('FOO') };
      unless ($@) {
          die("FOO command succeeded unexpectedly");
      }
   
      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
 
      my $expected;

      $expected = 500;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "FOO not understood";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      eval { $client->quote('BAR') };
      unless ($@) {
          die("BAR command succeeded unexpectedly");
      }
   
      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
 
      $expected = 500;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "BAR not understood";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      # The mod_ban rule will kick in as part of handling this command, so
      # this command shouldn't even get a response (which Net::FTP indicates
      # with a response code of "000").

      eval { $client->quote('BAZ') };
      unless ($@) {
          die("BAZ command succeeded unexpectedly");
      }
   
      $resp_code = $client->response_code();
 
      $expected = 000;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      eval { $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port,
        undef, 0) };
      unless ($@) {
        die("Connect succeeded unexpectedly");
      }

      my $conn_ex = ProFTPD::TestSuite::FTP::get_connect_exception();

      $expected = "";
      $self->assert($expected eq $conn_ex,
        test_msg("Expected '$expected', got '$conn_ex'"));
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

sub ban_on_event_client_connect_rate {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ban.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ban.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ban.scoreboard");

  my $log_file = test_get_logfile();

  my $ban_tab = File::Spec->rel2abs("$tmpdir/ban.tab");

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/ban.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/ban.group");

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
    Trace => 'event:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_ban.c' => {
        BanEngine => 'on',
        BanLog => $log_file,

        # This says to ban a client which connects more than twice in the
        # last 1 minute will be banned for 5 secs
        BanOnEvent => 'ClientConnectRate 2/00:01:00 00:00:05',

        BanTable => $ban_tab,
      },

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

      eval { $client->login($user, 'foo') };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Login incorrect.";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      eval { $client->login($user, 'foo') };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Login incorrect.";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      # Now try again with the correct info; we should be banned.  Note
      # that we have to create a separate connection for this.

      eval { $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port,
        undef, 0) };
      unless ($@) {
        die("Connect succeeded unexpectedly");
      }

      my $conn_ex = ProFTPD::TestSuite::FTP::get_connect_exception();

      $expected = "";
      $self->assert($expected eq $conn_ex,
        test_msg("Expected '$expected', got '$conn_ex'"));
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

sub ban_sighup_bug3751 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ban.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ban.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ban.scoreboard");

  my $log_file = test_get_logfile();

  my $ban_tab = File::Spec->rel2abs("$tmpdir/ban.tab");

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/ban.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/ban.group");

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
    Trace => 'event:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    MaxLoginAttempts => 2,

    IfModules => {
      'mod_ban.c' => {
        BanEngine => 'on',
        BanLog => $log_file,

        # This says to ban a client which exceeds the MaxLoginAttempts
        # limit once within the last 1 minute will be banned for 5 secs
        BanOnEvent => 'MaxLoginAttempts 1/00:01:00 00:00:05',

        BanTable => $ban_tab,
      },

      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Start the server
  server_start($config_file);
  sleep(1);

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

  # Stop server
  server_stop($pid_file);
  unlink($log_file);
}

sub ban_on_event_tlshandshake {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ban.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ban.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ban.scoreboard");

  my $log_file = test_get_logfile();

  my $ban_tab = File::Spec->rel2abs("$tmpdir/ban.tab");

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/ban.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/ban.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'event:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_ban.c' => {
        BanEngine => 'on',
        BanLog => $log_file,

        # This says to ban a client which requests TLS handshakes (control
        # connection) more than twice in the last 1 minute will be banned for
        # 5 secs
        BanOnEvent => 'TLSHandshake 2/00:01:00 00:00:05',

        BanTable => $ban_tab,
      },

      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client_opts = {
        Encryption => 'E',
        Port => $port,
      };

      if ($ENV{TEST_VERBOSE}) {
        $client_opts->{Debug} = 1;
      }

      my $client = Net::FTPSSL->new('127.0.0.1', $client_opts);
      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      $client->quit();

      # Now try again; we should be banned.  Note that we have to create a
      # separate connection for this.

      $client = Net::FTPSSL->new('127.0.0.1', $client_opts);
      if ($client) {
        die("Client successfully connected to FTPS unexpectedly");
      }

      my $errstr = IO::Socket::SSL::errstr();
      my $expected = 'connect attempt failed';
      $self->assert(qr/$expected/, $errstr,
        test_msg("Expected error message '$expected', got '$errstr'"));
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

sub ban_on_event_rootlogin {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ban.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ban.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ban.scoreboard");

  my $log_file = test_get_logfile();

  my $ban_tab = File::Spec->rel2abs("$tmpdir/ban.tab");

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/ban.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/ban.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $root_user = 'root';
  my $root_passwd = 'root';
  my $root_group = 'ftpd';
  my $root_home_dir = File::Spec->rel2abs($tmpdir);
  my $root_uid = 0;
  my $root_gid = 0;

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

  auth_user_write($auth_user_file, $root_user, $root_passwd, $root_uid,
    $root_gid, $root_home_dir, '/bin/bash');
  auth_group_write($auth_group_file, $root_group, $root_gid, $root_user);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'event:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    RootLogin => 'off',

    IfModules => {
      'mod_ban.c' => {
        BanEngine => 'on',
        BanLog => $log_file,

        # This says to ban a client which requests a root login more than twice
        # in the last 1 minute will be banned for 5 secs
        BanOnEvent => 'RootLogin 2/00:01:00 00:00:05',

        BanTable => $ban_tab,
      },

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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give server time to start up
      sleep(2);

      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      eval { $client->login($root_user, $root_passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Login incorrect.";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
      $client->quit();

      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->user($root_user);
      eval { $client->pass($root_passwd) };
      unless ($@) {
        die("PASS succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 000;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      # Now try again with the correct info; we should be banned.  Note
      # that we have to create a separate connection for this.
      eval { $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port,
        undef, 0) };
      unless ($@) {
        die("Connect succeeded unexpectedly");
      }

      my $conn_ex = ProFTPD::TestSuite::FTP::get_connect_exception();

      $expected = "";
      $self->assert($expected eq $conn_ex,
        test_msg("Expected '$expected', got '$conn_ex'"));
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

sub ban_on_event_rootlogin_userdefined {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ban.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ban.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ban.scoreboard");

  my $log_file = test_get_logfile();

  my $ban_tab = File::Spec->rel2abs("$tmpdir/ban.tab");

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/ban.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/ban.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $root_user = 'root';
  my $root_passwd = 'root';
  my $root_group = 'ftpd';
  my $root_home_dir = File::Spec->rel2abs($tmpdir);
  my $root_uid = 0;
  my $root_gid = 0;

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

  auth_user_write($auth_user_file, $root_user, $root_passwd, $root_uid,
    $root_gid, $root_home_dir, '/bin/bash');
  auth_group_write($auth_group_file, $root_group, $root_gid, $root_user);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'event:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    RootLogin => 'off',

    IfModules => {
      'mod_ban.c' => {
        BanEngine => 'on',
        BanLog => $log_file,

        # This says to ban a client which requests a root login more than twice
        # in the last 1 minute will be banned for 5 secs
        BanOnEvent => 'mod_auth.root-login 2/00:01:00 00:00:05',

        BanTable => $ban_tab,
      },

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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give server time to start up
      sleep(2);

      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      eval { $client->login($root_user, $root_passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Login incorrect.";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
      $client->quit();

      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->user($root_user);
      eval { $client->pass($root_passwd) };
      unless ($@) {
        die("PASS succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 000;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      # Now try again with the correct info; we should be banned.  Note
      # that we have to create a separate connection for this.
      eval { $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port,
        undef, 0) };
      unless ($@) {
        die("Connect succeeded unexpectedly");
      }

      my $conn_ex = ProFTPD::TestSuite::FTP::get_connect_exception();

      $expected = "";
      $self->assert($expected eq $conn_ex,
        test_msg("Expected '$expected', got '$conn_ex'"));
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
