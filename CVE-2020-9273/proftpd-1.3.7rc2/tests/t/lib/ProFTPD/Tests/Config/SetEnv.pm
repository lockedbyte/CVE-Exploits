package ProFTPD::Tests::Config::SetEnv;

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
  setenv_serverroot => {
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

sub setenv_serverroot {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";

  my $server_root = File::Spec->rel2abs($tmpdir);

  my $pid_path = File::Spec->rel2abs("$tmpdir/config.pid");
  my $pid_file = '%{env:SERVER_ROOT}/config.pid';
  my $scoreboard_file = '%{env:SERVER_ROOT}/config.scoreboard';

  my $log_file = test_get_logfile();

  my $auth_user_path = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_user_file = '%{env:SERVER_ROOT}/config.passwd';

  my $auth_group_path = File::Spec->rel2abs("$tmpdir/config.group");
  my $auth_group_file = '%{env:SERVER_ROOT}/config.group';

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

  auth_user_write($auth_user_path, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_path, $group, $gid, $user);

  my $config = [
    "SetEnv SERVER_ROOT $server_root",
    "PidFile $pid_file",
    "ScoreboardFile $scoreboard_file",
    "SystemLog $log_file",

    'AllowOverwrite on',
    'AllowStoreRestart on',
    "AuthUserFile $auth_user_file",
    "AuthGroupFile $auth_group_file",
    'DefaultChdir ~',

    '<IfModule mod_delay.c>',
    '  DelayEngine off',
    '</IfModule>',
  ];

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

      my $conn = $client->stor_raw('test.txt');
      unless ($conn) {
        die("Failed to STOR test.txt: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Hello, World!\n";
      $conn->write($buf, length($buf), 25);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
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
  server_stop($pid_path);

  $self->assert_child_ok($pid);

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

1;
