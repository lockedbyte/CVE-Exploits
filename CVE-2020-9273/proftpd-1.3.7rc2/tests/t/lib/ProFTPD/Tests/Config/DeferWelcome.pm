package ProFTPD::Tests::Config::DeferWelcome;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use File::Spec;
use IO::Handle;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

# Need to document the interaction between DeferWelcome and ServerIdent
# somewhere; in the mod_core docs for DeferWelcome (need to be added)?
#
# Note: "DeferWelcome" is a really bad name/description for what this
# directive controls.  Given ServerIdent's capabilities, is DeferWelcome
# needed anymore?
#
# Specifically:
#   DeferWelcome only used in the following cases:
#     ServerIdent NOT configured OR
#     "ServerIdent on ..." configured
#
#  if "ServerIdent on" WITH string, then DeferWelcome is ignored (admin
#  configured what they want specifically in the greeting.
#
# So "DeferWelcome on/off", with "ServerIdent off", should have no effect.
#
# Where exactly does DeferWelcome help?  Answer: for the following config:
#
#   ServerIdent on
#
# Usually results in:
#
#   220 ProFTPD 1.3.5rc4 Server (ServerName) [1.2.3.4]
#
# But:
#
#   ServerIdent on
#   DeferWelcome on
#
# Results in:
#
#   220 ProFTPD 1.3.5rc4 Server ready.
#
# Exactly the same result can be done using just ServerIdent:
#
#  ServerIdent on "ProFTPD Server ready."
#
# Well, almost.  ServerIdent supports the %v variable for ServerName, but
# currently has no variable for version (e.g. %{version}) or server address.
# And %L really should reflect a MasquerAddress setting.

my $TESTS = {
  deferwelcome_off_serverident_off => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  deferwelcome_off_serverident_on => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  deferwelcome_on_serverident_off => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  deferwelcome_on_serverident_on => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  deferwelcome_on_serverident_on_custom => {
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

sub deferwelcome_off_serverident_off {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = test_get_logfile();

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    ServerIdent => 'off',
    DeferWelcome => 'off',

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

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;
      $expected = 220;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = '127.0.0.1 FTP server ready';
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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub deferwelcome_off_serverident_on {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = test_get_logfile();

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    ServerIdent => 'on',
    DeferWelcome => 'off',

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

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;
      $expected = 220;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'ProFTPD \S+ Server \(ProFTPD\) \[\S+\]';
      $self->assert(qr/$expected/, $resp_msg,
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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub deferwelcome_on_serverident_off {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = test_get_logfile();

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    ServerIdent => 'off',
    DeferWelcome => 'on',

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

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;
      $expected = 220;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = '127.0.0.1 FTP server ready';
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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub deferwelcome_on_serverident_on {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = test_get_logfile();

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    ServerIdent => 'on',
    DeferWelcome => 'on',

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

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;
      $expected = 220;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'ProFTPD \S+ Server ready\.';
      $self->assert(qr/$expected/, $resp_msg,
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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub deferwelcome_on_serverident_on_custom {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = test_get_logfile();

  my $banner = "Greetings, Stranger.  The Notworks are treacherous today.";

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    ServerIdent => "on \"$banner\"",
    DeferWelcome => 'on',

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

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;
      $expected = 220;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      # Even though we configured "DeferWelcome on", we expect the
      # customised ServerIdent banner to be displayed.

      $expected = $banner;
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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

1;
