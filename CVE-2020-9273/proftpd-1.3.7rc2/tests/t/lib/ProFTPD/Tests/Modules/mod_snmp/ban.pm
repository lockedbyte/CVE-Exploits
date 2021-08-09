package ProFTPD::Tests::Modules::mod_snmp::ban;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use Data::Dumper;
use File::Spec;
use IO::Handle;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  snmp_ban_v1_get_conn_info => {
    order => ++$order,
    test_class => [qw(forking ban snmp)],
  },

  snmp_ban_v1_get_ban_info => {
    order => ++$order,
    test_class => [qw(forking ban snmp)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  # Check for the required Perl modules:
  #
  #  Net-SNMP

  my $required = [qw(
    Net::SNMP
  )];

  foreach my $req (@$required) {
    eval "use $req";
    if ($@) {
      print STDERR "\nWARNING:\n + Module '$req' not found, skipping all tests\n
";

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Unable to load $req: $@\n";
      }

      return qw(testsuite_empty_test);
    }
  }

  return testsuite_get_runnable_tests($TESTS);
}

# Support routines

sub get_ban_conn_info {
  my $agent_port = shift;
  my $snmp_community = shift;

  my ($snmp_sess, $snmp_err) = Net::SNMP->session(
    -hostname => '127.0.0.1',
    -port => $agent_port,
    -version => 'snmpv1',
    -community => $snmp_community,
    -retries => 1,
    -timeout => 3,
    -translate => 1,
  );
  unless ($snmp_sess) {
    die("Unable to create Net::SNMP session: $snmp_err");
  }

  if ($ENV{TEST_VERBOSE}) {
    # From the Net::SNMP debug perldocs
    my $debug_mask = (0x02|0x10|0x20);
    $snmp_sess->debug($debug_mask);
  }

  # ban.connections.connectionBannedTotal
  my $conn_banned_total_oid = '1.3.6.1.4.1.17852.2.2.9.1.1.0';

  # ban.connections.userBannedTotal
  my $user_banned_total_oid = '1.3.6.1.4.1.17852.2.2.9.1.2.0';

  # ban.connections.hostBannedTotal
  my $host_banned_total_oid = '1.3.6.1.4.1.17852.2.2.9.1.3.0';

  # ban.connections.classBannedTotal
  my $class_banned_total_oid = '1.3.6.1.4.1.17852.2.2.9.1.4.0';

  my $oids = [
    $conn_banned_total_oid,
    $user_banned_total_oid,
    $host_banned_total_oid,
    $class_banned_total_oid,
  ];

  my $snmp_resp = $snmp_sess->get_request(
    -varbindList => $oids,
  );
  unless ($snmp_resp) {
    die("No SNMP response received: " . $snmp_sess->error());
  }

  my ($conn_banned_total, $user_banned_total, $host_banned_total, $class_banned_total);

  # Do we have the requested OIDs in the response?

  foreach my $oid (@$oids) {
    unless (defined($snmp_resp->{$oid})) {
      die("Missing required OID $oid in response");
    }

    my $value = $snmp_resp->{$oid};
    if ($ENV{TEST_VERBOSE}) {
      print STDERR "Requested OID $oid = $value\n";
    }

    if ($oid eq $conn_banned_total_oid) {
      $conn_banned_total = $value;

    } elsif ($oid eq $user_banned_total_oid) {
      $user_banned_total = $value;

    } elsif ($oid eq $host_banned_total_oid) {
      $host_banned_total = $value;

    } elsif ($oid eq $class_banned_total_oid) {
      $class_banned_total = $value;
    }
  }

  $snmp_sess->close();
  $snmp_sess = undef;

  return ($conn_banned_total, $user_banned_total, $host_banned_total, $class_banned_total);
}

sub get_ban_ban_info {
  my $agent_port = shift;
  my $snmp_community = shift;

  my ($snmp_sess, $snmp_err) = Net::SNMP->session(
    -hostname => '127.0.0.1',
    -port => $agent_port,
    -version => 'snmpv1',
    -community => $snmp_community,
    -retries => 1,
    -timeout => 3,
    -translate => 1,
  );
  unless ($snmp_sess) {
    die("Unable to create Net::SNMP session: $snmp_err");
  }

  if ($ENV{TEST_VERBOSE}) {
    # From the Net::SNMP debug perldocs
    my $debug_mask = (0x02|0x10|0x20);
    $snmp_sess->debug($debug_mask);
  }

  # ban.bans.banCount
  my $ban_count_oid = '1.3.6.1.4.1.17852.2.2.9.2.1.0';

  # ban.bans.banTotal
  my $ban_total_oid = '1.3.6.1.4.1.17852.2.2.9.2.2.0';

  # ban.bans.userBanCount
  my $user_ban_count_oid = '1.3.6.1.4.1.17852.2.2.9.2.3.0';

  # ban.bans.userBanTotal
  my $user_ban_total_oid = '1.3.6.1.4.1.17852.2.2.9.2.4.0';

  # ban.bans.hostBanCount
  my $host_ban_count_oid = '1.3.6.1.4.1.17852.2.2.9.2.5.0';

  # ban.bans.hostBanTotal
  my $host_ban_total_oid = '1.3.6.1.4.1.17852.2.2.9.2.6.0';

  # ban.bans.classBanCount
  my $class_ban_count_oid = '1.3.6.1.4.1.17852.2.2.9.2.7.0';

  # ban.bans.classBanTotal
  my $class_ban_total_oid = '1.3.6.1.4.1.17852.2.2.9.2.8.0';

  my $oids = [
    $ban_count_oid,
    $ban_total_oid,
    $user_ban_count_oid,
    $user_ban_total_oid,
    $host_ban_count_oid,
    $host_ban_total_oid,
    $class_ban_count_oid,
    $class_ban_total_oid,
  ];

  my $snmp_resp = $snmp_sess->get_request(
    -varbindList => $oids,
  );
  unless ($snmp_resp) {
    die("No SNMP response received: " . $snmp_sess->error());
  }

  my ($ban_count, $ban_total);
  my ($user_ban_count, $user_ban_total);
  my ($host_ban_count, $host_ban_total);
  my ($class_ban_count, $class_ban_total);

  # Do we have the requested OIDs in the response?

  foreach my $oid (@$oids) {
    unless (defined($snmp_resp->{$oid})) {
      die("Missing required OID $oid in response");
    }

    my $value = $snmp_resp->{$oid};
    if ($ENV{TEST_VERBOSE}) {
      print STDERR "Requested OID $oid = $value\n";
    }

    if ($oid eq $ban_count_oid) {
      $ban_count = $value;

    } elsif ($oid eq $ban_total_oid) {
      $ban_total = $value;

    } elsif ($oid eq $user_ban_count_oid) {
      $user_ban_count = $value;

    } elsif ($oid eq $user_ban_total_oid) {
      $user_ban_total = $value;

    } elsif ($oid eq $host_ban_count_oid) {
      $host_ban_count = $value;

    } elsif ($oid eq $host_ban_total_oid) {
      $host_ban_total = $value;

    } elsif ($oid eq $class_ban_count_oid) {
      $class_ban_count = $value;

    } elsif ($oid eq $class_ban_total_oid) {
      $class_ban_total = $value;
    }
  }

  $snmp_sess->close();
  $snmp_sess = undef;

  return {
    ban_count => $ban_count,
    ban_total => $ban_total,
    user_ban_count => $user_ban_count,
    user_ban_total => $user_ban_total,
    host_ban_count => $host_ban_count,
    host_ban_total => $host_ban_total,
    class_ban_count => $class_ban_count,
    class_ban_total => $class_ban_total,
  };
}

# Test cases

sub snmp_ban_v1_get_conn_info {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/snmp.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/snmp.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/snmp.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/snmp.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/snmp.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $ban_tab = File::Spec->rel2abs("$tmpdir/ban.tab");
  my $table_dir = File::Spec->rel2abs("$tmpdir/var/snmp");

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $table_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $table_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $agent_port = ProFTPD::TestSuite::Utils::get_high_numbered_port();
  my $snmp_community = "public";

  my $ban_expiry_secs = 5;
  my $timeout_idle = 20;

  my $config = {
    TraceLog => $log_file,
    Trace => 'event:10 snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    MaxLoginAttempts => 2,

    IfModules => {
      'mod_ban.c' => {
        BanEngine => 'on',
        BanLog => $log_file,

        # This says to ban a client which exceeds the MaxLoginAttempts
        # limit once within the last 1 minute will be banned for 5 secs
        BanOnEvent => 'MaxLoginAttempts 1/00:01:00 00:00:05',

        BanTable => $ban_tab,
      },

      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_snmp.c' => {
        SNMPAgent => "master 127.0.0.1:$agent_port",
        SNMPCommunity => $snmp_community,
        SNMPEngine => 'on',
        SNMPLog => $log_file,
        SNMPTables => $table_dir,
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

  require Net::SNMP;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval { 
      # Give the server time to start up
      sleep(1);

      my $expected;

      # First, get the conn stats
      my ($conn_banned, $user_banned, $host_banned, $class_banned) = get_ban_conn_info($agent_port, $snmp_community);

      $expected = 0;
      $self->assert($conn_banned == $expected,
        test_msg("Expected connection banned total $expected, got $conn_banned"));

      $expected = 0;
      $self->assert($user_banned == $expected,
        test_msg("Expected user banned total $expected, got $user_banned"));

      $expected = 0;
      $self->assert($host_banned == $expected,
        test_msg("Expected host banned total $expected, got $host_banned"));

      $expected = 0;
      $self->assert($class_banned == $expected,
        test_msg("Expected class banned total $expected, got $class_banned"));

      # Now connect, and trigger a ban
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      eval { $client->login($user, 'foo') };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Login incorrect.";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      eval { $client->login($user, 'foo') };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Login incorrect.";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      # Now try again with the correct info; we should be banned.  Note
      # that we have to create a separate connection for this.
      eval { $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port,
        undef, 0) };
      unless ($@) {
        die("Connect succeeded unexpectedly");
      }

      # Double-check that the conn stats are now what we expect
      ($conn_banned, $user_banned, $host_banned, $class_banned) = get_ban_conn_info($agent_port, $snmp_community);

      $expected = 1;
      $self->assert($conn_banned == $expected,
        test_msg("Expected connection banned total $expected, got $conn_banned"));

      $expected = 0;
      $self->assert($user_banned == $expected,
        test_msg("Expected user banned total $expected, got $user_banned"));

      $expected = 1;
      $self->assert($host_banned == $expected,
        test_msg("Expected host banned total $expected, got $host_banned"));

      $expected = 0;
      $self->assert($class_banned == $expected,
        test_msg("Expected class banned total $expected, got $class_banned"));

      # Now wait for the ban to expire, then try again (and check stats)
      sleep($ban_expiry_secs + 1);

      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      eval { $client->login($user, 'foo') };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Login incorrect.";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      ($conn_banned, $user_banned, $host_banned, $class_banned) = get_ban_conn_info($agent_port, $snmp_community);

      $expected = 1;
      $self->assert($conn_banned == $expected,
        test_msg("Expected connection banned total $expected, got $conn_banned"));

      $expected = 0;
      $self->assert($user_banned == $expected,
        test_msg("Expected user banned total $expected, got $user_banned"));

      $expected = 1;
      $self->assert($host_banned == $expected,
        test_msg("Expected host banned total $expected, got $host_banned"));

      $expected = 0;
      $self->assert($class_banned == $expected,
        test_msg("Expected class banned total $expected, got $class_banned"));

    };
 
    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle) };
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

sub snmp_ban_v1_get_ban_info {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/snmp.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/snmp.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/snmp.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/snmp.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/snmp.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $ban_tab = File::Spec->rel2abs("$tmpdir/ban.tab");
  my $table_dir = File::Spec->rel2abs("$tmpdir/var/snmp");

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $table_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $table_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $agent_port = ProFTPD::TestSuite::Utils::get_high_numbered_port();
  my $snmp_community = "public";

  my $ban_expiry_secs = 5;
  my $timeout_idle = 45;

  my $config = {
    TraceLog => $log_file,
    Trace => 'event:10 snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    MaxClientsPerHost => 1,

    IfModules => {
      'mod_ban.c' => {
        BanEngine => 'on',
        BanLog => $log_file,

        # This says to ban a client which exceeds the MaxClientsPerHost
        # limit once within the last 2 minutes will be banned for 5 secs
        BanOnEvent => 'MaxClientsPerHost 1/00:02:00 00:00:05',

        BanTable => $ban_tab,
      },

      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_snmp.c' => {
        SNMPAgent => "master 127.0.0.1:$agent_port",
        SNMPCommunity => $snmp_community,
        SNMPEngine => 'on',
        SNMPLog => $log_file,
        SNMPTables => $table_dir,
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

  require Net::SNMP;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval { 
      # Give the server time to start up
      sleep(1);

      my $expected;

      # First, get the ban stats
      my $ban_info = get_ban_ban_info($agent_port, $snmp_community);

      $expected = 0;
      $self->assert($ban_info->{ban_count} == $expected,
        test_msg("Expected ban count $expected, got $ban_info->{ban_count}"));

      $expected = 0;
      $self->assert($ban_info->{ban_total} == $expected,
        test_msg("Expected ban total $expected, got $ban_info->{ban_total}"));

      $expected = 0;
      $self->assert($ban_info->{user_ban_count} == $expected,
        test_msg("Expected user ban count $expected, got $ban_info->{user_ban_count}"));

      $expected = 0;
      $self->assert($ban_info->{user_ban_total} == $expected,
        test_msg("Expected user ban total $expected, got $ban_info->{user_ban_total}"));

      $expected = 0;
      $self->assert($ban_info->{host_ban_count} == $expected,
        test_msg("Expected host ban count $expected, got $ban_info->{host_ban_count}"));

      $expected = 0;
      $self->assert($ban_info->{host_ban_total} == $expected,
        test_msg("Expected host ban total $expected, got $ban_info->{host_ban_total}"));

      $expected = 0;
      $self->assert($ban_info->{class_ban_count} == $expected,
        test_msg("Expected class ban count $expected, got $ban_info->{class_ban_count}"));

      $expected = 0;
      $self->assert($ban_info->{class_ban_total} == $expected,
        test_msg("Expected class ban total $expected, got $ban_info->{class_ban_total}"));

      # Now connect, and trigger a ban
      my $client1 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client1->login($user, $passwd);

      my $client2 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      eval { $client2->login($user, $passwd) };

      # Now try again with the correct info; we should be banned.  Note
      # that we have to create a separate connection for this.
      eval { my $client3 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port,
        undef, 0) };
      unless ($@) {
        die("Connect succeeded unexpectedly");
      }

      # Double-check that the ban stats are now what we expect
      $ban_info = get_ban_ban_info($agent_port, $snmp_community);

      $expected = 1;
      $self->assert($ban_info->{ban_count} == $expected,
        test_msg("Expected ban count $expected, got $ban_info->{ban_count}"));

      $expected = 1;
      $self->assert($ban_info->{ban_total} == $expected,
        test_msg("Expected ban total $expected, got $ban_info->{ban_total}"));

      $expected = 0;
      $self->assert($ban_info->{user_ban_count} == $expected,
        test_msg("Expected user ban count $expected, got $ban_info->{user_ban_count}"));

      $expected = 0;
      $self->assert($ban_info->{user_ban_total} == $expected,
        test_msg("Expected user ban total $expected, got $ban_info->{user_ban_total}"));

      $expected = 1;
      $self->assert($ban_info->{host_ban_count} == $expected,
        test_msg("Expected host ban count $expected, got $ban_info->{host_ban_count}"));

      $expected = 1;
      $self->assert($ban_info->{host_ban_total} == $expected,
        test_msg("Expected host ban total $expected, got $ban_info->{host_ban_total}"));

      $expected = 0;
      $self->assert($ban_info->{class_ban_count} == $expected,
        test_msg("Expected class ban count $expected, got $ban_info->{class_ban_count}"));

      $expected = 0;
      $self->assert($ban_info->{class_ban_total} == $expected,
        test_msg("Expected class ban total $expected, got $ban_info->{class_ban_total}"));

      # Now wait for the ban to expire, then try again (and check stats)
      sleep($ban_expiry_secs + 2);
      
      $client1 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client1->login($user, $passwd);
      $client1->quit();

      # And check the ban stats one more time
      $ban_info = get_ban_ban_info($agent_port, $snmp_community);

      $expected = 0;
      $self->assert($ban_info->{ban_count} == $expected,
        test_msg("Expected ban count $expected, got $ban_info->{ban_count}"));

      $expected = 1;
      $self->assert($ban_info->{ban_total} == $expected,
        test_msg("Expected ban total $expected, got $ban_info->{ban_total}"));

      $expected = 0;
      $self->assert($ban_info->{user_ban_count} == $expected,
        test_msg("Expected user ban count $expected, got $ban_info->{user_ban_count}"));

      $expected = 0;
      $self->assert($ban_info->{user_ban_total} == $expected,
        test_msg("Expected user ban total $expected, got $ban_info->{user_ban_total}"));

      $expected = 0;
      $self->assert($ban_info->{host_ban_count} == $expected,
        test_msg("Expected host ban count $expected, got $ban_info->{host_ban_count}"));

      $expected = 1;
      $self->assert($ban_info->{host_ban_total} == $expected,
        test_msg("Expected host ban total $expected, got $ban_info->{host_ban_total}"));

      $expected = 0;
      $self->assert($ban_info->{class_ban_count} == $expected,
        test_msg("Expected class ban count $expected, got $ban_info->{class_ban_count}"));

      $expected = 0;
      $self->assert($ban_info->{class_ban_total} == $expected,
        test_msg("Expected class ban total $expected, got $ban_info->{class_ban_total}"));
    };
 
    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle) };
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
