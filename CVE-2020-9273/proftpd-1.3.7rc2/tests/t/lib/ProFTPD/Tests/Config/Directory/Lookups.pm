package ProFTPD::Tests::Config::Directory::Lookups;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use Data::Dumper;
use File::Path qw(mkpath);
use File::Spec;
use IO::Handle;
use Time::HiRes qw(gettimeofday tv_interval);

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  dir_lookup_wide_layout_abs_paths => {
    order => ++$order,
    test_class => [qw(bug forking slow)],
  },

  dir_lookup_deep_layout_abs_paths => {
    order => ++$order,
    test_class => [qw(bug forking slow)],
  },

  dir_lookup_wide_layout_rel_paths => {
    order => ++$order,
    test_class => [qw(bug forking slow)],
  },

  dir_lookup_deep_layout_rel_paths => {
    order => ++$order,
    test_class => [qw(bug forking slow)],
  },

  dir_lookup_many_files_hidefiles_bug3526 => {
    order => ++$order,
    test_class => [qw(bug forking slow)],
  },

  # I suspect that, due to the nature of the parser, the order in which
  # the <Directory> sections appear in the config can affect performance.
  # If the _last_ <Directory> section is for the most common path referenced,
  # it could mean longer traversal times (for each lookup) before the
  # match is made.
  #
  # Defining absolute paths in the <Directory> paths, versus relative/runtime
  # paths, makes a difference at login time.  The resolve_deferred_dirs()
  # function can take a while in the case of relative paths, causing login
  # timeouts.

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
#  return testsuite_get_runnable_tests($TESTS);
  return qw(
    dir_lookup_many_files_hidefiles_bug3526
  );
}

sub set_up {
  my $self = shift;
  $self->SUPER::set_up(@_);

  make_name(0, 0);
}

my ($prev_name, $prev_namelen);

sub make_name {
  my $name_len = shift;
  my $inc = shift;

  if ($name_len == 0) {
    ($prev_name, $prev_namelen) = (undef, undef);
    return undef;
  }

  # If the requested name length has changed, start over
  if ($name_len != $prev_namelen) {
    $prev_name = undef;
  }

  if (defined($prev_name)) {
    # Split the name into its individual chars, in reverse order
    my @chars = reverse(split('', $prev_name));

    # Increment the first char, then reassemble the name.  We only want
    # ASCII characters (i.e. A-Za-z inclusive).  So if the incremented first
    # char is outside the range, reset the first char to the range start, and
    # increment the next char.

    for (my $i = 0; $i < $prev_namelen; $i++) {
      my $char = $chars[$i];
      my $val = ord($char);

      $char = chr(++$val);

      my $reset_char = 0;
      while ($char !~ /[A-Za-z]/o) {
        ++$val;
        if ($val > 122) {
          # Too far; reset to 'A'.
          $val = 65;
          $reset_char = 1;
        }

        $char = chr($val);
      }

      $chars[$i] = $char;

      unless ($reset_char) {
        last;
      }
    }

    $prev_name = join('', reverse(@chars));

  } else {
    $prev_name = "A" x $name_len;
    $prev_namelen = $name_len;
  }

  return $prev_name;
}

sub dir_lookup_wide_layout_abs_paths {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/dir.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/dir.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/dir.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/dir.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/dir.group");

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

  my $timeout = 300;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 auth:0 config:0 directory:10 fsio:0 lock:0',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    AllowOverwrite => 'on',
    CommandBufferSize => 1024,
    TimeoutIdle => $timeout,
    TimeoutLogin => $timeout,

    Directory => {
      '/' => {
        Umask => '066 077',
      },
    },

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Append our mess of many wide <Directory> sections to the config:
  #
  #  <Directory /path/to/a>
  #    Umask 066 077
  #  </Directory>
  #
  #  <Directory /path/to/b>
  #    Umask 066 077
  #  </Directory>

  my $target_dir;

  if (open(my $fh, ">> $config_file")) {
    my $count = 1000;
    print STDOUT "# Creating $count subdirectories\n";

    my $namelen = 3;

    for (my $i = 0; $i < $count; $i++) {
      $target_dir = make_name($namelen, 1);
      my $dir = File::Spec->rel2abs("$tmpdir/$target_dir");
      mkpath($dir);

      print $fh <<EOD;
<Directory $dir>
  Umask 066 077
</Directory>
EOD
    }

    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  # To test the worst-case scenario, the target directory (to which we will
  # write a file) should be the _last_ in the list.

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, undef,
        $timeout);

      # Make sure the underlying Net::FTP uses our long timeout
      my $old_timeout = $client->{ftp}->timeout($timeout);

      my $start_login = [gettimeofday()];
      $client->login($user, $passwd, $timeout);
      my $login_elapsed = tv_interval($start_login);
      print STDOUT "# Login elapsed: ", Dumper($login_elapsed);

      my ($resp_code, $resp_msg);

      my $start_upload = [gettimeofday()];

      my $conn = $client->stor_raw("$target_dir/test.txt");
      unless ($conn) {
        die("Failed to STOR $target_dir/test.txt: " . $client->response_code() .
          " " . $client->response_msg());
      }

      my $upload_elapsed = tv_interval($start_upload);
      print STDOUT "# Upload elapsed: ", Dumper($upload_elapsed);

      $conn->close();

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $client->quit();

      my $expected;

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected '$expected', got '$resp_code'"));

      $expected = "Transfer complete";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout + 5) };
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

sub dir_lookup_deep_layout_abs_paths {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/dir.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/dir.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/dir.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/dir.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/dir.group");

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

  my $timeout = 300;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 auth:0 config:0 directory:10 fsio:10 lock:0',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    AllowOverwrite => 'on',
    CommandBufferSize => 1024,
    TimeoutIdle => $timeout,
    TimeoutLogin => $timeout,

    Directory => {
      '/' => {
        Umask => '066 077',
      },
    },

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Append our mess of many deep <Directory> sections to the config:
  #
  #  <Directory /path/to/a>
  #    Umask 066 077
  #  </Directory>
  #
  #  <Directory /path/to/a/b>
  #    Umask 066 077
  #  </Directory>

  my $target_dir;
  if (open(my $fh, ">> $config_file")) {
    my $count = 256 - length($home_dir);
    print STDOUT "# Creating $count subdirectories\n";

    $target_dir = File::Spec->rel2abs("$tmpdir/" . make_name(1, 1));

    for (my $i = 0; $i < $count; $i++) {
      $target_dir = File::Spec->catdir($target_dir, make_name(1, 1));
      my $dir = File::Spec->rel2abs($target_dir);
      mkpath($dir);

      print $fh <<EOD;
<Directory $dir>
  Umask 066 077
</Directory>
EOD
    }

    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  # To test the worst-case scenario, the target directory (to which we will
  # write a file) should be the _last_ in the list.

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, undef,
        $timeout);

      # Make sure the underlying Net::FTP uses our long timeout
      my $old_timeout = $client->{ftp}->timeout($timeout);

      my $start_login = [gettimeofday()];
      $client->login($user, $passwd, $timeout);
      my $login_elapsed = tv_interval($start_login);
      print STDOUT "# Login elapsed: ", Dumper($login_elapsed);

      my ($resp_code, $resp_msg);

      my $start_upload = [gettimeofday()];

      my $conn = $client->stor_raw("$target_dir/test.txt");
      unless ($conn) {
        die("Failed to STOR $target_dir/test.txt: " . $client->response_code() .
          " " . $client->response_msg());
      }

      my $upload_elapsed = tv_interval($start_upload);
      print STDOUT "# Upload elapsed: ", Dumper($upload_elapsed);

      $conn->close();

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $client->quit();

      my $expected;

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected '$expected', got '$resp_code'"));

      $expected = "Transfer complete";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout + 5) };
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

sub dir_lookup_wide_layout_rel_paths {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/dir.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/dir.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/dir.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/dir.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/dir.group");

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

  my $timeout = 300;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 auth:0 config:0 directory:10 fsio:0 lock:0',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    AllowOverwrite => 'on',
    CommandBufferSize => 1024,
    TimeoutIdle => $timeout,
    TimeoutLogin => $timeout,

    Directory => {
      '/' => {
        Umask => '066 077',
      },
    },

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Append our mess of many wide <Directory> sections to the config:
  #
  #  <Directory ~/a>
  #    Umask 066 077
  #  </Directory>
  #
  #  <Directory ~/b>
  #    Umask 066 077
  #  </Directory>

  my $target_dir;

  if (open(my $fh, ">> $config_file")) {
    my $count = 1000;
    print STDOUT "# Creating $count subdirectories\n";

    my $namelen = 3;

    for (my $i = 0; $i < $count; $i++) {
      $target_dir = make_name($namelen, 1);
      my $dir = File::Spec->rel2abs("$tmpdir/$target_dir");
      mkpath($dir);

      print $fh <<EOD;
<Directory ~/$target_dir>
  Umask 066 077
</Directory>
EOD
    }

    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  # To test the worst-case scenario, the target directory (to which we will
  # write a file) should be the _last_ in the list.

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, undef,
        $timeout);

      # Make sure the underlying Net::FTP uses our long timeout
      my $old_timeout = $client->{ftp}->timeout($timeout);

      my $start_login = [gettimeofday()];
      $client->login($user, $passwd, $timeout);
      my $login_elapsed = tv_interval($start_login);
      print STDOUT "# Login elapsed: ", Dumper($login_elapsed);

      my ($resp_code, $resp_msg);

      my $start_upload = [gettimeofday()];

      my $conn = $client->stor_raw("$target_dir/test.txt");
      unless ($conn) {
        die("Failed to STOR $target_dir/test.txt: " . $client->response_code() .
          " " . $client->response_msg());
      }

      my $upload_elapsed = tv_interval($start_upload);
      print STDOUT "# Upload elapsed: ", Dumper($upload_elapsed);

      $conn->close();

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $client->quit();

      my $expected;

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected '$expected', got '$resp_code'"));

      $expected = "Transfer complete";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout + 5) };
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

sub dir_lookup_deep_layout_rel_paths {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/dir.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/dir.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/dir.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/dir.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/dir.group");

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

  my $timeout = 300;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 auth:0 config:0 directory:10 fsio:0 lock:0',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    AllowOverwrite => 'on',
    CommandBufferSize => 1024,
    TimeoutIdle => $timeout,
    TimeoutLogin => $timeout,

    Directory => {
      '/' => {
        Umask => '066 077',
      },
    },

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Append our mess of many deep <Directory> sections to the config:
  #
  #  <Directory ~/a>
  #    Umask 066 077
  #  </Directory>
  #
  #  <Directory ~/a/b>
  #    Umask 066 077
  #  </Directory>

  my $target_dir;
  if (open(my $fh, ">> $config_file")) {
    my $count = 256 - length($home_dir);
    print STDOUT "# Creating $count subdirectories\n";

    $target_dir = File::Spec->rel2abs("$tmpdir/" . make_name(1, 1));

    for (my $i = 0; $i < $count; $i++) {
      $target_dir = File::Spec->catdir($target_dir, make_name(1, 1));
      my $dir = File::Spec->rel2abs($target_dir);
      mkpath($dir);

      print $fh <<EOD;
<Directory ~/$target_dir>
  Umask 066 077
</Directory>
EOD
    }

    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  # To test the worst-case scenario, the target directory (to which we will
  # write a file) should be the _last_ in the list.

  print STDOUT "# target_dir: $target_dir\n";

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, undef,
        $timeout);

      # Make sure the underlying Net::FTP uses our long timeout
      my $old_timeout = $client->{ftp}->timeout($timeout);

      my $start_login = [gettimeofday()];
      $client->login($user, $passwd, $timeout);
      my $login_elapsed = tv_interval($start_login);
      print STDOUT "# Login elapsed: ", Dumper($login_elapsed);

      my ($resp_code, $resp_msg);

      my $start_upload = [gettimeofday()];

      my $conn = $client->stor_raw("$target_dir/test.txt");
      unless ($conn) {
        die("Failed to STOR $target_dir/test.txt: " . $client->response_code() .
          " " . $client->response_msg());
      }

      my $upload_elapsed = tv_interval($start_upload);
      print STDOUT "# Upload elapsed: ", Dumper($upload_elapsed);

      $conn->close();

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $client->quit();

      my $expected;

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected '$expected', got '$resp_code'"));

      $expected = "Transfer complete";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout + 5) };
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

sub dir_lookup_many_files_hidefiles_bug3526 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/dir.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/dir.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/dir.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/dir.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/dir.group");

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

  my $timeout = 300;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 auth:0 config:0 directory:10 fsio:10 lock:0 ftpaccess:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    AllowOverride => 'on',
    TimeoutIdle => $timeout,
    TimeoutLogin => $timeout,

    Directory => {
      '/' => {
        Umask => '066 077',
      },
    },

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Create 1500 files in the target directory.

  my $count = 1500;
  print STDOUT "# Creating $count files\n";

  my $test_dir = File::Spec->rel2abs("$tmpdir/" . make_name(1, 1));
  mkpath($test_dir);

  for (my $i = 0; $i < $count; $i++) {
    my $test_file = File::Spec->rel2abs(File::Spec->catdir($test_dir,
      make_name(5, 1)));
    $test_file .= ".txt";

    if (open(my $fh, "> $test_file")) {
      close($fh);

    } else {
      die("Can't open $test_file: $!");
    }
  }

  # Create a .ftpaccess file in the test directory with a simple HideFiles
  # pattern.
  my $ftpaccess_file = File::Spec->rel2abs("$test_dir/.ftpaccess");
  if (open(my $fh, "> $ftpaccess_file")) {
    print $fh <<EOC;
HideFiles ^\\.
EOC

    unless (close($fh)) {
      die("Can't write $ftpaccess_file: $!");
    }

  } else {
    die("Can't open $ftpaccess_file: $!");
  }

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, undef,
        $timeout);

      # Make sure the underlying Net::FTP uses our long timeout
      my $old_timeout = $client->{ftp}->timeout($timeout);

      my $start_login = [gettimeofday()];
      $client->login($user, $passwd, $timeout);
      my $login_elapsed = tv_interval($start_login);
      print STDOUT "# Login elapsed: ", Dumper($login_elapsed);

      $client->cwd($test_dir);

      my ($resp_code, $resp_msg);

      my $nlst_start = [gettimeofday()];

      my $conn = $client->nlst_raw($test_dir);
      unless ($conn) {
        die("Failed to NLST $test_dir: " . $client->response_code() .
          " " . $client->response_msg());
      }

      my $buf;
      while ($conn->read($buf, 8192, $timeout)) {
        if ($ENV{TEST_VERBOSE}) {
          print STDERR "recvd: $buf\n";
        }
      }

      $conn->close();

      my $nlst_elapsed = tv_interval($nlst_start);
      print STDOUT "# NLST elapsed: ", Dumper($nlst_elapsed);

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $client->quit();

      my $expected;

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected '$expected', got '$resp_code'"));

      $expected = "Transfer complete";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout + 5) };
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

1;
