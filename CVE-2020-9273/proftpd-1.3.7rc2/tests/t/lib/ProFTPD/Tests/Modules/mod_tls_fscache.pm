package ProFTPD::Tests::Modules::mod_tls_fscache;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use Carp;
use File::Copy;
use File::Path qw(mkpath);
use File::Spec;
use IO::Handle;
use Socket;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  tls_stapling_on_fscache_bug4175 => {
    order => ++$order,
    test_class => [qw(bug forking mod_tls_fscache)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  # Check for the required Perl modules:
  #
  #  Net-SSLeay
  #  IO-Socket-SSL
  #  Net-FTPSSL

  my $required = [qw(
    Net::SSLeay
    IO::Socket::SSL
    Net::FTPSSL
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

sub starttls_ftp {
  my $port = shift;
  my $ssl_opts = shift;

  my $client = IO::Socket::INET->new(
    PeerHost => '127.0.0.1',
    PeerPort => $port,
    Proto => 'tcp',
    Type => SOCK_STREAM,
    Timeout => 10
  );
  unless ($client) {
    croak("Can't connect to 127.0.0.1:$port: $!");
  }

  # Read the banner
  my $banner = <$client>;
  if ($ENV{TEST_VERBOSE}) {
    print STDOUT "# Received banner: $banner\n";
  }

  # Send the AUTH command
  my $cmd = "AUTH TLS\r\n";
  if ($ENV{TEST_VERBOSE}) {
    print STDOUT "# Sending command: $cmd";
  }

  $client->print($cmd);
  $client->flush();

  # Read the AUTH response
  my $resp = <$client>;
  if ($ENV{TEST_VERBOSE}) {
    print STDOUT "# Received response: $resp\n";
  }

  my $expected = "234 AUTH TLS successful\r\n";
  unless ($expected eq $resp) {
    croak("Expected response '$expected', got '$resp'");
  }

  # Now perform the SSL handshake
  if ($ENV{TEST_VERBOSE}) {
    $IO::Socket::SSL::DEBUG = 3;
  }

  my $res = IO::Socket::SSL->start_SSL($client, $ssl_opts);
  unless ($res) {
    croak("Failed SSL handshake: " . IO::Socket::SSL::errstr());
  }

  $cmd = "QUIT\r\n";
  if ($ENV{TEST_VERBOSE}) {
    print STDOUT "# Sending command: $cmd";
  }

  print $client $cmd;
  $client->flush();
  $client->close();
}

sub tls_stapling_on_fscache_bug4175 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'tls_fscache');

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $cache_tab = File::Spec->rel2abs("$tmpdir/var/tls/cache/ocsp");
  mkpath($cache_tab);

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'tls:20 tls.fscache:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $setup->{log_file},
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => 'EnableDiags',
        TLSStapling => 'on',
        TLSStaplingCache => "fs:/path=$cache_tab",
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

  require IO::Socket::INET;
  require IO::Socket::SSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      # Manually simulate the STARTTLS protocol

      my $ssl_opts = {
        SSL_ocsp_mode => IO::Socket::SSL::SSL_OCSP_TRY_STAPLE(),
        SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE(),
        SSL_alpn_protocols => [qw(ftp)],
      };

      starttls_ftp($port, $ssl_opts);

      my $delay = 5;
      if ($delay > 0) {
        if ($ENV{TEST_VERBOSE}) {
          print STDOUT "# Sleeping for $delay seconds\n";
        }

        sleep($delay);
      }

      # Do it again, see if we actually read our our cached OCSP response
      starttls_ftp($port, $ssl_opts);
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
