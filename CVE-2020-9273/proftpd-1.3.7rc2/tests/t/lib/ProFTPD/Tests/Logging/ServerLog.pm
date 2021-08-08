package ProFTPD::Tests::Logging::ServerLog;

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
  serverlog_ifclass_matching_class_bug3832 => {
    order => ++$order,
    test_class => [qw(bug forking mod_ifsession)],
  },

  serverlog_ifclass_not_matching_class_bug3832 => {
    order => ++$order,
    test_class => [qw(bug forking mod_ifsession)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub serverlog_ifclass_matching_class_bug3832 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/serverlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/serverlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/serverlog.scoreboard");

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/serverlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/serverlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $server_log = File::Spec->rel2abs("$tmpdir/server.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    ServerLog => $server_log,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Append the mod_ifsession config to the end of the config file
  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Class local>
  From 127.0.0.1
</Class>

<IfClass local>
  ServerLog none
</IfClass>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);
      $client->type('ascii');

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 25);
      eval { $conn->close() };
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

  $self->assert(!-f $server_log,
    test_msg("Expected ServerLog $server_log to not exist, but it does"));

  if ($ex) {
    test_append_logfile($server_log, $ex);
    unlink($server_log);

    die($ex);
  }

  unlink($server_log);
}

sub serverlog_ifclass_not_matching_class_bug3832 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/serverlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/serverlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/serverlog.scoreboard");

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/serverlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/serverlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $server_log = File::Spec->rel2abs("$tmpdir/server.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    ServerLog => $server_log,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Append the mod_ifsession config to the end of the config file
  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Class local>
  From 127.0.0.1
</Class>

<IfClass !local>
  ServerLog none
</IfClass>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);
      $client->type('ascii');

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 25);
      eval { $conn->close() };
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

  if (open(my $fh, "< $server_log")) {
    my $sess_nlines = 0;
    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /session (opened|closed)/) {
        $sess_nlines++;
      }
    }

    close($fh);

    $self->assert($sess_nlines > 0,
      test_msg("Expected lines in $server_log, got none"));

  } else {
    die("Can't read $server_log: $!");
  }

  if ($ex) {
    test_append_logfile($server_log, $ex);
    unlink($server_log);

    die($ex);
  }

  unlink($server_log);
}

1;
