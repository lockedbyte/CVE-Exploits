package ProFTPD::Tests::Config::DisplayConnect;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use File::Spec;
use IO::Handle;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  displayconnect_abs_path => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  displayconnect_rel_path => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  displayconnect_client_count => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  displayconnect_class_client_count => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  displayconnect_multiline => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  displayconnect_fs_vars => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  # XXX Add other tests with the various Display variables
};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub displayconnect_abs_path {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $connect_file = File::Spec->rel2abs("$tmpdir/connect.txt");

  if (open(my $fh, "> $connect_file")) {
    print $fh "Hello client!\n";

    unless (close($fh)) {
      die("Unable to write $connect_file: $!");
    }

  } else {
    die("Unable to open $connect_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DisplayConnect => $connect_file,

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

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg(0);

      my $expected;

      $expected = 220;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Hello client!";
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

sub displayconnect_rel_path {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $connect_file = 'connect.txt';

  # Turns out that when a relative DisplayConnect path is used, proftpd
  # looks for it in /, contrary to the docs.
  #
  # This is probably due to the fact that src/main.c:daemonize() does
  # a chdir("/").

  my $connect_path = "/$connect_file";

  if (open(my $fh, "> $connect_path")) {
    print $fh "Hello client!\n";

    unless (close($fh)) {
      die("Unable to write $connect_path: $!");
    }

  } else {
    die("Unable to open $connect_path: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DisplayConnect => $connect_file,

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

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg(0);

      my $expected;

      $expected = 220;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Hello client!";
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

  unlink($connect_path);

  # Stop server
  server_stop($pid_file);

  $self->assert_child_ok($pid);

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub displayconnect_client_count {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");

  my $connect_file = File::Spec->rel2abs("$tmpdir/connect.txt");

  if (open(my $fh, "> $connect_file")) {
    print $fh "Client count: %N\n";

    unless (close($fh)) {
      die("Unable to write $connect_file: $!");
    }

  } else {
    die("Unable to open $connect_file: $!");
  }

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

    DisplayConnect => $connect_file,

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
      my $client1 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client1->login($user, $passwd);

      my $client2 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      my ($resp_code, $resp_msg);

      $resp_code = $client2->response_code();
      $resp_msg = $client2->response_msg(0);

      my $expected;

      $expected = 220;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Client count: 2";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

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
    die($ex);
  }

  unlink($log_file);
}

sub displayconnect_class_client_count {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");

  my $connect_file = File::Spec->rel2abs("$tmpdir/connect.txt");

  if (open(my $fh, "> $connect_file")) {
    print $fh "Client count for class: %y\n";

    unless (close($fh)) {
      die("Unable to write $connect_file: $!");
    }

  } else {
    die("Unable to open $connect_file: $!");
  }

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

    DisplayConnect => $connect_file,

    Class => {
      test => {
        From => '127.0.0.1',
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
      my $client1 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client1->login($user, $passwd);

      my $client2 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      my ($resp_code, $resp_msg);

      $resp_code = $client2->response_code();
      $resp_msg = $client2->response_msg(0);

      my $expected;

      $expected = 220;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Client count for class: 1";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

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
    die($ex);
  }

  unlink($log_file);
}

sub displayconnect_multiline {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $connect_file = File::Spec->rel2abs("$tmpdir/connect.txt");

  if (open(my $fh, "> $connect_file")) {
    print $fh "Welcome to my domain\nThe files are restless today\nHello client!\n";

    unless (close($fh)) {
      die("Unable to write $connect_file: $!");
    }

  } else {
    die("Unable to open $connect_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    DisplayConnect => $connect_file,

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

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg(2);

      my $expected;

      $expected = 220;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = " Hello client!";
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

sub displayconnect_fs_vars {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'config');

  my $connect_file = File::Spec->rel2abs("$tmpdir/connect.txt");

  if (open(my $fh, "> $connect_file")) {
    print $fh "Hello client!\n";
    print $fh "Filesystem: %F %f\n";

    unless (close($fh)) {
      die("Unable to write $connect_file: $!");
    }

  } else {
    die("Unable to open $connect_file: $!");
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'fsio:20',

    DisplayConnect => $connect_file,

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
      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg(1);

      my $expected;

      $expected = 220;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'Filesystem: (\d+) (\S+)$';
      $self->assert(qr/$expected/, $resp_msg,
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
