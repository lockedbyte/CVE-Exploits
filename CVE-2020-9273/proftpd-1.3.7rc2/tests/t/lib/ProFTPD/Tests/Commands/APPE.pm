package ProFTPD::Tests::Commands::APPE;

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
  appe_ok_raw_active => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  appe_ok_raw_passive => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  appe_ok_file_new => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  appe_ok_file_existing => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  appe_ok_files_new_and_existing_bug3612 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  appe_fails_abs_symlink_new => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  appe_fails_abs_symlink_new_chrooted_bug4219 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  appe_fails_rel_symlink_new => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  appe_fails_rel_symlink_new_chrooted_bug4219 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  appe_ok_rel_symlink_existing => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  appe_ok_rel_symlink_existing_chrooted_bug4219 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  appe_ok_abs_symlink_existing => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  appe_ok_abs_symlink_existing_chrooted_bug4219 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  appe_fails_not_reg => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  appe_fails_rel_symlink_not_reg => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  appe_fails_rel_symlink_not_reg_chrooted_bug4219 => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  appe_fails_abs_symlink_not_reg => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  appe_fails_abs_symlink_not_reg_chrooted_bug4219 => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  appe_fails_login_required => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  appe_fails_no_path => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  appe_fails_eperm => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  appe_hiddenstores_bug4144 => {
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

sub appe_ok_raw_active {
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

      my $conn = $client->appe_raw('bar');
      unless ($conn) {
        die("Failed to APPE: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Foo!\n";
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

sub appe_ok_raw_passive {
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

      my $conn = $client->appe_raw('bar');
      unless ($conn) {
        die("Failed to APPE: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Foo!\n";
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

sub appe_ok_file_new {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $test_file = File::Spec->rel2abs("$tmpdir/bar");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    AllowOverwrite => 'on',
    AllowStoreRestart => 'on',

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

      my $conn = $client->appe_raw('bar');
      unless ($conn) {
        die("APPE failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Foo!\n";
      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      my $expected = -s $test_file;
      my $size = length($buf);
      $self->assert($expected == $size,
        test_msg("Expected $expected, got $size"));
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

sub appe_ok_file_existing {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $test_file = File::Spec->rel2abs("$tmpdir/bar");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $test_sz = -s $test_file;

  if ($< == 0) {
    unless (chmod(0755, $test_file)) {
      die("Can't set perms on $test_file to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $test_file)) {
      die("Can't set owner of $test_file to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    AllowOverwrite => 'on',
    AllowStoreRestart => 'on',

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

      my $conn = $client->appe_raw('bar');
      unless ($conn) {
        die("APPE failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Foo!\n";
      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      my $expected = $test_sz + length($buf);
      my $size = -s $test_file;
      $self->assert($expected == $size,
        test_msg("Expected $expected, got $size"));
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

sub appe_ok_files_new_and_existing_bug3612 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $test_file1 = File::Spec->rel2abs("$tmpdir/foo");
  my $test_file2 = File::Spec->rel2abs("$tmpdir/bar");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    AllowOverwrite => 'on',
    AllowStoreRestart => 'on',

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

      # 1.  STOR foo
      my $conn = $client->stor_raw('foo');
      unless ($conn) {
        die("STOR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Foo!\n";
      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      my $test_sz1 = length($buf);
      my $expected = $test_sz1;
      my $test_sz = -s $test_file1;
      $self->assert($expected == $test_sz,
        test_msg("Expected $expected bytes, got $test_sz bytes"));

      # 2.  STOR bar
      $conn = $client->stor_raw('bar');
      unless ($conn) {
        die("STOR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      $buf = "Bar!\n";
      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      my $test_sz2 = length($buf);
      $expected = $test_sz2;
      $test_sz = -s $test_file2;
      $self->assert($expected == $test_sz,
        test_msg("Expected $expected bytes, got $test_sz bytes"));

      # 3.  APPE foo
      $conn = $client->appe_raw('foo');
      unless ($conn) {
        die("APPE failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      $buf = "More foo!\n";
      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $expected = $test_sz1 + length($buf);
      $test_sz = -s $test_file1;
      $self->assert($expected == $test_sz,
        test_msg("Expected $expected bytes, got $test_sz bytes"));

      # 4.  STOR bar
      $conn = $client->stor_raw('bar');
      unless ($conn) {
        die("STOR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      $buf = "Bar!\n";
      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);
      $client->quit();

      $expected = $test_sz2;
      $test_sz = -s $test_file2;
      $self->assert($expected == $test_sz,
        test_msg("Expected $expected bytes, got $test_sz bytes"));
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

sub appe_fails_abs_symlink_new {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d");
  mkpath($test_dir);

  my $test_file = File::Spec->rel2abs("$test_dir/test.txt");
  my $test_symlink = File::Spec->rel2abs("$test_dir/test.lnk");

  unless (symlink($test_file, $test_symlink)) {
    die("Can't symlink $test_symlink to $test_file: $!");
  }

  if ($< == 0) {
    unless (chmod(0755, $test_dir)) {
      die("Can't set perms on $test_dir to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $test_dir)) {
      die("Can't set owner of $test_dir to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    AllowOverwrite => 'on',
    AllowStoreRestart => 'on',

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

      my $conn = $client->appe_raw('test.d/test.lnk');
      if ($conn) {
        die("APPE succeeded unexpectedly");
      }

      # In this case, we SHOULD expect failure, since we have a dangling
      # symlink.  We COULD automatically create a file, but we don't know
      # whether that symlink is meant to point to a file, or a directory,
      # or anything else.  Thus we bail.

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $client->quit();

      my $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'test.d/test.lnk: Not a regular file';
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message $expected, got $resp_msg"));
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

sub appe_fails_abs_symlink_new_chrooted_bug4219 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d");
  mkpath($test_dir);

  my $test_file = File::Spec->rel2abs("$test_dir/test.txt");
  my $test_symlink = File::Spec->rel2abs("$test_dir/test.lnk");

  unless (symlink($test_file, $test_symlink)) {
    die("Can't symlink $test_symlink to $test_file: $!");
  }

  if ($< == 0) {
    unless (chmod(0755, $test_dir)) {
      die("Can't set perms on $test_dir to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $test_dir)) {
      die("Can't set owner of $test_dir to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'fileperms:20 fsio:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    AllowOverwrite => 'on',
    AllowStoreRestart => 'on',
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

      my $conn = $client->appe_raw('test.d/test.lnk');
      if ($conn) {
        die("APPE succeeded unexpectedly");
      }

      # In this case, we SHOULD expect failure, since we have a dangling
      # symlink.  We COULD automatically create a file, but we don't know
      # whether that symlink is meant to point to a file, or a directory,
      # or anything else.  Thus we bail.

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $client->quit();

      my $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'test.d/test.lnk: Not a regular file';
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message $expected, got $resp_msg"));
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

sub appe_fails_rel_symlink_new {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d");
  mkpath($test_dir);

  my $test_file = File::Spec->rel2abs("$test_dir/test.txt");

  # Change to the test directory in order to create a relative path in the
  # symlink we need

  my $cwd = getcwd();
  unless (chdir($test_dir)) {
    die("Can't chdir to $test_dir: $!");
  }

  unless (symlink('./test.txt', './test.lnk')) {
    die("Can't symlink 'test.lnk' to './test.txt': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  if ($< == 0) {
    unless (chmod(0755, $test_dir)) {
      die("Can't set perms on $test_dir to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $test_dir)) {
      die("Can't set owner of $test_dir to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    AllowOverwrite => 'on',
    AllowStoreRestart => 'on',

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

      my $conn = $client->appe_raw('test.d/test.lnk');
      if ($conn) {
        die("APPE succeeded unexpectedly");
      }

      # In this case, we SHOULD expect failure, since we have a dangling
      # symlink.  We COULD automatically create a file, but we don't know
      # whether that symlink is meant to point to a file, or a directory,
      # or anything else.  Thus we bail.

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $client->quit();

      my $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'test.d/test.lnk: Not a regular file';
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message $expected, got $resp_msg"));
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

sub appe_fails_rel_symlink_new_chrooted_bug4219 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d");
  mkpath($test_dir);

  my $test_file = File::Spec->rel2abs("$test_dir/test.txt");

  # Change to the test directory in order to create a relative path in the
  # symlink we need

  my $cwd = getcwd();
  unless (chdir($test_dir)) {
    die("Can't chdir to $test_dir: $!");
  }

  unless (symlink('./test.txt', './test.lnk')) {
    die("Can't symlink 'test.lnk' to './test.txt': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  if ($< == 0) {
    unless (chmod(0755, $test_dir)) {
      die("Can't set perms on $test_dir to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $test_dir)) {
      die("Can't set owner of $test_dir to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    AllowOverwrite => 'on',
    AllowStoreRestart => 'on',
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

      my $conn = $client->appe_raw('test.d/test.lnk');
      if ($conn) {
        die("APPE succeeded unexpectedly");
      }

      # In this case, we SHOULD expect failure, since we have a dangling
      # symlink.  We COULD automatically create a file, but we don't know
      # whether that symlink is meant to point to a file, or a directory,
      # or anything else.  Thus we bail.

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $client->quit();

      my $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'test.d/test.lnk: Not a regular file';
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message $expected, got $resp_msg"));
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

sub appe_ok_abs_symlink_existing {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d");
  mkpath($test_dir);

  my $test_file = File::Spec->rel2abs("$test_dir/test.txt");
  if (open(my $fh, "> $test_file")) {
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $test_symlink = File::Spec->rel2abs("$test_dir/test.lnk");

  unless (symlink($test_file, $test_symlink)) {
    die("Can't symlink '$test_symlink' to '$test_file': $!");
  }

  if ($< == 0) {
    unless (chmod(0755, $test_dir)) {
      die("Can't set perms on $test_dir to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $test_dir, $test_file)) {
      die("Can't set owner of $test_dir to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    AllowOverwrite => 'on',
    AllowStoreRestart => 'on',

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

      my $conn = $client->appe_raw('test.d/test.lnk');
      unless ($conn) {
        die("APPE failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Foo!\n";
      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      my $expected = -s $test_file;
      my $size = length($buf);
      $self->assert($expected == $size,
        test_msg("Expected $expected, got $size"));
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

sub appe_ok_abs_symlink_existing_chrooted_bug4219 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d");
  mkpath($test_dir);

  my $test_file = File::Spec->rel2abs("$test_dir/test.txt");
  if (open(my $fh, "> $test_file")) {
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $test_symlink = File::Spec->rel2abs("$test_dir/test.lnk");

  my $dst_path = $test_file;
  if ($^O eq 'darwin') {
    # MacOSX-specific hack
    $dst_path = '/private' . $dst_path;
  }

  unless (symlink($dst_path, $test_symlink)) {
    die("Can't symlink '$test_symlink' to '$dst_path': $!");
  }

  if ($< == 0) {
    unless (chmod(0755, $test_dir)) {
      die("Can't set perms on $test_dir to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $test_dir, $test_file)) {
      die("Can't set owner of $test_dir to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'fileperms:20 fsio:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    AllowOverwrite => 'on',
    AllowStoreRestart => 'on',
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

      my $conn = $client->appe_raw('test.d/test.lnk');
      unless ($conn) {
        die("APPE failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Foo!\n";
      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      my $expected = -s $test_file;
      my $size = length($buf);
      $self->assert($expected == $size,
        test_msg("Expected $expected, got $size"));
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

sub appe_ok_rel_symlink_existing {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d");
  mkpath($test_dir);

  my $test_file = File::Spec->rel2abs("$test_dir/test.txt");
  if (open(my $fh, "> $test_file")) {
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  # Change to the test directory in order to create a relative path in the
  # symlink we need

  my $cwd = getcwd();
  unless (chdir($test_dir)) {
    die("Can't chdir to $test_dir: $!");
  }

  unless (symlink('./test.txt', './test.lnk')) {
    die("Can't symlink 'test.lnk' to './test.txt': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  if ($< == 0) {
    unless (chmod(0755, $test_dir)) {
      die("Can't set perms on $test_dir to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $test_dir, $test_file)) {
      die("Can't set owner of $test_dir to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    AllowOverwrite => 'on',
    AllowStoreRestart => 'on',

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

      my $conn = $client->appe_raw('test.d/test.lnk');
      unless ($conn) {
        die("APPE failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Foo!\n";
      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      my $expected = -s $test_file;
      my $size = length($buf);
      $self->assert($expected == $size,
        test_msg("Expected $expected, got $size"));
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

sub appe_ok_rel_symlink_existing_chrooted_bug4219 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d");
  mkpath($test_dir);

  my $test_file = File::Spec->rel2abs("$test_dir/test.txt");
  if (open(my $fh, "> $test_file")) {
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  # Change to the test directory in order to create a relative path in the
  # symlink we need

  my $cwd = getcwd();
  unless (chdir($test_dir)) {
    die("Can't chdir to $test_dir: $!");
  }

  unless (symlink('./test.txt', './test.lnk')) {
    die("Can't symlink 'test.lnk' to './test.txt': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  if ($< == 0) {
    unless (chmod(0755, $test_dir)) {
      die("Can't set perms on $test_dir to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $test_dir, $test_file)) {
      die("Can't set owner of $test_dir to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'fileperms:20 fsio:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    AllowOverwrite => 'on',
    AllowStoreRestart => 'on',
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

      my $conn = $client->appe_raw('test.d/test.lnk');
      unless ($conn) {
        die("APPE failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Foo!\n";
      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      my $expected = -s $test_file;
      my $size = length($buf);
      $self->assert($expected == $size,
        test_msg("Expected $expected, got $size"));
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

sub appe_fails_not_reg {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    AllowOverwrite => 'on',

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

      my $conn = $client->appe_raw($setup->{home_dir});
      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $client->quit();

      if ($conn) {
        die("APPE succeeded unexpectedly ($resp_code $resp_msg)");
      }

      my $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "$setup->{home_dir}: Not a regular file";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
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

sub appe_fails_abs_symlink_not_reg {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $sub_dir = File::Spec->rel2abs("$tmpdir/test.d");
  mkpath($sub_dir);

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d/foo.d");
  mkpath($test_dir);

  my $test_symlink = File::Spec->rel2abs("$test_dir/test.lnk");

  my $dst_path = $test_dir;
  if ($^O eq 'darwin') {
    # MacOSX-specific hack
    $dst_path = '/private' . $dst_path;
  }

  unless (symlink($dst_path, $test_symlink)) {
    die("Can't symlink '$test_symlink' to '$dst_path': $!");
  }

  if ($< == 0) {
    unless (chmod(0755, $sub_dir, $test_dir)) {
      die("Can't set perms on $test_dir to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $sub_dir, $test_dir)) {
      die("Can't set owner of $test_dir to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    AllowOverwrite => 'on',

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

      my $conn = $client->appe_raw('test.d/foo.d');
      if ($conn) {
        die("APPE succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $client->quit();

      my $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "test.d/foo.d: Not a regular file";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
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

sub appe_fails_abs_symlink_not_reg_chrooted_bug4219 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $sub_dir = File::Spec->rel2abs("$tmpdir/test.d");
  mkpath($sub_dir);

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d/foo.d");
  mkpath($test_dir);

  my $test_symlink = File::Spec->rel2abs("$test_dir/test.lnk");

  unless (symlink($test_dir, $test_symlink)) {
    die("Can't symlink '$test_symlink' to '$test_dir': $!");
  }

  if ($< == 0) {
    unless (chmod(0755, $sub_dir, $test_dir)) {
      die("Can't set perms on $test_dir to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $sub_dir, $test_dir)) {
      die("Can't set owner of $test_dir to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    AllowOverwrite => 'on',
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

      my $conn = $client->appe_raw('test.d/foo.d');
      if ($conn) {
        die("APPE succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $client->quit();

      my $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "test.d/foo.d: Not a regular file";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
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

sub appe_fails_rel_symlink_not_reg {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $sub_dir = File::Spec->rel2abs("$tmpdir/test.d");
  mkpath($sub_dir);

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d/foo.d");
  mkpath($test_dir);

  # Change to the test directory in order to create a relative path in the
  # symlink we need

  my $cwd = getcwd();
  unless (chdir($test_dir)) {
    die("Can't chdir to $test_dir: $!");
  }

  unless (symlink('./foo.d', './test.lnk')) {
    die("Can't symlink 'test.lnk' to './foo.d': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  if ($< == 0) {
    unless (chmod(0755, $sub_dir, $test_dir)) {
      die("Can't set perms on $test_dir to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $sub_dir, $test_dir)) {
      die("Can't set owner of $test_dir to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    AllowOverwrite => 'on',

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

      my $conn = $client->appe_raw('test.d/foo.d');
      if ($conn) {
        die("APPE succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $client->quit();

      my $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "test.d/foo.d: Not a regular file";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
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

sub appe_fails_rel_symlink_not_reg_chrooted_bug4219 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $sub_dir = File::Spec->rel2abs("$tmpdir/test.d");
  mkpath($sub_dir);

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d/foo.d");
  mkpath($test_dir);

  # Change to the test directory in order to create a relative path in the
  # symlink we need

  my $cwd = getcwd();
  unless (chdir($test_dir)) {
    die("Can't chdir to $test_dir: $!");
  }

  unless (symlink('./foo.d', './test.lnk')) {
    die("Can't symlink 'test.lnk' to './foo.d': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  if ($< == 0) {
    unless (chmod(0755, $sub_dir, $test_dir)) {
      die("Can't set perms on $test_dir to 0755: $!");
    }

    unless (chown($setup->{uid}, $setup->{gid}, $sub_dir, $test_dir)) {
      die("Can't set owner of $test_dir to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    AllowOverwrite => 'on',
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

      my $conn = $client->appe_raw('test.d/foo.d');
      if ($conn) {
        die("APPE succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $client->quit();

      my $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "test.d/foo.d: Not a regular file";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
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

sub appe_fails_login_required {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

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
      my ($resp_code, $resp_msg);

      my $path = $setup->{config_file};
      eval { ($resp_code, $resp_msg) = $client->appe($path, '/dev/null') };
      unless ($@) {
        die("APPE succeeded unexpectedly ($resp_code $resp_msg)");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      $client->quit();

      my $expected = 530;
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

sub appe_fails_no_path {
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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      $client->login($setup->{user}, $setup->{passwd});

      my ($resp_code, $resp_msg);

      my $path = $setup->{config_file};
      eval { ($resp_code, $resp_msg) = $client->appe($path, '') };
      unless ($@) {
        die("APPE succeeded unexpectedly ($resp_code $resp_msg)");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      $client->quit();

      my $expected = 500;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "'APPE' not understood";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
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

sub appe_fails_eperm {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $sub_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($sub_dir);

  my $src_file = File::Spec->rel2abs("$tmpdir/foo.txt");
  if (open(my $fh, "> $src_file")) {
    close($fh);

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/foo/bar.txt");

  if ($< == 0) {
    unless (chmod(0755, $sub_dir)) {
      die("Can't set perms on $sub_dir to 0755: $!");
    }
  
    unless (chown($setup->{uid}, $setup->{gid}, $sub_dir)) {
      die("Can't set owner of $sub_dir to $setup->{uid}/$setup->{gid}: $!");
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
      $client->port();

      chmod(0660, $sub_dir);

      my ($resp_code, $resp_msg);
      eval { ($resp_code, $resp_msg) = $client->appe($src_file, $dst_file) };
      unless ($@) {
        die("APPE succeeded unexpectedly ($resp_code $resp_msg)");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      $client->quit();

      my $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "$dst_file: Permission denied";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
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

sub appe_hiddenstores_bug4144 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $test_file = File::Spec->rel2abs("$tmpdir/bar");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    HiddenStores => 'on',

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

      my $conn = $client->appe_raw('bar');
      unless ($conn) {
        die("APPE failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected = 150;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      my $buf = "Foo!\n";
      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
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

  test_cleanup($setup->{log_file}, $ex);
}

1;
