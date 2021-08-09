package ProFTPD::Tests::Config::MaxTransfersPerUser;

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
  maxtransfersperuser_retr => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  maxtransfersperuser_retr_custom_message => {
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

sub maxtransfersperuser_retr {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'config');

  my $test_file = File::Spec->rel2abs($setup->{config_file});
  my $max_transfers = 1;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file}, 
    MaxTransfersPerUser => "RETR $max_transfers",

    IfModules => {
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
      # First client should be able to connect and log in...
      my $client1 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client1->login($setup->{user}, $setup->{passwd});
      my $conn1 = $client1->retr_raw($test_file);
      unless ($conn1) {
        die("RETR failed: " . $client1->response_code() . " " .
          $client1->response_msg());
      }

      my $client2 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client2->login($setup->{user}, $setup->{passwd});
      my $conn2 = $client2->retr_raw($test_file);
      if ($conn2) {
        die("RETR succeeded unexpectedly");
      }

      my $resp_code = $client2->response_code();
      my $resp_msg = $client2->response_msg();

      my $expected;

      $expected = 451;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Sorry, the maximum number of data transfers ($max_transfers) from this user are currently being used.";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      $client1->quit();
      $client2->quit();
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

sub maxtransfersperuser_retr_custom_message {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'config');

  my $test_file = File::Spec->rel2abs($setup->{config_file});
  my $max_transfers = 1;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file}, 
    MaxTransfersPerUser => "RETR $max_transfers \"Too many transfers from your user\"",

    IfModules => {
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
      # First client should be able to connect and log in...
      my $client1 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client1->login($setup->{user}, $setup->{passwd});
      my $conn1 = $client1->retr_raw($test_file);
      unless ($conn1) {
        die("RETR failed: " . $client1->response_code() . " " .
          $client1->response_msg());
      }

      my $client2 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client2->login($setup->{user}, $setup->{passwd});
      my $conn2 = $client2->retr_raw($test_file);
      if ($conn2) {
        die("RETR succeeded unexpectedly");
      }

      my $resp_code = $client2->response_code();
      my $resp_msg = $client2->response_msg();

      my $expected;

      $expected = 451;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'Too many transfers from your user';
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      $client1->quit();
      $client2->quit();
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
