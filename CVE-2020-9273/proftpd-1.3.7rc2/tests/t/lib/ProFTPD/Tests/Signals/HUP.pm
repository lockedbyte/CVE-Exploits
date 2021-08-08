package ProFTPD::Tests::Signals::HUP;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use File::Path qw(mkpath);
use File::Spec;
use IO::Handle;
use Time::HiRes qw(gettimeofday tv_interval);

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  hup_daemon_ok => {
    order => ++$order,
    test_class => [qw(bug)],
  },

  hup_directory_bug3610 => {
    order => ++$order,
    test_class => [qw(bug mod_sql_sqlite)],
  },

  hup_allowoverwrite_bug3740 => {
    order => ++$order,
    test_class => [qw(bug)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub hup_daemon_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/signals.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/signals.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/signals.scoreboard");

  my $log_file = test_get_logfile();

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    ServerIdent => 'on foo',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Start server
  server_start($config_file); 
  sleep(2);

  my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

  my $resp_code = $client->response_code();
  my $resp_msg = $client->response_msg();

  my $expected;
    
  $expected = 220;
  $self->assert($expected == $resp_code,
    test_msg("Expected $expected, got $resp_code"));

  $expected = "foo";
  $self->assert($expected eq $resp_msg,
    test_msg("Expected '$expected', got '$resp_msg'"));

  # Now change the config a little, and send the HUP signal
  $config->{ServerIdent} = 'on bar';
  ($port, $config_user, $config_group) = config_write($config_file, $config);
  server_restart($pid_file);
  sleep(2);

  $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

  $resp_code = $client->response_code();
  $resp_msg = $client->response_msg();

  $expected = 220;
  $self->assert($expected == $resp_code,
    test_msg("Expected $expected, got $resp_code"));

  $expected = "bar";
  $self->assert($expected eq $resp_msg,
    test_msg("Expected '$expected', got '$resp_msg'"));

  server_stop($pid_file);
  unlink($log_file);
}

sub hup_directory_bug3610 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/signals.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/signals.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/signals.scoreboard");

  my $log_file = test_get_logfile();

  my $user = 'proftpd';

  my $db_file = File::Spec->rel2abs("$tmpdir/signals.db");

  my $include_file = File::Spec->rel2abs("$tmpdir/include.conf");
  if (open(my $fh, "> $include_file")) {

    for (my $i = 1; $i <= 50; $i++) {
      my $dir = File::Spec->rel2abs("$tmpdir/u$i");
      mkpath($dir);
      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Created directory $dir\n";
      }

      print $fh <<EOC;
<Directory $dir>
  HideFiles _.+__\$ user !proftpdadm
  <Limit WRITE>
    Order allow,deny
    AllowUser $user
    DenyAll
  </Limit>
</Directory>

EOC

      for (my $j = 0; $j < 5; $j++) {
        my $subdir = File::Spec->rel2abs("$dir/d$j");
        mkpath($subdir);
        if ($ENV{TEST_VERBOSE}) {
          print STDERR "# Created directory $subdir\n";
        }

        print $fh <<EOC;
<Directory $subdir/*>
  <Limit WRITE>
    Order allow,deny
    AllowUser $user
    DenyAll
  </Limit>
</Directory>

EOC
      }
    }

    unless (close($fh)) {
      die("Can't write $include_file: $!");
    }

  } else {
    die("Can't open $include_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'config:12-12',

    ServerIdent => 'on foo',

    Global => {
      AccessGrantMsg => "Welcome %u",
      AllowOverride => 'off',
      ListOptions => '-al',
      MaxLoginAttempts => 3,
      PathAllowFilter => '^([A-Za-z0-9._-]|\/)+$',
      RequireValidShell => 'no',
      RootLogin => 'off',
      UseFtpUsers => 'off',
      Umask => '0002',

      Include => $include_file,
    },

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    my $vhost_port1 = $port + 200;
    my $vhost_port2 = $port + 400;

    print $fh <<EOC;
<Global>
  <Limit ALL>
    AllowAll
  </Limit>

  <Limit ABOR SITE_CHMOD SITE_CHGRP SITE_MKDIR SITE_RMDIR SITE_SYMLINK SITE_UTIME APPE STOU>
    DenyAll
  </Limit>

  <IfModule mod_sql.c>
SQLEngine               on

SQLLogFile /var/log/proftpd/proftpd.mysql.log
SQLBackend sqlite3
SQLAuthenticate users usersetfast
SQLAuthTypes Plaintext Crypt
SQLConnectInfo $db_file ftpuser ftppw
SQLUserInfo users username password uid gid homedir shell
SQLUserWhereClause "LoginAllowed = 'true' "
SQLMinUserUID 1000
SQLMinUserGID 1000
SQLNegativeCache on

SQLLog PASS,ERR_PASS updatecount
SQLNamedQuery updatecount UPDATE "count=count+1 , datecount=now() WHERE username='%u'" users
SQLLog PASS,ERR_PASS debutconnexions
SQLNamedQuery debutconnexions INSERT "'','%u',CURDATE(),now(),NULL,NULL,'%L','%h','%r','%s',%P,'%{env:UNIQUE_ID}'" connexions
SQLLog EXIT,ERR_EXIT finconnexions
SQLNamedQuery finconnexions UPDATE "DateFinConn=CURDATE(),HFinConn=now(), CommandConn='%r', CodeConn='%s' WHERE UniqueIdFtpd='%{env:UNIQUE_ID}'" connexions

SQLLog RETR,ERR_RETR,STOR,ERR_STOR,STOU,ERR_STOU,MKD,ERR_MKD,XMKD,ERR_XMKD,RMD,ERR_RMD,XRMD,ERR_XRMD,DELE,ERR_DELE,RNFR,ERR_RNFR transferts
SQLNamedQuery transferts    INSERT "'',CURDATE(),now(), '%f', %b, '%m', '%r','%s','%{env:UNIQUE_ID}'" transferts
SQLLog RNTO,ERR_RNTO renames
SQLNamedQuery renames       INSERT "'',CURDATE(),now(), '%f', %b, '%m', 'RNFR %w','%s','%{env:UNIQUE_ID}'" transferts
  </IfModule>

  <IfModule mod_tls.c>
  </IfModule>
</Global>

<VirtualHost 127.0.0.1>
  ServerIdent on "FTPS"
  Port $vhost_port1
  PassivePorts 49152 59151
</VirtualHost>

<VirtualHost 127.0.0.1>
  ServerIdent on "SFTP"
  Port $vhost_port2
</VirtualHost>

EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  # Start server
  server_start($config_file); 

  # Give the server some time to start up
  sleep(2);

  # Restart the server
  server_restart($pid_file);

  sleep(2);

  my $conn_start = [gettimeofday];
  my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
  my $conn_elapsed = tv_interval($conn_start);
  if ($ENV{TEST_VERBOSE}) {
    print STDERR " + Connect elapsed time: $conn_elapsed\n";
  }

  # If we can connect in under 5 secs, we've made progress on Bug#3610
  my $max_elapsed = 5;
  $self->assert($conn_elapsed < $max_elapsed,
    test_msg("Expected connection elapsed time < $max_elapsed, got $conn_elapsed"));

  my $resp_code = $client->response_code();
  my $resp_msg = $client->response_msg();

  my $expected;

  $expected = 220;
  $self->assert($expected == $resp_code,
    test_msg("Expected $expected, got $resp_code"));

  $expected = "foo";
  $self->assert($expected eq $resp_msg,
    test_msg("Expected '$expected', got '$resp_msg'"));

  server_stop($pid_file);
  unlink($log_file);
}

sub upload_file {
  my $port = shift;
  my $user = shift;
  my $passwd = shift;
  my $path = shift;

  my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
  $client->login($user, $passwd);

  my $conn = $client->stor_raw($path);
  unless ($conn) {
    die("Failed to STOR $path: " . $client->response_code() . " " .
      $client->response_msg());
  }

  my $buf = "Hello again\n";
  $conn->write($buf, length($buf), 30);
  eval { $conn->close() };

  my $resp_code = $client->response_code();
  my $resp_msg = $client->response_msg();

  $client->quit();

  my $expected;

  $expected = 226;
  unless ($resp_code == $expected) {
    die("Expected response code $expected, got $resp_code");
  }

  $expected = "Transfer complete";
  unless ($resp_msg eq $expected) {
    die("Expected response message '$expected', got '$resp_msg'");
  }

  return 1;
}

sub hup_allowoverwrite_bug3740 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/signals.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/signals.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/signals.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/cmds.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/cmds.group");

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

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    AllowOverwrite => 'on',
 
    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Add a <VirtualHost> to the config.  This appears to be a key factor
  # in causing Bug#3740, according to the bug report.
  if (open(my $fh, ">> $config_file")) {
    my $vhost_port = $port + 200;

    print $fh <<EOC;
<VirtualHost 127.0.0.1>
  Port $vhost_port
  ServerName "Bug#3740 vhost"
  ServerIdent on "Bug#3740 vhost"
</VirtualHost>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't read $config_file: $!");
  }

  # Start server
  server_start($config_file); 

  my $nattempts = 10;

  for (my $i = 0; $i < $nattempts; $i++) {
    if ($ENV{TEST_VERBOSE}) {
      print STDERR "Upload attempt #", $i + 1, "...";
    }

    eval { upload_file($port, $user, $passwd, 'test.txt') };
    if ($@) {
      my $ex = $@;

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "FAILED\n";
      }

      server_stop($pid_file);
      test_append_logfile($log_file, $ex);
      unlink($log_file);

      die($ex);
    }

    if ($ENV{TEST_VERBOSE}) {
      print STDERR "OK\n";
    }

    server_restart($pid_file);
  }

  server_stop($pid_file);
  unlink($log_file);
}

1;
