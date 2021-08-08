package ProFTPD::Tests::Config::TraceOptions;

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
  traceoptions_conn_ips => {
    order => ++$order,
    test_class => [qw(feature_trace forking)],
  },

  traceoptions_timestamp_millis => {
    order => ++$order,
    test_class => [qw(feature_trace forking)],
  },
};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub traceoptions_conn_ips {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/trace.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/trace.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/trace.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/trace.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/trace.group");

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

  my $trace_log = File::Spec->rel2abs("$tmpdir/trace.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $trace_log,
    Trace => 'DEFAULT:10',
    TraceOptions => '+ConnIPs',

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);
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

  if (open(my $fh, "< $trace_log")) {
    my $ok = 0;

    while (my $line = <$fh>) {
      chomp($line);

      my $expected = '\[\d+\]\s+\(client\s+(\S+), server\s+\S+\)\s+<(\S+):(\d+)>: (.*?)$';

      if ($line =~ /$expected/) {
        my $client_ip = $1;
        my $trace_channel = $2;
        my $trace_level = $3;
        my $trace_msg = $4;

        next unless $trace_channel eq 'command';

        my $expected = 'command';
        $self->assert($expected eq $trace_channel,
          test_msg("Expected '$expected', got '$trace_channel'"));

        $expected = 7;
        $self->assert($expected >= $trace_level,
          test_msg("Expected >= $expected, got $trace_level"));

        $expected = '127.0.0.1';
        $self->assert($expected eq $client_ip,
          test_msg("Expected '$expected', got '$client_ip'"));

        $ok = 1;
        last;
      }
    }

    close($fh);

    $self->assert($ok, test_msg("Missing expected TraceLog messages"));

  } else {
    die("Can't read $trace_log: $!");
  }

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub traceoptions_timestamp_millis {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/trace.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/trace.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/trace.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/trace.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/trace.group");

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

  my $trace_log = File::Spec->rel2abs("$tmpdir/trace.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $trace_log,
    Trace => 'DEFAULT:10',
    TraceOptions => '+TimestampMillis',

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);
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

  if (open(my $fh, "< $trace_log")) {
    my $ok = 0;

    while (my $line = <$fh>) {
      chomp($line);

      my $expected = '\d+:\d+:\d+,\d+\s+\[\d+\]\s+<(\S+):(\d+)>: (.*?)$';

      if ($line =~ /$expected/) {
        my $trace_channel = $1;
        my $trace_level = $2;
        my $trace_msg = $3;

        next unless $trace_channel eq 'command';

        my $expected = 'command';
        $self->assert($expected eq $trace_channel,
          test_msg("Expected '$expected', got '$trace_channel'"));

        $expected = 7;
        $self->assert($expected >= $trace_level,
          test_msg("Expected >= $expected, got $trace_level"));

        $ok = 1;
        last;
      }
    }

    close($fh);

    $self->assert($ok, test_msg("Missing expected TraceLog messages"));

  } else {
    die("Can't read $trace_log: $!");
  }

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

1;
