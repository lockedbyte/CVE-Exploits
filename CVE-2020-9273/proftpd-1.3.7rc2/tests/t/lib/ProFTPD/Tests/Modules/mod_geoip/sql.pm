package ProFTPD::Tests::Modules::mod_geoip::sql;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use File::Path qw(mkpath);
use File::Spec;
use IO::Handle;
use POSIX qw(:fcntl_h);

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  geoip_sql_allow_filter => {
    order => ++$order,
    test_class => [qw(forking mod_sql_sqlite)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub set_up {
  my $self = shift;
  $self->SUPER::set_up(@_);
}

sub build_db {
  my $cmd = shift;
  my $db_script = shift;
  my $db_file = shift;
  my $check_exit_status = shift;
  $check_exit_status = 0 unless defined $check_exit_status;

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  my $exit_status = $?;

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  if ($check_exit_status) {
    if ($? != 0) {
      croak("'$cmd' failed");
    }
  }

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      croak("Can't set perms on $db_file to 0666: $!");
    }
  }

  unlink($db_script);
  return 1;
}

sub geoip_sql_allow_filter {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'geoip');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftp_user_geoip (
  user TEXT,
  regions TEXT,
  countries TEXT
);
INSERT INTO ftp_user_geoip (user, regions, countries) VALUES ('$setup->{user}', 'TX', 'US');

EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script, $db_file);

  my $geoip_ip_table = File::Spec->rel2abs('t/etc/modules/mod_geoip/GeoIP.dat');
  my $geoip_ipv6_table = File::Spec->rel2abs('t/etc/modules/mod_geoip/GeoIPv6.dat');
  my $geoip_city_table = File::Spec->rel2abs('t/etc/modules/mod_geoip/GeoLiteCity.dat');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'geoip:20 sql:20',

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
        'GeoIPAllowFilter sql:/get-user-geoip-regions',
        'GeoIPDenyFilter sql:/get-user-geoip-countries',
      ],

      'mod_sql.c' => [
        'SQLEngine log',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $setup->{log_file}",
        "SQLNamedQuery get-user-geoip-regions SELECT \"'RegionCode', regions FROM ftp_user_geoip WHERE user = '%U'\"",
        "SQLNamedQuery get-user-geoip-countries SELECT \"'CountryCode', countries FROM ftp_user_geoip WHERE user = '%U'\"",
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
      # Give the server time to start up
      sleep(1);

      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      $client->login($setup->{user}, $setup->{passwd});
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
