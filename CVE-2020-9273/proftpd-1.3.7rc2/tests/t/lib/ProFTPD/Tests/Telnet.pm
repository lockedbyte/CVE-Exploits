package ProFTPD::Tests::Telnet;

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
  telnet_iac_bug3521 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  telnet_iac_bug3697 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  # Check for the required Perl modules:
  #
  #  Net-Telnet

  my $required = [qw(
    Net::Telnet
  )];

  foreach my $req (@$required) {
    eval "use $req";
    if ($@) {
      print STDERR "\nWARNING:\n + Module '$req' not found, skipping all tests\n";

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Unable to load $req: $@\n";
      }

      return qw(testsuite_empty_test);
    }
  }

  return testsuite_get_runnable_tests($TESTS);
}

sub telnet_iac_bug3521 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/telnet.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/telnet.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/telnet.scoreboard");

  my $log_file = File::Spec->rel2abs("tests.log");

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/telnet.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/telnet.group");

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

  require Net::Telnet;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(1);

      # To reproduce Bug#3521, we only need to connect to the server,
      # then issue a Telnet IAC at the right time.

      my $client = Net::Telnet->new(
        Host => '127.0.0.1',
        Port => $port,
        Timeout => 3,
        Errmode => 'return',
      );

      my $buf = "USER ";

      # In proftpd-1.3.2, the size would be 1016:
      #   PR_TUNABLE_BUFFER_SIZE (1024) - 3 - 5 ("USER ")
      #
      # I.e.: $buf .= ("A" x 1016);

      $buf .= ("A" x 4096);

      $buf .= chr(Net::Telnet::TELNET_IAC());
      $buf .= "Z" x 64;

      my $res = $client->cmd(
        String => $buf,
        Prompt => "/$user/",
      );

      if ($res) {
        die("USER succeeded expectedly");
      }

      my $ex = $client->errmsg();    
      unless ($ex =~ /^command\s+timed/) {
        die("Unexpected exception thrown: $ex");
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
    die($ex);
  }

  unlink($log_file);
}

sub telnet_iac_bug3697 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/telnet.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/telnet.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/telnet.scoreboard");

  my $log_file = File::Spec->rel2abs("tests.log");

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/telnet.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/telnet.group");

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

  # To reproduce Bug#3697, we expect a filename with a single \377 (decimal 255)
  # character in it.

  my $filename = "test";
  $filename .= chr(Net::Telnet::TELNET_IAC());
  $filename .= ".txt";

  my $test_file = File::Spec->rel2abs("$tmpdir/$filename");

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

  require Net::Telnet;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(1);

      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);

      my $name = "test";
      $name .= chr(Net::Telnet::TELNET_IAC());
      $name .= chr(Net::Telnet::TELNET_IAC());
      $name .= ".txt";

      my $conn = $client->stor_raw($name);
      unless ($conn) {
        die("STOR failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Foo!\n";
      $conn->write($buf, length($buf));
      $conn->close();

      my ($resp_code, $resp_msg);
      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Transfer complete";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $self->assert(-f $test_file,
        test_msg("File $test_file does not exist as expected"));
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

  unlink($log_file);
}

1;
