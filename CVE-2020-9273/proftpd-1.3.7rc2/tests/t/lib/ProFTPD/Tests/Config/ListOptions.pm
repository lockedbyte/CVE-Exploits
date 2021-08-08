package ProFTPD::Tests::Config::ListOptions;

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
  listoptions_opt_t => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  listoptions_opt_1_list => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  listoptions_opt_1_nlst => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  listoptions_opt_1_nlst_simple_glob => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  listoptions_opt_1_nlst_complex_glob => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  listoptions_listonly => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  listoptions_nlstonly => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  listoptions_sortednlst_bug4267 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  listoptions_maxfiles => {
    order => ++$order,
    test_class => [qw(forking slow)],
  },

  listoptions_nlstnamesonly_issue251 => {
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

sub listoptions_opt_t {
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

  # Create three files, and use utime() to modify the last-mod time of
  # each.
  my $test_files = [qw(
    a.txt
    b.txt
    c.txt
    d.txt
    e.txt
    f.txt
    g.txt
    h.txt
    i.txt
  )];

  my $count = scalar(@$test_files);
  foreach my $test_file (sort { $a cmp $b } @$test_files) {
    $count--;

    my $path = File::Spec->rel2abs("$tmpdir/$test_file");
    if (open(my $fh, "> $path")) {
      print $fh "Hello, World!\n";
      unless (close($fh)) {
        die("Can't write $path: $!");
      }

      my $mtime = (time() - ($count * 10));
      unless (utime(undef, $mtime, $path)) {
        die("Can't change mtime for $path: $!");
      }

    } else {
      die("Can't open $path: $!");
    }
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    ListOptions => '-t',

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

      my $conn = $client->list_raw("*.txt");
      unless ($conn) {
        die("Failed to LIST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = '';
      my $tmp;
      while ($conn->read($tmp, 8192, 25)) {
        $buf .= $tmp;
      }
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Transfer complete";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $client->quit();

      # We have to be careful of the fact that readdir returns directory
      # entries in an unordered fashion.
      my $res = [];
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          push(@$res, $1);
        }
      }

      $expected = [reverse(@$test_files)];

      my $nexpected = scalar(@$expected);
      my $nres = scalar(@$res);

      $self->assert($nexpected == $nres,
        test_msg("Expected $nexpected items, got $nres"));
      for (my $i = 0; $i < $nexpected; $i++) {
        $self->assert($expected->[$i] eq $res->[$i],
          test_msg("Expected '$expected->[$i]' at index $i, got '$res->[$i]'"));
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

sub listoptions_opt_1_list {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'config');

  my $test_files = [qw(
    a.txt
    b.txt
    c.txt
    d.txt
    e.txt
    f.txt
    g.txt
    h.txt
    i.txt
  )];

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d");
  mkpath($test_dir);

  my $count = scalar(@$test_files);
  foreach my $test_file (@$test_files) {
    my $path = File::Spec->rel2abs("$test_dir/$test_file");
    if (open(my $fh, "> $path")) {
      print $fh "Hello, World!\n";
      unless (close($fh)) {
        die("Can't write $path: $!");
      }

    } else {
      die("Can't open $path: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    ListOptions => '"-A -1" strict',

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

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Data:\n$buf\n";
      }

      # We have to be careful of the fact that readdir returns directory
      # entries in an unordered fashion.
      my $res = [];
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        push(@$res, $line);
      }

      my $expected = [@$test_files];
      my $nexpected = scalar(@$expected);
      my $nres = scalar(@$res);

      $self->assert($nexpected == $nres,
        "Expected $nexpected items, got $nres");
      for (my $i = 0; $i < $nexpected; $i++) {
        $self->assert($expected->[$i] eq $res->[$i],
          "Expected '$expected->[$i]' at index $i, got '$res->[$i]'");
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

sub listoptions_opt_1_nlst {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'config');

  my $test_files = [qw(
    a.txt
    b.txt
    c.txt
    d.txt
    e.txt
    f.txt
    g.txt
    h.txt
    i.txt
  )];

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d");
  mkpath($test_dir);

  my $count = scalar(@$test_files);
  foreach my $test_file (@$test_files) {
    my $path = File::Spec->rel2abs("$test_dir/$test_file");
    if (open(my $fh, "> $path")) {
      print $fh "Hello, World!\n";
      unless (close($fh)) {
        die("Can't write $path: $!");
      }

    } else {
      die("Can't open $path: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    ListOptions => '"-A -1" strict',

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

      my $conn = $client->nlst_raw('test.d');
      unless ($conn) {
        die("Failed to NLST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 16384, 25);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Data:\n$buf\n";
      }

      # We have to be careful of the fact that readdir returns directory
      # entries in an unordered fashion.
      my $res = [];
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        push(@$res, $line);
      }

      # Sort the results, so that they match the expected list.
      $res = [sort { $a cmp $b } @$res];

      my $expected = [@$test_files];
      my $nexpected = scalar(@$expected);
      my $nres = scalar(@$res);

      $self->assert($nexpected == $nres,
        "Expected $nexpected items, got $nres");

      for (my $i = 0; $i < $nexpected; $i++) {
        $self->assert($expected->[$i] eq $res->[$i],
          "Expected '$expected->[$i]' at index $i, got '$res->[$i]'");
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

sub listoptions_opt_1_nlst_simple_glob {
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

  my $test_files = [qw(
    a.txt
    b.txt
    c.txt
    d.txt
    e.txt
    f.txt
    g.txt
    h.txt
    i.txt
  )];

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d");
  mkpath($test_dir);

  my $count = scalar(@$test_files);
  foreach my $test_file (@$test_files) {
    my $path = File::Spec->rel2abs("$test_dir/$test_file");
    if (open(my $fh, "> $path")) {
      print $fh "Hello, World!\n";
      unless (close($fh)) {
        die("Can't write $path: $!");
      }

    } else {
      die("Can't open $path: $!");
    }
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    ListOptions => '"-A -1" strict',

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

      my $conn = $client->nlst_raw('test.d/*');
      unless ($conn) {
        die("Failed to NLST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 16384, 25);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $client->quit();

      $self->assert_transfer_ok($resp_code, $resp_msg);

      # We have to be careful of the fact that readdir returns directory
      # entries in an unordered fashion.
      my $res = [];
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        push(@$res, $line);
      }

      # Sort the results, so that they match the expected list.
      $res = [sort { $a cmp $b } @$res];

      my $expected = [@$test_files];
      my $nexpected = scalar(@$expected);
      my $nres = scalar(@$res);

      $self->assert($nexpected == $nres,
        test_msg("Expected $nexpected items, got $nres"));

      for (my $i = 0; $i < $nexpected; $i++) {
        $self->assert($expected->[$i] eq $res->[$i],
          test_msg("Expected '$expected->[$i]' at index $i, got '$res->[$i]'"));
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

sub listoptions_opt_1_nlst_complex_glob {
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

  my $test_files = [qw(
    2a-a.txt
    2b-b.txt
    2c-c.txt
    2d-d.txt
    2e-e.txt
    2f-f.txt
    2g-g.txt
    2h-h.txt
    2i-i.txt
  )];

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d/sub.d");
  mkpath($test_dir);

  my $count = scalar(@$test_files);
  foreach my $test_file (@$test_files) {
    my $path = File::Spec->rel2abs("$test_dir/$test_file");
    if (open(my $fh, "> $path")) {
      print $fh "Hello, World!\n";
      unless (close($fh)) {
        die("Can't write $path: $!");
      }

    } else {
      die("Can't open $path: $!");
    }
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    DefaultRoot => '~',
    ListOptions => '"-A -1" strict',

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

      my $conn = $client->nlst_raw('/test.d/sub.d/2?-*.txt');
      unless ($conn) {
        die("Failed to NLST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 16384, 25);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $client->quit();

      $self->assert_transfer_ok($resp_code, $resp_msg);

      # We have to be careful of the fact that readdir returns directory
      # entries in an unordered fashion.
      my $res = [];
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        push(@$res, $line);
      }

      # Sort the results, so that they match the expected list.
      $res = [sort { $a cmp $b } @$res];

      my $expected = [@$test_files];
      my $nexpected = scalar(@$expected);
      my $nres = scalar(@$res);

      $self->assert($nexpected == $nres,
        test_msg("Expected $nexpected items, got $nres"));

      for (my $i = 0; $i < $nexpected; $i++) {
        $self->assert($expected->[$i] eq $res->[$i],
          test_msg("Expected '$expected->[$i]' at index $i, got '$res->[$i]'"));
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

sub listoptions_listonly {
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

  my $test_files = [qw(
    a.txt
    b.txt
    c.txt
    d.txt
    e.txt
    f.txt
    g.txt
    h.txt
    i.txt
  )];

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d");
  mkpath($test_dir);

  my $count = scalar(@$test_files);
  foreach my $test_file (@$test_files) {
    my $path = File::Spec->rel2abs("$test_dir/$test_file");
    if (open(my $fh, "> $path")) {
      print $fh "Hello, World!\n";
      unless (close($fh)) {
        die("Can't write $path: $!");
      }

    } else {
      die("Can't open $path: $!");
    }
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutLinger => 1,

    ListOptions => '"-A -1" LISTOnly',

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
      # First, connect, do a LIST, examine the results
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);

      # First, do a LIST and see what we get
      my $conn = $client->list_raw('test.d');
      unless ($conn) {
        die("Failed to LIST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 16384, 25);
      eval { $conn->close() };
      sleep(2);

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);
      $client->quit();

      # We have to be careful of the fact that readdir returns directory
      # entries in an unordered fashion.
      my $res = [];
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        push(@$res, $line);
      }

      my $expected = [@$test_files];
      my $nexpected = scalar(@$expected);
      my $nres = scalar(@$res);

      $self->assert($nexpected == $nres,
        test_msg("Expected $nexpected items, got $nres"));
      for (my $i = 0; $i < $nexpected; $i++) {
        $self->assert($expected->[$i] eq $res->[$i],
          test_msg("Expected '$expected->[$i]' at index $i, got '$res->[$i]'"));
      }

      # Next, connect, do a NLST, examine the results
      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);

      $conn = $client->nlst_raw('test.d');
      unless ($conn) {
        die("Failed to NLST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      $buf = '';
      $conn->read($buf, 16384, 25);
      eval { $conn->close() };
      sleep(2);

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);
      $client->quit();

      # We have to be careful of the fact that readdir returns directory
      # entries in an unordered fashion.
      $res = [];
      $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        push(@$res, $line);
      }

      # Sort the results, so that they match the expected list.
      $res = [sort { $a cmp $b } @$res];

      $expected = [map { "test.d/$_" } @$test_files];
      $nexpected = scalar(@$expected);
      $nres = scalar(@$res);

      $self->assert($nexpected == $nres,
        test_msg("Expected $nexpected items, got $nres"));
      for (my $i = 0; $i < $nexpected; $i++) {
        $self->assert($expected->[$i] eq $res->[$i],
          test_msg("Expected '$expected->[$i]' at index $i, got '$res->[$i]'"));
      }
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, 30) };
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

sub listoptions_nlstonly {
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

  my $test_files = [qw(
    a.txt
    b.txt
    c.txt
    d.txt
    e.txt
    f.txt
    g.txt
    h.txt
    i.txt
  )];

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d");
  mkpath($test_dir);

  my $count = scalar(@$test_files);
  foreach my $test_file (@$test_files) {
    my $path = File::Spec->rel2abs("$test_dir/$test_file");
    if (open(my $fh, "> $path")) {
      print $fh "Hello, World!\n";
      unless (close($fh)) {
        die("Can't write $path: $!");
      }

    } else {
      die("Can't open $path: $!");
    }
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutLinger => 1,

    ListOptions => '"-A -1" NLSTOnly',

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
      # First, connect, do a LIST, examine the results
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);

      # First, do a LIST and see what we get
      my $conn = $client->list_raw('test.d');
      unless ($conn) {
        die("Failed to LIST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 16384, 25);
      eval { $conn->close() };
      sleep(2);

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);
      $client->quit();

      # We have to be careful of the fact that readdir returns directory
      # entries in an unordered fashion.
      my $res = [];
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          push(@$res, $1);
        }
      }

      my $expected = [@$test_files];
      my $nexpected = scalar(@$expected);
      my $nres = scalar(@$res);

      $self->assert($nexpected == $nres,
        test_msg("Expected $nexpected items, got $nres"));
      for (my $i = 0; $i < $nexpected; $i++) {
        $self->assert($expected->[$i] eq $res->[$i],
          test_msg("Expected '$expected->[$i]' at index $i, got '$res->[$i]'"));
      }

      # Next, connect, do a NLST, examine the results
      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);

      $conn = $client->nlst_raw('test.d');
      unless ($conn) {
        die("Failed to NLST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      $buf = '';
      $conn->read($buf, 16384, 25);
      eval { $conn->close() };
      sleep(2);

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);
      $client->quit();

      # We have to be careful of the fact that readdir returns directory
      # entries in an unordered fashion.
      $res = [];
      $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        push(@$res, $line);
      }

      # Sort the results, so that they match the expected list.
      $res = [sort { $a cmp $b } @$res];

      $expected = [@$test_files];
      $nexpected = scalar(@$expected);
      $nres = scalar(@$res);

      $self->assert($nexpected == $nres,
        test_msg("Expected $nexpected items, got $nres"));
      for (my $i = 0; $i < $nexpected; $i++) {
        $self->assert($expected->[$i] eq $res->[$i],
          test_msg("Expected '$expected->[$i]' at index $i, got '$res->[$i]'"));
      }
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, 30) };
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

sub listoptions_sortednlst_bug4267 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'config');

  my $test_files = [];
  my $nfiles = 1000;
  for (my $i = 0; $i < $nfiles; $i++) {
    my $fileno = sprintf("%04d", $i);
    push(@$test_files, "$fileno.dat");
  }

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d");
  mkpath($test_dir);

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "# Writing out files..."
  }

  my $count = scalar(@$test_files);
  foreach my $test_file (@$test_files) {
    my $path = File::Spec->rel2abs("$test_dir/$test_file");
    if (open(my $fh, "> $path")) {
      print $fh "Hello, World!\n";
      unless (close($fh)) {
        die("Can't write $path: $!");
      }

    } else {
      die("Can't open $path: $!");
    }
  }

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "done\n";
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    TimeoutLinger => 1,

    ListOptions => '"" SortedNLST',

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
      sleep(1);

      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      $client->login($setup->{user}, $setup->{passwd});
      $client->cwd('test.d');

      my $conn = $client->nlst_raw();
      unless ($conn) {
        die("Failed to NLST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my ($buf, $tmp);
      my $res = $conn->read($tmp, 8192, 5);
      while ($res) {
        $buf .= $tmp;
        $tmp = '';
        $res = $conn->read($tmp, 8192, 5);
      }
      eval { $conn->close() };
      sleep(2);

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "buf:\n$buf\n";
      }

      # Do NOT sort the results; we expect them to match the expected list.
      my $res = [];
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        push(@$res, $line);
      }

      my $expected = [@$test_files];
      my $nexpected = scalar(@$expected);
      my $nres = scalar(@$res);

      $self->assert($nexpected == $nres,
        test_msg("Expected $nexpected items, got $nres"));
      for (my $i = 0; $i < $nexpected; $i++) {
        $self->assert($expected->[$i] eq $res->[$i],
          test_msg("Expected '$expected->[$i]' at index $i, got '$res->[$i]'"));
      }

      $client->quit();
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, 180) };
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

sub listoptions_maxfiles {
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

  # For this test, we need to create MANY (i.e. 110K) files in the
  # home directory.
  my $test_file_prefix = File::Spec->rel2abs("$tmpdir/test_");

  my $max_files = 100000;

  my $count = $max_files + 10000;
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
 
  $max_files = 100000;
  my $timeout = 900;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    TimeoutIdle => $timeout + 15,
    TimeoutNoTransfer => $timeout + 15,

    ListOptions => "-al maxfiles $max_files",

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

      my $tmp;
      while ($conn->read($tmp, 16384, 25)) {
        $buf .= $tmp;
      }

      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      $self->assert_transfer_ok($resp_code, $resp_msg);
      $client->quit();

      # We have to be careful of the fact that readdir returns directory
      # entries in an unordered fashion.
      my $res = [];
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        if ($line =~ /^\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          push(@$res, $1);
        }
      }

      my $nexpected = $max_files;
      my $nres = scalar(@$res);

      $self->assert($nexpected == $nres,
        test_msg("Expected $nexpected items, got $nres"));
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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub listoptions_nlstnamesonly_issue251 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'config');

  my $test_files = [qw(
    a.txt
    b.txt
    c.txt
    d.txt
    e.txt
    f.txt
    g.txt
    h.txt
    i.txt
  )];

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d");
  mkpath($test_dir);

  my $count = scalar(@$test_files);
  foreach my $test_file (@$test_files) {
    my $path = File::Spec->rel2abs("$test_dir/$test_file");
    if (open(my $fh, "> $path")) {
      print $fh "Hello, World!\n";
      unless (close($fh)) {
        die("Can't write $path: $!");
      }

    } else {
      die("Can't open $path: $!");
    }
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    ListOptions => '"-A -1 NLSTOnly"',

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

      my $conn = $client->nlst_raw('test.d');
      unless ($conn) {
        die("Failed to NLST: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 16384, 25);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Data:\n$buf\n";
      }

      # We have to be careful of the fact that readdir returns directory
      # entries in an unordered fashion.
      my $res = [];
      my $lines = [split(/\n/, $buf)];
      foreach my $line (@$lines) {
        push(@$res, $line);
      }

      # Sort the results, so that they match the expected list.
      $res = [sort { $a cmp $b } @$res];

      my $expected = [@$test_files];
      my $nexpected = scalar(@$expected);
      my $nres = scalar(@$res);

      $self->assert($nexpected == $nres,
        "Expected $nexpected items, got $nres");

      for (my $i = 0; $i < $nexpected; $i++) {
        $self->assert($expected->[$i] eq $res->[$i],
          "Expected '$expected->[$i]' at index $i, got '$res->[$i]'");
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

1;
