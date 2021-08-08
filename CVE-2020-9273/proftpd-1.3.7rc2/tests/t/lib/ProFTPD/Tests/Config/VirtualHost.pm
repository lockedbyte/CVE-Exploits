package ProFTPD::Tests::Config::VirtualHost;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use File::Spec;
use IO::Handle;
use IO::Socket::INET;
use Sys::Hostname;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  vhost_namebased_different_ports => {
    test_class => [qw(forking)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub vhost_namebased_different_ports {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'config');

  my $host = hostname();

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    ServerName => 'Real Server',
    SocketBindTight => 'off',
    DefaultServer => 'off',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($setup->{config_file},
    $config);

  my $vhost_port = $port + 3;
  my $vhost_name = 'Virtual Server';

  if (open(my $fh, ">> $setup->{config_file}")) {
    print $fh <<EOC;
<VirtualHost $host>
  Port $vhost_port
  ServerName "$vhost_name"

  WtmpLog off
  TransferLog none

  AuthUserFile $setup->{auth_user_file}
  AuthGroupFile $setup->{auth_group_file}
</VirtualHost>
EOC
    unless (close($fh)) {
      die("Can't write $setup->{config_file}: $!");
    }

  } else {
    die("Can't open $setup->{config_file}: $!");
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
      my $client = ProFTPD::TestSuite::FTP->new($host, $vhost_port, 0);
      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $client->login($setup->{user}, $setup->{passwd});
      $client->quit();

      $self->assert(qr/$vhost_name/, $resp_msg,
        "Expected '$vhost_name', got '$resp_msg'");
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
