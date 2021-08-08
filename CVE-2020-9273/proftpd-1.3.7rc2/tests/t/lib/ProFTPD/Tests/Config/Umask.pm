package ProFTPD::Tests::Config::Umask;

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
  umask_new_dir_mode => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  umask_new_dir_mode_subdir => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  umask_new_dir_mode_subdir_userowner_groupowner => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
#  return testsuite_get_runnable_tests($TESTS);
  return qw(
    umask_new_dir_mode_subdir
  );
}

sub umask_new_dir_mode {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");
  
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

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    Umask => '022 000',

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

      my ($resp_code, $resp_msg) = $client->mkd('test.d');

      $client->quit();

      my $expected;

      $expected = 257;
      $self->assert($resp_code == $expected,
        test_msg("Expected response code $expected, got $resp_code"));

      if ($^O eq 'darwin') {
        # Mac OSX hack
        $test_dir = '/private' . $test_dir;
      }

      $expected = "\"$test_dir\" - Directory successfully created";
      $self->assert($resp_msg eq $expected,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      my $dir_mode = sprintf("%lo", (stat($test_dir))[2] & 07777);
      $expected = '777';
      $self->assert($dir_mode eq $expected,
        test_msg("Expected directory mode '$expected', got '$dir_mode'"));
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

sub umask_new_dir_mode_subdir {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");
  
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

  my $sub_dir = File::Spec->rel2abs("$tmpdir/sub.d");
  mkpath($sub_dir);

  if ($^O eq 'darwin') {
    # Mac OSX hack
    $sub_dir = '/private' . $sub_dir;
  }

  my $test_dir = File::Spec->rel2abs("$sub_dir/test.d");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    Umask => '022',

    Directory => {
      $sub_dir => {
        Umask => '022 000',
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

      my ($resp_code, $resp_msg) = $client->cwd('sub.d');
    
      my $expected;

      $expected = 250;
      $self->assert($resp_code == $expected,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'CWD command successful';
      $self->assert($resp_msg eq $expected,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      ($resp_code, $resp_msg) = $client->mkd('test.d');

      $client->quit();

      $expected = 257;
      $self->assert($resp_code == $expected,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "\"$test_dir\" - Directory successfully created";
      $self->assert($resp_msg eq $expected,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      my $dir_mode = sprintf("%lo", (stat($test_dir))[2] & 07777);
      $expected = '777';
      $self->assert($dir_mode eq $expected,
        test_msg("Expected directory mode '$expected', got '$dir_mode'"));
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

sub umask_new_dir_mode_subdir_userowner_groupowner {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");
  
  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $file_owner = 'test';
  my $file_owner_uid = 200;
  my $file_owner_gid = 200;
  my $file_group = 'testgroup';

  my $sub_dir = File::Spec->rel2abs("$tmpdir/sub.d");
  mkpath($sub_dir);

  my $test_dir = File::Spec->rel2abs("$sub_dir/test.d");

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
  auth_user_write($auth_user_file, $file_owner, $passwd, $file_owner_uid,
    $file_owner_gid, $home_dir, '/bin/bash'); 
  auth_group_write($auth_group_file, $group, $gid, $user);
  auth_group_write($auth_group_file, $file_group, $file_owner_gid, $file_owner);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    Umask => '022',

    Directory => {
      $sub_dir => {
        UserOwner => $file_owner,
        GroupOwner => $file_group,
        Umask => '022 000',
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

      my ($resp_code, $resp_msg) = $client->cwd('sub.d');
    
      my $expected;

      $expected = 250;
      $self->assert($resp_code == $expected,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'CWD command successful';
      $self->assert($resp_msg eq $expected,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      ($resp_code, $resp_msg) = $client->mkd('test.d');

      $client->quit();

      $expected = 257;
      $self->assert($resp_code == $expected,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "\"$test_dir\" - Directory successfully created";
      $self->assert($resp_msg eq $expected,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      my $dir_mode = sprintf("%lo", (stat($test_dir))[2] & 07777);
      $expected = '777';
      $self->assert($dir_mode eq $expected,
        test_msg("Expected directory mode '$expected', got '$dir_mode'"));
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
