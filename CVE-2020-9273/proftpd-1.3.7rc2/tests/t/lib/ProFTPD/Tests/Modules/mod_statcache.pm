package ProFTPD::Tests::Modules::mod_statcache;

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
  statcache_file => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  statcache_file_chrooted => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  statcache_file_tilde => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  statcache_dir => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  statcache_dir_chrooted => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  statcache_rel_symlink_file => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  statcache_rel_symlink_file_chrooted => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  statcache_rel_symlink_dir => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  statcache_rel_symlink_dir_chrooted => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  statcache_config_max_age => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  statcache_config_capacity => {
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

sub statcache_file {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'statcache');

  my $test_file = File::Spec->rel2abs("$setup->{home_dir}/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $statcache_tab = File::Spec->rel2abs("$tmpdir/statcache.tab");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'fsio:10 statcache:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_statcache.c' => {
        StatCacheEngine => 'on',
        StatCacheTable => $statcache_tab,
      },

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
      sleep(1);
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($setup->{user}, $setup->{passwd});
      my ($resp_code, $resp_msg) = $client->mlst('test.txt');

      my $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=file;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/.*\/test\.txt$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      # Do the MLST again; we'll check the logs to see if mod_statcache
      # did its job.
      $resp_code = $resp_msg = undef;
      ($resp_code, $resp_msg) = $client->mlst('test.txt');

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=file;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/.*\/test\.txt$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      $client->quit();

      # Now connect again, do another MLST, and see if we're still using
      # the cached entry.
      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($setup->{user}, $setup->{passwd});
      ($resp_code, $resp_msg) = $client->mlst('test.txt');

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=file;unique=\S+;UNIX\.group=\d+;UNIX\.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/.*\/test\.txt$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

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

  eval {
    if (open(my $fh, "< $setup->{log_file}")) {
      my $adding_entry = 0;
      my $cached_stat = 0;
      my $cached_lstat = 0;

      if ($^O eq 'darwin') {
        # MacOSX-specific hack
        $test_file = '/private' . $test_file;
      }

      while (my $line = <$fh>) {
        chomp($line);

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "# line: $line\n";
        }

        if ($line =~ /<statcache:9>/) {
          if ($line =~ /adding entry.*?type file/) {
            $adding_entry++;
            next;
          }
        }

        if ($line =~ /<statcache:11>/) {
          if ($cached_stat == 0 &&
              $line =~ /using cached stat.*?path '$test_file'/) {
            $cached_stat++;
            next;
          }

          if ($cached_lstat == 0 &&
              $line =~ /using cached lstat.*?path '$test_file'/) {
            $cached_lstat++;
            next;
          }
        }

        if ($adding_entry >= 2 &&
            $cached_stat == 1 &&
            $cached_lstat == 1) {
          last;
        }
      }

      close($fh);

      $self->assert($adding_entry >= 2 &&
                    $cached_stat == 1 &&
                    $cached_lstat == 1,
        test_msg("Did not see expected 'statcache' TraceLog messages"));

    } else {
      die("Can't read $setup->{log_file}: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub statcache_file_chrooted {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/statcache.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/statcache.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/statcache.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/statcache.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/statcache.group");

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

  my $test_file = File::Spec->rel2abs("$home_dir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $statcache_tab = File::Spec->rel2abs("$tmpdir/statcache.tab");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'fsio:10 statcache:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    DefaultRoot => '~',

    IfModules => {
      'mod_statcache.c' => {
        StatCacheEngine => 'on',
        StatCacheTable => $statcache_tab,
      },

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
      my ($resp_code, $resp_msg) = $client->mlst('test.txt');

      my $expected;

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=file;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/test\.txt$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      # Do the MLST again; we'll check the logs to see if mod_statcache
      # did its job.
      $resp_code = $resp_msg = undef;
      ($resp_code, $resp_msg) = $client->mlst('test.txt');

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=file;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/test\.txt$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      $client->quit();

      # Now connect again, do another MLST, and see if we're still using
      # the cached entry.
      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);
      ($resp_code, $resp_msg) = $client->mlst('test.txt');

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=file;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/test\.txt$';
      $self->assert(qr/$expected/, $resp_msg,
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

  eval {
    if (open(my $fh, "< $log_file")) {
      my $adding_entry = 0;
      my $cached_stat = 0;
      my $cached_lstat = 0;

      # Since we're chrooted, the expected path is now different.
      $test_file = '/test.txt';

      while (my $line = <$fh>) {
        if ($line =~ /<statcache:9>/) {
          if ($line =~ /adding entry.*?type file/) {
            $adding_entry++;
            next;
          }
        }

        if ($line =~ /<statcache:11>/) {
          if ($cached_stat == 0 &&
              $line =~ /using cached stat.*?path '$test_file'/) {
            $cached_stat++;
            next;
          }

          if ($cached_lstat == 0 &&
              $line =~ /using cached lstat.*?path '$test_file'/) {
            $cached_lstat++;
            next;
          }
        }

        if ($adding_entry >= 2 &&
            $cached_stat == 1 &&
            $cached_lstat == 1) {
          last;
        }
      }

      close($fh);

      $self->assert($adding_entry >= 2 &&
                    $cached_stat == 1 &&
                    $cached_lstat == 1,
        test_msg("Did not see expected 'statcache' TraceLog messages"));

    } else {
      die("Can't read $log_file: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub statcache_file_tilde {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/statcache.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/statcache.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/statcache.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/statcache.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/statcache.group");

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

  my $test_file = File::Spec->rel2abs("$home_dir/~test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $statcache_tab = File::Spec->rel2abs("$tmpdir/statcache.tab");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'fsio:10 statcache:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_statcache.c' => {
        StatCacheEngine => 'on',
        StatCacheTable => $statcache_tab,
      },

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
      my ($resp_code, $resp_msg) = $client->mlst('~test.txt');

      my $expected;

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=file;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/.*\/~test\.txt$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      # Do the MLST again; we'll check the logs to see if mod_statcache
      # did its job.
      $resp_code = $resp_msg = undef;
      ($resp_code, $resp_msg) = $client->mlst('~test.txt');

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=file;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/.*\/~test\.txt$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      $client->quit();

      # Now connect again, do another MLST, and see if we're still using
      # the cached entry.
      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);
      ($resp_code, $resp_msg) = $client->mlst('~test.txt');

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=file;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/.*\/~test\.txt$';
      $self->assert(qr/$expected/, $resp_msg,
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

  eval {
    if (open(my $fh, "< $log_file")) {
      my $adding_entry = 0;
      my $cached_stat = 0;
      my $cached_lstat = 0;

      if ($^O eq 'darwin') {
        # MacOSX-specific hack
        $test_file = '/private' . $test_file;
      }

      while (my $line = <$fh>) {
        if ($line =~ /<statcache:9>/) {
          if ($line =~ /adding entry.*?type file/) {
            $adding_entry++;
            next;
          }
        }

        if ($line =~ /<statcache:11>/) {
          if ($cached_stat == 0 &&
              $line =~ /using cached stat.*?path '$test_file'/) {
            $cached_stat++;
            next;
          }

          if ($cached_lstat == 0 &&
              $line =~ /using cached lstat.*?path '$test_file'/) {
            $cached_lstat++;
            next;
          }
        }

        if ($adding_entry >= 2 &&
            $cached_stat == 1 &&
            $cached_lstat == 1) {
          last;
        }
      }

      close($fh);

      $self->assert($adding_entry >= 2 &&
                    $cached_stat == 1 &&
                    $cached_lstat == 1,
        test_msg("Did not see expected 'statcache' TraceLog messages"));

    } else {
      die("Can't read $log_file: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub statcache_dir {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/statcache.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/statcache.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/statcache.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/statcache.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/statcache.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $test_dir = File::Spec->rel2abs("$home_dir/test.d");
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
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $statcache_tab = File::Spec->rel2abs("$tmpdir/statcache.tab");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'fsio:10 statcache:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_statcache.c' => {
        StatCacheEngine => 'on',
        StatCacheTable => $statcache_tab,
      },

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
      my ($resp_code, $resp_msg) = $client->mlst('test.d');

      my $expected;

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=flcdmpe;type=dir;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/.*\/test\.d$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      # Do the MLST again; we'll check the logs to see if mod_statcache
      # did its job.
      $resp_code = $resp_msg = undef;
      ($resp_code, $resp_msg) = $client->mlst('test.d');

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=flcdmpe;type=dir;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/.*\/test\.d$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      $client->quit();

      # Now connect again, do another MLST, and see if we're still using
      # the cached entry.
      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);
      ($resp_code, $resp_msg) = $client->mlst('test.d');

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=flcdmpe;type=dir;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/.*\/test\.d$';
      $self->assert(qr/$expected/, $resp_msg,
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

  eval {
    if (open(my $fh, "< $log_file")) {
      my $adding_entry = 0;
      my $cached_stat = 0;
      my $cached_lstat = 0;

      if ($^O eq 'darwin') {
        # MacOSX-specific hack
        $test_dir = '/private' . $test_dir;
      }

      while (my $line = <$fh>) {
        if ($line =~ /<statcache:9>/) {
          if ($line =~ /adding entry.*?type dir/) {
            $adding_entry++;
            next;
          }
        }

        if ($line =~ /<statcache:11>/) {
          if ($cached_stat == 0 &&
              $line =~ /using cached stat.*?path '$test_dir'/) {
            $cached_stat++;
            next;
          }

          if ($cached_lstat == 0 &&
              $line =~ /using cached lstat.*?path '$test_dir'/) {
            $cached_lstat++;
            next;
          }
        }

        if ($adding_entry >= 2 &&
            $cached_stat == 1 &&
            $cached_lstat == 1) {
          last;
        }
      }

      close($fh);

      $self->assert($adding_entry >= 2 &&
                    $cached_stat == 1 &&
                    $cached_lstat == 1,
        test_msg("Did not see expected 'statcache' TraceLog messages"));

    } else {
      die("Can't read $log_file: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub statcache_dir_chrooted {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/statcache.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/statcache.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/statcache.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/statcache.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/statcache.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $test_dir = File::Spec->rel2abs("$home_dir/test.d");
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
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $statcache_tab = File::Spec->rel2abs("$tmpdir/statcache.tab");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'fsio:10 statcache:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    DefaultRoot => '~',

    IfModules => {
      'mod_statcache.c' => {
        StatCacheEngine => 'on',
        StatCacheTable => $statcache_tab,
      },

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
      my ($resp_code, $resp_msg) = $client->mlst('test.d');

      my $expected;

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=flcdmpe;type=dir;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/test\.d$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      # Do the MLST again; we'll check the logs to see if mod_statcache
      # did its job.
      $resp_code = $resp_msg = undef;
      ($resp_code, $resp_msg) = $client->mlst('test.d');

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=flcdmpe;type=dir;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/test\.d$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      $client->quit();

      # Now connect again, do another MLST, and see if we're still using
      # the cached entry.
      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);
      ($resp_code, $resp_msg) = $client->mlst('test.d');
    
      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=flcdmpe;type=dir;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/test\.d$';
      $self->assert(qr/$expected/, $resp_msg,
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

  eval {
    if (open(my $fh, "< $log_file")) {
      my $adding_entry = 0;
      my $cached_stat = 0;
      my $cached_lstat = 0;

      # Since we're chrooted, the expected path is now different.
      $test_dir = '/test.d';

      while (my $line = <$fh>) {
        if ($line =~ /<statcache:9>/) {
          if ($line =~ /adding entry.*?type dir/) {
            $adding_entry++;
            next;
          }
        }

        if ($line =~ /<statcache:11>/) {
          if ($cached_stat == 0 &&
              $line =~ /using cached stat.*?path '$test_dir'/) {
            $cached_stat++;
            next;
          }

          if ($cached_lstat == 0 &&
              $line =~ /using cached lstat.*?path '$test_dir'/) {
            $cached_lstat++;
            next;
          }
        }

        if ($adding_entry >= 2 &&
            $cached_stat == 1 &&
            $cached_lstat == 1) {
          last;
        }
      }

      close($fh);

      $self->assert($adding_entry >= 2 &&
                    $cached_stat == 1 &&
                    $cached_lstat == 1,
        test_msg("Did not see expected 'statcache' TraceLog messages"));

    } else {
      die("Can't read $log_file: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub statcache_rel_symlink_file {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/statcache.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/statcache.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/statcache.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/statcache.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/statcache.group");

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

  my $test_file = File::Spec->rel2abs("$home_dir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  # Change to the directory in order to create a relative path in the
  # symlink we need.

  my $cwd = getcwd();
  unless (chdir("$home_dir")) {
    die("Can't chdir to $home_dir: $!");
  }

  unless (symlink('test.txt', 'test.lnk')) {
    die("Can't symlink 'test.txt' to 'test.lnk': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  my $test_symlink = File::Spec->rel2abs("$home_dir/test.lnk");

  my $statcache_tab = File::Spec->rel2abs("$tmpdir/statcache.tab");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'fsio:10 statcache:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_statcache.c' => {
        StatCacheEngine => 'on',
        StatCacheTable => $statcache_tab,
      },

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
      my ($resp_code, $resp_msg) = $client->mlst('test.lnk');

      my $expected;

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=file;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/.*\/test\.lnk$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      # Do the MLST again; we'll check the logs to see if mod_statcache
      # did its job.
      $resp_code = $resp_msg = undef;
      ($resp_code, $resp_msg) = $client->mlst('test.lnk');

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=file;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/.*\/test\.lnk$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      $client->quit();

      # Now connect again, do another MLST, and see if we're still using
      # the cached entry.
      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);
      ($resp_code, $resp_msg) = $client->mlst('test.lnk');
    
      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=file;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/.*\/test\.lnk$';
      $self->assert(qr/$expected/, $resp_msg,
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

  eval {
    if (open(my $fh, "< $log_file")) {
      my $adding_entry = 0;
      my $cached_stat = 0;
      my $cached_lstat = 0;

      if ($^O eq 'darwin') {
        # MacOSX-specific hack
        $test_symlink = '/private' . $test_symlink;
      }

      while (my $line = <$fh>) {
        if ($line =~ /<statcache:9>/) {
          if ($line =~ /adding entry.*?type file/) {
            $adding_entry++;
            next;
          }

          if ($line =~ /adding entry.*?type symlink/) {
            $adding_entry++;
            next;
          }
        }

        if ($line =~ /<statcache:11>/) {
          if ($cached_stat == 0 &&
              $line =~ /using cached stat.*?path '$test_symlink'/) {
            $cached_stat++;
            next;
          }

          if ($cached_lstat == 0 &&
              $line =~ /using cached lstat.*?path '$test_symlink'/) {
            $cached_lstat++;
            next;
          }
        }

        if ($adding_entry >= 2 &&
            $cached_stat == 1 &&
            $cached_lstat == 1) {
          last;
        }
      }

      close($fh);

      $self->assert($adding_entry >= 2 &&
                    $cached_stat == 1 &&
                    $cached_lstat == 1,
        test_msg("Did not see expected 'statcache' TraceLog messages"));

    } else {
      die("Can't read $log_file: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub statcache_rel_symlink_file_chrooted {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/statcache.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/statcache.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/statcache.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/statcache.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/statcache.group");

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

  my $test_file = File::Spec->rel2abs("$home_dir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  # Change to the directory in order to create a relative path in the
  # symlink we need.

  my $cwd = getcwd();
  unless (chdir("$home_dir")) {
    die("Can't chdir to $home_dir: $!");
  }

  unless (symlink('test.txt', 'test.lnk')) {
    die("Can't symlink 'test.txt' to 'test.lnk': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  my $test_symlink = File::Spec->rel2abs("$home_dir/test.lnk");

  my $statcache_tab = File::Spec->rel2abs("$tmpdir/statcache.tab");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'fsio:10 statcache:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    DefaultRoot => '~',

    IfModules => {
      'mod_statcache.c' => {
        StatCacheEngine => 'on',
        StatCacheTable => $statcache_tab,
      },

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
      my ($resp_code, $resp_msg) = $client->mlst('test.lnk');

      my $expected;

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=file;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/test\.lnk$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      # Do the MLST again; we'll check the logs to see if mod_statcache
      # did its job.
      $resp_code = $resp_msg = undef;
      ($resp_code, $resp_msg) = $client->mlst('test.lnk');

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=file;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/test\.lnk$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      $client->quit();

      # Now connect again, do another MLST, and see if we're still using
      # the cached entry.
      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);
      ($resp_code, $resp_msg) = $client->mlst('test.lnk');
    
      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=file;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/test\.lnk$';
      $self->assert(qr/$expected/, $resp_msg,
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

  eval {
    if (open(my $fh, "< $log_file")) {
      my $adding_entry = 0;
      my $cached_stat = 0;
      my $cached_lstat = 0;

      # Since we're chrooted, the expected path is now different.
      $test_symlink = '/test.lnk';

      while (my $line = <$fh>) {
        if ($line =~ /<statcache:9>/) {
          if ($line =~ /adding entry.*?type file/) {
            $adding_entry++;
            next;
          }

          if ($line =~ /adding entry.*?type symlink/) {
            $adding_entry++;
            next;
          }
        }

        if ($line =~ /<statcache:11>/) {
          if ($cached_stat == 0 &&
              $line =~ /using cached stat.*?path '$test_symlink'/) {
            $cached_stat++;
            next;
          }

          if ($cached_lstat == 0 &&
              $line =~ /using cached lstat.*?path '$test_symlink'/) {
            $cached_lstat++;
            next;
          }
        }

        if ($adding_entry >= 2 &&
            $cached_stat == 1 &&
            $cached_lstat == 1) {
          last;
        }
      }

      close($fh);

      $self->assert($adding_entry >= 2 &&
                    $cached_stat == 1 &&
                    $cached_lstat == 1,
        test_msg("Did not see expected 'statcache' TraceLog messages"));

    } else {
      die("Can't read $log_file: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub statcache_rel_symlink_dir {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/statcache.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/statcache.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/statcache.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/statcache.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/statcache.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d");
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
  auth_group_write($auth_group_file, $group, $gid, $user);

  # Change to the directory in order to create a relative path in the
  # symlink we need.

  my $cwd = getcwd();
  unless (chdir("$home_dir")) {
    die("Can't chdir to $home_dir: $!");
  }

  unless (symlink('test.d', 'test.lnk')) {
    die("Can't symlink 'test.d' to 'test.lnk': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  my $test_symlink = File::Spec->rel2abs("$home_dir/test.lnk");

  my $statcache_tab = File::Spec->rel2abs("$tmpdir/statcache.tab");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'fsio:10 statcache:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_statcache.c' => {
        StatCacheEngine => 'on',
        StatCacheTable => $statcache_tab,
      },

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
      my ($resp_code, $resp_msg) = $client->mlst('test.lnk');

      my $expected;

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=dir;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/.*\/test\.lnk$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      # Do the MLST again; we'll check the logs to see if mod_statcache
      # did its job.
      $resp_code = $resp_msg = undef;
      ($resp_code, $resp_msg) = $client->mlst('test.lnk');

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=dir;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/.*\/test\.lnk$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      $client->quit();

      # Now connect again, do another MLST, and see if we're still using
      # the cached entry.
      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);
      ($resp_code, $resp_msg) = $client->mlst('test.lnk');
    
      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=dir;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/.*\/test\.lnk$';
      $self->assert(qr/$expected/, $resp_msg,
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

  eval {
    if (open(my $fh, "< $log_file")) {
      my $adding_entry = 0;
      my $cached_stat = 0;
      my $cached_lstat = 0;

      if ($^O eq 'darwin') {
        # MacOSX-specific hack
        $test_symlink = '/private' . $test_symlink;
      }

      while (my $line = <$fh>) {
        if ($line =~ /<statcache:9>/) {
          if ($line =~ /adding entry.*?type dir/) {
            $adding_entry++;
            next;
          }

          if ($line =~ /adding entry.*?type symlink/) {
            $adding_entry++;
            next;
          }
        }

        if ($line =~ /<statcache:11>/) {
          if ($cached_stat == 0 &&
              $line =~ /using cached stat.*?path '$test_symlink'/) {
            $cached_stat++;
            next;
          }

          if ($cached_lstat == 0 &&
              $line =~ /using cached lstat.*?path '$test_symlink'/) {
            $cached_lstat++;
            next;
          }
        }

        if ($adding_entry >= 2 &&
            $cached_stat == 1 &&
            $cached_lstat == 1) {
          last;
        }
      }

      close($fh);

      $self->assert($adding_entry >= 2 &&
                    $cached_stat == 1 &&
                    $cached_lstat == 1,
        test_msg("Did not see expected 'statcache' TraceLog messages"));

    } else {
      die("Can't read $log_file: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub statcache_rel_symlink_dir_chrooted {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/statcache.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/statcache.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/statcache.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/statcache.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/statcache.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d");
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
  auth_group_write($auth_group_file, $group, $gid, $user);

  # Change to the directory in order to create a relative path in the
  # symlink we need.

  my $cwd = getcwd();
  unless (chdir("$home_dir")) {
    die("Can't chdir to $home_dir: $!");
  }

  unless (symlink('test.d', 'test.lnk')) {
    die("Can't symlink 'test.d' to 'test.lnk': $!");
  }

  unless (chdir($cwd)) {
    die("Can't chdir to $cwd: $!");
  }

  my $test_symlink = File::Spec->rel2abs("$home_dir/test.lnk");

  my $statcache_tab = File::Spec->rel2abs("$tmpdir/statcache.tab");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'fsio:10 statcache:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    DefaultRoot => '~',

    IfModules => {
      'mod_statcache.c' => {
        StatCacheEngine => 'on',
        StatCacheTable => $statcache_tab,
      },

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
      my ($resp_code, $resp_msg) = $client->mlst('test.lnk');

      my $expected;

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=dir;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/test\.lnk$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      # Do the MLST again; we'll check the logs to see if mod_statcache
      # did its job.
      $resp_code = $resp_msg = undef;
      ($resp_code, $resp_msg) = $client->mlst('test.lnk');

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=dir;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername\=S+; \/test\.lnk$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      $client->quit();

      # Now connect again, do another MLST, and see if we're still using
      # the cached entry.
      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);
      ($resp_code, $resp_msg) = $client->mlst('test.lnk');
    
      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=dir;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/test\.lnk$';
      $self->assert(qr/$expected/, $resp_msg,
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

  eval {
    if (open(my $fh, "< $log_file")) {
      my $adding_entry = 0;
      my $cached_stat = 0;
      my $cached_lstat = 0;

      # Since we're chrooted, the expected path is now different.
      $test_symlink = '/test.lnk';

      while (my $line = <$fh>) {
        if ($line =~ /<statcache:9>/) {
          if ($line =~ /adding entry.*?type dir/) {
            $adding_entry++;
            next;
          }

          if ($line =~ /adding entry.*?type symlink/) {
            $adding_entry++;
            next;
          }
        }

        if ($line =~ /<statcache:11>/) {
          if ($cached_stat == 0 &&
              $line =~ /using cached stat.*?path '$test_symlink'/) {
            $cached_stat++;
            next;
          }

          if ($cached_lstat == 0 &&
              $line =~ /using cached lstat.*?path '$test_symlink'/) {
            $cached_lstat++;
            next;
          }
        }

        if ($adding_entry >= 2 &&
            $cached_stat == 1 &&
            $cached_lstat == 1) {
          last;
        }
      }

      close($fh);

      $self->assert($adding_entry >= 2 &&
                    $cached_stat == 1 &&
                    $cached_lstat == 1,
        test_msg("Did not see expected 'statcache' TraceLog messages"));

    } else {
      die("Can't read $log_file: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub statcache_config_max_age {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/statcache.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/statcache.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/statcache.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/statcache.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/statcache.group");

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

  my $test_file = File::Spec->rel2abs("$home_dir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $statcache_tab = File::Spec->rel2abs("$tmpdir/statcache.tab");
  my $max_age = 3;
  my $timeout = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'fsio:10 statcache:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_statcache.c' => {
        StatCacheEngine => 'on',
        StatCacheTable => $statcache_tab,
        StatCacheMaxAge => $max_age,
      },

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
      my ($resp_code, $resp_msg) = $client->mlst('test.txt');

      my $expected;

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=file;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/.*\/test\.txt$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      # Do the MLST again; we'll check the logs to see if mod_statcache
      # did its job.
      $resp_code = $resp_msg = undef;
      ($resp_code, $resp_msg) = $client->mlst('test.txt');

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=file;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/.*\/test\.txt$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      $client->quit();

      # Now connect again, do another MLST, and see if we're still using
      # the cached entry.  But give enough time for the entry to expire.
      sleep($max_age + 1);

      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);
      ($resp_code, $resp_msg) = $client->mlst('test.txt');

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=file;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/.*\/test\.txt$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      $client->quit();
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  # Stop server
  server_stop($pid_file);

  $self->assert_child_ok($pid);

  eval {
    if (open(my $fh, "< $log_file")) {
      my $adding_entry = 0;
      my $expired_entry = 0;
      my $cached_stat = 0;
      my $cached_lstat = 0;

      if ($^O eq 'darwin') {
        # MacOSX-specific hack
        $test_file = '/private' . $test_file;
      }

      while (my $line = <$fh>) {
        chomp($line);
        if ($line =~ /<statcache:9>/) {
          if ($line =~ /adding entry.*?type file/) {
            $adding_entry++;
            next;
          }
        }

        if ($line =~ /<statcache:11>/) {
          if ($cached_stat == 0 &&
              $line =~ /using cached stat.*?path '$test_file'/) {
            $cached_stat++;
            next;
          }

          if ($cached_lstat == 0 &&
              $line =~ /using cached lstat.*?path '$test_file'/) {
            $cached_lstat++;
            next;
          }
        }

        if ($line =~ /<statcache:17>/) {
          if ($line =~ /expired cache entry.*?path '$test_file'/) {
            $expired_entry++;
            next;
          }
        }

        if ($adding_entry >= 2 &&
            $expired_entry >= 1 &&
            $cached_stat == 1 &&
            $cached_lstat == 1) {
          last;
        }
      }

      close($fh);

      $self->assert($adding_entry >= 2 &&
                    $expired_entry >= 1 &&
                    $cached_stat == 1 &&
                    $cached_lstat == 1,
        test_msg("Did not see expected 'statcache' TraceLog messages"));

    } else {
      die("Can't read $log_file: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub statcache_config_capacity {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/statcache.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/statcache.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/statcache.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/statcache.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/statcache.group");

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

  my $test_file = File::Spec->rel2abs("$home_dir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $statcache_tab = File::Spec->rel2abs("$tmpdir/statcache.tab");
  my $capacity = 10000;
  my $max_age = 5;
  my $timeout = 300;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'fsio:10 statcache:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_statcache.c' => {
        StatCacheEngine => 'on',
        StatCacheTable => $statcache_tab,
        StatCacheCapacity => $capacity,
      },

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
      my ($resp_code, $resp_msg) = $client->mlst('test.txt');

      my $expected;

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=file;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/.*\/test\.txt$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      # Do the MLST again; we'll check the logs to see if mod_statcache
      # did its job.
      $resp_code = $resp_msg = undef;
      ($resp_code, $resp_msg) = $client->mlst('test.txt');

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=file;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/.*\/test\.txt$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      $client->quit();

      # Now connect again, do another MLST, and see if we're still using
      # the cached entry.  But give enough time for the entry to expire.
      sleep($max_age + 1);

      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);
      ($resp_code, $resp_msg) = $client->mlst('test.txt');

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'modify=\d+;perm=adfr(w)?;size=\d+;type=file;unique=\S+;UNIX.group=\d+;UNIX.groupname=\S+;UNIX.mode=\d+;UNIX.owner=\d+;UNIX.ownername=\S+; \/.*\/test\.txt$';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      $client->quit();
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  # Stop server
  server_stop($pid_file);

  $self->assert_child_ok($pid);

  eval {
    if (open(my $fh, "< $log_file")) {
      my $adding_entry = 0;
      my $expired_entry = 0;
      my $cached_stat = 0;
      my $cached_lstat = 0;

      if ($^O eq 'darwin') {
        # MacOSX-specific hack
        $test_file = '/private' . $test_file;
      }

      while (my $line = <$fh>) {
        if ($line =~ /<statcache:9>/) {
          if ($line =~ /adding entry.*?type file/) {
            $adding_entry++;
            next;
          }
        }

        if ($line =~ /<statcache:11>/) {
          if ($cached_stat == 0 &&
              $line =~ /using cached stat.*?path '$test_file'/) {
            $cached_stat++;
            next;
          }

          if ($cached_lstat == 0 &&
              $line =~ /using cached lstat.*?path '$test_file'/) {
            $cached_lstat++;
            next;
          }
        }

        if ($line =~ /<statcache:17>/) {
          if ($line =~ /expired cache entry.*?path '$test_file'/) {
            $expired_entry++;
            next;
          }
        }

        if ($adding_entry >= 2 &&
            $expired_entry >= 1 &&
            $cached_stat == 1 &&
            $cached_lstat == 1) {
          last;
        }
      }

      close($fh);

      $self->assert($adding_entry >= 2 &&
                    $expired_entry >= 1 &&
                    $cached_stat == 1 &&
                    $cached_lstat == 1,
        test_msg("Did not see expected 'statcache' TraceLog messages"));

    } else {
      die("Can't read $log_file: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

1;
