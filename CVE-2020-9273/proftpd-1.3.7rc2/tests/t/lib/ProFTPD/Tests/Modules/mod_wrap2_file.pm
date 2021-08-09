package ProFTPD::Tests::Modules::mod_wrap2_file;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use File::Path qw(mkpath);
use File::Spec;
use IO::Handle;
use IO::Socket::INET6;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  wrap2_allow_msg => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_deny_msg => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_engine => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_file_allow_table => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_file_allow_table_multi_rows_multi_entries => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  wrap2_file_allow_table_ip_addr_prefix => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  wrap2_file_allow_table_keyword_local => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_file_allow_table_user_ip_addr_prefix => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_file_allow_table_user_ip_addr_netmask => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_file_allow_table_user_dns_name_suffix => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_file_allow_table_tilde => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_file_allow_table_var_U => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_file_deny_table_ipv4_addr => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_file_deny_table_ipv6_addr_bug4090 => {
    order => ++$order,
    test_class => [qw(bug feature_ipv6 forking)],
  },

  wrap2_file_deny_table_dns_name => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_file_deny_table_tilde => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_file_service_name => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_file_user_tables => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_file_user_plus_global_tables => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_file_group_tables => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  wrap2_file_bug3048 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  wrap2_file_syntax => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  wrap2_file_opt_check_on_connect_bug3508 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  wrap2_file_tilde_opt_check_on_connect_bug3508 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  wrap2_sftp_extlog_user_bug3727 => {
    order => ++$order,
    test_class => [qw(bug forking mod_sftp mod_wrap2)],
  },

  wrap2_file_user_table_reverse_dns_bug3938 => {
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

sub set_up {
  my $self = shift;
  $self->SUPER::set_up(@_);

  # Make sure that mod_sftp does not complain about permissions on the hostkey
  # files.

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

  unless (chmod(0400, $rsa_host_key, $dsa_host_key)) {
    die("Can't set perms on $rsa_host_key, $dsa_host_key: $!");
  }
}

sub wrap2_allow_msg {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $fh;
  my $allow_file = File::Spec->rel2abs("$tmpdir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    close($fh);

  } else {
    die("Can't open $allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    close($fh);

  } else {
    die("Can't open $deny_file: $!");
  }

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

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapAllowMsg => '"User %u allowed by access rules"',
        WrapTables => "file:$allow_file file:$deny_file",
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

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg(0);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "User $user allowed by access rules";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
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

sub wrap2_deny_msg {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $fh;
  my $allow_file = File::Spec->rel2abs("$tmpdir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    close($fh);

  } else {
    die("Can't open $allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "ALL: ALL\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

  my $timeout_idle = 15;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,
    UseReverseDNS => 'off',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapDenyMsg => '"User %u rejected by access rules"',
        WrapTables => "file:$allow_file file:$deny_file",
        WrapLog => $log_file,
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

      my ($resp_code, $resp_msg);

      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user rejected by access rules";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub wrap2_engine {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $fh;
  my $allow_file = File::Spec->rel2abs("$tmpdir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    close($fh);

  } else {
    die("Can't open $allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "ALL: ALL\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

      'mod_wrap2.c' => {
        WrapEngine => 'off',
        WrapAllowMsg => '"User %u allowed by access rules"',
        WrapDenyMsg => '"User %u rejected by access rules"',
        WrapTables => "file:$allow_file file:$deny_file",
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

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user logged in";
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

sub wrap2_file_allow_table {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $fh;
  my $allow_file = File::Spec->rel2abs("$tmpdir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    print $fh "ALL: ALL\n";
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "ALL: ALL\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapTables => "file:$allow_file file:$deny_file",
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

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user logged in";
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
    die($ex);
  }

  if (open($fh, "> $allow_file")) {
    print $fh "ALL: 127.0.0.1\n";
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Fork child
  $self->handle_sigchld();
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user logged in";
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

sub wrap2_file_allow_table_multi_rows_multi_entries {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $fh;
  my $allow_file = File::Spec->rel2abs("$tmpdir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    print $fh "ALL: a.b.c.com foo.bar.baz.com evil.org\\\n 192.168.127.5, 192.168.127.6\\\n 192.168.127.1 192.168.127.2 127.0.0.1\\\n 192.168.127.3,192.168.127.4 127.0.0.1\n";

    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "ALL: ALL\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

  my $timeout_idle = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'dns:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapLog => $log_file,
        WrapTables => "file:$allow_file file:$deny_file",
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

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user logged in";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub wrap2_file_allow_table_ip_addr_prefix {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $fh;
  my $allow_file = File::Spec->rel2abs("$tmpdir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    print $fh "ALL: 127.0.0.\n";

    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "ALL: ALL\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

  my $timeout_idle = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'dns:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapLog => $log_file,
        WrapTables => "file:$allow_file file:$deny_file",
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

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user logged in";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub wrap2_file_allow_table_keyword_local {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $fh;
  my $allow_file = File::Spec->rel2abs("$tmpdir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    print $fh "ALL: LOCAL\n";

    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "ALL: ALL\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

  my $timeout_idle = 30;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'dns:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,
    UseReverseDNS => 'on',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapLog => $log_file,
        WrapTables => "file:$allow_file file:$deny_file",
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
      my ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "User $user logged in";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub wrap2_file_allow_table_user_ip_addr_prefix {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $fh;
  my $allow_file = File::Spec->rel2abs("$tmpdir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    print $fh "proftpd: $user\@127.0.0.\n";
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "ALL: ALL\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapLog => $log_file,
        WrapUserTables => "* file:$allow_file file:$deny_file",
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

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user logged in";
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

sub wrap2_file_allow_table_user_ip_addr_netmask {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $fh;
  my $allow_file = File::Spec->rel2abs("$tmpdir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    print $fh "proftpd: $user\@127.0.0.1/255.255.255.247\n";
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "ALL: ALL\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapLog => $log_file,
        WrapUserTables => "* file:$allow_file file:$deny_file",
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

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user logged in";
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

sub wrap2_file_allow_table_user_dns_name_suffix {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $fh;
  my $allow_file = File::Spec->rel2abs("$tmpdir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    print $fh "proftpd: $user\@.castaglia.org\n";
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "ALL: ALL\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'dns:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    UseReverseDNS => 'on',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapLog => $log_file,
        WrapUserTables => "* file:$allow_file file:$deny_file",
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

      # XXX To make this test work, be sure to configure an interface
      # for 127.0.0.2, i.e.:
      #
      #  /sbin/ifconfig eth0:1 127.0.0.2
      #
      # And make sure that /etc/hosts contains something like:
      #
      #  127.0.0.2 golem.castaglia.org golem
      #
      # Do NOT put 'localhost' in the alias list for 127.0.0.2.

      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.2', $port);

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user logged in";
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

sub wrap2_file_allow_table_tilde {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $fh;
  my $allow_file = File::Spec->rel2abs("$tmpdir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    print $fh "ALL: ALL\n";
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "ALL: ALL\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapTables => "file:~/wrap2.allow file:~/wrap2.deny",
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

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user logged in";
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
    die($ex);
  }

  if (open($fh, "> $allow_file")) {
    print $fh "ALL: 127.0.0.1\n";
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Fork child
  $self->handle_sigchld();
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user logged in";
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

sub wrap2_file_allow_table_var_U {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs("$tmpdir/$user");
  mkpath($home_dir);
  my $uid = 500;
  my $gid = 500;

  my $fh;
  my $allow_file = File::Spec->rel2abs("$home_dir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    print $fh "ALL: ALL\n";
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$home_dir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "ALL: ALL\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapTables => "file:$tmpdir/%U/wrap2.allow file:$tmpdir/%U/wrap2.deny",
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
      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "User $user logged in";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
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

  if (open($fh, "> $allow_file")) {
    print $fh "ALL: 127.0.0.1\n";
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Fork child
  $self->handle_sigchld();
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "User $user logged in";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
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

sub wrap2_file_deny_table_ipv4_addr {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $fh;
  my $allow_file = File::Spec->rel2abs("$tmpdir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "ALL: ALL\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapTables => "file:$allow_file file:$deny_file",
        WrapLog => $log_file,
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

      my ($resp_code, $resp_msg);

      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Access denied";
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
    die($ex);
  }

  if (open($fh, "> $deny_file")) {
    print $fh "ALL: 127.0.0.1\n";
    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

  ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Fork child
  $self->handle_sigchld();
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      my ($resp_code, $resp_msg);

      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Access denied";
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

sub wrap2_file_deny_table_ipv6_addr_bug4090 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $fh;
  my $allow_file = File::Spec->rel2abs("$tmpdir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "ALL: ALL\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    DefaultAddress => '::1',
    UseIPv6 => 'on',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapTables => "file:$allow_file file:$deny_file",
        WrapLog => $log_file,
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
      sleep(2);

      my $client = IO::Socket::INET6->new(
        PeerAddr => '::1',
        PeerPort => $port,
        Proto => 'tcp',
        Timeout => 5,
      );
      unless ($client) {
        die("Can't connect to ::1: $!");
      }

      # Read the banner
      my $banner = <$client>;

      # Send the USER command
      my $cmd = "USER $user\r\n";
      $client->print($cmd);
      $client->flush();

      # Read USER response
      my $resp = <$client>;

      my $expected = "331 Password required for $user\r\n";
      $self->assert($expected eq $resp,
        test_msg("Expected '$expected', got '$resp'"));

      # Send the PASS command
      $cmd = "PASS $passwd\r\n";
      $client->print($cmd);
      $client->flush();

      # Read PASS response
      $resp = <$client>;

      $expected = "530 Access denied\r\n";
      $self->assert($expected eq $resp,
        test_msg("Expected response '$expected', got '$resp'"));

      $client->close();
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

  if (open($fh, "> $deny_file")) {
    print $fh "ALL: [::1]\n";
    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

  ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Fork child
  $self->handle_sigchld();
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(2);

      my $client = IO::Socket::INET6->new(
        PeerAddr => '::1',
        PeerPort => $port,
        Proto => 'tcp',
        Timeout => 5,
      );
      unless ($client) {
        die("Can't connect to ::1: $!");
      }

      # Read the banner
      my $banner = <$client>;

      # Send the USER command
      my $cmd = "USER $user\r\n";
      $client->print($cmd);
      $client->flush();

      # Read USER response
      my $resp = <$client>;

      my $expected = "331 Password required for $user\r\n";
      $self->assert($expected eq $resp,
        test_msg("Expected '$expected', got '$resp'"));

      # Send the PASS command
      $cmd = "PASS $passwd\r\n";
      $client->print($cmd);
      $client->flush();

      # Read PASS response
      $resp = <$client>;

      $expected = "530 Access denied\r\n";
      $self->assert($expected eq $resp,
        test_msg("Expected response '$expected', got '$resp'"));

      $client->close();
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

sub wrap2_file_deny_table_dns_name {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $fh;
  my $allow_file = File::Spec->rel2abs("$tmpdir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "ALL: ALL\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    UseReverseDNS => 'on',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapTables => "file:$allow_file file:$deny_file",
        WrapLog => $log_file,
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

      my ($resp_code, $resp_msg);

      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Access denied";
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
    die($ex);
  }

  if (open($fh, "> $deny_file")) {
    print $fh "ALL:  localhost\n";
    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

  ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Fork child
  $self->handle_sigchld();
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      my ($resp_code, $resp_msg);

      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Access denied";
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

sub wrap2_file_deny_table_tilde {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $fh;
  my $allow_file = File::Spec->rel2abs("$tmpdir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "ALL: ALL\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapTables => "file:~/wrap2.allow file:~/wrap2.deny",
        WrapLog => $log_file,
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

      my ($resp_code, $resp_msg);

      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Access denied";
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
    die($ex);
  }

  if (open($fh, "> $deny_file")) {
    print $fh "ALL: 127.0.0.1\n";
    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

  ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Fork child
  $self->handle_sigchld();
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      my ($resp_code, $resp_msg);

      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Access denied";
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

sub wrap2_file_service_name {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $fh;
  my $allow_file = File::Spec->rel2abs("$tmpdir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    print $fh "ftpd: ALL\n";
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "ALL: ALL\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapTables => "file:$allow_file file:$deny_file",
        WrapLog => $log_file,
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

      my ($resp_code, $resp_msg);

      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Access denied";
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
    die($ex);
  }

  if (open($fh, "> $allow_file")) {
    print $fh "proftpd: 127.0.0.1\n";
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Fork child
  $self->handle_sigchld();
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user logged in";
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

sub wrap2_file_user_tables {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $fh;
  my $allow_file = File::Spec->rel2abs("$tmpdir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "ALL: ALL\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapUserTables => "!$user file:$allow_file file:$deny_file",
        WrapLog => $log_file,
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

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user logged in";
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
    die($ex);
  }

  # Modify the config a little
  $config->{IfModules}->{'mod_wrap2.c'}->{WrapUserTables} = "$user file:$allow_file file:$deny_file";

  ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Fork child
  $self->handle_sigchld();
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      my ($resp_code, $resp_msg);

      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Access denied";
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

sub wrap2_file_group_tables {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $fh;
  my $allow_file = File::Spec->rel2abs("$tmpdir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "ALL: ALL\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapGroupTables => "foo file:$allow_file file:$deny_file",
        WrapLog => $log_file,
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

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user logged in";
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
    die($ex);
  }

  # Modify the config a little
  $config->{IfModules}->{'mod_wrap2.c'}->{WrapGroupTables} = "$group file:$allow_file file:$deny_file";

  ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Fork child
  $self->handle_sigchld();
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      my ($resp_code, $resp_msg);

      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Access denied";
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

sub wrap2_file_bug3048 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $fh;
  my $allow_file = File::Spec->rel2abs("$tmpdir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    print $fh "proftpd: 192.168.0.1,192.168.0.2 192.168.0.3, 192.168.0.4 127.0.0.1\n";
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "ALL: ALL\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapTables => "file:$allow_file file:$deny_file",
        WrapLog => $log_file,
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

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user logged in";
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

sub wrap2_file_syntax {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $fh;
  my $allow_file = File::Spec->rel2abs("$tmpdir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  # This particular issue arose because of a badly configured deny file:
  #
  #   http://forums.proftpd.org/smf/index.php/topic,4354.0.html
  #
  # However, mod_wrap2's handling of the syntax error should be better.

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "proftpd: ALL: DENY\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

  my $timeout_idle = 20;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapTables => "file:$allow_file file:$deny_file",
        WrapLog => $log_file,
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

      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Access denied";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 2) };
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

sub wrap2_file_user_plus_global_tables {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $fh;
  my $user_allow_file = File::Spec->rel2abs("$tmpdir/user.allow");
  if (open($fh, "> $user_allow_file")) {
    unless (close($fh)) {
      die("Can't write $user_allow_file: $!");
    }

  } else {
    die("Can't open $user_allow_file: $!");
  }

  my $host_allow_file = File::Spec->rel2abs("$tmpdir/host.allow");
  if (open($fh, "> $host_allow_file")) {
    print $fh "proftpd: 127.0.0.1\n";

    unless (close($fh)) {
      die("Can't write $host_allow_file: $!");
    }

  } else {
    die("Can't open $host_allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "ALL: ALL\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapUserTables => "* file:$user_allow_file file:$deny_file",
        WrapTables => "file:$host_allow_file file:$deny_file",
        WrapLog => $log_file,
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

      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
 
      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Access denied";
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

sub wrap2_file_opt_check_on_connect_bug3508 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $fh;
  my $allow_file = File::Spec->rel2abs("$tmpdir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    print $fh "ALL: ALL\n";
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "ALL: ALL\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapTables => "file:$allow_file file:$deny_file",
        WrapLog => $log_file,
        WrapOptions => 'CheckOnConnect',
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

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user logged in";
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
    die($ex);
  }

  if (open($fh, "> $allow_file")) {
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Fork child
  $self->handle_sigchld();
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client;

      eval {
        $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, undef, 2);
      };
      unless ($@) {
        die("Connect succeeded unexpectedly");
      }

      my $ex = ProFTPD::TestSuite::FTP::get_connect_exception();

      my $expected = "Access denied";
      $self->assert($expected eq $ex,
        test_msg("Expected '$expected', got '$ex'"));
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

sub wrap2_file_tilde_opt_check_on_connect_bug3508 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $fh;
  my $allow_file = File::Spec->rel2abs("$tmpdir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    print $fh "ALL: ALL\n";
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "ALL: ALL\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapTables => "file:~/wrap2.allow file:~/wrap2.deny",
        WrapLog => $log_file,
        WrapOptions => 'CheckOnConnect',
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

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->login($user, $passwd);

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user logged in";
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
    die($ex);
  }

  if (open($fh, "> $allow_file")) {
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Fork child
  $self->handle_sigchld();
  defined($pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {

      # This SHOULD be denied, but because we used a tilde in the path to the
      # allow/deny tables, that tilde can't be resolved, thus the paths can't
      # be opened, and the connection will be allowed by default.
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, undef, 2);
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

sub wrap2_sftp_extlog_user_bug3727 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");
  my $extlog_file = File::Spec->rel2abs("$tmpdir/ext.log");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

  my $fh;
  my $allow_file = File::Spec->rel2abs("$tmpdir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    print $fh "ALL: ALL\n";
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "ALL: ALL\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'login "%h %l %u %m"',
    ExtendedLog => "$extlog_file ALL login",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sftp.c' => [
        "SFTPEngine on",
        "SFTPLog $log_file",
        "SFTPHostKey $rsa_host_key",
        "SFTPHostKey $dsa_host_key",
      ],

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapLog => $log_file,
        WrapTables => "file:$allow_file file:$deny_file",
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

  require Net::SSH2;

  my $ex;

  # Ignore SIGPIPE
  local $SIG{PIPE} = sub { }; 

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $ssh2 = Net::SSH2->new();

      sleep(1);

      unless ($ssh2->connect('127.0.0.1', $port)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't connect to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $wrong_passwd = 'foobar';
      if ($ssh2->auth_password($user, $wrong_passwd)) {
        die("Login to SSH2 server succeeded unexpectedly with bad password");
      }

      $ssh2->disconnect();
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

  if (open(my $fh, "< $extlog_file")) {
    my $ok = 0;

    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /^\S+\s+\S+\s+(\S+)\s+(\S+)$/) {
        my $extlog_user = $1;
        my $req = $2;

        # For Bug#3727, we're only interested in the USERAUTH_REQUEST
        # SSH requests.

        next unless $req eq 'USERAUTH_REQUEST';

        # In this case, the user value should NOT be the user name provided
        # by the SFTP client.  If that client-provided name appears for
        # a bad/wrong password, it's wrong.

        if ($extlog_user ne $user) {
          $ok = 1;
          last;
        }
      }
    }

    close($fh);

    $self->assert($ok, test_msg("Wrong LogFormat %u expansion in ExtendedLog"));

  } else {
    die("Can't read $extlog_file: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }


  unlink($log_file);
}

sub wrap2_file_user_table_reverse_dns_bug3938 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/wrap2.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/wrap2.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/wrap2.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/wrap2.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/wrap2.group");

  my $fh;
  my $allow_file = File::Spec->rel2abs("$tmpdir/wrap2.allow");
  if (open($fh, "> $allow_file")) {
    unless (close($fh)) {
      die("Can't write $allow_file: $!");
    }

  } else {
    die("Can't open $allow_file: $!");
  }

  my $deny_file = File::Spec->rel2abs("$tmpdir/wrap2.deny");
  if (open($fh, "> $deny_file")) {
    print $fh "ALL: 127.0.0.1\n";

    unless (close($fh)) {
      die("Can't write $deny_file: $!");
    }

  } else {
    die("Can't open $deny_file: $!");
  }

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'dns:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_wrap2.c' => {
        WrapEngine => 'on',
        WrapUserTables => "!other file:$allow_file file:$deny_file",
        WrapLog => $log_file,
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
      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 530;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Access denied";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));
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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  eval {
    if (open(my $fh, "< $log_file")) {
      my $ok = 1;

      while (my $line = <$fh>) {
        chomp($line);

        if ($line =~ /via reverse DNS/) {
          $ok = 0;
          last;
        }
      }

      close($fh);

      $self->assert($ok,
        test_msg("Saw unexpected 'via reverse DNS' log message in TraceLog"));

    } else {
      die("Can't read $log_file: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

1;
