package ProFTPD::Tests::Modules::mod_quotatab::copy;

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
  quotatab_site_copy_user_limit_bug3641 => {
    order => ++$order,
    test_class => [qw(bug forking mod_copy)],
  },

  quotatab_site_copy_user_limit_bytes_in_exceeded_soft_limit_bug3641 => {
    order => ++$order,
    test_class => [qw(bug forking mod_copy)],
  },

  quotatab_site_copy_user_limit_bytes_in_exceeded_hard_limit_bug3641 => {
    order => ++$order,
    test_class => [qw(bug forking mod_copy)],
  },

  quotatab_site_copy_user_limit_files_in_reached_bug3641 => {
    order => ++$order,
    test_class => [qw(bug forking mod_copy)],
  },

  quotatab_site_copy_user_limit_files_in_exceeded_bug3641 => {
    order => ++$order,
    test_class => [qw(bug forking mod_copy)],
  },

  quotatab_site_copy_src_dir_bug3641 => {
    order => ++$order,
    test_class => [qw(bug forking mod_copy)],
  },

  quotatab_site_copy_src_dir_bytes_in_exceeded_bug3641 => {
    order => ++$order,
    test_class => [qw(bug forking mod_copy)],
  },

  quotatab_site_copy_src_dir_bytes_in_exceeded_chrooted_bug3641 => {
    order => ++$order,
    test_class => [qw(bug forking mod_copy rootprivs)],
  },

  quotatab_site_copy_src_dir_files_in_exceeded_bug3641 => {
    order => ++$order,
    test_class => [qw(bug forking mod_copy)],
  },

  quotatab_site_copy_src_dir_files_in_exceeded_chrooted_bug3641 => {
    order => ++$order,
    test_class => [qw(bug forking mod_copy rootprivs)],
  },

  quotatab_site_copy_src_dir_directory_tally_bug3641 => {
    order => ++$order,
    test_class => [qw(bug forking mod_copy)],
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

sub quotatab_site_copy_user_limit_bug3641 {
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
  userid TEXT,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL,
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
  name TEXT NOT NULL,
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

  my $src_file = File::Spec->rel2abs("$tmpdir/foo.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/bar.txt");

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

      my ($resp_code, $resp_msg) = $client->site('CPFR', 'foo.txt');
 
      my $expected;

      $expected = 350;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "File or directory exists, ready for destination name";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      ($resp_code, $resp_msg) = $client->site('CPTO', 'bar.txt');
      
      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Copy successful";
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

  $expected = '^(14.0|14)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected bytes-in-used, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected bytes-out-used, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected bytes-xfer-used, got $bytes_xfer_used"));

  $expected = 1;
  $self->assert($expected == $files_in_used,
    test_msg("Expected $expected files-in-used, got $files_in_used"));

  $expected = 0;
  $self->assert($expected == $files_out_used,
    test_msg("Expected $expected files-out-used, got $files_out_used"));

  $expected = 0;
  $self->assert($expected == $files_xfer_used,
    test_msg("Expected $expected files-xfer-used, got $files_xfer_used"));

  unlink($log_file);
}

sub quotatab_site_copy_user_limit_bytes_in_exceeded_soft_limit_bug3641 {
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
  userid TEXT,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL,
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
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 5, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL,
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

  my $src_file = File::Spec->rel2abs("$tmpdir/foo.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/bar.txt");

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

      my ($resp_code, $resp_msg) = $client->site('CPFR', 'foo.txt');
 
      my $expected;

      $expected = 350;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "File or directory exists, ready for destination name";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      ($resp_code, $resp_msg) = $client->site('CPTO', 'bar.txt');
      
      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'COPY: notice: quota reached: used \S+ of \S+ upload bytes';
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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$user\'");

  my $expected;

  $expected = 'user';
  $self->assert($expected eq $quota_type,
    test_msg("Expected '$expected', got '$quota_type'"));

  $expected = '^(14.0|14)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected bytes-in-used, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected bytes-out-used, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected bytes-xfer-used, got $bytes_xfer_used"));

  $expected = 1;
  $self->assert($expected == $files_in_used,
    test_msg("Expected $expected files-in-used, got $files_in_used"));

  $expected = 0;
  $self->assert($expected == $files_out_used,
    test_msg("Expected $expected files-out-used, got $files_out_used"));

  $expected = 0;
  $self->assert($expected == $files_xfer_used,
    test_msg("Expected $expected files-xfer-used, got $files_xfer_used"));

  unlink($log_file);
}

sub quotatab_site_copy_user_limit_bytes_in_exceeded_hard_limit_bug3641 {
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
  userid TEXT,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL,
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
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'hard', 5, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL,
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

  my $src_file = File::Spec->rel2abs("$tmpdir/foo.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/bar.txt");

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

      my ($resp_code, $resp_msg) = $client->site('CPFR', 'foo.txt');
 
      my $expected;

      $expected = 350;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "File or directory exists, ready for destination name";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      ($resp_code, $resp_msg) = $client->site('CPTO', 'bar.txt');
      
      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'COPY: notice: quota reached: used \S+ of \S+ upload bytes';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $resp_msg = $client->response_msg(2);
      $expected = "COPY: notice: quota reached: 'bar.txt' removed";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $self->assert(!-f $dst_file,
        test_msg("File $dst_file exists unexpectedly"));
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

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected bytes-in-used, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected bytes-out-used, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected bytes-xfer-used, got $bytes_xfer_used"));

  $expected = 0;
  $self->assert($expected == $files_in_used,
    test_msg("Expected $expected files-in-used, got $files_in_used"));

  $expected = 0;
  $self->assert($expected == $files_out_used,
    test_msg("Expected $expected files-out-used, got $files_out_used"));

  $expected = 0;
  $self->assert($expected == $files_xfer_used,
    test_msg("Expected $expected files-xfer-used, got $files_xfer_used"));

  unlink($log_file);
}

sub quotatab_site_copy_user_limit_files_in_reached_bug3641 {
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
  userid TEXT,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL,
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
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'hard', 32, 0, 0, 1, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL,
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

  my $src_file = File::Spec->rel2abs("$tmpdir/foo.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/bar.txt");

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

      my ($resp_code, $resp_msg) = $client->site('CPFR', 'foo.txt');
 
      my $expected;

      $expected = 350;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "File or directory exists, ready for destination name";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      ($resp_code, $resp_msg) = $client->site('CPTO', 'bar.txt');
      
      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'COPY: notice: quota reached: used \S+ of \S+ upload file';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $self->assert(-f $dst_file,
        test_msg("File $dst_file does not exist as expected"));
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

  $expected = '^(14.0|14)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected bytes-in-used, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected bytes-out-used, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected bytes-xfer-used, got $bytes_xfer_used"));

  $expected = 1;
  $self->assert($expected == $files_in_used,
    test_msg("Expected $expected files-in-used, got $files_in_used"));

  $expected = 0;
  $self->assert($expected == $files_out_used,
    test_msg("Expected $expected files-out-used, got $files_out_used"));

  $expected = 0;
  $self->assert($expected == $files_xfer_used,
    test_msg("Expected $expected files-xfer-used, got $files_xfer_used"));

  unlink($log_file);
}

sub quotatab_site_copy_user_limit_files_in_exceeded_bug3641 {
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
  userid TEXT,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL,
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
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'hard', 32, 0, 0, 1, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL,
  quota_type TEXT NOT NULL,
  bytes_in_used REAL NOT NULL,
  bytes_out_used REAL NOT NULL,
  bytes_xfer_used REAL NOT NULL,
  files_in_used INTEGER NOT NULL,
  files_out_used INTEGER NOT NULL,
  files_xfer_used INTEGER NOT NULL
);
INSERT INTO quotatallies (name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used) VALUES ('$user', 'user', 5, 0, 0, 1, 0, 0);
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

  my $src_file = File::Spec->rel2abs("$tmpdir/foo.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/bar.txt");

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

      my ($resp_code, $resp_msg) = $client->site('CPFR', 'foo.txt');
 
      my $expected;

      $expected = 350;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "File or directory exists, ready for destination name";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      eval { $client->site('CPTO', 'bar.txt') };
      unless ($@) {
        die("SITE CPTO succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      
      $expected = 552;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'COPY denied: quota exceeded: used \S+ of \S+ upload file';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $self->assert(!-f $dst_file,
        test_msg("File $dst_file exists unexpectedly"));
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

  $expected = '^(5.0|5)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected bytes-in-used, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected bytes-out-used, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected bytes-xfer-used, got $bytes_xfer_used"));

  $expected = 1;
  $self->assert($expected == $files_in_used,
    test_msg("Expected $expected files-in-used, got $files_in_used"));

  $expected = 0;
  $self->assert($expected == $files_out_used,
    test_msg("Expected $expected files-out-used, got $files_out_used"));

  $expected = 0;
  $self->assert($expected == $files_xfer_used,
    test_msg("Expected $expected files-xfer-used, got $files_xfer_used"));

  unlink($log_file);
}

sub quotatab_site_copy_src_dir_bug3641 {
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
  userid TEXT,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL,
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
  name TEXT NOT NULL,
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

  my $src_dir = File::Spec->rel2abs("$tmpdir/src.d");
  mkpath($src_dir);

  my $src_file = File::Spec->rel2abs("$tmpdir/src.d/foo.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  $src_file = File::Spec->rel2abs("$tmpdir/src.d/bar.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_dir = File::Spec->rel2abs("$tmpdir/dst.d");

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

      my ($resp_code, $resp_msg) = $client->site('CPFR', 'src.d');
 
      my $expected;

      $expected = 350;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "File or directory exists, ready for destination name";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      ($resp_code, $resp_msg) = $client->site('CPTO', 'dst.d');
      
      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Copy successful";
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

  $expected = '^(28.0|28)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected bytes-in-used, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected bytes-out-used, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected bytes-xfer-used, got $bytes_xfer_used"));

  $expected = 2;
  $self->assert($expected == $files_in_used,
    test_msg("Expected $expected files-in-used, got $files_in_used"));

  $expected = 0;
  $self->assert($expected == $files_out_used,
    test_msg("Expected $expected files-out-used, got $files_out_used"));

  $expected = 0;
  $self->assert($expected == $files_xfer_used,
    test_msg("Expected $expected files-xfer-used, got $files_xfer_used"));

  unlink($log_file);
}

sub quotatab_site_copy_src_dir_bytes_in_exceeded_bug3641 {
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
  userid TEXT,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL,
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
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 24, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL,
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

  my $src_dir = File::Spec->rel2abs("$tmpdir/src.d");
  mkpath($src_dir);

  my $src_file = File::Spec->rel2abs("$tmpdir/src.d/foo.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  $src_file = File::Spec->rel2abs("$tmpdir/src.d/bar.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_dir = File::Spec->rel2abs("$tmpdir/dst.d");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'response:20 copy:20 quotatab:20',

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

      my ($resp_code, $resp_msg) = $client->site('CPFR', 'src.d');
 
      my $expected;

      $expected = 350;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "File or directory exists, ready for destination name";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      ($resp_code, $resp_msg) = $client->site('CPTO', 'dst.d');
      
      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "COPY: notice: quota reached: used 28.00 of 24.00 upload bytes";
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

  $expected = '^(28.0|28)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected bytes-in-used, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected bytes-out-used, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected bytes-xfer-used, got $bytes_xfer_used"));

  $expected = 2;
  $self->assert($expected == $files_in_used,
    test_msg("Expected $expected files-in-used, got $files_in_used"));

  $expected = 0;
  $self->assert($expected == $files_out_used,
    test_msg("Expected $expected files-out-used, got $files_out_used"));

  $expected = 0;
  $self->assert($expected == $files_xfer_used,
    test_msg("Expected $expected files-xfer-used, got $files_xfer_used"));

  unlink($log_file);
}

sub quotatab_site_copy_src_dir_bytes_in_exceeded_chrooted_bug3641 {
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
  userid TEXT,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL,
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
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 24, 0, 0, 2, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL,
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

  my $src_dir = File::Spec->rel2abs("$tmpdir/src.d");
  mkpath($src_dir);

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $src_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $src_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }

    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $src_file = File::Spec->rel2abs("$tmpdir/src.d/foo.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  $src_file = File::Spec->rel2abs("$tmpdir/src.d/bar.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_dir = File::Spec->rel2abs("$tmpdir/dst.d");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'response:20 copy:20 quotatab:20',

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

      my ($resp_code, $resp_msg) = $client->site('CPFR', 'src.d');
 
      my $expected;

      $expected = 350;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "File or directory exists, ready for destination name";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      ($resp_code, $resp_msg) = $client->site('CPTO', 'dst.d');
      
      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "COPY: notice: quota reached: used 28.00 of 24.00 upload bytes";
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

  $expected = '^(28.0|28)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected bytes-in-used, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected bytes-out-used, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected bytes-xfer-used, got $bytes_xfer_used"));

  $expected = 2;
  $self->assert($expected == $files_in_used,
    test_msg("Expected $expected files-in-used, got $files_in_used"));

  $expected = 0;
  $self->assert($expected == $files_out_used,
    test_msg("Expected $expected files-out-used, got $files_out_used"));

  $expected = 0;
  $self->assert($expected == $files_xfer_used,
    test_msg("Expected $expected files-xfer-used, got $files_xfer_used"));

  unlink($log_file);
}

sub quotatab_site_copy_src_dir_files_in_exceeded_bug3641 {
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
  userid TEXT,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL,
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
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 64, 0, 0, 1, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL,
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

  my $src_dir = File::Spec->rel2abs("$tmpdir/src.d");
  mkpath($src_dir);

  my $src_file = File::Spec->rel2abs("$tmpdir/src.d/foo.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  $src_file = File::Spec->rel2abs("$tmpdir/src.d/bar.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_dir = File::Spec->rel2abs("$tmpdir/dst.d");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'response:20 copy:20 quotatab:20',

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

      my ($resp_code, $resp_msg) = $client->site('CPFR', 'src.d');
 
      my $expected;

      $expected = 350;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "File or directory exists, ready for destination name";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      eval { $client->site('CPTO', 'dst.d') };
      unless ($@) {
        die("SITE CPTO succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "CPTO: Disk quota exceeded";
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

  $expected = '^(14.0|14)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected bytes-in-used, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected bytes-out-used, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected bytes-xfer-used, got $bytes_xfer_used"));

  $expected = 1;
  $self->assert($expected == $files_in_used,
    test_msg("Expected $expected files-in-used, got $files_in_used"));

  $expected = 0;
  $self->assert($expected == $files_out_used,
    test_msg("Expected $expected files-out-used, got $files_out_used"));

  $expected = 0;
  $self->assert($expected == $files_xfer_used,
    test_msg("Expected $expected files-xfer-used, got $files_xfer_used"));

  unlink($log_file);
}

sub quotatab_site_copy_src_dir_files_in_exceeded_chrooted_bug3641 {
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
  userid TEXT,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL,
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
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 64, 0, 0, 1, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL,
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

  my $src_dir = File::Spec->rel2abs("$tmpdir/src.d");
  mkpath($src_dir);

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $src_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $src_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }

    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $src_file = File::Spec->rel2abs("$tmpdir/src.d/foo.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  $src_file = File::Spec->rel2abs("$tmpdir/src.d/bar.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_dir = File::Spec->rel2abs("$tmpdir/dst.d");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'response:20 copy:20 quotatab:20',

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

      my ($resp_code, $resp_msg) = $client->site('CPFR', 'src.d');
 
      my $expected;

      $expected = 350;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "File or directory exists, ready for destination name";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      eval { $client->site('CPTO', 'dst.d') };
      unless ($@) {
        die("SITE CPTO succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "CPTO: Disk quota exceeded";
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

  $expected = '^(14.0|14)$';
  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected bytes-in-used, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected bytes-out-used, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected bytes-xfer-used, got $bytes_xfer_used"));

  $expected = 1;
  $self->assert($expected == $files_in_used,
    test_msg("Expected $expected files-in-used, got $files_in_used"));

  $expected = 0;
  $self->assert($expected == $files_out_used,
    test_msg("Expected $expected files-out-used, got $files_out_used"));

  $expected = 0;
  $self->assert($expected == $files_xfer_used,
    test_msg("Expected $expected files-xfer-used, got $files_xfer_used"));

  unlink($log_file);
}

sub quotatab_site_copy_src_dir_directory_tally_bug3641 {
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
  userid TEXT,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user');

CREATE TABLE quotalimits (
  name TEXT NOT NULL,
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
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 16384, 0, 0, 3, 0, 0);

CREATE TABLE quotatallies (
  name TEXT NOT NULL,
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

  my $src_dir = File::Spec->rel2abs("$tmpdir/src.d");
  mkpath($src_dir);

  my $src_file = File::Spec->rel2abs("$tmpdir/src.d/foo.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  $src_file = File::Spec->rel2abs("$tmpdir/src.d/bar.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_dir = File::Spec->rel2abs("$tmpdir/dst.d");

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
        'QuotaDirectoryTally on',
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

      my ($resp_code, $resp_msg) = $client->site('CPFR', 'src.d');
 
      my $expected;

      $expected = 350;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "File or directory exists, ready for destination name";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $client->site('CPTO', 'dst.d');
      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg(0);
      
      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Copy successful";
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

  $expected = '^(4124.0|4124)$';
  if ($^O eq 'linux') {
    # On Linux, the block size for a directory file might be different,
    # hence the different expectations of bytes-in-used.
    $expected = '^(8220.0|8222)$';
  }

  $self->assert(qr/$expected/, $bytes_in_used,
    test_msg("Expected $expected bytes-in-used, got $bytes_in_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_out_used,
    test_msg("Expected $expected bytes-out-used, got $bytes_out_used"));

  $expected = '^(0.0|0)$';
  $self->assert(qr/$expected/, $bytes_xfer_used,
    test_msg("Expected $expected bytes-xfer-used, got $bytes_xfer_used"));

  # For purposes of a recursive copy, a directory file counts toward the
  # "files uploaded" limit/tally.
  $expected = 3;
  $self->assert($expected == $files_in_used,
    test_msg("Expected $expected files-in-used, got $files_in_used"));

  $expected = 0;
  $self->assert($expected == $files_out_used,
    test_msg("Expected $expected files-out-used, got $files_out_used"));

  $expected = 0;
  $self->assert($expected == $files_xfer_used,
    test_msg("Expected $expected files-xfer-used, got $files_xfer_used"));

  unlink($log_file);
}

1;
