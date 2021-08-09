package ProFTPD::Tests::Modules::mod_auth_otp;

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
  auth_otp_hotp_host => {
    order => ++$order,
    test_class => [qw(forking mod_auth_otp mod_sql mod_sql_sqlite)],
  },

  # HOTP tests
  auth_otp_hotp_login => {
    order => ++$order,
    test_class => [qw(forking mod_auth_otp mod_sql mod_sql_sqlite)],
  },

  auth_otp_consecutive_hotp_logins => {
    order => ++$order,
    test_class => [qw(forking mod_auth_otp mod_sql mod_sql_sqlite)],
  },

  auth_otp_hotp_unconfigured_user => {
    order => ++$order,
    test_class => [qw(forking mod_auth_otp mod_sql mod_sql_sqlite)],
  },

  auth_otp_hotp_authoritative => {
    order => ++$order,
    test_class => [qw(forking mod_auth_otp mod_sql mod_sql_sqlite)],
  },

  # TOTP tests
  auth_otp_totp_login => {
    order => ++$order,
    test_class => [qw(forking mod_auth_otp mod_sql mod_sql_sqlite)],
  },

  auth_otp_consecutive_totp_logins => {
    order => ++$order,
    test_class => [qw(forking mod_auth_otp mod_sql mod_sql_sqlite)],
  },

  auth_otp_totp_unconfigured_user => {
    order => ++$order,
    test_class => [qw(forking mod_auth_otp mod_sql mod_sql_sqlite)],
  },

  auth_otp_totp_authoritative => {
    order => ++$order,
    test_class => [qw(forking mod_auth_otp mod_sql mod_sql_sqlite)],
  },

  # AuthOTPOptions tests
  auth_otp_opt_std_response => {
    order => ++$order,
    test_class => [qw(forking mod_auth_otp mod_sql mod_sql_sqlite)],
  },

  auth_otp_opt_require_table_entry => {
    order => ++$order,
    test_class => [qw(forking mod_auth_otp mod_sql mod_sql_sqlite)],
  },

  auth_otp_opt_require_table_entry_authoritative => {
    order => ++$order,
    test_class => [qw(forking mod_auth_otp mod_sql mod_sql_sqlite)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  # Check for the required Perl modules:
  #
  #  Authen-OATH
  #  MIME-Base32

  my $required = [qw(
    Authen::OATH
    MIME::Base32
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

sub build_db {
  my $cmd = shift;
  my $db_script = shift;
  my $db_file = shift;
  my $check_exit_status = shift;
  $check_exit_status = 0 unless defined $check_exit_status;

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Executing sqlite3: $cmd\n";
  }

  my @output = `$cmd`;
  my $exit_status = $?;

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Output: ", join('', @output), "\n";
  }

  if ($check_exit_status) {
    if ($? != 0) {
      croak("'$cmd' failed");
    }
  }

  # Make sure that, if we're running as root, the database file has
  # the permissions/privs set for use by proftpd
  if ($< == 0) {
    unless (chmod(0666, $db_file)) {
      croak("Can't set perms on $db_file to 0666: $!");
    }
  }

  unlink($db_script);
  return 1;
}

sub auth_otp_hotp_host {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'auth_otp');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create HOTP tables
  my $db_script = File::Spec->rel2abs("$tmpdir/hotp.sql");

  # mod_auth_otp wants this secret to be base32-encoded, for interoperability
  # with Google Authenticator.
  require MIME::Base32;
  MIME::Base32->import('RFC');

  my $secret = 'Sup3rS3Cr3t';
  my $base32_secret = MIME::Base32::encode($secret);
  my $counter = 777;

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE auth_otp (
  user TEXT PRIMARY KEY,
  secret TEXT,
  counter INTEGER
);
INSERT INTO auth_otp (user, secret, counter) VALUES ('$setup->{user}', '$base32_secret', $counter);

EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script, $db_file);

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'auth:20 auth_otp:20 events:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    DefaultServer => 'on',
    ServerName => '"Default Server"',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_auth_otp.c' => {
        AuthOTPEngine => 'off',
      },

      'mod_sql.c' => {
        SQLEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($setup->{config_file},
    $config);

  my $host = 'localhost';

  if (open(my $fh, ">> $setup->{config_file}")) {
    print $fh <<EOC;
# This virtual host is name-based
<VirtualHost 127.0.0.1>
  Port $port
  ServerAlias $host
  ServerName "OTP Server"

  AuthUserFile $setup->{auth_user_file}
  AuthGroupFile $setup->{auth_group_file}

  <IfModule mod_delay.c>
    DelayEngine off
  </IfModule>

  <IfModule mod_auth_otp.c>
    AuthOTPEngine on
    AuthOTPLog $setup->{log_file}
    AuthOTPAlgorithm hotp
    AuthOTPTable sql:/get-user-hotp/update-user-hotp
  </IfModule>

  <IfModule mod_sql.c>
    SQLEngine log
    SQLBackend sqlite3
    SQLConnectInfo $db_file
    SQLLogFile $setup->{log_file}

    SQLNamedQuery get-user-hotp SELECT "secret, counter FROM auth_otp WHERE user = \'%{0}\'"
    SQLNamedQuery update-user-hotp UPDATE "counter = %{1} WHERE user = \'%{0}\'" auth_otp
  </IfModule>
</VirtualHost>
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

  require Authen::OATH;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(2);

      my $oath = Authen::OATH->new();
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      my ($resp_code, $resp_msg) = $client->host($host);
      my $expected = 220;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      # Calculate HOTP
      my $hotp = $oath->hotp($secret, $counter);
      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Generated HOTP $hotp for counter ", $counter, "\n";
      }

      $client->login($setup->{user}, $hotp);
      $client->quit();
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

sub auth_otp_hotp_login {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'auth_otp');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create HOTP tables
  my $db_script = File::Spec->rel2abs("$tmpdir/hotp.sql");

  # mod_auth_otp wants this secret to be base32-encoded, for interoperability
  # with Google Authenticator.
  require MIME::Base32;
  MIME::Base32->import('RFC');

  my $secret = 'Sup3rS3Cr3t';
  my $base32_secret = MIME::Base32::encode($secret);
  my $counter = 777;

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE auth_otp (
  user TEXT PRIMARY KEY,
  secret TEXT,
  counter INTEGER
);
INSERT INTO auth_otp (user, secret, counter) VALUES ('$setup->{user}', '$base32_secret', $counter);

EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script, $db_file);

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'auth:20 auth_otp:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_auth_otp.c' => {
        AuthOTPEngine => 'on',
        AuthOTPLog => $setup->{log_file},
        AuthOTPAlgorithm => 'hotp',

        # Assumes default table names, column names
        AuthOTPTable => 'sql:/get-user-hotp/update-user-hotp',
      },

      'mod_sql.c' => [
        'SQLEngine log',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $setup->{log_file}",

        'SQLNamedQuery get-user-hotp SELECT "secret, counter FROM auth_otp WHERE user = \'%{0}\'"',
        'SQLNamedQuery update-user-hotp UPDATE "counter = %{1} WHERE user = \'%{0}\'" auth_otp',
      ],
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

  require Authen::OATH;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(2);

      my $oath = Authen::OATH->new();
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # Calculate HOTP
      my $hotp = $oath->hotp($secret, $counter);
      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Generated HOTP $hotp for counter ", $counter, "\n";
      }

      $client->login($setup->{user}, $hotp);
      $client->quit();
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

sub auth_otp_consecutive_hotp_logins {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'auth_otp');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create HOTP tables
  my $db_script = File::Spec->rel2abs("$tmpdir/hotp.sql");

  # mod_auth_otp wants this secret to be base32-encoded, for interoperability
  # with Google Authenticator.
  require MIME::Base32;
  MIME::Base32->import('RFC');

  my $secret = 'Sup3rS3Cr3t';
  my $base32_secret = MIME::Base32::encode($secret);
  my $counter = 777;

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE auth_otp (
  user TEXT PRIMARY KEY,
  secret TEXT,
  counter INTEGER
);
INSERT INTO auth_otp (user, secret, counter) VALUES ('$setup->{user}', '$base32_secret', $counter);

EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script, $db_file);

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_auth_otp.c' => {
        AuthOTPEngine => 'on',
        AuthOTPLog => $setup->{log_file},
        AuthOTPAlgorithm => 'hotp',

        # Assumes default table names, column names
        AuthOTPTable => 'sql:/get-user-hotp/update-user-hotp',
      },

      'mod_sql.c' => [
        'SQLEngine log',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $setup->{log_file}",

        'SQLNamedQuery get-user-hotp SELECT "secret, counter FROM auth_otp WHERE user = \'%{0}\'"',
        'SQLNamedQuery update-user-hotp UPDATE "counter = %{1} WHERE user = \'%{0}\'" auth_otp',
      ],
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

  require Authen::OATH;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(2);

      my $oath = Authen::OATH->new();
      my $nattempts = 5;
      my $ok = 0;
    
      for (my $i = 0; $i < $nattempts; $i++) { 
        my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

        # Calculate HOTP
        my $next_counter = $counter + $i;
        my $hotp = $oath->hotp($secret, $next_counter);
        if ($ENV{TEST_VERBOSE}) {
          print STDERR "# Generated HOTP $hotp for counter $next_counter\n";
        }

        eval { $client->login($setup->{user}, $hotp) };
        if ($@) {
          next;
        }

        $client->quit();
        $ok = 1;
        last;
      }

      $self->assert($ok, test_msg("Failed to login successfully using HOTP"));
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

sub auth_otp_hotp_unconfigured_user {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'auth_otp');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create HOTP tables
  my $db_script = File::Spec->rel2abs("$tmpdir/hotp.sql");

  # mod_auth_otp wants this secret to be base32-encoded, for interoperability
  # with Google Authenticator.
  require MIME::Base32;
  MIME::Base32->import('RFC');

  my $secret = 'Sup3rS3Cr3t';
  my $base32_secret = MIME::Base32::encode($secret);
  my $counter = 777;

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE auth_otp (
  user TEXT PRIMARY KEY,
  secret TEXT,
  counter INTEGER
);

EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script, $db_file);

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_auth_otp.c' => {
        AuthOTPEngine => 'on',
        AuthOTPLog => $setup->{log_file},
        AuthOTPAlgorithm => 'hotp',

        # Assumes default table names, column names
        AuthOTPTable => 'sql:/get-user-hotp/update-user-hotp',
      },

      'mod_sql.c' => [
        'SQLEngine log',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $setup->{log_file}",

        'SQLNamedQuery get-user-hotp SELECT "secret, counter FROM auth_otp WHERE user = \'%{0}\'"',
        'SQLNamedQuery update-user-hotp UPDATE "counter = %{1} WHERE user = \'%{0}\'" auth_otp',
      ],
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

  require Authen::OATH;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(2);

      my $oath = Authen::OATH->new();
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # Calculate HOTP
      my $hotp = $oath->hotp($secret, $counter);
      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Generated HOTP $hotp for counter ", $counter, "\n";
      }

      eval { $client->login($setup->{user}, $hotp) };
      unless ($@) {
        die("HOTP login for user $setup->{user} succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected = 530;
      $self->assert($resp_code == $expected,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'Login incorrect.';
      $self->assert($resp_msg eq $expected,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      # Try again, this time using the real password.  Login should
      # succeed, since we have not configured mod_auth_otp to be authoritative.
      $client->login($setup->{user}, $setup->{passwd});

      $client->quit();
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

sub auth_otp_hotp_authoritative {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'auth_otp');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create HOTP tables
  my $db_script = File::Spec->rel2abs("$tmpdir/hotp.sql");

  # mod_auth_otp wants this secret to be base32-encoded, for interoperability
  # with Google Authenticator.
  require MIME::Base32;
  MIME::Base32->import('RFC');

  my $secret = 'Sup3rS3Cr3t';
  my $base32_secret = MIME::Base32::encode($secret);
  my $counter = 777;

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE auth_otp (
  user TEXT PRIMARY KEY,
  secret TEXT,
  counter INTEGER
);
INSERT INTO auth_otp (user, secret, counter) VALUES ('$setup->{user}', '$base32_secret', 1);

EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script, $db_file);

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    AuthOrder => 'mod_auth_otp.c* mod_auth_file.c',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_auth_otp.c' => {
        AuthOTPEngine => 'on',
        AuthOTPLog => $setup->{log_file},
        AuthOTPAlgorithm => 'hotp',

        # Assumes default table names, column names
        AuthOTPTable => 'sql:/get-user-hotp/update-user-hotp',
      },

      'mod_sql.c' => [
        'SQLEngine log',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $setup->{log_file}",

        'SQLNamedQuery get-user-hotp SELECT "secret, counter FROM auth_otp WHERE user = \'%{0}\'"',
        'SQLNamedQuery update-user-hotp UPDATE "counter = %{1} WHERE user = \'%{0}\'" auth_otp',
      ],
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

  require Authen::OATH;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(2);

      my $oath = Authen::OATH->new();
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # Calculate HOTP
      my $hotp = $oath->hotp($secret, $counter);
      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Generated HOTP $hotp for counter ", $counter, "\n";
      }

      eval { $client->login($setup->{user}, $hotp) };
      unless ($@) {
        die("HOTP login for user $setup->{user} succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected = 530;
      $self->assert($resp_code == $expected,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'Login incorrect.';
      $self->assert($resp_msg eq $expected,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      # Try again, this time using the real password.  Login should
      # still fail, since we require the OTP to be valid.
      eval { $client->login($setup->{user}, $setup->{passwd}) };
      unless ($@) {
        die("Password login for user $setup->{user} succeeded unexpectedly");
      }

      $client->quit();
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

sub auth_otp_totp_login {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'auth_otp');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create TOTP tables
  my $db_script = File::Spec->rel2abs("$tmpdir/totp.sql");

  # mod_auth_otp wants this secret to be base32-encoded, for interoperability
  # with Google Authenticator.
  require MIME::Base32;
  MIME::Base32->import('RFC');

  my $secret = 'Sup3rS3Cr3t';
  my $base32_secret = MIME::Base32::encode($secret);

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE auth_otp (
  user TEXT PRIMARY KEY,
  secret TEXT,
  counter INTEGER
);
INSERT INTO auth_otp (user, secret, counter) VALUES ('$setup->{user}', '$base32_secret', 0);

EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script, $db_file);

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_auth_otp.c' => {
        AuthOTPEngine => 'on',
        AuthOTPLog => $setup->{log_file},
        AuthOTPAlgorithm => 'totp',

        # Assumes default table names, column names
        AuthOTPTable => 'sql:/get-user-totp/update-user-totp',
      },

      'mod_sql.c' => [
        'SQLEngine log',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $setup->{log_file}",

        'SQLNamedQuery get-user-totp SELECT "secret FROM auth_otp WHERE user = \'%{0}\'"',
        'SQLNamedQuery update-user-totp UPDATE "counter = %{1} WHERE user = \'%{0}\'" auth_otp',
      ],
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

  require Authen::OATH;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(2);

      my $oath = Authen::OATH->new();
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # Calculate TOTP
      my $totp = $oath->totp($secret);
      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Generated TOTP $totp for current time\n";
      }

      $client->login($setup->{user}, $totp);
      $client->quit();
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

sub auth_otp_consecutive_totp_logins {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'auth_otp');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create TOTP tables
  my $db_script = File::Spec->rel2abs("$tmpdir/totp.sql");

  # mod_auth_otp wants this secret to be base32-encoded, for interoperability
  # with Google Authenticator.
  require MIME::Base32;
  MIME::Base32->import('RFC');

  my $secret = 'Sup3rS3Cr3t';
  my $base32_secret = MIME::Base32::encode($secret);

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE auth_otp (
  user TEXT PRIMARY KEY,
  secret TEXT,
  counter INTEGER
);
INSERT INTO auth_otp (user, secret, counter) VALUES ('$setup->{user}', '$base32_secret', 0);

EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script, $db_file);

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_auth_otp.c' => {
        AuthOTPEngine => 'on',
        AuthOTPLog => $setup->{log_file},
        AuthOTPAlgorithm => 'totp',

        # Assumes default table names, column names
        AuthOTPTable => 'sql:/get-user-totp/update-user-totp',
      },

      'mod_sql.c' => [
        'SQLEngine log',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $setup->{log_file}",

        'SQLNamedQuery get-user-totp SELECT "secret FROM auth_otp WHERE user = \'%{0}\'"',
        'SQLNamedQuery update-user-totp UPDATE "counter = %{1} WHERE user = \'%{0}\'" auth_otp',
      ],
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

  require Authen::OATH;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(2);

      my $oath = Authen::OATH->new();
      my $nattempts = 3; 
      my $now = time();
      my $ok = 0;

      for (my $i = 0; $i < $nattempts; $i++) {
        my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

        # Calculate TOTP
        my $ts = $now;

        # Try one "time step" behind and ahead.
        if ($i == 0) {
          $ts = $now - 30;

        } elsif ($i == 2) {
          $ts = $now + 30;
        }

        my $totp = $oath->totp($secret, $ts);
        if ($ENV{TEST_VERBOSE}) {
          print STDERR "# Generated TOTP $totp for ", scalar(localtime($ts)), "\n";
        }

        eval { $client->login($setup->{user}, $totp) };
        if ($@) {
          next;
        }

        $client->quit();
        $ok = 1;
        last;
      }

      $self->assert($ok, test_msg("Failed to login successfully using TOTP"));
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

sub auth_otp_totp_unconfigured_user {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'auth_otp');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create HOTP tables
  my $db_script = File::Spec->rel2abs("$tmpdir/hotp.sql");

  # mod_auth_otp wants this secret to be base32-encoded, for interoperability
  # with Google Authenticator.
  require MIME::Base32;
  MIME::Base32->import('RFC');

  my $secret = 'Sup3rS3Cr3t';
  my $base32_secret = MIME::Base32::encode($secret);
  my $counter = 777;

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE auth_otp (
  user TEXT PRIMARY KEY,
  secret TEXT,
  counter INTEGER
);

EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script, $db_file);

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_auth_otp.c' => {
        AuthOTPEngine => 'on',
        AuthOTPLog => $setup->{log_file},
        AuthOTPAlgorithm => 'totp',

        # Assumes default table names, column names
        AuthOTPTable => 'sql:/get-user-totp/update-user-totp',
      },

      'mod_sql.c' => [
        'SQLEngine log',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $setup->{log_file}",

        'SQLNamedQuery get-user-totp SELECT "secret FROM auth_otp WHERE user = \'%{0}\'"',
        'SQLNamedQuery update-user-totp UPDATE "counter = %{1} WHERE user = \'%{0}\'" auth_otp',
      ],
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

  require Authen::OATH;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(2);

      my $oath = Authen::OATH->new();
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # Calculate TOTP
      my $totp = $oath->totp($secret);
      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Generated TOTP $totp for current time\n";
      }

      eval { $client->login($setup->{user}, $totp) };
      unless ($@) {
        die("TOTP login for user $setup->{user} succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected = 530;
      $self->assert($resp_code == $expected,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'Login incorrect.';
      $self->assert($resp_msg eq $expected,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      # Try again, this time using the real password.  Login should
      # succeed, since we have not configured mod_auth_otp to be authoritative.
      $client->login($setup->{user}, $setup->{passwd});

      $client->quit();
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

sub auth_otp_totp_authoritative {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'auth_otp');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create HOTP tables
  my $db_script = File::Spec->rel2abs("$tmpdir/hotp.sql");

  # mod_auth_otp wants this secret to be base32-encoded, for interoperability
  # with Google Authenticator.
  require MIME::Base32;
  MIME::Base32->import('RFC');

  my $secret = 'Sup3rS3Cr3t';
  my $base32_secret = MIME::Base32::encode($secret);
  my $counter = 777;

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE auth_otp (
  user TEXT PRIMARY KEY,
  secret TEXT,
  counter INTEGER
);
INSERT INTO auth_otp (user, secret) VALUES ('$setup->{user}', '$base32_secret');

EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script, $db_file);

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    AuthOrder => 'mod_auth_otp.c* mod_auth_file.c',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_auth_otp.c' => {
        AuthOTPEngine => 'on',
        AuthOTPLog => $setup->{log_file},
        AuthOTPAlgorithm => 'totp',

        # Assumes default table names, column names
        AuthOTPTable => 'sql:/get-user-totp/update-user-totp',
      },

      'mod_sql.c' => [
        'SQLEngine log',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $setup->{log_file}",

        'SQLNamedQuery get-user-totp SELECT "secret FROM auth_otp WHERE user = \'%{0}\'"',
        'SQLNamedQuery update-user-totp UPDATE "counter = %{1} WHERE user = \'%{0}\'" auth_otp',
      ],
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

  require Authen::OATH;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(2);

      my $oath = Authen::OATH->new();
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # Calculate TOTP
      my $ts = 10;
      my $totp = $oath->totp($secret, $ts);
      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Generated TOTP $totp for ", scalar(gmtime($ts)), "\n";
      }

      eval { $client->login($setup->{user}, $totp) };
      unless ($@) {
        die("TOTP login for user $setup->{user} succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected = 530;
      $self->assert($resp_code == $expected,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'Login incorrect.';
      $self->assert($resp_msg eq $expected,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      # Try again, this time using the real password.  Login should still
      # fail since mod_auth_otp is authoritative.
      eval { $client->login($setup->{user}, $setup->{passwd}) };
      unless ($@) {
        die("Password login for user $setup->{user} succeeded unexpectedly");
      }

      $client->quit();
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

sub auth_otp_opt_std_response {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'auth_otp');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create HOTP tables
  my $db_script = File::Spec->rel2abs("$tmpdir/hotp.sql");

  # mod_auth_otp wants this secret to be base32-encoded, for interoperability
  # with Google Authenticator.
  require MIME::Base32;
  MIME::Base32->import('RFC');

  my $secret = 'Sup3rS3Cr3t';
  my $base32_secret = MIME::Base32::encode($secret);
  my $counter = 777;

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE auth_otp (
  user TEXT PRIMARY KEY,
  secret TEXT,
  counter INTEGER
);
INSERT INTO auth_otp (user, secret, counter) VALUES ('$setup->{user}', '$base32_secret', $counter);

EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script, $db_file);

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_auth_otp.c' => {
        AuthOTPEngine => 'on',
        AuthOTPLog => $setup->{log_file},
        AuthOTPAlgorithm => 'hotp',
        AuthOTPOptions => 'StandardResponse',

        # Assumes default table names, column names
        AuthOTPTable => 'sql:/get-user-hotp/update-user-hotp',
      },

      'mod_sql.c' => [
        'SQLEngine log',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $setup->{log_file}",

        'SQLNamedQuery get-user-hotp SELECT "secret, counter FROM auth_otp WHERE user = \'%{0}\'"',
        'SQLNamedQuery update-user-hotp UPDATE "counter = %{1} WHERE user = \'%{0}\'" auth_otp',
      ],
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

  require Authen::OATH;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(2);

      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      my ($resp_code, $resp_msg) = $client->user($setup->{user});

      my $expected = 331;
      $self->assert($resp_code == $expected,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Password required for $setup->{user}";
      $self->assert($resp_msg eq $expected,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      $client->quit();
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

sub auth_otp_opt_require_table_entry {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'auth_otp');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create HOTP tables
  my $db_script = File::Spec->rel2abs("$tmpdir/hotp.sql");

  # mod_auth_otp wants this secret to be base32-encoded, for interoperability
  # with Google Authenticator.
  require MIME::Base32;
  MIME::Base32->import('RFC');

  my $secret = 'Sup3rS3Cr3t';
  my $base32_secret = MIME::Base32::encode($secret);
  my $counter = 777;

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE auth_otp (
  user TEXT PRIMARY KEY,
  secret TEXT,
  counter INTEGER
);
INSERT INTO auth_otp (user, secret, counter) VALUES ('$setup->{user}', '$base32_secret', $counter);

EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script, $db_file);

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_auth_otp.c' => {
        AuthOTPEngine => 'on',
        AuthOTPLog => $setup->{log_file},
        AuthOTPAlgorithm => 'hotp',
        AuthOTPOptions => 'RequireTableEntry',

        # Assumes default table names, column names
        AuthOTPTable => 'sql:/get-user-hotp/update-user-hotp',
      },

      'mod_sql.c' => [
        'SQLEngine log',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $setup->{log_file}",

        'SQLNamedQuery get-user-hotp SELECT "secret, counter FROM auth_otp WHERE user = \'%{0}\'"',
        'SQLNamedQuery update-user-hotp UPDATE "counter = %{1} WHERE user = \'%{0}\'" auth_otp',
      ],
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

  require Authen::OATH;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(2);

      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # Even though we have not configured an entry in the OTP table
      # for this user, and even though we are using the RequireTableEntry
      # option, password-based login should still succeed, because we
      # did not make mod_auth_otp authoritative.
      $client->login($setup->{user}, $setup->{passwd});

      $client->quit();
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

sub auth_otp_opt_require_table_entry_authoritative {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'auth_otp');

  my $db_file = File::Spec->rel2abs("$tmpdir/proftpd.db");

  # Build up sqlite3 command to create HOTP tables
  my $db_script = File::Spec->rel2abs("$tmpdir/hotp.sql");

  # mod_auth_otp wants this secret to be base32-encoded, for interoperability
  # with Google Authenticator.
  require MIME::Base32;
  MIME::Base32->import('RFC');

  my $secret = 'Sup3rS3Cr3t';
  my $base32_secret = MIME::Base32::encode($secret);
  my $counter = 777;

  if (open(my $fh, "> $db_script")) {
    print $fh <<EOS;
CREATE TABLE auth_otp (
  user TEXT PRIMARY KEY,
  secret TEXT,
  counter INTEGER
);
INSERT INTO auth_otp (user, secret, counter) VALUES ('$setup->{user}', '$base32_secret', $counter);

EOS

    unless (close($fh)) {
      die("Can't write $db_script: $!");
    }

  } else {
    die("Can't open $db_script: $!");
  }

  my $cmd = "sqlite3 $db_file < $db_script";
  build_db($cmd, $db_script, $db_file);

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    AuthOrder => 'mod_auth_otp.c* mod_auth_file.c',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_auth_otp.c' => {
        AuthOTPEngine => 'on',
        AuthOTPLog => $setup->{log_file},
        AuthOTPAlgorithm => 'hotp',
        AuthOTPOptions => 'RequireTableEntry',

        # Assumes default table names, column names
        AuthOTPTable => 'sql:/get-user-hotp/update-user-hotp',
      },

      'mod_sql.c' => [
        'SQLEngine log',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $setup->{log_file}",

        'SQLNamedQuery get-user-hotp SELECT "secret, counter FROM auth_otp WHERE user = \'%{0}\'"',
        'SQLNamedQuery update-user-hotp UPDATE "counter = %{1} WHERE user = \'%{0}\'" auth_otp',
      ],
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

  require Authen::OATH;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(2);

      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # We have not configured an entry in the OTP table for this user, and
      # we are using the RequireTableEntry option, AND we marked mod_auth_otp
      # as authoriative.  Thus password-based login should fail.
      eval { $client->login($setup->{user}, $setup->{passwd}) };
      unless ($@) {
        die("Password login succeeded unexpectedly");
      }

      $client->quit();
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
