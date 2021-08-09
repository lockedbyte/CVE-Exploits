package ProFTPD::Tests::Commands::MLSD;

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

my $TESTS = {
  mlsd_ok_raw_active => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  mlsd_ok_raw_passive => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  mlsd_fails_file => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  mlsd_ok_cwd_dir => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  mlsd_ok_other_dir_bug4198 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  mlsd_ok_chrooted_dir => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  mlsd_ok_empty_dir => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  mlsd_ok_no_path => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  mlsd_ok_glob => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  mlsd_fails_login_required => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  mlsd_fails_enoent => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  mlsd_fails_eperm => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  mlsd_ok_hidden_file => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  mlsd_ok_path_with_spaces => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  mlsd_nonascii_chars_bug3032 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  mlsd_symlink_showsymlinks_off_bug3318 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  mlsd_symlink_showsymlinks_on_bug3318 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  mlsd_symlink_showsymlinks_on_chrooted_bug4219 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  mlsd_symlink_showsymlinks_on_use_slink_chrooted_bug4219 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  mlsd_symlinked_dir_bug3859 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  mlsd_symlinked_dir_showsymlinks_off_bug3859 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  mlsd_wide_dir => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  mlsd_symlink_rel_path_chrooted_bug4322 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  mlsd_symlink_rel_path_subdir_chrooted_bug4322 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  mlsd_symlink_rel_path_subdir_cwd_chrooted_bug4322 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  # XXX Plenty of other tests needed: params, maxfiles, maxdirs, depth, etc
};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub mlsd_ok_raw_active {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

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
    },
  };

  my ($port, $config_user, $config_group) = config_write($setup->{config_file},     $config);

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
      $client->type('binary');

      my $conn = $client->mlsd_raw();
      unless ($conn) {
        die("Failed to MLSD: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Response:\n$buf\n";
      }

      # We have to be careful of the fact that readdir returns directory
      # entries in an unordered fashion.
      my $res = {};
      my $lines = [split(/\r\n/, $buf)];
      $self->assert(scalar(@$lines) > 1,
        test_msg("Expected several MLSD lines, got " . scalar(@$lines)));

      foreach my $line (@$lines) {
        if ($line =~ /^modify=\S+;perm=\S+;type=\S+;unique=\S+;UNIX\.group=\d+;UNIX\.groupname=\S+;UNIX\.mode=\d+;UNIX\.owner=\d+;UNIX\.ownername=\S+; (.*?)$/) {
          $res->{$1} = 1;
        }
      }

      my $expected = {
        '.' => 1,
        '..' => 1,
        'cmds.conf' => 1,
        'cmds.group' => 1,
        'cmds.passwd' => 1,
        'cmds.pid' => 1,
        'cmds.scoreboard' => 1,
        'cmds.scoreboard.lck' => 1,
      };

      my $ok = 1;
      my $mismatch;
      foreach my $name (keys(%$res)) {
        unless (defined($expected->{$name})) {
          $mismatch = $name;
          $ok = 0;
          last;
        }
      }

      unless ($ok) {
        die("Unexpected name '$mismatch' appeared in MLSD data")
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

sub mlsd_ok_raw_passive {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/cmds.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/cmds.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/cmds.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/cmds.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/cmds.group");

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 1);
      $client->login($user, $passwd);

      my $conn = $client->mlsd_raw();
      unless ($conn) {
        die("Failed to MLSD: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      # We have to be careful of the fact that readdir returns directory
      # entries in an unordered fashion.
      my $res = {};
      my $lines = [split(/\r\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^modify=\S+;perm=\S+;type=\S+;unique=\S+;UNIX\.group=\d+;UNIX\.groupname=\S+;UNIX\.mode=\d+;UNIX\.owner=\d+;UNIX\.ownername=\S+; (.*?)$/) {
          $res->{$1} = 1;
        }
      }

      my $expected = {
        '.' => 1,
        '..' => 1,
        'cmds.conf' => 1,
        'cmds.group' => 1,
        'cmds.passwd' => 1,
        'cmds.pid' => 1,
        'cmds.scoreboard' => 1,
        'cmds.scoreboard.lck' => 1,
      };

      my $ok = 1;
      my $mismatch;
      foreach my $name (keys(%$res)) {
        unless (defined($expected->{$name})) {
          $mismatch = $name;
          $ok = 0;
          last;
        }
      }

      unless ($ok) {
        die("Unexpected name '$mismatch' appeared in MLSD data")
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
    test_append_logfile($log_file);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub mlsd_fails_file {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/cmds.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/cmds.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/cmds.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/cmds.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/cmds.group");

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

  my $test_file = File::Spec->rel2abs($config_file);

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

      my $conn = $client->mlsd_raw($test_file);
      if ($conn) {
        die("MLSD succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "'$test_file' is not a directory";
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
    test_append_logfile($log_file);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub mlsd_ok_cwd_dir {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/cmds.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/cmds.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/cmds.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/cmds.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/cmds.group");

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
      $client->type('binary');

      my $conn = $client->mlsd_raw($home_dir);
      unless ($conn) {
        die("MLSD failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $res = {};
      my $lines = [split(/\r\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^modify=\S+;perm=\S+;type=(\S+);unique=\S+;UNIX\.group=\d+;UNIX\.groupname=\S+;UNIX\.mode=\d+;UNIX\.owner=\d+;UNIX\.ownername=\S+; (.*?)$/) {
          $res->{$2} = $1;
        }
      }

      my $count = scalar(keys(%$res));
      my $expected = 8;
      unless ($count == $expected) {
        die("MLSD returned wrong number of entries (expected $expected, got $count)");
      }

      # Make sure that the 'type' fact for the current directory is
      # "cdir" (Bug#4198).
      my $type = $res->{'.'};
      $expected = 'cdir';
      $self->assert($expected eq $type,
        test_msg("Expected type '$expected', got '$type'"));
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
    test_append_logfile($log_file);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub mlsd_ok_other_dir_bug4198 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/cmds.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/cmds.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/cmds.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/cmds.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/cmds.group");

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

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d");
  my $sub_dir = File::Spec->rel2abs("$test_dir/sub.d");
  mkpath($sub_dir);

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
      $client->type('binary');

      # First, change to some other directory
      $client->cwd($sub_dir);

      my $conn = $client->mlsd_raw($test_dir);
      unless ($conn) {
        die("MLSD failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $res = {};
      my $lines = [split(/\r\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^modify=\S+;perm=\S+;type=(\S+);unique=\S+;UNIX\.group=\d+;UNIX\.groupname=\S+;UNIX\.mode=\d+;UNIX\.owner=\d+;UNIX\.ownername=\S+; (.*?)$/) {
          $res->{$2} = $1;
        }
      }

      my $count = scalar(keys(%$res));
      my $expected = 3;
      unless ($count == $expected) {
        die("MLSD returned wrong number of entries (expected $expected, got $count)");
      }

      # Make sure that the 'type' fact for the current directory is
      # "cdir" (Bug#4198).
      my $type = $res->{'.'};
      $expected = 'cdir';
      $self->assert($expected eq $type,
        test_msg("Expected type '$expected', got '$type'"));

      # Similarly, make sure that the 'type' fact for parent directory
      # (by name) is NOT "cdir", but is just "dir" (Bug#4198).
      $type = $res->{'sub.d'};
      $expected = 'dir';
      $self->assert($expected eq $type,
        test_msg("Expected type '$expected', got '$type'"));
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
    test_append_logfile($log_file);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub mlsd_ok_chrooted_dir {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    DefaultRoot => '~',

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
      $client->type('binary');

      my $conn = $client->mlsd_raw('/');
      unless ($conn) {
        die("MLSD failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Response:\n$buf\n";
      }

      my $res = {};
      my $lines = [split(/\r\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^modify=\S+;perm=\S+;type=\S+;unique=\S+;UNIX\.group=\d+;UNIX\.groupname=\S+;UNIX\.mode=\d+;UNIX\.owner=\d+;UNIX\.ownername=\S+; (.*?)$/) {
          $res->{$1} = 1;
        }
      }

      my $count = scalar(keys(%$res));
      unless ($count == 8) {
        die("MLSD returned wrong number of entries (expected 7, got $count)");
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

sub mlsd_ok_empty_dir {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/cmds.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/cmds.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/cmds.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/cmds.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/cmds.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $test_dir = File::Spec->rel2abs("$tmpdir/testdir");
  mkpath($test_dir);

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $test_dir)) {
      die("Can't set perms on $home_dir, $test_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $test_dir)) {
      die("Can't set owner of $home_dir, $test_dir to $uid/$gid: $!");
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
      $client->type('binary');

      my $conn = $client->mlsd_raw($test_dir);
      unless ($conn) {
        die("MLSD failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $res = {};
      my $lines = [split(/\r\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^modify=\S+;perm=\S+;type=(\S+);unique=\S+;UNIX\.group=\d+;UNIX\.groupname=\S+;UNIX\.mode=\d+;UNIX\.owner=\d+;UNIX\.ownername=\S+; (.*?)$/) {
          $res->{$2} = $1;
        }
      }

      my $count = scalar(keys(%$res));
      unless ($count == 2) {
        die("MLSD returned wrong number of entries (expected 2, got $count)");
      }

      # Make sure that the type reported by mod_facts for the '..' directory
      # is 'pdir', where the type for '.' is 'cdir'.

      my $type = $res->{'.'};
      my $expected = 'cdir';
      $self->assert($expected eq $type,
        test_msg("Expected type '$expected', got '$type'"));

      $type = $res->{'..'};
      $expected = 'pdir';
      $self->assert($expected eq $type,
        test_msg("Expected type '$expected', got '$type'"));
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
    test_append_logfile($log_file);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub mlsd_ok_no_path {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/cmds.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/cmds.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/cmds.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/cmds.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/cmds.group");

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
      $client->type('binary');

      my $conn = $client->mlsd_raw();
      unless ($conn) {
        die("MLSD failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $res = {};
      my $lines = [split(/\r\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^modify=\S+;perm=\S+;type=\S+;unique=\S+;UNIX\.group=\d+;UNIX\.groupname=\S+;UNIX\.mode=\d+;UNIX\.owner=\d+;UNIX\.ownername=\S+; (.*?)$/) {
          $res->{$1} = 1;
        }
      }

      my $count = scalar(keys(%$res));
      my $expected = 8;
      unless ($count == $expected) {
        die("MLSD returned wrong number of entries (expected $expected, got $count)");
      }
    };

    if ($@) {
      $ex = $@;
    }

    print $wfh "done\n";

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
    test_append_logfile($log_file);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub mlsd_ok_glob {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/cmds.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/cmds.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/cmds.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/cmds.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/cmds.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $test_dir = File::Spec->rel2abs("$tmpdir/?foo*");
  mkpath($test_dir);

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
      $client->type('binary');

      my $conn = $client->mlsd('?foo*');
      unless ($conn) {
        die("MLSD failed unexpectedly: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Transfer complete";
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
    test_append_logfile($log_file);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub mlsd_fails_login_required {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/cmds.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/cmds.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/cmds.scoreboard");

  my $log_file = test_get_logfile();

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

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

      eval { $client->mlsd() };
      unless ($@) {
        die("MLSD succeeded unexpectedly");
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
    test_append_logfile($log_file);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub mlsd_fails_enoent {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/cmds.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/cmds.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/cmds.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/cmds.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/cmds.group");

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
  auth_group_write($auth_group_file, 'ftpd', $uid, $user);

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
      $client->type('binary');
      $client->port();

      my $test_file = 'foo/bar/baz';

      eval { $client->mlsd($test_file) };
      unless ($@) {
        die("MLSD succeeded unexpectedly: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "$test_file: No such file or directory";
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
    test_append_logfile($log_file);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub mlsd_fails_eperm {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/cmds.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/cmds.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/cmds.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/cmds.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/cmds.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $sub_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($sub_dir);

  my $test_file = File::Spec->rel2abs("$tmpdir/foo/bar");
  if (open(my $fh, "> $test_file")) {
    close($fh);

  } else {
    die("Can't open $test_file: $!");
  }

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
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

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
      $client->type('binary');
      $client->port();

      chmod(0660, $sub_dir);

      eval { $client->mlsd($test_file) };
      unless ($@) {
        die("MLSD succeeded unexpectedly: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "$test_file: Permission denied";
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
    test_append_logfile($log_file);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub mlsd_ok_hidden_file {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/cmds.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/cmds.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/cmds.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/cmds.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/cmds.group");

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

  my $test_file = File::Spec->rel2abs("$tmpdir/test.foo");
  if (open(my $fh, "> $test_file")) {
    close($fh);

  } else {
    die("Can't open $test_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    Directory => {
      '/' => {
        HideFiles => '\.foo$',
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
      $client->type('binary');

      my $conn = $client->mlsd_raw($home_dir);
      unless ($conn) {
        die("MLSD failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $res = {};
      my $lines = [split(/\r\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^modify=\S+;perm=\S+;type=\S+;unique=\S+;UNIX\.group=\d+;UNIX\.groupname=\S+;UNIX\.mode=\d+;UNIX\.owner=\d+;UNIX\.ownername=\S+; (.*?)$/) {
          $res->{$1} = 1;
        }
      }

      # Bug#3190 occurred because mod_facts' handling of MLSD was not checking
      # to see if a listed file has been hidden (e.g. via HideFiles).

      my $count = scalar(keys(%$res));
      my $expected = 8;
      unless ($count == $expected) {
        die("MLSD returned wrong number of entries (expected $expected, got $count)");
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
    test_append_logfile($log_file);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub mlsd_ok_path_with_spaces {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/cmds.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/cmds.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/cmds.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/cmds.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/cmds.group");

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

  my $test_dir = File::Spec->rel2abs("$tmpdir/test foo");
  mkpath($test_dir);

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
      $client->type('binary');

      my $conn = $client->mlsd_raw('test foo');
      unless ($conn) {
        die("MLSD failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $res = {};
      my $lines = [split(/\r\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^modify=\S+;perm=\S+;type=\S+;unique=\S+;UNIX\.group=\d+;UNIX\.groupname=\S+;UNIX\.mode=\d+;UNIX\.owner=\d+;UNIX\.ownername=\S+; (.*?)$/) {
          $res->{$1} = 1;
        }
      }

      my $count = scalar(keys(%$res));
      unless ($count == 2) {
        die("MLSD returned wrong number of entries (expected 2, got $count)");
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
    test_append_logfile($log_file);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub mlsd_nonascii_chars_bug3032 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/cmds.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/cmds.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/cmds.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/cmds.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/cmds.group");

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

  my $test_dir = File::Spec->rel2abs("$tmpdir/test\b");
  mkpath($test_dir);

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
      $client->type('binary');

      my $conn = $client->mlsd_raw("test\b");
      unless ($conn) {
        die("MLSD failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $res = {};
      my $lines = [split(/\r\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^modify=\S+;perm=\S+;type=\S+;unique=\S+;UNIX\.group=\d+;UNIX\.groupname=\S+;UNIX\.mode=\d+;UNIX\.owner=\d+;UNIX\.ownername=\S+; (.*?)$/) {
          $res->{$1} = 1;
        }
      }

      my $count = scalar(keys(%$res));
      unless ($count == 2) {
        die("MLSD returned wrong number of entries (expected 2, got $count)");
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
    test_append_logfile($log_file);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub mlsd_symlink_showsymlinks_off_bug3318 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $foo_dir = File::Spec->rel2abs("$setup->{home_dir}/foo");
  mkpath($foo_dir);

  my $test_file = File::Spec->rel2abs("$foo_dir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  # Change to the 'foo' directory in order to create a relative path in the
  # symlink we need

  my $cwd = getcwd();
  unless (chdir($foo_dir)) {
    die("Can't chdir to $foo_dir: $!");
  }

  unless (symlink('./test.txt', './test.lnk')) {
    die("Can't symlink 'test.lnk' to './test.txt': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  if ($< == 0) {
    unless (chmod(0755, $foo_dir)) {
      die("Can't set perms on $foo_dir to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $foo_dir)) {
      die("Can't set owner of $foo_dir to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'fsio:20 fs.statcache:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    ShowSymlinks => 'off',

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
      $client->type('binary');

      my $conn = $client->mlsd_raw('foo');
      unless ($conn) {
        die("MLSD failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Response:\n$buf\n";
      }

      my $res = {};
      my $lines = [split(/\r\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^modify=\S+;perm=\S+;type=\S+;unique=(\S+);UNIX\.group=\d+;UNIX\.groupname=\S+;UNIX\.mode=\d+;UNIX\.owner=\d+;UNIX\.ownername=\S+; (.*?)$/) {
          $res->{$2} = $1;
        }
      }

      my $count = scalar(keys(%$res));
      unless ($count == 4) {
        die("MLSD returned wrong number of entries (expected 4, got $count)");
      }

      # test.lnk is a symlink to test.txt.  According to RFC 3659, the unique
      # fact for both of these should thus be the same, since they are the
      # same underlying object.

      my $expected = $res->{'test.txt'};
      my $got = $res->{'test.lnk'};
      $self->assert($expected eq $got,
        test_msg("Expected '$expected', got '$got'"));
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

sub mlsd_symlink_showsymlinks_on_bug3318 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $foo_dir = File::Spec->rel2abs("$setup->{home_dir}/foo");
  mkpath($foo_dir);

  my $test_file = File::Spec->rel2abs("$foo_dir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  # Change to the 'foo' directory in order to create a relative path in the
  # symlink we need

  my $cwd = getcwd();
  unless (chdir("$foo_dir")) {
    die("Can't chdir to $foo_dir: $!");
  }

  unless (symlink('test.txt', 'test.lnk')) {
    die("Can't symlink 'test.txt' to 'test.lnk': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $foo_dir)) {
      die("Can't set perms on $foo_dir to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $foo_dir)) {
      die("Can't set owner of $foo_dir to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    ShowSymlinks => 'on',

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
      $client->type('binary');

      my $conn = $client->mlsd_raw('foo');
      unless ($conn) {
        die("MLSD failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Response:\n$buf\n";
      }

      my $res = {};
      my $lines = [split(/\r\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^modify=\S+;perm=\S+;type=(\S+);unique=(\S+);UNIX\.group=\d+;UNIX\.groupname=\S+;UNIX\.mode=\d+;UNIX\.owner=\d+;UNIX\.ownername=\S+; (.*?)$/) {
          $res->{$3} = { type => $1, unique => $2 };
        }
      }

      my $count = scalar(keys(%$res));
      unless ($count == 4) {
        die("MLSD returned wrong number of entries (expected 4, got $count)");
      }

      # test.lnk is a symlink to test.txt.  According to RFC3659, the unique
      # fact for both of these should thus be the same, since they are the
      # same underlying object.

      my $expected = $res->{'test.txt'}->{unique};
      my $got = $res->{'test.lnk'}->{unique};
      $self->assert($expected eq $got,
        test_msg("Expected '$expected', got '$got'"));

      # Since ShowSymlinks is on, the type for test.lnk should indicate that
      # it's a symlink
      $expected = 'OS.unix=symlink';
      $got = $res->{'test.lnk'}->{type};
      $self->assert(qr/$expected/i, $got,
        test_msg("Expected '$expected', got '$got'"));
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

sub mlsd_symlink_showsymlinks_on_chrooted_bug4219 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $foo_dir = File::Spec->rel2abs("$setup->{home_dir}/foo");
  mkpath($foo_dir);

  my $test_file = File::Spec->rel2abs("$foo_dir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  # Change to the 'foo' directory in order to create a relative path in the
  # symlink we need

  my $cwd = getcwd();
  unless (chdir("$foo_dir")) {
    die("Can't chdir to $foo_dir: $!");
  }

  unless (symlink('test.txt', 'test.lnk')) {
    die("Can't symlink 'test.txt' to 'test.lnk': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $foo_dir)) {
      die("Can't set perms on $foo_dir to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $foo_dir)) {
      die("Can't set owner of $foo_dir to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'fsio:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    DefaultRoot => '~',
    ShowSymlinks => 'on',

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
      $client->type('binary');

      my $conn = $client->mlsd_raw('foo');
      unless ($conn) {
        die("MLSD failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Response:\n$buf\n";
      }

      my $res = {};
      my $lines = [split(/\r\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^modify=\S+;perm=\S+;type=(\S+);unique=(\S+);UNIX\.group=\d+;UNIX\.groupname=\S+;UNIX\.mode=\d+;UNIX\.owner=\d+;UNIX\.ownername=\S+; (.*?)$/) {
          $res->{$3} = { type => $1, unique => $2 };
        }
      }

      my $count = scalar(keys(%$res));
      unless ($count == 4) {
        die("MLSD returned wrong number of entries (expected 4, got $count)");
      }

      # test.lnk is a symlink to test.txt.  According to RFC3659, the unique
      # fact for both of these should thus be the same, since they are the
      # same underlying object.

      my $expected = $res->{'test.txt'}->{unique};
      my $got = $res->{'test.lnk'}->{unique};
      $self->assert($expected eq $got,
        test_msg("Expected '$expected', got '$got'"));

      # Since ShowSymlinks is on, the type for test.lnk should indicate that
      # it's a symlink
      $expected = 'OS.unix=symlink'; 
      $got = $res->{'test.lnk'}->{type};
      $self->assert(qr/$expected/i, $got,
        test_msg("Expected '$expected', got '$got'"));
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

sub mlsd_symlink_showsymlinks_on_use_slink_chrooted_bug4219 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $foo_dir = File::Spec->rel2abs("$setup->{home_dir}/foo");
  mkpath($foo_dir);

  my $test_file = File::Spec->rel2abs("$foo_dir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  # Change to the 'foo' directory in order to create a relative path in the
  # symlink we need

  my $cwd = getcwd();
  unless (chdir("$foo_dir")) {
    die("Can't chdir to $foo_dir: $!");
  }

  unless (symlink('test.txt', 'test.lnk')) {
    die("Can't symlink 'test.txt' to 'test.lnk': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $foo_dir)) {
      die("Can't set perms on $foo_dir to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $foo_dir)) {
      die("Can't set owner of $foo_dir to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'fsio:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    DefaultRoot => '~',
    FactsOptions => 'UseSlink',
    ShowSymlinks => 'on',

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
      $client->type('binary');

      my $conn = $client->mlsd_raw('foo');
      unless ($conn) {
        die("MLSD failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Response:\n$buf\n";
      }

      my $res = {};
      my $lines = [split(/\r\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^modify=\S+;perm=\S+;type=(\S+);unique=(\S+);UNIX\.group=\d+;UNIX\.groupname=\S+;UNIX\.mode=\d+;UNIX\.owner=\d+;UNIX\.ownername=\S+; (.*?)$/) {
          $res->{$3} = { type => $1, unique => $2 };
        }
      }

      my $count = scalar(keys(%$res));
      unless ($count == 4) {
        die("MLSD returned wrong number of entries (expected 4, got $count)");
      }

      # test.lnk is a symlink to test.txt.  According to RFC3659, the unique
      # fact for both of these should thus be the same, since they are the
      # same underlying object.

      my $expected = $res->{'test.txt'}->{unique};
      my $got = $res->{'test.lnk'}->{unique};
      $self->assert($expected eq $got,
        test_msg("Expected '$expected', got '$got'"));

      # Since ShowSymlinks is on, the type for test.lnk should indicate that
      # it's a symlink
      $expected = 'OS.unix=slink:/foo/test.txt';
      $got = $res->{'test.lnk'}->{type};
      $self->assert(qr/$expected/i, $got,
        test_msg("Expected '$expected', got '$got'"));
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

# See also:
#  Tests/Config/ShowSymlinks.pm::showsymlinks_on_mlsd_rel_symlinked_dir()
sub mlsd_symlinked_dir_bug3859 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/cmds.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/cmds.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/cmds.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/cmds.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/cmds.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $foo_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($foo_dir);

  my $test_dir = File::Spec->rel2abs("$tmpdir/foo/test.d");
  mkpath($test_dir);

  # Change to the 'foo' directory in order to create a relative path in the
  # symlink we need

  my $cwd = getcwd();
  unless (chdir("$foo_dir")) {
    die("Can't chdir to $foo_dir: $!");
  }

  unless (symlink('test.d', 'test.lnk')) {
    die("Can't symlink 'test.d' to 'test.lnk': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $foo_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $foo_dir)) {
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

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    # Note: use the default ShowSymlinks setting

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
      $client->type('binary');

      my $conn = $client->mlsd_raw('foo');
      unless ($conn) {
        die("MLSD failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $res = {};
      my $lines = [split(/\r\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^modify=\S+;perm=\S+;type=(\S+);unique=(\S+);UNIX\.group=\d+;UNIX\.groupname=\S+;UNIX\.mode=\d+;UNIX\.owner=\d+;UNIX\.ownername=\S+; (.*?)$/) {
          $res->{$3} = { type => $1, unique => $2 };
        }
      }

      my $count = scalar(keys(%$res));
      unless ($count == 4) {
        die("MLSD returned wrong number of entries (expected 4, got $count)");
      }

      # test.lnk is a symlink to test.d.  According to RFC3659, the unique
      # fact for both of these should thus be the same, since they are the
      # same underlying object.

      my $expected = $res->{'test.d'}->{unique};
      my $got = $res->{'test.lnk'}->{unique};
      $self->assert($expected eq $got,
        test_msg("Expected unique fact '$expected', got '$got'"));

      # Since ShowSymlinks is on by default, the type for test.lnk should
      # indicate that it's a symlink
      $expected = 'OS.unix=symlink';
      $got = $res->{'test.lnk'}->{type};
      $self->assert(qr/$expected/i, $got,
        test_msg("Expected type fact '$expected', got '$got'"));
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
    test_append_logfile($log_file);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub mlsd_symlinked_dir_showsymlinks_off_bug3859 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/cmds.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/cmds.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/cmds.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/cmds.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/cmds.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $foo_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($foo_dir);

  my $test_dir = File::Spec->rel2abs("$tmpdir/foo/test.d");
  mkpath($test_dir);

  # Change to the 'foo' directory in order to create a relative path in the
  # symlink we need

  my $cwd = getcwd();
  unless (chdir("$foo_dir")) {
    die("Can't chdir to $foo_dir: $!");
  }

  unless (symlink('test.d', 'test.lnk')) {
    die("Can't symlink 'test.d' to 'test.lnk': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $foo_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $foo_dir)) {
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

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    ShowSymlinks => 'off',

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
      $client->type('binary');

      my $conn = $client->mlsd_raw('foo');
      unless ($conn) {
        die("MLSD failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $res = {};
      my $lines = [split(/\r\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^modify=\S+;perm=\S+;type=(\S+);unique=(\S+);UNIX\.group=\d+;UNIX\.groupname=\S+;UNIX\.mode=\d+;UNIX\.owner=\d+;UNIX\.ownername=\S+; (.*?)$/) {
          $res->{$3} = { type => $1, unique => $2 };
        }
      }

      my $count = scalar(keys(%$res));
      unless ($count == 4) {
        die("MLSD returned wrong number of entries (expected 4, got $count)");
      }

      # test.lnk is a symlink to test.d.  According to RFC3659, the unique
      # fact for both of these should thus be the same, since they are the
      # same underlying object.

      my $expected = $res->{'test.d'}->{unique};
      my $got = $res->{'test.lnk'}->{unique};
      $self->assert($expected eq $got,
        test_msg("Expected unique fact '$expected', got '$got'"));

      # For ShowSymlinks off, the type for test.lnk should indicate that it's
      # a directory
      $expected = 'dir';
      $got = $res->{'test.lnk'}->{type};
      $self->assert(qr/$expected/i, $got,
        test_msg("Expected type fact '$expected', got '$got'"));
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
    test_append_logfile($log_file);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub mlsd_wide_dir {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d");
  mkpath($test_dir);

  my $expected = {
    '.' => 1,
    '..' => 1,
  };

  my $max_nfiles = 500;
  for (my $i = 0; $i < $max_nfiles; $i++) {
    my $test_filename = 'SomeReallyLongAndObnoxiousTestFileNameTemplate' . $i;

    # The expected hash is used later for verifying the results of the READDIR
    $expected->{$test_filename} = 1;

    my $test_path = File::Spec->rel2abs("$test_dir/$test_filename");

    if (open(my $fh, "> $test_path")) {
      close($fh);

    } else {
      die("Can't open $test_path: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'pool:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 1);
      $client->login($setup->{user}, $setup->{passwd});

      for (my $i = 0; $i < 10; $i++) {
        my $conn = $client->mlsd_raw($test_dir);
        unless ($conn) {
          die("Failed to MLSD: " . $client->response_code() . " " .
            $client->response_msg());
        }

        my $buf;
        my $tmp;
        while ($conn->read($tmp, 16382, 25)) {
          $buf .= $tmp;
          $tmp = '';
        }
        eval { $conn->close() };

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "buf:\n$buf\n";
        }

        # We have to be careful of the fact that readdir returns directory
        # entries in an unordered fashion.
        my $res = {};
        my $lines = [split(/\r\n/, $buf)];
        foreach my $line (@$lines) {
          if ($line =~ /^modify=\S+;perm=\S+;type=\S+;unique=\S+;UNIX\.group=\d+;UNIX\.groupname=\S+;UNIX\.mode=\d+;UNIX\.owner=\d+;UNIX\.ownername=\S+; (.*?)$/) {
            $res->{$1} = 1;
          }
        }

        my $ok = 1;
        my $mismatch;
        foreach my $name (keys(%$res)) {
          unless (defined($expected->{$name})) {
            $mismatch = $name;
            $ok = 0;
            last;
          }
        }

        unless ($ok) {
          die("Unexpected name '$mismatch' appeared in MLSD data")
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

sub mlsd_symlink_rel_path_chrooted_bug4322 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $dst_path = 'domains/test.oxilion.nl/public_html';
  my $dst_dir = File::Spec->rel2abs("$tmpdir/$dst_path");
  mkpath($dst_dir);

  my $cwd = getcwd();
  unless (chdir("$tmpdir")) {
    die("Can't chdir to $tmpdir: $!");
  }

  unless (symlink("./$dst_path", 'public_html')) {
    die("Can't symlink 'public_html' to './$dst_path': $!");
  }

  unless (symlink("$dst_path", 'public_html2')) {
    die("Can't symlink 'public_html2' to '$dst_path': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  if ($< == 0) {
    unless (chmod(0755, $dst_dir)) {
      die("Can't set perms on $dst_dir to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $dst_dir)) {
      die("Can't set owner of $dst_dir to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    ShowSymlinks => 'on',
    DefaultRoot => '~',

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($setup->{user}, $setup->{passwd});

      my $conn = $client->mlsd_raw();
      unless ($conn) {
        die("MLSD failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };
      $client->quit();

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# MLSD:\n$buf\n";
      }

      my $res = {};
      my $lines = [split(/(\r)?\n/, $buf)];

      foreach my $line (@$lines) {
        if ($line =~ /^modify=\S+;perm=\S+;type=(\S+);unique=(\S+);UNIX\.group=\d+;UNIX\.groupname=\S+;UNIX\.mode=\d+;UNIX\.owner=\d+;UNIX\.ownername=\S+; (.*?)$/) {
          $res->{$3} = { type => $1, unique => $2 };
        }
      }

      my $count = scalar(keys(%$res));
      my $expected = 11;
      unless ($count == $expected) {
        die("MLSD returned wrong number of entries (expected $expected, got $count)");
      }

      # public_html and public_html2 are symlinks to
      # domains/test.oxilion.nl/public_html.  According to RFC3659, the unique
      # fact for both of these should thus be the same, since they are the same
      # underlying object.

      $expected = 'OS.unix=symlink';
      my $got = $res->{'public_html'}->{type};
      $self->assert(qr/$expected/i, $got,
        "Expected type fact '$expected', got '$got'");

      $got = $res->{'public_html2'}->{type};
      $self->assert(qr/$expected/i, $got,
        "Expected type fact '$expected', got '$got'");
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

sub mlsd_symlink_rel_path_subdir_chrooted_bug4322 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $dst_path = 'domains/test.oxilion.nl/public_html';
  my $dst_dir = File::Spec->rel2abs("$tmpdir/test.d/$dst_path");
  mkpath($dst_dir);

  my $cwd = getcwd();
  unless (chdir("$tmpdir/test.d")) {
    die("Can't chdir to $tmpdir/test.d: $!");
  }

  unless (symlink("./$dst_path", 'public_html')) {
    die("Can't symlink 'public_html' to './$dst_path': $!");
  }

  unless (symlink("$dst_path", 'public_html2')) {
    die("Can't symlink 'public_html2' to '$dst_path': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  if ($< == 0) {
    unless (chmod(0755, $dst_dir)) {
      die("Can't set perms on $dst_dir to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $dst_dir)) {
      die("Can't set owner of $dst_dir to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    ShowSymlinks => 'on',
    DefaultRoot => '~',

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($setup->{user}, $setup->{passwd});

      my $conn = $client->mlsd_raw('test.d');
      unless ($conn) {
        die("MLSD test.d failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };
      $client->quit();

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# MLSD:\n$buf\n";
      }

      my $res = {};
      my $lines = [split(/(\r)?\n/, $buf)];

      foreach my $line (@$lines) {
        if ($line =~ /^modify=\S+;perm=\S+;type=(\S+);unique=(\S+);UNIX\.group=\d+;UNIX\.groupname=\S+;UNIX\.mode=\d+;UNIX\.owner=\d+;UNIX\.ownername=\S+; (.*?)$/) {
          $res->{$3} = { type => $1, unique => $2 };
        }
      }

      my $count = scalar(keys(%$res));
      my $expected = 5;
      unless ($count == $expected) {
        die("MLSD returned wrong number of entries (expected $expected, got $count)");
      }

      # public_html and public_html2 are symlinks to
      # domains/test.oxilion.nl/public_html.  According to RFC3659, the unique
      # fact for both of these should thus be the same, since they are the same
      # underlying object.

      $expected = 'OS.unix=symlink';
      my $got = $res->{'public_html'}->{type};
      $self->assert(qr/$expected/i, $got,
        "Expected type fact '$expected', got '$got'");

      $got = $res->{'public_html2'}->{type};
      $self->assert(qr/$expected/i, $got,
        "Expected type fact '$expected', got '$got'");
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

sub mlsd_symlink_rel_path_subdir_cwd_chrooted_bug4322 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $dst_path = 'domains/test.oxilion.nl/public_html';
  my $dst_dir = File::Spec->rel2abs("$tmpdir/test.d/$dst_path");
  mkpath($dst_dir);

  my $cwd = getcwd();
  unless (chdir("$tmpdir/test.d")) {
    die("Can't chdir to $tmpdir/test.d: $!");
  }

  unless (symlink("./$dst_path", 'public_html')) {
    die("Can't symlink 'public_html' to './$dst_path': $!");
  }

  unless (symlink("$dst_path", 'public_html2')) {
    die("Can't symlink 'public_html2' to '$dst_path': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  if ($< == 0) {
    unless (chmod(0755, $dst_dir)) {
      die("Can't set perms on $dst_dir to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $dst_dir)) {
      die("Can't set owner of $dst_dir to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    ShowSymlinks => 'on',
    DefaultRoot => '~',

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($setup->{user}, $setup->{passwd});
      $client->cwd('test.d');

      my $conn = $client->mlsd_raw();
      unless ($conn) {
        die("MLSD failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };
      $client->quit();

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# MLSD:\n$buf\n";
      }

      my $res = {};
      my $lines = [split(/(\r)?\n/, $buf)];

      foreach my $line (@$lines) {
        if ($line =~ /^modify=\S+;perm=\S+;type=(\S+);unique=(\S+);UNIX\.group=\d+;UNIX\.groupname=\S+;UNIX\.mode=\d+;UNIX\.owner=\d+;UNIX\.ownername=\S+; (.*?)$/) {
          $res->{$3} = { type => $1, unique => $2 };
        }
      }

      my $count = scalar(keys(%$res));
      my $expected = 5;
      unless ($count == $expected) {
        die("MLSD returned wrong number of entries (expected $expected, got $count)");
      }

      # public_html and public_html2 are symlinks to
      # domains/test.oxilion.nl/public_html.  According to RFC3659, the unique
      # fact for both of these should thus be the same, since they are the same
      # underlying object.

      $expected = 'OS.unix=symlink';
      my $got = $res->{'public_html'}->{type};
      $self->assert(qr/$expected/i, $got,
        "Expected type fact '$expected', got '$got'");

      $got = $res->{'public_html2'}->{type};
      $self->assert(qr/$expected/i, $got,
        "Expected type fact '$expected', got '$got'");
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
