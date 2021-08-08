package ProFTPD::Tests::Utils::ftpcount;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use File::Path qw(mkpath rmtree);
use File::Spec;
use IO::Handle;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  ftpcount_ok => {
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

sub ftpcount_wait_alarm {
  # We merely need to interrupt the current process by throwing an exception.
  # Messy, but it gets the job done (it's necessary, at least, on a
  # Mac OSX 10.4 machine).
  die();
}

sub ftpcount {
  my $scoreboard_file = shift;
  my $output_file = shift;
  my $ftpcount_wait_timeout = shift;
  $ftpcount_wait_timeout = 1 unless defined($ftpcount_wait_timeout);

  my $ftpcount_bin;
  if ($ENV{PROFTPD_TEST_PATH}) {
    $ftpcount_bin = "$ENV{PROFTPD_TEST_PATH}/../ftpcount";

  } else {
    $ftpcount_bin = '../ftpcount';
  }

  my $cmd = "$ftpcount_bin -f $scoreboard_file > $output_file 2>/dev/null &";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing ftpcount: $cmd\n";
  }

  eval {
    $SIG{ALRM} = \&ftpcount_wait_alarm;
    alarm($ftpcount_wait_timeout);
    system($cmd);
    alarm(0);
    $SIG{ALRM} = 'DEFAULT';
  };
}

sub ftpcount_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ftpcount.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ftpcount.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ftpcount.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/exec.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/exec.group");

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

  my $ftpcount_file = File::Spec->rel2abs("$tmpdir/ftpcount.txt");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

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
      sleep(1);

      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);

      # Before we stop the server, use ftpcount to read the scoreboard
      ftpcount($scoreboard_file, $ftpcount_file);

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
    die($ex);
  }

  my $lines = [];
  if (open(my $fh, "< $ftpcount_file")) {
    while (my $line = <$fh>) {
      chomp($line);
      push(@$lines, $line);
    }

    close($fh);

  } else {
    die("Can't read $ftpcount_file: $!");
  }

  my $expected = 2;

  my $count = scalar(@$lines);
  $self->assert($expected == $count,
    test_msg("Expected $expected, got $count"));

  my $ok = 0;
  foreach my $line (@$lines) {
    chomp($line);

    if ($line =~ /^Service class\s+\-\s+(\d+) user/) {
      my $user_count = $1;

      $expected = 1;
      $self->assert($expected eq $user_count,
        test_msg("Expected '$expected', got '$user_count'"));

      $ok = 1;
    }
  }

  $self->assert($ok,
    test_msg("Unexpected ftpcount output (expected user count not found)"));

  unlink($log_file);
}

1;
