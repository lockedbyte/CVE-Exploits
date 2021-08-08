package ProFTPD::Tests::Config::CreateHome;

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
  createhome_ok => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  createhome_dirmode_ok => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  createhome_explicit_parent_owner_ok => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  createhome_user_parent_owner_ok => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  createhome_skel_ok => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  createhome_homegid_bug3503 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  createhome_dirmode_uid_gid_ok => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  createhome_dirmode_uid_gid_norootprivs_bug3813 => {
    order => ++$order,
    test_class => [qw(bug forking norootprivs)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub createhome_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");
  
  my $user = 'proftpd';
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs("$tmpdir/foo/bar");
  my $uid = 500;
  my $gid = 500;

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash'); 
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    CreateHome => 'on',

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

  # Check that the home directory exists, and that the parent directory
  # of $tmpdir/foo is owned by UID/GID root.
  $self->assert(-d $home_dir,
    test_msg("Expected $home_dir directory to exist"));

  my $parent_dir = "$tmpdir/foo";
  my ($uid_owner, $gid_owner) = (stat($parent_dir))[4,5];

  my $expected = 0;
  $self->assert($expected == $uid_owner,
    test_msg("Expected $expected, got $uid_owner"));
  $self->assert($expected == $gid_owner,
    test_msg("Expected $expected, got $gid_owner"));

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub createhome_dirmode_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");
  
  my $user = 'proftpd';
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs("$tmpdir/foo/bar");
  my $uid = 500;
  my $gid = 500;

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash'); 
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    CreateHome => 'on 711 dirmode 755',

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

  # Check that the home directory exists, and that the parent directory
  # of $tmpdir/foo is owned by UID/GID root.
  $self->assert(-d $home_dir,
    test_msg("Expected $home_dir directory to exist"));

  my $parent_dir = "$tmpdir/foo";
  my ($uid_owner, $gid_owner) = (stat($parent_dir))[4,5];

  my $expected = 0;
  $self->assert($expected == $uid_owner,
    test_msg("Expected $expected, got $uid_owner"));
  $self->assert($expected == $gid_owner,
    test_msg("Expected $expected, got $gid_owner"));

  # Make sure that the permissions on the directories match the expected modes
  my $mode = sprintf("%04o", (stat($home_dir))[2] & 07777);

  $expected = '0711';
  $self->assert($expected eq $mode,
    test_msg("Expected '$expected', got '$mode'"));

  $mode = sprintf("%04o", (stat("$tmpdir/foo"))[2] & 07777);

  $expected = '0755';
  $self->assert($expected eq $mode,
    test_msg("Expected '$expected', got '$mode'"));

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub createhome_explicit_parent_owner_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");
  
  my $user = 'proftpd';
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs("$tmpdir/foo/bar");
  my $uid = 500;
  my $gid = 500;

  my $explicit_guid = 250;

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash'); 
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    CreateHome => "on 711 uid $explicit_guid gid $explicit_guid",

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

  # Check that the home directory exists, and that the parent directory
  # of $tmpdir/foo is owned by UID/GID root.
  $self->assert(-d $home_dir,
    test_msg("Expected $home_dir directory to exist"));

  my $parent_dir = "$tmpdir/foo";
  my ($uid_owner, $gid_owner) = (stat($parent_dir))[4,5];

  my $expected = $explicit_guid;
  $self->assert($expected == $uid_owner,
    test_msg("Expected $expected, got $uid_owner"));
  $self->assert($expected == $gid_owner,
    test_msg("Expected $expected, got $gid_owner"));

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub createhome_user_parent_owner_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");
  
  my $user = 'proftpd';
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs("$tmpdir/foo/bar");
  my $uid = 500;
  my $gid = 500;

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash'); 
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    CreateHome => "on 711 uid ~ gid ~",

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

  # Check that the home directory exists, and that the parent directory
  # of $tmpdir/foo is owned by UID/GID root.
  $self->assert(-d $home_dir,
    test_msg("Expected $home_dir directory to exist"));

  my $parent_dir = "$tmpdir/foo";
  my ($uid_owner, $gid_owner) = (stat($parent_dir))[4,5];

  my $expected = $uid;
  $self->assert($expected == $uid_owner,
    test_msg("Expected $expected, got $uid_owner"));

  $expected = $gid;
  $self->assert($expected == $gid_owner,
    test_msg("Expected $expected, got $gid_owner"));

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub createhome_skel_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");
  
  my $user = 'proftpd';
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs("$tmpdir/foo/bar");
  my $uid = 500;
  my $gid = 500;

  my $skel = File::Spec->rel2abs("$tmpdir/skel");
  mkpath($skel);

  my $skel_file = File::Spec->rel2abs("$skel/welcome.txt");
  if (open(my $fh, "> $skel_file")) {
    print $fh "Welcome, new user.\n";

    unless (close($fh)) {
      die("Can't write $skel_file: $!");
    }

  } else {
    die("Can't open $skel_file: $!");
  }

  my $skel_sub = File::Spec->rel2abs("$skel/subdir");
  mkpath($skel_sub);

  $skel_file = File::Spec->rel2abs("$skel_sub/test.txt");
  if (open(my $fh, "> $skel_file")) {
    print $fh "More test file stuff.\n";

    unless (close($fh)) {
      die("Can't write $skel_file: $!");
    }

  } else {
    die("Can't open $skel_file: $!");
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

    CreateHome => "on skel $skel",

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

  # Check that the home directory exists, and that it contains the
  # skeleton dirs/files.
  $self->assert(-d $home_dir,
    test_msg("Expected '$home_dir' directory to exist"));

  $self->assert(-d "$home_dir/subdir",
    test_msg("Expected '$home_dir/subdir' directory to exist"));

  $self->assert(-f "$home_dir/welcome.txt",
    test_msg("Expected '$home_dir/welcome.txt' file to exist"));

  $self->assert(-f "$home_dir/subdir/test.txt",
    test_msg("Expected '$home_dir/subdir/test.txt' file to exist"));

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub createhome_homegid_bug3503 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");
  
  my $user = 'proftpd';
  my $passwd = 'test';
  my $home_dir = File::Spec->rel2abs("$tmpdir/foo/bar");
  my $uid = 500;
  my $gid = 500;

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash'); 
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $home_gid = 777;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    CreateHome => "on 711 homegid $home_gid",

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

  # Check that the home directory exists, and that the home directory
  # of $tmpdir/foo/bar is owned by root UID and configured GID.
  $self->assert(-d $home_dir,
    test_msg("Expected $home_dir directory to exist"));

  my ($uid_owner, $gid_owner) = (stat($home_dir))[4,5];

  my $expected = $uid;
  $self->assert($expected == $uid_owner,
    test_msg("Expected $expected, got $uid_owner"));

  $expected = $home_gid;
  $self->assert($expected == $gid_owner,
    test_msg("Expected $expected, got $gid_owner"));

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub createhome_dirmode_uid_gid_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");
  
  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs("$tmpdir/foo/bar");
  my $uid = 500;
  my $gid = 500;

  my $explicit_guid = 250;

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash'); 
  auth_group_write($auth_group_file, $group, $gid, $user);

  # Trying to debug:
  #
  #  http://forums.proftpd.org/smf/index.php/topic,5534.0.html

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    CreateHome => "on 700 dirmode 700 uid ~ gid ~",

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

  # Check that the home directory exists, and that the parent directory
  # of $tmpdir/foo is owned by UID/GID root.
  $self->assert(-d $home_dir,
    test_msg("Expected $home_dir directory to exist"));

  my $parent_dir = "$tmpdir/foo";
  my ($uid_owner, $gid_owner) = (stat($parent_dir))[4,5];

  my $expected = $uid;
  $self->assert($expected == $uid_owner,
    test_msg("Expected $expected, got $uid_owner"));

  $expected = $gid;
  $self->assert($expected == $gid_owner,
    test_msg("Expected $expected, got $gid_owner"));

  # Make sure that the permissions on the directories match the expected modes
  my $mode = sprintf("%04o", (stat($home_dir))[2] & 07777);

  $expected = '0700';
  $self->assert($expected eq $mode,
    test_msg("Expected '$expected', got '$mode'"));

  $mode = sprintf("%04o", (stat("$tmpdir/foo"))[2] & 07777);

  $expected = '0700';
  $self->assert($expected eq $mode,
    test_msg("Expected '$expected', got '$mode'"));

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub createhome_dirmode_uid_gid_norootprivs_bug3813 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");
  
  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs("$tmpdir/foo/bar");
  my $uid = 500;
  my $gid = 500;

  my $explicit_guid = 250;

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash'); 
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    CreateHome => "on 700 dirmode 700 uid ~ gid ~ NoRootPrivs",

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

  # Check that the home directory exists, and that the parent directory
  # of $tmpdir/foo is owned by UID/GID root.
  $self->assert(-d $home_dir,
    test_msg("Expected $home_dir directory to exist"));

  my $parent_dir = "$tmpdir/foo";
  my ($uid_owner, $gid_owner) = (stat($parent_dir))[4,5];

  my $expected = $<;
  $self->assert($expected == $uid_owner,
    test_msg("Expected $expected, got $uid_owner"));

  $expected = $(;
  $self->assert($expected == $gid_owner,
    test_msg("Expected $expected, got $gid_owner"));

  # Make sure that the permissions on the directories match the expected modes
  my $mode = sprintf("%04o", (stat($home_dir))[2] & 07777);

  $expected = '0700';
  $self->assert($expected eq $mode,
    test_msg("Expected '$expected', got '$mode'"));

  $mode = sprintf("%04o", (stat("$tmpdir/foo"))[2] & 07777);

  $expected = '0700';
  $self->assert($expected eq $mode,
    test_msg("Expected '$expected', got '$mode'"));

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

1;
