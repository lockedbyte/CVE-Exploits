package ProFTPD::Tests::Config::Directory::Umask;

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
  umask_root_dir_bug2677 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  umask_server_config_bug2677 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  umask_glob_subdirs => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  umask_glob_dir_bug3491 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  umask_no_glob_dir_bug3491 => {
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

sub umask_root_dir_bug2677 {
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

  my $sub_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($sub_dir);

  my $test_dir = File::Spec->rel2abs("$tmpdir/foo/testdir");
  my $test_file = File::Spec->rel2abs("$tmpdir/foo/test.txt");
 
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
    Trace => 'directory:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    DefaultChdir => '~',

    Directory => {
      '/' => {
        Umask => '066 077',
        Limit => {
          'MKD STOR' => {
            DenyAll => '',
          },
        },
      },

      "~" => {
        Umask => '000 000',
        Limit => {
          'CWD MKD STOR' => {
            AllowUser => $user,
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
      ($resp_code, $resp_msg) = $client->mkd("foo/testdir");

      my $expected;

      $expected = 257;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "\"$test_dir\" - Directory successfully created";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      my $mode = sprintf("%04o", (stat($test_dir))[2] & 07777);
      $expected = '0777';
      $self->assert($expected == $mode,
        test_msg("Expected '$expected', got '$mode'"));

      my $conn = $client->stor_raw("foo/test.txt");
      unless ($conn) {
        die("Failed to STOR foo/test.txt: " . $client->response_code() .
          " " . $client->response_msg());
      }

      my $buf = "Foo!\n";
      $conn->write($buf, length($buf));
      $conn->close();

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected '$expected', got '$resp_code'"));

      $expected = "Transfer complete";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $mode = sprintf("%04o", (stat($test_file))[2] & 07777);
      $expected = '0666';
      $self->assert($expected == $mode,
        test_msg("Expected '$expected', got '$mode'"));
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

sub umask_server_config_bug2677 {
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

  my $sub_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($sub_dir);

  my $test_dir = File::Spec->rel2abs("$tmpdir/foo/testdir");
  my $test_file = File::Spec->rel2abs("$tmpdir/foo/test.txt");
 
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
    Trace => 'directory:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    DefaultChdir => '~',
    Umask => '066 077',

    Directory => {
      '/' => {
        Limit => {
          'MKD STOR' => {
            DenyAll => '',
          },
        },
      },

      '~' => {
        Umask => '000 000',
        Limit => {
          'CWD MKD STOR' => {
            AllowUser => $user,
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
      ($resp_code, $resp_msg) = $client->mkd("foo/testdir");

      my $expected;

      $expected = 257;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "\"$test_dir\" - Directory successfully created";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      my $mode = sprintf("%04o", (stat($test_dir))[2] & 07777);
      $expected = '0777';
      $self->assert($expected == $mode,
        test_msg("Expected '$expected', got '$mode'"));

      my $conn = $client->stor_raw("foo/test.txt");
      unless ($conn) {
        die("Failed to STOR foo/test.txt: " . $client->response_code() .
          " " . $client->response_msg());
      }

      my $buf = "Foo!\n";
      $conn->write($buf, length($buf));
      $conn->close();

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected '$expected', got '$resp_code'"));

      $expected = "Transfer complete";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $mode = sprintf("%04o", (stat($test_file))[2] & 07777);
      $expected = '0666';
      $self->assert($expected == $mode,
        test_msg("Expected '$expected', got '$mode'"));
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

sub umask_glob_subdirs {
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

  my $sub_dir1 = File::Spec->rel2abs("$tmpdir/subdir/foo");
  mkpath($sub_dir1);
  my $test_dir1 = File::Spec->rel2abs("$tmpdir/subdir/foo/testdir");
  my $test_file1 = File::Spec->rel2abs("$tmpdir/subdir/foo/test.txt");
 
  my $sub_dir2 = File::Spec->rel2abs("$tmpdir/otherdir/foo");
  mkpath($sub_dir2);
  my $test_dir2 = File::Spec->rel2abs("$tmpdir/otherdir/foo/testdir");
  my $test_file2 = File::Spec->rel2abs("$tmpdir/otherdir/foo/test.txt");

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir1, $sub_dir2)) {
      die("Can't set perms on $home_dir, $sub_dir1, $sub_dir2 to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir1, $sub_dir2)) {
      die("Can't set owner of $home_dir, $sub_dir1, $sub_dir2 to $uid/$gid: $!");
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
    Trace => 'directory:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    DefaultChdir => '~',

    Directory => {
      '~/*/foo' => {
        Umask => '066 077',
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

      my $expected;
      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->mkd("subdir/foo/testdir");

      $expected = 257;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "\"$test_dir1\" - Directory successfully created";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      my $mode = sprintf("%04o", (stat($test_dir1))[2] & 07777);
      $expected = '0700';
      $self->assert($expected == $mode,
        test_msg("Expected '$expected', got '$mode'"));

      my $conn = $client->stor_raw("subdir/foo/test.txt");
      unless ($conn) {
        die("Failed to STOR subdir/foo/test.txt: " . $client->response_code() .
          " " . $client->response_msg());
      }

      my $buf = "Foo!\n";
      $conn->write($buf, length($buf));
      $conn->close();

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected '$expected', got '$resp_code'"));

      $expected = "Transfer complete";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $mode = sprintf("%04o", (stat($test_file1))[2] & 07777);
      $expected = '0600';
      $self->assert($expected == $mode,
        test_msg("Expected '$expected', got '$mode'"));

      ($resp_code, $resp_msg) = $client->mkd("otherdir/foo/testdir");

      $expected = 257;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "\"$test_dir2\" - Directory successfully created";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $mode = sprintf("%04o", (stat($test_dir2))[2] & 07777);
      $expected = '0700';
      $self->assert($expected == $mode,
        test_msg("Expected '$expected', got '$mode'"));

      $conn = $client->stor_raw("otherdir/foo/test.txt");
      unless ($conn) {
        die("Failed to STOR otherdir/foo/test.txt: " .
          $client->response_code() .  " " . $client->response_msg());
      }

      $buf = "Foo!\n";
      $conn->write($buf, length($buf));
      $conn->close();

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected '$expected', got '$resp_code'"));

      $expected = "Transfer complete";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $mode = sprintf("%04o", (stat($test_file2))[2] & 07777);
      $expected = '0600';
      $self->assert($expected == $mode,
        test_msg("Expected '$expected', got '$mode'"));
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

sub umask_glob_dir_bug3491 {
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

  my $sub_dir1 = File::Spec->rel2abs("$tmpdir/subdir");
  mkpath($sub_dir1);
  my $test_dir1 = File::Spec->rel2abs("$tmpdir/subdir/foo");
 
  my $sub_dir2 = File::Spec->rel2abs("$tmpdir/otherdir/deeperdir");
  mkpath($sub_dir2);
  my $test_dir2 = File::Spec->rel2abs("$tmpdir/otherdir/deeperdir/foo");

  my $test_dir3 = File::Spec->rel2abs("$tmpdir/thirddir");

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir1, $sub_dir2)) {
      die("Can't set perms on $home_dir, $sub_dir1, $sub_dir2 to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir1, $sub_dir2)) {
      die("Can't set owner of $home_dir, $sub_dir1, $sub_dir2 to $uid/$gid: $!");
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
    Trace => 'directory:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    # Set a default umask
    Umask => '027 027',

    DefaultChdir => '~',

    Directory => {
      '~/*/foo' => {
        Umask => '066 077',
      },

      '~/subdir/foo' => {
        Umask => '066 077',
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

      my $expected;
      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->mkd("subdir/foo");

      $expected = 257;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "\"$test_dir1\" - Directory successfully created";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      my $mode = sprintf("%04o", (stat($test_dir1))[2] & 07777);
      $expected = '0700';
      $self->assert($expected == $mode,
        test_msg("Expected '$expected', got '$mode'"));

      ($resp_code, $resp_msg) = $client->mkd("otherdir/deeperdir/foo");

      $expected = 257;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "\"$test_dir2\" - Directory successfully created";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $mode = sprintf("%04o", (stat($test_dir2))[2] & 07777);
      $expected = '0700';
      $self->assert($expected == $mode,
        test_msg("Expected '$expected', got '$mode'"));

      ($resp_code, $resp_msg) = $client->mkd("thirddir");

      $expected = 257;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "\"$test_dir3\" - Directory successfully created";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $mode = sprintf("%04o", (stat($test_dir3))[2] & 07777);
      $expected = '0750';
      $self->assert($expected == $mode,
        test_msg("Expected '$expected', got '$mode'"));

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

sub umask_no_glob_dir_bug3491 {
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

  my $sub_dir1 = File::Spec->rel2abs("$tmpdir/subdir");
  mkpath($sub_dir1);
  my $test_dir1 = File::Spec->rel2abs("$tmpdir/subdir/foo");
 
  my $sub_dir2 = File::Spec->rel2abs("$tmpdir/otherdir/deeperdir");
  mkpath($sub_dir2);
  my $test_dir2 = File::Spec->rel2abs("$tmpdir/otherdir/deeperdir/foo");

  my $test_dir3 = File::Spec->rel2abs("$tmpdir/thirddir");

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir1, $sub_dir2)) {
      die("Can't set perms on $home_dir, $sub_dir1, $sub_dir2 to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir1, $sub_dir2)) {
      die("Can't set owner of $home_dir, $sub_dir1, $sub_dir2 to $uid/$gid: $!");
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
    Trace => 'directory:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    # Set a default umask
    Umask => '027 027',

    DefaultChdir => '~',

    Directory => {
      '/*' => {
        Umask => '066 077',
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

      my $expected;
      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->mkd("subdir/foo");

      $expected = 257;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "\"$test_dir1\" - Directory successfully created";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      my $mode = sprintf("%04o", (stat($test_dir1))[2] & 07777);
      $expected = '0700';
      $self->assert($expected == $mode,
        test_msg("Expected '$expected', got '$mode'"));

      ($resp_code, $resp_msg) = $client->mkd("otherdir/deeperdir/foo");

      $expected = 257;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "\"$test_dir2\" - Directory successfully created";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $mode = sprintf("%04o", (stat($test_dir2))[2] & 07777);
      $expected = '0700';
      $self->assert($expected == $mode,
        test_msg("Expected '$expected', got '$mode'"));

      ($resp_code, $resp_msg) = $client->mkd("thirddir");

      $expected = 257;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "\"$test_dir3\" - Directory successfully created";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $mode = sprintf("%04o", (stat($test_dir3))[2] & 07777);
      $expected = '0700';
      $self->assert($expected == $mode,
        test_msg("Expected '$expected', got '$mode'"));

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
