package ProFTPD::Tests::Modules::mod_copy;

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
  copy_file => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  copy_file_no_login_bug4169 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  copy_dir => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  copy_enoent => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  copy_before_auth => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  copy_help => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  copy_config_allowoverwrite => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  copy_config_limit => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  copy_config_pathdenyfilter => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  copy_quotatab_file_dst_enoent => {
    order => ++$order,
    test_class => [qw(forking mod_quotatab_sql mod_sql_sqlite)],
  },

  copy_quotatab_file_dst_zero_len => {
    order => ++$order,
    test_class => [qw(forking mod_quotatab_sql mod_sql_sqlite)],
  },

  copy_quotatab_file_dst_equal_len => {
    order => ++$order,
    test_class => [qw(forking mod_quotatab_sql mod_sql_sqlite)],
  },

  copy_quotatab_file_dst_smaller_len => {
    order => ++$order,
    test_class => [qw(forking mod_quotatab_sql mod_sql_sqlite)],
  },

  copy_quotatab_file_dst_larger_len => {
    order => ++$order,
    test_class => [qw(forking mod_quotatab_sql mod_sql_sqlite)],
  },

  copy_cpfr_cpto => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  copy_cpfr_cpto_no_login_bug4169 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  copy_cpto_no_cpfr => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  copy_cpfr_cpto_paths_with_spaces => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  copy_config_limit_bug3399 => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  copy_cpto_quotatab_file_dst_enopc_bug4262 => {
    order => ++$order,
    test_class => [qw(bug forking mod_quotatab_sql mod_sql_sqlite)],
  },

  copy_cpto_timeout_bug4263 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  copy_cpfr_config_limit_read_bug4372 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  copy_cpto_config_limit_write_bug4372 => {
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

sub copy_file {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/copy.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/copy.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/copy.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/copy.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/copy.group");

  my $user = 'proftpd';
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

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $src_file = File::Spec->rel2abs("$home_dir/foo.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$home_dir/bar.txt");

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

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->site('COPY', 'foo.txt', 'bar.txt');

      my $expected;
      $expected = 200;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "SITE COPY command successful";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      unless (-f $dst_file) {
        die("File $dst_file does not exist as expected");
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
    die($ex);
  }

  unlink($log_file);
}

sub copy_file_no_login_bug4169 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/copy.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/copy.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/copy.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/copy.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/copy.group");

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

  my $src_file = File::Spec->rel2abs("$home_dir/foo.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$home_dir/bar.txt");

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

      eval { $client->site('COPY', 'foo.txt', 'bar.txt') };
      unless ($@) { 
        die("SITE COPY succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;
      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Please login with USER and PASS";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
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

sub copy_dir {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/copy.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/copy.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/copy.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/copy.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/copy.group");

  my $user = 'proftpd';
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

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $src_dir = File::Spec->rel2abs("$home_dir/foo");
  mkpath($src_dir);

  my $src_file = File::Spec->rel2abs("$src_dir/test.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_dir = File::Spec->rel2abs("$home_dir/bar/baz");
  mkpath($dst_dir);

  my $dst_file = File::Spec->rel2abs("$dst_dir/test.txt");

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

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->site('COPY', 'foo', 'bar/baz');

      my $expected;
      $expected = 200;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "SITE COPY command successful";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      unless (-d $dst_dir) {
        die("Directory $dst_dir does not exist as expected");
      }

      unless (-f $dst_file) {
        die("File $dst_file does not exist as expected");
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
    die($ex);
  }

  unlink($log_file);
}

sub copy_enoent {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/copy.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/copy.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/copy.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/copy.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/copy.group");

  my $user = 'proftpd';
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

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $src_file = File::Spec->rel2abs("$home_dir/foo.txt");
  my $dst_file = File::Spec->rel2abs("$home_dir/bar.txt");

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

      my ($resp_code, $resp_msg);
      eval { $client->site('COPY', 'foo.txt', 'bar.txt') };
      unless ($@) {
        die("SITE COPY succeeded unexpectedly");
      } 

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;
      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "COPY: No such file or directory";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      if (-f $dst_file) {
        die("File $dst_file exists unexpectedly");
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
    die($ex);
  }

  unlink($log_file);
}

sub copy_before_auth {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/copy.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/copy.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/copy.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/copy.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/copy.group");

  my $user = 'proftpd';
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

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $src_file = File::Spec->rel2abs("$home_dir/foo.txt");
  my $dst_file = File::Spec->rel2abs("$home_dir/bar.txt");

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

      eval { $client->site('COPY', 'foo.txt', 'bar.txt') };
      unless ($@) {
        die("SITE COPY succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;
      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Please login with USER and PASS";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      if (-f $dst_file) {
        die("File $dst_file exists unexpectedly");
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
    die($ex);
  }

  unlink($log_file);
}

sub copy_help {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/copy.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/copy.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/copy.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/copy.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/copy.group");

  my $user = 'proftpd';
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

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $src_file = File::Spec->rel2abs("$home_dir/foo.txt");
  my $dst_file = File::Spec->rel2abs("$home_dir/bar.txt");

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

      $client->site('HELP');

      my $resp_code = $client->response_code();
      my $resp_msgs = $client->response_msgs();

      my $expected;
      $expected = 214;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'CPFR <sp> pathname';
      my $ok = 0;
      foreach my $msg (@$resp_msgs) {
        if ($msg =~ /$expected/) {
          $ok = 1;
          last;
        }
      }

      unless ($ok) {
        die("Failed to receive expected HELP output");
      }

      $expected = 'CPTO <sp> pathname';
      $ok = 0;
      foreach my $msg (@$resp_msgs) {
        if ($msg =~ /$expected/) {
          $ok = 1;
          last;
        }
      }

      unless ($ok) {
        die("Failed to receive expected HELP output");
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
    die($ex);
  }

  unlink($log_file);
}

sub copy_config_limit {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/copy.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/copy.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/copy.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/copy.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/copy.group");

  my $user = 'proftpd';
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

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $src_file = File::Spec->rel2abs("$home_dir/foo.txt");
  my $dst_file = File::Spec->rel2abs("$home_dir/bar.txt");

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
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Limit SITE_COPY>
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

      my ($resp_code, $resp_msg);
      eval { $client->site('COPY', 'foo.txt', 'bar.txt') };
      unless ($@) {
        die("SITE COPY succeeded unexpectedly");
      } 

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;
      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "bar.txt: Operation not permitted";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      if (-f $dst_file) {
        die("File $dst_file exists unexpectedly");
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
    die($ex);
  }

  unlink($log_file);
}

sub copy_config_allowoverwrite {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/copy.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/copy.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/copy.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/copy.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/copy.group");

  my $user = 'proftpd';
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

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $src_file = File::Spec->rel2abs("$home_dir/foo.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$home_dir/bar.txt");
  if (open(my $fh, "> $dst_file")) {
    print $fh "Farwell, World!\n";
    unless (close($fh)) {
      die("Can't write $dst_file: $!");
    }

  } else {
    die("Can't open $dst_file: $!");
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

      my ($resp_code, $resp_msg);
      eval { $client->site('COPY', 'foo.txt', 'bar.txt') };
      unless ($@) {
        die("SITE COPY succeeded unexpectedly");
      } 

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;
      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "COPY: Permission denied";
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
    die($ex);
  }

  unlink($log_file);
}

sub copy_config_pathdenyfilter {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/copy.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/copy.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/copy.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/copy.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/copy.group");

  my $user = 'proftpd';
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

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $src_file = File::Spec->rel2abs("$home_dir/foo.txt");
  my $dst_file = File::Spec->rel2abs("$home_dir/bar.txt");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    PathDenyFilter => '\.txt$',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      my ($resp_code, $resp_msg);
      eval { $client->site('COPY', 'foo.txt', 'bar.txt') };
      unless ($@) {
        die("SITE COPY succeeded unexpectedly");
      } 

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;
      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "COPY: Operation not permitted";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      if (-f $dst_file) {
        die("File $dst_file exists unexpectedly");
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
    die($ex);
  }

  unlink($log_file);
}

sub copy_quotatab_file_dst_enoent {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/copy.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/copy.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/copy.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/copy.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/copy.group");

  my $user = 'proftpd';
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
INSERT INTO groups (groupname, gid, members) VALUES ('ftpd', $gid, '$user');

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

  my $src_file = File::Spec->rel2abs("$home_dir/foo.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$home_dir/bar.txt");

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

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->site('COPY', 'foo.txt', 'bar.txt');

      my $expected;
      $expected = 200;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "SITE COPY command successful";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      unless (-f $dst_file) {
        die("File $dst_file does not exist as expected");
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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$user\'");

  my $expected;

  $expected = '^(14.0|14)$';
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
    die($ex);
  }

  unlink($log_file);
}

sub copy_quotatab_file_dst_zero_len {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/copy.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/copy.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/copy.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/copy.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/copy.group");

  my $user = 'proftpd';
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
INSERT INTO groups (groupname, gid, members) VALUES ('ftpd', $gid, '$user');

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

  my $src_file = File::Spec->rel2abs("$home_dir/foo.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$home_dir/bar.txt");
  if (open(my $fh, "> $dst_file")) {
    close($fh);

  } else {
    die("Can't open $dst_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AllowOverwrite => 'on',
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

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->site('COPY', 'foo.txt', 'bar.txt');

      my $expected;
      $expected = 200;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "SITE COPY command successful";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      unless (-f $dst_file) {
        die("File $dst_file does not exist as expected");
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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$user\'");

  my $expected;

  $expected = '^(14.0|14)$';
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
    die($ex);
  }

  unlink($log_file);
}

sub copy_quotatab_file_dst_equal_len {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/copy.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/copy.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/copy.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/copy.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/copy.group");

  my $user = 'proftpd';
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
INSERT INTO groups (groupname, gid, members) VALUES ('ftpd', $gid, '$user');

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

  my $src_file = File::Spec->rel2abs("$home_dir/foo.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$home_dir/bar.txt");
  if (open(my $fh, "> $dst_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $dst_file: $!");
    }

  } else {
    die("Can't open $dst_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AllowOverwrite => 'on',
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

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->site('COPY', 'foo.txt', 'bar.txt');

      my $expected;
      $expected = 200;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "SITE COPY command successful";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      unless (-f $dst_file) {
        die("File $dst_file does not exist as expected");
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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$user\'");

  my $expected;

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
    die($ex);
  }

  unlink($log_file);
}

sub copy_quotatab_file_dst_smaller_len {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/copy.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/copy.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/copy.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/copy.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/copy.group");

  my $user = 'proftpd';
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
INSERT INTO groups (groupname, gid, members) VALUES ('ftpd', $gid, '$user');

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

  my $src_file = File::Spec->rel2abs("$home_dir/foo.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$home_dir/bar.txt");
  if (open(my $fh, "> $dst_file")) {
    print $fh "Hello\n";

    unless (close($fh)) {
      die("Can't write $dst_file: $!");
    }

  } else {
    die("Can't open $dst_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AllowOverwrite => 'on',
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

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->site('COPY', 'foo.txt', 'bar.txt');

      my $expected;
      $expected = 200;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "SITE COPY command successful";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      unless (-f $dst_file) {
        die("File $dst_file does not exist as expected");
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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$user\'");

  my $expected;

  $expected = '^(8.0|8)$';
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
    die($ex);
  }

  unlink($log_file);
}

sub copy_quotatab_file_dst_larger_len {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/copy.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/copy.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/copy.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/copy.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/copy.group");

  my $user = 'proftpd';
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
INSERT INTO groups (groupname, gid, members) VALUES ('ftpd', $gid, '$user');

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
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$user', 'user', 'false', 'soft', 128, 0, 0, 2, 0, 0);

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
INSERT INTO quotatallies (name, quota_type, bytes_in_used, bytes_out_used, bytes_xfer_used, files_in_used, files_out_used, files_xfer_used) VALUES ('$user', 'user', 96, 0, 0, 2, 0, 0);
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

  my $src_file = File::Spec->rel2abs("$home_dir/foo.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$home_dir/bar.txt");
  if (open(my $fh, "> $dst_file")) {
    print $fh "Celebrating and suffering Life; something we all do every day\n";

    unless (close($fh)) {
      die("Can't write $dst_file: $!");
    }

  } else {
    die("Can't open $dst_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AllowOverwrite => 'on',
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

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->site('COPY', 'foo.txt', 'bar.txt');

      my $expected;
      $expected = 200;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "SITE COPY command successful";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      unless (-f $dst_file) {
        die("File $dst_file does not exist as expected");
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

  my ($quota_type, $bytes_in_used, $bytes_out_used, $bytes_xfer_used, $files_in_used, $files_out_used, $files_xfer_used) = get_tally($db_file, "name = \'$user\'");

  my $expected;

  $expected = '^(48.0|48)$';
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
    die($ex);
  }

  unlink($log_file);
}

sub copy_cpfr_cpto {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/copy.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/copy.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/copy.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/copy.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/copy.group");

  my $user = 'proftpd';
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

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $src_file = File::Spec->rel2abs("$home_dir/foo.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$home_dir/bar.txt");

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

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->site('CPFR', 'foo.txt');

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

      unless (-f $dst_file) {
        die("File $dst_file does not exist as expected");
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
    die($ex);
  }

  unlink($log_file);
}

sub copy_cpfr_cpto_no_login_bug4169 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/copy.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/copy.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/copy.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/copy.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/copy.group");

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

  my $src_file = File::Spec->rel2abs("$home_dir/foo.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$home_dir/bar.txt");

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
 
      eval { $client->site('CPFR', 'foo.txt') };
      unless ($@) {
        die("SITE CPFR succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;
      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Please login with USER and PASS";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      eval { $client->site('CPTO', 'bar.txt') };
      unless ($@) {
        die("SITE CPTO succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Please login with USER and PASS";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
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

sub copy_cpto_no_cpfr {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/copy.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/copy.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/copy.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/copy.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/copy.group");

  my $user = 'proftpd';
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

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $src_file = File::Spec->rel2abs("$home_dir/foo.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$home_dir/bar.txt");

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

      my ($resp_code, $resp_msg);

      eval { $client->site('CPTO', 'bar.txt') };
      unless ($@) {
        die("SITE CPTO bar.txt succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;
      $expected = 503;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Bad sequence of commands";
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
    die($ex);
  }

  unlink($log_file);
}

sub copy_cpfr_cpto_paths_with_spaces {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/copy.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/copy.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/copy.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/copy.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/copy.group");

  my $user = 'proftpd';
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

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $src_file = File::Spec->rel2abs("$home_dir/foo bar.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$home_dir/baz quxx.txt");

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

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->site('CPFR', 'foo bar.txt');

      my $expected;
      $expected = 350;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "File or directory exists, ready for destination name";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      ($resp_code, $resp_msg) = $client->site('CPTO', 'baz quxx.txt');

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Copy successful";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      unless (-f $dst_file) {
        die("File $dst_file does not exist as expected");
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
    die($ex);
  }

  unlink($log_file);
}

sub copy_config_limit_bug3399 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/copy.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/copy.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/copy.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/copy.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/copy.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $sub_dir = File::Spec->rel2abs("$home_dir/subdir");
  mkpath($sub_dir);

  my $src_file = File::Spec->rel2abs("$sub_dir/foo.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$sub_dir/bar.txt");

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
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

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
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  my $config_subdir = $sub_dir;
  if ($^O eq 'darwin') {
    # MacOSX hack
    $config_subdir = '/private' . $sub_dir;
  }

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Directory />
  <Limit WRITE>
    DenyAll
  </Limit>
</Directory>

<Directory $config_subdir>
  <Limit WRITE>
    AllowAll
  </Limit>
</Directory>
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
      $client->cwd('subdir');

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->site('COPY', 'foo.txt bar.txt');

      my $expected;
      $expected = 200;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "SITE COPY command successful";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      unless (-f $dst_file) {
        die("File $dst_file does not exist as expected");
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
    die($ex);
  }

  unlink($log_file);
}

sub copy_cpto_quotatab_file_dst_enopc_bug4262 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'copy');

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
INSERT INTO groups (groupname, gid, members) VALUES ('ftpd', $setup->{gid}, '$setup->{user}');

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
INSERT INTO quotalimits (name, quota_type, per_session, limit_type, bytes_in_avail, bytes_out_avail, bytes_xfer_avail, files_in_avail, files_out_avail, files_xfer_avail) VALUES ('$setup->{user}', 'user', 'false', 'hard', 32, 0, 0, 2, 0, 0);

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

  my $src_file = File::Spec->rel2abs("$setup->{home_dir}/foo.txt");
  if (open(my $fh, "> $src_file")) {
    # Make sure this file is larger than the allowed number of upload bytes
    print $fh "Hello, World!\n" x 1024;

    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$setup->{home_dir}/bar.txt");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'fsio:20',

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
        AuthOrder => 'mod_sql.c',
        SQLAuthTypes => 'plaintext',
        SQLBackend => 'sqlite3',
        SQLConnectInfo => $db_file,
        SQLLogFile => $setup->{log_file},
        SQLMinID => '0',
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
      sleep(1);

      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      $client->login($setup->{user}, $setup->{passwd});

      my ($resp_code, $resp_msg) = $client->site('CPFR', 'foo.txt');

      my $expected = 350;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "File or directory exists, ready for destination name";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      eval { $client->site('CPTO', 'bar.txt') };
      unless ($@) {
        die("SITE CPTO succeeded unexpectedly");
      }

      $resp_code = $client->response_code();

      $expected = 552;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $client->quit();

      $self->assert(!-f $dst_file,
        test_msg("File $dst_file exists unexpectedly"));
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

sub copy_cpto_timeout_bug4263 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'copy');

  my $src_file = File::Spec->rel2abs("$tmpdir/foo.dat");
  if (open(my $fh, "> $src_file")) {
    if ($ENV{TEST_VERBOSE}) {
      print STDERR "# Writing source file\n";
    }

    my $count = 20000;
    for (my $i = 0; $i < $count; $i++) {
      print $fh "AbCdEfGh" x 32768;
    }

    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/bar.dat");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'copy:20 timer:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutIdle => 3,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      my ($resp_code, $resp_msg) = $client->site('CPFR', 'foo.dat');

      my $expected = 350;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "File or directory exists, ready for destination name";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      ($resp_code, $resp_msg) = $client->site('CPTO', 'bar.dat');

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Copy successful";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      unless (-f $dst_file) {
        die("File $dst_file does not exist as expected");
      }
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, 30) };
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

sub copy_cpfr_config_limit_read_bug4372 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'copy');

  my $src_file = File::Spec->rel2abs("$tmpdir/foo.dat");
  if (open(my $fh, "> $src_file")) {
    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'copy:20 timer:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutIdle => 3,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($setup->{config_file},
    $config);

  if (open(my $fh, ">> $setup->{config_file}")) {
    print $fh <<EOC;
<Directory />
  <Limit READ>
    DenyAll
  </Limit>
</Directory>
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

      eval { $client->site('CPFR', 'foo.dat') };
      unless ($@) {
        die("SITE CPFR succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'Operation not permitted';
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
    eval { server_wait($setup->{config_file}, $rfh, 30) };
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

sub copy_cpto_config_limit_write_bug4372 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'copy');

  my $src_file = File::Spec->rel2abs("$tmpdir/foo.dat");
  if (open(my $fh, "> $src_file")) {
    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/bar.dat");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'copy:20 timer:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutIdle => 3,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($setup->{config_file},
    $config);

  if (open(my $fh, ">> $setup->{config_file}")) {
    print $fh <<EOC;
<Directory />
  <Limit WRITE>
    DenyAll
  </Limit>
</Directory>
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

      my ($resp_code, $resp_msg) = $client->site('CPFR', 'foo.dat');

      my $expected = 350;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'File or directory exists, ready for destination name';
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      eval { $client->site('CPTO', 'bar.dat') };
      unless ($@) {
        die('SITE CPTO succeeded unexpectedly');
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'Operation not permitted';
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
    eval { server_wait($setup->{config_file}, $rfh, 30) };
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
