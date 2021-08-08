package ProFTPD::Tests::Config::AllowForeignAddress;

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
  fxp_denied => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  fxp_denied_eprt => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  fxp_denied_by_class => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  fxp_allowed => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  fxp_allowed_eprt => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  fxp_allowed_by_class => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  fxp_allowed_2gb => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  # tls_fxp_allowed
};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub fxp_denied {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'config');

  my $src_file = File::Spec->rel2abs("$tmpdir/src.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, FXP World!\n";

    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/dst.txt");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    AllowForeignAddress => 'off',

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
      my $client1 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 1, 1);
      $client1->login($setup->{user}, $setup->{passwd});

      my $client2 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      $client2->login($setup->{user}, $setup->{passwd});

      # Get the PASV address from the first connection, and give it
      # to the second connection as a PORT command.
      my ($resp_code, $resp_msg) = $client1->pasv();

      my $expected = 227;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = '^Entering Passive Mode \(\d+,\d+,\d+,\d+,\d+,\d+\)';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      # Deliberately provide an IP address that does not match our source
      # IP address, to trigger the AllowForeignAddress restriction.
      my $port_addr = '1,2,3,4,192,6';
      eval { $client2->port($port_addr) };
      unless ($@) {
        die("PORT $port_addr succeeded unexpectedly");
      }

      $resp_code = $client2->response_code();
      $resp_msg = $client2->response_msg();

      $expected = 500;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'Illegal PORT command';
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      $client1->quit();
      $client2->quit();

      $self->assert(!-f $dst_file,
        test_msg("File $dst_file exists unexpectedly"));
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

  eval {
    if (open(my $fh, "< $setup->{log_file}")) {
      my $ok = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($line =~ /Refused PORT .*? \(address mismatch\)/) {
          $ok = 1;
          last;
        }
      }

      close($fh);

      $self->assert($ok, test_msg("Did not see expected log messages"));

    } else {
      die("Can't read $setup->{log_file}: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub fxp_denied_eprt {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'config');

  my $src_file = File::Spec->rel2abs("$tmpdir/src.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, FXP World!\n";

    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/dst.txt");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    AllowForeignAddress => 'off',

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
      my $client1 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 1, 1);
      $client1->login($setup->{user}, $setup->{passwd});

      my $client2 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      $client2->login($setup->{user}, $setup->{passwd});

      # Get the PASV address from the first connection, and give it
      # to the second connection as an EPRT command.
      my ($resp_code, $resp_msg) = $client1->pasv();

      my $expected = 227;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = '^Entering Passive Mode \(\d+,\d+,\d+,\d+,\d+,\d+\)';
      $self->assert(qr/$expected/, $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");

      # Deliberately provide an IP address that does not match our source
      # IP address, to trigger the AllowForeignAddress restriction.
      my $eprt_addr = '|1|1.2.3.4|49158|';
      eval { $client2->eprt($eprt_addr) };
      unless ($@) {
        die("EPRT $eprt_addr succeeded unexpectedly");
      }

      $resp_code = $client2->response_code();
      $resp_msg = $client2->response_msg();

      $expected = 500;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = 'Illegal EPRT command';
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");

      $client1->quit();
      $client2->quit();

      $self->assert(!-f $dst_file, "File $dst_file exists unexpectedly");
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

  eval {
    if (open(my $fh, "< $setup->{log_file}")) {
      my $ok = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($line =~ /Refused EPRT .*? \(address mismatch\)/) {
          $ok = 1;
          last;
        }
      }

      close($fh);

      $self->assert($ok, test_msg("Did not see expected log messages"));

    } else {
      die("Can't read $setup->{log_file}: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub fxp_denied_by_class {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'config');

  my $src_file = File::Spec->rel2abs("$tmpdir/src.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, FXP World!\n";

    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/dst.txt");

  my $class_name = 'allowed_fxp';

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    AllowForeignAddress => $class_name,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($setup->{config_file},
    $config);

  if (open(my $fh, ">> $setup->{config_file}")) {
    print $fh <<EOC;
<Class $class_name>
  From none
</Class>
EOC
    unless (close($fh)) {
      die("Can't write $setup->{config_file}: $!");
    }

  } else {
    die("Can't open $setup->{config_file}: $!");
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
      my $client1 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 1, 1);
      $client1->login($setup->{user}, $setup->{passwd});

      my $client2 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      $client2->login($setup->{user}, $setup->{passwd});

      # Get the PASV address from the first connection, and give it
      # to the second connection as a PORT command.
      my ($resp_code, $resp_msg) = $client1->pasv();

      my $expected = 227;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = '^Entering Passive Mode \(\d+,\d+,\d+,\d+,\d+,\d+\)';
      $self->assert(qr/$expected/, $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");

      # Deliberately provide an IP address that does not match our source
      # IP address, to trigger the AllowForeignAddress restriction.
      my $port_addr = '1,2,3,4,192,6';
      eval { $client2->port($port_addr) };
      unless ($@) {
        die("PORT $port_addr succeeded unexpectedly");
      }

      $resp_code = $client2->response_code();
      $resp_msg = $client2->response_msg();

      $expected = 500;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = 'Illegal PORT command';
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");

      $client1->quit();
      $client2->quit();

      $self->assert(!-f $dst_file,
        test_msg("File $dst_file exists unexpectedly"));
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

  eval {
    if (open(my $fh, "< $setup->{log_file}")) {
      my $ok = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "$line\n";
        }

        if ($line =~ /Refused PORT .*? \(address mismatch\)/) {
          $ok = 1;
          last;
        }
      }

      close($fh);

      $self->assert($ok, "Did not see expected log messages");

    } else {
      die("Can't read $setup->{log_file}: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub fxp_allowed {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'config');

  my $src_file = File::Spec->rel2abs("$tmpdir/src.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, FXP World!\n";

    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/dst.txt");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    AllowForeignAddress => 'on',

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
      my $client1 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 1, 1);
      $client1->login($setup->{user}, $setup->{passwd});

      my $client2 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      $client2->login($setup->{user}, $setup->{passwd});

      # Get the PASV address from the first connection, and give it
      # to the second connection as a PORT command.
      my ($resp_code, $resp_msg) = $client1->pasv();

      my $expected = 227;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = '^Entering Passive Mode \(\d+,\d+,\d+,\d+,\d+,\d+\)';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      # This will actually work, since both our connections are
      # from 127.0.0.1, which means we shouldn't run afoul of the
      # AllowForeignAddress limit.
      $resp_msg =~ /'^Entering Passive Mode \((\d+,\d+,\d+,\d+,\d+,\d+\))/;
      my $port_addr = $1;

      ($resp_code, $resp_msg) = $client2->port($port_addr);

      $expected = 200;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'PORT command successful';
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      my $tmpfile = 'tmpfile.bin';
      ($resp_code, $resp_msg) = $client1->stor($src_file, $tmpfile);
      $self->assert_transfer_ok($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client2->retr($tmpfile, $dst_file);
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client1->quit();
      $client2->quit();

      $self->assert(-f $dst_file,
        test_msg("File $dst_file does not exist as expected"));

      my $dst_size = -s $dst_file;
      my $expected = -s $src_file;
      $self->assert($expected == $dst_size,
        test_msg("Expected file size $expected, got $dst_size"));
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

sub fxp_allowed_eprt {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'config');

  my $src_file = File::Spec->rel2abs("$tmpdir/src.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, FXP World!\n";

    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/dst.txt");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    AllowForeignAddress => 'on',

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
      my $client1 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 1, 1);
      $client1->login($setup->{user}, $setup->{passwd});

      my $client2 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      $client2->login($setup->{user}, $setup->{passwd});

      # Get the PASV address from the first connection, and give it
      # to the second connection as an EPRT command.
      my ($resp_code, $resp_msg) = $client1->pasv();

      my $expected = 227;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = '^Entering Passive Mode \(\d+,\d+,\d+,\d+,\d+,\d+\)';
      $self->assert(qr/$expected/, $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");

      # This will actually work, since both our connections are
      # from 127.0.0.1, which means we shouldn't run afoul of the
      # AllowForeignAddress limit.
      $resp_msg =~ /^Entering Passive Mode \(\d+,\d+,\d+,\d+,(\d+),(\d+)\)/;

      my $eprt_port = (($1 << 8) | $2);
      my $eprt_addr = "|1|127.0.0.1|$eprt_port|";

      ($resp_code, $resp_msg) = $client2->eprt($eprt_addr);

      $expected = 200;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = 'EPRT command successful';
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");

      my $tmpfile = 'tmpfile.bin';
      ($resp_code, $resp_msg) = $client1->stor($src_file, $tmpfile);
      $self->assert_transfer_ok($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client2->retr($tmpfile, $dst_file);
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client1->quit();
      $client2->quit();

      $self->assert(-f $dst_file,
        "File $dst_file does not exist as expected");

      my $dst_size = -s $dst_file;
      my $expected = -s $src_file;
      $self->assert($expected == $dst_size,
        "Expected file size $expected, got $dst_size");
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

sub fxp_allowed_by_class {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'config');

  my $src_file = File::Spec->rel2abs("$tmpdir/src.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "Hello, FXP World!\n";

    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/dst.txt");

  my $class_name = 'allowed_fxp';

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    AllowForeignAddress => $class_name,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($setup->{config_file},
    $config);

  if (open(my $fh, ">> $setup->{config_file}")) {
    print $fh <<EOC;
<Class $class_name>
  From 127.0.0.0/8
</Class>
EOC
    unless (close($fh)) {
      die("Can't write $setup->{config_file}: $!");
    }

  } else {
    die("Can't open $setup->{config_file}: $!");
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
      my $client1 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 1, 1);
      $client1->login($setup->{user}, $setup->{passwd});

      my $client2 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      $client2->login($setup->{user}, $setup->{passwd});

      # Get the PASV address from the first connection, and give it
      # to the second connection as a PORT command.
      my ($resp_code, $resp_msg) = $client1->pasv();

      my $expected = 227;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = '^Entering Passive Mode \(\d+,\d+,\d+,\d+,\d+,\d+\)';
      $self->assert(qr/$expected/, $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");

      # This will actually work, since both our connections are
      # from 127.0.0.1, which means we shouldn't run afoul of the
      # AllowForeignAddress limit.
      $resp_msg =~ /'^Entering Passive Mode \((\d+,\d+,\d+,\d+,\d+,\d+\))/;
      my $port_addr = $1;

      ($resp_code, $resp_msg) = $client2->port($port_addr);

      $expected = 200;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = 'PORT command successful';
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");

      my $tmpfile = 'tmpfile.bin';
      ($resp_code, $resp_msg) = $client1->stor($src_file, $tmpfile);
      $self->assert_transfer_ok($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client2->retr($tmpfile, $dst_file);
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client1->quit();
      $client2->quit();

      $self->assert(-f $dst_file, "File $dst_file does not exist as expected");

      my $dst_size = -s $dst_file;
      my $expected = -s $src_file;
      $self->assert($expected == $dst_size,
        "Expected file size $expected, got $dst_size");
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

sub fxp_allowed_2gb {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'config');

  # See:
  #  http://serverfault.com/questions/660372/proftpd-1-34-and-files-size-2-gb

  my $src_file = File::Spec->rel2abs("$tmpdir/src.txt");
  if (open(my $fh, "> $src_file")) {
    # Seek to the 2GB limit, then fill the rest with 'A'
    unless (seek($fh, (2 ** 31), 0)) {
       die("Can't seek to 2GB length: $!");
    }

    print $fh "A" x 24;

    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/dst.txt");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    AllowForeignAddress => 'on',

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
      my $client1 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 1, 1);
      $client1->login($setup->{user}, $setup->{passwd});

      my $client2 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      $client2->login($setup->{user}, $setup->{passwd});

      # Get the PASV address from the first connection, and give it
      # to the second connection as a PORT command.
      my ($resp_code, $resp_msg) = $client1->pasv();

      my $expected = 227;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = '^Entering Passive Mode \(\d+,\d+,\d+,\d+,\d+,\d+\)';
      $self->assert(qr/$expected/, $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      # This will actually work, since both our connections are
      # from 127.0.0.1, which means we shouldn't run afoul of the
      # AllowForeignAddress limit.
      $resp_msg =~ /'^Entering Passive Mode \((\d+,\d+,\d+,\d+,\d+,\d+\))/;
      my $port_addr = $1;

      ($resp_code, $resp_msg) = $client2->port($port_addr);

      $expected = 200;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'PORT command successful';
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      my $tmpfile = 'tmpfile.bin';
      ($resp_code, $resp_msg) = $client1->stor($src_file, $tmpfile);
      $self->assert_transfer_ok($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client2->retr($tmpfile, $dst_file);
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client1->quit();
      $client2->quit();

      $self->assert(-f $dst_file,
        test_msg("File $dst_file does not exist as expected"));

      my $dst_size = -s $dst_file;
      my $expected = -s $src_file;
      $self->assert($expected == $dst_size,
        test_msg("Expected file size $expected, got $dst_size"));
    };
    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, 600) };
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
