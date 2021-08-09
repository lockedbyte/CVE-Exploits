package ProFTPD::Tests::Modules::mod_ban::memcache;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use Cache::Memcached;
use File::Spec;
use IO::Handle;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  ban_memcache_max_login_attempts => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ban_memcache_json_max_login_attempts_bug4056 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub set_up {
  my $self = shift;
  $self->SUPER::set_up(@_);

  # Clear the memcached servers before each unit test
  my $memcached_servers = $ENV{MEMCACHED_SERVERS} ? $ENV{MEMCACHED_SERVERS} : "127.0.0.1:11211";

  my $mc = Cache::Memcached->new({
    servers => [ $memcached_servers ],
    debug => 0,
  });

  # First, make sure that a memcached is running
  my $stats = $mc->stats('misc');
  unless ($stats) {
    die("Can't obtain stats from memached servers '$memcached_servers'");
  }

  $mc->flush_all();
  $mc->disconnect_all();
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub ban_memcache_max_login_attempts {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'ban');

  my $ban_tab = File::Spec->rel2abs("$tmpdir/ban.tab");
  my $memcached_servers = $ENV{MEMCACHED_SERVERS} ? $ENV{MEMCACHED_SERVERS} : '127.0.0.1:11211';

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'ban:20 memcache:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    MaxLoginAttempts => 1,

    IfModules => {
      'mod_ban.c' => {
        BanEngine => 'on',
        BanLog => $setup->{log_file},

        # This says to ban a client which exceeds the MaxLoginAttempts
        # limit once within the last 1 minute will be banned for 3 min
        BanOnEvent => 'MaxLoginAttempts 1/00:01:00 00:03:00',

        BanTable => $ban_tab,

        BanCache => 'memcache',
      },

      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_memcache.c' => {
        MemcacheEngine => 'on',
        MemcacheLog => $setup->{log_file},
        MemcacheServers => $memcached_servers,
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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      eval { $client->login($setup->{user}, 'foo') };
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

      eval { ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, undef, 0); };
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
    eval { server_wait($setup->{config_file}, $rfh) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  # Stop server
  server_stop($setup->{pid_file});

  $self->assert_child_ok($pid);

  if ($ex) {
    die($ex);
  }

  # Close the pipe, then re-open it for the second daemon
  close($rfh);
  close($wfh);

  unless (pipe($rfh, $wfh)) {
    die("Can't open pipe: $!");
  }

  # Fork child
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Now try again with the correct info; we should be banned.  Note
      # that we have to create a separate connection for this.

      # Give the server some time to start up.
      sleep(2);

      eval { ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, undef, 0); };
      unless ($@) {
        die("Connect succeeded unexpectedly");
      }

      my $conn_ex = ProFTPD::TestSuite::FTP::get_connect_exception();

      # If we see an exception of "Net::FTP: connect: Connection refused",
      # it means that the daemon hadn't even started up yet, which is not
      # the same as listening but rejecting our connection.

      my $expected = '';
      $self->assert($expected eq $conn_ex,
        test_msg("Expected '$expected', got '$conn_ex'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh) };
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

sub ban_memcache_json_max_login_attempts_bug4056 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'ban');

  my $ban_tab = File::Spec->rel2abs("$tmpdir/ban.tab");
  my $memcached_servers = $ENV{MEMCACHED_SERVERS} ? $ENV{MEMCACHED_SERVERS} : '127.0.0.1:11211';

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'ban:20 memcache:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    MaxLoginAttempts => 1,

    IfModules => {
      'mod_ban.c' => {
        BanEngine => 'on',
        BanLog => $setup->{log_file},

        # This says to ban a client which exceeds the MaxLoginAttempts
        # limit once within the last 1 minute will be banned for 3 min
        BanOnEvent => 'MaxLoginAttempts 1/00:01:00 00:03:00',

        BanTable => $ban_tab,

        BanCache => 'memcache',
        BanCacheOptions => 'UseJSON',
      },

      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_memcache.c' => {
        MemcacheEngine => 'on',
        MemcacheLog => $setup->{log_file},
        MemcacheServers => $memcached_servers,
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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      eval { $client->login($setup->{user}, 'foo') };
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

      eval { ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, undef, 0); };
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
    eval { server_wait($setup->{config_file}, $rfh) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  # Stop server
  server_stop($setup->{pid_file});

  $self->assert_child_ok($pid);

  if ($ex) {
    die($ex);
  }

  # Close the pipe, then re-open it for the second daemon
  close($rfh);
  close($wfh);

  unless (pipe($rfh, $wfh)) {
    die("Can't open pipe: $!");
  }

  # Fork child
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Now try again with the correct info; we should be banned.  Note
      # that we have to create a separate connection for this.

      # Give the server some time to start up.
      sleep(2);

      eval { ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, undef, 0); };
      unless ($@) {
        die("Connect succeeded unexpectedly");
      }

      my $conn_ex = ProFTPD::TestSuite::FTP::get_connect_exception();

      # If we see an exception of "Net::FTP: connect: Connection refused",
      # it means that the daemon hadn't even started up yet, which is not
      # the same as listening but rejecting our connection.

      my $expected = '';
      $self->assert($expected eq $conn_ex,
        test_msg("Expected '$expected', got '$conn_ex'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh) };
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
