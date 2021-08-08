package ProFTPD::Tests::Modules::mod_deflate;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use Compress::Raw::Zlib;
use Compress::Zlib;
use Digest::MD5;
use File::Spec;
use IO::Handle;
use Time::HiRes qw(gettimeofday tv_interval);

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  deflate_opts_modez_level => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  deflate_feat => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  deflate_list => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  deflate_list_alternating_modes => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  deflate_rest => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  deflate_retr => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  deflate_rest_retr => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  deflate_stor => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  deflate_rest_stor => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  deflate_stor_64kb_binary => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  deflate_stor_64kb_binary_chunks => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  deflate_tls_mode_z => {
    order => ++$order,
    test_class => [qw(forking mod_tls)],
  },

  deflate_netio_close_bad_cmd_sequence_bug3828 => {
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

sub deflate_opts_modez_level {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/deflate.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/deflate.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/deflate.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/deflate.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/deflate.group");

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_deflate.c' => {
        DeflateEngine => 'on',
        DeflateLog => $log_file,
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

      my ($resp_code, $resp_msg) = $client->opts("MODE Z LEVEL 7");

      my $expected;

      $expected = 200;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'OPTS MODE Z OK';
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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub deflate_feat {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/deflate.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/deflate.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/deflate.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/deflate.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/deflate.group");

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_deflate.c' => {
        DeflateEngine => 'on',
        DeflateLog => $log_file,
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

      $client->feat();
 
      my $resp_code = $client->response_code();
      my $resp_msgs = $client->response_msgs();

      my $expected;

      $expected = 211;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      my $nfeat = scalar(@$resp_msgs);

      my $feats = {
        ' MODE Z' => 1,
      };

      my $ok = 0;

      for (my $i = 0; $i < $nfeat; $i++) {
        if (defined($feats->{$resp_msgs->[$i]})) {
          $ok = 1;
          last;
        }
      }

      unless ($ok) {
        die("Unexpected FEAT response");
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

sub deflate_list {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/deflate.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/deflate.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/deflate.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/deflate.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/deflate.group");

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutLinger => 1,

    IfModules => {
      'mod_deflate.c' => {
        DeflateEngine => 'on',
        DeflateLog => $log_file,
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
      $client->mode('Z');

      my $conn = $client->list_raw();
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      my $data;
      while ($conn->read($data, 32768, 30)) {
        $buf .= $data;
      }
      $conn->close();

      my $inflated = uncompress($buf);

      # We have to be careful of the fact that readdir returns directory
      # entries in an unordered fashion.
      my $res = {};
      my $lines = [split(/(\r)?\n/, $inflated)];
      foreach my $line (@$lines) {
        if ($line =~ /\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
          $res->{$1} = 1;
        }
      }

      unless (scalar(keys(%$res)) > 0) {
        die("LIST contained no data unexpectedly");
      }

      my $expected = {
        'deflate.conf' => 1,
        'deflate.group' => 1,
        'deflate.passwd' => 1,
        'deflate.pid' => 1,
        'deflate.scoreboard' => 1,
        'deflate.scoreboard.lck' => 1,
      };

      my $ok = 1;
      my $mismatch;
      foreach my $name (keys(%$res)) {
        unless (defined($expected->{$name})) {
          $mismatch = $name;
          $ok = 0;
          last;
        }
      }

      unless ($ok) {
        die("Unexpected name '$mismatch' appeared in LIST data")
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

sub deflate_list_alternating_modes {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/deflate.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/deflate.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/deflate.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/deflate.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/deflate.group");

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutLinger => 1,

    IfModules => {
      'mod_deflate.c' => {
        DeflateEngine => 'on',
        DeflateLog => $log_file,
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

      # Get a directory listing in alternating modes; first MODE Z, then
      # MODE S, then MODE Z again.

      for (my $i = 0; $i < 3; $i++) {
        if ($i % 2 == 0) {
          $client->mode('Z');

        } else {
          $client->mode('S');
        }

        my $conn = $client->list_raw();
        unless ($conn) {
          die("LIST failed: " . $client->response_code() . " " .
            $client->response_msg());
        }

        my $buf;
        my $data;
        while ($conn->read($data, 32768, 30)) {
          $buf .= $data;
        }

        my $inflated;

        if ($i % 2 == 0) {
          $inflated = uncompress($buf);

        } else {
          $inflated = $buf;
        }

        # We have to be careful of the fact that readdir returns directory
        # entries in an unordered fashion.
        my $res = {};
        my $lines = [split(/(\r)?\n/, $inflated)];
        foreach my $line (@$lines) {
          if ($line =~ /\S+\s+\d+\s+\S+\s+\S+\s+.*?\s+(\S+)$/) {
            $res->{$1} = 1;
          }
        }

        unless (scalar(keys(%$res)) > 0) {
          die("LIST contained no data unexpectedly");
        }

        my $expected = {
          'deflate.conf' => 1,
          'deflate.group' => 1,
          'deflate.passwd' => 1,
          'deflate.pid' => 1,
          'deflate.scoreboard' => 1,
          'deflate.scoreboard.lck' => 1,
        };

        my $ok = 1;
        my $mismatch;
        foreach my $name (keys(%$res)) {
          unless (defined($expected->{$name})) {
            $mismatch = $name;
            $ok = 0;
            last;
          }
        }

        unless ($ok) {
          die("Unexpected name '$mismatch' appeared in LIST data")
        }

        $conn->close();
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

sub deflate_rest {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/deflate.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/deflate.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/deflate.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/deflate.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/deflate.group");

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutLinger => 1,

    IfModules => {
      'mod_deflate.c' => {
        DeflateEngine => 'on',
        DeflateLog => $log_file,
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
      $client->mode('Z');

      my ($resp_code, $resp_msg) = $client->rest(0);

      my $expected;

      $expected = 350;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Restarting at 0. Send STORE or RETRIEVE to initiate transfer";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

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

sub deflate_retr {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/deflate.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/deflate.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/deflate.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/deflate.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/deflate.group");

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

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Ab" x 8192;
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  # Calculate the MD5 checksum of this file, for comparison with the
  # downloaded file.
  my $ctx = Digest::MD5->new();
  my $expected_md5;

  if (open(my $fh, "< $test_file")) {
    binmode($fh);
    $ctx->addfile($fh);
    $expected_md5 = $ctx->hexdigest();
    close($fh);

  } else {
    die("Can't read $test_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutLinger => 1,

    IfModules => {
      'mod_deflate.c' => {
        DeflateEngine => 'on',
        DeflateLog => $log_file,
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
      $client->mode('Z');

      my $conn = $client->retr_raw('test.txt');
      unless ($conn) {
        die("RETR test.txt failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      my $data;
      while ($conn->read($data, 32768, 30)) {
        $buf .= $data;
      }

      my $inflated = uncompress($buf);

      # Calculate the MD5 checksum of the downloaded data
      $ctx->reset();
      my $md5;

      $ctx->add($inflated);
      $md5 = $ctx->hexdigest();

      $self->assert($expected_md5 eq $md5,
        test_msg("Expected '$expected_md5', got '$md5'"));

      $conn->close();
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

sub deflate_rest_retr {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/deflate.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/deflate.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/deflate.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/deflate.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/deflate.group");

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

  my $src_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Ab" x 8192;
    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  # Calculate the MD5 checksum of this file, for comparison with the
  # downloaded file.
  my $ctx = Digest::MD5->new();
  my $expected_md5;

  if (open(my $fh, "< $src_file")) {
    binmode($fh);
    $ctx->addfile($fh);
    $expected_md5 = $ctx->hexdigest();
    close($fh);

  } else {
    die("Can't read $src_file: $!");
  }

  my $offset = (-s $src_file) / 2;

  my $dst_file = File::Spec->rel2abs("$tmpdir/downloaded.txt");
  if (open(my $fh, "> $dst_file")) {
    print $fh "Ab" x 4096;
    unless (close($fh)) {
      die("Can't write $dst_file: $!");
    }

  } else {
    die("Can't open $dst_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutLinger => 1,

    AllowRetrieveRestart => 'on',

    IfModules => {
      'mod_deflate.c' => {
        DeflateEngine => 'on',
        DeflateLog => $log_file,
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
      $client->type('binary');
      $client->mode('Z');
      $client->rest($offset);

      my $conn = $client->retr_raw('test.txt');
      unless ($conn) {
        die("RETR test.txt failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      my $data;
      while ($conn->read($data, 32768, 30)) {
        $buf .= $data;
      }

      $conn->close();

      $client->quit();

      my $inflated = uncompress($buf);

      # Append the inflated data onto the destination file
      if (open(my $fh, ">> $dst_file")) {
        print $fh $inflated;

        unless (close($fh)) {
          die("Can't write $dst_file: $!");
        }

      } else {
        die("Can't open $dst_file: $!");
      }

      # Calculate the MD5 checksum of the downloaded file
      $ctx->reset();
      my $md5;

      if (open(my $fh, "< $dst_file")) {
        binmode($fh);
        $ctx->addfile($fh);
        $md5 = $ctx->hexdigest();
        close($fh);

      } else {
        die("Can't read $dst_file: $!");
      }

      $self->assert($expected_md5 eq $md5,
        test_msg("Expected '$expected_md5', got '$md5'"));

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

sub deflate_stor {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/deflate.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/deflate.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/deflate.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/deflate.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/deflate.group");

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

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");

  # Calculate the expected MD5 checksum of this file, for comparison with the
  # uploaded file.
  my $ctx = Digest::MD5->new();
  my $expected_md5;

  $ctx->add("Ab" x 8192);
  $expected_md5 = $ctx->hexdigest();

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutLinger => 1,

    IfModules => {
      'mod_deflate.c' => {
        DeflateEngine => 'on',
        DeflateLog => $log_file,
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
      $client->mode('Z');

      my $conn = $client->stor_raw('test.txt');
      unless ($conn) {
        die("STOR test.txt failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Ab" x 8192;
      my $deflated = compress($buf); 
      $conn->write($deflated, length($deflated));
      $conn->close();

      $client->quit();

      # Calculate the MD5 checksum of the uploaded file
      $ctx->reset();
      my $md5;

      if (open(my $fh, "< $test_file")) {
        binmode($fh);
        $ctx->addfile($fh);
        $md5 = $ctx->hexdigest();
        close($fh);

      } else {
        die("Can't read $test_file: $!");
      }

      $self->assert($expected_md5 eq $md5,
        test_msg("Expected '$expected_md5', got '$md5'"));
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

sub deflate_rest_stor {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/deflate.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/deflate.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/deflate.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/deflate.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/deflate.group");

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

  my $src_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Ab" x 8192;
    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  # Calculate the MD5 checksum of this file, for comparison with the
  # downloaded file.
  my $ctx = Digest::MD5->new();
  my $expected_md5;

  if (open(my $fh, "< $src_file")) {
    binmode($fh);
    $ctx->addfile($fh);
    $expected_md5 = $ctx->hexdigest();
    close($fh);

  } else {
    die("Can't read $src_file: $!");
  }

  my $offset = (-s $src_file) / 2;

  my $dst_file = File::Spec->rel2abs("$tmpdir/uploaded.txt");
  if (open(my $fh, "> $dst_file")) {
    print $fh "Ab" x 4096;
    unless (close($fh)) {
      die("Can't write $dst_file: $!");
    }

  } else {
    die("Can't open $dst_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutLinger => 1,

    AllowOverwrite => 'on',
    AllowRetrieveRestart => 'on',
    AllowStoreRestart => 'on',

    IfModules => {
      'mod_deflate.c' => {
        DeflateEngine => 'on',
        DeflateLog => $log_file,
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
      $client->type('binary');
      $client->mode('Z');
      $client->rest($offset);

      my $conn = $client->stor_raw('uploaded.txt');
      unless ($conn) {
        die("STOR uploaded.txt failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Ab" x 4096;
      my $deflated = compress($buf);
      $conn->write($deflated, length($deflated));
      $conn->close();

      $client->quit();

      # Calculate the MD5 checksum of the uploaded file
      $ctx->reset();
      my $md5;

      if (open(my $fh, "< $dst_file")) {
        binmode($fh);
        $ctx->addfile($fh);
        $md5 = $ctx->hexdigest();
        close($fh);

      } else {
        die("Can't read $dst_file: $!");
      }

      $self->assert($expected_md5 eq $md5,
        test_msg("Expected '$expected_md5', got '$md5'"));

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

sub deflate_stor_64kb_binary {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/deflate.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/deflate.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/deflate.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/deflate.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/deflate.group");

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

  my $input_file = File::Spec->rel2abs("t/etc/modules/mod_deflate/zmode.pdf");
  my $test_file = File::Spec->rel2abs("$tmpdir/zmode.pdf");

  # Calculate the expected MD5 checksum of this file, for comparison with the
  # uploaded file.
  my $ctx = Digest::MD5->new();
  my $expected_md5;

  if (open(my $fh, "< $input_file")) {
    binmode($fh);
    $ctx->addfile($fh);
    $expected_md5 = $ctx->hexdigest();
    close($fh);

  } else {
    die("Can't read $input_file: $!");
  }

  my $timeout_idle = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'deflate:20 DEFAULT:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_deflate.c' => {
        DeflateEngine => 'on',
        DeflateLog => $log_file,
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
      $client->type('binary');
      $client->mode('Z');

      my $zlevel = 7;

      my ($resp_code, $resp_msg) = $client->opts("MODE Z LEVEL $zlevel");

      my $expected;

      $expected = 200;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'OPTS MODE Z OK';
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      my $conn = $client->stor_raw('zmode.pdf');
      unless ($conn) {
        die("STOR zmode.pdf failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      if (open(my $fh, "< $input_file")) {
        my $buf;
        my $buflen;
        my $bufsz = 8192;
        my $total_read = 0;

        binmode($fh);

        my ($d, $status) = Compress::Raw::Zlib::Deflate->new({
          -AppendOutput => 1,
          -Level => $zlevel,
        });
        unless ($status == Z_OK) {
          die("Can't create deflation stream");
        }

        my $deflated;

        while (1) {
          $buflen = read($fh, $buf, $bufsz);
          unless (defined($buflen)) {
            die("Can't read from $input_file: $!");
          }

          if ($buflen == 0) {
            # EOF
            last;
          }

          $total_read += $buflen;

          # We don't want to use Compress::Zlib::compress() here because
          # it calls flush(Z_FINISH) every time, and we only want to use
          # Z_FINISH when we're done reading the file.

          $status = $d->deflate($buf, $deflated);
          unless ($status == Z_OK) {
            die("Error deflating data: " . $d->msg());
          }
        }

        $status = $d->flush($deflated, Z_FINISH);
        unless ($status == Z_OK) {
          die("Error deflating data: " . $d->msg());
        }

        my $deflated_len = length($deflated);

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "# writing $deflated_len compressed bytes\n";
        }

        my $upload_start = [gettimeofday];
        my $nwrote = $conn->write($deflated, $deflated_len, 25);
        my $upload_elapsed = tv_interval($upload_start);

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "# wrote $nwrote compressed bytes (elapsed time: $upload_elapsed)\n";
        }

        unless (defined($nwrote)) {
          die("Error writing to client: $!");
        }

        close($fh);

      } else {
        die("Can't read $input_file: $!");
      }

      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Transfer complete";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $client->quit();

      # Calculate the MD5 checksum of the uploaded file
      $ctx->reset();
      my $md5;

      if (open(my $fh, "< $test_file")) {
        binmode($fh);
        $ctx->addfile($fh);
        $md5 = $ctx->hexdigest();
        close($fh);

      } else {
        die("Can't read $test_file: $!");
      }

      $self->assert($expected_md5 eq $md5,
        test_msg("Expected '$expected_md5', got '$md5'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub deflate_stor_64kb_binary_chunks {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/deflate.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/deflate.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/deflate.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/deflate.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/deflate.group");

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

  my $input_file = File::Spec->rel2abs("t/etc/modules/mod_deflate/zmode.pdf");
  my $test_file = File::Spec->rel2abs("$tmpdir/zmode.pdf");

  # Calculate the expected MD5 checksum of this file, for comparison with the
  # uploaded file.
  my $ctx = Digest::MD5->new();
  my $expected_md5;

  if (open(my $fh, "< $input_file")) {
    binmode($fh);
    $ctx->addfile($fh);
    $expected_md5 = $ctx->hexdigest();
    close($fh);

  } else {
    die("Can't read $input_file: $!");
  }

  my $timeout_idle = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'deflate:20 DEFAULT:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_deflate.c' => {
        DeflateEngine => 'on',
        DeflateLog => $log_file,
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
      $client->type('binary');
      $client->mode('Z');

      my $zlevel = 7;

      my ($resp_code, $resp_msg) = $client->opts("MODE Z LEVEL $zlevel");

      my $expected;

      $expected = 200;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'OPTS MODE Z OK';
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      my $conn = $client->stor_raw('zmode.pdf');
      unless ($conn) {
        die("STOR zmode.pdf failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      if (open(my $fh, "< $input_file")) {
        my $buf;
        my $buflen;
        my $bufsz = 32768;

        binmode($fh);

        my ($d, $status) = Compress::Raw::Zlib::Deflate->new({
          -AppendOutput => 1,
          -Level => $zlevel,
        });
        unless ($status == Z_OK) {
          die("Can't create deflation stream");
        }

        my $deflated;

        while (1) {
          # As we read each chunk of data from disk, compress the chunk
          # and send it to the server.  The previous regression test buffered
          # all of the data from disk up, compressed it all in one go, and
          # uploaded it all at once.

          $buflen = read($fh, $buf, $bufsz);
          unless (defined($buflen)) {
            die("Can't read from $input_file: $!");
          }

          if ($buflen == 0) {
            # EOF
            last;
          }

          $deflated = undef;
          $status = $d->deflate($buf, $deflated);
          unless ($status == Z_OK) {
            die("Error deflating data: " . $d->msg());
          }

          $status = $d->flush($deflated, Z_SYNC_FLUSH);
          unless ($status == Z_OK) {
            die("Error flushing deflated data: " . $d->msg());
          }

          my $deflated_len = length($deflated);
          if ($deflated_len > 0) {
            if ($ENV{TEST_VERBOSE}) {
              print STDERR "# writing chunk: $deflated_len compressed bytes (from $buflen uncompressed bytes)\n";
            }

            my $upload_start = [gettimeofday];
            my $nwrote = $conn->write($deflated, $deflated_len, 25);
            my $upload_elapsed = tv_interval($upload_start);

            if ($ENV{TEST_VERBOSE}) {
              print STDERR "# wrote chunk: $nwrote compressed bytes (elapsed time: $upload_elapsed)\n";
            }

            unless (defined($nwrote)) {
              die("Error writing to client: $!");
            }
          }
        }

        $deflated = undef;
        $status = $d->flush($deflated, Z_FINISH);
        unless ($status == Z_OK) {
          die("Error deflating data: " . $d->msg());
        }

        my $deflated_len = length($deflated);
        if ($deflated_len > 0) {
          if ($ENV{TEST_VERBOSE}) {
            print STDERR "# writing final chunk: $deflated_len compressed bytes\n";
          }

          my $upload_start = [gettimeofday];
          my $nwrote = $conn->write($deflated, $deflated_len, 25);
          my $upload_elapsed = tv_interval($upload_start);

          if ($ENV{TEST_VERBOSE}) {
            print STDERR "# wrote final chunk: $nwrote compressed bytes (elapsed time: $upload_elapsed)\n";
          }

          unless (defined($nwrote)) {
            die("Error writing to client: $!");
          }
        }

        close($fh);

      } else {
        die("Can't read $input_file: $!");
      }

      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Transfer complete";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $client->quit();

      # Calculate the MD5 checksum of the uploaded file
      $ctx->reset();
      my $md5;

      if (open(my $fh, "< $test_file")) {
        binmode($fh);
        $ctx->addfile($fh);
        $md5 = $ctx->hexdigest();
        close($fh);

      } else {
        die("Can't read $test_file: $!");
      }

      $self->assert($expected_md5 eq $md5,
        test_msg("Expected '$expected_md5', got '$md5'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub deflate_tls_mode_z {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/deflate.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/deflate.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/deflate.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/deflate.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/deflate.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_deflate.c' => {
        DeflateEngine => 'on',
        DeflateLog => $log_file,
      },

      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      $client->quot('MODE', 'Z');

      my $resp_msg = $client->last_message();
      my $expected;

      # Now that we support MODE Z for FTPS connections (Issue #505), we
      # expect success here.
      $expected = '200 OK';
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
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub deflate_netio_close_bad_cmd_sequence_bug3828 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/deflate.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/deflate.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/deflate.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/deflate.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/deflate.group");

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutLinger => 1,

    IfModules => {
      'mod_deflate.c' => {
        DeflateEngine => 'on',
        DeflateLog => $log_file,
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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0);
      $client->login($user, $passwd);

      eval { $client->mlsd("DoesNotExist") };
      unless ($@) {
        die("MLSD succeeded unexpectedly");
      }

      $client->mode('Z');
      $client->port('127,0,0,1,4,5');
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

1;
