package ProFTPD::Tests::Modules::mod_wrap2_sql;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use File::Spec;
use IO::Handle;
use IO::Socket::INET6;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :features :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  wrap2_allow_msg => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_deny_msg => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_engine => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_sql_allow_table => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_sql_allow_table_multi_rows_multi_entries => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  wrap2_sql_allow_table_all => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  wrap2_sql_deny_table_ip_addr => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_sql_deny_table_ipv4_netmask => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_sql_deny_table_ipv4mappedv6_netmask => {
    order => ++$order,
    test_class => [qw(bug feature_ipv6 forking)],
  },

  wrap2_sql_deny_table_ipv6_netmask_bug3606 => {
    order => ++$order,
    test_class => [qw(bug feature_ipv6 forking)],
  },

  wrap2_sql_deny_table_dns_name => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_sql_deny_table_dns_domain_bug3558 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  wrap2_sql_user_tables => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_sql_group_tables => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_sql_bug3215 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  wrap2_bug3341 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  wrap2_sql_opt_check_on_connect_bug3508 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  wrap2_allow_msg_bug3538 => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_allow_msg_anon_bug3538 => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  wrap2_sql_deny_event_exec_bug3209 => {
    order => ++$order,
    test_class => [qw(forking mod_exec)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub wrap2_allow_msg {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $db_file = File::Spec->rel2abs("$tmpdir/wrap2.db");

  # Build up sqlite3 command to create allow, deny tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/wrap2.sql");

  my $fh;
  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpallow (
  name TEXT,
  allowed TEXT
);

CREATE TABLE ftpdeny (
  name TEXT,
  denied TEXT
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

  unlink($db_script);

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

  my $timeout_idle = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql_sqlite.c' => [
        'SQLAuthenticate off',
        "SQLConnectInfo $db_file",
        'SQLNamedQuery get-allowed-clients SELECT "allowed FROM ftpallow WHERE name = \'%{0}\'"',
        'SQLNamedQuery get-denied-clients SELECT "denied FROM ftpdeny WHERE name = \'%{0}\'"',
        "SQLLogFile $log_file",
      ],

      'mod_wrap2_sql.c' => {
        WrapEngine => 'on',
        WrapAllowMsg => '"User %u allowed by access rules"',
        WrapTables => "sql:/get-allowed-clients sql:/get-denied-clients",
        WrapLog => $log_file,
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

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg(0);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "User $user allowed by access rules";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub wrap2_deny_msg {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $db_file = File::Spec->rel2abs("$tmpdir/wrap2.db");

  # Build up sqlite3 command to create allow, deny tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/wrap2.sql");

  my $fh;
  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpallow (
  name TEXT,
  allowed TEXT
);

CREATE TABLE ftpdeny (
  name TEXT,
  denied TEXT
);

INSERT INTO ftpdeny (name, denied) VALUES ('', 'ALL');
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

  unlink($db_script);

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

  my $timeout_idle = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql_sqlite.c' => [
        'SQLAuthenticate off',
        "SQLConnectInfo $db_file",
        'SQLNamedQuery get-allowed-clients SELECT "allowed FROM ftpallow WHERE name = \'%{0}\'"',
        'SQLNamedQuery get-denied-clients SELECT "denied FROM ftpdeny WHERE name = \'%{0}\'"',
        "SQLLogFile $log_file",
      ],

      'mod_wrap2_sql.c' => {
        WrapEngine => 'on',
        WrapDenyMsg => '"User %u rejected by access rules"',
        WrapTables => "sql:/get-allowed-clients sql:/get-denied-clients",
        WrapLog => $log_file,
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

      my ($resp_code, $resp_msg);

      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "User $user rejected by access rules";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub wrap2_engine {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $db_file = File::Spec->rel2abs("$tmpdir/wrap2.db");

  # Build up sqlite3 command to create allow, deny tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/wrap2.sql");

  my $fh;
  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpallow (
  name TEXT,
  allowed TEXT
);

CREATE TABLE ftpdeny (
  name TEXT,
  denied TEXT
);

INSERT INTO ftpdeny (name, denied) VALUES ('', 'ALL');
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

  unlink($db_script);

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

  my $timeout_idle = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql_sqlite.c' => [
        'SQLAuthenticate off',
        "SQLConnectInfo $db_file",
        'SQLNamedQuery get-allowed-clients SELECT "allowed FROM ftpallow WHERE name = \'%{0}\'"',
        'SQLNamedQuery get-denied-clients SELECT "denied FROM ftpdeny WHERE name = \'%{0}\'"',
        "SQLLogFile $log_file",
      ],

      'mod_wrap2_sql.c' => {
        WrapEngine => 'off',
        WrapAllowMsg => '"User %u allowed by access rules"',
        WrapDenyMsg => '"User %u rejected by access rules"',
        WrapTables => "sql:/get-allowed-clients sql:/get-denied-clients",
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
      my ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "User $user logged in";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub wrap2_sql_allow_table {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $db_file = File::Spec->rel2abs("$tmpdir/wrap2.db");

  # Build up sqlite3 command to create allow, deny tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/wrap2.sql");

  my $fh;
  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpallow (
  name TEXT,
  allowed TEXT
);

CREATE TABLE ftpdeny (
  name TEXT,
  denied TEXT
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

  unlink($db_script);

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

  my $timeout_idle = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql_sqlite.c' => [
        'SQLAuthenticate off',
        "SQLConnectInfo $db_file",
        'SQLNamedQuery get-allowed-clients SELECT "allowed FROM ftpallow WHERE name = \'%{0}\'"',
        'SQLNamedQuery get-denied-clients SELECT "denied FROM ftpdeny WHERE name = \'%{0}\'"',
        "SQLLogFile $log_file",
      ],

      'mod_wrap2_sql.c' => {
        WrapEngine => 'on',
        WrapTables => "sql:/get-allowed-clients sql:/get-denied-clients",
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
      my ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "User $user logged in";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
INSERT INTO ftpallow (name, allowed) VALUES ('', '127.0.0.1');
EOS
    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  @output = `$cmd`;

  unlink($db_script);

  ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Fork child
  $self->handle_sigchld();
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      my ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "User $user logged in";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub wrap2_sql_allow_table_multi_rows_multi_entries {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $db_file = File::Spec->rel2abs("$tmpdir/wrap2.db");

  # Build up sqlite3 command to create allow, deny tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/wrap2.sql");

  my $fh;
  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpallow (
  name TEXT,
  allowed TEXT
);

INSERT INTO ftpallow (name, allowed) VALUES ('', '192.168.127.5, 192.168.127.6');
INSERT INTO ftpallow (name, allowed) VALUES ('', '192.168.127.1 192.168.127.2 127.0.0.1');
INSERT INTO ftpallow (name, allowed) VALUES ('', '192.168.127.3,192.168.127.4 127.0.0.1');

CREATE TABLE ftpdeny (
  name TEXT,
  denied TEXT
);

INSERT INTO ftpdeny (name, denied) VALUES ('', 'ALL');
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

  unlink($db_script);

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

  my $timeout_idle = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql_sqlite.c' => [
        'SQLAuthenticate off',
        "SQLConnectInfo $db_file",
        "SQLLogFile $log_file",
        'SQLNamedQuery get-allowed-clients SELECT "allowed FROM ftpallow WHERE name = \'%{0}\'"',
        'SQLNamedQuery get-denied-clients SELECT "denied FROM ftpdeny WHERE name = \'%{0}\'"',
      ],

      'mod_wrap2_sql.c' => {
        WrapEngine => 'on',
        WrapLog => $log_file,
        WrapTables => "sql:/get-allowed-clients sql:/get-denied-clients",
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
      my ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "User $user logged in";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub wrap2_sql_allow_table_all {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $db_file = File::Spec->rel2abs("$tmpdir/wrap2.db");

  # Build up sqlite3 command to create allow, deny tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/wrap2.sql");

  my $fh;
  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpallow (
  name TEXT,
  allowed TEXT
);

INSERT INTO ftpallow (name, allowed) VALUES ('', 'ALL');

CREATE TABLE ftpdeny (
  name TEXT,
  denied TEXT
);

INSERT INTO ftpdeny (name, allowed) VALUES ('', 'ALL');
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

  unlink($db_script);

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

  my $timeout_idle = 30;

  my $config = {
    TraceLog => $log_file,
    Trace => 'dns:10',
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql_sqlite.c' => [
        'SQLAuthenticate off',
        "SQLConnectInfo $db_file",
        'SQLNamedQuery get-allowed-clients SELECT "allowed FROM ftpallow WHERE name = \'%{0}\'"',
        'SQLNamedQuery get-denied-clients SELECT "denied FROM ftpdeny WHERE name = \'%{0}\'"',
        "SQLLogFile $log_file",
      ],

      'mod_wrap2_sql.c' => {
        WrapEngine => 'on',
        WrapTables => "sql:/get-allowed-clients sql:/get-denied-clients",
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
      my ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "User $user logged in";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub wrap2_sql_deny_table_ip_addr {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $db_file = File::Spec->rel2abs("$tmpdir/wrap2.db");

  # Build up sqlite3 command to create allow, deny tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/wrap2.sql");

  my $fh;
  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpallow (
  name TEXT,
  allowed TEXT
);

CREATE TABLE ftpdeny (
  name TEXT,
  denied TEXT
);

INSERT INTO ftpdeny (name, denied) VALUES ('', 'ALL');
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

  unlink($db_script);

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

  my $timeout_idle = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql_sqlite.c' => [
        "SQLAuthenticate off",
        "SQLConnectInfo $db_file",
        'SQLNamedQuery get-allowed-clients SELECT "allowed FROM ftpallow WHERE name = \'%{0}\'"',
        'SQLNamedQuery get-denied-clients SELECT "denied FROM ftpdeny WHERE name = \'%{0}\'"',
        "SQLLogFile $log_file",
      ],

      'mod_wrap2_sql.c' => {
        WrapEngine => 'on',
        WrapTables => "sql:/get-allowed-clients sql:/get-denied-clients",
        WrapLog => $log_file,
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
      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Access denied";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
DELETE FROM ftpdeny;
INSERT INTO ftpdeny (name, denied) VALUES ('', '127.0.0.1');
EOS
    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  @output = `$cmd`;

  unlink($db_script);

  ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Fork child
  $self->handle_sigchld();
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Access denied";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub wrap2_sql_deny_table_ipv4_netmask {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $db_file = File::Spec->rel2abs("$tmpdir/wrap2.db");

  # Build up sqlite3 command to create allow, deny tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/wrap2.sql");

  my $fh;
  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpallow (
  name TEXT,
  allowed TEXT
);

CREATE TABLE ftpdeny (
  name TEXT,
  denied TEXT
);

INSERT INTO ftpdeny (name, denied) VALUES ('', 'ALL');
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

  unlink($db_script);

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

  my $timeout_idle = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql_sqlite.c' => [
        "SQLAuthenticate off",
        "SQLConnectInfo $db_file",
        'SQLNamedQuery get-allowed-clients SELECT "allowed FROM ftpallow WHERE name = \'%{0}\'"',
        'SQLNamedQuery get-denied-clients SELECT "denied FROM ftpdeny WHERE name = \'%{0}\'"',
        "SQLLogFile $log_file",
      ],

      'mod_wrap2_sql.c' => {
        WrapEngine => 'on',
        WrapTables => "sql:/get-allowed-clients sql:/get-denied-clients",
        WrapLog => $log_file,
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
      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Access denied";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
DELETE FROM ftpdeny;
INSERT INTO ftpdeny (name, denied) VALUES ('', '127.0.0.0/255.255.255.0');
EOS
    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  @output = `$cmd`;

  unlink($db_script);

  ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Fork child
  $self->handle_sigchld();
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Access denied";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub wrap2_sql_deny_table_ipv4mappedv6_netmask {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $db_file = File::Spec->rel2abs("$tmpdir/wrap2.db");

  # Build up sqlite3 command to create allow, deny tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/wrap2.sql");

  my $fh;
  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpallow (
  name TEXT,
  allowed TEXT
);

CREATE TABLE ftpdeny (
  name TEXT,
  denied TEXT
);

INSERT INTO ftpdeny (name, denied) VALUES ('', 'ALL');
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

  unlink($db_script);

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

  my $timeout_idle = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,

    UseIPv6 => 'on',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql_sqlite.c' => [
        "SQLAuthenticate off",
        "SQLConnectInfo $db_file",
        'SQLNamedQuery get-allowed-clients SELECT "allowed FROM ftpallow WHERE name = \'%{0}\'"',
        'SQLNamedQuery get-denied-clients SELECT "denied FROM ftpdeny WHERE name = \'%{0}\'"',
        "SQLLogFile $log_file",
      ],

      'mod_wrap2_sql.c' => {
        WrapEngine => 'on',
        WrapTables => "sql:/get-allowed-clients sql:/get-denied-clients",
        WrapLog => $log_file,
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
      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Access denied";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
DELETE FROM ftpdeny;
INSERT INTO ftpdeny (name, denied) VALUES ('', '127.0.0.0/255.255.255.0');
EOS
    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  @output = `$cmd`;

  unlink($db_script);

  ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Fork child
  $self->handle_sigchld();
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Access denied";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub wrap2_sql_deny_table_ipv6_netmask_bug3606 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $db_file = File::Spec->rel2abs("$tmpdir/wrap2.db");

  # Build up sqlite3 command to create allow, deny tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/wrap2.sql");

  my $fh;
  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpallow (
  name TEXT,
  allowed TEXT
);

CREATE TABLE ftpdeny (
  name TEXT,
  denied TEXT
);

INSERT INTO ftpdeny (name, denied) VALUES ('', 'ALL');
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

  unlink($db_script);

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

  my $timeout_idle = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,

    DefaultAddress => '::1',
    UseIPv6 => 'on',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql_sqlite.c' => [
        "SQLAuthenticate off",
        "SQLConnectInfo $db_file",
        'SQLNamedQuery get-allowed-clients SELECT "allowed FROM ftpallow WHERE name = \'%{0}\'"',
        'SQLNamedQuery get-denied-clients SELECT "denied FROM ftpdeny WHERE name = \'%{0}\'"',
        "SQLLogFile $log_file",
      ],

      'mod_wrap2_sql.c' => {
        WrapEngine => 'on',
        WrapTables => "sql:/get-allowed-clients sql:/get-denied-clients",
        WrapLog => $log_file,
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
      sleep(2);

      my $client = IO::Socket::INET6->new(
        PeerAddr => '::1',
        PeerPort => $port,
        Proto => 'tcp',
        Timeout => 5,
      );
      unless ($client) {
        die("Can't connect to ::1: $!");
      } 

      # Read the banner
      my $banner = <$client>;

      # Send the USER command
      my $cmd = "USER $user\r\n";
      $client->print($cmd);
      $client->flush();

      # Read USER response
      my $resp = <$client>;

      my $expected = "331 Password required for $user\r\n";
      $self->assert($expected eq $resp,
        test_msg("Expected '$expected', got '$resp'"));
 
      # Send the PASS command
      $cmd = "PASS $passwd\r\n";
      $client->print($cmd);
      $client->flush();

      # Read PASS response
      $resp = <$client>;

      $expected = "530 Access denied\r\n";
      $self->assert($expected eq $resp,
        test_msg("Expected '$expected', got '$resp'"));
 
      $client->close();
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
DELETE FROM ftpdeny;
INSERT INTO ftpdeny (name, denied) VALUES ('', '[::1]/32');
EOS
    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  @output = `$cmd`;

  unlink($db_script);

  ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Fork child
  $self->handle_sigchld();
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(2);

      my $client = IO::Socket::INET6->new(
        PeerAddr => '::1',
        PeerPort => $port,
        Proto => 'tcp',
        Timeout => 5,
      );
      unless ($client) {
        die("Can't connect to ::1: $!");
      } 

      # Read the banner
      my $banner = <$client>;

      # Send the USER command
      my $cmd = "USER $user\r\n";
      $client->print($cmd);
      $client->flush();

      # Read USER response
      my $resp = <$client>;

      my $expected = "331 Password required for $user\r\n";
      $self->assert($expected eq $resp,
        test_msg("Expected '$expected', got '$resp'"));
 
      # Send the PASS command
      $cmd = "PASS $passwd\r\n";
      $client->print($cmd);
      $client->flush();

      # Read PASS response
      $resp = <$client>;

      $expected = "530 Access denied\r\n";
      $self->assert($expected eq $resp,
        test_msg("Expected '$expected', got '$resp'"));
 
      $client->close();
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub wrap2_sql_deny_table_dns_name {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $db_file = File::Spec->rel2abs("$tmpdir/wrap2.db");

  # Build up sqlite3 command to create allow, deny tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/wrap2.sql");

  my $fh;
  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpallow (
  name TEXT,
  allowed TEXT
);

CREATE TABLE ftpdeny (
  name TEXT,
  denied TEXT
);

INSERT INTO ftpdeny (name, denied) VALUES ('', 'ALL');
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

  unlink($db_script);

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

  my $timeout_idle = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,
    UseReverseDNS => 'on',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql_sqlite.c' => [
        'SQLAuthenticate off',
        "SQLConnectInfo $db_file",
        'SQLNamedQuery get-allowed-clients SELECT "allowed FROM ftpallow WHERE name = \'%{0}\'"',
        'SQLNamedQuery get-denied-clients SELECT "denied FROM ftpdeny WHERE name = \'%{0}\'"',
        "SQLLogFile $log_file",
      ],

      'mod_wrap2_sql.c' => {
        WrapEngine => 'on',
        WrapTables => "sql:/get-allowed-clients sql:/get-denied-clients",
        WrapLog => $log_file,
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
      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Access denied";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
DELETE FROM ftpdeny;
INSERT INTO ftpdeny (name, denied) VALUES ('', 'localhost');
EOS
    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  @output = `$cmd`;

  unlink($db_script);

  ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Fork child
  $self->handle_sigchld();
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Access denied";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub wrap2_sql_deny_table_dns_domain_bug3558 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $db_file = File::Spec->rel2abs("$tmpdir/wrap2.db");

  # Build up sqlite3 command to create allow, deny tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/wrap2.sql");

  my $fh;
  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpallow (
  name TEXT,
  allowed TEXT
);

CREATE TABLE ftpdeny (
  name TEXT,
  denied TEXT
);

INSERT INTO ftpdeny (name, denied) VALUES ('', 'ALL');
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

  unlink($db_script);

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

  my $timeout_idle = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'dns:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,

    UseReverseDNS => 'on',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql_sqlite.c' => [
        'SQLAuthenticate off',
        "SQLConnectInfo $db_file",
        'SQLNamedQuery get-allowed-clients SELECT "allowed FROM ftpallow WHERE name = \'%{0}\'"',
        'SQLNamedQuery get-denied-clients SELECT "denied FROM ftpdeny WHERE name = \'%{0}\'"',
        "SQLLogFile $log_file",
      ],

      'mod_wrap2_sql.c' => {
        WrapEngine => 'on',
        WrapTables => "sql:/get-allowed-clients sql:/get-denied-clients",
        WrapLog => $log_file,
        WrapOptions => 'CheckAllNames',
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
      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Access denied";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
DELETE FROM ftpdeny;
INSERT INTO ftpdeny (name, denied) VALUES ('', '.castaglia.org');
EOS
    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  @output = `$cmd`;

  unlink($db_script);

  ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Fork child
  $self->handle_sigchld();
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Access denied";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub wrap2_sql_user_tables {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $db_file = File::Spec->rel2abs("$tmpdir/wrap2.db");

  # Build up sqlite3 command to create allow, deny tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/wrap2.sql");

  my $fh;
  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpallow (
  name TEXT,
  allowed TEXT
);

CREATE TABLE ftpdeny (
  name TEXT,
  denied TEXT
);

INSERT INTO ftpdeny (name, denied) VALUES ('$user', 'ALL');
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

  unlink($db_script);

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

  my $timeout_idle = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql_sqlite.c' => [
        'SQLAuthenticate off',
        "SQLConnectInfo $db_file",
        'SQLNamedQuery get-allowed-clients SELECT "allowed FROM ftpallow WHERE name = \'%{0}\'"',
        'SQLNamedQuery get-denied-clients SELECT "denied FROM ftpdeny WHERE name = \'%{0}\'"',
        "SQLLogFile $log_file",
      ],

      'mod_wrap2_sql.c' => {
        WrapEngine => 'on',
        WrapUserTables => "!$user sql:/get-allowed-clients sql:/get-denied-clients",
        WrapLog => $log_file,
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
      my ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "User $user logged in";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

  # Modify the config a little
  $config->{IfModules}->{'mod_wrap2_sql.c'}->{WrapUserTables} = "$user sql:/get-allowed-clients sql:/get-denied-clients";

  ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Fork child
  $self->handle_sigchld();
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Access denied";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub wrap2_sql_group_tables {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $db_file = File::Spec->rel2abs("$tmpdir/wrap2.db");

  # Build up sqlite3 command to create allow, deny tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/wrap2.sql");

  my $fh;
  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpallow (
  name TEXT,
  allowed TEXT
);

CREATE TABLE ftpdeny (
  name TEXT,
  denied TEXT
);

INSERT INTO ftpdeny (name, denied) VALUES ('$group', 'ALL');
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

  unlink($db_script);

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

  my $timeout_idle = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql_sqlite.c' => [
        'SQLAuthenticate off',
        "SQLConnectInfo $db_file",
        'SQLNamedQuery get-allowed-clients SELECT "allowed FROM ftpallow WHERE name = \'%{0}\'"',
        'SQLNamedQuery get-denied-clients SELECT "denied FROM ftpdeny WHERE name = \'%{0}\'"',
        "SQLLogFile $log_file",
      ],

      'mod_wrap2_sql.c' => {
        WrapEngine => 'on',
        WrapGroupTables => "foo sql:/get-allowed-clients sql:/get-denied-clients",
        WrapLog => $log_file,
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
      my ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "User $user logged in";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

  # Modify the config a little
  $config->{IfModules}->{'mod_wrap2_sql.c'}->{WrapGroupTables} = "ftpd sql:/get-allowed-clients sql:/get-denied-clients";

  ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Fork child
  $self->handle_sigchld();
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Access denied";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub wrap2_sql_bug3215 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $db_file = File::Spec->rel2abs("$tmpdir/wrap2.db");

  # Build up sqlite3 command to create allow, deny tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/wrap2.sql");

  my $fh;
  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpallow (
  allowed TEXT
);

INSERT INTO ftpallow (allowed) VALUES ('192.168.0.1,192.168.0.2 192.168.0.3, 192.168.0.4 127.0.0.1');

CREATE TABLE ftpdeny (
  denied TEXT
);

INSERT INTO ftpdeny (denied) VALUES ('ALL');
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

  unlink($db_script);

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

  my $timeout_idle = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql_sqlite.c' => [
        'SQLAuthenticate off',
        "SQLConnectInfo $db_file",
        'SQLNamedQuery get-allowed-clients SELECT "allowed FROM ftpallow"',
        'SQLNamedQuery get-denied-clients SELECT "denied FROM ftpdeny"',
        "SQLLogFile $log_file",
      ],

      'mod_wrap2_sql.c' => {
        WrapEngine => 'on',
        WrapTables => "sql:/get-allowed-clients sql:/get-denied-clients",
        WrapLog => $log_file,
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
      my ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "User $user logged in";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub wrap2_bug3341 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $db_file = File::Spec->rel2abs("$tmpdir/wrap2.db");

  # Build up sqlite3 command to create allow, deny tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/wrap2.sql");

  my $fh;
  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpallow (
  allowed TEXT
);

INSERT INTO ftpallow (allowed) VALUES ('192.168.0.1,192.168.0.2 192.168.0.3, 192.168.0.4 127.0.0.1');

CREATE TABLE ftpdeny (
  denied TEXT
);

INSERT INTO ftpdeny (denied) VALUES ('ALL');
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

  unlink($db_script);

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

  my $timeout_idle = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql_sqlite.c' => [
        'SQLAuthenticate off',
        "SQLConnectInfo $db_file",
        'SQLNamedQuery get-allowed-clients SELECT "allowed FROM ftpallow"',
        'SQLNamedQuery get-denied-clients SELECT "denied FROM ftpdeny"',
        "SQLLogFile $log_file",
      ],

      'mod_wrap2_sql.c' => {
        WrapEngine => 'on',
        WrapTables => "sql:/get-allowed-clients sql:/get-denied-clients",
        WrapLog => $log_file,
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

      # As per Bug#3341, we need to send a bad password twice.  The second
      # attempt triggered a segfault in mod_wrap2.
      eval { $client->login($user, 'foo') };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg(); 

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Login incorrect.";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      # Now try to login again
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

      ($resp_code, $resp_msg) = $client->login($user, $passwd);

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "User $user logged in";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub wrap2_sql_opt_check_on_connect_bug3508 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  # XXX NOTE: In order for the CheckOnConnect WrapOption to work properly
  # with mod_wrap2_sql, the module load order must be very specific, e.g.:
  #
  #  --with-modules=mod_wrap2:mod_wrap2_sql:mod_sql:mod_sqlite
  #
  # Specifically, mod_sql and its backend(s) MUST appear AFTER mod_wrap2 and
  # its submodules in the module load order list.  This is necessary because
  # mod_sql's session init callback is where the database connection is
  # defined.  If mod_wrap2 appears after mod_sql in the module load order
  # list, then mod_wrap2's session init callback is called first, and it
  # will try to use mod_wrap2_sql to get the table data, which will try to
  # use mod_sql -- and the database connection won't be defined.  And only
  # mod_sql has the knowledge of how to handle the SQLConnectInfo directive,
  # which is needed in order to define/create that database connection.

  my $mod_list = feature_get_compiled_modules();
  my ($mod_wrap2_idx, $mod_sql_idx);

  my $nmodules = scalar(@$mod_list);
  for (my $i = 0; $i < $nmodules; $i++) {
    if ($mod_list->[$i] =~ /mod_wrap2\.c/) {
      $mod_wrap2_idx = $i;
    }

    if ($mod_list->[$i] =~ /mod_sql\.c/) {
      $mod_sql_idx = $i;
    }
  }

  if ($mod_sql_idx < $mod_wrap2_idx) {
    print STDERR " + unable to run 'wrap2_sql_opt_check_on_connect_bug3508' test with current module order (mod_sql appears BEFORE mod_wrap2), skipping\n";
    return;
  }

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $db_file = File::Spec->rel2abs("$tmpdir/wrap2.db");

  # Build up sqlite3 command to create allow, deny tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/wrap2.sql");

  my $fh;
  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpallow (
  name TEXT,
  allowed TEXT
);

CREATE TABLE ftpdeny (
  name TEXT,
  denied TEXT
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
    print STDERR "Output: ", join("", @output), "\n";
  }

  unlink($db_script);

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

  my $timeout_idle = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql_sqlite.c' => [
        'SQLAuthenticate off',
        "SQLConnectInfo $db_file",
        'SQLNamedQuery get-allowed-clients SELECT "allowed FROM ftpallow WHERE name = \'%{0}\'"',
        'SQLNamedQuery get-denied-clients SELECT "denied FROM ftpdeny WHERE name = \'%{0}\'"',
        "SQLLogFile $log_file",
      ],

      'mod_wrap2_sql.c' => {
        WrapEngine => 'on',
        WrapTables => "sql:/get-allowed-clients sql:/get-denied-clients",
        WrapLog => $log_file,
        WrapOptions => 'CheckOnConnect',
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
      my ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "User $user logged in";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
INSERT INTO ftpdeny (name, denied) VALUES ('', '127.0.0.1');
EOS
    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  $cmd = "sqlite3 $db_file < $db_script";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  @output = `$cmd`;
  if (scalar(@output) &&
      $ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  unlink($db_script);

  ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Fork child
  $self->handle_sigchld();
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client;

      eval {
        $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, undef, 2);
      };
      unless ($@) {
        die("Connect succeeded unexpectedly");
      }

      my $ex = ProFTPD::TestSuite::FTP::get_connect_exception();

      my $expected = "Access denied";
      $self->assert($expected eq $ex,
        test_msg("Expected '$expected', got '$ex'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub wrap2_allow_msg_bug3538 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $db_file = File::Spec->rel2abs("$tmpdir/wrap2.db");

  # Build up sqlite3 command to create allow, deny tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/wrap2.sql");

  my $fh;
  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpallow (
  name TEXT,
  allowed TEXT
);

CREATE TABLE ftpdeny (
  name TEXT,
  denied TEXT
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

  unlink($db_script);

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

  my $timeout_idle = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AccessGrantMsg => '"User %u logged in."',
    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql_sqlite.c' => [
        'SQLAuthenticate off',
        "SQLConnectInfo $db_file",
        'SQLNamedQuery get-allowed-clients SELECT "allowed FROM ftpallow WHERE name = \'%{0}\'"',
        'SQLNamedQuery get-denied-clients SELECT "denied FROM ftpdeny WHERE name = \'%{0}\'"',
        "SQLLogFile $log_file",
      ],

      'mod_wrap2_sql.c' => {
        WrapEngine => 'on',
        WrapAllowMsg => '"User %u allowed by access rules"',
        WrapTables => "sql:/get-allowed-clients sql:/get-denied-clients",
        WrapLog => $log_file,
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

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg(0);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "User $user allowed by access rules";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      $resp_msg = $client->response_msg(1);

      $expected = "User $user logged in.";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response meessage '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub wrap2_allow_msg_anon_bug3538 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $db_file = File::Spec->rel2abs("$tmpdir/wrap2.db");

  # Build up sqlite3 command to create allow, deny tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/wrap2.sql");

  my $fh;
  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpallow (
  name TEXT,
  allowed TEXT
);

CREATE TABLE ftpdeny (
  name TEXT,
  denied TEXT
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

  unlink($db_script);

  my ($test_user, $test_group) = config_get_identity();
  my $passwd = 'test';
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

  auth_user_write($auth_user_file, $test_user, $passwd, $uid, $gid, '/tmp',
    '/bin/bash');
  auth_group_write($auth_group_file, $test_group, $gid, $test_user);

  my $timeout_idle = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AccessGrantMsg => '"User %u logged in."',
    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,

    Anonymous => {
      $home_dir => {
        User => $test_user,
        Group => $test_group,
        UserAlias => "anonymous $test_user", 
        RequireValidShell => 'off',
      },
    },

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql_sqlite.c' => [
        'SQLAuthenticate off',
        "SQLConnectInfo $db_file",
        'SQLNamedQuery get-allowed-clients SELECT "allowed FROM ftpallow WHERE name = \'%{0}\'"',
        'SQLNamedQuery get-denied-clients SELECT "denied FROM ftpdeny WHERE name = \'%{0}\'"',
        "SQLLogFile $log_file",
      ],

      'mod_wrap2_sql.c' => {
        WrapEngine => 'on',
        WrapAllowMsg => '"User %u allowed by access rules"',
        WrapTables => "sql:/get-allowed-clients sql:/get-denied-clients",
        WrapLog => $log_file,
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

      $client->login('anonymous', 'ftp@nospam.org');

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg(0);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User anonymous logged in.";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $resp_msg = $client->response_msg(1);

      $expected = "User anonymous allowed by access rules";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub wrap2_sql_deny_event_exec_bug3209 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $db_file = File::Spec->rel2abs("$tmpdir/wrap2.db");

  # Build up sqlite3 command to create allow, deny tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/wrap2.sql");

  my $fh;
  if (open($fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpallow (
  name TEXT,
  allowed TEXT
);

CREATE TABLE ftpdeny (
  name TEXT,
  denied TEXT
);

INSERT INTO ftpdeny (name, denied) VALUES ('', 'ALL');
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

  unlink($db_script);

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

  my $event_file = File::Spec->rel2abs("$tmpdir/denied-client.txt");
  my $spawn_script = File::Spec->rel2abs("$tmpdir/spawn.sh");
  if (open(my $fh, "> $spawn_script")) {
    print $fh <<EOS;
#!/usr/bin/env bash
echo $@ > $event_file
exit
EOS
    unless (close($fh)) {
      die("Can't write $spawn_script: $!");
    }

    unless (chmod(0777, $spawn_script)) {
      die("Can't set perms on $spawn_script to 0777: $!");
    }

  } else {
    die("Can't open $spawn_script: $!");
  }

  my $timeout_idle = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'event:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_exec.c' => {
        ExecEngine => 'on',
        ExecLog => $log_file,
        ExecTimeout => 1,
        ExecOnEvent => "mod_wrap.connection-denied $spawn_script %a",
      },

      'mod_sql_sqlite.c' => [
        "SQLAuthenticate off",
        "SQLConnectInfo $db_file",
        'SQLNamedQuery get-allowed-clients SELECT "allowed FROM ftpallow WHERE name = \'%{0}\'"',
        'SQLNamedQuery get-denied-clients SELECT "denied FROM ftpdeny WHERE name = \'%{0}\'"',
        "SQLLogFile $log_file",
      ],

      'mod_wrap2_sql.c' => {
        WrapEngine => 'on',
        WrapTables => "sql:/get-allowed-clients sql:/get-denied-clients",
        WrapLog => $log_file,
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
      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Access denied";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      if (open(my $fh, "< $event_file")) {
        my $line = <$fh>;
        chomp($line);
        close($fh);

        my $expected = '127.0.0.1';
        $self->assert($expected eq $line,
          test_msg("Expected line '$expected', got '$line'"));

      } else {
        die("Can't read $event_file: $!");
      }

    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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
