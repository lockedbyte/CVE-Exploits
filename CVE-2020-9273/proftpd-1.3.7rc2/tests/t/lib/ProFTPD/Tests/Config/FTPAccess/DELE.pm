package ProFTPD::Tests::Config::FTPAccess::DELE;

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
  dele_bug2321 => {
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

sub dele_bug2321 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/limit.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/limit.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/limit.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/limit.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/limit.group");

  # As per Bug#2321, the reproduction layout looks like:
  #
  #  $root/web/ 
  #  $root/web/.ftpaccess
  #  $root/users/$user/
  #  $root/users/$user/web -> $root/web/
  #
  # The .ftpaccess file should contain:
  #
  #  <Limit ALL>
  #    AllowUser $user
  #    DenyAll
  #  </Limit>

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs("$tmpdir/users/$user");
  my $uid = 500;
  my $gid = 500;

  mkpath($home_dir);

  my $web_dir = File::Spec->rel2abs("$tmpdir/web");
  mkpath($web_dir);

  my $test_dir = File::Spec->rel2abs("$tmpdir/users/$user/web/testdir");
  my $real_test_dir = File::Spec->rel2abs("$web_dir/testdir");
  my $real_test_file = File::Spec->rel2abs("$web_dir/test.txt");

  my $ftpaccess_file = File::Spec->rel2abs("$tmpdir/web/.ftpaccess");
  if (open(my $fh, "> $ftpaccess_file")) {
    print $fh <<EOL;
<Limit ALL>
  AllowUser $user
  DenyAll
</Limit>
EOL

    unless (close($fh)) {
      die("Can't write $ftpaccess_file: $!");
    }

  } else {
    die("Can't open $ftpaccess_file: $!");
  }

  unless (symlink($web_dir, "$home_dir/web")) {
    die("Can't symlink $web_dir to $home_dir/web: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $web_dir)) {
      die("Can't set perms on $home_dir, $web_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $web_dir)) {
      die("Can't set owner of $home_dir, $web_dir to $uid/$gid: $!");
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

    AllowOverride => 'on',

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
      $client->cwd($home_dir);

      # STOR web/test.txt
      # MKD web/testdir/
      # DELE web/test.txt
      # RMD web/testdir/

      my ($resp_code, $resp_msg);

      my $conn = $client->stor_raw("web/test.txt");
      unless ($conn) {
        die("Failed to STOR web/test.txt: " . $client->response_code() .
          " " . $client->response_msg());
      }

      my $buf = "Foo!\n";
      $conn->write($buf, length($buf));
      $conn->close();

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Transfer complete";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      ($resp_code, $resp_msg) = $client->mkd("web/testdir");

      $expected = 257;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "\"$test_dir\" - Directory successfully created";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      unless (-f $real_test_file) {
        die("File $real_test_file does not exist");
      }

      unless (-d $real_test_dir) {
        die("Directory $real_test_dir does not exist");
      }

      ($resp_code, $resp_msg) = $client->dele("web/test.txt");

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "DELE command successful";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      ($resp_code, $resp_msg) = $client->rmd("web/testdir");

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "RMD command successful";
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

1;
