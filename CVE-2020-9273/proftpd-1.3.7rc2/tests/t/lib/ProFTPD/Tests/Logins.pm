package ProFTPD::Tests::Logins;

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
  login_plaintext_fails_bad_password => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  login_plaintext_fails_empty_password_bug4139 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  login_anonymous_ok => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  login_anonymous_with_delay_ok => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  login_anonymous_user_alias_ok => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  login_anonymous_fails_bad_perms => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  login_anonymous_fails_empty_password_bug4139 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  login_anonymous_symlink_dir_ok => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  login_anonymous_allowchrootsymlinks_bug3852 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  login_multiple_attempts_per_conn => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  login_regular_with_anon_defined_bug3307 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  login_fails_bad_sequence => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  login_reauthenticate_fails_bug3736 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  login_reauthenticate_ok_same_user_bug4217 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  login_reauthenticate_fails_different_user_bug4217 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  login_reauthenticate_fails_extra_pass_bug4217 => {
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

sub login_plaintext_fails_bad_password {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/login.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/login.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/login.scoreboard");

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

  my ($port, $user, $group) = config_write($config_file, $config);

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

      # In parent process, login to server using a plaintext password which
      # should NOT work.
      eval { $client->login('daemon', '*') };
      unless ($@) {
        die("Logged in unexpectedly");
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

sub login_plaintext_fails_empty_password_bug4139 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/login.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/login.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/login.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/login.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/login.group");

  my $user = 'proftpd';
  my $passwd = '';
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

    AllowEmptyPasswords => 'off',

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
      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Logged in unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 501;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'Login incorrect.';
      $self->assert($expected eq $resp_msg,
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

  unlink($log_file);
}

sub login_anonymous_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/login.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/login.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/login.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/login.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/login.group");

  my ($config_user, $config_group) = config_get_identity();

  my $anon_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $anon_dir)) {
      die("Can't set perms on $anon_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $anon_dir)) {
      die("Can't set owner of $anon_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $config_user, 'foo', $uid, $gid,
    '/tmp', '/bin/bash');
  auth_group_write($auth_group_file, $config_group, $gid, $config_user);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 privs:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },

    Anonymous => {
      $anon_dir => {
        User => $config_user,
        Group => $config_group,
        UserAlias => "anonymous $config_user",
        RequireValidShell => 'off',
      },
    },
  };

  my ($port, $user, $group) = config_write($config_file, $config);

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

      # In parent process, login anonymously to server using a plaintext
      # password which SHOULD work.
      my ($resp_code, $resp_msg) = $client->login($config_user, 'ftp@nospam.org');

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'Anonymous access granted, restrictions apply';
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

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

sub login_anonymous_with_delay_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/login.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/login.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/login.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/login.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/login.group");

  my ($config_user, $config_group) = config_get_identity();

  my $anon_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $anon_dir)) {
      die("Can't set perms on $anon_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $anon_dir)) {
      die("Can't set owner of $anon_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $config_user, 'foo', $uid, $gid,
    '/tmp', '/bin/bash');
  auth_group_write($auth_group_file, $config_group, $gid, $config_user);

  my $delay_tab = File::Spec->rel2abs("$tmpdir/delay.tab");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 privs:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayTable => $delay_tab,
      },
    },

    Anonymous => {
      $anon_dir => {
        User => $config_user,
        Group => $config_group,
        UserAlias => "anonymous $config_user",
        RequireValidShell => 'off',
      },
    },
  };

  my ($port, $user, $group) = config_write($config_file, $config);

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

      # In parent process, login anonymously to server using a plaintext
      # password which SHOULD work.
      my ($resp_code, $resp_msg) = $client->login($config_user, 'ftp@nospam.org');

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'Anonymous access granted, restrictions apply';
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

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

sub login_anonymous_user_alias_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/login.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/login.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/login.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/login.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/login.group");

  my ($config_user, $config_group) = config_get_identity();

  my $anon_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $anon_dir)) {
      die("Can't set perms on $anon_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $anon_dir)) {
      die("Can't set owner of $anon_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $config_user, 'foo', $uid, $gid,
    '/tmp', '/bin/bash');
  auth_group_write($auth_group_file, $config_group, $gid, $config_user);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 privs:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },

    Anonymous => {
      $anon_dir => {
        User => $config_user,
        Group => $config_group,
        UserAlias => "anonymous $config_user",
        RequireValidShell => 'off',
      },
    },
  };

  my ($port, $user, $group) = config_write($config_file, $config);

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

      # In parent process, login anonymously to server using a plaintext
      # password which SHOULD work.
      my ($resp_code, $resp_msg) = $client->login('anonymous', 'ftp@nospam.org');

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'Anonymous access granted, restrictions apply';
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

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

sub login_anonymous_fails_bad_perms {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/login.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/login.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/login.scoreboard");

  my $log_file = test_get_logfile();

  my $anon_dir = File::Spec->rel2abs($tmpdir);

  my ($user, $group) = config_get_identity();

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },

    Anonymous => {
      $anon_dir => {
        User => $user,
        Group => $group,
        UserAlias => "anonymous $user",
        RequireValidShell => 'off',
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

      my $perms = (stat($anon_dir))[2];
      chmod(0660, $anon_dir);

      eval { $client->login('anonymous', 'ftp@nospam.org') };
      unless ($@) {
        die("Unexpectedly logged in anonymously");
      }

      chmod($perms, $anon_dir);
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

sub login_anonymous_fails_empty_password_bug4139 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/login.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/login.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/login.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/login.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/login.group");

  my ($config_user, $config_group) = config_get_identity();

  my $anon_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $anon_dir)) {
      die("Can't set perms on $anon_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $anon_dir)) {
      die("Can't set owner of $anon_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $config_user, 'foo', $uid, $gid,
    '/tmp', '/bin/bash');
  auth_group_write($auth_group_file, $config_group, $gid, $config_user);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 privs:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },

    Anonymous => {
      $anon_dir => {
        User => $config_user,
        Group => $config_group,
        UserAlias => "anonymous $config_user",
        RequireValidShell => 'off',
        AllowEmptyPasswords => 'off',
      },
    },
  };

  my ($port, $user, $group) = config_write($config_file, $config);

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
      eval { $client->login($config_user, '') };
      unless ($@) {
        die("Anonymous login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 501;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'Login incorrect.';
      $self->assert($expected eq $resp_msg,
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

  unlink($log_file);
}

sub login_anonymous_symlink_dir_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/login.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/login.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/login.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/login.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/login.group");

  my ($config_user, $config_group) = config_get_identity();

  my $anon_dir = File::Spec->rel2abs("$tmpdir/users/anonymous");
  my $uid = 500;
  my $gid = 500;

  my $intermed_dir = File::Spec->rel2abs("$tmpdir/users");
  mkpath($intermed_dir);

  my $symlink_dst = File::Spec->rel2abs("$tmpdir/public_ftp");
  mkpath($symlink_dst);

  my $cwd = getcwd();

  unless (chdir($intermed_dir)) {
    die("Can't chdir to $intermed_dir: $!");
  }

  unless (symlink("../public_ftp", "./anonymous")) {
    die("Can't symlink '../public_ftp' to './anonymous': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $symlink_dst)) {
      die("Can't set perms on $symlink_dst to 0755: $!");
    }

    unless (chown($uid, $gid, $symlink_dst)) {
      die("Can't set owner of $symlink_dst to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $config_user, 'foo', $uid, $gid,
    '/tmp', '/bin/bash');
  auth_group_write($auth_group_file, $config_group, $gid, $config_user);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 privs:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },

    Anonymous => {
      $anon_dir => {
        User => $config_user,
        Group => $config_group,
        UserAlias => "anonymous $config_user",
        RequireValidShell => 'off',
      },
    },
  };

  my ($port, $user, $group) = config_write($config_file, $config);

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

      # In parent process, login anonymously to server using a plaintext
      # password which SHOULD work.
      my ($resp_code, $resp_msg) = $client->login($config_user, 'ftp@nospam.org');

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'Anonymous access granted, restrictions apply';
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

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

sub login_anonymous_allowchrootsymlinks_bug3852 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/login.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/login.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/login.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/login.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/login.group");

  my ($config_user, $config_group) = config_get_identity();

  my $anon_dir = File::Spec->rel2abs("$tmpdir/users/anonymous");
  my $uid = 500;
  my $gid = 500;

  my $intermed_dir = File::Spec->rel2abs("$tmpdir/users");
  mkpath($intermed_dir);

  my $symlink_dst = File::Spec->rel2abs("$tmpdir/public_ftp");
  mkpath($symlink_dst);

  my $cwd = getcwd();

  unless (chdir($intermed_dir)) {
    die("Can't chdir to $intermed_dir: $!");
  }

  unless (symlink("../public_ftp", "./anonymous")) {
    die("Can't symlink '../public_ftp' to './anonymous': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $symlink_dst)) {
      die("Can't set perms on $symlink_dst to 0755: $!");
    }

    unless (chown($uid, $gid, $symlink_dst)) {
      die("Can't set owner of $symlink_dst to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $config_user, 'foo', $uid, $gid,
    '/tmp', '/bin/bash');
  auth_group_write($auth_group_file, $config_group, $gid, $config_user);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    AllowChrootSymlinks => 'off',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },

    Anonymous => {
      $anon_dir => {
        User => $config_user,
        Group => $config_group,
        UserAlias => "anonymous $config_user",
        RequireValidShell => 'off',
      },
    },
  };

  my ($port, $user, $group) = config_write($config_file, $config);

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
      eval { $client->login($config_user, 'ftp@nospam.org') };
      unless ($@) {
        die("Anonymous login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'Login incorrect.';
      $self->assert($expected eq $resp_msg,
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

  unlink($log_file);
}

sub login_multiple_attempts_per_conn {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/login.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/login.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/login.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/login.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/login.group");

  my $test_file = File::Spec->rel2abs($config_file);

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
      eval { $client->login($user, 'foo') };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

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

sub login_regular_with_anon_defined_bug3307 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/login.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/login.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/login.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/login.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/login.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my ($config_user, $config_group) = config_get_identity();

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    Anonymous => {
      $home_dir => {
        User => $config_user,
        Group => $config_group,
        RequireValidShell => 'off',
        UserAlias => "anonymous $config_user",
      },
    },

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my $port;
  ($port, $config_user, $config_group) = config_write($config_file, $config);

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

      my ($resp_code, $resp_msg) = $client->user($user);

      my $expected;

      $expected = 331;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Password required for $user";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

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

sub login_fails_bad_sequence {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/login.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/login.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/login.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/login.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/login.group");

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
      $client->user($user);

      eval { $client->pwd() };
      unless ($@) {
        die("PWD after USER succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

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

sub login_reauthenticate_fails_bug3736 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'login');

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($setup->{user}, $setup->{passwd});

      my $other_user = 'foobar';
      eval { $client->user($other_user) };
      unless ($@) {
        die("Subsequent USER command succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected = 501;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Reauthentication not supported";
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

sub login_reauthenticate_ok_same_user_bug4217 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'login');

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($setup->{user}, $setup->{passwd});

      my ($resp_code, $resp_msg) = $client->user($setup->{user});
      my $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "User $setup->{user} logged in";
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

sub login_reauthenticate_fails_different_user_bug4217 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'login');

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($setup->{user}, $setup->{passwd});

      my $bad_user = "foobar";
      eval { $client->user($bad_user) };
      unless ($@) {
        die("Subsequent USER with different name succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected = 501;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Reauthentication not supported";
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

sub login_reauthenticate_fails_extra_pass_bug4217 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'login');

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($setup->{user}, $setup->{passwd});

      # We can't use login() here, since that will properly handle the 230
      # response from the USER command.
      $client->user($setup->{user});
      eval { $client->pass($setup->{passwd}) };
      unless ($@) {
        die("Subsequent PASS succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected = 503;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "You are already logged in";
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

1;
