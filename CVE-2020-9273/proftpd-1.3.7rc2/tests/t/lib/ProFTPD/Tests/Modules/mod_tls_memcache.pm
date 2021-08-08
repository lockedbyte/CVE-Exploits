package ProFTPD::Tests::Modules::mod_tls_memcache;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use Cache::Memcached;
use Carp;
use File::Spec;
use IO::Handle;
use IPC::Open3;
use Socket;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  tls_sess_cache_memcache => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_sess_cache_memcache_json_bug4057 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_stapling_on_memcache_bug4175 => {
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
  $memcached_servers = [split(/,?\s+?/, $memcached_servers)];

  my $mc = Cache::Memcached->new({
    servers => $memcached_servers,
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

sub tls_sess_cache_memcache {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'tls_memcache');

  my $memcached_servers = $ENV{MEMCACHED_SERVERS} ? $ENV{MEMCACHED_SERVERS} : '127.0.0.1:11211';

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $sessid_file = File::Spec->rel2abs("$tmpdir/sessid.pem");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'tls:20 memcache:30 tls.memcache:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_memcache.c' => {
        MemcacheEngine => 'on',
        MemcacheLog => $setup->{log_file},
        MemcacheServers => $memcached_servers,
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $setup->{log_file},
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSVerifyClient => 'off',
        TLSOptions => 'EnableDiags',
      },

      'mod_tls_memcache.c' => {
        TLSSessionCache => 'memcache:',
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
      # Give the server a chance to start up
      sleep(2);

      # To test SSL session resumption, we use the command-line
      # openssl s_client tool, rather than any Perl module.

      # XXX Some OpenSSL versions' of s_client do not support the 'ftp'
      # parameter for -starttls; in this case, point the openssl binary
      # to be used to a version which does support this.
#      my $openssl = 'openssl';
my $openssl = '/Users/tj/local/openssl-1.0.2d/bin/openssl';

      my @cmd = (
        $openssl,
        's_client',
        '-connect',
        "127.0.0.1:$port",
        '-starttls',
        'ftp',
        '-sess_out',
        $sessid_file,
      );

      my $tls_rh = IO::Handle->new();
      my $tls_wh = IO::Handle->new();
      my $tls_eh = IO::Handle->new();

      $tls_wh->autoflush(1);

      local $SIG{CHLD} = 'DEFAULT';

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Executing: ", join(' ', @cmd), "\n";
      }

      my $tls_pid = open3($tls_wh, $tls_rh, $tls_eh, @cmd);
      print $tls_wh "QUIT\r\n";
      waitpid($tls_pid, 0);

      my ($res, $cipher_str, $err_str, $out_str);
      if ($? >> 8) {
        $err_str = join('', <$tls_eh>);
        $res = 0;

      } else {
        my $output = [<$tls_rh>];

        # Specifically look for the line containing 'Cipher is'
        foreach my $line (@$output) {
          if ($line =~ /Cipher is/) {
            $cipher_str = $line;
            chomp($cipher_str);
          }
        }

        if ($ENV{TEST_VERBOSE}) {
          $out_str = join('', @$output);
          print STDERR "Stdout: $out_str\n";
        }

        if ($ENV{TEST_VERBOSE}) {
          $err_str = join('', <$tls_eh>);
          print STDERR "Stderr: $err_str\n";
        }

        $res = 1;
      }

      unless ($res) {
        die("Can't talk to server: $err_str");
      }

      my $expected = '^New';
      $self->assert(qr/$expected/, $cipher_str,
        test_msg("Expected '$expected', got '$cipher_str'"));

      @cmd = (
        $openssl,
        's_client',
        '-connect',
        "127.0.0.1:$port",
        '-starttls',
        'ftp',
        '-sess_in',
        $sessid_file,
      );

      $tls_rh = IO::Handle->new();
      $tls_wh = IO::Handle->new();
      $tls_eh = IO::Handle->new();

      $tls_wh->autoflush(1);

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Executing: ", join(' ', @cmd), "\n";
      }

      $tls_pid = open3($tls_wh, $tls_rh, $tls_eh, @cmd);
      print $tls_wh "QUIT\r\n";
      waitpid($tls_pid, 0);

      $res = 0;
      $cipher_str = undef;
      $err_str = undef;
      $out_str = undef;

      if ($? >> 8) {
        $err_str = join('', <$tls_eh>);
        $res = 0;

      } else {
        my $output = [<$tls_rh>];

        # Specifically look for the line containing 'Cipher is'
        foreach my $line (@$output) {
          if ($line =~ /Cipher is/) {
            $cipher_str = $line;
            chomp($cipher_str);
          }
        }

        if ($ENV{TEST_VERBOSE}) {
          $out_str = join('', @$output);
          print STDERR "Stdout: $out_str\n";
        }

        if ($ENV{TEST_VERBOSE}) {
          $err_str = join('', <$tls_eh>);
          print STDERR "Stderr: $err_str\n";
        }

        $res = 1;
      }

      unless ($res) {
        die("Can't talk to server: $err_str");
      }

      $expected = '^Reused';
      $self->assert(qr/$expected/, $cipher_str,
        test_msg("Expected '$expected', got '$cipher_str'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, 45) };
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

sub tls_sess_cache_memcache_json_bug4057 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'tls_memcache');

  my $memcached_servers = $ENV{MEMCACHED_SERVERS} ? $ENV{MEMCACHED_SERVERS} : '127.0.0.1:11211';

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $sessid_file = File::Spec->rel2abs("$tmpdir/sessid.pem");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'tls:20 memcache:30 tls.memcache:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_memcache.c' => {
        MemcacheEngine => 'on',
        MemcacheLog => $setup->{log_file},
        MemcacheServers => $memcached_servers,
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $setup->{log_file},
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSVerifyClient => 'off',
        TLSOptions => 'EnableDiags',
      },

      'mod_tls_memcache.c' => {
        TLSSessionCache => 'memcache:/json',
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
      # Give the server a chance to start up
      sleep(2);

      # To test SSL session resumption, we use the command-line
      # openssl s_client tool, rather than any Perl module.

      # XXX Some OpenSSL versions' of s_client do not support the 'ftp'
      # parameter for -starttls; in this case, point the openssl binary
      # to be used to a version which does support this.
#      my $openssl = 'openssl';
my $openssl = '/Users/tj/local/openssl-1.0.2d/bin/openssl';

      my @cmd = (
        $openssl,
        's_client',
        '-connect',
        "127.0.0.1:$port",
        '-starttls',
        'ftp',
        '-sess_out',
        $sessid_file, 
      );

      my $tls_rh = IO::Handle->new();
      my $tls_wh = IO::Handle->new();
      my $tls_eh = IO::Handle->new();

      $tls_wh->autoflush(1);

      local $SIG{CHLD} = 'DEFAULT';

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Executing: ", join(' ', @cmd), "\n";
      }

      my $tls_pid = open3($tls_wh, $tls_rh, $tls_eh, @cmd);
      print $tls_wh "QUIT\r\n";
      waitpid($tls_pid, 0);

      my ($res, $cipher_str, $err_str, $out_str);
      if ($? >> 8) {
        $err_str = join('', <$tls_eh>);
        $res = 0;

      } else {
        my $output = [<$tls_rh>];

        # Specifically look for the line containing 'Cipher is'
        foreach my $line (@$output) {
          if ($line =~ /Cipher is/) {
            $cipher_str = $line;
            chomp($cipher_str);
          }
        }

        if ($ENV{TEST_VERBOSE}) {
          $out_str = join('', @$output);
          print STDERR "Stdout: $out_str\n";
        }

        if ($ENV{TEST_VERBOSE}) {
          $err_str = join('', <$tls_eh>);
          print STDERR "Stderr: $err_str\n";
        }

        $res = 1;
      }

      unless ($res) {
        die("Can't talk to server: $err_str");
      }

      my $expected = '^New';
      $self->assert(qr/$expected/, $cipher_str,
        test_msg("Expected '$expected', got '$cipher_str'"));

      @cmd = (
        $openssl,
        's_client',
        '-connect',
        "127.0.0.1:$port",
        '-starttls',
        'ftp',
        '-sess_in',
        $sessid_file, 
      );

      $tls_rh = IO::Handle->new();
      $tls_wh = IO::Handle->new();
      $tls_eh = IO::Handle->new();

      $tls_wh->autoflush(1);

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Executing: ", join(' ', @cmd), "\n";
      }

      $tls_pid = open3($tls_wh, $tls_rh, $tls_eh, @cmd);
      print $tls_wh "QUIT\r\n";
      waitpid($tls_pid, 0);

      $res = 0;
      $cipher_str = undef;
      $err_str = undef;
      $out_str = undef;

      if ($? >> 8) {
        $err_str = join('', <$tls_eh>);
        $res = 0;

      } else {
        my $output = [<$tls_rh>];

        # Specifically look for the line containing 'Cipher is'
        foreach my $line (@$output) {
          if ($line =~ /Cipher is/) {
            $cipher_str = $line;
            chomp($cipher_str);
          }
        }

        if ($ENV{TEST_VERBOSE}) {
          $out_str = join('', @$output);
          print STDERR "Stdout: $out_str\n";
        }

        if ($ENV{TEST_VERBOSE}) {
          $err_str = join('', <$tls_eh>);
          print STDERR "Stderr: $err_str\n";
        }

        $res = 1;
      }

      unless ($res) {
        die("Can't talk to server: $err_str");
      }

      $expected = '^Reused';
      $self->assert(qr/$expected/, $cipher_str,
        test_msg("Expected '$expected', got '$cipher_str'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, 45) };
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

sub tls_stapling_on_memcache_bug4175 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'tls_memcache');

  my $memcached_servers = $ENV{MEMCACHED_SERVERS} ? $ENV{MEMCACHED_SERVERS} : '127.0.0.1:11211';

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'tls:20 tls.memcache:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_memcache.c' => {
        MemcacheEngine => 'on',
        MemcacheLog => $setup->{log_file},
        MemcacheServers => $memcached_servers,
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
        TLSStaplingCache => "memcache:/",
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
