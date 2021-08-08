package ProFTPD::Tests::Config::Limit::LOGIN;

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
  login_limit_ip_glob_range_bug3484 => {
    order => ++$order,
    test_class => [qw(bug forking inprogress)],
  },

  login_limit_allowgroup_backslash => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  login_limit_multiple_sections => {
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

sub login_limit_ip_glob_range_bug3484 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/limit.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/limit.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/limit.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/limit.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/limit.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group ='ftpd';
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

  # See http://forums.proftpd.org/smf/index.php/topic,4774.0.html

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'netacl:20 dns:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    UseIPv6 => 'off',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },

    Limit => {
      LOGIN => {
        Deny => '127.0.0.[0-9]',
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
      my $client;

      eval { $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port,
        undef, 0) };
      unless ($@) {
        die("Connect succeeded unexpectedly");
      }

      my $conn_ex = ProFTPD::TestSuite::FTP::get_connect_exception();

      my $expected = 'Connection refused';
      $self->assert(qr/$expected/, $conn_ex,
        test_msg("Expected '$expected', got '$conn_ex'"));
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

sub login_limit_allowgroup_backslash {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/limit.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/limit.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/limit.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/limit.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/limit.group");

  # See:
  #   https://forums.proftpd.org/smf/index.php/topic,11304.0.html

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd\group';
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

  # See http://forums.proftpd.org/smf/index.php/topic,4774.0.html

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'netacl:20 dns:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    UseIPv6 => 'off',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },

    Limit => {
      LOGIN => {
        AllowGroup => $group,
        DenyAll => '',
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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub login_limit_multiple_sections {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/limit.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/limit.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/limit.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/limit.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/limit.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group ='ftpd';
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

  # See http://forums.proftpd.org/smf/index.php/topic,4774.0.html

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'netacl:20 dns:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    UseIPv6 => 'off',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    # When multiple <Limit LOGIN> sections are present, which one is used:
    # first, or last?
    print $fh <<EOC;
<Limit LOGIN>
  Order allow,deny
  Allow 127.0.0.1
  DenyAll
</Limit>

<Limit LOGIN>
  Order deny,allow
  Deny 127.0.0.1
</Limit>

EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }
  } else {
    die("Can't open $config_file: $!");
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
      my $client;

      eval { $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port,
        undef, 0) };
      unless ($@) {
        die("Connect succeeded unexpectedly");
      }

      my $conn_ex = ProFTPD::TestSuite::FTP::get_connect_exception();

      # Looks like the last <Limit LOGIN> section wins.
      my $expected = 'Connection refused';
      $self->assert(qr/$expected/, $conn_ex,
        test_msg("Expected '$expected', got '$conn_ex'"));
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
