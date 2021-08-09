package ProFTPD::Tests::Modules::mod_snmp;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use Data::Dumper;
use File::Spec;
use IO::Handle;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :features :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  snmp_start_existing_dirs => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v1_get_unknown => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v1_get_wrong_community => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v1_get_daemon_software => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v1_get_daemon_version => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v1_get_daemon_admin => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v1_get_daemon_admin_with_config => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v1_get_daemon_uptime => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v1_get_daemon_vhost_count => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  # XXX Add snmp_v1_get_daemon_vhost_count w/ 2 vhosts in config

  snmp_v1_get_daemon_conn_counts => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v1_get_daemon_restart_count => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v1_get_daemon_segfault_count => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v1_get_daemon_maxinsts_count => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  # XXX Need unit tests for the ftp.sessions, ftp.logins, ftp.dataTransfers
  snmp_v1_get_ftp_sess_counts => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v1_get_ftp_xfer_upload_counts => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v1_get_multi => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v1_get_multi_with_unknown => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v1_get_next => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v1_get_next_unknown => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v1_get_next_missing_instance_id => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v1_get_next_end_of_mib_view => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v1_get_next_multi => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v1_get_next_multi_with_unknown => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v1_set => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  # snmp_v1_trap
  # XXX Net::SNMP's session->trap() method seems buggy; often crashes/
  #  unit tests.

  snmp_v2_get_unknown => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v2_get_missing_instance_id => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v2_get_next_end_of_mib_view => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v2_get_bulk => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v2_get_bulk_max_repetitions_only => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v2_get_bulk_end_of_mib_view => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_v2_set_no_access => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  # snmp_v3_XXX

  snmp_config_limit => {
    order => ++$order,
    test_class => [qw(forking snmp)],
  },

  snmp_config_max_variables => {
    order => ++$order,
    test_class => [qw(forking snmp)],
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

sub get_conn_info {
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

  # connectionCount
  my $conn_count_oid = '1.3.6.1.4.1.17852.2.2.1.6.0';

  # connectionTotal
  my $conn_total_oid = '1.3.6.1.4.1.17852.2.2.1.7.0';

  my $oids = [$conn_count_oid, $conn_total_oid];

  my $snmp_resp = $snmp_sess->get_request(
    -varbindList => $oids,
  );
  unless ($snmp_resp) {
    die("No SNMP response received: " . $snmp_sess->error());
  }

  my ($conn_count, $conn_total);

  # Do we have the requested OIDs in the response?

  foreach my $oid (@$oids) {
    unless (defined($snmp_resp->{$oid})) {
      die("Missing required OID $oid in response");
    }

    my $value = $snmp_resp->{$oid};
    if ($ENV{TEST_VERBOSE}) {
      print STDERR "Requested OID $oid = $value\n";
    }

    if ($oid eq $conn_count_oid) {
      $conn_count = $value;

    } elsif ($oid eq $conn_total_oid) {
      $conn_total = $value;
    }
  }

  $snmp_sess->close();
  $snmp_sess = undef;

  return ($conn_count, $conn_total);
}

sub get_ftp_sess_info {
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

  # sessionCount
  my $sess_count_oid = '1.3.6.1.4.1.17852.2.2.3.1.1.0';

  # fileUploadTotal
  my $sess_total_oid = '1.3.6.1.4.1.17852.2.2.3.1.2.0';

  my $oids = [
    $sess_count_oid,
    $sess_total_oid,
  ];

  my $snmp_resp = $snmp_sess->get_request(
    -varbindList => $oids,
  );
  unless ($snmp_resp) {
    die("No SNMP response received: " . $snmp_sess->error());
  }

  my ($sess_count, $sess_total);

  # Do we have the requested OIDs in the response?

  foreach my $oid (@$oids) {
    unless (defined($snmp_resp->{$oid})) {
      die("Missing required OID $oid in response");
    }

    my $value = $snmp_resp->{$oid};
    if ($ENV{TEST_VERBOSE}) {
      print STDERR "Requested OID $oid = $value\n";
    }

    if ($oid eq $sess_count_oid) {
      $sess_count = $value;

    } elsif ($oid eq $sess_total_oid) {
      $sess_total = $value;
    }
  }

  $snmp_sess->close();
  $snmp_sess = undef;

  return ($sess_count, $sess_total);
}

sub get_ftp_xfer_upload_info {
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

  # fileUploadCount
  my $upload_file_count_oid = '1.3.6.1.4.1.17852.2.2.3.3.4.0';

  # fileUploadTotal
  my $upload_file_total_oid = '1.3.6.1.4.1.17852.2.2.3.3.5.0';

  # kbUploadTotal
  my $upload_kb_oid = '1.3.6.1.4.1.17852.2.2.3.3.10.0';

  my $oids = [
    $upload_file_count_oid,
    $upload_file_total_oid,
    $upload_kb_oid
  ];

  my $snmp_resp = $snmp_sess->get_request(
    -varbindList => $oids,
  );
  unless ($snmp_resp) {
    die("No SNMP response received: " . $snmp_sess->error());
  }

  my ($file_count, $file_total, $kb_count);

  # Do we have the requested OIDs in the response?

  foreach my $oid (@$oids) {
    unless (defined($snmp_resp->{$oid})) {
      die("Missing required OID $oid in response");
    }

    my $value = $snmp_resp->{$oid};
    if ($ENV{TEST_VERBOSE}) {
      print STDERR "Requested OID $oid = $value\n";
    }

    if ($oid eq $upload_file_count_oid) {
      $file_count = $value;

    } elsif ($oid eq $upload_file_total_oid) {
      $file_total = $value;

    } elsif ($oid eq $upload_kb_oid) {
      $kb_count = $value;
    }
  }

  $snmp_sess->close();
  $snmp_sess = undef;

  return ($file_count, $file_total, $kb_count);
}

sub upload_file {
  my $port = shift;
  my $user = shift;
  my $passwd = shift;
  my $file_path = shift;
  my $file_kb_len = shift;

  my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

  $client->login($user, $passwd);

  my $conn = $client->stor_raw($file_path);
  unless ($conn) {
    die("Failed to STOR: " . $client->response_code() . " " .
      $client->response_msg());
  }

  my $buf = ("A" x ($file_kb_len * 1024));
  $conn->write($buf, length($buf), 25);
  eval { $conn->close() };

  my ($resp_code, $resp_msg);
  $resp_code = $client->response_code();
  $resp_msg = $client->response_msg();

  $client->quit();
  $client = undef;

  my $expected;
  $expected = 226;
  unless ($expected == $resp_code) {
    die("Unexpected response code $resp_code (expected $expected)");
  }

  $expected = "Transfer complete";
  unless ($expected eq $resp_msg) {
    die("Unexpected response message $resp_msg (expected $expected)");
  }

  return 1;
}

# Test cases

sub snmp_start_existing_dirs {
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

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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

  my $ex;

  # First, start the server
  server_start($config_file);
  
  # ...then stop the server.  This means mod_snmp will have created all
  # the necessary directories, etc.
  sleep(2);
  server_stop($pid_file);

  # Now start the server again.  Time time, mod_snmp will double-check
  # permissions et al on the already-existing mod_snmp directories that it
  # created the first time.
  sleep(2);
  server_start($config_file);

  # Stop server
  sleep(2);
  eval { server_stop($pid_file) };
  if ($@) {
    $ex = $@;
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub snmp_v1_get_unknown {
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

  my $request_oid = '1.3.6.1.4.1.17852.1.0';

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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

      my $oids = [$request_oid];

      my $snmp_resp = $snmp_sess->get_request(
        -varbindList => $oids,
      );
      if ($snmp_resp) {
        die("SNMP response received unexpectedly");
      }

      my $err = $snmp_sess->error();
      my $expected = 'Received noSuchName(2) error-status at error-index 1';

      $self->assert($expected eq $err,
        test_msg("Expected error '$expected' for OID, got '$err'"));

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_v1_get_wrong_community {
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

  my $request_oid = '1.3.6.1.4.1.17852.2.2.1.1.0';

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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
      my ($snmp_sess, $snmp_err) = Net::SNMP->session(
        -hostname => '127.0.0.1',
        -port => $agent_port,
        -version => 'snmpv1',

        # Deliberately configure the wrong community name
        -community => 'foo',

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

      my $oids = [$request_oid];

      my $snmp_resp = $snmp_sess->get_request(
        -varbindList => $oids,
      );
      if ($snmp_resp) {
        die("SNMP response received unexpectedly");
      }

      # We don't expect to receive a response here; the community info is
      # wrong.  The only indication *might* be a trap that's generated, and
      # sent somewhere else.

      my $err = $snmp_sess->error();
      my $expected = 'No response from remote host "127.0.0.1"';

      $self->assert($expected eq $err,
        test_msg("Expected error '$expected' for OID, got '$err'"));

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_v1_get_daemon_software {
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

  my $request_oid = '1.3.6.1.4.1.17852.2.2.1.1.0';

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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

      my $oids = [$request_oid];

      my $snmp_resp = $snmp_sess->get_request(
        -varbindList => $oids,
      );
      unless ($snmp_resp) {
        die("No SNMP response received: " . $snmp_sess->error());
      }

      # Do we have the requested OID in the response?
      unless (defined($snmp_resp->{$request_oid})) {
        die("Missing required OID $request_oid in response");
      }

      my $value = $snmp_resp->{$request_oid};

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Requested OID $request_oid = $value\n";
      }

      my $expected = 'proftpd';

      $self->assert($expected eq $value,
        test_msg("Expected value '$expected' for OID, got '$value'"));

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_v1_get_daemon_version {
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

  my $request_oid = '1.3.6.1.4.1.17852.2.2.1.2.0';

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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

      my $oids = [$request_oid];

      my $snmp_resp = $snmp_sess->get_request(
        -varbindList => $oids,
      );
      unless ($snmp_resp) {
        die("No SNMP response received: " . $snmp_sess->error());
      }

      # Do we have the requested OID in the response?
      unless (defined($snmp_resp->{$request_oid})) {
        die("Missing required OID $request_oid in response");
      }

      my $value = $snmp_resp->{$request_oid};

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Requested OID $request_oid = $value\n";
      }

      my $expected = '^ProFTPD Version';

      $self->assert(qr/$expected/, $value,
        test_msg("Expected value '$expected' for OID, got '$value'"));

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_v1_get_daemon_admin {
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

  my $request_oid = '1.3.6.1.4.1.17852.2.2.1.3.0';

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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

      my $oids = [$request_oid];

      my $snmp_resp = $snmp_sess->get_request(
        -varbindList => $oids,
      );
      unless ($snmp_resp) {
        die("No SNMP response received: " . $snmp_sess->error());
      }

      # Do we have the requested OID in the response?
      unless (defined($snmp_resp->{$request_oid})) {
        die("Missing required OID $request_oid in response");
      }

      my $value = $snmp_resp->{$request_oid};

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Requested OID $request_oid = $value\n";
      }

      # The default proftpd string, without ServerAdmin configured.
      my $expected = 'root@127.0.0.1';

      $self->assert(qr/$expected/, $value,
        test_msg("Expected value '$expected' for OID, got '$value'"));

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_v1_get_daemon_admin_with_config {
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

  my $request_oid = '1.3.6.1.4.1.17852.2.2.1.3.0';
  my $server_admin = 'tj@castaglia.org';

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    ServerAdmin => $server_admin,

    IfModules => {
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

      my $oids = [$request_oid];

      my $snmp_resp = $snmp_sess->get_request(
        -varbindList => $oids,
      );
      unless ($snmp_resp) {
        die("No SNMP response received: " . $snmp_sess->error());
      }

      # Do we have the requested OID in the response?
      unless (defined($snmp_resp->{$request_oid})) {
        die("Missing required OID $request_oid in response");
      }

      my $value = $snmp_resp->{$request_oid};

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Requested OID $request_oid = $value\n";
      }

      my $expected = $server_admin;

      $self->assert(qr/$expected/, $value,
        test_msg("Expected value '$expected' for OID, got '$value'"));

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_v1_get_daemon_uptime {
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

  my $request_oid = '1.3.6.1.4.1.17852.2.2.1.4.0';

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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
      # Wait a couple of secs, so that the uptime has a non-zero value
      sleep(2);

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

      my $oids = [$request_oid];

      my $snmp_resp = $snmp_sess->get_request(
        -varbindList => $oids,
      );
      unless ($snmp_resp) {
        die("No SNMP response received: " . $snmp_sess->error());
      }

      # Do we have the requested OID in the response?
      unless (defined($snmp_resp->{$request_oid})) {
        die("Missing required OID $request_oid in response");
      }

      my $value = $snmp_resp->{$request_oid};

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Requested OID $request_oid = $value\n";
      }

      my $expected = '(^\d+ days, )?.*?\d+\.\d+';

      $self->assert(qr/$expected/, $value,
        test_msg("Expected value '$expected' for OID, got '$value'"));

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_v1_get_daemon_vhost_count {
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

  my $request_oid = '1.3.6.1.4.1.17852.2.2.1.5.0';

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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

      my $oids = [$request_oid];

      my $snmp_resp = $snmp_sess->get_request(
        -varbindList => $oids,
      );
      unless ($snmp_resp) {
        die("No SNMP response received: " . $snmp_sess->error());
      }

      # Do we have the requested OID in the response?
      unless (defined($snmp_resp->{$request_oid})) {
        die("Missing required OID $request_oid in response");
      }

      my $value = $snmp_resp->{$request_oid};

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Requested OID $request_oid = $value\n";
      }

      my $expected = 1;

      $self->assert($expected == $value,
        test_msg("Expected value $expected for OID, got $value"));

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_v1_get_daemon_conn_counts {
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

  my $delay_nsecs = 45;
  my $use_delay = 0;

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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
      my $expected;

      # First, get the conn count/total
      my ($conn_count, $conn_total) = get_conn_info($agent_port,
        $snmp_community);

      $expected = 0;
      $self->assert($conn_count == $expected,
        test_msg("Expected connection count $expected, got $conn_count"));

      $expected = 0;
      $self->assert($conn_total == $expected,
        test_msg("Expected connection total $expected, got $conn_total"));

      # Now, connect to the server
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # Then, get the connection counts again
      ($conn_count, $conn_total) = get_conn_info($agent_port, $snmp_community);

      $expected = 1;
      $self->assert($conn_count == $expected,
        test_msg("Expected connection count $expected, got $conn_count"));

      $self->assert($conn_total == $expected,
        test_msg("Expected connection total $expected, got $conn_total"));

      # Disconnect from the server.
      $client->quit();
      $client = undef;

      # Get the connection counts one more time, make sure they're what we
      # expect.
      ($conn_count, $conn_total) = get_conn_info($agent_port, $snmp_community);

      $expected = 0;
      $self->assert($conn_count == $expected,
        test_msg("Expected connection count $expected, got $conn_count"));

      $expected = 1;
      $self->assert($conn_total == $expected,
        test_msg("Expected connection total $expected, got $conn_total"));

      # Now wait for 2 secs, then try again (make sure the counters aren't
      # reset somehow on the server's side).
      sleep(2);

      ($conn_count, $conn_total) = get_conn_info($agent_port, $snmp_community);

      $expected = 0;
      $self->assert($conn_count == $expected,
        test_msg("Expected connection count $expected, got $conn_count"));

      $expected = 1;
      $self->assert($conn_total == $expected,
        test_msg("Expected connection total $expected, got $conn_total"));

      # Now connect several more times
      my $nconnects = 10;
      for (my $i = 0; $i < $nconnects; $i++) {
        $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
        $client->quit();
      }

      if ($use_delay) {
          # Wait for more than 45 secs; that's when the resets are
          # usually seen
          if ($ENV{TEST_VERBOSE}) {
            print STDERR "# Waiting for $delay_nsecs secs\n";
          }
          sleep($delay_nsecs);
      }

      ($conn_count, $conn_total) = get_conn_info($agent_port, $snmp_community);

      $expected = 0;
      $self->assert($conn_count == $expected,
        test_msg("Expected connection count $expected, got $conn_count"));

      $expected = $nconnects + 1;
      $self->assert($conn_total == $expected,
        test_msg("Expected connection total $expected, got $conn_total"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $delay_nsecs + 10) };
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

sub snmp_v1_get_daemon_restart_count {
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

  my $request_oid = '1.3.6.1.4.1.17852.2.2.1.6.0';

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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

      my $oids = [$request_oid];

      my $snmp_resp = $snmp_sess->get_request(
        -varbindList => $oids,
      );
      unless ($snmp_resp) {
        die("No SNMP response received: " . $snmp_sess->error());
      }

      # Do we have the requested OID in the response?
      unless (defined($snmp_resp->{$request_oid})) {
        die("Missing required OID $request_oid in response");
      }

      my $value = $snmp_resp->{$request_oid};

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Requested OID $request_oid = $value\n";
      }

      my $expected = 0;

      $self->assert($expected == $value,
        test_msg("Expected value $expected for OID, got $value"));

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_v1_get_daemon_segfault_count {
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

  my $request_oid = '1.3.6.1.4.1.17852.2.2.1.7.0';

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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

      my $oids = [$request_oid];

      my $snmp_resp = $snmp_sess->get_request(
        -varbindList => $oids,
      );
      unless ($snmp_resp) {
        die("No SNMP response received: " . $snmp_sess->error());
      }

      # Do we have the requested OID in the response?
      unless (defined($snmp_resp->{$request_oid})) {
        die("Missing required OID $request_oid in response");
      }

      my $value = $snmp_resp->{$request_oid};

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Requested OID $request_oid = $value\n";
      }

      my $expected = 0;

      $self->assert($expected == $value,
        test_msg("Expected value $expected for OID, got $value"));

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_v1_get_daemon_maxinsts_count {
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

  my $request_oid = '1.3.6.1.4.1.17852.2.2.1.8.0';

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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

      my $oids = [$request_oid];

      my $snmp_resp = $snmp_sess->get_request(
        -varbindList => $oids,
      );
      unless ($snmp_resp) {
        die("No SNMP response received: " . $snmp_sess->error());
      }

      # Do we have the requested OID in the response?
      unless (defined($snmp_resp->{$request_oid})) {
        die("Missing required OID $request_oid in response");
      }

      my $value = $snmp_resp->{$request_oid};

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Requested OID $request_oid = $value\n";
      }

      my $expected = 0;

      $self->assert($expected == $value,
        test_msg("Expected value $expected for OID, got $value"));

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_v1_get_ftp_sess_counts {
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

  my $timeout_idle = 45;

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle + 1,

    IfModules => {
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
      my $expected;

      # First, get the session count
      my ($sess_count, $sess_total) = get_ftp_sess_info($agent_port,
        $snmp_community);

      $expected = 0;
      $self->assert($sess_count == $expected,
        test_msg("Expected session count $expected, got $sess_count"));

      $expected = 0;
      $self->assert($sess_total == $expected,
        test_msg("Expected session total $expected, got $sess_total"));

      # Now, login
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # Get the session counts again.  We've only connected, not logged in,
      # so the session counts should not have changed.
      ($sess_count, $sess_total) = get_ftp_sess_info($agent_port, $snmp_community);

      $expected = 0;
      $self->assert($sess_count == $expected,
        test_msg("Expected session count $expected, got $sess_count"));

      $expected = 0;
      $self->assert($sess_total == $expected,
        test_msg("Expected session total $expected, got $sess_total"));

      # Login.
      $client->login($user, $passwd);

      # Then, get the session counts again
      ($sess_count, $sess_total) = get_ftp_sess_info($agent_port, $snmp_community);

      $expected = 1;
      $self->assert($sess_count == $expected,
        test_msg("Expected session count $expected, got $sess_count"));

      $expected = 1;
      $self->assert($sess_total == $expected,
        test_msg("Expected session total $expected, got $sess_total"));

      # Now log out
      $client->quit();
      $client = undef;

      # And get the session counts one more time, make sure it's what we expect
      ($sess_count, $sess_total) = get_ftp_sess_info($agent_port, $snmp_community);

      # We MIGHT see a value of 1 here; I suspect it is leftover from the
      # previous test (and in anonymous memory).  Tolerate it, for now.
      $expected = 0;
      $self->assert($sess_count == 0 || $sess_count == 1,
        test_msg("Expected session count $expected, got $sess_count"));

      $expected = 1;
      $self->assert($sess_total == $expected,
        test_msg("Expected session total $expected, got $sess_total"));
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

sub snmp_v1_get_ftp_xfer_upload_counts {
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

  my $timeout_idle = 45;

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle + 1,

    IfModules => {
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
      my $expected;

      # First, get the upload count/KB
      my ($file_count, $file_total, $kb_count) = get_ftp_xfer_upload_info($agent_port,
        $snmp_community);

      $expected = 0;
      $self->assert($file_count == $expected,
        test_msg("Expected upload file count $expected, got $file_count"));

      $expected = 0;
      $self->assert($file_total == $expected,
        test_msg("Expected upload file total $expected, got $file_total"));

      $expected = 0;
      $self->assert($kb_count == $expected,
        test_msg("Expected upload KB count $expected, got $kb_count"));

      # Next, upload a file
      my $file_path = 'test1.txt';
      my $file_kb_len = 4;
      upload_file($port, $user, $passwd, $file_path, $file_kb_len);

      # Then, get the upload count/KB again
      ($file_count, $file_total, $kb_count) = get_ftp_xfer_upload_info($agent_port, $snmp_community);

      $expected = 0;
      $self->assert($file_count == $expected,
        test_msg("Expected upload file count $expected, got $file_count"));

      $expected = 1;
      $self->assert($file_total == $expected,
        test_msg("Expected upload file total $expected, got $file_total"));

      $expected = $file_kb_len;
      $self->assert($kb_count == $expected,
        test_msg("Expected upload KB count $expected, got $kb_count"));

      # Upload another file
      $file_path = 'test2.txt';
      upload_file($port, $user, $passwd, $file_path, $file_kb_len);

      # Get the upload count/KB one more time, make sure it's what we expect
      ($file_count, $file_total, $kb_count) = get_ftp_xfer_upload_info($agent_port, $snmp_community);

      $expected = 0;
      $self->assert($file_count == $expected,
        test_msg("Expected upload file count $expected, got $file_count"));

      $expected = 2;
      $self->assert($file_total == $expected,
        test_msg("Expected upload file total $expected, got $file_total"));

      $expected = ($file_kb_len * 2);
      $self->assert($kb_count == $expected,
        test_msg("Expected upload KB count $expected, got $kb_count"));

      # Now wait for 5 secs, then try again (make sure the counters aren't
      # reset somehow on the server's side).
      sleep(5);

      ($file_count, $file_total, $kb_count) = get_ftp_xfer_upload_info($agent_port, $snmp_community);

      $expected = 0;
      $self->assert($file_count == $expected,
        test_msg("Expected upload file count $expected, got $file_count"));

      $expected = 2;
      $self->assert($file_total == $expected,
        test_msg("Expected upload file total $expected, got $file_total"));

      $expected = ($file_kb_len * 2);
      $self->assert($kb_count == $expected,
        test_msg("Expected upload KB count $expected, got $kb_count"));
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

sub snmp_v1_get_multi {
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

  my $request_oids = [
    '1.3.6.1.4.1.17852.2.2.1.1.0',
    '1.3.6.1.4.1.17852.2.2.1.3.0',
  ];

  my $expected_oid_values = {
    '1.3.6.1.4.1.17852.2.2.1.1.0' => 'proftpd',
    '1.3.6.1.4.1.17852.2.2.1.3.0' => 'root@127.0.0.1',
  };

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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

      my $snmp_resp = $snmp_sess->get_request(
        -varbindList => $request_oids,
      );
      unless ($snmp_resp) {
        die("No SNMP response received: " . $snmp_sess->error());
      }

      # Do we have the requested OIDs in the response?
      foreach my $request_oid (@$request_oids) {
        unless (defined($snmp_resp->{$request_oid})) {
          die("Missing required OID $request_oid in response");
        }

        my $value = $snmp_resp->{$request_oid};

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "Requested OID $request_oid = $value\n";
        }

        my $expected = $expected_oid_values->{$request_oid};

        $self->assert($expected eq $value,
          test_msg("Expected value '$expected' for OID, got '$value'"));
      }

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_v1_get_multi_with_unknown {
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

  my $request_oids = [
    '1.3.6.1.4.1.17852.2.2.1.1.0',
    '1.3.6.1.4.1.17852.1.1',
  ];

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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

      my $snmp_resp = $snmp_sess->get_request(
        -varbindList => $request_oids,
      );
      if ($snmp_resp) {
        die("SNMP response received unexpectedly");
      }

      my $err = $snmp_sess->error();
      my $expected = 'Received noSuchName(2) error-status at error-index 2';

      $self->assert($expected eq $err,
        test_msg("Expected error '$expected' for OIDs, got '$err'"));

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_v1_get_next {
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

  my $request_oid = '1.3.6.1.4.1.17852.2.2.1.2.0';
  my $next_oid = '1.3.6.1.4.1.17852.2.2.1.3.0';

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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

      my $oids = [$request_oid];

      my $snmp_resp = $snmp_sess->get_next_request(
        -varbindList => $oids,
      );
      unless ($snmp_resp) {
        die("No SNMP response received: " . $snmp_sess->error());
      }

      # Do we have the next OID of the requested OID in the response?
      unless (defined($snmp_resp->{$next_oid})) {
        die("Missing required OID $next_oid in response");
      }

      my $value = $snmp_resp->{$next_oid};

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Requested OID $next_oid = $value\n";
      }

      # The default proftpd string, without ServerAdmin configured.
      my $expected = 'root@127.0.0.1';

      $self->assert(qr/$expected/, $value,
        test_msg("Expected value '$expected' for OID, got '$value'"));

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_v1_get_next_unknown {
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

  my $request_oid = '1.3.6.1.4.1.17852.999.0.1';

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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

      my $oids = [$request_oid];

      my $snmp_resp = $snmp_sess->get_next_request(
        -varbindList => $oids,
      );
      if ($snmp_resp) {
        die("SNMP response received unexpectedly");
      }

      my $err = $snmp_sess->error();
      my $expected = 'Received noSuchName(2) error-status at error-index 1';

      $self->assert($expected eq $err,
        test_msg("Expected error '$expected' for OID, got '$err'"));

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_v1_get_next_missing_instance_id {
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

  my $request_oid = '1.3.6.1.4.1.17852.2.2.1.1';
  my $next_oid = '1.3.6.1.4.1.17852.2.2.1.1.0';

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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

      my $oids = [$request_oid];

      my $snmp_resp = $snmp_sess->get_next_request(
        -varbindList => $oids,
      );
      unless ($snmp_resp) {
        die("No SNMP response received: " . $snmp_sess->error());
      }

      # Do we have the next OID of the requested OID in the response?
      unless (defined($snmp_resp->{$next_oid})) {
        die("Missing required OID $next_oid in response");
      }

      my $value = $snmp_resp->{$next_oid};

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Requested OID $next_oid = $value\n";
      }

      my $expected = 'proftpd';

      $self->assert(qr/$expected/, $value,
        test_msg("Expected value '$expected' for OID, got '$value'"));

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_v1_get_next_end_of_mib_view {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'snmp');

  my $table_dir = File::Spec->rel2abs("$tmpdir/var/snmp");

  my $agent_port = ProFTPD::TestSuite::Utils::get_high_numbered_port();
  my $snmp_community = "public";

  # Deliberately request an OID (within the proftpd.snmpModulen.snmp arc)
  # which does NOT exist.
  my $request_oid = '1.3.6.1.4.1.17852.2.2.4.6.0';
  my $timeout = 30;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_snmp.c' => {
        SNMPAgent => "master 127.0.0.1:$agent_port",
        SNMPCommunity => $snmp_community,
        SNMPEngine => 'on',
        SNMPLog => $setup->{log_file},
        SNMPTables => $table_dir,
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

  require Net::SNMP;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Allow server to start up
      sleep(1);

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

      my $oids = [$request_oid];

      my $snmp_resp = $snmp_sess->get_next_request(
        -varbindList => $oids,
      );
      if ($snmp_resp) {
        die("SNMP response received unexpectedly");
      }

      my $err = $snmp_sess->error();
      my $expected = 'Received noSuchName(2) error-status at error-index 1';

      $self->assert($expected eq $err,
        test_msg("Expected error '$expected' for OID, got '$err'"));

      $snmp_sess->close();
      $snmp_sess = undef;
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, $timeout) };
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

sub snmp_v1_get_next_multi {
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

  my $request_oids = [
    '1.3.6.1.4.1.17852.2.2.1.2.0',
    '1.3.6.1.4.1.17852.2.2.1.4.0',
  ];

  my $next_oid_values = {
    '1.3.6.1.4.1.17852.2.2.1.3.0' => 'root@127.0.0.1',
    '1.3.6.1.4.1.17852.2.2.1.5.0' => '1',
  };

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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

      my $snmp_resp = $snmp_sess->get_next_request(
        -varbindList => $request_oids,
      );
      unless ($snmp_resp) {
        die("No SNMP response received: " . $snmp_sess->error());
      }

      # Do we have the expected OIDs in the response?
      foreach my $next_oid (keys(%$next_oid_values)) {
        unless (defined($snmp_resp->{$next_oid})) {
          die("Missing required OID $next_oid in response");
        }

        my $value = $snmp_resp->{$next_oid};

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "Requested OID $next_oid = $value\n";
        }

        my $expected = $next_oid_values->{$next_oid};

        $self->assert($expected eq $value,
          test_msg("Expected value '$expected' for OID, got '$value'"));
      }

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_v1_get_next_multi_with_unknown {
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

  my $request_oids = [
    '1.3.6.1.4.1.17852.2.2.1.2.0',
    '1.3.6.1.4.1.17852.1.1.0',
  ];

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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

      my $snmp_resp = $snmp_sess->get_next_request(
        -varbindList => $request_oids,
      );
      if ($snmp_resp) {
        die("SNMP response received unexpectedly");
      }

      my $err = $snmp_sess->error();
      my $expected = 'Received noSuchName(2) error-status at error-index 2';

      $self->assert($expected eq $err,
        test_msg("Expected error '$expected', got '$err'"));

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_v1_set {
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

  my $request_oid = '1.3.6.1.4.1.17852.2.2.1.1.0';

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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
  require Net::SNMP::Message;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
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

      my $snmp_resp = $snmp_sess->set_request(
        -varbindList => [ $request_oid, Net::SNMP::Message::OCTET_STRING(),
                          'mod_smp' ],
      );
      if ($snmp_resp) {
        die("SNMP response received unexpectedly");
      }

      my $err = $snmp_sess->error();
      my $expected = 'Received noSuchName(2) error-status at error-index 1';

      $self->assert($expected eq $err,
        test_msg("Expected error '$expected' for OID, got '$err'"));

      $snmp_sess->close();
      $snmp_sess = undef;
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, 10) };
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

sub snmp_v1_trap {
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

  my $request_oid = '1.3.6.1.4.1.17852.2.2.1.1.0';

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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
  require Net::SNMP::Message;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
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

      my $snmp_resp = $snmp_sess->trap(
        -varbindList => [ $request_oid, Net::SNMP::Message::OCTET_STRING(),
                          'mod_smp' ],
      );
      if ($snmp_resp) {
        die("SNMP response received unexpectedly");
      }

      my $err = $snmp_sess->error();
      my $expected = 'Received noSuchName(2) error-status at error-index 1';

      $self->assert($expected eq $err,
        test_msg("Expected error '$expected' for OID, got '$err'"));

      $snmp_sess->close();
      $snmp_sess = undef;
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, 10) };
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

sub snmp_v2_get_unknown {
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

  my $request_oid = '1.3.6.1.4.1.17852.1.0';

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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
      my ($snmp_sess, $snmp_err) = Net::SNMP->session(
        -hostname => '127.0.0.1',
        -port => $agent_port,
        -version => 'snmpv2c',
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

      my $oids = [$request_oid];

      my $snmp_resp = $snmp_sess->get_request(
        -varbindList => $oids,
      );
      unless ($snmp_resp) {
        die("No SNMP response received: " . $snmp_sess->error());
      }

      # Do we have the requested OID in the response?
      unless (defined($snmp_resp->{$request_oid})) {
        die("Missing required OID $request_oid in response");
      }

      my $value = $snmp_resp->{$request_oid};

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Requested OID $request_oid = $value\n";
      }

      my $expected = 'noSuchObject';

      $self->assert($expected eq $value,
        test_msg("Expected value $expected for OID, got $value"));

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_v2_get_missing_instance_id {
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

  my $request_oid = '1.3.6.1.4.1.17852.2.2.1.1';

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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
      my ($snmp_sess, $snmp_err) = Net::SNMP->session(
        -hostname => '127.0.0.1',
        -port => $agent_port,
        -version => 'snmpv2c',
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

      my $oids = [$request_oid];

      my $snmp_resp = $snmp_sess->get_request(
        -varbindList => $oids,
      );
      unless ($snmp_resp) {
        die("No SNMP response received: " . $snmp_sess->error());
      }

      # Do we have the requested OID in the response?
      unless (defined($snmp_resp->{$request_oid})) {
        die("Missing required OID $request_oid in response");
      }

      my $value = $snmp_resp->{$request_oid};

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Requested OID $request_oid = $value\n";
      }

      my $expected = 'noSuchInstance';

      $self->assert($expected eq $value,
        test_msg("Expected value '$expected' for OID, got '$value'"));

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_v2_get_next_end_of_mib_view {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'snmp');

  my $table_dir = File::Spec->rel2abs("$tmpdir/var/snmp");

  my $agent_port = ProFTPD::TestSuite::Utils::get_high_numbered_port();
  my $snmp_community = "public";

  # The "last" OID in the entire arc depends on the modules loaded.
  my $request_oid = '1.3.6.1.4.1.17852.2.2.4.5.0';
  if (feature_have_module_compiled('mod_tls.c')) {
    # End of the proftpd.snmpModule.ftps arc
    $request_oid = '1.3.6.1.4.1.17852.2.2.5.3.11.0';
  }
  if (feature_have_module_compiled('mod_sftp.c')) {
    # End of the proftpd.snmpModule.scp arc
    $request_oid = '1.3.6.1.4.1.17852.2.2.8.2.8.0';
  }
  if (feature_have_module_compiled('mod_ban.c')) {
    # End of the proftpd.snmpModule.ban arc
    $request_oid = '1.3.6.1.4.1.17852.2.2.9.2.8.0';
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_snmp.c' => {
        SNMPAgent => "master 127.0.0.1:$agent_port",
        SNMPCommunity => $snmp_community,
        SNMPEngine => 'on',
        SNMPLog => $setup->{log_file},
        SNMPTables => $table_dir,
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

  require Net::SNMP;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Allow server to start up
      sleep(1);

      my ($snmp_sess, $snmp_err) = Net::SNMP->session(
        -hostname => '127.0.0.1',
        -port => $agent_port,
        -version => 'snmpv2c',
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

      my $oids = [$request_oid];

      my $snmp_resp = $snmp_sess->get_next_request(
        -varbindList => $oids,
      );
      unless ($snmp_resp) {
        die("No SNMP response received: " . $snmp_sess->error());
      }

      # Do we have the requested OID in the response?
      unless (defined($snmp_resp->{$request_oid})) {
        die("Missing required OID $request_oid in response");
      }

      my $value = $snmp_resp->{$request_oid};

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Requested OID $request_oid = $value\n";
      }

      my $expected = 'endOfMibView';

      $self->assert($expected eq $value,
        test_msg("Expected value '$expected' for OID, got '$value'"));

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_v2_get_bulk {
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

  my $request_oid = '1.3.6.1.4.1.17852.2.2.1.2.0';
  my $next_oid = '1.3.6.1.4.1.17852.2.2.1.3.0';

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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
      my ($snmp_sess, $snmp_err) = Net::SNMP->session(
        -hostname => '127.0.0.1',
        -port => $agent_port,
        -version => 'snmpv2c',
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

      my $oids = [$request_oid];

      my $snmp_resp = $snmp_sess->get_bulk_request(
        -nonrepeaters => 1,
        -varbindList => $oids,
      );
      unless ($snmp_resp) {
        die("No SNMP response received: " . $snmp_sess->error());
      }

      # Do we have the next OID of the requested OID in the response?
      unless (defined($snmp_resp->{$next_oid})) {
        die("Missing required OID $next_oid in response");
      }

      my $value = $snmp_resp->{$next_oid};

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Requested OID $next_oid = $value\n";
      }

      # The default proftpd string, without ServerAdmin configured.
      my $expected = 'root@127.0.0.1';

      $self->assert(qr/$expected/, $value,
        test_msg("Expected value '$expected' for OID, got '$value'"));

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_v2_get_bulk_max_repetitions_only {
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

  my $request_oid = '1.3.6.1.4.1.17852.2.2.1.2.0';

  my $next_oids = {
    '1.3.6.1.4.1.17852.2.2.1.3.0' => 'root@127.0.0.1',
    '1.3.6.1.4.1.17852.2.2.1.4.0' => '\d+\.\d+',
  };

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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
      my ($snmp_sess, $snmp_err) = Net::SNMP->session(
        -hostname => '127.0.0.1',
        -port => $agent_port,
        -version => 'snmpv2c',
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

      my $oids = [$request_oid];

      my $snmp_resp = $snmp_sess->get_bulk_request(
        -maxrepetitions => 2,
        -varbindList => $oids,
      );
      unless ($snmp_resp) {
        die("No SNMP response received: " . $snmp_sess->error());
      }

      foreach my $next_oid (keys(%$next_oids)) {
        # Do we have the next OID of the requested OID in the response?
        unless (defined($snmp_resp->{$next_oid})) {
          die("Missing required OID $next_oid in response");
        }

        my $value = $snmp_resp->{$next_oid};

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "Requested OID $next_oid = $value\n";
        }

        my $expected = $next_oids->{$next_oid};

        $self->assert(qr/$expected/, $value,
          test_msg("Expected value '$expected' for OID, got '$value'"));
      }

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_v2_get_bulk_end_of_mib_view {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'snmp');

  my $table_dir = File::Spec->rel2abs("$tmpdir/var/snmp");

  my $agent_port = ProFTPD::TestSuite::Utils::get_high_numbered_port();
  my $snmp_community = "public";

  # These OIDs to request depend on the modules loaded.
  my $request_oid = '1.3.6.1.4.1.17852.2.2.4.3.0';

  my $next_oids = {
    '1.3.6.1.4.1.17852.2.2.4.4.0' => '\d+',
    '1.3.6.1.4.1.17852.2.2.4.5.0' => '\d+',
    '1.3.6.1.4.1.17852.2.2.4.5.0 ' => 'endOfMibView',
  };

  if (feature_have_module_compiled('mod_tls.c')) {
    $request_oid = '1.3.6.1.4.1.17852.2.2.5.3.9.0';
    $next_oids = {
      '1.3.6.1.4.1.17852.2.2.5.3.10.0' => '\d+',
      '1.3.6.1.4.1.17852.2.2.5.3.11.0' => '\d+',
      '1.3.6.1.4.1.17852.2.2.5.3.11.0 ' => 'endOfMibView',
    };
  }

  if (feature_have_module_compiled('mod_sftp.c')) {
    $request_oid = '1.3.6.1.4.1.17852.2.2.8.2.6.0';
    $next_oids = {
      '1.3.6.1.4.1.17852.2.2.8.2.7.0' => '\d+',
      '1.3.6.1.4.1.17852.2.2.8.2.8.0' => '\d+',
      '1.3.6.1.4.1.17852.2.2.8.2.8.0 ' => 'endOfMibView',
    };
  }

  if (feature_have_module_compiled('mod_ban.c')) {
    $request_oid = '1.3.6.1.4.1.17852.2.2.9.2.6.0';
    $next_oids = {
      '1.3.6.1.4.1.17852.2.2.9.2.7.0' => '\d+',
      '1.3.6.1.4.1.17852.2.2.9.2.8.0' => '\d+',
      '1.3.6.1.4.1.17852.2.2.9.2.8.0 ' => 'endOfMibView',
    };
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_snmp.c' => {
        SNMPAgent => "master 127.0.0.1:$agent_port",
        SNMPCommunity => $snmp_community,
        SNMPEngine => 'on',
        SNMPLog => $setup->{log_file},
        SNMPTables => $table_dir,
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

  require Net::SNMP;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Allow the server to start up
      sleep(1);

      my ($snmp_sess, $snmp_err) = Net::SNMP->session(
        -hostname => '127.0.0.1',
        -port => $agent_port,
        -version => 'snmpv2c',
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

      my $oids = [$request_oid];

      my $snmp_resp = $snmp_sess->get_bulk_request(
        -maxrepetitions => 5,
        -varbindList => $oids,
      );
      unless ($snmp_resp) {
        die("No SNMP response received: " . $snmp_sess->error());
      }

      if ($ENV{TEST_VERBOSE}) {
        use Data::Dumper;
        print STDERR "# SNMP response: ", Dumper($snmp_resp), "\n";
      }

      foreach my $next_oid (keys(%$next_oids)) {
        # Do we have the next OID of the requested OID in the response?
        unless (defined($snmp_resp->{$next_oid})) {
          die("Missing required OID $next_oid in response");
        }

        my $value = $snmp_resp->{$next_oid};

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "Requested OID $next_oid = $value\n";
        }

        my $expected = $next_oids->{$next_oid};

        $self->assert(qr/$expected/, $value,
          test_msg("Expected value '$expected' for OID, got '$value'"));
      }

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_v2_set_no_access {
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

  my $request_oid = '1.3.6.1.4.1.17852.2.2.1.1.0';

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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
  require Net::SNMP::Message;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my ($snmp_sess, $snmp_err) = Net::SNMP->session(
        -hostname => '127.0.0.1',
        -port => $agent_port,
        -version => 'snmpv2c',
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

      my $snmp_resp = $snmp_sess->set_request(
        -varbindList => [ $request_oid, Net::SNMP::Message::OCTET_STRING(),
                          'mod_smp' ],
      );
      if ($snmp_resp) {
        die("SNMP response received unexpectedly");
      }

      my $err = $snmp_sess->error();
      my $expected = 'Received noAccess(6) error-status at error-index 1';

      $self->assert($expected eq $err,
        test_msg("Expected error '$expected' for OID, got '$err'"));

      $snmp_sess->close();
      $snmp_sess = undef;
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, 10) };
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

sub snmp_config_limit {
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

  my $request_oid = '1.3.6.1.4.1.17852.2.2.1.3.0';

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
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

    Limit => {
      SNMP => {
        Deny => '127.0.0.1',
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

      my $oids = [$request_oid];

      my $snmp_resp = $snmp_sess->get_request(
        -varbindList => $oids,
      );
      if ($snmp_resp) {
        die("SNMP response received unexpectedly");
      }

      my $err = $snmp_sess->error();
      my $expected = '^No response from remote host';

      $self->assert(qr/$expected/, $err,
        test_msg("Expected error '$expected', got '$err'"));

      $snmp_sess->close();
      $snmp_sess = undef;
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

sub snmp_config_max_variables {
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

  my $request_oids = [
    '1.3.6.1.4.1.17852.2.2.1.1.0',
    '1.3.6.1.4.1.17852.2.2.1.3.0',
  ];

  my $expected_oid_values = {
    '1.3.6.1.4.1.17852.2.2.1.1.0' => 'proftpd',
    '1.3.6.1.4.1.17852.2.2.1.3.0' => 'root@127.0.0.1',
  };

  my $config = {
    TraceLog => $log_file,
    Trace => 'snmp:20 snmp.asn1:20 snmp.db:20 snmp.msg:20 snmp.pdu:20 snmp.smi:20',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_snmp.c' => {
        SNMPAgent => "master 127.0.0.1:$agent_port",
        SNMPCommunity => $snmp_community,
        SNMPEngine => 'on',
        SNMPLog => $log_file,
        SNMPTables => $table_dir,

        SNMPMaxVariables => 1,
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

      my $snmp_resp = $snmp_sess->get_request(
        -varbindList => $request_oids,
      );
      if ($snmp_resp) {
        die("SNMP response received unexpectedly");
      }

      my $err = $snmp_sess->error();
      my $expected = 'Received tooBig(1) error-status at error-index 0';

      $self->assert($expected eq $err,
        test_msg("Expected error '$expected', got '$err'"));

      $snmp_sess->close();
      $snmp_sess = undef;
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
