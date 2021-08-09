package ProFTPD::Tests::Commands::LIST;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use Cwd;
use File::Path qw(mkpath);
use File::Spec;
use IO::Handle;
use Time::HiRes qw(gettimeofday tv_interval);

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :features :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  list_ok_raw_active => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  list_ok_raw_passive => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  list_ok_file => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  list_file_rel_paths_bug4259 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  list_file_after_upload => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  list_ok_dir => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  list_dir_twice => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  list_ok_no_path => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  list_ok_glob => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  list_fails_login_required => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  list_fails_enoent => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  list_fails_enoent_glob => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  list_fails_eperm => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  list_bug2821 => {
    order => ++$order,
    test_class => [qw(bug forking slow)],
  },

  list_unsorted_buffering_bug4060 => {
    order => ++$order,
    test_class => [qw(bug forking slow)],
  },

  list_opt_C => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  list_nonascii_chars_bug3032 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  list_leading_whitespace_bug3268 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  list_leading_whitespace_with_opts_bug3268 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  list_leading_whitespace_with_strict_opts_bug3268 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  list_symlink_bug3254 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  list_symlink_issue697 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  list_symlink_rel_with_double_slash_bug3719 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  list_showsymlinks_off => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  list_showsymlinks_off_chrooted_bug4219 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  list_showsymlinks_on => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  list_showsymlinks_on_chrooted_bug4219 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  list_glob_bug2367 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  list_glob_legit_dir_name => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  list_glob_legit_dir_name_bug3407 => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  list_opt_c => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  list_opt_u => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  list_dash_filename_bug3476 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  list_opt_noerrorifabsent_bug3506 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  list_slashstar_bug3529 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  list_star_bug3529 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  list_opt_R => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  list_opt_R_self_symlinked_dir_bug3719 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  list_opt_R_self_complex_symlinked_dir_bug3719 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  list_opt_R_rel_symlinked_file_bug3719 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  list_option_parsing => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  list_symlink_rel_path_chrooted_bug4322 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  list_symlink_rel_path_subdir_chrooted_bug4322 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  list_symlink_rel_path_subdir_cwd_chrooted_bug4322 => {
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

sub list_ok_raw_active {
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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 1, 1);
      $client->login($setup->{user}, $setup->{passwd});

      my $conn = $client->list_raw();
      unless ($conn) {
        die("Failed to LIST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $client->quit();

      $self->assert_transfer_ok($resp_code, $resp_msg);

      # We have to be careful of the fact that readdir returns directory
      # entries in an unordered fashion.
      my $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          $res->{$1} = 1;
        }
      }

      my $expected = {
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
        die("Unexpected name '$mismatch' appeared in LIST data")
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

sub list_ok_raw_passive {
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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 1, 1);
      $client->login($setup->{user}, $setup->{passwd});

      my $conn = $client->list_raw();
      unless ($conn) {
        die("Failed to LIST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $client->quit();

      $self->assert_transfer_ok($resp_code, $resp_msg);

      # We have to be careful of the fact that readdir returns directory
      # entries in an unordered fashion.
      my $res = {};
      my $lines = [split(/(\r)?\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          $res->{$1} = 1;
        }
      }

      my $expected = {
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
        die("Unexpected name '$mismatch' appeared in LIST data")
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

sub list_ok_file {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $test_file = File::Spec->rel2abs($setup->{config_file});

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

      my $conn = $client->list_raw($test_file);
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $client->quit();

      $self->assert_transfer_ok($resp_code, $resp_msg);

      my $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          $res->{$1} = 1;
        }
      }

      my $count = scalar(keys(%$res));
      unless ($count == 1) {
        die("LIST returned wrong number of entries (expected 1, got $count)");
      }

      unless (defined($res->{$test_file})) {
        die("LIST failed to return $test_file");
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

# See: https://forums.proftpd.org/smf/index.php/topic,12000.0.html
sub list_file_rel_paths_bug4259 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $test_file = File::Spec->rel2abs("$tmpdir/test.dat");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
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

      my $rel_path = 'test.dat';
      my $conn = $client->list_raw($rel_path);
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# response: $buf\n";
      }

      my $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          $res->{$1} = 1;
        }
      }

      my $count = scalar(keys(%$res));
      unless ($count == 1) {
        die("LIST returned wrong number of entries (expected 1, got $count)");
      }

      unless (defined($res->{$rel_path})) {
        die("LIST failed to return $rel_path");
      }

      # Now list using a different relative path syntax
      $rel_path = './test.dat';
      $conn = $client->list_raw($rel_path);
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      $buf = '';
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# response: $buf\n";
      }

      $res = {};
      $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          $res->{$1} = 1;
        }
      }

      $count = scalar(keys(%$res));
      unless ($count == 1) {
        die("LIST returned wrong number of entries (expected 1, got $count)");
      }

      unless (defined($res->{$rel_path})) {
        die("LIST failed to return $rel_path");
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

sub list_file_after_upload {
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

  my $test_file = File::Spec->rel2abs("$tmpdir/test.dat");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'fsio:10 fs.statcache:20',

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

      if ($ENV{TEST_VERBOSE}) {
        print STDOUT "# Logged in, sending STOR\n";
      }
 
      my $conn = $client->stor_raw('test.dat');
      unless ($conn) {
        die("STOR test.dat failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      if ($ENV{TEST_VERBOSE}) {
        print STDOUT "# Data connection opened, writing data\n";
      }
 
      my $start = [gettimeofday()];
      my $buf = "ABCD" x 10240;
      $conn->write($buf, length($buf), 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      my $elapsed = tv_interval($start);
      if ($ENV{TEST_VERBOSE}) {
        print STDOUT "# elapsed upload duration: $elapsed\n";
      }

      if ($ENV{TEST_VERBOSE}) {
        print STDOUT "# File uploaded, sending LIST\n";
      }
 
      $conn = $client->list_raw($test_file);
      unless ($conn) {
        die("LIST $test_file failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      $buf = '';
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();

      my $res = {};
      my $lines = [split(/\r?\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          my $path = $1;
          $res->{$path} = 1;
        }
      }

      my $count = scalar(keys(%$res));
      unless ($count == 1) {
        die("LIST returned wrong number of entries (expected 1, got $count)");
      }

      unless (defined($res->{$test_file})) {
        die("LIST failed to return $test_file");
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

sub list_ok_dir {
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

      my $conn = $client->list_raw($home_dir);
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          $res->{$1} = 1;
        }
      }

      my $count = scalar(keys(%$res));
      my $expected = 6;
      unless ($count == $expected) {
        if ($ENV{TEST_VERBOSE}) {
          print STDERR "Received:\n$buf\n";
        }

        die("LIST returned wrong number of entries (expected $expected, got $count)");
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

sub list_dir_twice {
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

      my $conn = $client->list_raw($home_dir);
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $res = {};
      my $lines = [split(/\r?\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          $res->{$1} = 1;
        }
      }

      my $count = scalar(keys(%$res));
      my $expected = 6;
      unless ($count == $expected) {
        if ($ENV{TEST_VERBOSE}) {
          print STDERR "Received:\n$buf\n";
        }

        die("LIST returned wrong number of entries (expected $expected, got $count)");
      }

      $conn = $client->list_raw($home_dir);
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      $buf = '';
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $res2 = {};
      $lines = [split(/\r?\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          $res2->{$1} = 1;
        }
      }

      my $count2 = scalar(keys(%$res2));
      unless ($count2 == $count) {
        if ($ENV{TEST_VERBOSE}) {
          print STDERR "Received:\n$buf\n";
        }

        die("Second LIST returned wrong number of entries (expected $count, got $count2)");
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

sub list_ok_no_path {
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

      my $conn = $client->list_raw();
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          $res->{$1} = 1;
        }
      }

      my $count = scalar(keys(%$res));
      my $expected = 6;
      unless ($count == $expected) {
        die("LIST returned wrong number of entries (expected $expected, got $count)");
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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub list_ok_glob {
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

      my $conn = $client->list_raw("*.conf");
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          $res->{$1} = 1;
        }
      }

      my $count = scalar(keys(%$res));
      unless ($count == 1) {
        die("LIST returned wrong number of entries (expected 1, got $count)");
      }

      my $test_file = 'cmds.conf';
      unless (defined($res->{$test_file})) {
        die("LIST failed to return $test_file");
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

sub list_fails_login_required {
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

      my ($resp_code, $resp_msg);
      eval { ($resp_code, $resp_msg) = $client->list() };
      unless ($@) {
        die("LIST succeeded unexpectedly ($resp_code $resp_msg)");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Please login with USER and PASS";
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

sub list_fails_enoent {
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

      my ($resp_code, $resp_msg);
      $client->port();

      my $test_file = 'foo/bar/baz';

      eval { ($resp_code, $resp_msg) = $client->list($test_file) };
      unless ($@) {
        die("LIST succeeded unexpectedly ($resp_code $resp_msg)");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 450;
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

  unlink($log_file);
}

sub list_fails_enoent_glob {
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
      $client->port();

      my $test_glob = '*foo';

      my ($resp_code, $resp_msg);
      ($resp_code, $resp_msg) = $client->list($test_glob);

      # Unlike NLST, for LIST proftpd returns 226, and simply sends an
      # empty list.

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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub list_fails_eperm {
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
      $client->port();

      chmod(0660, $sub_dir);

      my ($resp_code, $resp_msg);
      eval { ($resp_code, $resp_msg) = $client->list($test_file) };
      unless ($@) {
        die("LIST succeeded unexpectedly ($resp_code $resp_msg)");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 450;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "$test_file: Permission denied";
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

sub list_bug2821 {
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

  # For this test, we need to create MANY (i.e. 110K) files in the
  # home directory.
  my $test_file_prefix = File::Spec->rel2abs("$tmpdir/test_");

  my $count = 110000;
  print STDOUT "# Creating $count files in $tmpdir\n";
  for (my $i = 1; $i <= $count; $i++) {
    my $test_file = 'test_' . sprintf("%07s", $i);
    my $test_path = "$home_dir/$test_file";

    if (open(my $fh, "> $test_path")) {
      close($fh);

    } else {
      die("Can't open $test_path: $!");
    }

    if ($i % 10000 == 0) {
      print STDOUT "# Created file $test_file\n";
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $timeout = 900;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 fsio:0 lock:0',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    TimeoutIdle => $timeout + 15,
    TimeoutNoTransfer => $timeout + 15,

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

      # One of the symptoms of Bug#2821 is that a LIST (or NLST) glob
      # which matches more than 99999 files will not receive the full
      # list.
      #
      # The issue turned out to be the MAX_RESULTS (now
      # PR_TUNABLE_GLOBBING_MAX_MATCHES) limit in lib/glibc-glob.c.
      # So now, we deliberate make sure that the number of files returned
      # is less than the number of potential matches.

      my $conn = $client->list_raw("-C test_*");
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      my $tmp;
      while ($conn->read($tmp, 32768, $timeout)) {
        $buf .= $tmp;
      }
      eval { $conn->close() };
      $client->quit();

      my $res = {};

      # Preallocate memory for the expected hash size, to help speed up the
      # evaluation of the results.
      keys(%$res) = $count;

      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          $res->{$line} = 1;
        }
      }

      my $list_count = scalar(keys(%$res));
      if ($list_count >= $count) {
        die("LIST returned wrong number of entries (expected less than $count, got $list_count); check the PR_TUNABLE_GLOBBING_MAX_MATCHES value");
      }

    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout * 2) };
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

sub list_unsorted_buffering_bug4060 {
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

  # For this test, we need to create MANY (i.e. 110K) files in a subdirectory.
  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d");
  mkpath($test_dir);

  my $count = 100000;
  print STDOUT "# Creating $count files in $test_dir\n";
  for (my $i = 1; $i <= $count; $i++) {
    my $test_file = 'test_' . sprintf("%07s", $i);
    my $test_path = "$test_dir/$test_file";

    if (open(my $fh, "> $test_path")) {
      close($fh);

    } else {
      die("Can't open $test_path: $!");
    }

    if ($i % 10000 == 0) {
      print STDOUT "# Created file $test_file\n";
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $timeout = 900;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:0 data:10 fsio:0 lock:0',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    TimeoutIdle => $timeout + 15,
    TimeoutNoTransfer => $timeout + 15,

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

      my $conn = $client->list_raw('-U test.d');
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $list_start = [gettimeofday()];

      my $buf;
      my $tmp;
      while ($conn->read($tmp, 32768, $timeout)) {
        $buf .= $tmp;
      }
      eval { $conn->close() };

      my $list_elapsed = tv_interval($list_start);

      $client->quit();

      my $res = {};

      # Preallocate memory for the expected hash size, to help speed up the
      # evaluation of the results.
      keys(%$res) = $count;

      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          $res->{$line} = 1;
        }
      }

      my $list_count = scalar(keys(%$res));
      $self->assert($list_count == $count,
        test_msg("LIST returned wrong number of entries (expected $count, got $list_count)"));

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# LIST elapsed time: $list_elapsed\n";
      }
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout * 2) };
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

sub list_opt_C {
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

  # For this test, we need to create about 100 files in home directory.
  my $test_file_prefix = File::Spec->rel2abs($tmpdir);

  my $count = 100;
  print STDOUT "# Creating $count files in $tmpdir\n";
  for (my $i = 1; $i <= $count; $i++) {
    my $test_file = sprintf("%04s", $i);
    my $test_path = "$home_dir/$test_file";

    if (open(my $fh, "> $test_path")) {
      close($fh);

    } else {
      die("Can't open $test_path: $!");
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

      my $conn = $client->list_raw("-C 0*");
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 32768, 30);
      eval { $conn->close() };

      my $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)$/) {
          $res->{$1} = 1;
          $res->{$2} = 1;
          $res->{$3} = 1;
          $res->{$4} = 1;
          $res->{$5} = 1;
          $res->{$6} = 1;
          $res->{$7} = 1;
          $res->{$8} = 1;
          $res->{$9} = 1;

        } elsif ($line =~ /^(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)$/) {
          $res->{$1} = 1;
          $res->{$2} = 1;
          $res->{$3} = 1;
          $res->{$4} = 1;
          $res->{$5} = 1;
          $res->{$6} = 1;
          $res->{$7} = 1;
          $res->{$8} = 1;
        }
      }

      my $list_count = scalar(keys(%$res));
      unless ($list_count == $count) {
        die("LIST returned wrong number of entries (expected $count, got $list_count)");
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

sub list_nonascii_chars_bug3032 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  if (feature_have_feature_enabled('nls')) {
    # This test is only valid if NLS support is not enabled.
    return;
  }

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

  my $test_file = File::Spec->rel2abs("$tmpdir/" . sprintf("test\b"));
  if (open(my $fh, "> $test_file")) {
    close($fh);

  } else {
    die("Can't open $test_file: $!");
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

      my $conn = $client->list_raw("-B test*");
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 32768, 30);
      eval { $conn->close() };

      my $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          $res->{$1} = 1;
        }
      }

      my $expected = {
        'test\010' => 1,
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
        die("Unexpected name '$mismatch' appeared in LIST data")
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

sub list_leading_whitespace_bug3268 {
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

  my $test_file = File::Spec->rel2abs("$tmpdir/ test.txt");
  if (open(my $fh, "> $test_file")) {
    close($fh);

  } else {
    die("Can't open '$test_file': $!");
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

      my $conn = $client->list_raw(' test.txt');
      unless ($conn) {
        die("Failed to LIST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      # We have to be careful of the fact that readdir returns directory
      # entries in an unordered fashion.
      my $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+\d+\s+\S+\s+\d+\s+\S+ (.*?)$/) {
          $res->{$1} = 1;
        }
      }

      my $expected = {
        ' test.txt' => 1,
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
        die("Unexpected name '$mismatch' appeared in LIST data")
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

sub list_leading_whitespace_with_opts_bug3268 {
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

  my $test_file = File::Spec->rel2abs("$tmpdir/ test.txt");
  if (open(my $fh, "> $test_file")) {
    close($fh);

  } else {
    die("Can't open '$test_file': $!");
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

      my $conn = $client->list_raw('-a -b  test.txt');
      unless ($conn) {
        die("Failed to LIST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      # We have to be careful of the fact that readdir returns directory
      # entries in an unordered fashion.
      my $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+\d+\s+\S+\s+\d+\s+\S+ (.*?)$/) {
          $res->{$1} = 1;
        }
      }

      my $expected = {
        ' test.txt' => 1,
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
        die("Unexpected name '$mismatch' appeared in LIST data")
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

sub list_leading_whitespace_with_strict_opts_bug3268 {
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

  my $test_file = File::Spec->rel2abs("$tmpdir/ test.txt");
  if (open(my $fh, "> $test_file")) {
    close($fh);

  } else {
    die("Can't open '$test_file': $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    ListOptions => '"-a +R" strict',

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

      my $conn = $client->list_raw('-a  -b  test.txt');
      unless ($conn) {
        die("Failed to LIST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      # We have to be careful of the fact that readdir returns directory
      # entries in an unordered fashion.
      my $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+\d+\s+\S+\s+\d+\s+\S+ (.*?)$/) {
          $res->{$1} = 1;
        }
      }

      my $expected = {
        ' test.txt' => 1,
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
        die("Unexpected name '$mismatch' appeared in LIST data")
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

sub list_symlink_bug3254 {
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

  my $foo_dir = File::Spec->rel2abs("$tmpdir/foo");
  my $bar_dir = File::Spec->rel2abs("$tmpdir/bar");
  my $baz_dir = File::Spec->rel2abs("$tmpdir/bar/baz");
  my $quxx_dir = File::Spec->rel2abs("$tmpdir/bar/quxx");
  mkpath([$foo_dir, $bar_dir, $baz_dir, $quxx_dir]);

  # Change to the 'foo' directory in order to create a relative path in the
  # symlink we need

  my $cwd = getcwd();
  unless (chdir("$foo_dir")) {
    die("Can't chdir to $foo_dir: $!");
  }

  unless (symlink('../bar/baz', 'baz')) {
    die("Can't symlink '../bar/baz' to 'baz': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  my $ftpaccess_file = File::Spec->rel2abs("$foo_dir/.ftpaccess");
  if (open(my $fh, "> $ftpaccess_file")) {
    print $fh <<EOL;
<Limit ALL>
  AllowUser $user
  DenyAll
</Limit>
EOL
    unless (close($fh)) {
      die("Can't write $ftpaccess_file: $!");
    }

  } else {
    die("Can't open $ftpaccess_file: $!");
  }

  $ftpaccess_file = File::Spec->rel2abs("$bar_dir/.ftpaccess");
  if (open(my $fh, "> $ftpaccess_file")) {
    print $fh <<EOL;
<Limit ALL>
  AllowUser bar
  DenyAll
</Limit>
EOL
    unless (close($fh)) {
      die("Can't write $ftpaccess_file: $!");
    }

  } else {
    die("Can't open $ftpaccess_file: $!");
  }

  $ftpaccess_file = File::Spec->rel2abs("$baz_dir/.ftpaccess");
  if (open(my $fh, "> $ftpaccess_file")) {
    print $fh <<EOL;
<Limit ALL>
  AllowUser bar,$user
  DenyAll
</Limit>
EOL
    unless (close($fh)) {
      die("Can't write $ftpaccess_file: $!");
    }

  } else {
    die("Can't open $ftpaccess_file: $!");
  }

  $ftpaccess_file = File::Spec->rel2abs("$quxx_dir/.ftpaccess");
  if (open(my $fh, "> $ftpaccess_file")) {
    print $fh <<EOL;
<Limit ALL>
  AllowUser bar,$user,
  DenyAll
</Limit>
EOL
    unless (close($fh)) {
      die("Can't write $ftpaccess_file: $!");
    }

  } else {
    die("Can't open $ftpaccess_file: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $foo_dir, $bar_dir, $baz_dir, $quxx_dir)) {
      die("Can't set perms on dirs to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $foo_dir, $bar_dir, $baz_dir, $quxx_dir)) {
      die("Can't set owner of dirs to $uid/$gid: $!");
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

    AllowOverride => 'on',
    DefaultRoot => '~',
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

      $client->cwd("foo/baz");
      my $conn = $client->list_raw();
      unless ($conn) {
        die("Failed to LIST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quote('CWD', '..');
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

sub list_symlink_issue697 {
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

  my $a_dir = File::Spec->rel2abs("$tmpdir/a");
  my $b_dir = File::Spec->rel2abs("$tmpdir/b");
  mkpath([$a_dir, $b_dir]);

  my $a_file = File::Spec->rel2abs("$a_dir/file");
  if (open(my $fh, "> $a_file")) {
    close($fh);

  } else {
    die("Can't open $a_file: $!");
  }

  # Change to the 'b' directory in order to create a relative path in the
  # symlink we need

  my $cwd = getcwd();
  unless (chdir("$b_dir")) {
    die("Can't chdir to $b_dir: $!");
  }

  unless (symlink('../file', 'link')) {
    die("Can't symlink '../file' to 'link': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $a_dir, $b_dir)) {
      die("Can't set perms on dirs to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $a_dir, $b_dir)) {
      die("Can't set owner of dirs to $uid/$gid: $!");
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

    AllowOverride => 'on',
    DefaultRoot => '~',
    ListOptions => '-al NoAdjustedSymlinks',

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

      $client->cwd("b");
      my $conn = $client->list_raw();
      unless ($conn) {
        die("Failed to LIST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# LIST:\n$buf\n";
      }

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

sub list_symlink_rel_with_double_slash_bug3719 {
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
  my $bar_dir = File::Spec->rel2abs("$tmpdir/bar");
  my $baz_dir = File::Spec->rel2abs("$tmpdir/bar/baz");
  mkpath([$foo_dir, $bar_dir, $baz_dir]);

  # Change to the 'foo' directory in order to create a relative path in the
  # symlink we need

  my $cwd = getcwd();
  unless (chdir("$foo_dir")) {
    die("Can't chdir to $foo_dir: $!");
  }

  unless (symlink('../bar//baz', 'baz')) {
    die("Can't symlink '../bar//baz' to 'baz': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $foo_dir, $bar_dir, $baz_dir)) {
      die("Can't set perms on dirs to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $foo_dir, $bar_dir, $baz_dir)) {
      die("Can't set owner of dirs to $uid/$gid: $!");
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

    DefaultRoot => '~',

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

      $client->cwd("foo");
      my $conn = $client->list_raw();
      unless ($conn) {
        die("Failed to LIST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();

      # We have to be careful of the fact that readdir returns directory
      # entries in an unordered fashion.
      my $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          $res->{$1} = 1;
        }
      }

      my $expected = {
        '../bar//baz' => 1,
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
        die("Unexpected name '$mismatch' appeared in LIST data")
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

sub list_showsymlinks_off {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $foo_dir = File::Spec->rel2abs("$tmpdir/foo");
  my $bar_dir = File::Spec->rel2abs("$tmpdir/bar");
  my $baz_dir = File::Spec->rel2abs("$tmpdir/bar/baz");
  mkpath([$foo_dir, $bar_dir, $baz_dir]);

  # Change to the 'foo' directory in order to create a relative path in the
  # symlink we need

  my $cwd = getcwd();
  unless (chdir($foo_dir)) {
    die("Can't chdir to $foo_dir: $!");
  }

  unless (symlink('../bar/baz', 'baz')) {
    die("Can't symlink '../bar/baz' to 'baz': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  # Make sure that, if we're running as root, that the directories have
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $foo_dir, $bar_dir, $baz_dir)) {
      die("Can't set perms on dirs to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $foo_dir, $bar_dir, $baz_dir)) {
      die("Can't set owner of dirs to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

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

      $client->cwd("foo");
      my $conn = $client->list_raw('-l');
      unless ($conn) {
        die("Failed to LIST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $client->quit();

      $self->assert_transfer_ok($resp_code, $resp_msg);

      chomp($buf);

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Response:\n$buf\n";
      }

      my $expected = '^d\S+\s+\d+\s+\S+\s+\S+\s+\d+\s+\S+\s+\d+\s+\S+\s+(.*?)$';
      $self->assert(qr/$expected/, $buf,
        test_msg("Expected '$expected', got '$buf'"));

      $buf =~ /$expected/;
      my $finfo = $1;

      $expected = 'baz';
      $self->assert($expected eq $finfo,
        test_msg("Expected '$expected', got '$finfo'"));
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

sub list_showsymlinks_off_chrooted_bug4219 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $foo_dir = File::Spec->rel2abs("$tmpdir/foo");
  my $bar_dir = File::Spec->rel2abs("$tmpdir/bar");
  my $baz_dir = File::Spec->rel2abs("$tmpdir/bar/baz");
  mkpath([$foo_dir, $bar_dir, $baz_dir]);

  # Change to the 'foo' directory in order to create a relative path in the
  # symlink we need

  my $cwd = getcwd();
  unless (chdir($foo_dir)) {
    die("Can't chdir to $foo_dir: $!");
  }

  unless (symlink('../bar/baz', 'baz')) {
    die("Can't symlink '../bar/baz' to 'baz': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  # Make sure that, if we're running as root, that the directories have
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $foo_dir, $bar_dir, $baz_dir)) {
      die("Can't set perms on dirs to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $foo_dir, $bar_dir, $baz_dir)) {
      die("Can't set owner of dirs to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    DefaultRoot => '~',
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

      $client->cwd("foo");
      my $conn = $client->list_raw('-l');
      unless ($conn) {
        die("Failed to LIST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $client->quit();

      $self->assert_transfer_ok($resp_code, $resp_msg);

      chomp($buf);

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Response:\n$buf\n";
      }

      my $expected = '^d\S+\s+\d+\s+\S+\s+\S+\s+\d+\s+\S+\s+\d+\s+\S+\s+(.*?)$';
      $self->assert(qr/$expected/, $buf,
        test_msg("Expected '$expected', got '$buf'"));

      $buf =~ /$expected/;
      my $finfo = $1;

      $expected = 'baz';
      $self->assert($expected eq $finfo,
        test_msg("Expected '$expected', got '$finfo'"));
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

sub list_showsymlinks_on {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $foo_dir = File::Spec->rel2abs("$tmpdir/foo");
  my $bar_dir = File::Spec->rel2abs("$tmpdir/bar");
  my $baz_dir = File::Spec->rel2abs("$tmpdir/bar/baz");
  mkpath([$foo_dir, $bar_dir, $baz_dir]);

  # Change to the 'foo' directory in order to create a relative path in the
  # symlink we need

  my $cwd = getcwd();
  unless (chdir($foo_dir)) {
    die("Can't chdir to $foo_dir: $!");
  }

  unless (symlink('../bar/baz', 'baz')) {
    die("Can't symlink '../bar/baz' to 'baz': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  # Make sure that, if we're running as root, that the directories have
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $foo_dir, $bar_dir, $baz_dir)) {
      die("Can't set perms on dirs to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $foo_dir, $bar_dir, $baz_dir)) {
      die("Can't set owner of dirs to $setup->{uid}/$setup->{gid}: $!");
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

      $client->cwd("foo");
      my $conn = $client->list_raw('-l');
      unless ($conn) {
        die("Failed to LIST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $client->quit();

      $self->assert_transfer_ok($resp_code, $resp_msg);

      chomp($buf);

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Response:\n$buf\n";
      }

      my $expected = '^l\S+\s+\d+\s+\S+\s+\S+\s+\d+\s+\S+\s+\d+\s+\S+\s+(.*?)$';
      $self->assert(qr/$expected/, $buf,
        test_msg("Expected '$expected', got '$buf'"));

      $buf =~ /$expected/;
      my $finfo = $1;

      $expected = 'baz -> ../bar/baz';
      $self->assert($expected eq $finfo,
        test_msg("Expected '$expected', got '$finfo'"));
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

sub list_showsymlinks_on_chrooted_bug4219 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $foo_dir = File::Spec->rel2abs("$tmpdir/foo");
  my $bar_dir = File::Spec->rel2abs("$tmpdir/bar");
  my $baz_dir = File::Spec->rel2abs("$tmpdir/bar/baz");
  mkpath([$foo_dir, $bar_dir, $baz_dir]);

  # Change to the 'foo' directory in order to create a relative path in the
  # symlink we need

  my $cwd = getcwd();
  unless (chdir($foo_dir)) {
    die("Can't chdir to $foo_dir: $!");
  }

  unless (symlink('../bar/baz', 'baz')) {
    die("Can't symlink '../bar/baz' to 'baz': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  # Make sure that, if we're running as root, that the directories have
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $foo_dir, $bar_dir, $baz_dir)) {
      die("Can't set perms on dirs to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $foo_dir, $bar_dir, $baz_dir)) {
      die("Can't set owner of dirs to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

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

      $client->cwd("foo");
      my $conn = $client->list_raw('-l');
      unless ($conn) {
        die("Failed to LIST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $client->quit();

      $self->assert_transfer_ok($resp_code, $resp_msg);

      chomp($buf);

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Response:\n$buf\n";
      }

      my $expected = '^l\S+\s+\d+\s+\S+\s+\S+\s+\d+\s+\S+\s+\d+\s+\S+\s+(.*?)$';
      $self->assert(qr/$expected/, $buf,
        test_msg("Expected '$expected', got '$buf'"));

      $buf =~ /$expected/;
      my $finfo = $1;

      $expected = 'baz -> /bar/baz';
      $self->assert($expected eq $finfo,
        test_msg("Expected '$expected', got '$finfo'"));
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

sub list_glob_bug2367 {
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

  my $test_dir = File::Spec->rel2abs("$home_dir/foo");
  mkpath($test_dir);

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $test_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $test_dir)) {
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
      $client->cwd($test_dir);

      my $conn = $client->list_raw("*.*");
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          $res->{$1} = 1;
        }
      }

      my $count = scalar(keys(%$res));
      unless ($count == 0) {
        die("LIST returned wrong number of entries (expected 0, got $count)");
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

sub list_glob_legit_dir_name {
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

  my $test_dir = File::Spec->rel2abs("$home_dir/\[foo bar");
  mkpath($test_dir);

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $test_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $test_dir)) {
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
      $client->cwd($test_dir);

      my $conn = $client->list_raw("-a $test_dir");
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          $res->{$1} = 1;
        }
      }

      my $count = scalar(keys(%$res));
      unless ($count == 2) {
        die("LIST returned wrong number of entries (expected 2, got $count)");
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

sub list_glob_legit_dir_name_bug3407 {
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

  my $test_dir = File::Spec->rel2abs("$home_dir/\[foo bar\]");
  mkpath($test_dir);

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $test_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $test_dir)) {
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
      $client->cwd($test_dir);

      my $conn = $client->list_raw("-a $test_dir");
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          $res->{$1} = 1;
        }
      }

      my $count = scalar(keys(%$res));
      unless ($count == 2) {
        die("LIST returned wrong number of entries (expected 2, got $count)");
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

sub list_opt_c {
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

  # For this test, we need to create about 3 files in home directory.

  my $count = 3;
  for (my $i = 1; $i <= $count; $i++) {
    my $test_file = sprintf("%04s", $i);
    my $test_path = "$home_dir/$test_file";

    if (open(my $fh, "> $test_path")) {
      close($fh);

    } else {
      die("Can't open $test_path: $!");
    }

    my $timestamp = time() - ($i * 5);
    unless (utime($timestamp, $timestamp, $test_path)) {
      die("Can't change times on $test_path: $!");
    }

    # Delay between file creations, to make the ctimes different
    sleep(1);
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

      # Use the -t option to sort by time, and the -c option to sort by
      # st_ctime.  Thus the last file we created should appear first in the
      # returned list.
      my $conn = $client->list_raw("-ct 0*");
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 32768, 30);
      eval { $conn->close() };

      my $res = {};
      my $lines = [split(/\n/, $buf)];

      my $fileno = 3;
      foreach my $line (@$lines) {
        if ($line =~ /\s+(\S+)$/) {
          my $filename = $1;

          my $expected = sprintf("%04s", $fileno--);

          $self->assert($expected eq $filename,
            test_msg("Expected '$expected', got '$filename'"));

          $res->{$filename} = 1;
        }
      }

      my $list_count = scalar(keys(%$res));
      unless ($list_count == $count) {
        die("LIST returned wrong number of entries (expected $count, got $list_count)");
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

sub list_opt_u {
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

  # For this test, we need to create about 3 files in home directory.

  my $count = 3;
  for (my $i = 1; $i <= $count; $i++) {
    my $test_file = sprintf("%04s", $i);
    my $test_path = "$home_dir/$test_file";

    if (open(my $fh, "> $test_path")) {
      close($fh);

    } else {
      die("Can't open $test_path: $!");
    }

    my $atime = time() + ($i * 5);
    my $mtime = time() - ($i * 5);
    unless (utime($atime, $mtime, $test_path)) {
      die("Can't change times on $test_path: $!");
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

      # Use the -t option to sort by time, and the -u option to sort by
      # st_atime.  Thus the last file we created should appear first in the
      # returned list.
      my $conn = $client->list_raw("-ut 0*");
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 32768, 30);
      eval { $conn->close() };

      my $res = {};
      my $lines = [split(/\n/, $buf)];

      my $fileno = 3;
      foreach my $line (@$lines) {
        if ($line =~ /\s+(\S+)$/) {
          my $filename = $1;

          my $expected = sprintf("%04s", $fileno--);

          $self->assert($expected eq $filename,
            test_msg("Expected '$expected', got '$filename'"));

          $res->{$filename} = 1;
        }
      }

      my $list_count = scalar(keys(%$res));
      unless ($list_count == $count) {
        die("LIST returned wrong number of entries (expected $count, got $list_count)");
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

sub list_dash_filename_bug3476 {
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

  my $test_file = File::Spec->rel2abs("$tmpdir/-test.txt");
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

      my $conn = $client->list_raw('-test.txt');
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*\s+(.*?)$/) {
          my $filename = $1;
          $res->{$filename} = 1;
        }
      }

      my $count = scalar(keys(%$res));
      unless ($count == 1) {
        die("LIST returned wrong number of entries (expected 1, got $count)");
      }

      my $expected = '-test.txt';
      unless (defined($res->{$expected})) {
        die("LIST failed to return $expected");
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

sub list_opt_noerrorifabsent_bug3506 {
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

  my $test_file = File::Spec->rel2abs('foo-bar.txt');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    ListOptions => '"" NoErrorIfAbsent',

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

      my $conn = $client->list_raw($test_file);
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      my $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          $res->{$1} = 1;
        }
      }

      my $count = scalar(keys(%$res));
      unless ($count == 0) {
        die("LIST returned wrong number of entries (expected 0, got $count)");
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

sub list_slashstar_bug3529 {
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

  my $sub_dir = File::Spec->rel2abs("$tmpdir/AAA");
  mkpath($sub_dir);

  my $test_file = File::Spec->rel2abs("$tmpdir/foo.txt");
  if (open(my $fh, "> $test_file")) {
    close($fh);

  } else {
    die("Can't open $test_file: $!");
  }

  $test_file = File::Spec->rel2abs("$tmpdir/.dotfile");
  if (open(my $fh, "> $test_file")) {
    close($fh);

  } else {
    die("Can't open $test_file: $!");
  }

  $test_file = File::Spec->rel2abs("$sub_dir/bar.txt");
  if (open(my $fh, "> $test_file")) {
    close($fh);

  } else {
    die("Can't open $test_file: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on dirs to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
      die("Can't set owner of dirs to $uid/$gid: $!");
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

      my $conn = $client->list_raw('/*');
      unless ($conn) {
        die("Failed to LIST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();

      # We have to be careful of the fact that readdir returns directory
      # entries in an unordered fashion.
      my $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          $res->{$1} = 1;
        }
      }

      my $expected = {
        '/AAA' => 1,
        '/cmds.conf' => 1,
        '/cmds.group' => 1,
        '/cmds.passwd' => 1,
        '/cmds.pid' => 1,
        '/cmds.scoreboard' => 1,
        '/cmds.scoreboard.lck' => 1,
        '/foo.txt' => 1,
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
        die("Unexpected name '$mismatch' appeared in LIST data")
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

sub list_star_bug3529 {
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

  my $sub_dir = File::Spec->rel2abs("$tmpdir/AAA");
  mkpath($sub_dir);

  my $test_file = File::Spec->rel2abs("$tmpdir/foo.txt");
  if (open(my $fh, "> $test_file")) {
    close($fh);

  } else {
    die("Can't open $test_file: $!");
  }

  $test_file = File::Spec->rel2abs("$tmpdir/.dotfile");
  if (open(my $fh, "> $test_file")) {
    close($fh);

  } else {
    die("Can't open $test_file: $!");
  }

  $test_file = File::Spec->rel2abs("$sub_dir/bar.txt");
  if (open(my $fh, "> $test_file")) {
    close($fh);

  } else {
    die("Can't open $test_file: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on dirs to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
      die("Can't set owner of dirs to $uid/$gid: $!");
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

      my $conn = $client->list_raw('*');
      unless ($conn) {
        die("Failed to LIST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();

      # We have to be careful of the fact that readdir returns directory
      # entries in an unordered fashion.
      my $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          $res->{$1} = 1;
        }
      }

      my $expected = {
        'AAA' => 1,
        'cmds.conf' => 1,
        'cmds.group' => 1,
        'cmds.passwd' => 1,
        'cmds.pid' => 1,
        'cmds.scoreboard' => 1,
        'cmds.scoreboard.lck' => 1,
        'foo.txt' => 1,
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
        die("Unexpected name '$mismatch' appeared in LIST data")
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

sub list_opt_R {
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

  # For this test, we need to create about 100 files in home directory.
  my $test_file_prefix = File::Spec->rel2abs($tmpdir);

  my $dir_count = 10;
  my $file_count = 10;

  print STDOUT "# Creating $dir_count directories in $tmpdir\n";
  for (my $i = 1; $i <= $dir_count; $i++) {
    my $test_dir = sprintf("%04s", $i);
    my $dir_path = "$home_dir/$test_dir";

    mkpath($dir_path);

    print STDOUT "# Creating $file_count files in $dir_path\n";
    for (my $j = 1; $j <= $file_count; $j++) {
      my $test_file = sprintf("%02s%02s", $i, $j);
      my $file_path = "$dir_path/$test_file";

      if (open(my $fh, "> $file_path")) {
        close($fh);

      } else {
        die("Can't open $file_path: $!");
      }
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

      my $conn = $client->list_raw("-R");
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      my $tmp;

      my $res = $conn->read($tmp, 32768, 25);
      while ($res) {
        $buf .= $tmp;
        $tmp = undef;

        $res = $conn->read($tmp, 32768, 25);
      }

      eval { $conn->close() };

      $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /\s+(\S+)$/) {
          $res->{$1} = 1;
        }
      }

      my $list_count = scalar(keys(%$res));

      # There are 10 directories, with 10 files in each.  That's 100 files.
      # Plus 10 for the directory names themselves.  Plus 6 files for the
      # config, scoreboard, etc.  That gives a total of 116 files expected.
      # The  extra files are for the config file, scoreboard, etc.
      my $expected_count = ($dir_count * $file_count) + 16;
      unless ($list_count == $expected_count) {
        die("LIST returned wrong number of entries (expected $expected_count, got $list_count)");
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

sub list_opt_R_self_symlinked_dir_bug3719 {
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

  # For this test, we need to create about 100 files in a sub directory.
  my $test_dir = File::Spec->rel2abs("$tmpdir/sub.d");
  mkpath($test_dir);

  my $test_file_prefix = $test_dir;

  my $dir_count = 10;
  my $file_count = 10;

  if ($ENV{TEST_VERBOSE}) {
    print STDOUT "# Creating $dir_count directories in $tmpdir\n";
  }

  for (my $i = 1; $i <= $dir_count; $i++) {
    my $sub_dir = sprintf("%04s", $i);
    my $dir_path = "$home_dir/$sub_dir";

    mkpath($dir_path);

    if ($ENV{TEST_VERBOSE}) {
      print STDOUT "# Creating $file_count files in $dir_path\n";
    }

    for (my $j = 1; $j <= $file_count; $j++) {
      my $test_file = sprintf("%02s%02s", $i, $j);
      my $file_path = "$dir_path/$test_file";

      if (open(my $fh, "> $file_path")) {
        close($fh);

      } else {
        die("Can't open $file_path: $!");
      }
    }
  }

  # Now create a directory symlink, in the home directory, pointing to itself.
  # This self-symlink is what caused Bug#3719 - proftpd would loop endlessly.

  my $cwd = getcwd();

  unless (chdir($test_dir)) {
    die("Can't chdir to $test_dir: $!");
  }

  unless (symlink('.', 'self.d')) {
    die("Can't symlink '.' to 'self.d': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
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

      my $conn = $client->list_raw("-R");
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      my $tmp;

      my $res = $conn->read($tmp, 32768, 25);
      while ($res) {
        $buf .= $tmp;
        $tmp = undef;

        $res = $conn->read($tmp, 32768, 25);
      }

      eval { $conn->close() };

      $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /\s+(\S+)$/) {
          $res->{$1} = 1;
        }
      }

      my $list_count = scalar(keys(%$res));

      # There are 10 directories, with 10 files in each.  That's 100 files.
      # Plus 10 for the directory names themselves.  Plus 6 files for the
      # config, scoreboard, etc, and one for the symlink.  That gives a total
      # of 116 files expected.  The extra files are for the config file,
      # scoreboard, etc.
      my $expected_count = ($dir_count * $file_count) + 17;
      unless ($list_count == $expected_count) {
        die("LIST returned wrong number of entries (expected $expected_count, got $list_count)");
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

sub list_opt_R_self_complex_symlinked_dir_bug3719 {
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

  # For this test, we need to create about 100 files in a sub directory.
  my $test_dir = File::Spec->rel2abs("$tmpdir/sub.d");
  mkpath($test_dir);

  my $test_file_prefix = $test_dir;

  my $dir_count = 10;
  my $file_count = 10;

  if ($ENV{TEST_VERBOSE}) {
    print STDOUT "# Creating $dir_count directories in $tmpdir\n";
  }

  for (my $i = 1; $i <= $dir_count; $i++) {
    my $sub_dir = sprintf("%04s", $i);
    my $dir_path = "$home_dir/$sub_dir";

    mkpath($dir_path);

    if ($ENV{TEST_VERBOSE}) {
      print STDOUT "# Creating $file_count files in $dir_path\n";
    }

    for (my $j = 1; $j <= $file_count; $j++) {
      my $test_file = sprintf("%02s%02s", $i, $j);
      my $file_path = "$dir_path/$test_file";

      if (open(my $fh, "> $file_path")) {
        close($fh);

      } else {
        die("Can't open $file_path: $!");
      }
    }
  }

  # Now create a directory symlink, in the home directory, pointing to itself.
  # This self-symlink is what caused Bug#3719 - proftpd would loop endlessly.

  my $cwd = getcwd();

  unless (chdir($test_dir)) {
    die("Can't chdir to $test_dir: $!");
  }

  unless (symlink('../.././././.././', 'self.d')) {
    die("Can't symlink '../.././././.././' to 'self.d': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
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

      my $conn = $client->list_raw("-R");
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      my $tmp;

      my $res = $conn->read($tmp, 32768, 25);
      while ($res) {
        $buf .= $tmp;
        $tmp = undef;

        $res = $conn->read($tmp, 32768, 25);
      }

      eval { $conn->close() };

      $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /\s+(\S+)$/) {
          $res->{$1} = 1;
        }
      }

      my $list_count = scalar(keys(%$res));

      # There are 10 directories, with 10 files in each.  That's 100 files.
      # Plus 10 for the directory names themselves.  Plus 6 files for the
      # config, scoreboard, etc, and one for the symlink.  That gives a total
      # of 116 files expected.  The extra files are for the config file,
      # scoreboard, etc.
      my $expected_count = ($dir_count * $file_count) + 17;
      unless ($list_count == $expected_count) {
        die("LIST returned wrong number of entries (expected $expected_count, got $list_count)");
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

sub list_opt_R_rel_symlinked_file_bug3719 {
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

  # For this test, we need to create about 100 files in a sub directory.
  my $test_dir = File::Spec->rel2abs("$tmpdir/sub.d");
  mkpath($test_dir);

  my $test_file = File::Spec->rel2abs("$test_dir/test.txt");
  if (open(my $fh, "> $test_file")) {
    close($fh);

  } else {
    die("Can't open $test_file: $!");
  }

  my $test_file_prefix = $test_dir;

  my $dir_count = 10;
  my $file_count = 10;

  if ($ENV{TEST_VERBOSE}) {
    print STDOUT "# Creating $dir_count directories in $tmpdir\n";
  }

  for (my $i = 1; $i <= $dir_count; $i++) {
    my $sub_dir = sprintf("%04s", $i);
    my $dir_path = "$home_dir/$sub_dir";

    mkpath($dir_path);

    if ($ENV{TEST_VERBOSE}) {
      print STDOUT "# Creating $file_count files in $dir_path\n";
    }

    for (my $j = 1; $j <= $file_count; $j++) {
      my $test_file = sprintf("%02s%02s", $i, $j);
      my $file_path = "$dir_path/$test_file";

      if (open(my $fh, "> $file_path")) {
        close($fh);

      } else {
        die("Can't open $file_path: $!");
      }
    }
  }

  my $cwd = getcwd();

  unless (chdir($test_dir)) {
    die("Can't chdir to $test_dir: $!");
  }

  unless (symlink('./test.txt', 'test.lnk')) {
    die("Can't symlink './test.txt' to 'test.lnk': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
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

      my $conn = $client->list_raw("-R");
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      my $tmp;

      my $res = $conn->read($tmp, 32768, 25);
      while ($res) {
        $buf .= $tmp;
        $tmp = undef;

        $res = $conn->read($tmp, 32768, 25);
      }

      eval { $conn->close() };

      $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /\s+(\S+)$/) {
          $res->{$1} = 1;
        }
      }

      my $list_count = scalar(keys(%$res));

      # There are 10 directories, with 10 files in each.  That's 100 files.
      # Plus 10 for the directory names themselves.  Plus 6 files for the
      # config, scoreboard, etc, and one for the symlink.  That gives a total
      # of 116 files expected.  The extra files are for the config file,
      # scoreboard, etc.
      my $expected_count = ($dir_count * $file_count) + 19;
      unless ($list_count == $expected_count) {
        die("LIST returned wrong number of entries (expected $expected_count, got $list_count)");
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

sub list_option_parsing {
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

      for (my $i = 0; $i < 5; $i++) {
        my $conn = $client->list_raw("-a ");
        unless ($conn) {
          die("LIST failed: " . $client->response_code() . " " .
            $client->response_msg());
        }

        my $buf;
        my $tmp;

        my $res = $conn->read($tmp, 32768, 25);
        while ($res) {
          $buf .= $tmp;
          $tmp = undef;

          $res = $conn->read($tmp, 32768, 25);
        }

        eval { $conn->close() };

        my $resp_code = $client->response_code();
        my $resp_msg = $client->response_msg();
        $self->assert_transfer_ok($resp_code, $resp_msg);
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

sub list_symlink_rel_path_chrooted_bug4322 {
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

      my $conn = $client->list_raw();
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      my $res = $conn->read($buf, 8192, 25);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);
      $client->quit();

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# LIST:\n$buf\n";
      }

      $res = {};
      my $lines = [split(/(\r)?\n/, $buf)];
      my $line_count = 0;
      foreach my $line (@$lines) {
        if ($line =~ /\s+(\S+)$/) {
          $line_count++;
          $res->{$1} = 1;
        }
      }

      my $expected = 9;
      $self->assert($line_count == $expected,
        "Expected $expected lines, got $line_count");

      # The keys are the filenames; we have two symlinks pointing to the same
      # file.  Hence the different line vs key counts.
      my $list_count = scalar(keys(%$res));
      $expected = 8;
      $self->assert($list_count == $expected,
        "Expected $expected entries, got $list_count");

      $self->assert($res->{'/domains/test.oxilion.nl/public_html'},
        "Expected '/domains/test.oxilion.nl/public_html'");
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

sub list_symlink_rel_path_subdir_chrooted_bug4322 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $dst_path = 'domains/test.oxilion.nl/public_html';
  my $dst_dir = File::Spec->rel2abs("$tmpdir/test.d/$dst_path");
  mkpath($dst_dir);

  my $cwd = getcwd();
  unless (chdir("$tmpdir/test.d")) {
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

      my $conn = $client->list_raw('test.d');
      unless ($conn) {
        die("LIST test.d failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      my $res = $conn->read($buf, 8192, 25);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);
      $client->quit();

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# LIST:\n$buf\n";
      }

      $res = {};
      my $lines = [split(/(\r)?\n/, $buf)];
      my $line_count = 0;
      foreach my $line (@$lines) {
        if ($line =~ /\s+(\S+)$/) {
          $line_count++;
          $res->{$1} = 1;
        }
      }

      my $expected = 3;
      $self->assert($line_count == $expected,
        "Expected $expected lines, got $line_count");

      # The keys are the filenames; we have two symlinks pointing to the same
      # file.  Hence the different line vs key counts.
      my $list_count = scalar(keys(%$res));
      $expected = 2;
      $self->assert($list_count == $expected,
        "Expected $expected entries, got $list_count");

      $self->assert($res->{'/domains/test.oxilion.nl/public_html'},
        "Expected '/domains/test.oxilion.nl/public_html'");
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

sub list_symlink_rel_path_subdir_cwd_chrooted_bug4322 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $dst_path = 'domains/test.oxilion.nl/public_html';
  my $dst_dir = File::Spec->rel2abs("$tmpdir/test.d/$dst_path");
  mkpath($dst_dir);

  my $cwd = getcwd();
  unless (chdir("$tmpdir/test.d")) {
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

      my $conn = $client->list_raw();
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      my $res = $conn->read($buf, 8192, 25);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);
      $client->quit();

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# LIST:\n$buf\n";
      }

      $res = {};
      my $lines = [split(/(\r)?\n/, $buf)];
      my $line_count = 0;
      foreach my $line (@$lines) {
        if ($line =~ /\s+(\S+)$/) {
          $line_count++;
          $res->{$1} = 1;
        }
      }

      my $expected = 3;
      $self->assert($line_count == $expected,
        "Expected $expected lines, got $line_count");

      # The keys are the filenames; we have two symlinks pointing to the same
      # file.  Hence the different line vs key counts.
      my $list_count = scalar(keys(%$res));
      $expected = 2;
      $self->assert($list_count == $expected,
        "Expected $expected entries, got $list_count");

      $self->assert($res->{'/domains/test.oxilion.nl/public_html'},
        "Expected '/domains/test.oxilion.nl/public_html'");
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
