package ProFTPD::Tests::Modules::mod_sql_odbc;

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
  sql_sqllog => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_custom_user_info => {
    order => ++$order,
    test_class => [qw(forking)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub get_sessions {
  my $db_file = shift;
  my $where = shift;

  my $sql = "SELECT user, ip_addr, timestamp FROM ftpsessions";
  if ($where) {
    $sql .= " WHERE $where";
  }

  my $cmd = "sqlite3 $db_file \"$sql\"";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my $res = join('', `$cmd`);
  chomp($res);

  # The default sqlite3 delimiter is '|'
  return split(/\|/, $res);
}

sub sql_sqllog {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/odbc.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/odbc.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/odbc.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/odbc.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/odbc.group");

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

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpsessions (
  user TEXT,
  ip_addr TEXT,
  timestamp TEXT
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

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $odbc_config = 'sqliteodbc';

  my $ini_file = File::Spec->rel2abs("$tmpdir/odbc.ini");
  if (open(my $fh, "> $ini_file")) {
    print $fh <<EOI;
[$odbc_config]
Description = SqliteODBC
Driver = SQLite3
Database = $db_file
TraceFile = $log_file
Trace = off
EOI
    unless (close($fh)) {
      die("Can't write $ini_file: $!");
    }

  } else {
    die("Can't open $ini_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'odbc',
        SQLConnectInfo => $odbc_config,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'session_start INSERT "\'%u\', \'%L\', \'%{time:%Y-%m-%d %H:%M:%S}\'" ftpsessions',
        SQLLog => 'PASS session_start',
      },
    },
  };

  # We need to specify the ODBCINI environment variable prior to starting
  # proftpd
  $ENV{ODBCINI}=$ini_file;

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
    die($ex);
  }

  my ($login, $ip_addr, $timestamp) = get_sessions($db_file,
    "user = \'$user\'");

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected '$expected', got '$ip_addr'"));

  $expected = '\d{4}\-\d{2}\-\d{2} \d{2}:\d{2}:\d{2}';
  $self->assert(qr/$expected/, $timestamp,
    test_msg("Expected '$expected', got '$timestamp'"));

  unlink($log_file);
}

sub sql_custom_user_info {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/odbc.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/odbc.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/odbc.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

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
CREATE TABLE ftpusers (
  userid TEXT,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT, 
  shell TEXT,
  lastdir TEXT
);
INSERT INTO ftpusers (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user');
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

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $odbc_config = 'sqliteodbc';

  my $ini_file = File::Spec->rel2abs("$tmpdir/odbc.ini");
  if (open(my $fh, "> $ini_file")) {
    print $fh <<EOI;
[$odbc_config]
Description = SqliteODBC
Driver = SQLite3
Database = $db_file
TraceFile = $log_file
Trace = off
EOI
    unless (close($fh)) {
      die("Can't write $ini_file: $!");
    }

  } else {
    die("Can't open $ini_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => [
        'SQLAuthTypes plaintext',
        'SQLBackend odbc',
        "SQLConnectInfo $odbc_config",
        "SQLLogFile $log_file",
        'SQLNamedQuery get-user-by-name SELECT "userid, passwd, uid, gid, homedir, shell FROM ftpusers WHERE userid = \'%U\'"',
        'SQLNamedQuery get-user-by-name SELECT "userid, passwd, uid, gid, homedir, shell FROM ftpusers WHERE uid = %{0}"',
        'SQLUserInfo custom:/get-user-by-name/get-user-by-id',
      ],
    },
  };

  # We need to specify the ODBCINI environment variable prior to starting
  # proftpd
  $ENV{ODBCINI}=$ini_file;

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

      my $resp_msgs = $client->response_msgs();
      my $nmsgs = scalar(@$resp_msgs);

      my $expected;

      $expected = 1;
      $self->assert($expected == $nmsgs,
        test_msg("Expected $expected, got $nmsgs")); 

      $expected = "User proftpd logged in";
      $self->assert($expected eq $resp_msgs->[0],
        test_msg("Expected '$expected', got '$resp_msgs->[0]'"));

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
    die($ex);
  }

  unlink($log_file);
}

1;
