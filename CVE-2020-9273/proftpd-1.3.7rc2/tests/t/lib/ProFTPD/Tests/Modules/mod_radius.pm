package ProFTPD::Tests::Modules::mod_radius;

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
  radius_auth => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  radius_acct => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  radius_acct_aborted_xfer_bug3278 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  radius_userinfo_var_u => {
    order => ++$order,
    test_class => [qw(forking)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub radius_auth {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/radius.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/radius.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/radius.scoreboard");

  my $log_file = test_get_logfile();

  my $user = $ENV{RADIUS_USER} ? $ENV{RADIUS_USER} : "proftpd";
  my $passwd = $ENV{RADIUS_PASSWD} ? $ENV{RADIUS_PASSWD} : "test";
  my $group = $ENV{RADIUS_GROUP} ? $ENV{RADIUS_GROUP} : 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 1000;
  my $gid = 1000;

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

      'mod_radius.c' => {
        RadiusEngine => 'on',
        RadiusLog => $log_file,
        RadiusAuthServer => "localhost:1812 testing123 5",
        RadiusUserInfo => "$uid $gid $home_dir /bin/bash",
        RadiusGroupInfo => "$group $user $gid",
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

  # Make sure that radiusd is running before running these tests, e.g.:
  #
  #  sudo /path/to/freeradius-dir/sbin/radiusd -X -f -xx

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);

      my ($resp_code, $resp_msg);
      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user logged in";
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

  server_stop($pid_file);

  $self->assert_child_ok($pid);

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub radius_acct {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/radius.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/radius.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/radius.scoreboard");

  my $log_file = test_get_logfile();

  my $user = $ENV{RADIUS_USER} ? $ENV{RADIUS_USER} : "proftpd";
  my $passwd = $ENV{RADIUS_PASSWD} ? $ENV{RADIUS_PASSWD} : "test";
  my $group = $ENV{RADIUS_GROUP} ? $ENV{RADIUS_GROUP} : 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 1000;
  my $gid = 1000;

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

      'mod_radius.c' => {
        RadiusEngine => 'on',
        RadiusLog => $log_file,
        RadiusAuthServer => "localhost:1812 testing123 5",
        RadiusAcctServer => "localhost:1813 testing123 5",
        RadiusUserInfo => "$uid $gid $home_dir /bin/bash",
        RadiusGroupInfo => "$group $user $gid",
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

  # Make sure that radiusd is running before running these tests, e.g.:
  #
  #  sudo /path/to/freeradius-dir/sbin/radiusd -X -f -xx

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);

      my ($resp_code, $resp_msg);
      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user logged in";
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

  server_stop($pid_file);

  $self->assert_child_ok($pid);

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub radius_acct_aborted_xfer_bug3278 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/radius.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/radius.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/radius.scoreboard");

  my $log_file = test_get_logfile();

  my $user = $ENV{RADIUS_USER} ? $ENV{RADIUS_USER} : "proftpd";
  my $passwd = $ENV{RADIUS_PASSWD} ? $ENV{RADIUS_PASSWD} : "test";
  my $group = $ENV{RADIUS_GROUP} ? $ENV{RADIUS_GROUP} : 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 1000;
  my $gid = 1000;

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

      'mod_radius.c' => {
        RadiusEngine => 'on',
        RadiusLog => $log_file,
        RadiusAuthServer => "localhost:1812 testing123 5",
        RadiusAcctServer => "localhost:1813 testing123 5",
        RadiusUserInfo => "$uid $gid $home_dir /bin/bash",
        RadiusGroupInfo => "$group $user $gid",
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

  # Make sure that radiusd is running before running these tests, e.g.:
  #
  #  sudo /path/to/freeradius-dir/sbin/radiusd -X -f -xx

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);

      my ($resp_code, $resp_msg);
      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user logged in";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      my $conn = $client->stor_raw('test.txt');
      unless ($conn) {
        die("Failed to STOR test.txt: " . $client->response_code() . " " .
          $client->response_msg());
      }

      for (my $i = 0; $i < 1000; $i++) {
        my $buf = "ABCD" x 1024;
        $conn->write($buf, length($buf));
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

  server_stop($pid_file);

  $self->assert_child_ok($pid);

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub radius_userinfo_var_u {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/radius.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/radius.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/radius.scoreboard");

  my $log_file = test_get_logfile();

  my $user = $ENV{RADIUS_USER} ? $ENV{RADIUS_USER} : "proftpd";
  my $passwd = $ENV{RADIUS_PASSWD} ? $ENV{RADIUS_PASSWD} : "test";
  my $group = $ENV{RADIUS_GROUP} ? $ENV{RADIUS_GROUP} : 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 1000;
  my $gid = 1000;

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

      'mod_radius.c' => {
        RadiusEngine => 'on',
        RadiusLog => $log_file,
        RadiusAuthServer => "localhost:1812 testing123 5",
        RadiusUserInfo => "$uid $gid /home/%u /bin/bash",
        RadiusGroupInfo => "$group $user $gid",
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

  # Make sure that radiusd is running before running these tests, e.g.:
  #
  #  sudo /path/to/freeradius-dir/sbin/radiusd -X -f -xx

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);

      my ($resp_code, $resp_msg);
      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user logged in";
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
