package ProFTPD::Tests::Modules::mod_quotatab_sql;

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
  quotatab_stor_ok_user_limit => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_appe_ok_user_limit_bytes_in_exceeded_soft_limit => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_appe_ok_user_limit_bytes_in_exceeded_hard_limit => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_retr_ok_user_limit_bytes_out_exceeded => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_retr_ok_user_limit_files_out_exceeded => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_stor_ok_user_limit_bytes_in_exceeded_soft_limit => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_stor_ok_user_limit_bytes_in_exceeded_hard_limit => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_stor_ok_user_default_limit_bytes_in_exceeded_soft_limit => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_stor_ok_user_default_limit_bytes_in_exceeded_hard_limit => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_stor_ok_user_limit_files_in_exceeded => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_stor_ok_user_default_with_group_limit => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_stor_ok_user_default_with_no_group_limit => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_stor_ok_group_limit => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_stor_ok_group_limit_bytes_in_exceeded_soft_limit => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_stor_ok_group_limit_bytes_in_exceeded_hard_limit => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_stor_ok_group_limit_files_in_exceeded => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_stor_ok_group_limit_with_default => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_stor_ok_class_limit => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_stor_ok_class_limit_bytes_in_exceeded_soft_limit => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_stor_ok_class_limit_bytes_in_exceeded_hard_limit => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_stor_ok_class_limit_files_in_exceeded => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_stor_ok_all_limit => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_stor_ok_all_limit_bytes_in_exceeded_soft_limit => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_stor_ok_all_limit_bytes_in_exceeded_hard_limit => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_stor_ok_all_limit_files_in_exceeded => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_stor_bug3164 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  quotatab_dele_ok_user_limit => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_dele_user_owner_bug3161 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  quotatab_dele_group_owner_bug3161 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  quotatab_new_tally_lock_bug3086 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  quotatab_config_exclude_filter_bug3298 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  quotatab_config_exclude_filter_chrooted_bug3298 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  quotatab_config_exclude_filter_bug3878 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  quotatab_config_opt_scanonlogin => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  quotatab_config_opt_scanonlogin_chrooted => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  quotatab_config_opt_scanonlogin_new_tally_bug3440 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  quotatab_site_bug3483 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  quotatab_dele_failed_bug3517 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  quotatab_sql_dele_bug3524 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  quotatab_stor_deleteabortedstores_conn_abor_bug3621 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  quotatab_stor_deleteabortedstores_cmd_abor_bug3621 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  quotatab_sql_addl_query_columns_bug3879 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  quotatab_sql_odbc => {
    order => ++$order,
    test_class => [qw(forking mod_sql_odbc)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub get_tally {
  my $db_file = shift;
  my $where = shift;

  my $sql = "SELECT quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies";
  if ($where) {
    $sql .= " WHERE $where";
  }

  my $cmd = "sqlite3 $db_file \"$sql\"";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my $res = join('', `$cmd`);

  # The default sqlite3 delimiter is '|'
  return split(/\|/, $res);
}

my $bug3164_wait_timeout = 0;
sub bug3164_wait_alarm {
  croak("Test timed out after $bug3164_wait_timeout secs");
}

sub bug3164_server_wait {
  my $config_file = shift;
  my $db_file = shift;
  my $rfh = shift;
  $bug3164_wait_timeout = shift;
  $bug3164_wait_timeout = 10 unless defined($bug3164_wait_timeout);

  # Start server
  server_start($config_file);

  $SIG{ALRM} = \&bug3164_wait_alarm;
  alarm($bug3164_wait_timeout);

  # Wait until we receive word from the child that it has finished its test.
  while (my $msg = <$rfh>) {
    chomp($msg);

    if ($msg eq 'do_update') {
      my $cmd = "sqlite3 $db_file \"UPDATE quotatallies SET bytes_in_used = 10.0, bytes_out_used = 10.0, bytes_xfer_used = 10.0, files_in_used = 2, files_out_used = 2, files_xfer_used = 2 WHERE name = 'proftpd';\"";
      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Executing sqlite3: $cmd\n";
      }

      my @output = `$cmd`;
      if (scalar(@output) &&
          $ENV{TEST_VERBOSE}) {
        print STDERR "Output: ", join('', @output), "\n";
      }

      next;
    }

    if ($msg eq 'done') {
      last;
    }
  }

  alarm(0);
  $SIG{ALRM} = 'DEFAULT';
  return 1;
}

sub quotatab_stor_ok_user_limit {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 32, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$user\'");

  my $expected;

  $expected = 'user';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(13.0|13)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected, got $bytes_xfer_used"));

  $expected = 1;
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

sub quotatab_appe_ok_user_limit_bytes_in_exceeded_soft_limit {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $test_file = File::Spec->rel2abs("$home_dir/test.txt");

  if (open(my $fh, "> $test_file")) {
    close($fh);

  } else {
    die("Can't open $test_file: $!");
  }

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 5, 0, 0, 3, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AllowOverwrite => 'on',
    AllowStoreRestart => 'on',
    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

      my $conn = $client->stor_raw('foo.txt');
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

      # We've exceeded the soft limit, so this upload should be denied
      $conn = $client->appe_raw('test.txt');
      if ($conn) {
        die("APPE test.txt succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected = 552;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'APPE denied: quota exceeded: used \S+ of \S+ upload bytes';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

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

sub quotatab_appe_ok_user_limit_bytes_in_exceeded_hard_limit {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $test_file = File::Spec->rel2abs("$home_dir/test.txt");

  if (open(my $fh, "> $test_file")) {
    close($fh);

  } else {
    die("Can't open $test_file: $!");
  }

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'hard', 5, 0, 0, 3, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AllowOverwrite => 'on',
    AllowStoreRestart => 'on',
    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

      my $conn = $client->appe_raw('test.txt');
      unless ($conn) {
        die("Failed to APPE test.txt: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Hello, World\n";
      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 552;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'Transfer aborted. (Disc|Disk) quota exceeded';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $client->quit();

      if (-f $test_file) {
        die("$test_file exists, should have been deleted");
      }
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

sub quotatab_retr_ok_user_limit_bytes_out_exceeded {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $test_file = File::Spec->rel2abs("$home_dir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 0, 5, 0, 0, 3, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10',

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 1);
      $client->login($user, $passwd);

      my $conn = $client->retr_raw('test.txt');
      unless ($conn) {
        die("Failed to RETR test.txt: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 25);
      eval { $conn->close() };

      my $resp_code = $client->response_code(1);

      my $msg_idx = 1;
      if ($resp_code == 150) {
        $msg_idx = 0;
      }
      my $resp_msg = $client->response_msg($msg_idx);

      $self->assert_transfer_ok($resp_code, $resp_msg);

      sleep(1);

      # We've exceeded the bytes out limit, so this download should be denied
      $conn = $client->retr_raw('test.txt');
      if ($conn) {
        die("RETR test.txt succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected = 451;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'RETR denied: quota exceeded: used \S+ of \S+ download bytes';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

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

sub quotatab_retr_ok_user_limit_files_out_exceeded {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $test_file = File::Spec->rel2abs("$home_dir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 0, 0, 0, 0, 1, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10',

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 1);
      $client->login($user, $passwd);

      my $conn = $client->retr_raw('test.txt');
      unless ($conn) {
        die("Failed to RETR test.txt: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 25);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      $self->assert_transfer_ok($resp_code, $resp_msg);

      # We've exceeded the files out limit, so this download should be denied
      $conn = $client->retr_raw('test.txt');
      if ($conn) {
        die("RETR test.txt succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected = 451;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'RETR denied: quota exceeded: used \S+ of \S+ download file(s)?';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

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

sub quotatab_stor_ok_user_limit_bytes_in_exceeded_soft_limit {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 5, 0, 0, 3, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

      my $conn = $client->stor_raw('foo.txt');
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

      # We've exceeded the soft limit, so this upload should be denied
      $conn = $client->stor_raw('test.txt');
      if ($conn) {
        die("STOR test.txt succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected = 552;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'STOR denied: quota exceeded: used \S+ of \S+ upload bytes';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

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

sub quotatab_stor_ok_user_limit_bytes_in_exceeded_hard_limit {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'hard', 5, 0, 0, 3, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

      my $expected;

      $expected = 552;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'Transfer aborted. (Disc|Disk) quota exceeded';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $client->quit();

      if (-f $test_file) {
        die("$test_file exists, should have been deleted");
      }
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

sub quotatab_stor_ok_user_default_limit_bytes_in_exceeded_soft_limit {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',

        'QuotaDefault group false soft 5 0 0 3 0 0',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

      my $conn = $client->stor_raw('foo.txt');
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

      # We've exceeded the soft limit, so this upload should be denied
      $conn = $client->stor_raw('test.txt');
      if ($conn) {
        die("STOR test.txt succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected = 552;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'STOR denied: quota exceeded: used \S+ of \S+ upload bytes';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

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

sub quotatab_stor_ok_user_default_limit_bytes_in_exceeded_hard_limit {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',

        'QuotaDefault user false hard 5 0 0 3 0 0',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

      my $expected;

      $expected = 552;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'Transfer aborted. (Disc|Disk) quota exceeded';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $client->quit();

      if (-f $test_file) {
        die("$test_file exists, should have been deleted");
      }
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

sub quotatab_stor_ok_user_limit_files_in_exceeded {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 32, 0, 0, 1, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

      $conn = $client->stor_raw('test2.txt');
      if ($conn) {
        die("STOR test2.txt succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected = 552;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'STOR: notice: quota reached: used \d+ of \d+ upload file';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));
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

sub quotatab_stor_ok_user_default_with_group_limit {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user1 = 'proftpd';
  my $group = 'ftpd';
  my $passwd = 'test';
  my $home_dir1 = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($home_dir1);

  my $uid1 = 500;
  my $gid = 500;

  my $user2 = 'proftpd2';
  my $home_dir2 = File::Spec->rel2abs("$tmpdir/bar");
  mkpath($home_dir2);

  my $uid2 = 1000;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user1', '$passwd', $uid1, $gid, '$home_dir1', '/bin/bash');
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user2', '$passwd', $uid2, $gid, '$home_dir2', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user1,$user2');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$group', 'group', 'false', 'soft', 32, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
INSERT INTO quotatallies (name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used) VALUES ('$group', 'group', 32, 0, 0, 2, 0, 0);

EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
        'QuotaDefault user false hard 0 1 0 3 0 0',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
        SQLNamedQuery => 'get-user-info SELECT "userid, passwd, uid, gid, homedir, shell FROM users WHERE userid=\'%U\'"',
        SQLUserInfo => 'custom:/get-user-info',
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
      my $client1 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);

      # Login as user1, and upload a file
      $client1->login($user1, $passwd);

      # These uploads should fail because they encounter the configured
      # group limits/tallies in the database, despite the presence of a
      # user QuotaDefault in the config; the group limits/tallies should
      # take precedence over the config default.

      my $conn = $client1->stor_raw('test.txt');
      if ($conn) {
        die("STOR test.txt succeeded unexpectedly");
      }

      my $resp_code = $client1->response_code();
      my $resp_msg = $client1->response_msg();

      my $expected = 552;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      ($resp_code, $resp_msg) = $client1->quit();

      $expected = 221;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      my $client2 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);

      # Login as user2, and upload a file
      $client2->login($user2, $passwd);

      $conn = $client2->stor_raw('test.txt');
      if ($conn) {
        die("STOR test.txt succeeded unexpectedly");
      }

      $resp_code = $client2->response_code();
      $resp_msg = $client2->response_msg();

      $expected = 552;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $client2->quit();
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

  eval {
    my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$group\'");

    my $expected = 'group';
    $self->assert($expected eq $quota_type,
      test_msg("Expected '$expected', got '$quota_type'"));

    $expected = '^(32.0|32)$';
    $self->assert(qr/$expected/, $bytes_in_used,
      test_msg("Expected $expected, got $bytes_in_used"));

    $expected = '^(0.0|0)$';
    $self->assert(qr/$expected/, $bytes_out_used,
      test_msg("Expected $expected, got $bytes_out_used"));

    $expected = '^(0.0|0)$';
    $self->assert(qr/$expected/, $bytes_xfer_used,
      test_msg("Expected $expected, got $bytes_xfer_used"));

    $expected = 2;
    $self->assert($expected == $files_in_used,
      test_msg("Expected $expected, got $files_in_used"));

    $expected = 0;
    $self->assert($expected == $files_out_used,
      test_msg("Expected $expected, got $files_out_used"));

    $expected = 0;
    $self->assert($expected == $files_xfer_used,
      test_msg("Expected $expected, got $files_xfer_used"));
  };
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

sub quotatab_stor_ok_user_default_with_no_group_limit {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user1 = 'proftpd';
  my $group = 'ftpd';
  my $passwd = 'test';
  my $home_dir1 = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($home_dir1);

  my $uid1 = 500;
  my $gid = 500;

  my $user2 = 'proftpd2';
  my $home_dir2 = File::Spec->rel2abs("$tmpdir/bar");
  mkpath($home_dir2);

  my $uid2 = 1000;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user1', '$passwd', $uid1, $gid, '$home_dir1', '/bin/bash');
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user2', '$passwd', $uid2, $gid, '$home_dir2', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user1,$user2');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);

EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
        'QuotaDefault user false hard 0 1 0 3 0 0',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
        SQLNamedQuery => 'get-user-info SELECT "userid, passwd, uid, gid, homedir, shell FROM users WHERE userid=\'%U\'"',
        SQLUserInfo => 'custom:/get-user-info',
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
      my $client1 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);

      # Login as user1, and upload a file
      $client1->login($user1, $passwd);

      # These uploads should fail because they encounter the configured
      # group limits/tallies in the database, despite the presence of a
      # user QuotaDefault in the config; the group limits/tallies should
      # take precedence over the config default.

      my $conn = $client1->stor_raw('test.txt');
      unless ($conn) {
        die("STOR test.txt failed: " . $client1->response_code() . " " .
          $client1->response_msg());
      }

      my $buf = "Hello, World\n";
      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      my $resp_code = $client1->response_code();
      my $resp_msg = $client1->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client1->quit();

      my $expected = 221;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      my $client2 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);

      # Login as user2, and upload a file
      $client2->login($user2, $passwd);

      $conn = $client2->stor_raw('test.txt');
      unless ($conn) {
        die("STOR test.txt failed: " . $client2->response_code() . " " .
          $client2->response_msg());
      }

      my $buf = "Hello, World\n";
      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      my $resp_code = $client2->response_code();
      my $resp_msg = $client2->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client2->quit();
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

  eval {
    my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$user1\'");

    my $expected = 'user';
    $self->assert($expected eq $quota_type,
      test_msg("Expected '$expected', got '$quota_type'"));

    $expected = '^(0.0|0)$';
    $self->assert(qr/$expected/, $bytes_in_used,
      test_msg("Expected $expected, got $bytes_in_used"));

    $expected = '^(0.0|0)$';
    $self->assert(qr/$expected/, $bytes_out_used,
      test_msg("Expected $expected, got $bytes_out_used"));

    $expected = '^(0.0|0)$';
    $self->assert(qr/$expected/, $bytes_xfer_used,
      test_msg("Expected $expected, got $bytes_xfer_used"));

    $expected = 1;
    $self->assert($expected == $files_in_used,
      test_msg("Expected $expected, got $files_in_used"));

    $expected = 0;
    $self->assert($expected == $files_out_used,
      test_msg("Expected $expected, got $files_out_used"));

    $expected = 0;
    $self->assert($expected == $files_xfer_used,
      test_msg("Expected $expected, got $files_xfer_used"));
  };
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

sub quotatab_stor_ok_group_limit {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user1 = 'proftpd';
  my $group = 'ftpd';
  my $passwd = 'test';
  my $home_dir1 = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($home_dir1);

  my $uid1 = 500;
  my $gid = 500;

  my $user2 = 'proftpd2';
  my $home_dir2 = File::Spec->rel2abs("$tmpdir/bar");
  mkpath($home_dir2);

  my $uid2 = 1000;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user1', '$passwd', $uid1, $gid, '$home_dir1', '/bin/bash');
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user2', '$passwd', $uid2, $gid, '$home_dir2', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user1,$user2');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$group', 'group', 'false', 'soft', 32, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
        SQLNamedQuery => 'get-user-info SELECT "userid, passwd, uid, gid, homedir, shell FROM users WHERE userid=\'%U\'"',
        SQLUserInfo => 'custom:/get-user-info',
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

      # Login as user1, and upload a file
      $client->login($user1, $passwd);

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

      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # Login as user2, and upload a file
      $client->login($user2, $passwd);

      $conn = $client->stor_raw('test.txt');
      unless ($conn) {
        die("Failed to STOR test.txt: " . $client->response_code() . " " .
          $client->response_msg());
      }

      $buf = "Hello, World\n";
      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$group\'");

  my $expected;

  $expected = 'group';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(26.0|26)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected, got $bytes_xfer_used"));

  $expected = 2;
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

sub quotatab_stor_ok_group_limit_bytes_in_exceeded_soft_limit  {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user1 = 'proftpd';
  my $group = 'ftpd';
  my $passwd = 'test';
  my $home_dir1 = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($home_dir1);

  my $uid1 = 500;
  my $gid = 500;

  my $user2 = 'proftpd2';
  my $home_dir2 = File::Spec->rel2abs("$tmpdir/bar");
  mkpath($home_dir2);

  my $uid2 = 1000;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user1', '$passwd', $uid1, $gid, '$home_dir1', '/bin/bash');
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user2', '$passwd', $uid2, $gid, '$home_dir2', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user1,$user2');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$group', 'group', 'false', 'soft', 5, 0, 0, 3, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

      # Login as user1, and upload a file
      $client->login($user1, $passwd);

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

      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # Login as user2, and upload a file
      $client->login($user2, $passwd);

      $conn = $client->stor_raw('test.txt');
      if ($conn) {
        die("STOR test.txt succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected = 552;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'STOR denied: quota exceeded: used \S+ of \S+ upload bytes';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

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

sub quotatab_stor_ok_group_limit_bytes_in_exceeded_hard_limit  {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user1 = 'proftpd';
  my $group = 'ftpd';
  my $passwd = 'test';
  my $home_dir1 = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($home_dir1);

  my $uid1 = 500;
  my $gid = 500;

  my $user2 = 'proftpd2';
  my $home_dir2 = File::Spec->rel2abs("$tmpdir/bar");
  mkpath($home_dir2);

  my $uid2 = 1000;

  my $test_file = File::Spec->rel2abs("$tmpdir/bar/test.txt");

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user1', '$passwd', $uid1, $gid, '$home_dir1', '/bin/bash');
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user2', '$passwd', $uid2, $gid, '$home_dir2', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user1,$user2');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$group', 'group', 'false', 'hard', 20, 0, 0, 3, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

      # Login as user1, and upload a file
      $client->login($user1, $passwd);

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

      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # Login as user2, and upload a file
      $client->login($user2, $passwd);

      $conn = $client->stor_raw('test.txt');
      unless ($conn) {
        die("Failed to STOR test.txt: " . $client->response_code() . " " .
          $client->response_msg());
      }

      $buf = "Hello, World\n";
      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected = 552;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'Transfer aborted. (Disc|Disk) quota exceeded';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $client->quit();

      if (-f $test_file) {
        die("$test_file exists, should have been deleted");
      }
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

sub quotatab_stor_ok_group_limit_files_in_exceeded  {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user1 = 'proftpd';
  my $group = 'ftpd';
  my $passwd = 'test';
  my $home_dir1 = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($home_dir1);

  my $uid1 = 500;
  my $gid = 500;

  my $user2 = 'proftpd2';
  my $home_dir2 = File::Spec->rel2abs("$tmpdir/bar");
  mkpath($home_dir2);

  my $uid2 = 1000;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user1', '$passwd', $uid1, $gid, '$home_dir1', '/bin/bash');
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user2', '$passwd', $uid2, $gid, '$home_dir2', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user1,$user2');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$group', 'group', 'false', 'soft', 32, 0, 0, 1, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

      # Login as user1, and upload a file
      $client->login($user1, $passwd);

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

      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # Login as user2, and upload a file
      $client->login($user2, $passwd);

      $conn = $client->stor_raw('test2.txt');
      if ($conn) {
        die("STOR test2.txt succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected = 552;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'STOR: notice: quota reached: used \d+ of \d+ upload file';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));
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

sub quotatab_stor_ok_group_limit_with_default {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user1 = 'proftpd';
  my $group = 'ftpd';
  my $passwd = 'test';
  my $home_dir1 = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($home_dir1);

  my $uid1 = 500;
  my $gid = 500;

  my $user2 = 'proftpd2';
  my $home_dir2 = File::Spec->rel2abs("$tmpdir/bar");
  mkpath($home_dir2);

  my $uid2 = 1000;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user1', '$passwd', $uid1, $gid, '$home_dir1', '/bin/bash');
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user2', '$passwd', $uid2, $gid, '$home_dir2', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user1,$user2');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$group', 'group', 'false', 'soft', 32, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
        'QuotaDefault group false hard 0 1 0 3 0 0',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
        SQLNamedQuery => 'get-user-info SELECT "userid, passwd, uid, gid, homedir, shell FROM users WHERE userid=\'%U\'"',
        SQLUserInfo => 'custom:/get-user-info',
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

      # Login as user1, and upload a file
      $client->login($user1, $passwd);

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

      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # Login as user2, and upload a file
      $client->login($user2, $passwd);

      $conn = $client->stor_raw('test.txt');
      unless ($conn) {
        die("Failed to STOR test.txt: " . $client->response_code() . " " .
          $client->response_msg());
      }

      $buf = "Hello, World\n";
      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$group\'");

  my $expected;

  $expected = 'group';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(26.0|26)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected, got $bytes_xfer_used"));

  $expected = 2;
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

sub quotatab_stor_ok_class_limit {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user1 = 'proftpd';
  my $group = 'ftpd';
  my $passwd = 'test';
  my $home_dir1 = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($home_dir1);

  my $uid1 = 500;
  my $gid = 500;

  my $user2 = 'proftpd2';
  my $home_dir2 = File::Spec->rel2abs("$tmpdir/bar");
  mkpath($home_dir2);

  my $uid2 = 1000;

  my $class = 'test';

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user1', '$passwd', $uid1, $gid, '$home_dir1', '/bin/bash');
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user2', '$passwd', $uid2, $gid, '$home_dir2', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$class', 'class', 'false', 'soft', 32, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    Class => {
      $class => {
        From => '127.0.0.1',
      },
    },

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

      # Login as user1, and upload a file
      $client->login($user1, $passwd);

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

      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # Login as user2, and upload a file
      $client->login($user2, $passwd);

      $conn = $client->stor_raw('test.txt');
      unless ($conn) {
        die("Failed to STOR test.txt: " . $client->response_code() . " " .
          $client->response_msg());
      }

      $buf = "Hello, World\n";
      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$class\'");

  my $expected;

  $expected = 'class';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(26.0|26)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected, got $bytes_xfer_used"));

  $expected = 2;
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

sub quotatab_stor_ok_class_limit_bytes_in_exceeded_soft_limit {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user1 = 'proftpd';
  my $group = 'ftpd';
  my $passwd = 'test';
  my $home_dir1 = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($home_dir1);

  my $uid1 = 500;
  my $gid = 500;

  my $user2 = 'proftpd2';
  my $home_dir2 = File::Spec->rel2abs("$tmpdir/bar");
  mkpath($home_dir2);

  my $uid2 = 1000;

  my $class = 'test';

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user1', '$passwd', $uid1, $gid, '$home_dir1', '/bin/bash');
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user2', '$passwd', $uid2, $gid, '$home_dir2', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$class', 'class', 'false', 'soft', 5, 0, 0, 3, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    Class => {
      $class => {
        From => '127.0.0.1',
      },
    },

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

      # Login as user1, and upload a file
      $client->login($user1, $passwd);

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

      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # Login as user2, and upload a file
      $client->login($user2, $passwd);

      $conn = $client->stor_raw('test.txt');
      if ($conn) {
        die("STOR test.txt succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected = 552;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'STOR denied: quota exceeded: used \S+ of \S+ upload bytes';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

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

sub quotatab_stor_ok_class_limit_bytes_in_exceeded_hard_limit {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user1 = 'proftpd';
  my $group = 'ftpd';
  my $passwd = 'test';
  my $home_dir1 = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($home_dir1);

  my $uid1 = 500;
  my $gid = 500;

  my $user2 = 'proftpd2';
  my $home_dir2 = File::Spec->rel2abs("$tmpdir/bar");
  mkpath($home_dir2);

  my $uid2 = 1000;

  my $class = 'test';

  my $test_file = File::Spec->rel2abs("$tmpdir/bar/test.txt");

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user1', '$passwd', $uid1, $gid, '$home_dir1', '/bin/bash');
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user2', '$passwd', $uid2, $gid, '$home_dir2', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$class', 'class', 'false', 'hard', 20, 0, 0, 3, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    Class => {
      $class => {
        From => '127.0.0.1',
      },
    },

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

      # Login as user1, and upload a file
      $client->login($user1, $passwd);

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

      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # Login as user2, and upload a file
      $client->login($user2, $passwd);

      $conn = $client->stor_raw('test.txt');
      unless ($conn) {
        die("Failed to STOR test.txt: " . $client->response_code() . " " .
          $client->response_msg());
      }

      $buf = "Hello, World\n";
      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected = 552;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'Transfer aborted. (Disc|Disk) quota exceeded';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $client->quit();

      if (-f $test_file) {
        die("$test_file exists, should have been deleted");
      }
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

sub quotatab_stor_ok_class_limit_files_in_exceeded {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user1 = 'proftpd';
  my $group = 'ftpd';
  my $passwd = 'test';
  my $home_dir1 = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($home_dir1);

  my $uid1 = 500;
  my $gid = 500;

  my $user2 = 'proftpd2';
  my $home_dir2 = File::Spec->rel2abs("$tmpdir/bar");
  mkpath($home_dir2);

  my $uid2 = 1000;

  my $class = 'test';

  my $test_file = File::Spec->rel2abs("$tmpdir/bar/test.txt");

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user1', '$passwd', $uid1, $gid, '$home_dir1', '/bin/bash');
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user2', '$passwd', $uid2, $gid, '$home_dir2', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$class', 'class', 'false', 'hard', 32, 0, 0, 1, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    Class => {
      $class => {
        From => '127.0.0.1',
      },
    },

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

      # Login as user1, and upload a file
      $client->login($user1, $passwd);

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

      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # Login as user2, and upload a file
      $client->login($user2, $passwd);

      $conn = $client->stor_raw('test2.txt');
      if ($conn) {
        die("STOR test2.txt succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected = 552;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'STOR: notice: quota reached: used \d+ of \d+ upload file';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));
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

sub quotatab_stor_ok_all_limit {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user1 = 'proftpd';
  my $group = 'ftpd';
  my $passwd = 'test';
  my $home_dir1 = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($home_dir1);

  my $uid1 = 500;
  my $gid = 500;

  my $user2 = 'proftpd2';
  my $home_dir2 = File::Spec->rel2abs("$tmpdir/bar");
  mkpath($home_dir2);

  my $uid2 = 1000;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user1', '$passwd', $uid1, $gid, '$home_dir1', '/bin/bash');
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user2', '$passwd', $uid2, $gid, '$home_dir2', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('', 'all', 'false', 'soft', 32, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

      # Login as user1, and upload a file
      $client->login($user1, $passwd);

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

      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # Login as user2, and upload a file
      $client->login($user2, $passwd);

      $conn = $client->stor_raw('test.txt');
      unless ($conn) {
        die("Failed to STOR test.txt: " . $client->response_code() . " " .
          $client->response_msg());
      }

      $buf = "Hello, World\n";
      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'\'");

  my $expected;

  $expected = 'all';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(26.0|26)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected, got $bytes_xfer_used"));

  $expected = 2;
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

sub quotatab_stor_ok_all_limit_bytes_in_exceeded_soft_limit {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user1 = 'proftpd';
  my $group = 'ftpd';
  my $passwd = 'test';
  my $home_dir1 = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($home_dir1);

  my $uid1 = 500;
  my $gid = 500;

  my $user2 = 'proftpd2';
  my $home_dir2 = File::Spec->rel2abs("$tmpdir/bar");
  mkpath($home_dir2);

  my $uid2 = 1000;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user1', '$passwd', $uid1, $gid, '$home_dir1', '/bin/bash');
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user2', '$passwd', $uid2, $gid, '$home_dir2', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('', 'all', 'false', 'soft', 5, 0, 0, 3, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

      # Login as user1, and upload a file
      $client->login($user1, $passwd);

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

      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # Login as user2, and upload a file
      $client->login($user2, $passwd);

      $conn = $client->stor_raw('test.txt');
      if ($conn) {
        die("STOR test.txt succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected = 552;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'STOR denied: quota exceeded: used \S+ of \S+ upload bytes';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

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

sub quotatab_stor_ok_all_limit_bytes_in_exceeded_hard_limit {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user1 = 'proftpd';
  my $group = 'ftpd';
  my $passwd = 'test';
  my $home_dir1 = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($home_dir1);

  my $uid1 = 500;
  my $gid = 500;

  my $user2 = 'proftpd2';
  my $home_dir2 = File::Spec->rel2abs("$tmpdir/bar");
  mkpath($home_dir2);

  my $uid2 = 1000;

  my $test_file = File::Spec->rel2abs("$tmpdir/bar/test.txt");

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user1', '$passwd', $uid1, $gid, '$home_dir1', '/bin/bash');
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user2', '$passwd', $uid2, $gid, '$home_dir2', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('', 'all', 'false', 'hard', 20, 0, 0, 3, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

      # Login as user1, and upload a file
      $client->login($user1, $passwd);

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

      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # Login as user2, and upload a file
      $client->login($user2, $passwd);

      $conn = $client->stor_raw('test.txt');
      unless ($conn) {
        die("Failed to STOR test.txt: " . $client->response_code() . " " .
          $client->response_msg());
      }

      $buf = "Hello, World\n";
      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected = 552;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'Transfer aborted. (Disc|Disk) quota exceeded';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $client->quit();

      if (-f $test_file) {
        die("$test_file exists, should have been deleted");
      }
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

sub quotatab_stor_ok_all_limit_files_in_exceeded {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user1 = 'proftpd';
  my $group = 'ftpd';
  my $passwd = 'test';
  my $home_dir1 = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($home_dir1);

  my $uid1 = 500;
  my $gid = 500;

  my $user2 = 'proftpd2';
  my $home_dir2 = File::Spec->rel2abs("$tmpdir/bar");
  mkpath($home_dir2);

  my $uid2 = 1000;

  my $test_file = File::Spec->rel2abs("$tmpdir/bar/test.txt");

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user1', '$passwd', $uid1, $gid, '$home_dir1', '/bin/bash');
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user2', '$passwd', $uid2, $gid, '$home_dir2', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('', 'all', 'false', 'hard', 32, 0, 0, 1, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

      # Login as user1, and upload a file
      $client->login($user1, $passwd);

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

      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # Login as user2, and upload a file
      $client->login($user2, $passwd);

      $conn = $client->stor_raw('test2.txt');
      if ($conn) {
        die("STOR test2.txt succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected = 552;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'STOR: notice: quota reached: used \d+ of \d+ upload file';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));
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

sub quotatab_stor_bug3164 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 32, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

      $wfh->print("do_update\n");
      $wfh->flush();

      sleep(1);

      # This STOR should fail, since the out-of-band update filled up the
      # available file upload slots.
      my $conn = $client->stor_raw('test.txt');
      if ($conn) {
        die("STOR test.txt succeeded unexpectedly"); 
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 552;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "STOR: notice: quota reached: used 2 of 2 upload files";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { bug3164_server_wait($config_file, $db_file, $rfh) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  # Stop server
  server_stop($pid_file);

  $self->assert_child_ok($pid);

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$user\'");

  my $expected;

  $expected = 'user';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(10.0|10)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected bytes_in_used, got $bytes_in_used"));

  $expected = '^(10.0|10)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected bytes_out_used, got $bytes_out_used"));

  $expected = '^(10.0|10)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected bytes_xfer_used, got $bytes_xfer_used"));

  $expected = 2;
  $self->assert($expected == $files_in_used,
    test_msg("Expected $expected files_in_used, got $files_in_used"));

  $expected = 2;
  $self->assert($expected == $files_out_used,
    test_msg("Expected $expected files_out_used, got $files_out_used"));

  $expected = 2;
  $self->assert($expected == $files_xfer_used,
    test_msg("Expected $expected files_xfer_used, got $files_xfer_used"));

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub quotatab_dele_ok_user_limit {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0775, $home_dir)) {
      die("Can't set perms on $home_dir to 0775: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 32, 0, 32, 3, 0, 3);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);

EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $test_sz = (stat($test_file))[7];

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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
      $client->dele('test.txt');

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      $client->quit();

      my $expected;

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "DELE command successful";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));
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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$user\'");

  my $expected;

  $expected = 'user';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(-14.0|-14)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected, got $bytes_xfer_used"));

  $expected = -1;
  $self->assert($expected == $files_in_used,
    test_msg("Expected $expected, got $files_in_used"));

  $expected = 0;
  $self->assert($expected == $files_out_used,
    test_msg("Expected $expected, got $files_out_used"));

  $expected = 0;
  $self->assert($expected == $files_xfer_used,
    test_msg("Expected $expected, got $files_xfer_used"));

  unlink($log_file);
}

sub quotatab_dele_user_owner_bug3161 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0775, $home_dir)) {
      die("Can't set perms on $home_dir to 0775: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  my $other_user = 'liz';

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$other_user', '$passwd', 777, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user,$other_user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 32, 0, 0, 2, 0, 0);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$other_user', 'user', 'false', 'soft', 32, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
INSERT INTO quotatallies (name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used) VALUES ('$user', 'user',  32, 0, 0, 2, 0, 0);
INSERT INTO quotatallies (name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used) VALUES ('$other_user', 'user',  32, 0, 0, 2, 0, 0);

EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  unless (chown(777, 500, $test_file)) {
    die("Can't chown() $test_file to UID 777, GID 500: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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
      $client->dele('test.txt');

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      $client->quit();

      my $expected;

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "DELE command successful";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));
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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$user\'");

  my $expected;

  $expected = 'user';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(32.0|32)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected, got $bytes_xfer_used"));

  $expected = 2;
  $self->assert($expected == $files_in_used,
    test_msg("Expected $expected, got $files_in_used"));

  $expected = 0;
  $self->assert($expected == $files_out_used,
    test_msg("Expected $expected, got $files_out_used"));

  $expected = 0;
  $self->assert($expected == $files_xfer_used,
    test_msg("Expected $expected, got $files_xfer_used"));

  ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$other_user\'");

  $expected = 'user';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(18.0|18)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected, got $bytes_xfer_used"));

  $expected = 1;
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

sub quotatab_dele_group_owner_bug3161 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0775, $home_dir)) {
      die("Can't set perms on $home_dir to 0775: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  my $other_user = 'liz';
  my $other_group = 'sxsw';

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$other_user', '$passwd', 777, 777, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');
INSERT INTO groups (groupname, gid, members) VALUES ('$other_group', 777, '$other_user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 32, 0, 0, 2, 0, 0);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$other_group', 'group', 'false', 'soft', 32, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
INSERT INTO quotatallies (name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used) VALUES ('$user', 'user',  32, 0, 0, 2, 0, 0);
INSERT INTO quotatallies (name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used) VALUES ('$other_group', 'group',  32, 0, 0, 2, 0, 0);

EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  unless (chown(777, 777, $test_file)) {
    die("Can't chown() $test_file to UID 777, GID 500: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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
      $client->dele('test.txt');

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      $client->quit();

      my $expected;

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "DELE command successful";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));
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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$user\'");

  my $expected;

  $expected = 'user';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(32.0|32)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected, got $bytes_xfer_used"));

  $expected = 2;
  $self->assert($expected == $files_in_used,
    test_msg("Expected $expected, got $files_in_used"));

  $expected = 0;
  $self->assert($expected == $files_out_used,
    test_msg("Expected $expected, got $files_out_used"));

  $expected = 0;
  $self->assert($expected == $files_xfer_used,
    test_msg("Expected $expected, got $files_xfer_used"));

  ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$other_group\'");

  $expected = 'group';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(18.0|18)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected, got $bytes_xfer_used"));

  $expected = 1;
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

sub quotatab_new_tally_lock_bug3086 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0775, $home_dir)) {
      die("Can't set perms on $home_dir to 0775: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 32, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $quota_lock = File::Spec->rel2abs("$tmpdir/quota.lock");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'lock:10',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        "QuotaLock $quota_lock",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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
      $client->quit();

      # Make sure the QuotaLock file now exists. */
      $self->assert(-f $quota_lock,
        test_msg("$quota_lock file does not exist as expected"));
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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$user\'");

  my $expected;

  $expected = 'user';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
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

sub quotatab_config_exclude_filter_bug3298 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 32, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $exclude_filter = $tmpdir;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
        "QuotaExcludeFilter $exclude_filter",
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$user\'");

  my $expected;

  $expected = 'user';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
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

sub quotatab_config_exclude_filter_chrooted_bug3298 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 32, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultRoot => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
        "QuotaExcludeFilter $tmpdir",
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$user\'");

  my $expected;

  $expected = 'user';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
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

sub quotatab_config_exclude_filter_bug3878 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'hard', 32, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $exclude_filter = $tmpdir;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
        "QuotaExcludeFilter $exclude_filter",
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

      my $buf = "ABCD" x 9;
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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$user\'");

  my $expected;

  $expected = 'user';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
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

sub quotatab_config_opt_scanonlogin {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs("$tmpdir/home/$user");
  mkpath($home_dir);
  my $uid = 500;
  my $gid = 500;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 32, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
INSERT INTO quotatallies (name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used) VALUES ('$user', 'user',  0, 0, 0, 0, 0, 0);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $test_file = File::Spec->rel2abs("$home_dir/welcome.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh <<EOH;
Hello, World.  This is a simple text file used in a regression
test of proftpd mod_quotatab's ScanOnLogin feature.
EOH
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $sub_dir = File::Spec->rel2abs("$home_dir/subdir");
  mkpath($sub_dir);

  my $test_file2 = File::Spec->rel2abs("$sub_dir/test.txt");
  if (open(my $fh, "> $test_file2")) {
    print $fh "Just another test file.\n";

    unless (close($fh)) {
      die("Can't write $test_file2: $!");
    }

  } else {
    die("Can't open $test_file2: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir, $test_file, $test_file2)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir, $test_file, $test_file2)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        "QuotaOptions ScanOnLogin",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$user\'");

  my $expected;

  $expected = 'user';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(139.0|139)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected, got $bytes_xfer_used"));

  $expected = 2;
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

sub quotatab_config_opt_scanonlogin_chrooted {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs("$tmpdir/home/$user");
  mkpath($home_dir);
  my $uid = 500;
  my $gid = 500;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 32, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
INSERT INTO quotatallies (name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used) VALUES ('$user', 'user',  0, 0, 0, 0, 0, 0);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $test_file = File::Spec->rel2abs("$home_dir/welcome.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh <<EOH;
Hello, World.  This is a simple text file used in a regression
test of proftpd mod_quotatab's ScanOnLogin feature.
EOH
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $sub_dir = File::Spec->rel2abs("$home_dir/subdir");
  mkpath($sub_dir);

  my $test_file2 = File::Spec->rel2abs("$sub_dir/test.txt");
  if (open(my $fh, "> $test_file2")) {
    print $fh "Just another test file.\n";

    unless (close($fh)) {
      die("Can't write $test_file2: $!");
    }

  } else {
    die("Can't open $test_file2: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir, $test_file, $test_file2)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir, $test_file, $test_file2)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultRoot => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        "QuotaOptions ScanOnLogin",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$user\'");

  my $expected;

  $expected = 'user';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(139.0|139)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected, got $bytes_xfer_used"));

  $expected = 2;
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

sub quotatab_config_opt_scanonlogin_new_tally_bug3440 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs("$tmpdir/home/$user");
  mkpath($home_dir);
  my $uid = 500;
  my $gid = 500;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 32, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $test_file = File::Spec->rel2abs("$home_dir/welcome.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh <<EOH;
Hello, World.  This is a simple text file used in a regression
test of proftpd mod_quotatab's ScanOnLogin feature.
EOH
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $sub_dir = File::Spec->rel2abs("$home_dir/subdir");
  mkpath($sub_dir);

  my $test_file2 = File::Spec->rel2abs("$sub_dir/test.txt");
  if (open(my $fh, "> $test_file2")) {
    print $fh "Just another test file.\n";

    unless (close($fh)) {
      die("Can't write $test_file2: $!");
    }

  } else {
    die("Can't open $test_file2: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir, $test_file, $test_file2)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir, $test_file, $test_file2)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        "QuotaOptions ScanOnLogin",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$user\'");

  my $expected;

  $expected = 'user';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(139.0|139)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected, got $bytes_xfer_used"));

  $expected = 2;
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

sub quotatab_site_bug3483 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs("$tmpdir/home/$user");
  mkpath($home_dir);
  my $uid = 500;
  my $gid = 500;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 32, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

      eval { $client->site("") };
      unless ($@) {
        die("SITE command succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 500;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "'SITE' requires parameters";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

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

sub quotatab_dele_failed_bug3517 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0775, $home_dir)) {
      die("Can't set perms on $home_dir to 0775: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 32, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
INSERT INTO quotatallies (name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used) VALUES ('$user', 'user',  32, 0, 0, 2, 0, 0);

EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

      my $test_file = 'test.txt';

      eval { $client->dele($test_file) };
      unless ($@) {
        die("DELE $test_file succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      $client->quit();

      my $expected;

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "$test_file: No such file or directory";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));
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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$user\'");

  my $expected;

  $expected = 'user';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(32.0|32)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected, got $bytes_xfer_used"));

  $expected = 2;
  $self->assert($expected == $files_in_used,
    test_msg("Expected $expected, got $files_in_used"));

  $expected = 0;
  $self->assert($expected == $files_out_used,
    test_msg("Expected $expected, got $files_out_used"));

  $expected = 0;
  $self->assert($expected == $files_xfer_used,
    test_msg("Expected $expected, got $files_xfer_used"));

  unlink($log_file);
}

sub quotatab_sql_dele_bug3524 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0775, $home_dir)) {
      die("Can't set perms on $home_dir to 0775: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 32, 0, 32, 3, 0, 3);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
INSERT INTO quotatallies (name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used) VALUES ('$user', 'user',  30, 0, 30, 2, 0, 2);

EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $test_sz = (stat($test_file))[7];

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

      $client->site('QUOTA');
      my $resp_msgs = $client->response_msgs();

      my $expected;

      $expected = '\s+?Uploaded bytes:\s+?30.00/32.00';
      my $line = $resp_msgs->[5];
      chomp($line);
      $self->assert(qr/$expected/, $line,
        test_msg("Expected '$expected', got '$line'"));

      $expected = '\s+?Uploaded files:\s+?2/3';
      $line = $resp_msgs->[8];
      chomp($line);
      $self->assert(qr/$expected/, $line,
        test_msg("Expected '$expected', got '$line'"));

      $client->dele('test.txt');

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "DELE command successful";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $client->site('QUOTA');
      $resp_msgs = $client->response_msgs();

      $expected = '\s+?Uploaded bytes:\s+?16.00/32.00';
      $line = $resp_msgs->[5];
      chomp($line);
      $self->assert(qr/$expected/, $line,
        test_msg("Expected '$expected', got '$line"));

      $expected = '\s+?Uploaded files:\s+?1/3';
      $line = $resp_msgs->[8];
      chomp($line);
      $self->assert(qr/$expected/, $line,
        test_msg("Expected '$expected', got '$line'"));

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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$user\'");

  my $expected;

  $expected = 'user';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(16.0|16)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected bytes_in_used, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected bytes_out_used, got $bytes_out_used"));

  $expected = '^(30.0|30)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected bytes_xfer_used, got $bytes_xfer_used"));

  $expected = 1;
  $self->assert($expected == $files_in_used,
    test_msg("Expected $expected files_in_used, got $files_in_used"));

  $expected = 0;
  $self->assert($expected == $files_out_used,
    test_msg("Expected $expected files_out_used, got $files_out_used"));

  $expected = 2;
  $self->assert($expected == $files_xfer_used,
    test_msg("Expected $expected files_xfer_used, got $files_xfer_used"));

  unlink($log_file);
}

sub quotatab_stor_deleteabortedstores_conn_abor_bug3621 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 32, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',
    DeleteAbortedStores => 'on',
    TimeoutLinger => 0,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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
      $conn->abort();

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      $self->assert_transfer_ok($resp_code, $resp_msg, 1);
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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$user\'");

  my $expected;

  $expected = 'user';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
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

sub quotatab_stor_deleteabortedstores_cmd_abor_bug3621 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 32, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',
    DeleteAbortedStores => 'on',
    TimeoutLinger => 0,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

      $client->quote('ABOR');

      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 426;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Transfer aborted. Data connection closed";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));
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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$user\'");

  my $expected;

  $expected = 'user';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
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

sub quotatab_sql_addl_query_columns_bug3879 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/quotatab.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/quotatab.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/quotatab.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT PRIMARY KEY,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT PRIMARY KEY,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL,
  ip_addr TEXT NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail, ip_addr) VALUES ('$user', 'user', 'false', 'soft', 32, 0, 0, 2, 0, 0, '127.0.0.1');

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL,
  ip_addr TEXT NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail, ip_addr FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\' AND ip_addr = \'%a\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used, ip_addr FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\' AND ip_addr = \'%a\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\' AND ip_addr = \'%a\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}, \'%a\'" quotatallies',

        'QuotaEngine on',
        "QuotaLog $log_file",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => '0',
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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$user\'");

  my $expected;

  $expected = 'user';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(13.0|13)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected, got $bytes_xfer_used"));

  $expected = 1;
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

# See:
#  https://forums.proftpd.org/smf/index.php/topic,11862.0.html
#
# Note that this is more for diagnosing ODBC issues than quotatab issues.
sub quotatab_sql_odbc {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'quotatab');

  my $odbcini_path = File::Spec->rel2abs("t/etc/modules/mod_sql_odbc/odbc.ini");
  my $odbcinst_path = File::Spec->rel2abs("t/etc/modules/mod_sql_odbc/odbcinst.ini");

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE quotalimits (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  per_session TEXT NOT NULL,
  limit_type TEXT NOT NULL,
  bytes_in_avail REAL NOT NULL,
  bytes_out_avail REAL NOT NULL,
  bytes_xfer_avail REAL NOT NULL,
  files_in_avail INTEGER NOT NULL,
  files_out_avail INTEGER NOT NULL,
  files_xfer_avail INTEGER NOT NULL
);
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$setup->{user}', 'user', 'false', 'soft', 32, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL PRIMARY KEY,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    AuthOrder => 'mod_auth_file.c',
    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_quotatab_sql.c' => [
        'SQLNamedQuery get-quota-limit SELECT "name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail FROM quotalimits WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery get-quota-tally SELECT "name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used FROM quotatallies WHERE name = \'%{0}\' AND quota_type = \'%{1}\'"',
        'SQLNamedQuery update-quota-tally UPDATE "bytes_in_used = bytes_in_used + %{0}, bytes_out_used = bytes_out_used + %{1}, bytes_xfer_used = bytes_xfer_used + %{2}, files_in_used = files_in_used + %{3}, files_out_used = files_out_used + %{4}, files_xfer_used = files_xfer_used + %{5} WHERE name = \'%{6}\' AND quota_type = \'%{7}\'" quotatallies',
        'SQLNamedQuery insert-quota-tally INSERT "%{0}, %{1}, %{2}, %{3}, %{4}, %{5}, %{6}, %{7}" quotatallies',

        'QuotaEngine on',
        "QuotaLog $setup->{log_file}",
        'QuotaLimitTable sql:/get-quota-limit',
        'QuotaTallyTable sql:/get-quota-tally/update-quota-tally/insert-quota-tally',
      ],

      'mod_sql.c' => {
        SQLAuthenticate => 'off',
        SQLEngine => 'on',
        SQLBackend => 'odbc',
        SQLConnectInfo => "mysql proftpd developer PERCONNECTION",
        SQLLogFile => $setup->{log_file},
        SQLOptions => 'NoDisconnectOnError',
      },

      'mod_sql_odbc.c' => {
        SQLODBCVersion => '2',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($setup->{config_file},
    $config);

  if (open(my $fh, ">> $setup->{config_file}")) {
    print $fh <<EOC;
# Necessary ODBC environment variables
SetEnv ODBCINST $odbcinst_path
SetEnv ODBCINI $odbcini_path
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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      $client->login($setup->{user}, $setup->{passwd});

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
