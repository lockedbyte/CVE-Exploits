package ProFTPD::Tests::Config::DirFakeGroup;

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
  dirfakegroup_list => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  dirfakegroup_mlsd_bug3604 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  dirfakegroup_mlst_bug3604 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  dirfakegroup_mlsd_bug3715 => {
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

sub dirfakegroup_list {
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

  my $fake_group = 'foo';

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    DirFakeGroup => "on $fake_group",

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
        die("Failed to LIST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 16384, 25);
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
        if ($line =~ /^\S+\s+\d+\s+\S+\s+(\S+)\s+.*?\s+(\S+)$/) {
          $res->{$2} = $1;
        }
      }

      my $expected = {
        'config.conf' => $fake_group,
        'config.group' => $fake_group,
        'config.passwd' => $fake_group,
        'config.pid' => $fake_group,
        'config.scoreboard' => $fake_group,
        'config.scoreboard.lck' => $fake_group,
      };

      my $file_ok = 1;
      my $owner_ok = 1;

      my $mismatch;
      foreach my $name (keys(%$res)) {
        unless (defined($expected->{$name})) {
          $mismatch = $name;
          $file_ok = 0;
          last;
        }

        unless ($res->{$name} eq $expected->{$name}) {
          $mismatch = "$name: $res->{$name}";
          $owner_ok = 0;
          last;
        }
      }

      unless ($file_ok) {
        die("Unexpected name '$mismatch' appeared in LIST data")
      }

      unless ($owner_ok) {
        die("Unexpected group owner '$mismatch' appeared in LIST data")
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

sub dirfakegroup_mlsd_bug3604 {
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

  my $fake_group = 'foo';
  my $fake_gid = 2476;

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
  auth_group_write($auth_group_file, $fake_group, $fake_gid);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    DirFakeGroup => "on $fake_group",

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

      my $conn = $client->mlsd_raw();
      unless ($conn) {
        die("Failed to MLSD: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 16384, 25);
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
        if ($line =~ /^modify=\S+;perm=\S+;type=\S+;unique=\S+;UNIX\.group=(\d+);UNIX\.mode=\d+;UNIX.owner=\d+; (.*?)$/) {
          $res->{$2} = $1;
        }
      }

      my $expected = {
        '.' => $fake_gid,
        '..' => $fake_gid,
        'config.conf' => $fake_gid,
        'config.group' => $fake_gid,
        'config.passwd' => $fake_gid,
        'config.pid' => $fake_gid,
        'config.scoreboard' => $fake_gid,
        'config.scoreboard.lck' => $fake_gid,
      };

      my $file_ok = 1;
      my $owner_ok = 1;

      my $mismatch;
      foreach my $name (keys(%$res)) {
        unless (defined($expected->{$name})) {
          $mismatch = $name;
          $file_ok = 0;
          last;
        }

        unless ($res->{$name} == $expected->{$name}) {
          $mismatch = "$name: $res->{$name}";
          $owner_ok = 0;
          last;
        }
      }

      unless ($file_ok) {
        die("Unexpected name '$mismatch' appeared in LIST data")
      }

      unless ($owner_ok) {
        die("Unexpected GID owner '$mismatch' appeared in LIST data")
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

sub dirfakegroup_mlst_bug3604 {
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

  my $fake_group = 'foo';
  my $fake_gid = 2476;

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
  auth_group_write($auth_group_file, $fake_group, $fake_gid);

  my $test_file = File::Spec->rel2abs($config_file);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    DirFakeGroup => "on $fake_group",

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
      ($resp_code, $resp_msg) = $client->mlst('config.conf');

      my $expected;

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=file;unique=\S+;UNIX.group=(\d+);UNIX.mode=\d+;UNIX.owner=\d+; (.*?)\/config\.conf$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $client->quit();

      $resp_msg =~ /$expected/;
      my $file_gid = $2;

      $self->assert($file_gid == $fake_gid,
        test_msg("Expected $fake_gid, got $file_gid"));
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

sub dirfakegroup_mlsd_bug3715 {
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

  my $expected_gid = $(;

  # On some systems, $( returns a space-delimited list of GIDs.
  if ($expected_gid !~ /^\d+$/) {
    my $gids = [split(' ', $()];
    $expected_gid = $gids->[0];
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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    AuthOrder => 'mod_auth_file.c',

    DirFakeGroup => "off",

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

      my $conn = $client->mlsd_raw();
      unless ($conn) {
        die("Failed to MLSD: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 16384, 25);
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
        if ($line =~ /^modify=\S+;perm=\S+;type=\S+;unique=\S+;UNIX\.group=(\d+);UNIX\.mode=\d+;UNIX.owner=\d+; (.*?)$/) {
          $res->{$2} = $1;
        }
      }

      # Remove the '.' and '..' entries; they are relevant to this test.
      delete($res->{'.'});
      delete($res->{'..'});

      my $expected = {
        'config.conf' => $expected_gid,
        'config.group' => $expected_gid,
        'config.passwd' => $expected_gid,
        'config.pid' => $expected_gid,
        'config.scoreboard' => $expected_gid,
        'config.scoreboard.lck' => $expected_gid,
      };

      my $file_ok = 1;
      my $owner_ok = 1;

      my $mismatch;
      foreach my $name (keys(%$res)) {
        unless (defined($expected->{$name})) {
          $mismatch = $name;
          $file_ok = 0;
          last;
        }

        unless ($res->{$name} == $expected->{$name}) {
          $mismatch = "$name: $res->{$name}";
          $owner_ok = 0;
          last;
        }
      }

      unless ($file_ok) {
        die("Unexpected name '$mismatch' appeared in LIST data")
      }

      unless ($owner_ok) {
        die("Unexpected GID owner '$mismatch' appeared in LIST data")
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

1;
