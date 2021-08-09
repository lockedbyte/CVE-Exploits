package ProFTPD::Tests::Config::Directory::Limits;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use Cwd;
use File::Path qw(mkpath);
use File::Spec;
use IO::Handle;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

# A fun collection of various <Directory> and <Limit> configurations

my $TESTS = {
  limits_with_glob_then_nonglob_dirs_for_same_path => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  limits_with_nonglob_then_glob_dirs_for_same_path => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  limits_with_glob_denied_delete_bug3146 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  limits_without_glob_denied_delete_bug3146 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  limits_commands_comma_space_delimited_deferred_paths_bug3147 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  limits_commands_comma_delimited_deferred_paths_bug3147 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  limits_commands_no_commas_deferred_paths_bug3147 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  limits_rename_dir_ok_write_denied => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  limits_rename_dir_failed_rnfr_denied => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  limits_one_char_dir_bug3337 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  limits_symlink_dir_bug3166 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  limits_anon_dir_abs_path_bug3283 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  limits_with_multi_globs_denied_delete => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  limits_retr_bug3915 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  limits_retr_bug3915_chrooted => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  limits_stor_with_multiple_groups_chrooted => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub limits_with_glob_then_nonglob_dirs_for_same_path {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/dir.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/dir.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/dir.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/dir.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/dir.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs("$tmpdir/home/users/$user");
  my $uid = 500;
  my $gid = 500;

  mkpath($home_dir);

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

  my $abs_tmp_dir = File::Spec->rel2abs($tmpdir);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 fsio:0 directory:10 lock:0',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  # In order to ensure that the <Directory> sections appear in the desired
  # order in the config file, we write them out here.  The config_write()
  # function, whilst useful, uses hashrefs, which means the ordering of the
  # keys is not necessarily predictable.
  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOD;
<Directory $abs_tmp_dir/home/*/proftpd>
  <Limit ALL>
    DenyAll
  </Limit>
</Directory>
<Directory $abs_tmp_dir/home/users/proftpd>
  <Limit ALL>
    AllowAll
  </Limit>
</Directory>
EOD
    close($fh);

  } else {
    die("Can't read $config_file: $!");
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

      my $conn = $client->stor_raw('test.txt');
      unless ($conn) {
        die("Failed to STOR test.txt: " . $client->response_code() . " " .
          $client->response_msg());
      };

      my $buf = "Hello, World\n";
      $conn->write($buf, length($buf));
      $conn->close();

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Transfer complete";
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

  unlink($log_file);
}

sub limits_with_nonglob_then_glob_dirs_for_same_path {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/dir.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/dir.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/dir.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/dir.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/dir.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs("$tmpdir/home/users/$user");
  my $uid = 500;
  my $gid = 500;

  mkpath($home_dir);

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

  my $abs_tmp_dir = File::Spec->rel2abs($tmpdir);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 fsio:0 directory:10 lock:0',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  # In order to ensure that the <Directory> sections appear in the desired
  # order in the config file, we write them out here.  The config_write()
  # function, whilst useful, uses hashrefs, which means the ordering of the
  # keys is not necessarily predictable.
  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOD;
<Directory $abs_tmp_dir/home/users/proftpd>
  <Limit ALL>
    AllowAll
  </Limit>
</Directory>
<Directory $abs_tmp_dir/home/*/proftpd>
  <Limit ALL>
    DenyAll
  </Limit>
</Directory>
EOD
    close($fh);

  } else {
    die("Can't read $config_file: $!");
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

      my $conn = $client->stor_raw('test.txt');
      if ($conn) {
        die("STOR test.txt succeeded unexpectedly");
      };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "test.txt: Operation not permitted";
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

  unlink($log_file);
}

sub limits_with_glob_denied_delete_bug3146 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  # This config is from:
  #
  #  http://forums.proftpd.org/smf/index.php/topic,3491.0
  #  http://bugs.proftpd.org/show_bug.cgi?id=3146

  my $config_file = "$tmpdir/dir.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/dir.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/dir.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/dir.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/dir.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs("$tmpdir/home/users/$user");
  my $uid = 500;
  my $gid = 500;

  mkpath($home_dir);

  my $test_file = File::Spec->rel2abs("$home_dir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
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
 
  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $abs_tmp_dir = File::Spec->rel2abs($tmpdir);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 fsio:0 directory:10 lock:0',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    DefaultChdir => '~',

    Directory => {
      "$abs_tmp_dir/home/*/proftpd" => {
        Limit => {
          'ALL' => {
            DenyAll => '',
          },

          'CDUP CWD XCWD XCUP LIST NLST' => {
            AllowAll => '',
          },

          'STOR STOU' => {
            AllowAll => '',
          },
        },
      },
    },

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
      eval { $client->dele('test.txt') };
      unless ($@) {
        die("DELE succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "test.txt: Operation not permitted";
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

  unlink($log_file);
}

sub limits_without_glob_denied_delete_bug3146 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  # This config is from:
  #
  #  http://forums.proftpd.org/smf/index.php/topic,3491.0
  #
  # only without the glob pattern, to check for regressions.

  my $config_file = "$tmpdir/dir.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/dir.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/dir.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/dir.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/dir.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs("$tmpdir/home/users/$user");
  my $uid = 500;
  my $gid = 500;

  mkpath($home_dir);

  my $test_file = File::Spec->rel2abs("$home_dir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
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
 
  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $abs_tmp_dir = File::Spec->rel2abs($tmpdir);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 fsio:0 directory:10 lock:0',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    DefaultChdir => '~',

    Directory => {
      "$abs_tmp_dir/home/users/proftpd" => {
        Limit => {
          'ALL' => {
            DenyAll => '',
          },

          'CDUP CWD XCWD XCUP LIST NLST' => {
            AllowAll => '',
          },

          'STOR STOU' => {
            AllowAll => '',
          },
        },
      },
    },

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
      eval { $client->dele('test.txt') };
      unless ($@) {
        die("DELE succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "test.txt: Operation not permitted";
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

  unlink($log_file);
}

sub limits_commands_comma_space_delimited_deferred_paths_bug3147 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  # This config is from:
  #
  #  http://forums.proftpd.org/smf/index.php/topic,3648.0
  #  http://bugs.proftpd.org/show_bug.cgi?id=3147

  my $config_file = "$tmpdir/dir.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/dir.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/dir.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/dir.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/dir.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs("$tmpdir/home/$user");
  my $uid = 500;
  my $gid = 500;

  mkpath($home_dir);

  my $sub_dir = File::Spec->rel2abs("$tmpdir/home/$user/upload");
  mkpath($sub_dir);

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir, $sub_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
      die("Can't set owner of $home_dir, $sub_dir to $uid/$gid: $!");
    }
  }
 
  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 fsio:0 directory:10 lock:0',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    DefaultChdir => '~',

    Directory => {
      "~$user" => {
        Limit => {
          'WRITE' => {
            DenyAll => '',
          },
        },
      },

      # Bug#3147 happened because proftpd's parsing of the list of commands
      # in the <Limit> section was not properly handling commas after the
      # command names.

      "~$user/upload" => {
        Limit => {
          'STOR, APPE, MKD, RMD, RNTO, STOU, XMKD, XRMD' => {
            AllowAll => '',
          },
        },
      },
    },

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

      my $conn = $client->stor_raw('upload/test.txt');
      unless ($conn) {
        die("Failed to STOR upload/test.txt: " . $client->response_code() .
          " " . $client->response_msg());
      }

      my $buf = "Hello, World!\n";
      $conn->write($buf, length($buf));
      $conn->close();

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Transfer complete";
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

  unlink($log_file);
}

sub limits_commands_comma_delimited_deferred_paths_bug3147 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  # This config is from:
  #
  #  http://forums.proftpd.org/smf/index.php/topic,3648.0
  #  http://bugs.proftpd.org/show_bug.cgi?id=3147

  my $config_file = "$tmpdir/dir.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/dir.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/dir.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/dir.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/dir.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs("$tmpdir/home/$user");
  my $uid = 500;
  my $gid = 500;

  mkpath($home_dir);

  my $sub_dir = File::Spec->rel2abs("$tmpdir/home/$user/upload");
  mkpath($sub_dir);

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir, $sub_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
      die("Can't set owner of $home_dir, $sub_dir to $uid/$gid: $!");
    }
  }
 
  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 fsio:0 directory:10 lock:0',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    DefaultChdir => '~',

    Directory => {
      "~$user" => {
        Limit => {
          'WRITE' => {
            DenyAll => '',
          },
        },
      },

      # Bug#3147 happened because proftpd's parsing of the list of commands
      # in the <Limit> section was not properly handling commas after the
      # command names.

      "~$user/upload" => {
        Limit => {
          'STOR,APPE,MKD,RMD,RNTO,STOU,XMKD,XRMD' => {
            AllowAll => '',
          },
        },
      },
    },

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

      my $conn = $client->stor_raw('upload/test.txt');
      unless ($conn) {
        die("Failed to STOR upload/test.txt: " . $client->response_code() .
          " " . $client->response_msg());
      }

      my $buf = "Hello, World!\n";
      $conn->write($buf, length($buf));
      $conn->close();

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Transfer complete";
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

  unlink($log_file);
}

sub limits_commands_no_commas_deferred_paths_bug3147 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  # This config is from:
  #
  #  http://forums.proftpd.org/smf/index.php/topic,3648.0
  #  http://bugs.proftpd.org/show_bug.cgi?id=3147

  my $config_file = "$tmpdir/dir.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/dir.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/dir.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/dir.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/dir.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs("$tmpdir/home/$user");
  my $uid = 500;
  my $gid = 500;

  mkpath($home_dir);

  my $sub_dir = File::Spec->rel2abs("$tmpdir/home/$user/upload");
  mkpath($sub_dir);

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir, $sub_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
      die("Can't set owner of $home_dir, $sub_dir to $uid/$gid: $!");
    }
  }
 
  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 fsio:0 directory:10 lock:0',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    DefaultChdir => '~',

    Directory => {
      "~$user" => {
        Limit => {
          'WRITE' => {
            DenyAll => '',
          },
        },
      },

      # Bug#3147 happened because proftpd's parsing of the list of commands
      # in the <Limit> section was not properly handling commas after the
      # command names.  Make sure the fix for Bug#3147 doesn't break command
      # lists which DO NOT use commas.

      "~$user/upload" => {
        Limit => {
          'STOR APPE MKD RMD RNTO STOU XMKD XRMD' => {
            AllowAll => '',
          },
        },
      },
    },

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

      my $conn = $client->stor_raw('upload/test.txt');
      unless ($conn) {
        die("Failed to STOR upload/test.txt: " . $client->response_code() .
          " " . $client->response_msg());
      }

      my $buf = "Hello, World!\n";
      $conn->write($buf, length($buf));
      $conn->close();

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Transfer complete";
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

  unlink($log_file);
}

sub limits_rename_dir_ok_write_denied {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/dir.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/dir.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/dir.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/dir.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/dir.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs("$tmpdir/home/$user");
  my $uid = 500;
  my $gid = 500;

  mkpath($home_dir);

  my $sub_dir = File::Spec->rel2abs("$tmpdir/home/$user/upload");
  mkpath($sub_dir);

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir, $sub_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
      die("Can't set owner of $home_dir, $sub_dir to $uid/$gid: $!");
    }
  }
 
  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 fsio:0 directory:10 lock:0',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    DefaultChdir => '~',

    Directory => {
      "~$user/*" => {
        Limit => {
          'CWD XCWD RNFR RNTO' => {
            AllowAll => '',
          },

          'ALL' => {
            DenyAll => '',
          },
        },
      },

      "~$user/upload" => {
        Limit => {
          'WRITE' => {
            DenyAll => '',
          },
        },
      },
    },

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

      ($resp_code, $resp_msg) = $client->rnfr('upload');

      my $expected;

      $expected = 350;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "File or directory exists, ready for destination name";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      ($resp_code, $resp_msg) = $client->rnto('upload2');

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Rename successful";
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

  unlink($log_file);
}

sub limits_rename_dir_failed_rnfr_denied {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/dir.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/dir.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/dir.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/dir.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/dir.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs("$tmpdir/home/$user");
  my $uid = 500;
  my $gid = 500;

  mkpath($home_dir);

  my $sub_dir = File::Spec->rel2abs("$tmpdir/home/$user/upload");
  mkpath($sub_dir);

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir, $sub_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
      die("Can't set owner of $home_dir, $sub_dir to $uid/$gid: $!");
    }
  }
 
  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 fsio:0 directory:10 lock:0',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    DefaultChdir => '~',

    Directory => {
      "~$user/*" => {
        Limit => {
          'CWD XCWD RNFR RNTO' => {
            AllowAll => '',
          },

          'ALL' => {
            DenyAll => '',
          },
        },
      },

      "~$user/upload" => {
        Limit => {
          'RNFR' => {
            DenyAll => '',
          },
        },
      },
    },

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

      eval { $client->rnfr('upload') };
      unless ($@) {
        die("RNFR upload succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "upload: Operation not permitted";
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

  unlink($log_file);
}

sub limits_one_char_dir_bug3337 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/dir.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/dir.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/dir.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/dir.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/dir.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $a_dir = File::Spec->rel2abs("$home_dir/a");
  mkpath($a_dir);

  my $ab_dir = File::Spec->rel2abs("$home_dir/ab");
  mkpath($ab_dir);

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $a_dir, $ab_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $a_dir, $ab_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }
 
  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  # Reported in
  #
  #  http://forums.proftpd.org/smf/index.php/topic,4170.0.html

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 fsio:0 directory:10 lock:0',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    DefaultChdir => '~',

    Directory => {
      "$home_dir" => {
        Limit => {
          WRITE => {
            DenyUser => $user,
          },
        },
      },

      "$a_dir" => {
        Limit => {
          WRITE => {
            AllowUser => $user,
          },
        },
      },

      "$ab_dir" => {
        Limit => {
          WRITE => {
            AllowUser => $user,
          },
        },
      },
    },

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

      $client->cwd('ab');
      my $conn = $client->stor_raw('test.txt');
      unless ($conn) {
        die("STOR test.txt failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      $conn->close();

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Transfer complete";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $client->cwd('../a');
      $conn = $client->stor_raw('test.txt');
      unless ($conn) {
        die("STOR test.txt failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      $conn->close();

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Transfer complete";
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

  unlink($log_file);
}

sub limits_symlink_dir_bug3166 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/dir.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/dir.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/dir.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/dir.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/dir.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $src_dir = File::Spec->rel2abs("$tmpdir/dispatch/$user");
  mkpath($src_dir);

  my $dst_dir = File::Spec->rel2abs("$tmpdir/writable/dir1");
  mkpath($dst_dir);

  # Change to the $src_dir in order to create a symlink with a relative
  # path (so that it will work in the chroot).

  my $cwd = getcwd();
  unless (chdir($src_dir)) {
    die("Can't chdir to $src_dir: $!");
  }

  unless (symlink("../../writable/dir1", "dir1")) {
    die("Can't symlink '../../writable/dir1' to 'dir1': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $src_dir, $dst_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $src_dir, $dst_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }
 
  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 fsio:0 directory:10 lock:0',

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

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOD;
<Directory $src_dir>
  <Limit ALL>
    Order allow, deny
    AllowUser $user
    DenyAll
  </Limit>
</Directory>

<Directory $home_dir/writable>
  <Limit ALL>
    Order allow, deny
    AllowUser admin
    DenyAll
  </Limit>

  <Limit DIRS PORT PASV EPRT EPSV>
    Order allow, deny
    AllowUser admin
    AllowUser test
    DenyAll
  </Limit>
</Directory>

<Directory $dst_dir>

  # Bug#3166 was caused by using just ALL in this limit; the parent
  # directory's limit included the DIRS command group, which took precedence
  # over ALL.  By adding DIRS to the limit (which includes the test user),
  # the desired behavior is achieved.

  <Limit ALL DIRS>
    Order allow, deny
    AllowUser admin
    AllowUser $user
    DenyAll
  </Limit>
</Directory>
EOD
    close($fh);

  } else {
    die("Can't read $config_file: $!");
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

      $client->cwd('dispatch');
      $client->nlst();

      $client->cwd($user);
      $client->nlst();

      $client->cwd('dir1');

      my ($resp_code, $resp_msg) = $client->pwd();

      my $expected;

      $expected = 257;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = '"/writable/dir1" is the current directory';
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

  unlink($log_file);
}

sub limits_anon_dir_abs_path_bug3283 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/dir.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/dir.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/dir.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/dir.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/dir.group");

  my ($user, $group) = config_get_identity();

  my $passwd = 'test';
  my $anon_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $hide_dir = File::Spec->rel2abs("$tmpdir/hide");
  mkpath($hide_dir);

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $anon_dir, $hide_dir)) {
      die("Can't set perms on $anon_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $anon_dir, $hide_dir)) {
      die("Can't set owner of $anon_dir to $uid/$gid: $!");
    }
  }
 
  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, '/tmp',
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 fsio:0 directory:10 lock:0',

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
    print $fh <<EOD;
<Anonymous $anon_dir>
  User $user
  Group $group
  UserAlias anonymous $user
  RequireValidShell off

  <Directory $hide_dir>
    <Limit ALL>
      DenyAll
    </Limit>
  </Directory>
</Anonymous>
EOD
    close($fh);

  } else {
    die("Can't read $config_file: $!");
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

      my $conn = $client->list_raw();
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 32768, 30);
      $conn->close();

      my $lines = [split(/\n/, $buf)];

      foreach my $line (@$lines) {
        if ($line =~ /\s+(\S+)$/) {
          my $dir_name = $1;

          # The <Directory> with <Limit ALL>DenyAll should not appear in
          # the returned list

          my $unexpected = 'hide';
          $self->assert($unexpected ne $dir_name,
            test_msg("Unexpectedly saw '$dir_name' in LIST"));
        }
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

  unlink($log_file);
}

sub limits_with_multi_globs_denied_delete {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  # This config is from:
  #
  #  http://forums.proftpd.org/smf/index.php/topic,6807.0.html

  my $config_file = "$tmpdir/dir.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/dir.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/dir.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/dir.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/dir.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $users_dir = File::Spec->rel2abs("$tmpdir/home/users");
  my $home_dir = File::Spec->rel2abs("$users_dir/$user");
  my $uid = 500;
  my $gid = 500;

  mkpath($home_dir);

  my $test_file = File::Spec->rel2abs("$home_dir/hiddenfile_foo.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
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
 
  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $abs_tmp_dir = File::Spec->rel2abs($tmpdir);

  my $glob_expr = "$users_dir/*/hiddenfile_*";
  if ($^O eq 'darwin') {
    # MacOSX-specific hack/tweak
    $glob_expr = '/private' . $glob_expr;
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 fsio:0 directory:10 lock:0',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    DefaultChdir => '~',

    Directory => {
      $glob_expr => {
        Limit => {
          'ALL' => {
            DenyAll => '',
          },
        },
      },
    },

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

      my $filename = 'hiddenfile_foo.txt';
      eval { $client->dele($filename) };
      unless ($@) {
        die("DELE succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "$filename: Operation not permitted";
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

  unlink($log_file);
}

sub limits_retr_bug3915 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/dir.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/dir.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/dir.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/dir.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/dir.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs("$tmpdir/home/users/$user");
  my $uid = 500;
  my $gid = 500;

  mkpath($home_dir);

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

  my $test_file = File::Spec->rel2abs("$home_dir/test.txt");
  if (open(my $fh, "> $test_file")) {
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
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 fsio:0 directory:10 lock:0',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    DefaultChdir => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Directory ~$user>
  <Limit RETR>
    DenyAll
  </Limit>
</Directory>
EOC
    close($fh);

  } else {
    die("Can't read $config_file: $!");
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

      my $conn = $client->retr_raw('test.txt');
      if ($conn) {
        die("RETR test.txt succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "test.txt: Operation not permitted";
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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub limits_retr_bug3915_chrooted {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/dir.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/dir.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/dir.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/dir.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/dir.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs("$tmpdir/home/users/$user");
  my $uid = 500;
  my $gid = 500;

  mkpath($home_dir);

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

  my $test_file = File::Spec->rel2abs("$home_dir/test.txt");
  if (open(my $fh, "> $test_file")) {
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
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 fsio:0 directory:10 lock:0',

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

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Directory ~$user>
  <Limit RETR>
    DenyAll
  </Limit>
</Directory>
EOC
    close($fh);

  } else {
    die("Can't read $config_file: $!");
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

      my $conn = $client->retr_raw('test.txt');
      if ($conn) {
        die("RETR test.txt succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "test.txt: Operation not permitted";
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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub limits_stor_with_multiple_groups_chrooted {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/dir.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/dir.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/dir.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/dir.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/dir.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $read_group = 'ftpd_read';
  my $read_gid = 501;
  my $write_group = 'ftpd_write';
  my $write_gid = 502;

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d");
  mkpath($test_dir);

  my $sub_dir = File::Spec->rel2abs("$test_dir/sub.d");
  mkpath($sub_dir);

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }

    unless(chmod(0775, $test_dir, $sub_dir)) {
      die("Can't set perms on $test_dir to 0775: $!");
    }

    unless (chown($uid, $write_gid, $test_dir, $sub_dir)) {
      die("Can't set owner of $test_dir to $uid/$write_gid: $!");
    }

  }
 
  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);
  auth_group_write($auth_group_file, $read_group, $read_gid, $user);
  auth_group_write($auth_group_file, $write_group, $write_gid, $user);

  # See:
  #  https://forums.proftpd.org/smf/index.php/topic,11304.0.html

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 fileperms:10 fsio:0 directory:10 lock:0',

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

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOD;
<Directory $test_dir>
  <Limit DIRS READ>
    AllowGroup OR $read_group,$write_group
  </Limit>

  <Limit ALL>
    DenyAll
  </Limit>
</Directory>

<Directory $sub_dir>
  <Limit DIRS READ>
    AllowGroup OR $read_group,$write_group
  </Limit>

  <Limit ALL>
    AllowGroup $write_group
    DenyAll
  </Limit>
</Directory>
EOD
    close($fh);

  } else {
    die("Can't read $config_file: $!");
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
      $client->cwd('test.d/sub.d');

      my $conn = $client->stor_raw('test.txt');
      unless ($conn) {
        die("Failed to STOR test.txt: " . $client->response_code() . " " .
          $client->response_msg());
      };

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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

1;
