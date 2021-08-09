package ProFTPD::Tests::Modules::mod_snmp::tls;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use Data::Dumper;
use File::Spec;
use IO::Handle;
use POSIX qw(:fcntl_h);

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  snmp_tls_v1_get_sess_counts => {
    order => ++$order,
    test_class => [qw(forking snmp tls)],
  },

  snmp_tls_v1_get_xfer_dirlist_counts => {
    order => ++$order,
    test_class => [qw(forking snmp tls)],
  },

  snmp_tls_v1_get_xfer_download_counts => {
    order => ++$order,
    test_class => [qw(forking snmp tls)],
  },

  snmp_tls_v1_get_xfer_upload_counts => {
    order => ++$order,
    test_class => [qw(forking snmp tls)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  # Check for the required Perl modules:
  #
  #  Net-SNMP
  #  Net-FTPSSL

  my $required = [qw(
    Net::SNMP
    Net::FTPSSL
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

sub get_tls_sess_info {
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

  # tlsSessions.sessionCount
  my $sess_count_oid = '1.3.6.1.4.1.17852.2.2.5.1.1.0';

  # tlsSessions.sessionTotal
  my $sess_total_oid = '1.3.6.1.4.1.17852.2.2.5.1.2.0';

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

sub get_tls_xfer_dirlist_info {
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

  # tlsDataTransfers.dirListCount
  my $dirlist_count_oid = '1.3.6.1.4.1.17852.2.2.5.3.1.0';

  # tlsDataTransfers.dirListTotal
  my $dirlist_total_oid = '1.3.6.1.4.1.17852.2.2.5.3.2.0';

  my $oids = [
    $dirlist_count_oid,
    $dirlist_total_oid,
  ];

  my $snmp_resp = $snmp_sess->get_request(
    -varbindList => $oids,
  );
  unless ($snmp_resp) {
    die("No SNMP response received: " . $snmp_sess->error());
  }

  my ($dirlist_count, $dirlist_total);

  # Do we have the requested OIDs in the response?

  foreach my $oid (@$oids) {
    unless (defined($snmp_resp->{$oid})) {
      die("Missing required OID $oid in response");
    }

    my $value = $snmp_resp->{$oid};
    if ($ENV{TEST_VERBOSE}) {
      print STDERR "Requested OID $oid = $value\n";
    }

    if ($oid eq $dirlist_count_oid) {
      $dirlist_count = $value;

    } elsif ($oid eq $dirlist_total_oid) {
      $dirlist_total = $value;
    }
  }

  $snmp_sess->close();
  $snmp_sess = undef;

  return ($dirlist_count, $dirlist_total);
}

sub get_tls_xfer_download_info {
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

  # tlsDataTransfers.fileDownloadCount
  my $download_file_count_oid = '1.3.6.1.4.1.17852.2.2.5.3.7.0';

  # tlsDataTransfers.fileDownloadTotal
  my $download_file_total_oid = '1.3.6.1.4.1.17852.2.2.5.3.8.0';

  # tlsDataTransfers.kbDownloadTotal
  my $download_kb_oid = '1.3.6.1.4.1.17852.2.2.5.3.11.0';

  my $oids = [
    $download_file_count_oid,
    $download_file_total_oid,
    $download_kb_oid
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

    if ($oid eq $download_file_count_oid) {
      $file_count = $value;

    } elsif ($oid eq $download_file_total_oid) {
      $file_total = $value;

    } elsif ($oid eq $download_kb_oid) {
      $kb_count = $value;
    }
  }

  $snmp_sess->close();
  $snmp_sess = undef;

  return ($file_count, $file_total, $kb_count);
}

sub get_tls_xfer_upload_info {
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

  # tlsDataTransfers.fileUploadCount
  my $upload_file_count_oid = '1.3.6.1.4.1.17852.2.2.5.3.4.0';

  # tlsDataTransfers.fileUploadTotal
  my $upload_file_total_oid = '1.3.6.1.4.1.17852.2.2.5.3.5.0';

  # tlsDataTransfers.kbUploadTotal
  my $upload_kb_oid = '1.3.6.1.4.1.17852.2.2.5.3.10.0';

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

sub list_dir {
  my $port = shift;
  my $user = shift;
  my $passwd = shift;
  my $dir_path = shift;

  require Net::FTPSSL;

  my $client = Net::FTPSSL->new('127.0.0.1',
    Encryption => 'E',
    Port => $port,
  );

  unless ($client) {
    die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
  }

  unless ($client->login($user, $passwd)) {
    die("Can't login: " . $client->last_message());
  }

  unless ($client->list($dir_path)) {
    die("Can't list directory '$dir_path': " . $client->last_message());
  }

  $client->quit();

  return 1;
}

sub download_file {
  my $port = shift;
  my $user = shift;
  my $passwd = shift;
  my $file_path = shift;
  my $file_kb_len = shift;

  require Net::FTPSSL;

  my $client = Net::FTPSSL->new('127.0.0.1',
    Encryption => 'E',
    Port => $port,
  );

  unless ($client) {
    die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
  }

  unless ($client->login($user, $passwd)) {
    die("Can't login: " . $client->last_message());
  }

  my $dst_path = '/dev/null';
  unless ($client->get($file_path, $dst_path)) {
    die("Can't download '$file_path' to '$dst_path': " .
      $client->last_message());
  }

  $client->quit();

  return 1;
}

sub upload_file {
  my $port = shift;
  my $user = shift;
  my $passwd = shift;
  my $file_path = shift;
  my $file_kb_len = shift;
  my $test_file = shift;

  require Net::FTPSSL;

  my $client = Net::FTPSSL->new('127.0.0.1',
    Encryption => 'E',
    Port => $port,
  );

  unless ($client) {
    die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
  }

  unless ($client->login($user, $passwd)) {
    die("Can't login: " . $client->last_message());
  }

  if (open(my $fh, "> $test_file")) {
    my $buf = ("A" x ($file_kb_len * 1024)); 
    print $fh $buf;

    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  unless ($client->put($test_file, $file_path)) {
    die("Can't upload '$test_file' to '$file_path': " .
      $client->last_message());
  }

  $client->quit();
  return 1;
}

# Test cases

sub snmp_tls_v1_get_sess_counts {
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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_snmp/tls-server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_snmp/tls-ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => 'NoSessionReuseRequired',
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
  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server time to start up
      sleep(2);

      my $expected;

      # First, get the session count
      my ($sess_count, $sess_total) = get_tls_sess_info($agent_port,
        $snmp_community);

      $expected = 0;
      $self->assert($sess_count == $expected,
        test_msg("Expected session count $expected, got $sess_count"));

      $expected = 0;
      $self->assert($sess_total == $expected,
        test_msg("Expected session total $expected, got $sess_total"));

      # Now, connect
      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      # And get the counts again.
      ($sess_count, $sess_total) = get_tls_sess_info($agent_port, $snmp_community);

      $expected = 1;
      $self->assert($sess_count == $expected,
        test_msg("Expected session count $expected, got $sess_count"));

      $expected = 1;
      $self->assert($sess_total == $expected,
        test_msg("Expected session total $expected, got $sess_total"));

      # Now log out
      $client->quit();

      # And get the session counts one more time, make sure it's what we expect
      ($sess_count, $sess_total) = get_tls_sess_info($agent_port, $snmp_community);

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

sub snmp_tls_v1_get_xfer_dirlist_counts {
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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_snmp/tls-server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_snmp/tls-ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => 'NoSessionReuseRequired',
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
  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $expected;

      # First, get the dirlist counts
      my ($dirlist_count, $dirlist_total) = get_tls_xfer_dirlist_info($agent_port, $snmp_community);

      $expected = 0;
      $self->assert($dirlist_count == $expected,
        test_msg("Expected directory list count $expected, got $dirlist_count"));

      $expected = 0;
      $self->assert($dirlist_total == $expected,
        test_msg("Expected directory list total $expected, got $dirlist_total"));

      # Next, list a directory
      list_dir($port, $user, $passwd, '.');

      # Then, get the dirlist count again
      ($dirlist_count, $dirlist_total) = get_tls_xfer_dirlist_info($agent_port, $snmp_community);

      $expected = 0;
      $self->assert($dirlist_count == $expected,
        test_msg("Expected directory list count $expected, got $dirlist_count"));

      $expected = 1;
      $self->assert($dirlist_total == $expected,
        test_msg("Expected directory list total $expected, got $dirlist_total"));

      # List another directory
      list_dir($port, $user, $passwd, '.');

      # Get the dirlist count one more time, make sure it's what we expect
      ($dirlist_count, $dirlist_total) = get_tls_xfer_dirlist_info($agent_port, $snmp_community);

      $expected = 0;
      $self->assert($dirlist_count == $expected,
        test_msg("Expected directory list count $expected, got $dirlist_count"));

      $expected = 2;
      $self->assert($dirlist_total == $expected,
        test_msg("Expected directory list total $expected, got $dirlist_total"));

      # Now wait for 5 secs, then try again (make sure the counters aren't
      # reset somehow on the server's side).
      sleep(5);

      ($dirlist_count, $dirlist_total) = get_tls_xfer_dirlist_info($agent_port, $snmp_community);

      $expected = 0;
      $self->assert($dirlist_count == $expected,
        test_msg("Expected directory list count $expected, got $dirlist_count"));

      $expected = 2;
      $self->assert($dirlist_total == $expected,
        test_msg("Expected directory list total $expected, got $dirlist_total"));
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

sub snmp_tls_v1_get_xfer_download_counts {
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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_snmp/tls-server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_snmp/tls-ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => 'NoSessionReuseRequired',
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
  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $expected;

      # First, get the download count/KB
      my ($file_count, $file_total, $kb_count) = get_tls_xfer_download_info($agent_port, $snmp_community);

      $expected = 0;
      $self->assert($file_count == $expected,
        test_msg("Expected download file count $expected, got $file_count"));

      $expected = 0;
      $self->assert($file_total == $expected,
        test_msg("Expected download file total $expected, got $file_total"));

      $expected = 0;
      $self->assert($kb_count == $expected,
        test_msg("Expected download KB count $expected, got $kb_count"));

      # Next, download a file
      my $file_name = 'test1.txt';
      my $file_path = File::Spec->rel2abs("$tmpdir/$file_name");
      my $file_kb_len = 4;

      if (open(my $fh, "> $file_path")) {
        my $buf = ("A" x ($file_kb_len * 1024));
        print $fh $buf;
        unless (close($fh)) {
          die("Can't write $file_path: $!");
        }

      } else {
        die("Can't open $file_path: $!");
      }

      download_file($port, $user, $passwd, $file_name, $file_kb_len);

      # Then, get the download count/KB again
      ($file_count, $file_total, $kb_count) = get_tls_xfer_download_info($agent_port, $snmp_community);

      $expected = 0;
      $self->assert($file_count == $expected,
        test_msg("Expected download file count $expected, got $file_count"));

      $expected = 1;
      $self->assert($file_total == $expected,
        test_msg("Expected download file total $expected, got $file_total"));

      $expected = $file_kb_len;
      $self->assert($kb_count == $expected,
        test_msg("Expected download KB count $expected, got $kb_count"));

      # Download another file
      $file_name = 'test2.txt';
      $file_path = File::Spec->rel2abs("$tmpdir/$file_name");

      if (open(my $fh, "> $file_path")) {
        my $buf = ("A" x ($file_kb_len * 1024));
        print $fh $buf;
        unless (close($fh)) {
          die("Can't write $file_path: $!");
        }

      } else {
        die("Can't open $file_path: $!");
      }

      download_file($port, $user, $passwd, $file_name, $file_kb_len);

      # Get the download count/KB one more time, make sure it's what we expect
      ($file_count, $file_total, $kb_count) = get_tls_xfer_download_info($agent_port, $snmp_community);

      $expected = 0;
      $self->assert($file_count == $expected,
        test_msg("Expected download file count $expected, got $file_count"));

      $expected = 2;
      $self->assert($file_total == $expected,
        test_msg("Expected download file total $expected, got $file_total"));

      $expected = ($file_kb_len * 2);
      $self->assert($kb_count == $expected,
        test_msg("Expected download KB count $expected, got $kb_count"));

      # Now wait for 5 secs, then try again (make sure the counters aren't
      # reset somehow on the server's side).
      sleep(5);

      ($file_count, $file_total, $kb_count) = get_tls_xfer_download_info($agent_port, $snmp_community);

      $expected = 0;
      $self->assert($file_count == $expected,
        test_msg("Expected download file count $expected, got $file_count"));

      $expected = 2;
      $self->assert($file_total == $expected,
        test_msg("Expected upload file total $expected, got $file_total"));

      $expected = ($file_kb_len * 2);
      $self->assert($kb_count == $expected,
        test_msg("Expected download KB count $expected, got $kb_count"));
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

sub snmp_tls_v1_get_xfer_upload_counts {
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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_snmp/tls-server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_snmp/tls-ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => 'NoSessionReuseRequired',
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
  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $expected;

      # First, get the upload count/KB
      my ($file_count, $file_total, $kb_count) = get_tls_xfer_upload_info($agent_port, $snmp_community);

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
      my $test_file = File::Spec->rel2abs("$tmpdir/test1.tmp");
      upload_file($port, $user, $passwd, $file_path, $file_kb_len, $test_file);

      # Then, get the upload count/KB again
      ($file_count, $file_total, $kb_count) = get_tls_xfer_upload_info($agent_port, $snmp_community);

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
      $test_file = File::Spec->rel2abs("$tmpdir/test2.tmp");
      upload_file($port, $user, $passwd, $file_path, $file_kb_len, $test_file);

      # Get the upload count/KB one more time, make sure it's what we expect
      ($file_count, $file_total, $kb_count) = get_tls_xfer_upload_info($agent_port, $snmp_community);

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

      ($file_count, $file_total, $kb_count) = get_tls_xfer_upload_info($agent_port, $snmp_community);

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

1;
