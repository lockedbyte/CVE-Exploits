package ProFTPD::Tests::Config::TransferOptions;

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
  transferoptions_ignore_ascii_download_bug4159 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  transferoptions_ignore_ascii_upload_bug4159 => {
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

sub transferoptions_ignore_ascii_download_bug4159 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $test_data = "Hello, World!\r\n";
  my $test_file = File::Spec->rel2abs("$tmpdir/test.dat");
  if (open(my $fh, "> $test_file")) {
    print $fh $test_data;
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    DefaultTransferMode => 'binary',
    TransferOptions => 'IgnoreASCII',

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
      # When run too quickly with the other tests, this test can fail.  So
      # pause a little here.
      sleep(1);

      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 1);
      $client->login($setup->{user}, $setup->{passwd});

      # Tell the server we'll be doing an ASCII transfer, BUT configure
      # the Net::FTP internals to expect binary data, so that we can properly
      # compare the data we transfer.
      $client->type('A');
      my $ftp = $client->{ftp};
      ${*$ftp}{net_ftp_type} = 'I';

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my ($resp_code, $resp_msg);
      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);
      $client->quit();

      # Make sure that proftpd did NOT perform ASCII translation, per our
      # configured TransferOption.
      my $buflen = length($buf);
      my $test_datalen = length($test_data);
      $self->assert($buf eq $test_data,
        test_msg("Downloaded data '$buf' ($buflen) did not match expected data '$test_data' ($test_datalen)"));
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

sub transferoptions_ignore_ascii_upload_bug4159 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'cmds');

  my $test_data = "Hello, World!\r\n";
  my $test_file = File::Spec->rel2abs("$tmpdir/test.dat");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    DefaultTransferMode => 'binary',
    TransferOptions => 'IgnoreASCII',

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
      # When run too quickly with the other tests, this test can fail.  So
      # pause a little here.
      sleep(1);

      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 1);
      $client->login($setup->{user}, $setup->{passwd});

      # Tell the server we'll be doing an ASCII transfer, BUT configure
      # the Net::FTP internals to expect binary data, so that we can properly
      # compare the data we transfer.
      $client->type('A');
      my $ftp = $client->{ftp};
      ${*$ftp}{net_ftp_type} = 'I';

      my $conn = $client->stor_raw($test_file);
      unless ($conn) {
        die("Failed to STOR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      $conn->write($test_data, length($test_data), 30);
      eval { $conn->close() };

      my ($resp_code, $resp_msg);
      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);
      $client->quit();

      # Make sure that proftpd did NOT perform ASCII translation, per our
      # configured TransferOption.
      if (open(my $fh, "< $test_file")) {
        local $/;
        my $buf = <$fh>;
        close($fh);

        my $buflen = length($buf);
        my $test_datalen = length($test_data);
        $self->assert($buf eq $test_data,
          test_msg("Downloaded data '$buf' ($buflen) did not match expected data '$test_data' ($test_datalen)"));

      } else {
        die("Can't read $test_file: $!");
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
