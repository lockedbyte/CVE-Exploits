package ProFTPD::Tests::Config::FactsOptions;

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
  # XXX All of these tests use relative symlink paths.  Also need
  # tests which use absolute symlink paths, in both chrooted and non-chrooted
  # flavors.

  factsoptions_use_slink_mlsd_rel_symlinked_file => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  factsoptions_use_slink_mlsd_rel_symlinked_dir => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  factsoptions_use_slink_mlst_rel_symlinked_file => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  factsoptions_use_slink_mlst_rel_symlinked_file_chrooted => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  factsoptions_use_slink_mlst_rel_symlinked_dir => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  factsoptions_use_slink_mlst_rel_symlinked_dir_chrooted => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub factsoptions_use_slink_mlsd_rel_symlinked_file {
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

  my $foo_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($foo_dir);

  my $test_file = File::Spec->rel2abs("$tmpdir/foo/test.txt");
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

    ShowSymlinks => 'on',
    FactsOptions => 'UseSlink',

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

      my $conn = $client->mlsd_raw('foo');
      unless ($conn) {
        die("MLSD failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 25);
      eval { $conn->close() };

      my $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^modify=\S+;perm=\S+;type=(\S+);unique=(\S+);UNIX\.group=\d+;UNIX\.mode=\d+;UNIX.owner=\d+; (.*?)$/) {
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
      # it's a symlink.  And since the UseSlink FactOption is used, the
      # type should include the target path.
      $expected = 'OS.unix=slink:(.*)?'; 
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

sub factsoptions_use_slink_mlsd_rel_symlinked_dir {
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

    ShowSymlinks => 'on',
    FactsOptions => 'UseSlink',

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

      my $conn = $client->mlsd_raw('foo');
      unless ($conn) {
        die("MLSD failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 25);
      eval { $conn->close() };

      my $res = {};
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^modify=\S+;perm=\S+;type=(\S+);unique=(\S+);UNIX\.group=\d+;UNIX\.mode=\d+;UNIX.owner=\d+; (.*?)$/) {
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
        test_msg("Expected '$expected', got '$got'"));

      # Since ShowSymlinks is on, the type for test.lnk should indicate that
      # it's a symlink.  And since the UseSlink FactOption is used, the
      # type should include the target path.
      $expected = 'OS.unix=slink:(.*)?'; 
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

sub factsoptions_use_slink_mlst_rel_symlinked_file {
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

  my $foo_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($foo_dir);

  my $test_file = File::Spec->rel2abs("$tmpdir/foo/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $test_symlink = File::Spec->rel2abs("$tmpdir/foo/test.lnk");

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

    ShowSymlinks => 'on',
    FactsOptions => 'UseSlink',

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

      my ($resp_code, $resp_msg) = $client->mlst('foo/test.lnk');

      my $expected;

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      if ($^O eq 'darwin') {
        # MacOSX-specific hack, due to how it handles tmp files
        $test_symlink = ('/private' . $test_symlink);
      }

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=OS\.unix=slink:(\S+);unique=\S+;UNIX.group=\d+;UNIX.mode=\d+;UNIX.owner=\d+; ' . $test_symlink . '$';
      $self->assert(qr/$expected/, $resp_msg,
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

sub factsoptions_use_slink_mlst_rel_symlinked_file_chrooted {
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

  my $foo_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($foo_dir);

  my $test_file = File::Spec->rel2abs("$tmpdir/foo/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  # Since we're chrooting the session, we don't expect to see the real
  # absolute path.
  my $test_symlink = "/foo/test.lnk";

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

    ShowSymlinks => 'on',
    FactsOptions => 'UseSlink',

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

      my ($resp_code, $resp_msg) = $client->mlst('foo/test.lnk');

      my $expected;

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=OS\.unix=slink:(\S+);unique=\S+;UNIX.group=\d+;UNIX.mode=\d+;UNIX.owner=\d+; ' . $test_symlink . '$';
      $self->assert(qr/$expected/, $resp_msg,
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

sub factsoptions_use_slink_mlst_rel_symlinked_dir {
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

  my $foo_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($foo_dir);

  my $test_dir = File::Spec->rel2abs("$tmpdir/foo/test.d");
  mkpath($test_dir);

  my $test_symlink = File::Spec->rel2abs("$tmpdir/foo/test.lnk");

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

    ShowSymlinks => 'on',
    FactsOptions => 'UseSlink',

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

      my ($resp_code, $resp_msg) = $client->mlst('foo/test.lnk');

      my $expected;

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      if ($^O eq 'darwin') {
        # MacOSX-specific hack, due to how it handles tmp files
        $test_symlink = ('/private' . $test_symlink);
      }

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=OS.unix=slink:(\S+);unique=\S+;UNIX.group=\d+;UNIX.mode=\d+;UNIX.owner=\d+; ' . $test_symlink . '$';
      $self->assert(qr/$expected/, $resp_msg,
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

sub factsoptions_use_slink_mlst_rel_symlinked_dir_chrooted {
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

  my $foo_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($foo_dir);

  my $test_dir = File::Spec->rel2abs("$tmpdir/foo/test.d");
  mkpath($test_dir);

  # Since we're chrooting the session, we don't expect to see the real
  # absolute path
  my $test_symlink = "/foo/test.lnk";

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

    ShowSymlinks => 'on',
    FactsOptions => 'UseSlink',

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

      my ($resp_code, $resp_msg) = $client->mlst('foo/test.lnk');

      my $expected;

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=OS\.unix=slink:(\S+);unique=\S+;UNIX.group=\d+;UNIX.mode=\d+;UNIX.owner=\d+; ' . $test_symlink . '$';
      $self->assert(qr/$expected/, $resp_msg,
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

1;
