package ProFTPD::Tests::Modules::mod_ratio;

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
  ratio_bug3600 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  ratio_after_disconnect => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  ratio_userratio_with_credit => {
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

sub ratio_bug3600 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ratio.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ratio.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ratio.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/ratio.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/ratio.group");

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

  my $ratio_file = File::Spec->rel2abs("$home_dir/.ratio");
  if (open(my $fh, "> $ratio_file")) {
    unless (close($fh)) {
      die("Can't write $ratio_file: $!");
    }

  } else {
    die("Can't open $ratio_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'response:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_ratio.c' => {
        Ratios => 'on',
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

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg(0);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Down: 0 Files (0mb)  Up: 0 Files (0mb)  10,000,000:1  CR: LEECH";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      ($resp_code, $resp_msg) = $client->syst(); 

      $expected = 215;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "UNIX Type: L8";
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

sub ratio_after_disconnect {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ratio.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ratio.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ratio.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/ratio.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/ratio.group");

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

  my $ratio_file = File::Spec->rel2abs("$home_dir/ratios.dat");
  if (open(my $fh, "> $ratio_file")) {
    unless (close($fh)) {
      die("Can't write $ratio_file: $!");
    }

  } else {
    die("Can't open $ratio_file: $!");
  }

  my $ratio_tmp_file = File::Spec->rel2abs("$home_dir/ratios.tmp");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'response:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_ratio.c' => {
        Ratios => 'on',
        SaveRatios => 'on',
        RatioFile => $ratio_file,
        RatioTempFile => $ratio_tmp_file,
        CwdRatioMsg => "Please Upload first",
        FileRatioErrMsg => "Come on, gimme a lil more",
        ByteRatioErrMsg => "COME ON NOW",
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

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg(0);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Down: 0 Files (0mb)  Up: 0 Files (0mb)  10,000,000:1  CR: LEECH";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      my $conn = $client->stor_raw("test.txt");
      unless ($conn) {
        die("STOR test.txt failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Hello, World!";
      $conn->write($buf, length($buf), 5);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg(1);
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $conn = $client->retr_raw("test.txt");
      unless ($conn) {
        die("RETR test.txt failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      $conn->read($buf, 8192, 5);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg(1);
      $self->assert_transfer_ok($resp_code, $resp_msg);

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

  if (open(my $fh, "< $ratio_file")) {
    my $line = <$fh>;
    chomp($line);
    close($fh);

    my $expected = "$user|2|0|1|0";
    $self->assert($line eq $expected,
      test_msg("Expected RatioFile content '$expected', got '$line'"));

  } else {
    die("Can't read $ratio_file: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

# See: https://bugs.launchpad.net/ubuntu/+source/proftpd-dfsg/+bug/479963
sub ratio_userratio_with_credit {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ratio.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ratio.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ratio.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/ratio.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/ratio.group");

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

  my $ratio_file = File::Spec->rel2abs("$home_dir/ratios.dat");
  if (open(my $fh, "> $ratio_file")) {
    print $fh "$user|7|102404|1|51218\n";

    unless (close($fh)) {
      die("Can't write $ratio_file: $!");
    }

  } else {
    die("Can't open $ratio_file: $!");
  }

  my $ratio_tmp_file = File::Spec->rel2abs("$home_dir/ratios.tmp");
  if (open(my $fh, "> $ratio_tmp_file")) {
    print $fh "$user|7|102404|1|51218\n";

    unless (close($fh)) {
      die("Can't write $ratio_tmp_file: $!");
    }

  } else {
    die("Can't open $ratio_tmp_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'response:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_ratio.c' => {
        Ratios => 'on',
        SaveRatios => 'on',
        RatioFile => $ratio_file,
        RatioTempFile => $ratio_tmp_file,
        CwdRatioMsg => "Please Upload first",
        FileRatioErrMsg => "Come on, gimme a lil more",
        ByteRatioErrMsg => "COME ON NOW",
        UserRatio => '* 0 0 5 2355200',
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

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg(0);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Down: 1 Files (0mb)  Up: 7 Files (0mb)   1:5B CR: 2300";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      my $conn = $client->stor_raw("test.txt");
      unless ($conn) {
        die("STOR test.txt failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Hello, World!";
      $conn->write($buf, length($buf), 5);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg(1);
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $conn = $client->retr_raw("test.txt");
      unless ($conn) {
        die("RETR test.txt failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      $conn->read($buf, 8192, 5);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg(1);
      $self->assert_transfer_ok($resp_code, $resp_msg);

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

  if (open(my $fh, "< $ratio_file")) {
    my $line = <$fh>;
    chomp($line);
    close($fh);

    my $expected = "$user|7|102404|1|51218";
    $self->assert($line eq $expected,
      test_msg("Expected RatioFile content '$expected', got '$line'"));

  } else {
    die("Can't read $ratio_file: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

1;
