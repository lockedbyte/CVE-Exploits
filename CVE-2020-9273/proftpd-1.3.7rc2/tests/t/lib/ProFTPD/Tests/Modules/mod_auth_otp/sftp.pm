package ProFTPD::Tests::Modules::mod_auth_otp::sftp;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use Data::Dumper;
use File::Spec;
use IO::Handle;
use POSIX qw(:fcntl_h);

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  # HOTP tests
  auth_otp_sftp_hotp_login_ok => {
    order => ++$order,
    test_class => [qw(forking mod_auth_otp mod_sftp mod_sql mod_sql_sqlite)],
  },

  auth_otp_sftp_hotp_login_failed => {
    order => ++$order,
    test_class => [qw(forking mod_auth_otp mod_sftp mod_sql mod_sql_sqlite)],
  },

  # TOTP tests
  auth_otp_sftp_totp_login_ok => {
    order => ++$order,
    test_class => [qw(forking mod_auth_otp mod_sftp mod_sql mod_sql_sqlite)],
  },

  auth_otp_sftp_totp_login_failed => {
    order => ++$order,
    test_class => [qw(forking mod_auth_otp mod_sftp mod_sql mod_sql_sqlite)],
  },

  auth_otp_sftp_totp_login_authoritative => {
    order => ++$order,
    test_class => [qw(forking mod_auth_otp mod_sftp mod_sql mod_sql_sqlite)],
  },

  auth_otp_sftp_totp_login_authoritative_failed => {
    order => ++$order,
    test_class => [qw(forking mod_auth_otp mod_sftp mod_sql mod_sql_sqlite)],
  },

  # Other tests
  auth_otp_sftp_password_failed => {
    order => ++$order,
    test_class => [qw(forking mod_auth_otp mod_sftp mod_sql mod_sql_sqlite)],
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
    Net::SSH2
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

sub set_up {
  my $self = shift;
  $self->SUPER::set_up(@_);

  # Make sure that mod_sftp does not complain about permissions on the hostkey
  # files.

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_auth_otp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_auth_otp/ssh_host_dsa_key');

  unless (chmod(0400, $rsa_host_key, $dsa_host_key)) {
    die("Can't set perms on $rsa_host_key, $dsa_host_key: $!");
  }
}

# Support routines

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

# Tests

sub auth_otp_sftp_hotp_login_ok {
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
  my $bad_secret = 'B@d1YK3pts3kr3T!';

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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_auth_otp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_auth_otp/ssh_host_dsa_key');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'ssh2:20 sftp:20 auth_otp:20',

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

      'mod_sftp.c' => [
        "SFTPEngine on",
        "SFTPLog $setup->{log_file}",
        "SFTPHostKey $rsa_host_key",
        "SFTPHostKey $dsa_host_key",

        # Configure mod_sftp to only use the keyboard-interactive method.
        # NOTE: How to handle this when both mod_auth_otp AND mod_sftp_pam
        # are used/loaded?
        'SFTPAuthMethods keyboard-interactive',
      ],

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
  require Net::SSH2;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(2);

      my $ssh2 = Net::SSH2->new();
      unless ($ssh2->connect('127.0.0.1', $port)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't connect to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      # Calculate HOTP
      my $oath = Authen::OATH->new();
      my $hotp = $oath->hotp($secret, $counter);
      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Generated HOTP $hotp for counter ", $counter, "\n";
      }

      unless ($ssh2->auth_keyboard($setup->{user}, $hotp)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      $ssh2->disconnect();
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

sub auth_otp_sftp_hotp_login_failed {
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
  my $bad_secret = 'B@d1YK3pts3kr3T!';

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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_auth_otp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_auth_otp/ssh_host_dsa_key');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'ssh2:20 auth_otp:20',

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

      'mod_sftp.c' => [
        "SFTPEngine on",
        "SFTPLog $setup->{log_file}",
        "SFTPHostKey $rsa_host_key",
        "SFTPHostKey $dsa_host_key",

        # Configure mod_sftp to only use the keyboard-interactive method.
        # NOTE: How to handle this when both mod_auth_otp AND mod_sftp_pam
        # are used/loaded?
        'SFTPAuthMethods keyboard-interactive',
      ],

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
  require Net::SSH2;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(2);

      my $ssh2 = Net::SSH2->new();
      unless ($ssh2->connect('127.0.0.1', $port)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't connect to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      # Calculate HOTP
      my $oath = Authen::OATH->new();
      my $hotp = $oath->hotp($bad_secret, $counter);
      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Generated HOTP $hotp for counter ", $counter, "\n";
      }

      if ($ssh2->auth_keyboard($setup->{user}, $hotp)) {
        die("Login to SSH2 server succeeded unexpectedly");
      }

      my ($err_code, $err_name, $err_str) = $ssh2->error();
      $self->assert($err_str, qr/Authentication failed \(keyboard-interactive\)/,
        test_msg("Expected 'Authentication failed (keyboard-interactive), got '$err_str'"));

      $ssh2->disconnect();
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

sub auth_otp_sftp_totp_login_ok {
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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_auth_otp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_auth_otp/ssh_host_dsa_key');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'ssh2:20 auth_otp:20',

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

      'mod_sftp.c' => [
        "SFTPEngine on",
        "SFTPLog $setup->{log_file}",
        "SFTPHostKey $rsa_host_key",
        "SFTPHostKey $dsa_host_key",

        # Configure mod_sftp to only use the keyboard-interactive method.
        # NOTE: How to handle this when both mod_auth_otp AND mod_sftp_pam
        # are used/loaded?
        'SFTPAuthMethods keyboard-interactive',
      ],

      'mod_sql.c' => [
        'SQLEngine log',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $setup->{log_file}",

        'SQLNamedQuery get-user-totp SELECT "secret, counter FROM auth_otp WHERE user = \'%{0}\'"',
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
  require Net::SSH2;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(2);

      my $ssh2 = Net::SSH2->new();
      unless ($ssh2->connect('127.0.0.1', $port)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't connect to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      # Calculate TOTP
      my $oath = Authen::OATH->new();
      my $totp = $oath->totp($secret);
      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Generated TOTP $totp for current time\n";
      }

      unless ($ssh2->auth_keyboard($setup->{user}, $totp)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      $ssh2->disconnect();
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

sub auth_otp_sftp_totp_login_failed {
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
  my $counter = 777;
  my $bad_secret = 'B@d1YK3pts3kr3T!';

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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_auth_otp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_auth_otp/ssh_host_dsa_key');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'ssh2:20 auth_otp:20',

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

      'mod_sftp.c' => [
        "SFTPEngine on",
        "SFTPLog $setup->{log_file}",
        "SFTPHostKey $rsa_host_key",
        "SFTPHostKey $dsa_host_key",

        # Configure mod_sftp to only use the keyboard-interactive method.
        # NOTE: How to handle this when both mod_auth_otp AND mod_sftp_pam
        # are used/loaded?
        'SFTPAuthMethods keyboard-interactive',
      ],

      'mod_sql.c' => [
        'SQLEngine log',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $setup->{log_file}",

        'SQLNamedQuery get-user-totp SELECT "secret, counter FROM auth_otp WHERE user = \'%{0}\'"',
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
  require Net::SSH2;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(2);

      my $ssh2 = Net::SSH2->new();
      unless ($ssh2->connect('127.0.0.1', $port)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't connect to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      # Calculate TOTP
      my $oath = Authen::OATH->new();
      my $totp = $oath->totp($bad_secret);
      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Generated TOTP $totp for current time\n";
      }

      if ($ssh2->auth_keyboard($setup->{user}, $totp)) {
        die("Login to SSH2 server succeeded unexpectedly");
      }

      my ($err_code, $err_name, $err_str) = $ssh2->error();
      $self->assert($err_str, qr/Authentication failed \(keyboard-interactive\)/,
        test_msg("Expected 'Authentication failed (keyboard-interactive), got '$err_str'"));

      $ssh2->disconnect();
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

sub auth_otp_sftp_totp_login_authoritative {
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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_auth_otp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_auth_otp/ssh_host_dsa_key');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'ssh2:20 auth_otp:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    AuthOrder => 'mod_auth_file.c mod_auth_otp.c*',

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

      'mod_sftp.c' => [
        "SFTPEngine on",
        "SFTPLog $setup->{log_file}",
        "SFTPHostKey $rsa_host_key",
        "SFTPHostKey $dsa_host_key",

        # Configure mod_sftp to only use the keyboard-interactive method.
        # NOTE: How to handle this when both mod_auth_otp AND mod_sftp_pam
        # are used/loaded?
        'SFTPAuthMethods keyboard-interactive',
      ],

      'mod_sql.c' => [
        'SQLEngine log',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $setup->{log_file}",

        'SQLNamedQuery get-user-totp SELECT "secret, counter FROM auth_otp WHERE user = \'%{0}\'"',
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
  require Net::SSH2;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(2);

      my $ssh2 = Net::SSH2->new();
      unless ($ssh2->connect('127.0.0.1', $port)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't connect to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      # Calculate TOTP
      my $oath = Authen::OATH->new();
      my $totp = $oath->totp($secret);
      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Generated TOTP $totp for current time\n";
      }

      unless ($ssh2->auth_keyboard($setup->{user}, $totp)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      $ssh2->disconnect();
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

sub auth_otp_sftp_totp_login_authoritative_failed {
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
  my $counter = 777;
  my $bad_secret = 'B@d1YK3pts3kr3T!';

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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_auth_otp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_auth_otp/ssh_host_dsa_key');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'ssh2:20 auth_otp:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    AuthOrder => 'mod_auth_file.c mod_auth_otp.c*',

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

      'mod_sftp.c' => [
        "SFTPEngine on",
        "SFTPLog $setup->{log_file}",
        "SFTPHostKey $rsa_host_key",
        "SFTPHostKey $dsa_host_key",

        # Configure mod_sftp to only use the keyboard-interactive method.
        # NOTE: How to handle this when both mod_auth_otp AND mod_sftp_pam
        # are used/loaded?
        'SFTPAuthMethods keyboard-interactive',
      ],

      'mod_sql.c' => [
        'SQLEngine log',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $setup->{log_file}",

        'SQLNamedQuery get-user-totp SELECT "secret, counter FROM auth_otp WHERE user = \'%{0}\'"',
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
  require Net::SSH2;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(2);

      my $ssh2 = Net::SSH2->new();
      unless ($ssh2->connect('127.0.0.1', $port)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't connect to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      # Calculate TOTP
      my $oath = Authen::OATH->new();
      my $totp = $oath->totp($bad_secret);
      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Generated TOTP $totp for current time\n";
      }

      if ($ssh2->auth_keyboard($setup->{user}, $totp)) {
        die("Login to SSH2 server succeeded unexpectedly");
      }

      my ($err_code, $err_name, $err_str) = $ssh2->error();
      $self->assert($err_str, qr/Authentication failed \(keyboard-interactive\)/,
        test_msg("Expected 'Authentication failed (keyboard-interactive), got '$err_str'"));

      $ssh2->disconnect();
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

sub auth_otp_sftp_password_failed {
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
  my $counter = 777;
  my $bad_secret = 'B@d1YK3pts3kr3T!';

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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_auth_otp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_auth_otp/ssh_host_dsa_key');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'auth:20 ssh2:20 auth_otp:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    AuthOrder => 'mod_auth_file.c mod_auth_otp.c*',

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

      'mod_sftp.c' => [
        "SFTPEngine on",
        "SFTPLog $setup->{log_file}",
        "SFTPHostKey $rsa_host_key",
        "SFTPHostKey $dsa_host_key",
        'SFTPAuthMethods password',
      ],

      'mod_sql.c' => [
        'SQLEngine log',
        'SQLBackend sqlite3',
        "SQLConnectInfo $db_file",
        "SQLLogFile $setup->{log_file}",

        'SQLNamedQuery get-user-totp SELECT "secret, counter FROM auth_otp WHERE user = \'%{0}\'"',
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
  require Net::SSH2;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(2);

      my $ssh2 = Net::SSH2->new();
      unless ($ssh2->connect('127.0.0.1', $port)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't connect to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      # Calculate TOTP
      my $oath = Authen::OATH->new();
      my $totp = $oath->totp($bad_secret);
      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Generated TOTP $totp for current time\n";
      }

      if ($ssh2->auth_password($setup->{user}, $totp)) {
        die("Password authentication to SSH2 server succeeded unexpectedly");
      }

      my ($err_code, $err_name, $err_str) = $ssh2->error();
      $self->assert($err_str, qr/Authentication failed \(password\)/,
        test_msg("Expected 'Authentication failed (password), got '$err_str'"));

      $ssh2->disconnect();
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
