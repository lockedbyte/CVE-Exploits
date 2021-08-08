package ProFTPD::Tests::Modules::mod_sql_sqlite;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use Carp;
use File::Path qw(mkpath);
use File::Spec;
use IO::Handle;
use Sys::HostAddr;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  sql_bug2045 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_bug2922 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  sql_bug3116 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_bug3124 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqlite_bug3126 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_user_where_clause_ok => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_user_where_clause_with_vars_ok => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_group_where_clause_ok => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_bug3149 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqllog => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_sqlite_sqllog_with_chroot => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  sql_user_info_different_table_names => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_custom_user_info => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_custom_user_info_null_ids => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_userset_bug2434 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  sql_usersetfast_bug2434 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  sql_custom_group_info_bug3043 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_groupset_bug3043 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  sql_groupsetfast_bug3043 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  sql_sqllog_var_w => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_sqllog_var_w_chrooted => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  sql_openssl_auth_type_md5 => {
    order => ++$order,
    test_class => [qw(feature_openssl forking)],
  },

  sql_openssl_auth_type_sha1 => {
    order => ++$order,
    test_class => [qw(feature_openssl forking)],
  },

  sql_sqllog_var_S => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_sqllog_var_S_err => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_negative_cache_bug3282 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqllog_var_T_rnfr => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqllog_var_T_retr => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqllog_var_transfer_millisecs_retr_bug4218 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqllog_var_R_retr_bug4218 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqllog_exit => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_sqllog_exit_var_remote_port_bug4296 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqllog_var_d_bug3395 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqllog_var_d_chroot_bug3395 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  sql_sqllog_var_uid_gid_bug3390 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqlite_auth_type_backend_bug3511 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqllog_pass_ok_var_s_bug3528 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqllog_pass_failed_var_s_bug3528 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqllog_pass_failed_bug4301 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqlshowinfo_pass_bug3423 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqlshowinfo_list_bug3423 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_multiple_users_shared_uid_gid => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_resolve_tag_bug3536 => {
    order => ++$order,
    test_class => [qw(bug forking inprogress)],
  },

  sql_sqllog_vars_I_O_bug3554 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqllog_note_var_unique_id_bug3572 => {
    order => ++$order,
    test_class => [qw(bug forking mod_unique_id)],
  },

  sql_sqllog_note_var_rewrite_bug3572 => {
    order => ++$order,
    test_class => [qw(bug forking mod_rewrite)],
  },

  sql_sqllog_note_sql_user_info => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_sqllog_var_E => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_named_conn_bug3262 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_named_conn_sqllog_exit_bug3645 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  sql_sqllog_vars_H_L_matching_server_bug3620 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqllog_vars_H_L_default_server_bug3620 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqllog_exit_ifuser => {
    order => ++$order,
    test_class => [qw(forking mod_ifsession)],
  },

  sql_sqllog_exit_ifgroup => {
    order => ++$order,
    test_class => [qw(forking mod_ifsession)],
  },

  sql_sqllog_multi_pass_ifclass_bug4025 => {
    order => ++$order,
    test_class => [qw(forking mod_ifsession)],
  },

  sql_opt_no_disconnect_on_error_with_extlog_bug3633 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqllog_ignore_errors_bad_table_bug3692 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqllog_ignore_errors_bad_db_bug3692 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqllog_var_xfer_status_nonxfer => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_sqllog_var_xfer_status_success_download => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_sqllog_var_xfer_status_success_upload => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_sqllog_var_xfer_status_cancelled => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_sqllog_var_xfer_status_failed => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_sqllog_var_xfer_status_timeout => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_sqllog_var_xfer_status_filtered => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_sqllog_var_xfer_failure_none => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_sqllog_var_xfer_failure_reason => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_sqlshowinfo_pass_failed_bug3782 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqllog_preauth_var_U_bug3822 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqllog_preauth_var_u_bug3822 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqlite_maxhostsperuser => {
    order => ++$order,
    test_class => [qw(forking mod_unique_id)],
  },

  sql_sqllog_var_micros_ts_bug3889 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqllog_var_millis_ts_bug3889 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqllog_var_iso8601_ts_bug3889 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqllogonevent_bug3893 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_userprimarykey_bug3864 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_userprimarykey_custom_bug3864 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_groupprimarykey_bug3864 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_groupprimarykey_custom_bug3864 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqllog_var_basename_bug3987 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_user_info_defaulthomedir_bug4083 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_user_info_null_uid_gid_columns => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_64_bit_uid_bug4164 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  sql_sqllog_var_remote_port => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  sql_userowner_issue346 => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  sql_sqlite_log_db_enoent_issue654 => {
    order => ++$order,
    test_class => [qw(forking bug)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub build_db {
  my $cmd = shift;
  my $db_script = shift;
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

  unlink($db_script);
  return 1;
}

sub sql_bug2045 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'sqlite');

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
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$setup->{user}', '$setup->{passwd}', $setup->{uid}, $setup->{gid}, '$setup->{home_dir}', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$setup->{group}', $setup->{gid}, '$setup->{user}');
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'sql:20',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $setup->{log_file},
        SQLNamedQuery => 'lastdir SELECT "lastdir FROM users WHERE userid = \'%u\'"',
        SQLShowInfo => 'PASS "230" "\"%{lastdir}\" was the last directory"',
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

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($setup->{user}, $setup->{passwd});

      my $resp_msgs = $client->response_msgs();
      my $nmsgs = scalar(@$resp_msgs);

      my $expected = 1;
      $self->assert($expected == $nmsgs, "Expected $expected, got $nmsgs");

      $expected = "User proftpd logged in";
      $self->assert($expected eq $resp_msgs->[0],
        "Expected '$expected', got '$resp_msgs->[0]'");
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

sub sql_bug2922 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  # Bug#2922 occurred because mod_sql would "authenticate" the plaintext
  # password (if configured to do so) of a user whose info did NOT come from
  # mod_sql.

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
  shell TEXT
);

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    MaxLoginAttempts => 100,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
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
      # Bug#2922 would allow a login which should NOT happen.  So if
      # *any* of the following logins succeed, we have a problem.

      my $accounts = [
        { user => 'bin', passwd => '*' },
        { user => 'bin', passwd => 'x' },
        { user => 'daemon', passwd => '*' },
        { user => 'daemon', passwd => 'x' },
        { user => 'mysql', passwd => '*' },
        { user => 'mysql', passwd => 'x' },
      ];

      foreach my $account (@$accounts) {
        my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
        my $user = $account->{user};
        my $passwd = $account->{passwd};

        eval { $client->login($user, $passwd) };
        unless ($@) {
          die("Logged in unexpectedly");
        }
      }
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, 30) };
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

sub sql_bug3116 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  # Bug#3116 occurred because mod_sql was treating percent signs in user
  # (and group) names as variables to be substituted.

  my $user = 'proftpd%proftpd.org';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);

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
  shell TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');
INSERT INTO groups (groupname, gid, members) VALUES ('ftpadm', 501, '$user');
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 -echo $db_file < $db_script 2>&1";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
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

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
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

      # Bug#3116 would prevent a login from occurring, so we only need to
      # attempt a login.
      $client->login($user, $passwd, 5);
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

sub sql_bug3124 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);

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
  shell TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  # Bug#3124 occurred when SQLNegativeCache was on, and there was no group
  # info; it would cause a segfault.

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNegativeCache => 'on',
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

      # Bug#3124 would prevent a login from occurring, so we only need to
      # attempt a login.
      $client->login($user, $passwd, 5);
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

sub sql_sqlite_bug3126 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);

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
  shell TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', 500, 500, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user');
INSERT INTO groups (groupname, gid, members) VALUES ('ftpadm', 501, '$user');
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
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

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
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

      # Bug#3126 would prevent a login from occurring, so we only need to
      # attempt a login.
      $client->login($user, $passwd, 5);
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

sub sql_user_where_clause_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $user1 = 'proftpd';
  my $user2 = 'proftpd2';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);

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
  allowed TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell, allowed) VALUES ('$user1', '$passwd', 500, 500, '$home_dir', '/bin/bash', 'false');
INSERT INTO users (userid, passwd, uid, gid, homedir, shell, allowed) VALUES ('$user2', '$passwd', 500, 500, '$home_dir', '/bin/bash', 'true');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', 500, '$user1,$user2');
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
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

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLUserWhereClause => '"allowed = \'true\'"',
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

      # This account should not be allowed to login based on the
      # SQLUserWhereClause...
      eval { $client->login($user1, $passwd) };
      unless ($@) {
        die("Login for user '$user1' succeeded unexpectedly");
      }

      # ...but this one should succeed.
      $client->login($user2, $passwd);
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

sub sql_user_where_clause_with_vars_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'sqlite');

  my $user2 = 'proftpd2';

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
  allowed_ip TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell, allowed_ip) VALUES ('$setup->{user}', '$setup->{passwd}', $setup->{uid}, $setup->{gid}, '$setup->{home_dir}', '/bin/bash', '1.2.3.4');
INSERT INTO users (userid, passwd, uid, gid, homedir, shell, allowed_ip) VALUES ('$user2', '$setup->{passwd}', $setup->{uid}, $setup->{gid}, '$setup->{home_dir}', '/bin/bash', '127.0.0.1');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$setup->{group}', $setup->{gid}, '$setup->{user},$user2');
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'jot:20 sql:20',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $setup->{log_file},
        SQLUserWhereClause => '"allowed_ip = \'%L\'"',
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

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # This account should not be allowed to login based on the
      # SQLUserWhereClause...
      eval { $client->login($setup->{user}, $setup->{passwd}) };
      unless ($@) {
        die("Login for user '$setup->{user}' succeeded unexpectedly");
      }

      # ...but this one should succeed.
      $client->login($user2, $setup->{passwd});
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

sub sql_group_where_clause_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid= 500;

  my $acl_group = 'whitelist';

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
  shell TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT,
  allowed TEXT
);
INSERT INTO groups (groupname, gid, members, allowed) VALUES ('$group', $gid, '$user', 'false');
INSERT INTO groups (groupname, gid, members, allowed) VALUES ('$acl_group', $gid, '$user', 'true');
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
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

      'mod_sql.c' => {
        AuthOrder => 'mod_sql.c',

        SQLAuthenticate => 'users groups',
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLGroupWhereClause => '"allowed = \'true\'"',
        SQLOptions => 'useNormalizedGroupSchema',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;

<Limit LOGIN>
  AllowGroup $acl_group
  DenyAll
</Limit>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub sql_bug3149 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'sqlite');

  my $user2 = 'proftpd2';

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
  host TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell, host) VALUES ('$setup->{user}', '$setup->{passwd}', $setup->{uid}, $setup->{gid}, '$setup->{home_dir}', '/bin/bash', 'remotehost');
INSERT INTO users (userid, passwd, uid, gid, homedir, shell, host) VALUES ('$user2', '$setup->{passwd}', $setup->{uid}, $setup->{gid}, '$setup->{home_dir}', '/bin/bash', '127.0.0.1');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$setup->{group}', $setup->{gid}, '$setup->{user},$user2');
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'jot:20 sql:20',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      # Bug#3149 occurred because mod_sql's resolve_short_tag() function
      # was not able to resolve %V properly (it was deferencing a bad pointer).
      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $setup->{log_file},
        SQLUserWhereClause => '"host=\'%V\'"',
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

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # This account should not be allowed to login based on the
      # SQLUserWhereClause...
      eval { $client->login($setup->{user}, $setup->{passwd}) };
      unless ($@) {
        die("Login for user '$setup->{user}' succeeded unexpectedly");
      }

      # ...but this one should succeed.
      $client->login($user2, $setup->{passwd});
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
  my $setup = test_setup($tmpdir, 'sqlite');

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
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'jot:20 sql:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $setup->{log_file},
        SQLNamedQuery => 'session_start FREEFORM "INSERT INTO ftpsessions (user, ip_addr, timestamp) VALUES (\'%u\', \'%L\', \'%{time:%Y-%m-%d %H:%M:%S}\')"',
        SQLLog => 'PASS session_start',
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

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
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

  if ($ex) {
    test_cleanup($setup->{log_file}, $ex);
  }

  eval {
    my ($login, $ip_addr, $timestamp) = get_sessions($db_file,
      "user = \'$setup->{user}\'");

    my $expected = $setup->{user};
    $self->assert($expected eq $login, "Expected '$expected', got '$login'");

    $expected = '127.0.0.1';
    $self->assert($expected eq $ip_addr,
      "Expected '$expected', got '$ip_addr'");

    $expected = '\d{4}\-\d{2}\-\d{2} \d{2}:\d{2}:\d{2}';
    $self->assert(qr/$expected/, $timestamp,
      "Expected '$expected', got '$timestamp'");
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub sql_sqlite_sqllog_with_chroot {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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

  my $tmp_dir = File::Spec->rel2abs("$tmpdir/tmp");
  mkpath($tmp_dir);
  if ($< == 0) {
    unless (chmod(0777, $tmp_dir)) {
      die("Can't set perms on $tmp_dir to 0777: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, '$group', $gid, $user);

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
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    DefaultRoot => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => "$db_file foo bar PERCONNECTION",
        SQLLogFile => $log_file,
        SQLNamedQuery => 'session_start FREEFORM "INSERT INTO ftpsessions (user, ip_addr, timestamp) VALUES (\'%u\', \'%L\', \'%{time:%Y-%m-%d %H:%M:%S}\')"',
        SQLLog => 'PASS session_start',
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

sub sql_user_info_different_table_names {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

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
CREATE TABLE ftpusers (
  userid TEXT,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT, 
  shell TEXT
);
INSERT INTO ftpusers (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

CREATE TABLE ftpgroups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO ftpgroups (groupname, gid, members) VALUES ('$group', $gid, '$user');
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
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

      'mod_sql.c' => [
        'SQLAuthTypes plaintext',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $log_file",
        'SQLUserInfo ftpusers userid passwd uid gid homedir shell',
        'SQLGroupInfo ftpgroups groupname gid members',
      ],
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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub sql_custom_user_info {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

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
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
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

      'mod_sql.c' => [
        'SQLAuthTypes plaintext',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $log_file",
        'SQLNamedQuery get-user-by-name SELECT "userid, passwd, uid, gid, homedir, shell FROM ftpusers WHERE userid = \'%U\'"',
        'SQLNamedQuery get-user-by-id SELECT "userid, passwd, uid, gid, homedir, shell FROM ftpusers WHERE uid = %{0}"',
         'SQLNamedQuery get-user-names SELECT "userid FROM ftpusers"',
         'SQLNamedQuery get-all-users SELECT "userid, passwd, uid, gid, homedir, shell FROM ftpusers"',
        'SQLUserInfo custom:/get-user-by-name/get-user-by-id/get-user-names/get-all-users',
      ],
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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub sql_custom_user_info_null_ids {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

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
    # Note: by inserting/using NULL for the uid and gid columns, we will
    # force mod_sql to use the SQLDefaultUID/SQLDefaultGID values (rather than
    # e.g. segfaulting).

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
INSERT INTO ftpusers (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', NULL, NULL, '$home_dir', '/bin/bash');

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
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
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

      'mod_sql.c' => [
        'SQLAuthTypes plaintext',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $log_file",
        'SQLNamedQuery get-user-by-name SELECT "userid, passwd, uid, gid, homedir, shell FROM ftpusers WHERE userid = \'%U\'"',
        'SQLNamedQuery get-user-by-id SELECT "userid, passwd, uid, gid, homedir, shell FROM ftpusers WHERE uid = %{0}"',
         'SQLNamedQuery get-user-names SELECT "userid FROM ftpusers"',
         'SQLNamedQuery get-all-users SELECT "userid, passwd, uid, gid, homedir, shell FROM ftpusers"',
        'SQLUserInfo custom:/get-user-by-name/get-user-by-id/get-user-names/get-all-users',
      ],
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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub sql_userset_bug2434 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

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
CREATE TABLE ftpusers (
  userid TEXT,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT, 
  shell TEXT,
  lastdir TEXT
);
INSERT INTO ftpusers (userid, passwd, uid, gid, homedir, shell) VALUES ('foo', '$passwd', 500, 500, '$home_dir', '/bin/bash');
INSERT INTO ftpusers (userid, passwd, uid, gid, homedir, shell) VALUES ('bar', '$passwd', 500, 500, '$home_dir', '/bin/bash');
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
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    # This bug requires that a chroot occur in order to be tickled.
    DefaultRoot => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => [
        'SQLAuthenticate users userset groups',
        'SQLAuthTypes plaintext',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $log_file",
        'SQLNamedQuery get-all-users SELECT "userid FROM ftpusers"',
        'SQLNamedQuery get-user-by-name SELECT "userid, passwd, uid, gid, homedir, shell FROM ftpusers WHERE userid = \'%U\'"',
        'SQLNamedQuery get-user-by-id SELECT "userid, passwd, uid, gid, homedir, shell FROM ftpusers WHERE uid = %{0}"',
        'SQLUserInfo custom:/get-user-by-name/get-user-by-id/get-all-users',
      ],
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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub sql_usersetfast_bug2434 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

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
CREATE TABLE ftpusers (
  userid TEXT,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT, 
  shell TEXT,
  lastdir TEXT
);
INSERT INTO ftpusers (userid, passwd, uid, gid, homedir, shell) VALUES ('foo', '$passwd', 500, 500, '$home_dir', '/bin/bash');
INSERT INTO ftpusers (userid, passwd, uid, gid, homedir, shell) VALUES ('bar', '$passwd', 500, 500, '$home_dir', '/bin/bash');
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
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    # This bug requires that a chroot occur in order to be tickled.
    DefaultRoot => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => [
        'SQLAuthenticate users usersetfast groups',
        'SQLAuthTypes plaintext',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $log_file",
        'SQLNamedQuery get-all-usernames SELECT "userid FROM ftpusers"',
        'SQLNamedQuery get-all-users SELECT "userid, passwd, uid, gid, homedir, shell FROM ftpusers"',
        'SQLNamedQuery get-user-by-name SELECT "userid, passwd, uid, gid, homedir, shell FROM ftpusers WHERE userid = \'%U\'"',
        'SQLNamedQuery get-user-by-id SELECT "userid, passwd, uid, gid, homedir, shell FROM ftpusers WHERE uid = %{0}"',
        'SQLUserInfo custom:/get-user-by-name/get-user-by-id/get-all-usernames/get-all-users',
      ],
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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub sql_custom_group_info_bug3043 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

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
  userid TEXT,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT, 
  shell TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

CREATE TABLE ftpgroups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO ftpgroups (groupname, gid, members) VALUES ('$group', $gid, '$user');
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
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

      'mod_sql.c' => [
        'SQLMinID 0',
        'SQLAuthenticate users groups',
        'SQLAuthTypes plaintext',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $log_file",
        'SQLNamedQuery get-group-by-name SELECT "groupname, gid, members FROM ftpgroups WHERE groupname = \'%{0}\'"',
        'SQLNamedQuery get-group-by-id SELECT "groupname, gid, members FROM ftpgroups WHERE gid = %{0}"',
        'SQLNamedQuery get-members-by-user SELECT "members FROM ftpgroups WHERE (members LIKE \'%%,%{0},%%\' OR members LIKE \'%{0},%%\' OR members LIKE \'%%,%{0}\')"',
        'SQLGroupInfo custom:/get-group-by-name/get-group-by-id/get-members-by-user',
      ],
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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub sql_groupset_bug3043 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

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
  userid TEXT,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT, 
  shell TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

CREATE TABLE ftpgroups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO ftpgroups (groupname, gid, members) VALUES ('$group', $gid, '$user');
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
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

      'mod_sql.c' => [
        'SQLMinID 0',
        'SQLAuthenticate users groups groupset',
        'SQLAuthTypes plaintext',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $log_file",
        'SQLNamedQuery get-group-by-name SELECT "groupname, gid, members FROM ftpgroups WHERE groupname = \'%{0}\'"',
        'SQLNamedQuery get-group-by-id SELECT "groupname, gid, members FROM ftpgroups WHERE gid = %{0}"',
        'SQLNamedQuery get-members-by-user SELECT "members FROM ftpgroups WHERE (members LIKE \'%%,%{0},%%\' OR members LIKE \'%{0},%%\' OR members LIKE \'%%,%{0}\')"',
        'SQLNamedQuery get-all-groupnames SELECT "groupname FROM ftpgroups"',
        'SQLGroupInfo custom:/get-group-by-name/get-group-by-id/get-members-by-user/get-all-groupnames',
      ],
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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub sql_groupsetfast_bug3043 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

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
  userid TEXT,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT, 
  shell TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

CREATE TABLE ftpgroups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO ftpgroups (groupname, gid, members) VALUES ('$group', $gid, '$user');
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
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

      'mod_sql.c' => [
        'SQLMinID 0',
        'SQLAuthenticate users groups groupsetfast',
        'SQLAuthTypes plaintext',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $log_file",
        'SQLNamedQuery get-group-by-name SELECT "groupname, gid, members FROM ftpgroups WHERE groupname = \'%{0}\'"',
        'SQLNamedQuery get-group-by-id SELECT "groupname, gid, members FROM ftpgroups WHERE gid = %{0}"',
        'SQLNamedQuery get-group-by-member SELECT "groupname, gid, members FROM ftpgroups WHERE (members LIKE \'%%,%{0},%%\' OR members LIKE \'%{0},%%\' OR members LIKE \'%%,%{0}\')"',
        'SQLNamedQuery get-all-groupnames SELECT "groupname FROM ftpgroups"',
        'SQLNamedQuery get-all-groups SELECT "groupname, gid, members FROM ftpgroups"',
        'SQLGroupInfo custom:/get-group-by-name/get-group-by-id/get-group-by-member/get-all-groupnames/get-all-groups',
      ],
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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub get_renames {
  my $db_file = shift;
  my $where = shift;

  my $sql = "SELECT user, ip_addr, rename_from FROM ftpsessions";
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

sub sql_sqllog_var_w {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  rename_from TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $src_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $src_file")) {
    close($fh);

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/foo.txt");

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
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'rename FREEFORM "INSERT INTO ftpsessions (user, ip_addr, rename_from) VALUES (\'%u\', \'%L\', \'%w\')"',
        SQLLog => 'RNTO rename',
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
      $client->rnfr('test.txt');
      $client->rnto('foo.txt');
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

  my ($login, $ip_addr, $rnfr_path) = get_renames($db_file, "user = \'$user\'");

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected '$expected', got '$ip_addr'"));

  if ($^O eq 'darwin') {
    # MacOSX-specific hack
    $src_file = '/private' . $src_file;
  }

  $expected = $src_file;
  $self->assert($expected eq $rnfr_path,
    test_msg("Expected '$expected', got '$rnfr_path'"));

  unlink($log_file);
}

sub sql_sqllog_var_w_chrooted {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  rename_from TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $src_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $src_file")) {
    close($fh);

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/foo.txt");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    DefaultRoot => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => "$db_file foo bar PERCONNECTION",
        SQLLogFile => $log_file,
        SQLNamedQuery => 'rename FREEFORM "INSERT INTO ftpsessions (user, ip_addr, rename_from) VALUES (\'%u\', \'%L\', \'%w\')"',
        SQLLog => 'RNTO rename',
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
      $client->rnfr('test.txt');
      $client->rnto('foo.txt');
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

  my ($login, $ip_addr, $rnfr_path) = get_renames($db_file, "user = \'$user\'");

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected '$expected', got '$ip_addr'"));

  $expected = $src_file;
  $self->assert($expected eq $rnfr_path,
    test_msg("Expected '$expected', got '$rnfr_path'"));

  unlink($log_file);
}

sub sql_openssl_auth_type_md5 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = '{md5}X03MO1qnZdYdgyfeuILPmQ==';
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
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
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

      'mod_sql.c' => {
        SQLAuthTypes => 'OpenSSL',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
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

      $client->login($user, 'password');

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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub sql_openssl_auth_type_sha1 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = '{sha1}W6ph5Mm5Pz8GgiULbPgzG37mj9g=';
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
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
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

      'mod_sql.c' => {
        SQLAuthTypes => 'OpenSSL',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
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

      $client->login($user, 'password');

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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub get_resp_mesgs {
  my $db_file = shift;
  my $where = shift;
  my $cols = shift;

  my $sql = "SELECT $cols FROM ftpsessions";
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

sub sql_sqllog_var_S {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  resp_mesg TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
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
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'info FREEFORM "INSERT INTO ftpsessions (user, ip_addr, resp_mesg) VALUES (\'%u\', \'%L\', \'%S\')"',
        SQLLog => 'LIST info',
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
      $client->list();
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

  my ($login, $ip_addr, $resp_mesg) = get_resp_mesgs($db_file,
    "user = \'$user\'", "user, ip_addr, resp_mesg");

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected '$expected', got '$ip_addr'"));

  $expected = 'Transfer complete';
  $self->assert($expected eq $resp_mesg,
    test_msg("Expected '$expected', got '$resp_mesg'"));

  unlink($log_file);
}

sub sql_sqllog_var_S_err {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'sqlite');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpsessions (
  user TEXT,
  ip_addr TEXT,
  resp_mesg TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'jot:20 sql:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $setup->{log_file},
        SQLNamedQuery => 'info FREEFORM "INSERT INTO ftpsessions (user, ip_addr, resp_mesg) VALUES (\'%u\', \'%L\', \'%S\')"',
        SQLLog => 'ERR_* info',
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

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($setup->{user}, $setup->{passwd});
      eval { $client->quote('CLIENT', 'NcFTP 3.2.2 linux-x86_64-glibc2.3') };
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

  if ($ex) {
    test_cleanup($setup->{log_file}, $ex);
  }

  eval {
    my ($login, $ip_addr, $resp_mesg) = get_resp_mesgs($db_file,
      "user = \'$setup->{user}\'", "user, ip_addr, resp_mesg");

    my $expected = $setup->{user};
    $self->assert($expected eq $login, "Expected '$expected', got '$login'");

    $expected = '127.0.0.1';
    $self->assert($expected eq $ip_addr,
      "Expected '$expected', got '$ip_addr'");

    $expected = 'CLIENT not understood';
    $self->assert($expected eq $resp_mesg,
      "Expected '$expected', got '$resp_mesg'");
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub sql_negative_cache_bug3282 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

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
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'auth:10',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNegativeCache => 'on',
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

      eval { $client->login('foo', 'foo') };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      $client->login($user, $passwd);

      my $expected;

      my $resp_msgs = $client->response_msgs();
      my $nmsgs = scalar(@$resp_msgs);

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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub sql_sqllog_var_T_rnfr {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'sqlite');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpsessions (
  user TEXT,
  ip_addr TEXT,
  rename_from TEXT,
  rename_time FLOAT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $src_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $src_file")) {
    close($fh);

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/foo.txt");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'jot:20 sql:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $setup->{log_file},
        SQLNamedQuery => 'rename FREEFORM "INSERT INTO ftpsessions (user, ip_addr, rename_from, rename_time) VALUES (\'%u\', \'%L\', \'%w\', %T)"',
        SQLLog => 'RNTO rename',
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

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($setup->{user}, $setup->{passwd});
      $client->rnfr('test.txt');
      $client->rnto('foo.txt');
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

  if ($ex) {
    test_cleanup($setup->{log_file}, $ex);
  }

  eval {
    my $query = "SELECT user, ip_addr, rename_from, rename_time FROM ftpsessions WHERE user = \'$setup->{user}\'";
    $cmd = "sqlite3 $db_file \"$query\"";

    if ($ENV{TEST_VERBOSE}) {
      print STDERR "Executing sqlite3: $cmd\n";
    }

    my $res = join('', `$cmd`);
    chomp($res);

    my ($login, $ip_addr, $rnfr_path, $rename_time) = split(/\|/, $res);

    my $expected = $setup->{user};
    $self->assert($expected eq $login, "Expected '$expected', got '$login'");

    $expected = '127.0.0.1';
    $self->assert($expected eq $ip_addr,
      "Expected '$expected', got '$ip_addr'");

    if ($^O eq 'darwin') {
      # MacOSX-specific hack
      $src_file = '/private' . $src_file;
    }

    $expected = $src_file;
    $self->assert($expected eq $rnfr_path,
      "Expected '$expected', got '$rnfr_path'");

    $expected = '0.0';
    $self->assert($expected eq $rename_time,
      "Expected '$expected', got '$rename_time'");
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub sql_sqllog_var_T_retr {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'sqlite');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpsessions (
  user TEXT PRIMARY KEY,
  ip_addr TEXT,
  download_time FLOAT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $setup->{log_file},
        SQLNamedQuery => 'download FREEFORM "INSERT INTO ftpsessions (user, ip_addr, download_time) VALUES (\'%u\', \'%L\', %T)"',
        SQLLog => 'RETR download',
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

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      $client->login($setup->{user}, $setup->{passwd});

      my $conn = $client->retr_raw('sqlite.conf');
      unless ($conn) {
        die("RETR sqlite.conf failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      while ($conn->read($buf, 8192, 30)) {
      }
      $conn->close();

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

  eval {
    my $query = "SELECT user, ip_addr, download_time FROM ftpsessions WHERE user = \'$setup->{user}\'";
    $cmd = "sqlite3 $db_file \"$query\"";

    if ($ENV{TEST_VERBOSE}) {
      print STDERR "Executing sqlite3: $cmd\n";
    }

    my $res = join('', `$cmd`);
    chomp($res);

    my ($login, $ip_addr, $download_time) = split(/\|/, $res);

    if ($ENV{TEST_VERBOSE}) {
      print STDERR "# login = '$login', ip_addr = '$ip_addr', download_time = $download_time\n";
    }

    my $expected;

    $expected = $setup->{user};
    $self->assert($expected eq $login,
      test_msg("Expected '$expected', got '$login'"));

    $expected = '127.0.0.1';
    $self->assert($expected eq $ip_addr,
      test_msg("Expected '$expected', got '$ip_addr'"));

    $self->assert($download_time > 0.0,
      test_msg("Expected > 0.0, got $download_time"));
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub sql_sqllog_var_transfer_millisecs_retr_bug4218 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'sqlite');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpsessions (
  user TEXT PRIMARY KEY,
  ip_addr TEXT,
  download_ms INTEGER
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $setup->{log_file},
        SQLNamedQuery => 'download FREEFORM "INSERT INTO ftpsessions (user, ip_addr, download_ms) VALUES (\'%u\', \'%L\', %{transfer-millisecs})"',
        SQLLog => 'RETR download',
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

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      $client->login($setup->{user}, $setup->{passwd});

      my $conn = $client->retr_raw('sqlite.conf');
      unless ($conn) {
        die("RETR sqlite.conf failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      while ($conn->read($buf, 8192, 30)) {
      }
      $conn->close();

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

  eval {
    my $query = "SELECT user, ip_addr, download_ms FROM ftpsessions WHERE user = \'$setup->{user}\'";
    $cmd = "sqlite3 $db_file \"$query\"";

    if ($ENV{TEST_VERBOSE}) {
      print STDERR "Executing sqlite3: $cmd\n";
    }

    my $res = join('', `$cmd`);
    chomp($res);

    my ($login, $ip_addr, $download_ms) = split(/\|/, $res);

    if ($ENV{TEST_VERBOSE}) {
      print STDERR "# login = '$login', ip_addr = '$ip_addr', download_ms = $download_ms\n";
    }

    my $expected;

    $expected = $setup->{user};
    $self->assert($expected eq $login,
      test_msg("Expected '$expected', got '$login'"));

    $expected = '127.0.0.1';
    $self->assert($expected eq $ip_addr,
      test_msg("Expected '$expected', got '$ip_addr'"));

    $self->assert($download_ms > 0,
      test_msg("Expected > 0, got $download_ms"));
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub sql_sqllog_var_R_retr_bug4218 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'sqlite');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpsessions (
  user TEXT PRIMARY KEY,
  ip_addr TEXT,
  response_ms INTEGER
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $setup->{log_file},
        SQLNamedQuery => 'download FREEFORM "INSERT INTO ftpsessions (user, ip_addr, response_ms) VALUES (\'%u\', \'%L\', %R)"',
        SQLLog => 'RETR download',
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

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      $client->login($setup->{user}, $setup->{passwd});

      my $conn = $client->retr_raw('sqlite.conf');
      unless ($conn) {
        die("RETR sqlite.conf failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      while ($conn->read($buf, 8192, 30)) {
      }
      $conn->close();

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

  eval {
    my $query = "SELECT user, ip_addr, response_ms FROM ftpsessions WHERE user = \'$setup->{user}\'";
    $cmd = "sqlite3 $db_file \"$query\"";

    if ($ENV{TEST_VERBOSE}) {
      print STDERR "Executing sqlite3: $cmd\n";
    }

    my $res = join('', `$cmd`);
    chomp($res);

    my ($login, $ip_addr, $response_ms) = split(/\|/, $res);

    if ($ENV{TEST_VERBOSE}) {
      print STDERR "# login = '$login', ip_addr = '$ip_addr', response_ms = $response_ms\n";
    }

    my $expected;

    $expected = $setup->{user};
    $self->assert($expected eq $login,
      test_msg("Expected '$expected', got '$login'"));

    $expected = '127.0.0.1';
    $self->assert($expected eq $ip_addr,
      test_msg("Expected '$expected', got '$ip_addr'"));

    $self->assert($response_ms > 0,
      test_msg("Expected > 0, got $response_ms"));
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub sql_sqllog_exit {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  ip_addr TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
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
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'logout FREEFORM "INSERT INTO ftpsessions (user, ip_addr) VALUES (\'%u\', \'%L\')"',
        SQLLog => 'EXIT logout',
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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  my $query = "SELECT user, ip_addr FROM ftpsessions WHERE user = \'$user\'";
  $cmd = "sqlite3 $db_file \"$query\"";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my $res = join('', `$cmd`);
  chomp($res);

  my ($login, $ip_addr) = split(/\|/, $res);

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected '$expected', got '$ip_addr'"));

  unlink($log_file);
}

sub sql_sqllog_exit_var_remote_port_bug4296 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'sqlite');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpsessions (
  user TEXT,
  ip_addr TEXT,
  port NUMBER
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'jot:20 sql:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $setup->{log_file},
        SQLNamedQuery => 'logout FREEFORM "INSERT INTO ftpsessions (user, ip_addr, port) VALUES (\'%u\', \'%L\', %{remote-port})"',
        SQLLog => 'EXIT logout',
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

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
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

  if ($ex) {
    test_cleanup($setup->{log_file}, $ex);
  }

  eval {
    my $query = "SELECT * FROM ftpsessions where user = '$setup->{user}'";
    $cmd = "sqlite3 $db_file \"$query\"";

    if ($ENV{TEST_VERBOSE}) {
      print STDERR "Executing sqlite3: $cmd\n";
    }

    my $output = `$cmd`;
    my $res = join('', `$cmd`);
    chomp($res);

    my ($login, $ip_addr, $remote_port) = split(/\|/, $res);

    my $expected = $setup->{user};
    $self->assert($expected eq $login, "Expected '$expected', got '$login'");

    $expected = '127.0.0.1';
    $self->assert($expected eq $ip_addr,
      "Expected '$expected', got '$ip_addr'");
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub get_locations {
  my $db_file = shift;
  my $where = shift;

  my $sql = "SELECT user, ip_addr, dir FROM ftpsessions";
  if ($where) {
    $sql .= " WHERE $where";
  }

  my $cmd = "sqlite3 $db_file \"$sql\"";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my $res = join('', `$cmd`);
  chomp($res);

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Results: $res\n";
  }

  # The default sqlite3 delimiter is '|'
  return split(/\|/, $res);
}

sub sql_sqllog_var_d_bug3395 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'sqlite');

  my $sub_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($sub_dir);

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $sub_dir)) {
      die("Can't set perms on $sub_dir to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $sub_dir)) {
      die("Can't set owner of $sub_dir to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpsessions (
  user TEXT,
  ip_addr TEXT,
  dir TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'jot:20 sql:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $setup->{log_file},
        SQLNamedQuery => 'location FREEFORM "INSERT INTO ftpsessions (user, ip_addr, dir) VALUES (\'%u\', \'%L\', \'%d\')"',
        SQLLog => 'EXIT location',
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

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($setup->{user}, $setup->{passwd});
      $client->cwd('foo');
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

  if ($ex) {
    test_cleanup($setup->{log_file}, $ex);
  }

  eval {
    my ($login, $ip_addr, $dir) = get_locations($db_file, "user = \'$setup->{user}\'");

    my $expected = $setup->{user};
    $self->assert($expected eq $login, "Expected '$expected', got '$login'");

    $expected = '127.0.0.1';
    $self->assert($expected eq $ip_addr,
      "Expected '$expected', got '$ip_addr'");

    if ($^O eq 'darwin') {
      # MacOSX-specific hack
      $sub_dir = '/private' . $sub_dir;
    }

    $expected = $sub_dir;
    $self->assert($expected eq $dir, "Expected '$expected', got '$dir'");
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub sql_sqllog_var_d_chroot_bug3395 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $sub_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($sub_dir);

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
  dir TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }

    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
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
        SQLBackend => 'sqlite3',
        SQLConnectInfo => "$db_file foo bar PERCONNECTION",
        SQLLogFile => $log_file,
        SQLNamedQuery => 'location FREEFORM "INSERT INTO ftpsessions (user, ip_addr, dir) VALUES (\'%u\', \'%L\', \'%d\')"',
        SQLLog => 'EXIT location',
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
      $client->cwd('foo');
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

  my ($login, $ip_addr, $dir) = get_locations($db_file, "user = \'$user\'");

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected '$expected', got '$ip_addr'"));

  $expected = $sub_dir;
  $self->assert($expected eq $dir,
    test_msg("Expected '$expected', got '$dir'"));

  unlink($log_file);
}

sub get_ids {
  my $db_file = shift;
  my $where = shift;

  my $sql = "SELECT user, ip_addr, uid, gid FROM ftpsessions";
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

sub sql_sqllog_var_uid_gid_bug3390 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $sub_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($sub_dir);

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
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
  uid NUMBER,
  gid NUMBER
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
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
        SQLBackend => 'sqlite3',
        SQLConnectInfo => "$db_file foo bar PERCONNECTION",
        SQLLogFile => $log_file,
        SQLNamedQuery => 'location FREEFORM "INSERT INTO ftpsessions (user, ip_addr, uid, gid) VALUES (\'%u\', \'%L\', %{uid}, %{gid})"',
        SQLLog => 'PASS location',
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
      $client->cwd('foo');
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

  my ($login, $ip_addr, $sql_uid, $sql_gid) = get_ids($db_file, "user = \'$user\'");

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected '$expected', got '$ip_addr'"));

  $expected = $uid;
  $self->assert($expected == $sql_uid,
    test_msg("Expected $expected, got $sql_uid"));

  $expected = $gid;
  $self->assert($expected == $sql_gid,
    test_msg("Expected $expected, got $sql_gid"));

  unlink($log_file);
}

sub sql_sqlite_auth_type_backend_bug3511 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'sqlite');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLAuthTypes => 'backend',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $setup->{log_file},
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($setup->{config_file},
    $config);

  # As of Bug#4281, the mod_sql module no longer supports the "Backend"
  # SQLAuthType itself.  Which means that attempting to use it here, with
  # mod_sql_sqlite, will cause the server to not start up at all.

  my $ex;

  # This should silently fail.
  server_start($setup->{config_file});

  # This is where we detect the actual problem.
  eval { server_stop($setup->{pid_file}) };
  unless ($@) {
    $ex = "Server start with bad config unexpectedly";
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub sql_sqllog_pass_ok_var_s_bug3528 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  resp_code TEXT,
  resp_mesg TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
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
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'info FREEFORM "INSERT INTO ftpsessions (user, resp_code, resp_mesg) VALUES (\'%u\', \'%s\', \'%S\')"',
        SQLLog => 'PASS,ERR_PASS info',
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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  my ($login, $resp_code, $resp_mesg) = get_resp_mesgs($db_file,
    undef, "user, resp_code, resp_mesg");

  my $expected;

  $expected = 230;
  $self->assert($expected eq $resp_code,
    test_msg("Expected '$expected', got '$resp_code'"));

  $expected = "User $user logged in";
  $self->assert($expected eq $resp_mesg,
    test_msg("Expected '$expected', got '$resp_mesg'"));

  unlink($log_file);
}

sub sql_sqllog_pass_failed_var_s_bug3528 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  resp_code TEXT,
  resp_mesg TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
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
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'info FREEFORM "INSERT INTO ftpsessions (user, resp_code, resp_mesg) VALUES (\'%u\', \'%s\', \'%S\')"',
        SQLLog => 'PASS,ERR_PASS info',
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
      eval { $client->login($user, 'foobar') };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

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

  my ($login, $resp_code, $resp_mesg) = get_resp_mesgs($db_file,
    undef, "user, resp_code, resp_mesg");

  my $expected;

  $expected = 530;
  $self->assert($expected eq $resp_code,
    test_msg("Expected '$expected', got '$resp_code'"));

  $expected = "Login incorrect.";
  $self->assert($expected eq $resp_mesg,
    test_msg("Expected '$expected', got '$resp_mesg'"));

  unlink($log_file);
}

sub sql_sqllog_pass_failed_bug4301 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  resp_code TEXT,
  resp_mesg TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
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
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'info FREEFORM "INSERT INTO ftpsessions (user, resp_code, resp_mesg) VALUES (\'%u\', \'%s\', \'%S\')"',
        SQLLog => 'PASS info',
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
      $client->user($user);
      eval { $client->pass('') };
      unless ($@) {
        die("PASS succeeded unexpectedly");
      }

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

  # We want to ensure/assert that a failed PASS command does NOT cause
  # the SQLLog directive to be triggered (Bug#4301).
  eval {
    my ($login, $resp_code, $resp_mesg) = get_resp_mesgs($db_file,
      undef, "user, resp_code, resp_mesg");
    $self->assert(!defined($resp_code), "Expected undef, got $resp_code");
    $self->assert(!defined($resp_mesg), "Expected undef, got '$resp_mesg'");
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

sub sql_sqlshowinfo_pass_bug3423 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'sqlite');

  my $lastdir = '/path/to/lastdir';

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
INSERT INTO users (userid, passwd, uid, gid, homedir, shell, lastdir) VALUES ('$setup->{user}', '$setup->{passwd}', $setup->{uid}, $setup->{gid}, '$setup->{home_dir}', '/bin/bash', '$lastdir');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$setup->{group}', $setup->{gid}, '$setup->{user}');
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'jot:20 sql:20',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => [
        'AuthOrder mod_sql.c',

        'SQLAuthenticate users groups',
        'SQLAuthTypes plaintext',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $setup->{log_file}",
        'SQLMinID 100',

        'SQLNamedQuery lastdir SELECT "lastdir FROM users WHERE userid = \'%u\'"',

        # Configure the equivalent of a multiline DisplayLogin file
        # using the SQLShowInfo directive
        'SQLShowInfo PASS 230 " "',
        'SQLShowInfo PASS 230 "Greetings, %u"',
        'SQLShowInfo PASS 230 "Last directory: \"%{lastdir}\""',
        'SQLShowInfo PASS 230 "-"',
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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($setup->{user}, $setup->{passwd});

      my $resp_msgs = $client->response_msgs();
      my $nmsgs = scalar(@$resp_msgs);

      my $expected = 5;
      $self->assert($expected == $nmsgs, "Expected $expected, got $nmsgs");

      $expected = " ";
      $self->assert($expected eq $resp_msgs->[0],
        "Expected '$expected', got '$resp_msgs->[0]'");

      $expected = " Greetings, $setup->{user}";
      $self->assert($expected eq $resp_msgs->[1],
        "Expected '$expected', got '$resp_msgs->[1]'");

      $expected = " Last directory: \"$lastdir\"";
      $self->assert($expected eq $resp_msgs->[2],
        "Expected '$expected', got '$resp_msgs->[2]'");

      $expected = " -";
      $self->assert($expected eq $resp_msgs->[3],
        "Expected '$expected', got '$resp_msgs->[3]'");

      $expected = "User $setup->{user} logged in";
      $self->assert($expected eq $resp_msgs->[4],
        "Expected '$expected', got '$resp_msgs->[4]'");

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

sub sql_sqlshowinfo_list_bug3423 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'sqlite');

  my $lastdir = '/path/to/lastdir';

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
INSERT INTO users (userid, passwd, uid, gid, homedir, shell, lastdir) VALUES ('$setup->{user}', '$setup->{passwd}', $setup->{uid}, $setup->{gid}, '$setup->{home_dir}', '/bin/bash', '$lastdir');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$setup->{group}', $setup->{gid}, '$setup->{user}');
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'jot:20 sql:20',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => [
        'AuthOrder mod_sql.c',

        'SQLAuthenticate users groups',
        'SQLAuthTypes plaintext',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $setup->{log_file}",
        'SQLMinID 100',

        # Configure the equivalent of a multiline DisplayLogin file
        # using the SQLShowInfo directive

        'SQLShowInfo LIST 226 "Get that directory listing OK, %u?"',
        'SQLShowInfo LIST 226 "-"',
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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($setup->{user}, $setup->{passwd});

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected = 230;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code"); 

      $expected = "User $setup->{user} logged in";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");

      my $conn = $client->list_raw();
      unless ($conn) {
        die("LIST failed unexpectedly: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 25);
      eval { $conn->close() };

      $resp_code = $client->response_code();

      $expected = 226;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code"); 

      my $resp_msgs = $client->response_msgs();
      my $nmsgs = scalar(@$resp_msgs);

      $expected = 4;
      $self->assert($expected == $nmsgs, "Expected $expected, got $nmsgs");

      $expected = "Opening ASCII mode data connection for file list";
      $self->assert($expected eq $resp_msgs->[0],
        "Expected response message '$expected', got '$resp_msgs->[0]'");

      $expected = "Transfer complete";
      $self->assert($expected eq $resp_msgs->[1],
        "Expected response message '$expected', got '$resp_msgs->[1]'");

      $expected = " Get that directory listing OK, $setup->{user}?";
      $self->assert($expected eq $resp_msgs->[2],
        "Expected response message '$expected', got '$resp_msgs->[2]'");

      $expected = "-";
      $self->assert($expected eq $resp_msgs->[3],
        "Expected response message '$expected', got '$resp_msgs->[3]'");

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

sub sql_multiple_users_shared_uid_gid {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

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
    print $fh <<EOU;
CREATE TABLE users (
  userid TEXT,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT, 
  shell TEXT
);
EOU

  for (my $i = 1; $i <= 10; $i++) {
    my $name = $user . $i;

    print $fh "INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$name', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');\n";
  }

    print $fh <<EOG;
CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
EOG

  my $group_members = ($user . '1');
  for (my $i = 2; $i <= 5; $i++) {
    my $name = $user . $i;
    $group_members .= ",$name";
  }

  my $group_name = ($group . '1');
  print $fh "INSERT INTO groups (groupname, gid, members) VALUES ('$group_name', $gid, '$group_members');\n";

  $group_members = ($user . '6');
  for (my $i = 7; $i <= 10; $i++) {
    my $name = $user . $i;
    $group_members .= ",$name";
  }

  $group_name = ($group . '2');
  print $fh "INSERT INTO groups (groupname, gid, members) VALUES ('$group_name', $gid, '$group_members');\n";

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
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

      'mod_sql.c' => [
        'AuthOrder mod_sql.c',

        'SQLAuthenticate users groups',
        'SQLAuthTypes plaintext',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $log_file",
        'SQLMinID 100',
      ],
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

      my $name = $user . '10';
      $client->login($name, $passwd);
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

sub get_cmds {
  my $db_file = shift;
  my $where = shift;

  my $sql = "SELECT user, ip_addr, command, request FROM ftpsessions";
  if ($where) {
    $sql .= " WHERE $where";
  }

  my $cmd = "sqlite3 $db_file \"$sql\"";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my $rows = [`$cmd`];

  if ($ENV{TEST_VERBOSE}) {
    use Data::Dumper;
    print STDERR "Results: ", Dumper($rows), "\n";
  }

  my $res;

  # Return the last row found, for now
  foreach my $row (@$rows) {
    chomp($row);

    # The default sqlite3 delimiter is '|'
    $res = [split(/\|/, $row)];
  }

  return unless $res;
  return @$res;
}

sub sql_resolve_tag_bug3536 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

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
  userid TEXT,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT, 
  shell TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user');

CREATE TABLE ftpsessions (
  user TEXT,
  ip_addr TEXT,
  command TEXT,
  request TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'sql:20',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'command FREEFORM "INSERT INTO ftpsessions (user, ip_addr, command, request) VALUES (\'%u\', \'%L\', \'%m\', \'%r\')"',
        SQLLog => '* command',
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

      # Ignore errors for these commands
      eval {
        my $name = "AAAAAAAAAA%m%m%mA%m%m%mA%m%mAA%m%m%m%m%mA%m%Z%m%mA%m%mAA%mA%ZAA%m%m%m%m%m%mA%m%ZAAA%m%m%m%m%m%m%m%m%m%m%m%m%m%m%mAa0Aa1Aa2Aa3Aa4Aa5Aa6Aa7Aa8Aa9Ab0Ab1Ab2Ab3Ab4Ab5Ab6Ab7Ab8Ab9Ac0A%%%m%r%m%Z";
        $client->user($name);
      };
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

  my ($login, $ip_addr, $req);
  ($login, $ip_addr, $cmd, $req) = get_cmds($db_file, "user = \'$config_user\'");

  $self->assert(!defined($login), test_msg("Expected undef, got '$login'"));
  $self->assert(!defined($ip_addr), test_msg("Expected undef, got '$ip_addr'"));

  unlink($log_file);
}

sub get_session_io {
  my $db_file = shift;
  my $where = shift;

  my $sql = "SELECT user, ip_addr, bytes_in, bytes_out FROM ftpsessions";
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

sub sql_sqllog_vars_I_O_bug3554 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'sqlite');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpsessions (
  user TEXT,
  ip_addr TEXT,
  bytes_in NUMBER,
  bytes_out NUMBER
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'DEFAULT:10 jot:20 sql:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $setup->{log_file},
        SQLNamedQuery => 'session_io FREEFORM "INSERT INTO ftpsessions (user, ip_addr, bytes_in, bytes_out) VALUES (\'%u\', \'%L\', %I, %O)"',
        SQLLog => 'EXIT session_io',
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

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($setup->{user}, $setup->{passwd});
      $client->type('ascii');

      my $conn = $client->stor_raw('test.txt');
      unless ($conn) {
        die("STOR test.txt failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "ABCD\n" x 8;
      $conn->write($buf, length($buf), 30);
      $conn->close();

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      $client->quit();

      my $expected = 226;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = 'Transfer complete';
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");
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

  if ($ex) {
    test_cleanup($setup->{log_file}, $ex);
  }

  eval {
    my ($login, $ip_addr, $bytes_in, $bytes_out) = get_session_io($db_file,
      "user = \'$setup->{user}\'");

    my $expected = $setup->{user};
    $self->assert($expected eq $login, "Expected '$expected', got '$login'");

    $expected = '127.0.0.1';
    $self->assert($expected eq $ip_addr,
      "Expected '$expected', got '$ip_addr'");

    $expected = 108;
    $self->assert($expected == $bytes_in,
      "Expected $expected, got $bytes_in");

    # Why would this number vary so widely?  It's because of the notation
    # used to express the port number in a PASV response.  That port
    # number is ephemeral, chosen by the kernel.

    my $expected_min = 232;
    my $expected_max = 236;
    $self->assert($expected_min <= $bytes_out ||
                  $expected_max >= $bytes_out,
      "Expected $expected_min - $expected_max, got $bytes_out");
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub get_session_id {
  my $db_file = shift;
  my $where = shift;

  my $sql = "SELECT user, ip_addr, session_id FROM ftpsessions";
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

sub sql_sqllog_note_var_unique_id_bug3572 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  session_id TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'session_id FREEFORM "INSERT INTO ftpsessions (user, ip_addr, session_id) VALUES (\'%u\', \'%L\', \'%{note:UNIQUE_ID}\')"',
        SQLLog => 'PASS session_id',
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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  my ($login, $ip_addr, $session_id) = get_session_id($db_file,
    "user = \'$user\'");

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected '$expected', got '$ip_addr'"));

  $self->assert($session_id ne '',
    test_msg("Expected session ID ($session_id), got ''"));

  unlink($log_file);
}

sub sql_sqllog_note_var_rewrite_bug3572 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $domain = 'proftpd.org';

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
  session_id TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'rewrite:10 sql:20 table:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteCondition %m USER',
        'RewriteRule ^(.*#)?([-_.0-9A-Za-z]+)(@)?(.*)? $2',
      ],

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'session_id FREEFORM "INSERT INTO ftpsessions (user, ip_addr, session_id) VALUES (\'%U\', \'%L\', \'%{note:mod_rewrite.$4}\')"',
        SQLLog => 'USER session_id',
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

      my $login = $user . '@' . $domain;
      $client->login($login, $passwd);
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

  my ($login, $ip_addr, $session_id) = get_session_id($db_file,
    "user = \'$user\'");

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected '$expected', got '$ip_addr'"));

  $expected = $domain;
  $self->assert($expected eq $session_id,
    test_msg("Expected '$expected', got '$session_id'"));

  unlink($log_file);
}

sub get_sql_notes {
  my $db_file = shift;
  my $where = shift;

  my $sql = "SELECT user, primary_group, home, shell FROM ftpnotes";
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

sub sql_sqllog_note_sql_user_info {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $group = 'ftpd',
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
  my $shell = '/bin/bash';

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
  userid TEXT,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT,
  shell TEXT,
  lastdir TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '$shell');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user');

CREATE TABLE ftpnotes (
  user TEXT,
  primary_group TEXT,
  home TEXT,
  shell TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 sql:20',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLMinID => 100,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'sql_notes FREEFORM "INSERT INTO ftpnotes (user, primary_group, home, shell) VALUES (\'%u\', \'%{note:primary-group}\', \'%{note:home}\', \'%{note:shell}\')"',
        SQLLog => 'PASS sql_notes',
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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  my ($login, $sql_group, $sql_home, $sql_shell) = get_sql_notes($db_file,
    "user = \'$user\'");

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected '$expected', got '$login'"));

  $expected = $group;
  $self->assert($expected eq $sql_group,
    test_msg("Expected '$expected', got '$sql_group'"));

  $expected = $home_dir;
  $self->assert($expected eq $sql_home,
    test_msg("Expected '$expected', got '$sql_home'"));

  $expected = $shell;
  $self->assert($expected eq $sql_shell,
    test_msg("Expected '$expected', got '$sql_shell'"));

  unlink($log_file);
}

sub sql_sqllog_var_E {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'sqlite');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpsessions (
  user TEXT,
  ip_addr TEXT,
  resp_mesg TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'jot:20 sql:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $setup->{log_file},
        SQLNamedQuery => 'info FREEFORM "INSERT INTO ftpsessions (user, ip_addr, resp_mesg) VALUES (\'%u\', \'%L\', \'%E\')"',
        SQLLog => 'EXIT info',
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

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($setup->{user}, $setup->{passwd});
      $client->list();
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

  if ($ex) {
    test_cleanup($setup->{log_file}, $ex);
  }

  eval {
    my ($login, $ip_addr, $resp_mesg) = get_resp_mesgs($db_file,
      "user = \'$setup->{user}\'", "user, ip_addr, resp_mesg");

    my $expected = $setup->{user};
    $self->assert($expected eq $login, "Expected '$expected', got '$login'");

    $expected = '127.0.0.1';
    $self->assert($expected eq $ip_addr,
      "Expected '$expected', got '$ip_addr'");

    $expected = 'Quit';
    $self->assert($expected eq $resp_mesg,
      "Expected '$expected', got '$resp_mesg'");
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub sql_named_conn_bug3262 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

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

  my $userdb_file = File::Spec->rel2abs("$tmpdir/proftpd-users.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd-users.sql");

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

  my $cmd = "sqlite3 $userdb_file < $db_script";
  build_db($cmd, $db_script);

  my $logdb_file = File::Spec->rel2abs("$tmpdir/proftpd-log.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  $db_script = File::Spec->rel2abs("$tmpdir/proftpd-log.sql");

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

  $cmd = "sqlite3 $logdb_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $userdb_file, $logdb_file)) {
      die("Can't set perms on $userdb_file, $logdb_file to 0666: $!");
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

      'mod_sql.c' => [
        'SQLAuthTypes plaintext',
        'SQLBackend sqlite3',
        "SQLConnectInfo $userdb_file",
        "SQLNamedConnectInfo logdb sqlite3 $logdb_file foo bar PERSESSION",
        "SQLLogFile $log_file",
        'SQLNamedQuery get-user-by-name SELECT "userid, passwd, uid, gid, homedir, shell FROM ftpusers WHERE userid = \'%U\'"',
        'SQLNamedQuery get-user-by-id SELECT "userid, passwd, uid, gid, homedir, shell FROM ftpusers WHERE uid = %{0}"',
        'SQLNamedQuery get-user-names SELECT "userid FROM ftpusers"',
        'SQLNamedQuery get-all-users SELECT "userid, passwd, uid, gid, homedir, shell FROM ftpusers"',
        'SQLUserInfo custom:/get-user-by-name/get-user-by-id/get-user-names/get-all-users',
        'SQLNamedQuery session_start FREEFORM "INSERT INTO ftpsessions (user, ip_addr, timestamp) VALUES (\'%u\', \'%L\', \'%{time:%Y-%m-%d %H:%M:%S}\')" logdb',
        'SQLLog PASS session_start',
      ],
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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  my ($login, $ip_addr, $timestamp) = get_sessions($userdb_file,
    "user = \'$user\'");

  $self->assert(!defined($login),
    test_msg("Expected undef, got '$login'"));

  $self->assert(!defined($ip_addr),
    test_msg("Expected undef, got '$ip_addr'"));

  $self->assert(!defined($timestamp),
    test_msg("Expected undef, got '$timestamp'"));

  ($login, $ip_addr, $timestamp) = get_sessions($logdb_file,
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

sub sql_named_conn_sqllog_exit_bug3645 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

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

  my $userdb_file = File::Spec->rel2abs("$tmpdir/proftpd-users.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd-users.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER,
  homedir TEXT, 
  shell TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

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

  my $cmd = "sqlite3 $userdb_file < $db_script";
  build_db($cmd, $db_script);

  my $logdb_file = File::Spec->rel2abs("$tmpdir/proftpd-log.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  $db_script = File::Spec->rel2abs("$tmpdir/proftpd-log.sql");

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

  $cmd = "sqlite3 $logdb_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $userdb_file, $logdb_file)) {
      die("Can't set perms on $userdb_file, $logdb_file to 0666: $!");
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

      'mod_sql.c' => [
        'SQLAuthTypes plaintext',
        'SQLBackend sqlite3',
        "SQLConnectInfo $userdb_file",
        "SQLNamedConnectInfo logdb sqlite3 $logdb_file",
        "SQLLogFile $log_file",
        'SQLNamedQuery session_end FREEFORM "INSERT INTO ftpsessions (user, ip_addr, timestamp) VALUES (\'%u\', \'%L\', \'%{time:%Y-%m-%d %H:%M:%S}\')" logdb',
        'SQLLog EXIT session_end',
      ],
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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  my ($login, $ip_addr, $timestamp) = get_sessions($userdb_file,
    "user = \'$user\'");

  $self->assert(!defined($login),
    test_msg("Expected undef, got '$login'"));

  $self->assert(!defined($ip_addr),
    test_msg("Expected undef, got '$ip_addr'"));

  $self->assert(!defined($timestamp),
    test_msg("Expected undef, got '$timestamp'"));

  ($login, $ip_addr, $timestamp) = get_sessions($logdb_file,
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

sub sql_sqllog_vars_H_L_matching_server_bug3620 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'sqlite');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpsessions (
  user TEXT,
  ip_addr TEXT,
  rename_from TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $src_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $src_file")) {
    close($fh);

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/foo.txt");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'jot:20 sql:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    DefaultServer => 'off',
    SocketBindTight => 'off',
    Port => '0',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($setup->{config_file},
    $config);

  my $sysaddr = Sys::HostAddr->new();
  my $real_addr = $sysaddr->main_ip();
  my $real_port = ProFTPD::TestSuite::Utils::get_high_numbered_port();
  my $vhost_addr = '0.0.0.0';

  if (open(my $fh, ">> $setup->{config_file}")) {
    print $fh <<EOC;
<VirtualHost $vhost_addr>
  ServerName "DefaultServer VHost"
  Port $real_port
  DefaultServer on

  AuthUserFile $setup->{auth_user_file}
  AuthGroupFile $setup->{auth_group_file}
  RequireValidShell off
  WtmpLog off

  <IfModule mod_sql.c>
    SQLEngine log
    SQLBackend sqlite3
    SQLConnectInfo $db_file
    SQLLogFile $setup->{log_file}
    SQLNamedQuery session_start FREEFORM "INSERT INTO ftpsessions (user, ip_addr, rename_from) VALUES ('%u', '%L', '%H')"
    SQLLog PASS session_start
  </IfModule>
</VirtualHost>
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
      my $client = ProFTPD::TestSuite::FTP->new($real_addr, $real_port);
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

  if ($ex) {
    test_cleanup($setup->{log_file}, $ex);
  }

  eval {
    my ($login, $ip_addr, $sess_vhost_addr) = get_renames($db_file, "user = \'$setup->{user}\'");

    my $expected = $setup->{user};
    $self->assert($expected eq $login,
      test_msg("Expected '$expected', got '$login'"));

    $expected = $real_addr;
    $self->assert($expected eq $ip_addr,
      test_msg("Expected '$expected', got '$ip_addr'"));

    $expected = $vhost_addr;
    $self->assert($expected eq $sess_vhost_addr,
      test_msg("Expected '$expected', got '$sess_vhost_addr'"));
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub sql_sqllog_vars_H_L_default_server_bug3620 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'sqlite');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpsessions (
  user TEXT,
  ip_addr TEXT,
  rename_from TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $src_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $src_file")) {
    close($fh);

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/foo.txt");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'jot:20 sql:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    DefaultServer => 'off',
    SocketBindTight => 'off',
    Port => '0',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $setup->{log_file},
        SQLNamedQuery => 'session_start FREEFORM "INSERT INTO ftpsessions (user, ip_addr, rename_from) VALUES (\'%u\', \'%L\', \'%H\')"',
        SQLLog => 'PASS session_start',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($setup->{config_file},
    $config);

  my $sysaddr = Sys::HostAddr->new();
  my $real_addr = $sysaddr->main_ip();
  my $real_port = ProFTPD::TestSuite::Utils::get_high_numbered_port();
  my $vhost_addr = '0.0.0.0';

  if (open(my $fh, ">> $setup->{config_file}")) {
    print $fh <<EOC;

<VirtualHost $vhost_addr>
  ServerName "DefaultServer VHost"
  Port $real_port
  DefaultServer on

  AuthUserFile $setup->{auth_user_file}
  AuthGroupFile $setup->{auth_group_file}
  RequireValidShell off
  WtmpLog off

  <IfModule mod_sql.c>
    SQLEngine log
    SQLBackend sqlite3
    SQLConnectInfo $db_file
    SQLLogFile $setup->{log_file}
    SQLNamedQuery session_start FREEFORM "INSERT INTO ftpsessions (user, ip_addr, rename_from) VALUES (\'%u\', \'%L\', \'%H\')"
    SQLLog PASS session_start
  </IfModule>
</VirtualHost>
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
      my $client = ProFTPD::TestSuite::FTP->new($real_addr, $real_port);
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

  if ($ex) {
    test_cleanup($setup->{log_file}, $ex);
  }

  eval {
    my ($login, $ip_addr, $sess_addr) = get_renames($db_file, "user = \'$setup->{user}\'");

    my $expected = $setup->{user};
    $self->assert($expected eq $login, "Expected '$expected', got '$login'");

    $expected = $real_addr;
    $self->assert($expected eq $ip_addr,
      "Expected '$expected', got '$ip_addr'");

    $expected = $vhost_addr;
    $self->assert($expected eq $sess_addr,
      "Expected '$expected', got '$sess_addr'");
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub sql_sqllog_exit_ifuser {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  ip_addr TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
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
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'logout FREEFORM "INSERT INTO ftpsessions (user, ip_addr) VALUES (\'%u\', \'%L\')"',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<IfModule mod_ifsession.c>
  <IfUser regex .*>
    SQLLog EXIT logout
  </IfUser>
</IfModule>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
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

      # First, just connect and quit, without logging in
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->quit();

      # Then connect, login, and quit
      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  my $query = "SELECT user, ip_addr FROM ftpsessions";
  $cmd = "sqlite3 $db_file \"$query\"";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @res = `$cmd`;
  my $res = join('', @res);
  chomp($res);

  my ($login, $ip_addr) = split(/\|/, $res);

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected '$expected', got '$ip_addr'"));

  unlink($log_file);
}

sub sql_sqllog_exit_ifgroup {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  ip_addr TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
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
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'logout FREEFORM "INSERT INTO ftpsessions (user, ip_addr) VALUES (\'%u\', \'%L\')"',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<IfModule mod_ifsession.c>
  <IfGroup regex .*>
    SQLLog EXIT logout
  </IfGroup>
</IfModule>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
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

      # First, just connect and quit, without logging in
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->quit();

      # Then connect, login, and quit
      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  my $query = "SELECT user, ip_addr FROM ftpsessions";
  $cmd = "sqlite3 $db_file \"$query\"";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @res = `$cmd`;
  my $res = join('', @res);
  chomp($res);

  my ($login, $ip_addr) = split(/\|/, $res);

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected '$expected', got '$ip_addr'"));

  unlink($log_file);
}

sub sql_sqllog_multi_pass_ifclass_bug4025 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  ip_addr TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 ifsession:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    AuthOrder => 'mod_auth_file.c',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => [
        'SQLEngine log',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $log_file",
        'SQLNamedQuery login_ip FREEFORM "INSERT INTO ftpsessions (ip_addr) VALUES (\'%L\')"',
        'SQLNamedQuery login_user FREEFORM "INSERT INTO ftpsessions (user) VALUES (\'%u\')"',
      ],
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Class test>
  From 127.0.0.1
</Class>

<IfModule mod_ifsession.c>
  <IfClass test>
    SQLLog PASS login_ip
    SQLLog PASS login_user
  </IfClass>
</IfModule>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  my $query = "SELECT user, ip_addr FROM ftpsessions";
  $cmd = "sqlite3 $db_file \"$query\"";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @res = `$cmd`;
  my $res = join('', @res);
  $res =~ s/\n//g;
  chomp($res);

  my ($login, $ip_addr) = split(/\|+/, $res);

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected '$expected', got '$ip_addr'"));

  unlink($log_file);
}

sub sql_opt_no_disconnect_on_error_with_extlog_bug3633 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $test_file = File::Spec->rel2abs("$home_dir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 sql:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%m %f"',
    ExtendedLog => "$ext_log ALL custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'log_dele FREEFORM "INSERT INTO ftpsessions (user, ip_addr, ts) VALUES (\'%u\', \'%L\', \'%{time:%Y-%m-%d %H:%M:%S}\')"',
        SQLLog => 'DELE log_dele',

        SQLOptions => 'noDisconnectOnError',
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

  # Now, read in the ExtendedLog, and see whether the %f variable was
  # properly written out.
  if (open(my $fh, "< $ext_log")) {
    my $ok = 0;

    while (my $line = <$fh>) {
      chomp($line);

      # We're only interested in the DELE log line
      unless ($line =~ /^DELE (.*)$/i) {
        next;
      }

      my $name = $1;

      if ($^O eq 'darwin') {
        # MacOSX-specific hack
        $test_file = '/private' . $test_file;
      }

      my $expected = $test_file;
      $self->assert($expected eq $name,
        test_msg("Expected '$expected', got '$name'"));

      $ok = 1;
    }

    close($fh);

    $self->assert($ok, test_msg("Expected ExtendedLog messages not found"));

  } else {
    die("Can't read $ext_log: $!");
  }

  unlink($log_file);
}

sub sql_sqllog_ignore_errors_bad_table_bug3692 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
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
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'session_start FREEFORM "INSERT INTO ftpsessions (user, ip_addr, ts) VALUES (\'%u\', \'%L\', \'%{time:%Y-%m-%d %H:%M:%S}\')"',
        SQLLog => 'PASS session_start IGNORE_ERRORS',
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

sub sql_sqllog_ignore_errors_bad_db_bug3692 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
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
        SQLBackend => 'sqlite3',
        SQLConnectInfo => "/foobar/$db_file",
        SQLLogFile => $log_file,
        SQLNamedQuery => 'session_start FREEFORM "INSERT INTO ftpsessions (user, ip_addr, ts) VALUES (\'%u\', \'%L\', \'%{time:%Y-%m-%d %H:%M:%S}\')"',
        SQLLog => 'PASS session_start IGNORE_ERRORS',
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

sub get_xfer_status {
  my $db_file = shift;
  my $where = shift;

  my $sql = "SELECT user, ip_addr, xfer_status, xfer_path FROM ftpsessions";
  if ($where) {
    $sql .= " WHERE $where";
  }
  $sql .= " LIMIT 1";

  my $cmd = "sqlite3 $db_file \"$sql\"";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my $res = join('', `$cmd`);
  chomp($res);

  # The default sqlite3 delimiter is '|'
  return map { chomp($_); $_; } split(/\|/, $res);
}

sub sql_sqllog_var_xfer_status_nonxfer {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  xfer_status TEXT,
  xfer_path TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    close($fh);

  } else {
    die("Can't open $test_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'sql:20 command:20 netio:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'xfer_status FREEFORM "INSERT INTO ftpsessions (user, ip_addr, xfer_status, xfer_path) VALUES (\'%u\', \'%L\', \'%{transfer-status}\', \'%f\')"',
        SQLLog => 'PWD xfer_status',
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
      $client->pwd();
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

  my ($login, $ip_addr, $xfer_status, $xfer_path) = get_xfer_status($db_file, "user = \'$user\'");

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected user '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected IP address '$expected', got '$ip_addr'"));

  $expected = '-';
  $self->assert($expected eq $xfer_status,
    test_msg("Expected transfer status '$expected', got '$xfer_status'"));

  if ($^O eq 'darwin') {
    # MacOSX-specific hack
    $home_dir = '/private' . $home_dir;
  }

  $expected = $home_dir;
  $self->assert($expected eq $xfer_path,
    test_msg("Expected file path '$expected', got '$xfer_path'"));

  unlink($log_file);
}

sub sql_sqllog_var_xfer_status_success_download {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  xfer_status TEXT,
  xfer_path TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    close($fh);

  } else {
    die("Can't open $test_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'sql:20 command:20 netio:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'xfer_status FREEFORM "INSERT INTO ftpsessions (user, ip_addr, xfer_status, xfer_path) VALUES (\'%u\', \'%L\', \'%{transfer-status}\', \'%f\')"',
        SQLLog => 'ERR_RETR,RETR xfer_status',
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
        die("RETR test.txt failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 25);
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

  my ($login, $ip_addr, $xfer_status, $xfer_path) = get_xfer_status($db_file, "user = \'$user\'");

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected user '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected IP address '$expected', got '$ip_addr'"));

  $expected = 'success';
  $self->assert($expected eq $xfer_status,
    test_msg("Expected transfer status '$expected', got '$xfer_status'"));

  if ($^O eq 'darwin') {
    # MacOSX-specific hack
    $test_file = '/private' . $test_file;
  }

  $expected = $test_file;
  $self->assert($expected eq $xfer_path,
    test_msg("Expected file path '$expected', got '$xfer_path'"));

  unlink($log_file);
}

sub sql_sqllog_var_xfer_status_success_upload {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  xfer_status TEXT,
  xfer_path TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'sql:20 command:20 netio:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'xfer_status FREEFORM "INSERT INTO ftpsessions (user, ip_addr, xfer_status, xfer_path) VALUES (\'%u\', \'%L\', \'%{transfer-status}\', \'%f\')"',
        SQLLog => 'ERR_STOR,STOR xfer_status',
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
        die("STOR test.txt failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Hello, World!\n";
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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  my ($login, $ip_addr, $xfer_status, $xfer_path) = get_xfer_status($db_file, "user = \'$user\'");

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected user '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected IP address '$expected', got '$ip_addr'"));

  $expected = 'success';
  $self->assert($expected eq $xfer_status,
    test_msg("Expected transfer status '$expected', got '$xfer_status'"));

  if ($^O eq 'darwin') {
    # MacOSX-specific hack
    $test_file = '/private' . $test_file;
  }

  $expected = $test_file;
  $self->assert($expected eq $xfer_path,
    test_msg("Expected file path '$expected', got '$xfer_path'"));

  unlink($log_file);
}

sub sql_sqllog_var_xfer_status_cancelled {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  xfer_status TEXT,
  xfer_path TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "ABCDefgh" x 32768;

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
    TraceLog => $log_file,
    Trace => 'sql:20 command:20 netio:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'xfer_status FREEFORM "INSERT INTO ftpsessions (user, ip_addr, xfer_status, xfer_path) VALUES (\'%u\', \'%L\', \'%{transfer-status}\', \'%f\')"',
        SQLLog => 'ERR_RETR,RETR xfer_status',
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
        die("RETR test.txt failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 4, 25);
      eval { $conn->abort() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      $self->assert_transfer_ok($resp_code, $resp_msg, 1);

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

  my ($login, $ip_addr, $xfer_status, $xfer_path) = get_xfer_status($db_file, "user = \'$user\'");

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected user '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected IP address '$expected', got '$ip_addr'"));

  $expected = 'cancelled';
  $self->assert($expected eq $xfer_status,
    test_msg("Expected transfer status '$expected', got '$xfer_status'"));

  if ($^O eq 'darwin') {
    # MacOSX-specific hack
    $test_file = '/private' . $test_file;
  }

  $expected = $test_file;
  $self->assert($expected eq $xfer_path,
    test_msg("Expected file path '$expected', got '$xfer_path'"));

  unlink($log_file);
}

sub sql_sqllog_var_xfer_status_failed {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  xfer_status TEXT,
  xfer_path TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "ABCDefgh" x 32768;

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
    TraceLog => $log_file,
    Trace => 'sql:20 command:20 netio:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    # This is used to tickle the "failed" transfer status
    MaxRetrieveFileSize => '12 B',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'xfer_status FREEFORM "INSERT INTO ftpsessions (user, ip_addr, xfer_status, xfer_path) VALUES (\'%u\', \'%L\', \'%{transfer-status}\', \'%f\')"',
        SQLLog => 'ERR_RETR,RETR xfer_status',
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
        die("RETR test.txt failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 4, 25);
      eval { $conn->close() };

      # Make the control connection go away uncleanly
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

  my ($login, $ip_addr, $xfer_status, $xfer_path) = get_xfer_status($db_file, "user = \'$user\'");

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected user '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected IP address '$expected', got '$ip_addr'"));

  $expected = 'failed';
  $self->assert($expected eq $xfer_status,
    test_msg("Expected transfer status '$expected', got '$xfer_status'"));

  if ($^O eq 'darwin') {
    # MacOSX-specific hack
    $test_file = '/private' . $test_file;
  }

  $expected = $test_file;
  $self->assert($expected eq $xfer_path,
    test_msg("Expected file path '$expected', got '$xfer_path'"));

  unlink($log_file);
}

sub sql_sqllog_var_xfer_status_timeout {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  xfer_status TEXT,
  xfer_path TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "ABCDefgh" x 32768;

    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $timeout_stalled = 1;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'sql:20 command:20 netio:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    # This is used to tickle the "timeout" transfer status
    TimeoutStalled => $timeout_stalled,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'xfer_status FREEFORM "INSERT INTO ftpsessions (user, ip_addr, xfer_status, xfer_path) VALUES (\'%u\', \'%L\', \'%{transfer-status}\', \'%f\')"',
        SQLLog => 'ERR_RETR,RETR,EXIT xfer_status',
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
      $client->type('ascii');

      my $conn = $client->retr_raw('test.txt');
      unless ($conn) {
        die("RETR test.xt failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      sleep($timeout_stalled + 1);

      my $buf;
      $conn->read($buf, 32, 25);
      sleep($timeout_stalled);
      eval { $conn->close() };

      eval { $client->noop() };
      unless ($@) {
        die("NOOP succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      # Perl's Net::Cmd module uses a very non-standard 599 code to
      # indicate that the connection is closed
      $expected = 599;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Connection closed";
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

  my ($login, $ip_addr, $xfer_status, $xfer_path) = get_xfer_status($db_file, "user = \'$user\'");

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected user '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected IP address '$expected', got '$ip_addr'"));

  $expected = '^(timeout|failed)$';
  $self->assert(qr/$expected/, $xfer_status,
    test_msg("Expected transfer status '$expected', got '$xfer_status'"));

  if ($xfer_status eq 'timeout') {
    if ($^O eq 'darwin') {
      # MacOSX-specific hack
      $test_file = '/private' . $test_file;
    }

    $expected = $test_file;
    $self->assert($expected eq $xfer_path,
      test_msg("Expected file path '$expected', got '$xfer_path'"));
  }

  unlink($log_file);
}

sub sql_sqllog_var_xfer_status_filtered {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  xfer_status TEXT,
  xfer_path TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "ABCDefgh" x 32768;

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
    TraceLog => $log_file,
    Trace => 'sql:20 command:20 netio:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    PathDenyFilter => '^.*\.csv$',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'xfer_status FREEFORM "INSERT INTO ftpsessions (user, ip_addr, xfer_status, xfer_path) VALUES (\'%u\', \'%L\', \'%{transfer-status}\', \'%f\')"',
        SQLLog => 'ERR_STOR,STOR,EXIT xfer_status',
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
      $client->type('ascii');

      my $conn = $client->stor_raw('test.csv');
      if ($conn) {
        die("RETR test.csv succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $client->quit();

      my $expected = 550;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "test.csv: Forbidden filename";
      $self->assert($expected eq $resp_msg,
        "Expected '$expected', got '$resp_msg'");
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

  my ($login, $ip_addr, $xfer_status, $xfer_path) = get_xfer_status($db_file, "user = \'$user\'");

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected user '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected IP address '$expected', got '$ip_addr'"));

  $expected = '^(timeout|failed)$';
  $self->assert(qr/$expected/, $xfer_status,
    test_msg("Expected transfer status '$expected', got '$xfer_status'"));

  if ($xfer_status eq 'timeout') {
    if ($^O eq 'darwin') {
      # MacOSX-specific hack
      $test_file = '/private' . $test_file;
    }

    $expected = $test_file;
    $self->assert($expected eq $xfer_path,
      test_msg("Expected file path '$expected', got '$xfer_path'"));
  }

  unlink($log_file);
}

sub get_xfer_failure {
  my $db_file = shift;
  my $where = shift;

  my $sql = "SELECT user, ip_addr, xfer_status, xfer_failure, xfer_path FROM ftpsessions";
  if ($where) {
    $sql .= " WHERE $where";
  }
  $sql .= " LIMIT 1";

  my $cmd = "sqlite3 $db_file \"$sql\"";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my $res = join('', `$cmd`);
  chomp($res);

  # The default sqlite3 delimiter is '|'
  return split(/\|/, $res);
}

sub sql_sqllog_var_xfer_failure_none {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  xfer_status TEXT,
  xfer_failure TEXT,
  xfer_path TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    close($fh);

  } else {
    die("Can't open $test_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'sql:20 command:20 netio:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'xfer_reason FREEFORM "INSERT INTO ftpsessions (user, ip_addr, xfer_status, xfer_failure, xfer_path) VALUES (\'%u\', \'%L\', \'%{transfer-status}\', \'%{transfer-failure}\', \'%f\')"',
        SQLLog => 'ERR_RETR,RETR xfer_reason',
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
        die("RETR test.txt failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 25);
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

  my ($login, $ip_addr, $xfer_status, $xfer_failure, $xfer_path) = get_xfer_failure($db_file, "user = \'$user\'");

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected user '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected IP address '$expected', got '$ip_addr'"));

  $expected = 'success';
  $self->assert($expected eq $xfer_status,
    test_msg("Expected transfer status '$expected', got '$xfer_status'"));

  $expected = '-';
  $self->assert($expected eq $xfer_failure,
    test_msg("Expected transfer failure '$expected', got '$xfer_failure'"));

  if ($^O eq 'darwin') {
    # MacOSX-specific hack
    $test_file = '/private' . $test_file;
  }

  $expected = $test_file;
  $self->assert($expected eq $xfer_path,
    test_msg("Expected file path '$expected', got '$xfer_path'"));

  unlink($log_file);
}

sub sql_sqllog_var_xfer_failure_reason {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  xfer_status TEXT,
  xfer_failure TEXT,
  xfer_path TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "ABCD" x 1024;
    close($fh);

  } else {
    die("Can't open $test_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'sql:20 command:20 netio:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    # This is used to tickle the "failed" transfer status
    MaxRetrieveFileSize => '12 B',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'xfer_reason FREEFORM "INSERT INTO ftpsessions (user, ip_addr, xfer_status, xfer_failure, xfer_path) VALUES (\'%u\', \'%L\', \'%{transfer-status}\', \'%{transfer-failure}\', \'%f\')"',
        SQLLog => 'ERR_RETR,RETR xfer_reason',
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
        die("RETR test.txt failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 25);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected = 426;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'Transfer aborted';
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

  my ($login, $ip_addr, $xfer_status, $xfer_failure, $xfer_path) = get_xfer_failure($db_file, "user = \'$user\'");

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected user '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected IP address '$expected', got '$ip_addr'"));

  $expected = 'failed';
  $self->assert($expected eq $xfer_status,
    test_msg("Expected transfer status '$expected', got '$xfer_status'"));

  $expected = 'Operation not permitted';
  $self->assert($expected eq $xfer_failure,
    test_msg("Expected transfer failure '$expected', got '$xfer_failure'"));

  if ($^O eq 'darwin') {
    # MacOSX-specific hack
    $test_file = '/private' . $test_file;
  }

  $expected = $test_file;
  $self->assert($expected eq $xfer_path,
    test_msg("Expected file path '$expected', got '$xfer_path'"));

  unlink($log_file);
}

sub sql_sqlshowinfo_pass_failed_bug3782 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'sqlite');

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
  secure_only INTEGER
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell, secure_only) VALUES ('$setup->{user}', '$setup->{passwd}', $setup->{uid}, $setup->{gid}, '$setup->{home_dir}', '/bin/bash', 1);

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$setup->{group}', $setup->{gid}, '$setup->{user}');

CREATE TABLE login_responses (
  secure_only INTEGER,
  response TEXT
);

INSERT INTO login_responses (secure_only, response) VALUES (0, "Login failed.");
INSERT INTO login_responses (secure_only, response) VALUES (1, "You may not log into this account via FTP. Please use SFTP instead.");
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'jot:20 response:20 sql:20',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => [
        'AuthOrder mod_sql.c',

        'SQLAuthenticate users groups',
        'SQLAuthTypes plaintext',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $setup->{log_file}",
        'SQLMinID 100',

        'SQLUserWhereClause "secure_only != 1"',
        'SQLNamedQuery login_failure SELECT "response FROM users u, login_responses lr WHERE u.userid = \'%U\' AND u.secure_only = lr.secure_only"',

        # Configure the equivalent of a multiline DisplayLogin file
        # using the SQLShowInfo directive

        'SQLShowInfo ERR_PASS 530 "Sorry, %U"',
        'SQLShowInfo ERR_PASS 530 "%{login_failure}"',
        'SQLShowInfo ERR_PASS 530 " "',
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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      eval { $client->login($setup->{user}, $setup->{passwd}) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_msgs = $client->response_msgs();
      my $nmsgs = scalar(@$resp_msgs);

      my $expected = 4;
      $self->assert($expected == $nmsgs, "Expected $expected, got $nmsgs"); 

      $expected = "Login incorrect.";
      $self->assert($expected eq $resp_msgs->[0],
        "Expected response '$expected', got '$resp_msgs->[0]'");

      $expected = " Sorry, $setup->{user}";
      $self->assert($expected eq $resp_msgs->[1],
        "Expected response '$expected', got '$resp_msgs->[1]'");

      $expected = " You may not log into this account via FTP. Please use SFTP instead.";
      $self->assert($expected eq $resp_msgs->[2],
        "Expected response '$expected', got '$resp_msgs->[2]'");

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

sub sql_sqllog_preauth_var_U_bug3822 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  resp_mesg TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
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
        SQLBackend => 'sqlite3',
        SQLConnectInfo => "$db_file foo bar PERCONNECTION",
        SQLLogFile => $log_file,
        SQLNamedQuery => 'info FREEFORM "INSERT INTO ftpsessions (user, ip_addr, resp_mesg) VALUES (\'%U\', \'%L\', \'%S\')"',
        SQLLog => 'ERR_PWD info',
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
      eval { $client->pwd() };
      unless ($@) {
        die("PWD succeeded unexpectedly");
      }

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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  my ($login, $ip_addr, $resp_mesg) = get_resp_mesgs($db_file,
    "user = '-'", "user, ip_addr, resp_mesg");

  my $expected;

  $expected = '-';
  $self->assert($expected eq $login,
    test_msg("Expected '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected '$expected', got '$ip_addr'"));

  $expected = 'Please login with USER and PASS';
  $self->assert($expected eq $resp_mesg,
    test_msg("Expected '$expected', got '$resp_mesg'"));

  unlink($log_file);
}

sub sql_sqllog_preauth_var_u_bug3822 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  resp_mesg TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
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
        SQLBackend => 'sqlite3',
        SQLConnectInfo => "$db_file foo bar PERCONNECTION",
        SQLLogFile => $log_file,
        SQLNamedQuery => 'info FREEFORM "INSERT INTO ftpsessions (user, ip_addr, resp_mesg) VALUES (\'%u\', \'%L\', \'%S\')"',
        SQLLog => 'ERR_PWD info',
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
      eval { $client->pwd() };
      unless ($@) {
        die("PWD succeeded unexpectedly");
      }

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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  my ($login, $ip_addr, $resp_mesg) = get_resp_mesgs($db_file,
    "user = '-'", "user, ip_addr, resp_mesg");

  my $expected;

  $expected = '-';
  $self->assert($expected eq $login,
    test_msg("Expected '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected '$expected', got '$ip_addr'"));

  $expected = 'Please login with USER and PASS';
  $self->assert($expected eq $resp_mesg,
    test_msg("Expected '$expected', got '$resp_mesg'"));

  unlink($log_file);
}

sub sql_sqlite_maxhostsperuser {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

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
  shell TEXT
);
CREATE INDEX i_users_userid ON users.userid;
CREATE INDEX i_users_uid ON users.uid;
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
CREATE INDEX i_groups_gid ON groups.gid;
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user');

CREATE TABLE user_hosts (
  session_id TEXT,
  userid TEXT,
  host TEXT
);
CREATE INDEX i_user_hosts_userid ON user_hosts.userid;
INSERT INTO user_hosts (session_id, userid, host) VALUES ('abc', '$user', '127.0.0.1');

EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'response:20 sql:20',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => [
        'AuthOrder mod_sql.c',

        'SQLAuthenticate users groups',
        'SQLAuthTypes plaintext',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $log_file",
        'SQLMinID 100',

        # Here, the MaxHostsPerUser limit is 3; it has to be hardcoded into
        # the SQL query, unfortunately.  (Or maybe use a config file variable?)
        #
        # The LEFT JOIN is necessary for dealing with the case where the
        # user_hosts table has no matching rows for the user logging in.
        'SQLNamedQuery get-user-by-name SELECT "u.userid, u.passwd, u.uid, u.gid, u.homedir, u.shell, COUNT(uh.session_id) AS count FROM users u JOIN user_hosts uh ON u.userid = \"%U\" GROUP BY u.userid HAVING (count >= 0 AND count < 4)"',
        'SQLNamedQuery get-user-by-id SELECT "userid, passwd, uid, gid, homedir, shell FROM users WHERE uid = %{0}"',
        'SQLUserInfo custom:/get-user-by-name/get-user-by-id',

        'SQLNamedQuery add-user-host FREEFORM "INSERT INTO user_hosts (session_id, userid, host) VALUES (\'%{env:UNIQUE_ID}\', \'%u\', \'%a\')"',
        'SQLLog PASS add-user-host',

        'SQLNamedQuery remove-user-host FREEFORM "DELETE FROM user_hosts WHERE session_id = \"%{env:UNIQUE_ID}\"',
        'SQLLog EXIT remove-user-host',

        'SQLShowInfo ERR_PASS 530 "Sorry, the maximum number of hosts for this user are already connected."',
      ],
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
      my $client1 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client1->login($user, $passwd);

      my $client2 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client2->login($user, $passwd);

      my $client3 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client3->login($user, $passwd);

      my $client4 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      eval { $client4->login($user, $passwd) };
      unless ($@) {
        die("Fourth login succeeded unexpectedly");
      }

      my $resp_code = $client4->response_code();
      my $resp_msgs = $client4->response_msgs();

      my $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Login incorrect.";
      $self->assert($expected eq $resp_msgs->[0],
        test_msg("Expected response '$expected', got '$resp_msgs->[0]'"));

      $expected = "Sorry, the maximum number of hosts for this user are already connected.";
      $self->assert($expected eq $resp_msgs->[1],
        test_msg("Expected response '$expected', got '$resp_msgs->[1]'"));

      $client4->quit();

      $client3->quit();

      $client4 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client4->login($user, $passwd);
      $client4->quit();

      $client2->quit();
      $client1->quit();
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

sub get_logins {
  my $db_file = shift;
  my $where = shift;

  my $sql = "SELECT user, ip_addr, ts FROM ftpsessions";
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

sub sql_sqllog_var_micros_ts_bug3889 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  ts TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $src_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $src_file")) {
    close($fh);

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/foo.txt");

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
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'login FREEFORM "INSERT INTO ftpsessions (user, ip_addr, ts) VALUES (\'%u\', \'%L\', \'%{microsecs}\')"',
        SQLLog => 'PASS login',
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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  my ($login, $ip_addr, $ts) = get_logins($db_file, "user = \'$user\'");

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected login user '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected IP address '$expected', got '$ip_addr'"));

  $expected = '\d{6}';
  $self->assert(qr/$expected/, $ts,
    test_msg("Expected timestamp '$expected', got '$ts'"));

  unlink($log_file);
}

sub sql_sqllog_var_millis_ts_bug3889 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  ts TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $src_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $src_file")) {
    close($fh);

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/foo.txt");

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
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'login FREEFORM "INSERT INTO ftpsessions (user, ip_addr, ts) VALUES (\'%u\', \'%L\', \'%{millisecs}\')"',
        SQLLog => 'PASS login',
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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  my ($login, $ip_addr, $ts) = get_logins($db_file, "user = \'$user\'");

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected login user '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected IP address '$expected', got '$ip_addr'"));

  $expected = '\d{3}';
  $self->assert(qr/$expected/, $ts,
    test_msg("Expected timestamp '$expected', got '$ts'"));

  unlink($log_file);
}

sub sql_sqllog_var_iso8601_ts_bug3889 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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
  ts TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $src_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $src_file")) {
    close($fh);

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/foo.txt");

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
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'login FREEFORM "INSERT INTO ftpsessions (user, ip_addr, ts) VALUES (\'%u\', \'%L\', \'%{iso8601}\')"',
        SQLLog => 'PASS login',
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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  my ($login, $ip_addr, $ts) = get_logins($db_file, "user = \'$user\'");

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected login user '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected IP address '$expected', got '$ip_addr'"));

  $expected = '\d{4}\-\d{2}\-\d{2} \d{2}:\d{2}:\d{2},\d{3}';
  $self->assert(qr/$expected/, $ts,
    test_msg("Expected timestamp '$expected', got '$ts'"));

  unlink($log_file);
}

sub sql_sqllogonevent_bug3893 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'sqlite');

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
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $max_login_attempts = 2;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'jot:20 sql:20 sql.sqlite:20',

    AuthOrder => 'mod_auth_file.c',
    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    MaxLoginAttempts => $max_login_attempts,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $setup->{log_file},
        SQLNamedQuery => 'max_logins_exceeded FREEFORM "INSERT INTO ftpsessions (user, ip_addr, timestamp) VALUES (\'%U\', \'%L\', \'%{time:%Y-%m-%d %H:%M:%S}\')"',
        SQLLogOnEvent => 'MaxLoginAttempts max_logins_exceeded',
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

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      eval { $client->login($setup->{user}, 'badpassword') };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      eval { $client->login($setup->{user}, 'badpassword') };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }
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

  if ($ex) {
    test_cleanup($setup->{log_file}, $ex);
  }

  eval {
    my ($login, $ip_addr, $timestamp) = get_sessions($db_file,
      "user = \'$setup->{user}\'");

    my $expected = $setup->{user};
    $self->assert($expected eq $login,
      test_msg("Expected '$expected', got '$login'"));

    $expected = '127.0.0.1';
    $self->assert($expected eq $ip_addr,
      test_msg("Expected '$expected', got '$ip_addr'"));

    $expected = '\d{4}\-\d{2}\-\d{2} \d{2}:\d{2}:\d{2}';
    $self->assert(qr/$expected/, $timestamp,
      test_msg("Expected '$expected', got '$timestamp'"));
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub get_session_with_primary_key {
  my $db_file = shift;
  my $where = shift;

  my $sql = "SELECT name, ip_addr, primary_key FROM sessions";
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

sub sql_userprimarykey_bug3864 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

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
  shell TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user');

CREATE TABLE sessions (
  name TEXT,
  ip_addr TEXT,
  primary_key INTEGER
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'sql:20',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => 200,

        SQLUserPrimaryKey => 'uid',

        SQLNamedQuery => 'session_start FREEFORM "INSERT INTO sessions (name, ip_addr, primary_key) VALUES (\'%u\', \'%L\', %{note:sql.user-primary-key})"',
        SQLLog => 'PASS session_start',
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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  eval {
    my ($name, $ip_addr, $primary_key) = get_session_with_primary_key($db_file,
      "name = \'$user\'");

    my $expected;

    $expected = $user;
    $self->assert($expected eq $name,
      test_msg("Expected name '$expected', got '$name'"));

    $expected = '127.0.0.1';
    $self->assert($expected eq $ip_addr,
      test_msg("Expected IP address '$expected', got '$ip_addr'"));

    $expected = $uid;
    $self->assert($expected == $primary_key,
      test_msg("Expected primary key $expected, got $primary_key"));
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

sub sql_userprimarykey_custom_bug3864 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

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
  primary_key INTEGER
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell, primary_key) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash', $uid);

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user');

CREATE TABLE sessions (
  name TEXT,
  ip_addr TEXT,
  primary_key INTEGER
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'sql:20',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => [
        'SQLAuthTypes plaintext',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $log_file",
        'SQLMinID 200',

        'SQLNamedQuery get-user-primary-key SELECT "primary_key FROM users WHERE userid = \'%{0}\'"',
        'SQLUserPrimaryKey custom:/get-user-primary-key',

        'SQLNamedQuery session_start FREEFORM "INSERT INTO sessions (name, ip_addr, primary_key) VALUES (\'%u\', \'%L\', %{note:sql.user-primary-key})"',
        'SQLLog PASS session_start',
      ],
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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  eval {
    my ($name, $ip_addr, $primary_key) = get_session_with_primary_key($db_file,
      "name = \'$user\'");

    my $expected;

    $expected = $user;
    $self->assert($expected eq $name,
      test_msg("Expected name '$expected', got '$name'"));

    $expected = '127.0.0.1';
    $self->assert($expected eq $ip_addr,
      test_msg("Expected IP address '$expected', got '$ip_addr'"));

    $expected = $uid;
    $self->assert($expected == $primary_key,
      test_msg("Expected primary key $expected, got $primary_key"));
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

sub sql_groupprimarykey_bug3864 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

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
  shell TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $gid, '$user');

CREATE TABLE sessions (
  name TEXT,
  ip_addr TEXT,
  primary_key INTEGER
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'sql:20',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => 200,

        SQLGroupPrimaryKey => 'gid',

        SQLNamedQuery => 'session_start FREEFORM "INSERT INTO sessions (name, ip_addr, primary_key) VALUES (\'%g\', \'%L\', %{note:sql.group-primary-key})"',
        SQLLog => 'PASS session_start',
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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  eval {
    my ($name, $ip_addr, $primary_key) = get_session_with_primary_key($db_file,
      "name = \'$group\'");

    my $expected;

    $expected = $group;
    $self->assert($expected eq $name,
      test_msg("Expected name '$expected', got '$name'"));

    $expected = '127.0.0.1';
    $self->assert($expected eq $ip_addr,
      test_msg("Expected IP address '$expected', got '$ip_addr'"));

    $expected = $uid;
    $self->assert($expected == $primary_key,
      test_msg("Expected primary key $expected, got $primary_key"));
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

sub sql_groupprimarykey_custom_bug3864 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'sqlite');

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
  shell TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$setup->{user}', '$setup->{passwd}', $setup->{uid}, $setup->{gid}, '$setup->{home_dir}', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT,
  primary_key INTEGER
);
INSERT INTO groups (groupname, gid, members, primary_key) VALUES ('$setup->{group}', $setup->{gid}, '$setup->{user}', $setup->{gid});

CREATE TABLE sessions (
  name TEXT,
  ip_addr TEXT,
  primary_key INTEGER
);
EOS
    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'jot:20 sql:20',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => [
        'SQLAuthTypes plaintext',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $setup->{log_file}",
        'SQLMinID 200',

        'SQLNamedQuery get-group-primary-key SELECT "primary_key from groups WHERE groupname = \'%{0}\'"',
        'SQLGroupPrimaryKey custom:/get-group-primary-key',

        'SQLNamedQuery session_start FREEFORM "INSERT INTO sessions (name, ip_addr, primary_key) VALUES (\'%g\', \'%L\', %{note:sql.group-primary-key})"',
        'SQLLog PASS session_start',
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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
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

  if ($ex) {
    test_cleanup($setup->{log_file}, $ex);
  }

  eval {
    my ($name, $ip_addr, $primary_key) = get_session_with_primary_key($db_file,
      "name = \'$setup->{group}\'");

    my $expected = $setup->{group};
    $self->assert($expected eq $name, "Expected name '$expected', got '$name'");

    $expected = '127.0.0.1';
    $self->assert($expected eq $ip_addr,
      "Expected IP address '$expected', got '$ip_addr'");

    $expected = $setup->{gid};
    $self->assert($expected == $primary_key,
      "Expected primary key $expected, got $primary_key");
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub sql_sqllog_var_basename_bug3987 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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

  my $test_file = File::Spec->rel2abs($config_file);

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpsessions (
  user TEXT,
  ip_addr TEXT,
  dir TEXT
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
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
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'filename FREEFORM "INSERT INTO ftpsessions (user, ip_addr, dir) VALUES (\'%u\', \'%L\', \'%{basename}\')"',
        SQLLog => 'RETR filename',
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

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
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

  # Note: We are simply re-using the existing get_locations() function here
  # for convenience/expedience.
  my ($login, $ip_addr, $name) = get_locations($db_file, "user = \'$user\'");

  my $expected;

  $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected '$expected', got '$ip_addr'"));

  $expected = 'sqlite.conf';
  $self->assert($expected eq $name,
    test_msg("Expected '$expected', got '$name'"));

  unlink($log_file);
}

sub sql_user_info_defaulthomedir_bug4083 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs("$tmpdir/$user");
  mkpath($home_dir);
  my $uid = 500;
  my $gid = 500;

  my $default_home = File::Spec->rel2abs($tmpdir) . '/%u';

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT,
  passwd TEXT,
  uid INTEGER,
  gid INTEGER
);
INSERT INTO users (userid, passwd, uid, gid) VALUES ('$user', '$passwd', $uid, $gid);

EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
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

      'mod_sql.c' => {
        SQLAuthenticate => 'users',
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLUserInfo => 'users userid passwd uid gid Null Null',
        SQLDefaultHomedir => $default_home,
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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub sql_user_info_null_uid_gid_columns {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $default_home = '/tmp';
  my $default_uid = 14;
  my $default_gid = 28;

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE users (
  userid TEXT,
  passwd TEXT
);
INSERT INTO users (userid, passwd) VALUES ('$user', '$passwd');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$group', $default_gid, '$user');

EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
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

      'mod_sql.c' => {
        SQLAuthenticate => 'users groups',
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLUserInfo => 'users userid passwd Null Null Null Null',
        SQLDefaultUID => $default_uid,
        SQLDefaultGID => $default_gid,
        SQLDefaultHomedir => $default_home,
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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub sql_64_bit_uid_bug4164 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);

  # See: https://github.com/proftpd/proftpd/issues/74
  my $uid = 25440237859;
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
  shell TEXT
);
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$user', '$passwd', $uid, $gid, '$home_dir', '/bin/bash');

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
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
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

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLMinID => 100,
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

      my $resp_msgs = $client->response_msgs();
      my $nmsgs = scalar(@$resp_msgs);

      my $expected;

      $expected = 1;
      $self->assert($expected == $nmsgs,
        test_msg("Expected $expected, got $nmsgs")); 

      $expected = "User proftpd logged in";
      $self->assert($expected eq $resp_msgs->[0],
        test_msg("Expected '$expected', got '$resp_msgs->[0]'"));

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

sub get_port {
  my $db_file = shift;
  my $where = shift;

  my $sql = "SELECT user, ip_addr, port FROM ftpsessions";
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

sub sql_sqllog_var_remote_port {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/sqlite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/sqlite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/sqlite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/sqlite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/sqlite.group");

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

  my $test_file = File::Spec->rel2abs($config_file);

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE ftpsessions (
  user TEXT,
  ip_addr TEXT,
  port NUMBER
);
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
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
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'filename FREEFORM "INSERT INTO ftpsessions (user, ip_addr, port) VALUES (\'%u\', \'%L\', %{remote-port})"',
        SQLLog => 'RETR filename',
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

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
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

  my ($login, $ip_addr, $port) = get_port($db_file, "user = \'$user\'");

  my $expected = $user;
  $self->assert($expected eq $login,
    test_msg("Expected '$expected', got '$login'"));

  $expected = '127.0.0.1';
  $self->assert($expected eq $ip_addr,
    test_msg("Expected '$expected', got '$ip_addr'"));

  $expected = '^\d+$';
  $self->assert(qr/$expected/, $port,
    test_msg("Expected '$expected', got '$port'"));

  unlink($log_file);
}

sub sql_userowner_issue346 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'sqlite');

  my $uid = 0;
  my $gid = 0;

  my $test_file = File::Spec->rel2abs("$tmpdir/test.dat");
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
INSERT INTO users (userid, passwd, uid, gid, homedir, shell) VALUES ('$setup->{user}', '$setup->{passwd}', $uid, $gid, '$setup->{home_dir}', '/bin/bash');

CREATE TABLE groups (
  groupname TEXT,
  gid INTEGER,
  members TEXT
);
INSERT INTO groups (groupname, gid, members) VALUES ('$setup->{group}', $gid, '$setup->{user}');
EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script);

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      die("Can't set perms on $db_file to 0666: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    RootLogin => 'on',
    RootRevoke => 'off',

    Directory => {
      '/' => {
        UserOwner => 'www',
        GroupOwner => 'www',
      },
    },

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $setup->{log_file},
        SQLMinUserUID => 0,
        SQLMinUserGID => 0,
        SQLMinID => 0,
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

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0);
      $client->login($setup->{user}, $setup->{passwd});

      my $conn = $client->stor_raw('test.dat');
      unless ($conn) {
        die("STOR test.dat failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $text = "Hello, World!\n";
      $conn->write($text, length($text), 10);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);
      $client->quit();

      $self->assert(-f $test_file,
        "File $test_file does not exist as expected");

      my $file_uid = (stat($test_file))[4];
      my $file_gid = (stat($test_file))[5];

      $self->assert($file_uid != 0, "Expected UID non-0, got $file_uid");
      $self->assert($file_gid != 0, "Expected GID non-0, got $file_gid");
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

sub sql_sqlite_log_db_enoent_issue654 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'sqlite');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'sql:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $setup->{log_file},
        SQLNamedQuery => 'session_start FREEFORM "INSERT INTO ftpsessions (user, ip_addr, timestamp) VALUES (\'%u\', \'%L\', \'%{time:%Y-%m-%d %H:%M:%S}\')"',
        SQLLog => 'PASS session_start',
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

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      eval { $client->login($setup->{user}, $setup->{passwd}) };
      unless ($@) {
        $client->quit();
        die("Login succeeded unexpectedly");
      }
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
