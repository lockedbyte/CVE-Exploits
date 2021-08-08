package ProFTPD::Tests::SSH2;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use File::Spec;
use IO::Handle;
use Socket;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  ssh2_session => {
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

sub ssh2_session {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'ssh2');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

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
      sleep(1);

      my $client_opts = {
        PeerHost => '127.0.0.1',
        PeerPort => $port,
        Proto => 'tcp',
        Type => SOCK_STREAM,
        Timeout => 10
      };

      my $client = IO::Socket::INET->new(%$client_opts);
      unless ($client) {
        die("Can't connect to 127.0.0.1:$port: $!");
      }

      my $banner = <$client>;
      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Received banner: $banner";
      }

      my $req = "SSH-2.0-OpenSSH_5.6p1\r\n";
      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Sending request: $req";
      }
      $client->print($req);
      $client->flush(); 

      my $resp = <$client>;
      if ($ENV{TEST_VEROBSE}) {
        print STDERR "# Received response: $resp";
      }
      $client->close();

      chomp($resp);
      my $expected = '';
      $self->assert(qr/$expected/, $resp,
        test_msg("Expected response '$expected', got '$resp'"));
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
