package ProFTPD::Tests::Modules::mod_quotatab_file;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use File::Copy;
use File::Path qw(mkpath);
use File::Spec;
use IO::Handle;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  quotatab_file_single_suppl_group => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  quotatab_file_all_limit => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_file_bytes_download_zero => {
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

sub set_up {
  my $self = shift;
  $self->SUPER::set_up(@_);

  # Make copies of the original tables into our scratch directory
  my ($src_file, $dst_file);

  $src_file = File::Spec->rel2abs('t/etc/modules/mod_quotatab_file/ftpquota-group-limit.tab');
  $dst_file = File::Spec->rel2abs("$self->{tmpdir}/ftpquota-group-limit.tab");

  unless (copy($src_file, $dst_file)) {
    die("Can't copy $src_file to $dst_file: $!");
  }

  $src_file = File::Spec->rel2abs('t/etc/modules/mod_quotatab_file/ftpquota-group-tally.tab');
  $dst_file = File::Spec->rel2abs("$self->{tmpdir}/ftpquota-group-tally.tab");

  unless (copy($src_file, $dst_file)) {
    die("Can't copy $src_file to $dst_file: $!");
  }

  $src_file = File::Spec->rel2abs('t/etc/modules/mod_quotatab_file/ftpquota-all-limit.tab');
  $dst_file = File::Spec->rel2abs("$self->{tmpdir}/ftpquota-all-limit.tab");

  unless (copy($src_file, $dst_file)) {
    die("Can't copy $src_file to $dst_file: $!");
  }

  $src_file = File::Spec->rel2abs('t/etc/modules/mod_quotatab_file/ftpquota-all-tally.tab');
  $dst_file = File::Spec->rel2abs("$self->{tmpdir}/ftpquota-all-tally.tab");

  unless (copy($src_file, $dst_file)) {
    die("Can't copy $src_file to $dst_file: $!");
  }
}

sub get_ftpquota_bin {
  my $ftpquota_bin;

  if ($ENV{PROFTPD_TEST_PATH}) {
    $ftpquota_bin = File::Spec->rel2abs("$ENV{PROFTPD_TEST_PATH}/contrib/ftpquota");

  } else {
    $ftpquota_bin = File::Spec->rel2abs('../contrib/ftpquota');
  }

  return $ftpquota_bin;
}

sub get_tally {
  my $tally_file = shift;
  my $name = shift;
  my $quota_type = shift;

  my $ftpquota_bin = get_ftpquota_bin();

  my $cmd;

  if ($ENV{TEST_VERBOSE}) {
    $cmd = "perl $ftpquota_bin --verbose --show-records --table-path=$tally_file --type=tally";

  } else {
    $cmd = "perl $ftpquota_bin --show-records --table-path=$tally_file --type=tally";
  }

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing perl: $cmd\n";
  }

  my @res = `$cmd`;

  if (scalar(@res) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @res), "\n";
  }

  if ($? != 0) {
    die("'$cmd' failed");
  }

  my ($bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used);

  foreach my $line (@res) {
    chomp($line);

    if ($line =~ /Uploaded bytes:\s+(\S+)$/) {
      $bytes_in_used = $1;

    } elsif ($line =~ /Downloaded bytes:\s+(\S+)$/) {
      $bytes_out_used = $1;

    } elsif ($line =~ /Transferred bytes:\s+(\S+)$/) {
      $bytes_xfer_used = $1;

    } elsif ($line =~ /Uploaded files:\s+(\S+)$/) {
      $files_in_used = $1;

    } elsif ($line =~ /Downloaded files:\s+(\S+)$/) {
      $files_out_used = $1;

    } elsif ($line =~ /Transferred files:\s+(\S+)$/) {
      $files_xfer_used = $1;
    }
  }

  return ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used);
}

sub quotatab_file_single_suppl_group {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/quotatab.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/quotatab.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  mkpath($home_dir);

  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directories has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  auth_group_write($auth_group_file, 'test1', $gid+2, $user);

  # Make sure that the group for whom there is a limit is NOT the user's
  # primary group, but IS the user's only supplemental group.
  auth_group_write($auth_group_file, 'test', $gid+1, $user);

  my $limit_file = File::Spec->rel2abs("$tmpdir/ftpquota-group-limit.tab");
  my $tally_file = File::Spec->rel2abs("$tmpdir/ftpquota-group-tally.tab");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_file.c' => {
        QuotaEngine => 'on',
        QuotaLog => $log_file,
        QuotaLimitTable => "file:$limit_file",
        QuotaTallyTable => "file:$tally_file",
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

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      $client->login($user, $passwd);

      my $conn = $client->stor_raw('test.txt');
      unless ($conn) {
        die("Failed to STOR test.txt: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Hello, World\n";
      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();
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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($tally_file, 'test', 'group');

  my $expected;

  $expected = 'group';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(13.0+|13)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected, got $bytes_in_used"));

  $expected = '^(0.0+|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected, got $bytes_out_used"));

  $expected = '^(0.0+|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected, got $bytes_xfer_used"));

  $expected = 0;
  $self->assert($expected == $files_in_used,
    test_msg("Expected $expected, got $files_in_used"));

  $expected = 0;
  $self->assert($expected == $files_out_used,
    test_msg("Expected $expected, got $files_out_used"));

  $expected = 0;
  $self->assert($expected == $files_xfer_used,
    test_msg("Expected $expected, got $files_xfer_used"));

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub quotatab_file_all_limit {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/quotatab.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/quotatab.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  mkpath($home_dir);

  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directories has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $limit_file = File::Spec->rel2abs("$tmpdir/ftpquota-all-limit.tab");
  my $tally_file = File::Spec->rel2abs("$tmpdir/ftpquota-all-tally.tab");

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, ">> $test_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_file.c' => {
        QuotaEngine => 'on',
        QuotaLog => $log_file,
        QuotaLimitTable => "file:$limit_file",
        QuotaTallyTable => "file:$tally_file",
        QuotaDisplayUnits => 'Mb',
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

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);

      my $conn = $client->retr_raw('test.txt');
      unless ($conn) {
        die("Failed to RETR test.txt: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      my $bufsz = 8192;

      $conn->read($buf, $bufsz, 25);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();
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

sub quotatab_file_bytes_download_zero {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/quotatab.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/quotatab.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  mkpath($home_dir);

  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directories has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  # Generate our limit file

  my $limit_file = File::Spec->rel2abs("$tmpdir/ftpquota-limit-zero-bytes.tab");
  my $tally_file = File::Spec->rel2abs("$tmpdir/ftpquota-tally-zero-bytes.tab");

  my $ftpquota_bin = get_ftpquota_bin();
  my $cmd;

  # See:
  #   https://forums.proftpd.org/smf/index.php/topic,11242.0.html

  # Create the limit table
  if ($ENV{TEST_VERBOSE}) {
    $cmd = "perl $ftpquota_bin --verbose --create-table --table-path=$limit_file --type=limit";

  } else {
    $cmd = "perl $ftpquota_bin --create-table --table-path=$limit_file --type=limit";
  }

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing perl: $cmd\n";
  }

  my @res = `$cmd`;

  if (scalar(@res) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @res), "\n";
  }

  if ($? != 0) {
    die("'$cmd' failed");
  }

  # Create the tally table
  if ($ENV{TEST_VERBOSE}) {
    $cmd = "perl $ftpquota_bin --verbose --create-table --table-path=$tally_file --type=tally";

  } else {
    $cmd = "perl $ftpquota_bin --create-table --table-path=$tally_file --type=tally";
  }

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing perl: $cmd\n";
  }

  @res = `$cmd`;

  if (scalar(@res) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @res), "\n";
  }

  if ($? != 0) {
    die("'$cmd' failed");
  }

  # Populate the limit table
  if ($ENV{TEST_VERBOSE}) {
    $cmd = "perl $ftpquota_bin --verbose --table-path=$limit_file --type=limit --add-record --name=$user -Q=user -L=hard --Bu=10485760 --Fd=0 --Bd=0";

  } else {
    $cmd = "perl $ftpquota_bin --table-path=$limit_file --type=limit --add-record --name=$user -Q=user -L=hard --Bu=10485760 --Fd=0 --Bd=0";
  }

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing perl: $cmd\n";
  }

  @res = `$cmd`;

  if (scalar(@res) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @res), "\n";
  }

  if ($? != 0) {
    die("'$cmd' failed");
  }

  if ($ENV{TEST_VERBOSE}) {
    $cmd = "perl $ftpquota_bin --verbose --table-path=$limit_file --type=limit --show-record --name=$user";

  } else {
    $cmd = "perl $ftpquota_bin --table-path=$limit_file --type=limit --show-record --name=$user";
  }

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing perl: $cmd\n";
  }

  @res = `$cmd`;

  if (scalar(@res) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @res), "\n";
  }

  if ($? != 0) {
    die("'$cmd' failed");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_file.c' => {
        QuotaEngine => 'on',
        QuotaLog => $log_file,
        QuotaLimitTable => "file:$limit_file",
        QuotaTallyTable => "file:$tally_file",
        QuotaDisplayUnits => 'Mb',
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

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);

      $client->site("QUOTA");
      my $resp_code = $client->response_code();
      my $resp_msgs = $client->response_msgs();

      my $expected = 200;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      my $expected = '   Downloaded Mb:    unlimited';
      $self->assert($expected eq $resp_msgs->[6],
        test_msg("Expected response message '$expected', got '$resp_msgs->[6]'"));

      $client->quit();
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

#  unlink($log_file);
}

1;
