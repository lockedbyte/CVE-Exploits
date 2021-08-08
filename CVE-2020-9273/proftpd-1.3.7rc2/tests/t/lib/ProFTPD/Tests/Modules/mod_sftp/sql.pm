package ProFTPD::Tests::Modules::mod_sftp::sql;

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
  sftp_sql_sqllog_var_xfer_status_nonxfer => {
    order => ++$order,
    test_class => [qw(forking mod_sql_sqlite)],
  },

  sftp_sql_sqllog_var_xfer_status_success_download => {
    order => ++$order,
    test_class => [qw(forking mod_sql_sqlite)],
  },

  sftp_sql_sqllog_var_xfer_status_success_upload => {
    order => ++$order,
    test_class => [qw(forking mod_sql_sqlite)],
  },

  sftp_sql_sqllog_var_xfer_status_failed_download => {
    order => ++$order,
    test_class => [qw(forking mod_sql_sqlite)],
  },

  sftp_sql_sqllog_var_xfer_status_failed_upload => {
    order => ++$order,
    test_class => [qw(forking mod_sql_sqlite)],
  },

  sftp_sql_sqllog_var_xfer_failure_none => {
    order => ++$order,
    test_class => [qw(forking mod_sql_sqlite)],
  },

  sftp_sql_sqllog_var_userauth_method => {
    order => ++$order,
    test_class => [qw(forking mod_sql_sqlite)],
  },

  sftp_sql_sqllog_var_userauth_method_env_var => {
    order => ++$order,
    test_class => [qw(forking mod_sql_sqlite)],
  },

  # XXX Need to support xfer_status_timeout, xfer_failure_reason
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

  # Make sure that mod_sftp does not complain about permissions on the hostkey
  # files.

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

  unless (chmod(0400, $rsa_host_key, $dsa_host_key)) {
    die("Can't set perms on $rsa_host_key, $dsa_host_key: $!");
  }
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
  return split(/\|/, $res);
}

sub sftp_sql_sqllog_var_xfer_status_nonxfer {
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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

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
    Trace => 'sql:20 command:20 netio:20 ssh2:20 sftp:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sftp.c' => [
        "SFTPEngine on",
        "SFTPLog $log_file",
        "SFTPHostKey $rsa_host_key",
        "SFTPHostKey $dsa_host_key",
      ],

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'xfer_status FREEFORM "INSERT INTO ftpsessions (user, ip_addr, xfer_status, xfer_path) VALUES (\'%u\', \'%L\', \'%{transfer-status}\', \'%f\')"',
        SQLLog => 'REALPATH xfer_status',
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

  require Net::SSH2;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $ssh2 = Net::SSH2->new();

      sleep(1);

      unless ($ssh2->connect('127.0.0.1', $port)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't connect to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      unless ($ssh2->auth_password($user, $passwd)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $sftp = $ssh2->sftp();
      unless ($sftp) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't use SFTP on SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $cwd = $sftp->realpath('.');
      unless ($cwd) {
        my ($err_code, $err_name) = $sftp->error();
        die("Can't get real path for '.': [$err_name] ($err_code)");
      }

      my $expected;

      $expected = $home_dir;

      if ($^O eq 'darwin') {
        # MacOSX hack
        $expected = ('/private' . $expected);
      }

      $self->assert($expected eq $cwd,
        test_msg("Expected '$expected', got '$cwd'"));

      $sftp = undef;
      $ssh2->disconnect();
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

  $expected = '-';
  $self->assert($expected eq $xfer_path,
    test_msg("Expected file path '$expected', got '$xfer_path'"));

  unlink($log_file);
}

sub sftp_sql_sqllog_var_xfer_status_success_download {
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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

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
    Trace => 'sql:20 command:20 netio:20 response:20 ssh2:20 sftp:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sftp.c' => [
        "SFTPEngine on",
        "SFTPLog $log_file",
        "SFTPHostKey $rsa_host_key",
        "SFTPHostKey $dsa_host_key",
      ],

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

  require Net::SSH2;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $ssh2 = Net::SSH2->new();

      sleep(1);

      unless ($ssh2->connect('127.0.0.1', $port)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't connect to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      unless ($ssh2->auth_password($user, $passwd)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $sftp = $ssh2->sftp();
      unless ($sftp) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't use SFTP on SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $fh = $sftp->open('test.txt', O_RDONLY);
      unless ($fh) {
        my ($err_code, $err_name) = $sftp->error();
        die("Can't open test.txt: [$err_name] ($err_code)");
      }

      my $buf;

      my $res = $fh->read($buf, 8192);
      while ($res) {
        $res = $fh->read($buf, 8192);
      }

      # To issue the FXP_CLOSE, we have to explicitly destroy the filehandle
      $fh = undef;

      # To close the SFTP channel, we have to explicitly destroy the object
      $sftp = undef;

      $ssh2->disconnect();
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
    # Mac OSX hack
    $test_file = '/private' . $test_file;
  }

  $expected = $test_file;
  $self->assert($expected eq $xfer_path,
    test_msg("Expected file path '$expected', got '$xfer_path'"));

  unlink($log_file);
}

sub sftp_sql_sqllog_var_xfer_status_success_upload {
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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

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

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'sql:20 command:20 netio:20 response:20 ssh2:20 sftp:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sftp.c' => [
        "SFTPEngine on",
        "SFTPLog $log_file",
        "SFTPHostKey $rsa_host_key",
        "SFTPHostKey $dsa_host_key",
      ],

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

  require Net::SSH2;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $ssh2 = Net::SSH2->new();

      sleep(1);

      unless ($ssh2->connect('127.0.0.1', $port)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't connect to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      unless ($ssh2->auth_password($user, $passwd)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $sftp = $ssh2->sftp();
      unless ($sftp) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't use SFTP on SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $fh = $sftp->open('test.txt', O_CREAT|O_WRONLY);
      unless ($fh) {
        my ($err_code, $err_name) = $sftp->error();
        die("Can't open test.txt: [$err_name] ($err_code)");
      }

      my $buf = "Hello, World!\n";
      my $res= $fh->write($buf);

      # To issue the FXP_CLOSE, we have to explicitly destroy the filehandle
      $fh = undef;

      # To close the SFTP channel, we have to explicitly destroy the object
      $sftp = undef;

      $ssh2->disconnect();
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
    # Mac OSX hack
    $test_file = '/private' . $test_file;
  }

  $expected = $test_file;
  $self->assert($expected eq $xfer_path,
    test_msg("Expected file path '$expected', got '$xfer_path'"));

  unlink($log_file);
}

sub sftp_sql_sqllog_var_xfer_status_failed_download {
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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

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
    Trace => 'sql:20 command:20 netio:20 response:20 ssh2:20 sftp:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    # This is used to tickle the "failed" transfer status
    MaxRetrieveFileSize => '12 B',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sftp.c' => [
        "SFTPEngine on",
        "SFTPLog $log_file",
        "SFTPHostKey $rsa_host_key",
        "SFTPHostKey $dsa_host_key",
      ],

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

  require Net::SSH2;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $ssh2 = Net::SSH2->new();

      sleep(1);

      unless ($ssh2->connect('127.0.0.1', $port)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't connect to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      unless ($ssh2->auth_password($user, $passwd)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $sftp = $ssh2->sftp();
      unless ($sftp) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't use SFTP on SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $fh = $sftp->open('test.txt', O_RDONLY);
      unless ($fh) {
        my ($err_code, $err_name) = $sftp->error();
        die("Can't open test.txt: [$err_name] ($err_code)");
      }

      # Explicitly close the channel before we have closed the file, to
      # simulate an "aborted" transfer.
      $sftp = undef;
      $ssh2->disconnect();

      # Give the server a little time to do its end-of-session thing.
      sleep(1);
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
    # Mac OSX hack
    $test_file = '/private' . $test_file;
  }

  $expected = $test_file;
  $self->assert($expected eq $xfer_path,
    test_msg("Expected file path '$expected', got '$xfer_path'"));

  unlink($log_file);
}

sub sftp_sql_sqllog_var_xfer_status_failed_upload {
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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

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

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh >> "Hello, World!  How are you doing?\n";

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
    Trace => 'sql:20 command:20 netio:20 response:20 ssh2:20 sftp:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    AllowOverwrite => 'on',
    AllowStoreRestart => 'on',

    # This is used to tickle the "failed" transfer status
    MaxStoreFileSize => '12 B',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sftp.c' => [
        "SFTPEngine on",
        "SFTPLog $log_file",
        "SFTPHostKey $rsa_host_key",
        "SFTPHostKey $dsa_host_key",
      ],

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $log_file,
        SQLNamedQuery => 'xfer_status FREEFORM "INSERT INTO ftpsessions (user, ip_addr, xfer_status, xfer_path) VALUES (\'%u\', \'%L\', \'%{transfer-status}\', \'%f\')"',
        SQLLog => 'ERR_APPE,ERR_STOR,APPE,STOR xfer_status',
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

  require Net::SSH2;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $ssh2 = Net::SSH2->new();

      sleep(1);

      unless ($ssh2->connect('127.0.0.1', $port)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't connect to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      unless ($ssh2->auth_password($user, $passwd)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $sftp = $ssh2->sftp();
      unless ($sftp) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't use SFTP on SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $fh = $sftp->open('test.txt', O_WRONLY|O_APPEND);
      unless ($fh) {
        my ($err_code, $err_name) = $sftp->error();
        die("Can't open test.txt: [$err_name] ($err_code)");
      }

      my $buf = "ABCDefgh" x 16382;
      unless ($fh->write($buf)) {
        my ($err_code, $err_name) = $sftp->error();
        die("Can't write test.txt: [$err_name] ($err_code)");
      }

      # Explicitly close the channel before we have closed the file, to
      # simulate an "aborted" transfer.
      $sftp = undef;
      $ssh2->disconnect();

      # Give the server a little time to do its end-of-session thing.
      sleep(1);
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
    # Mac OSX hack
    $test_file = '/private' . $test_file;
  }

  $expected = $test_file;
  $self->assert($expected eq $xfer_path,
    test_msg("Expected file path '$expected', got '$xfer_path'"));

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

sub sftp_sql_sqllog_var_xfer_failure_none {
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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

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
    Trace => 'sql:20 command:20 netio:20 response:20 ssh2:20 sftp:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sftp.c' => [
        "SFTPEngine on",
        "SFTPLog $log_file",
        "SFTPHostKey $rsa_host_key",
        "SFTPHostKey $dsa_host_key",
      ],

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

  require Net::SSH2;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $ssh2 = Net::SSH2->new();

      sleep(1);

      unless ($ssh2->connect('127.0.0.1', $port)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't connect to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      unless ($ssh2->auth_password($user, $passwd)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $sftp = $ssh2->sftp();
      unless ($sftp) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't use SFTP on SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $fh = $sftp->open('test.txt', O_RDONLY);
      unless ($fh) {
        my ($err_code, $err_name) = $sftp->error();
        die("Can't open test.txt: [$err_name] ($err_code)");
      }

      my $buf;

      my $res = $fh->read($buf, 8192);
      while ($res) {
        $res = $fh->read($buf, 8192);
      }

      # To issue the FXP_CLOSE, we have to explicitly destroy the filehandle
      $fh = undef;

      # To close the SFTP channel, we have to explicitly destroy the object
      $sftp = undef;

      $ssh2->disconnect();
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
    # Mac OSX hack
    $test_file = '/private' . $test_file;
  }

  $expected = $test_file;
  $self->assert($expected eq $xfer_path,
    test_msg("Expected file path '$expected', got '$xfer_path'"));

  unlink($log_file);
}

sub get_auth_methods {
  my $db_file = shift;
  my $where = shift;

  my $sql = "SELECT user, ip_addr, auth_method FROM sftpauth";
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

sub sftp_sql_sqllog_var_userauth_method {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'sqlite');

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE sftpauth (
  user TEXT,
  ip_addr TEXT,
  auth_method TEXT
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

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'sql:20 command:20 netio:20 response:20 ssh2:20 sftp:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sftp.c' => [
        "SFTPEngine on",
        "SFTPLog $setup->{log_file}",
        "SFTPHostKey $rsa_host_key",
        "SFTPHostKey $dsa_host_key",
      ],

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $setup->{log_file},
        SQLNamedQuery => 'auth_method FREEFORM "INSERT INTO sftpauth (user, ip_addr, auth_method) VALUES (\'%u\', \'%L\', \'%J\')"',
        SQLLog => 'ERR_USERAUTH_REQUEST,USERAUTH_REQUEST auth_method',
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

  require Net::SSH2;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $ssh2 = Net::SSH2->new();

      sleep(1);

      unless ($ssh2->connect('127.0.0.1', $port)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't connect to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      unless ($ssh2->auth_password($setup->{user}, $setup->{passwd})) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $sftp = $ssh2->sftp();
      unless ($sftp) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't use SFTP on SSH2 server: [$err_name] ($err_code) $err_str");
      }

      # To close the SFTP channel, we have to explicitly destroy the object
      $sftp = undef;

      $ssh2->disconnect();
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
    my ($login, $ip_addr, $auth_method) = get_auth_methods($db_file,
      "user = \'$setup->{user}\'");

    my $expected = $setup->{user};
    $self->assert($expected eq $login,
      "Expected user '$expected', got '$login'");

    $expected = '127.0.0.1';
    $self->assert($expected eq $ip_addr,
      "Expected IP address '$expected', got '$ip_addr'");

    $expected = "$setup->{user} password";
    $self->assert($expected eq $auth_method,
      "Expected method '$expected', got '$auth_method'");
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub sftp_sql_sqllog_var_userauth_method_env_var {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'sqlite');

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create users, groups tables and populate them
  my $db_script = File::Spec->rel2abs("$tmpdir/proftpd.sql");

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE sftpauth (
  user TEXT,
  ip_addr TEXT,
  auth_method TEXT
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

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'sql:20 command:20 netio:20 response:20 ssh2:20 sftp:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sftp.c' => [
        "SFTPEngine on",
        "SFTPLog $setup->{log_file}",
        "SFTPHostKey $rsa_host_key",
        "SFTPHostKey $dsa_host_key",
      ],

      'mod_sql.c' => {
        SQLEngine => 'log',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $setup->{log_file},
        SQLNamedQuery => 'auth_method FREEFORM "INSERT INTO sftpauth (user, ip_addr, auth_method) VALUES (\'%u\', \'%L\', \'%{env:SFTP_USER_AUTH_METHOD}\')"',
        SQLLog => 'PASS auth_method',
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

  require Net::SSH2;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $ssh2 = Net::SSH2->new();

      sleep(1);

      unless ($ssh2->connect('127.0.0.1', $port)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't connect to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      unless ($ssh2->auth_password($setup->{user}, $setup->{passwd})) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $sftp = $ssh2->sftp();
      unless ($sftp) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't use SFTP on SSH2 server: [$err_name] ($err_code) $err_str");
      }

      # To close the SFTP channel, we have to explicitly destroy the object
      $sftp = undef;

      $ssh2->disconnect();
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
    my ($login, $ip_addr, $auth_method) = get_auth_methods($db_file,
      "user = \'$setup->{user}\'");

    my $expected = $setup->{user};
    $self->assert($expected eq $login,
      "Expected user '$expected', got '$login'");

    $expected = '127.0.0.1';
    $self->assert($expected eq $ip_addr,
      "Expected IP address '$expected', got '$ip_addr'");

    $expected = 'password';
    $self->assert($expected eq $auth_method,
      "Expected method '$expected', got '$auth_method'");
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

1;
