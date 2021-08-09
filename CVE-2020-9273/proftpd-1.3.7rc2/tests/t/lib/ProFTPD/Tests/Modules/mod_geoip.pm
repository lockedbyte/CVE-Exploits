package ProFTPD::Tests::Modules::mod_geoip;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use File::Path qw(mkpath);
use File::Spec;
use IO::Handle;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  geoip_explicitly_allowed => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  geoip_multi_allow_bug4188 => {
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

sub geoip_explicitly_allowed {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'geoip');

  my $test_file = File::Spec->rel2abs($setup->{config_file});

  my $geoip_ip_table = File::Spec->rel2abs('t/etc/modules/mod_geoip/GeoIP.dat');
  my $geoip_ipv6_table = File::Spec->rel2abs('t/etc/modules/mod_geoip/GeoIPv6.dat');
  my $geoip_city_table = File::Spec->rel2abs('t/etc/modules/mod_geoip/GeoLiteCity.dat');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'geoip:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_geoip.c' => [
        'GeoIPEngine on',
        "GeoIPLog $setup->{log_file}",
        "GeoIPTable $geoip_ip_table",
        "GeoIPTable $geoip_ipv6_table",
        "GeoIPTable $geoip_city_table",

        'GeoIPPolicy allow,deny',
        'GeoIPAllowFilter RegionCode TX',
        'GeoIPDenyFilter CountryCode US',
      ],
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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 1);
      $client->quit();
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

sub geoip_multi_allow_bug4188 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'geoip');

  my $test_file = File::Spec->rel2abs($setup->{config_file});

  my $geoip_ip_table = File::Spec->rel2abs('t/etc/modules/mod_geoip/GeoIP.dat');
  my $geoip_ipv6_table = File::Spec->rel2abs('t/etc/modules/mod_geoip/GeoIPv6.dat');
  my $geoip_city_table = File::Spec->rel2abs('t/etc/modules/mod_geoip/GeoLiteCity.dat');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'geoip:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_geoip.c' => [
        'GeoIPEngine on',
        "GeoIPLog $setup->{log_file}",
        "GeoIPTable $geoip_ip_table",
        "GeoIPTable $geoip_ipv6_table",
        "GeoIPTable $geoip_city_table",

        'GeoIPPolicy deny,allow',
        'GeoIPAllowFilter RegionCode TX CountryCode US',
      ],
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
      $client->quit();
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
