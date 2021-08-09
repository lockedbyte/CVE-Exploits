package ProFTPD::Tests::Modules::mod_wrap2_redis;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use File::Spec;
use IO::Handle;
use IO::Socket::INET6;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :features :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  wrap2_allow_msg => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_deny_msg => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_engine => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_redis_allow_list => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_redis_allow_set => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_redis_allow_list_multi_rows_multi_entries => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  wrap2_redis_allow_list_all => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  wrap2_redis_deny_list_ip_addr => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_redis_deny_set_ip_addr => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_redis_deny_list_ipv4_netmask => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_redis_deny_list_ipv4mappedv6_netmask => {
    order => ++$order,
    test_class => [qw(bug feature_ipv6 forking)],
  },

  wrap2_redis_deny_list_ipv6_netmask_bug3606 => {
    order => ++$order,
    test_class => [qw(bug feature_ipv6 forking)],
  },

  wrap2_redis_deny_list_dns_name => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  # Note: requires local modification to /etc/hosts, to add
  # "familiar.castaglia.org" for 127.0.0.1.
  wrap2_redis_deny_list_dns_domain_bug3558 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  wrap2_redis_user_lists => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_redis_group_lists => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_bug3341 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  wrap2_redis_opt_check_on_connect_bug3508 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  wrap2_allow_msg_bug3538 => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_allow_msg_anon_bug3538 => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  wrap2_redis_deny_event_exec_bug3209 => {
    order => ++$order,
    test_class => [qw(forking mod_exec)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  # Check for the required Perl modules:
  #
  #  Redis

  my $required = [qw(
    Redis
  )];

  foreach my $req (@$required) {
    eval "use $req";
    if ($@) {
      print STDERR "\nWARNING:\n + Module '$req' not found, skipping all tests\n";

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Unable to load $req: $@\n";
      }

      return qw(testsuite_empty_test);
    }
  }

  return testsuite_get_runnable_tests($TESTS);
}

sub provision_redis {
  my $allowed_key = shift;
  my $allowed = shift;
  my $denied_key = shift;
  my $denied = shift;
  my $use_set = shift;
  $use_set = 0 unless defined($use_set);

  require Redis;
  my $redis = Redis->new(
    reconnect => 5,
    every => 250_000
  );

  $redis->del($allowed_key, $denied_key);

  if ($use_set) {
    if (scalar(@$allowed) > 0) {
      $redis->sadd($allowed_key, @$allowed);
    }

    if (scalar(@$denied) > 0) {
      $redis->sadd($denied_key, @$denied);
    }

  } else {
    if (scalar(@$allowed) > 0) {
      $redis->lpush($allowed_key, @$allowed);
    }

    if (scalar(@$denied) > 0) {
      $redis->lpush($denied_key, @$denied);
    }
  }

  $redis->quit();
  return 1;
}

sub wrap2_allow_msg {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'wrap2');

  # XXX Create allow, deny lists in Redis, and populate them
  my $timeout_idle = 30;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_redis.c' => {
        RedisEngine => 'on',
        RedisServer => '127.0.0.1:6379',
        RedisLog => $setup->{log_file},
      },

      'mod_wrap2_redis.c' => {
        WrapEngine => 'on',
        WrapAllowMsg => '"User %u allowed by access rules"',
        WrapTables => "redis:/get-allowed-clients redis:/get-denied-clients",
        WrapLog => $setup->{log_file},
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
      $client->login($setup->{user}, $setup->{passwd});

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg(0);
      $client->quit();

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "User $setup->{user} allowed by access rules";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 2) };
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

sub wrap2_deny_msg {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'wrap2');

  # Create allow, deny lists in Redis, and populate them
  my $allowed_key = 'ftpallow';
  my $denied_key = 'ftpdeny';
  provision_redis($allowed_key, [], $denied_key, [qw(ALL)]);

  my $timeout_idle = 30;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_redis.c' => {
        RedisEngine => 'on',
        RedisServer => '127.0.0.1:6379',
        RedisLog => $setup->{log_file},
      },

      'mod_wrap2_redis.c' => {
        WrapEngine => 'on',
        WrapDenyMsg => '"User %u rejected by access rules"',
        WrapTables => "redis:/list:$allowed_key redis:/list:$denied_key",
        WrapLog => $setup->{log_file},
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
      eval { $client->login($setup->{user}, $setup->{passwd}) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "User $setup->{user} rejected by access rules";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 2) };
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

sub wrap2_engine {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'wrap2');

  # Create allow, deny lists in Redis, and populate them
  my $allowed_key = 'ftpallow';
  my $denied_key = 'ftpdeny';
  provision_redis($allowed_key, [], $denied_key, [qw(ALL)]);

  my $timeout_idle = 30;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_redis.c' => {
        RedisEngine => 'on',
        RedisServer => '127.0.0.1:6379',
        RedisLog => $setup->{log_file},
      },

      'mod_wrap2_redis.c' => {
        WrapEngine => 'off',
        WrapAllowMsg => '"User %u allowed by access rules"',
        WrapDenyMsg => '"User %u rejected by access rules"',
        WrapTables => "redis:/list:$allowed_key redis:/list:$denied_key",
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
      my ($resp_code, $resp_msg) = $client->login($setup->{user},
        $setup->{passwd});
      $client->quit();

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "User $setup->{user} logged in";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 2) };
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

sub wrap2_redis_allow_list {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'wrap2');

  # Create allow, deny lists in Redis, and populate them
  my $allowed_key = 'ftpallow';
  my $denied_key = 'ftpdeny';
  provision_redis($allowed_key, [], $denied_key, []);

  my $timeout_idle = 30;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_redis.c' => {
        RedisEngine => 'on',
        RedisServer => '127.0.0.1:6379',
        RedisLog => $setup->{log_file},
      },

      'mod_wrap2_redis.c' => {
        WrapEngine => 'on',
        WrapTables => "redis:/list:$allowed_key redis:/list:$denied_key",
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
      my ($resp_code, $resp_msg) = $client->login($setup->{user},
        $setup->{passwd});
      $client->quit();

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "User $setup->{user} logged in";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 2) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  if ($ex) {
    # Stop server
    server_stop($setup->{pid_file});
    $self->assert_child_ok($pid);

    test_cleanup($setup->{log_file}, $ex);
  }

  provision_redis($allowed_key, [qw(127.0.0.1)], $denied_key, [qw(ALL)]);

  eval {
    my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
    my ($resp_code, $resp_msg) = $client->login($setup->{user},
      $setup->{passwd});
    $client->quit();

    my $expected;

    $expected = 230;
    $self->assert($expected == $resp_code,
      "Expected response code $expected, got $resp_code");

    $expected = "User $setup->{user} logged in";
    $self->assert($expected eq $resp_msg,
      "Expected response message '$expected', got '$resp_msg'");
  };
  if ($@) {
    $ex = $@;
  }

  # Stop server
  server_stop($setup->{pid_file});
  $self->assert_child_ok($pid);

  test_cleanup($setup->{log_file}, $ex);
}

sub wrap2_redis_allow_set {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'wrap2');

  # Create allow, deny lists in Redis, and populate them
  my $allowed_key = 'ftpallow';
  my $denied_key = 'ftpdeny';
  provision_redis($allowed_key, [], $denied_key, [], 1);

  my $timeout_idle = 30;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'redis:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_redis.c' => {
        RedisEngine => 'on',
        RedisServer => '127.0.0.1:6379',
        RedisLog => $setup->{log_file},
      },

      'mod_wrap2_redis.c' => {
        WrapEngine => 'on',
        WrapTables => "redis:/set:$allowed_key redis:/set:$denied_key",
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
      my ($resp_code, $resp_msg) = $client->login($setup->{user},
        $setup->{passwd});
      $client->quit();

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "User $setup->{user} logged in";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 2) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  if ($ex) {
    # Stop server
    server_stop($setup->{pid_file});
    $self->assert_child_ok($pid);

    test_cleanup($setup->{log_file}, $ex);
    return;
  }

  provision_redis($allowed_key, [qw(127.0.0.1)], $denied_key, [qw(ALL)], 1);

  eval {
    my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
    my ($resp_code, $resp_msg) = $client->login($setup->{user},
      $setup->{passwd});
    $client->quit();

    my $expected;

    $expected = 230;
    $self->assert($expected == $resp_code,
      "Expected response code $expected, got $resp_code");

    $expected = "User $setup->{user} logged in";
    $self->assert($expected eq $resp_msg,
      "Expected response message '$expected', got '$resp_msg'");
  };
  if ($@) {
    $ex = $@;
  }

  # Stop server
  server_stop($setup->{pid_file});
  $self->assert_child_ok($pid);

  test_cleanup($setup->{log_file}, $ex);
}

sub wrap2_redis_allow_list_multi_rows_multi_entries {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'wrap2');

  # Create allow, deny lists in Redis, and populate them
  my $allowed_key = 'ftpallow';
  my $denied_key = 'ftpdeny';

  my $allowed = [
    '192.168.127.5, 192.168.127.6',
    '192.168.127.1 192.168.127.2 127.0.0.1',
    '192.168.127.3,192.168.127.4 127.0.0.1'
  ];
  provision_redis($allowed_key, $allowed, $denied_key, [qw(ALL)]);

  my $timeout_idle = 30;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_redis.c' => {
        RedisEngine => 'on',
        RedisServer => '127.0.0.1:6379',
        RedisLog => $setup->{log_file},
      },

      'mod_wrap2_redis.c' => {
        WrapEngine => 'on',
        WrapLog => $setup->{log_file},
        WrapTables => "redis:/list:$allowed_key redis:/list:$denied_key",
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
      my ($resp_code, $resp_msg) = $client->login($setup->{user},
        $setup->{passwd});
      $client->quit();

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "User $setup->{user} logged in";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 2) };
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

sub wrap2_redis_allow_list_all {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'wrap2');

  # Create allow, deny lists in Redis, and populate them
  my $allowed_key = 'ftpallow';
  my $denied_key = 'ftpdeny';
  provision_redis($allowed_key, [qw(ALL)], $denied_key, [qw(ALL)]);

  my $timeout_idle = 30;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'dns:10',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_redis.c' => {
        RedisEngine => 'on',
        RedisServer => '127.0.0.1:6379',
        RedisLog => $setup->{log_file},
      },

      'mod_wrap2_redis.c' => {
        WrapEngine => 'on',
        WrapTables => "redis:/list:$allowed_key redis:/list:$denied_key",
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
      my ($resp_code, $resp_msg) = $client->login($setup->{user},
        $setup->{passwd});
      $client->quit();

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "User $setup->{user} logged in";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 2) };
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

sub wrap2_redis_deny_list_ip_addr {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'wrap2');

  # Create allow, deny lists in Redis, and populate them
  my $allowed_key = 'ftpallow';
  my $denied_key = 'ftpdeny';
  provision_redis($allowed_key, [], $denied_key, [qw(ALL)]);

  my $timeout_idle = 30;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_redis.c' => {
        RedisEngine => 'on',
        RedisServer => '127.0.0.1:6379',
        RedisLog => $setup->{log_file},
      },

      'mod_wrap2_redis.c' => {
        WrapEngine => 'on',
        WrapTables => "redis:/list:$allowed_key redis:/list:$denied_key",
        WrapLog => $setup->{log_file},
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
      eval { $client->login($setup->{user}, $setup->{passwd}) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "Access denied";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 2) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  if ($ex) {
    # Stop server
    server_stop($setup->{pid_file});
    $self->assert_child_ok($pid);

    test_cleanup($setup->{log_file}, $ex);
    return;
  }

  provision_redis($allowed_key, [], $denied_key, [qw(127.0.0.1)]);

  eval {
    my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
    eval { $client->login($setup->{user}, $setup->{passwd}) };
    unless ($@) {
      die("Login succeeded unexpectedly");
    }

    my $resp_code = $client->response_code();
    my $resp_msg = $client->response_msg();

    my $expected;

    $expected = 530;
    $self->assert($expected == $resp_code,
      "Expected response code $expected, got $resp_code");

    $expected = "Access denied";
    $self->assert($expected eq $resp_msg,
      "Expected response message '$expected', got '$resp_msg'");
  };
  if ($@) {
    $ex = $@;
  }

  # Stop server
  server_stop($setup->{pid_file});
  $self->assert_child_ok($pid);

  test_cleanup($setup->{log_file}, $ex);
}

sub wrap2_redis_deny_set_ip_addr {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'wrap2');

  # Create allow, deny lists in Redis, and populate them
  my $allowed_key = 'ftpallow';
  my $denied_key = 'ftpdeny';
  provision_redis($allowed_key, [], $denied_key, [qw(ALL)], 1);

  my $timeout_idle = 30;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_redis.c' => {
        RedisEngine => 'on',
        RedisServer => '127.0.0.1:6379',
        RedisLog => $setup->{log_file},
      },

      'mod_wrap2_redis.c' => {
        WrapEngine => 'on',
        WrapTables => "redis:/set:$allowed_key redis:/set:$denied_key",
        WrapLog => $setup->{log_file},
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
      eval { $client->login($setup->{user}, $setup->{passwd}) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "Access denied";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 2) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  if ($ex) {
    # Stop server
    server_stop($setup->{pid_file});
    $self->assert_child_ok($pid);

    test_cleanup($setup->{log_file}, $ex);
    return;
  }

  provision_redis($allowed_key, [], $denied_key, [qw(127.0.0.1)], 1);

  eval {
    my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
    eval { $client->login($setup->{user}, $setup->{passwd}) };
    unless ($@) {
      die("Login succeeded unexpectedly");
    }

    my $resp_code = $client->response_code();
    my $resp_msg = $client->response_msg();

    my $expected;

    $expected = 530;
    $self->assert($expected == $resp_code,
      "Expected response code $expected, got $resp_code");

    $expected = "Access denied";
    $self->assert($expected eq $resp_msg,
      "Expected response message '$expected', got '$resp_msg'");
  };
  if ($@) {
    $ex = $@;
  }

  # Stop server
  server_stop($setup->{pid_file});
  $self->assert_child_ok($pid);

  test_cleanup($setup->{log_file}, $ex);
}

sub wrap2_redis_deny_list_ipv4_netmask {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'wrap2');

  # Create allow, deny lists in Redis, and populate them
  my $allowed_key = 'ftpallow';
  my $denied_key = 'ftpdeny';
  provision_redis($allowed_key, [], $denied_key, [qw(ALL)]);

  my $timeout_idle = 30;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_redis.c' => {
        RedisEngine => 'on',
        RedisServer => '127.0.0.1:6379',
        RedisLog => $setup->{log_file},
      },

      'mod_wrap2_redis.c' => {
        WrapEngine => 'on',
        WrapTables => "redis:/list:$allowed_key redis:/list:$denied_key",
        WrapLog => $setup->{log_file},
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
      eval { $client->login($setup->{user}, $setup->{passwd}) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "Access denied";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 2) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  if ($ex) {
    # Stop server
    server_stop($setup->{pid_file});
    $self->assert_child_ok($pid);

    test_cleanup($setup->{log_file}, $ex);
    return;
  }

  provision_redis($allowed_key, [], $denied_key, [qw(127.0.0.0/255.255.255.0)]);

  eval {
    my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
    eval { $client->login($setup->{user}, $setup->{passwd}) };
    unless ($@) {
      die("Login succeeded unexpectedly");
    }

    my $resp_code = $client->response_code();
    my $resp_msg = $client->response_msg();

    my $expected;

    $expected = 530;
    $self->assert($expected == $resp_code,
      "Expected response code $expected, got $resp_code");

    $expected = "Access denied";
    $self->assert($expected eq $resp_msg,
      "Expected response message '$expected', got '$resp_msg'");
   };

  if ($@) {
    $ex = $@;
  }

  # Stop server
  server_stop($setup->{pid_file});
  $self->assert_child_ok($pid);

  test_cleanup($setup->{log_file}, $ex);
}

sub wrap2_redis_deny_list_ipv4mappedv6_netmask {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'wrap2');

  # Create allow, deny lists in Redis, and populate them
  my $allowed_key = 'ftpallow';
  my $denied_key = 'ftpdeny';
  provision_redis($allowed_key, [], $denied_key, [qw(ALL)]);

  my $timeout_idle = 30;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutIdle => $timeout_idle,

    UseIPv6 => 'on',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_redis.c' => {
        RedisEngine => 'on',
        RedisServer => '127.0.0.1:6379',
        RedisLog => $setup->{log_file},
      },

      'mod_wrap2_redis.c' => {
        WrapEngine => 'on',
        WrapTables => "redis:/list:$allowed_key redis:/list:$denied_key",
        WrapLog => $setup->{log_file},
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
      eval { $client->login($setup->{user}, $setup->{passwd}) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "Access denied";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 2) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  if ($ex) {
    # Stop server
    server_stop($setup->{pid_file});
    $self->assert_child_ok($pid);

    test_cleanup($setup->{log_file}, $ex);
    return;
  }

  # Note: this does NOT actually test the handling of IPv4-mapped IPv6 ACLs;
  # the Net::FTP Perl module does not handle connecting to IPv6 addresses.
  provision_redis($allowed_key, [], $denied_key, ['ALL, [::ffff:127.0.0.1]/32']);

  eval {
    my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

    eval { $client->login($setup->{user}, $setup->{passwd}) };
    unless ($@) {
      die("Login succeeded unexpectedly");
    }

    my $resp_code = $client->response_code();
    my $resp_msg = $client->response_msg();

    my $expected;

    $expected = 530;
    $self->assert($expected == $resp_code,
      "Expected response code $expected, got $resp_code");

    $expected = "Access denied";
    $self->assert($expected eq $resp_msg,
      "Expected response message '$expected', got '$resp_msg'");
  };

  if ($@) {
    $ex = $@;
  }

  # Stop server
  server_stop($setup->{pid_file});
  $self->assert_child_ok($pid);

  test_cleanup($setup->{log_file}, $ex);
}

sub wrap2_redis_deny_list_ipv6_netmask_bug3606 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'wrap2');

  # Create allow, deny lists in Redis, and populate them
  my $allowed_key = 'ftpallow';
  my $denied_key = 'ftpdeny';
  provision_redis($allowed_key, [], $denied_key, [qw(ALL)]);

  my $timeout_idle = 30;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutIdle => $timeout_idle,

    DefaultAddress => '::1',
    UseIPv6 => 'on',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_redis.c' => {
        RedisEngine => 'on',
        RedisServer => '127.0.0.1:6379',
        RedisLog => $setup->{log_file},
      },

      'mod_wrap2_redis.c' => {
        WrapEngine => 'on',
        WrapTables => "redis:/list:$allowed_key redis:/list:$denied_key",
        WrapLog => $setup->{log_file},
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
      sleep(2);

      my $client = IO::Socket::INET6->new(
        PeerAddr => '::1',
        PeerPort => $port,
        Proto => 'tcp',
        Timeout => 5,
      );
      unless ($client) {
        die("Can't connect to ::1: $!");
      } 

      # Read the banner
      my $banner = <$client>;

      # Send the USER command
      my $cmd = "USER $setup->{user}\r\n";
      $client->print($cmd);
      $client->flush();

      # Read USER response
      my $resp = <$client>;

      my $expected = "331 Password required for $setup->{user}\r\n";
      $self->assert($expected eq $resp, "Expected '$expected', got '$resp'");
 
      # Send the PASS command
      $cmd = "PASS $setup->{passwd}\r\n";
      $client->print($cmd);
      $client->flush();

      # Read PASS response
      $resp = <$client>;

      $expected = "530 Access denied\r\n";
      $self->assert($expected eq $resp, "Expected '$expected', got '$resp'");
 
      $client->close();
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 2) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  if ($ex) {
    # Stop server
    server_stop($setup->{pid_file});
    $self->assert_child_ok($pid);

    test_cleanup($setup->{log_file}, $ex);
    return;
  }

  provision_redis($allowed_key, [], $denied_key, ['[::1]/32']);

  eval {
    sleep(2);

    my $client = IO::Socket::INET6->new(
      PeerAddr => '::1',
      PeerPort => $port,
      Proto => 'tcp',
      Timeout => 5,
    );
    unless ($client) {
      die("Can't connect to ::1: $!");
    } 

    # Read the banner
    my $banner = <$client>;

    # Send the USER command
    my $cmd = "USER $setup->{user}\r\n";
    $client->print($cmd);
    $client->flush();

    # Read USER response
    my $resp = <$client>;

    my $expected = "331 Password required for $setup->{user}\r\n";
    $self->assert($expected eq $resp, "Expected '$expected', got '$resp'");
 
    # Send the PASS command
    $cmd = "PASS $setup->{passwd}\r\n";
    $client->print($cmd);
    $client->flush();

    # Read PASS response
    $resp = <$client>;

    $expected = "530 Access denied\r\n";
    $self->assert($expected eq $resp, "Expected '$expected', got '$resp'");
 
    $client->close();
  };

  if ($@) {
    $ex = $@;
  }

  # Stop server
  server_stop($setup->{pid_file});
  $self->assert_child_ok($pid);

  test_cleanup($setup->{log_file}, $ex);
}

sub wrap2_redis_deny_list_dns_name {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'wrap2');

  # Create allow, deny lists in Redis, and populate them
  my $allowed_key = 'ftpallow';
  my $denied_key = 'ftpdeny';
  provision_redis($allowed_key, [], $denied_key, [qw(ALL)]);

  my $timeout_idle = 30;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutIdle => $timeout_idle,
    UseReverseDNS => 'on',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_redis.c' => {
        RedisEngine => 'on',
        RedisServer => '127.0.0.1:6379',
        RedisLog => $setup->{log_file},
      },

      'mod_wrap2_redis.c' => {
        WrapEngine => 'on',
        WrapTables => "redis:/list:$allowed_key redis:/list:$denied_key",
        WrapLog => $setup->{log_file},
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
      eval { $client->login($setup->{user}, $setup->{passwd}) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "Access denied";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 2) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  if ($ex) {
    # Stop server
    server_stop($setup->{pid_file});
    $self->assert_child_ok($pid);

    test_cleanup($setup->{log_file}, $ex);
    return;
  }

  provision_redis($allowed_key, [], $denied_key, [qw(localhost)]);

  eval {
    my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
    eval { $client->login($setup->{user}, $setup->{passwd}) };
    unless ($@) {
      die("Login succeeded unexpectedly");
    }

    my $resp_code = $client->response_code();
    my $resp_msg = $client->response_msg();

    my $expected;

    $expected = 530;
    $self->assert($expected == $resp_code,
      "Expected response code $expected, got $resp_code");

    $expected = "Access denied";
    $self->assert($expected eq $resp_msg,
      "Expected response message '$expected', got '$resp_msg'");
  };
  if ($@) {
    $ex = $@;
  }

  # Stop server
  server_stop($setup->{pid_file});
  $self->assert_child_ok($pid);

  test_cleanup($setup->{log_file}, $ex);
}

sub wrap2_redis_deny_list_dns_domain_bug3558 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'wrap2');

  # Create allow, deny lists in Redis, and populate them
  my $allowed_key = 'ftpallow';
  my $denied_key = 'ftpdeny';
  provision_redis($allowed_key, [], $denied_key, [qw(ALL)]);

  my $timeout_idle = 30;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'dns:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutIdle => $timeout_idle,

    UseReverseDNS => 'on',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_redis.c' => {
        RedisEngine => 'on',
        RedisServer => '127.0.0.1:6379',
        RedisLog => $setup->{log_file},
      },

      'mod_wrap2_redis.c' => {
        WrapEngine => 'on',
        WrapTables => "redis:/list:$allowed_key redis:/list:$denied_key",
        WrapLog => $setup->{log_file},
        WrapOptions => 'CheckAllNames',
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
      eval { $client->login($setup->{user}, $setup->{passwd}) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "Access denied";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");
    };
    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 2) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  if ($ex) {
    # Stop server
    server_stop($setup->{pid_file});
    $self->assert_child_ok($pid);

    test_cleanup($setup->{log_file}, $ex);
    return;
  }

  provision_redis($allowed_key, [], $denied_key, [qw(.castaglia.org)]);

  eval {
    my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
    eval { $client->login($setup->{user}, $setup->{passwd}) };
    unless ($@) {
      die("Login succeeded unexpectedly");
    }

    my $resp_code = $client->response_code();
    my $resp_msg = $client->response_msg();

    my $expected;

    $expected = 530;
    $self->assert($expected == $resp_code,
      "Expected response code $expected, got $resp_code");

    $expected = "Access denied";
    $self->assert($expected eq $resp_msg,
      "Expected response message '$expected', got '$resp_msg'");
  };
  if ($@) {
    $ex = $@;
  }

  # Stop server
  server_stop($setup->{pid_file});
  $self->assert_child_ok($pid);

  test_cleanup($setup->{log_file}, $ex);
}

sub wrap2_redis_user_lists {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'wrap2');

  # Create allow, deny lists in Redis, and populate them
  my $allowed_key = 'ftpallow';
  my $denied_key = "ftpdeny.$setup->{user}";
  provision_redis($allowed_key, [], $denied_key, [qw(ALL)]);
  $denied_key = 'ftpdeny.%{name}';

  my $timeout_idle = 30;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'redis:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_redis.c' => {
        RedisEngine => 'on',
        RedisServer => '127.0.0.1:6379',
        RedisLog => $setup->{log_file},
      },

      'mod_wrap2_redis.c' => {
        WrapEngine => 'on',
        WrapUserTables => "!$setup->{user} redis:/list:$allowed_key redis:/list:$denied_key",
        WrapLog => $setup->{log_file},
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
      my ($resp_code, $resp_msg) = $client->login($setup->{user},
        $setup->{passwd});
      $client->quit();

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "User $setup->{user} logged in";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");
    };
    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 2) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  # Stop server
  server_stop($setup->{pid_file});
  $self->assert_child_ok($pid);

  # Wait a little for the daemon to shutdown.
  sleep(1);

  if ($ex) {
    test_cleanup($setup->{log_file}, $ex);
    return;
  }

  # Modify the config a little
  $config->{IfModules}->{'mod_wrap2_redis.c'}->{WrapUserTables} = "$setup->{user} redis:/list:$allowed_key redis:/list:$denied_key";

  unlink($setup->{config_file});
  ($port, $config_user, $config_group) = config_write($setup->{config_file},
    $config);

  # Fork child
  $self->handle_sigchld();
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      eval { $client->login($setup->{user}, $setup->{passwd}) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "Access denied";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");
    };
    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 2) };
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

sub wrap2_redis_group_lists {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'wrap2');

  # Create allow, deny lists in Redis, and populate them
  my $allowed_key = 'ftpallow';
  my $denied_key = "ftpdeny.$setup->{group}";
  provision_redis($allowed_key, [], $denied_key, [qw(ALL)]);
  $denied_key = 'ftpdeny.%{name}';

  my $timeout_idle = 30;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'redis:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_redis.c' => {
        RedisEngine => 'on',
        RedisServer => '127.0.0.1:6379',
        RedisLog => $setup->{log_file},
      },

      'mod_wrap2_redis.c' => {
        WrapEngine => 'on',
        WrapGroupTables => "foo redis:/list:$allowed_key redis:/list:$denied_key",
        WrapLog => $setup->{log_file},
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
      my ($resp_code, $resp_msg) = $client->login($setup->{user},
        $setup->{passwd});
      $client->quit();

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "User $setup->{user} logged in";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");
    };
    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 2) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  # Stop server
  server_stop($setup->{pid_file});
  $self->assert_child_ok($pid);

  # Give the server time to shut down.
  sleep(1);

  if ($ex) {
    test_cleanup($setup->{log_file}, $ex);
    return;
  }

  # Modify the config a little
  $config->{IfModules}->{'mod_wrap2_redis.c'}->{WrapGroupTables} = "$setup->{group} redis:/list:$allowed_key redis:/list:$denied_key";

  unlink($setup->{config_file});
  ($port, $config_user, $config_group) = config_write($setup->{config_file},
    $config);

  # Fork child
  $self->handle_sigchld();
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      eval { $client->login($setup->{user}, $setup->{passwd}) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "Access denied";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");
    };
    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 2) };
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

sub wrap2_bug3341 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'wrap2');

  # Create allow, deny lists in Redis, and populate them
  my $allowed_key = 'ftpallow';
  my $denied_key = 'ftpdeny';

  my $allowed = ['192.168.0.1,192.168.0.2 192.168.0.3, 192.168.0.4 127.0.0.1'];
  provision_redis($allowed_key, $allowed, $denied_key, [qw(ALL)]);

  my $timeout_idle = 30;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_redis.c' => {
        RedisEngine => 'on',
        RedisServer => '127.0.0.1:6379',
        RedisLog => $setup->{log_file},
      },

      'mod_wrap2_redis.c' => {
        WrapEngine => 'on',
        WrapTables => "redis:/list:$allowed_key redis:/list:$denied_key",
        WrapLog => $setup->{log_file},
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

      # As per Bug#3341, we need to send a bad password twice.  The second
      # attempt triggered a segfault in mod_wrap2.
      eval { $client->login($setup->{user}, 'foo') };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg(); 

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "Login incorrect.";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");

      # Now try to login again
      eval { $client->login($setup->{user}, 'foo') };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg(); 

      $expected = 530;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "Login incorrect.";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");

      ($resp_code, $resp_msg) = $client->login($setup->{user},
        $setup->{passwd});

      $expected = 230;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "User $setup->{user} logged in";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");
    };
    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 2) };
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

sub wrap2_redis_opt_check_on_connect_bug3508 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'wrap2');

  # Create allow, deny lists in Redis, and populate them
  my $allowed_key = 'ftpallow';
  my $denied_key = 'ftpdeny';
  provision_redis($allowed_key, [], $denied_key, [qw(127.0.0.2)]);

  my $timeout_idle = 30;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_redis.c' => {
        RedisEngine => 'on',
        RedisServer => '127.0.0.1:6379',
        RedisLog => $setup->{log_file},
      },

      'mod_wrap2_redis.c' => {
        WrapEngine => 'on',
        WrapTables => "redis:/list:$allowed_key redis:/list:$denied_key",
        WrapLog => $setup->{log_file},
        WrapOptions => 'CheckOnConnect',
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
      my ($resp_code, $resp_msg) = $client->login($setup->{user},
        $setup->{passwd});

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "User $setup->{user} logged in";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");
    };
    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 2) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  if ($ex) {
    # Stop server
    server_stop($setup->{pid_file});
    $self->assert_child_ok($pid);

    test_cleanup($setup->{log_file}, $ex);
    return;
  }

  provision_redis($allowed_key, [], $denied_key, [qw(127.0.0.1)]);

  eval {
    my $client;

    eval {
      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, undef, 2);
    };
    unless ($@) {
      die("Connect succeeded unexpectedly");
    }

    my $ex = ProFTPD::TestSuite::FTP::get_connect_exception();

    my $expected = "Access denied";
    $self->assert($expected eq $ex, "Expected '$expected', got '$ex'");
  };
  if ($@) {
    $ex = $@;
  }

  # Stop server
  server_stop($setup->{pid_file});
  $self->assert_child_ok($pid);

  test_cleanup($setup->{log_file}, $ex);
}

sub wrap2_allow_msg_bug3538 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'wrap2');

  # Create allow, deny lists in Redis, and populate them
  my $allowed_key = 'ftpallow';
  my $denied_key = 'ftpdeny';
  provision_redis($allowed_key, [], $denied_key, []);

  my $timeout_idle = 30;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AccessGrantMsg => '"User %u logged in."',
    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_redis.c' => {
        RedisEngine => 'on',
        RedisServer => '127.0.0.1:6379',
        RedisLog => $setup->{log_file},
      },

      'mod_wrap2_redis.c' => {
        WrapEngine => 'on',
        WrapAllowMsg => '"User %u allowed by access rules"',
        WrapTables => "redis:/list:$allowed_key redis:/list:$denied_key",
        WrapLog => $setup->{log_file},
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
      $client->login($setup->{user}, $setup->{passwd});

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg(0);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "User $setup->{user} allowed by access rules";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");

      $resp_msg = $client->response_msg(1);

      $expected = "User $setup->{user} logged in.";
      $self->assert($expected eq $resp_msg,
        "Expected response meessage '$expected', got '$resp_msg'");

      $client->quit();
    };
    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 2) };
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

sub wrap2_allow_msg_anon_bug3538 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'wrap2');

  # Create allow, deny lists in Redis, and populate them
  my $allowed_key = 'ftpallow';
  my $denied_key = 'ftpdeny';
  provision_redis($allowed_key, [], $denied_key, []);

  my ($test_user, $test_group) = config_get_identity();
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs($tmpdir);

  my $timeout_idle = 30;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AccessGrantMsg => '"User %u logged in."',
    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutIdle => $timeout_idle,

    Anonymous => {
      $setup->{home_dir} => {
        User => $test_user,
        Group => $test_group,
        UserAlias => "anonymous $test_user", 
        RequireValidShell => 'off',
      },
    },

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_redis.c' => {
        RedisEngine => 'on',
        RedisServer => '127.0.0.1:6379',
        RedisLog => $setup->{log_file},
      },

      'mod_wrap2_redis.c' => {
        WrapEngine => 'on',
        WrapAllowMsg => '"User %u allowed by access rules"',
        WrapTables => "redis:/list:$allowed_key redis:/list:$denied_key",
        WrapLog => $setup->{log_file},
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
      $client->login('anonymous', 'ftp@nospam.org');

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg(0);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "User anonymous allowed by access rules";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");

      $resp_msg = $client->response_msg(1);

      $expected = "User anonymous logged in.";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");

      $client->quit();
    };
    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 2) };
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

sub wrap2_redis_deny_event_exec_bug3209 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'wrap2');

  # Create allow, deny lists in Redis, and populate them
  my $allowed_key = 'ftpallow';
  my $denied_key = 'ftpdeny';
  provision_redis($allowed_key, [], $denied_key, [qw(ALL)]);

  my $event_file = File::Spec->rel2abs("$tmpdir/denied-client.txt");
  my $spawn_script = File::Spec->rel2abs("$tmpdir/spawn.sh");
  if (open(my $fh, "> $spawn_script")) {
    print $fh <<EOS;
#!/bin/bash
echo \$\@ > $event_file
exit
EOS
    unless (close($fh)) {
      die("Can't write $spawn_script: $!");
    }

    unless (chmod(0777, $spawn_script)) {
      die("Can't set perms on $spawn_script to 0777: $!");
    }

  } else {
    die("Can't open $spawn_script: $!");
  }

  my $timeout_idle = 30;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'event:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_exec.c' => {
        ExecEngine => 'on',
        ExecLog => $setup->{log_file},
        ExecTimeout => 1,
        ExecOnEvent => "mod_wrap.connection-denied $spawn_script %a",
      },

      'mod_redis.c' => {
        RedisEngine => 'on',
        RedisServer => '127.0.0.1:6379',
        RedisLog => $setup->{log_file},
      },

      'mod_wrap2_redis.c' => {
        WrapEngine => 'on',
        WrapTables => "redis:/list:$allowed_key redis:/list:$denied_key",
        WrapLog => $setup->{log_file},
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
      eval { $client->login($setup->{user}, $setup->{passwd}) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "Access denied";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");

      if (open(my $fh, "< $event_file")) {
        my $line = <$fh>;
        chomp($line);
        close($fh);

        if ($ENV{TEST_VERBOSE}) {
          print STDOUT "# line: $line\n";
        }

        my $expected = '127.0.0.1';
        $self->assert($expected eq $line,
          "Expected line '$expected', got '$line'");

      } else {
        die("Can't read $event_file: $!");
      }
    };
    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 2) };
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
