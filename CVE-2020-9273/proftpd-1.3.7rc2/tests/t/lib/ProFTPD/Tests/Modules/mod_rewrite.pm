package ProFTPD::Tests::Modules::mod_rewrite;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use File::Path qw(mkpath);
use File::Spec;
use IO::Handle;
use POSIX qw(:fcntl_h);
use URI::Escape;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  rewrite_map_lowercase => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  rewrite_map_spaces_underscores => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  rewrite_map_whitespace_underscores => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  rewrite_rule_append_pid => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  rewrite_bug2915 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  rewrite_bug3027 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  rewrite_bug3034 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  rewrite_bug3169 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  rewrite_map_unescape_bug3170 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  rewrite_cond_env_var_failed => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  rewrite_cond_env_var_ok => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  rewrite_rule_env_var_failed => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  rewrite_rule_env_var_ok => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  rewrite_escape_rule_backref_bug3028 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  rewrite_escape_cond_backref_bug3028 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  rewrite_cond_rename_var_bug3029 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  rewrite_cond_or_flags_bug3269 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  rewrite_cond_nc_flags => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  rewrite_map_fifo_bug3611 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  rewrite_rule_replaceall_backslash_with_slash => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  rewrite_map_max_replace_bug3721 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  rewrite_cond_time_var_bug3673 => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  rewrite_cond_time_year_var_bug3673 => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  rewrite_cond_time_mon_var_bug3673 => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  rewrite_cond_time_day_var_bug3673 => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  rewrite_cond_time_wday_var_bug3673 => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  rewrite_cond_time_hour_var_bug3673 => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  rewrite_cond_time_min_var_bug3673 => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  rewrite_cond_time_sec_var_bug3673 => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  rewrite_rule_time_year_var_bug3673 => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  rewrite_rule_time_mon_var_bug3673 => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  rewrite_rule_time_day_var_bug3673 => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  rewrite_rule_time_wday_var_bug3673 => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  rewrite_rule_time_hour_var_bug3673 => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  rewrite_rule_time_min_var_bug3673 => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  rewrite_bug3767 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  rewrite_bug4017 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  rewrite_using_pcre_bug4017 => {
    order => ++$order,
    test_class => [qw(bug feature_pcre forking rootprivs)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  my @tests = testsuite_get_runnable_tests($TESTS);

  eval "use DateTime";
  if ($@) {
    # If the DateTime module is not present, disable time-related tests

    my $timevar_tests = {
      rewrite_cond_time_var_bug3673 => 1,
      rewrite_cond_time_year_var_bug3673 => 1,
      rewrite_cond_time_mon_var_bug3673 => 1,
      rewrite_cond_time_day_var_bug3673 => 1,
      rewrite_cond_time_wday_var_bug3673 => 1,
      rewrite_cond_time_hour_var_bug3673 => 1,
      rewrite_cond_time_min_var_bug3673 => 1,
      rewrite_cond_time_sec_var_bug3673 => 1,
      rewrite_rule_time_year_var_bug3673 => 1,
      rewrite_rule_time_mon_var_bug3673 => 1,
      rewrite_rule_time_day_var_bug3673 => 1,
      rewrite_rule_time_wday_var_bug3673 => 1,
      rewrite_rule_time_hour_var_bug3673 => 1,
      rewrite_rule_time_min_var_bug3673 => 1,
    };

    # We use arrays, not hashes, here in order to preserve test order
    foreach my $key (keys(%$timevar_tests)) {
      my $ntests = scalar(@tests);

      for (my $i = 0; $i < $ntests; $i++) {
        if ($tests[$i] eq $key) {
          splice(@tests, $i, 1);
          last;
        }
      }
    }
  }

  return @tests;
}

sub rewrite_map_lowercase {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $sub_dir = File::Spec->rel2abs("$tmpdir/tmp");
  mkpath($sub_dir);

  my $test_file = 'test.txt';
  my $test_path = File::Spec->rel2abs("$tmpdir/tmp/$test_file");

  if (open(my $fh, "> $test_path")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_path: $!");
    }

  } else {
    die("Can't open $test_path: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteCondition %m !PASS',
        'RewriteMap lowercase int:tolower',
        'RewriteRule ^(.*) ${lowercase:$1}',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      # Send the path all in uppercase; the rewrite rules should lowercase
      # everything.
      ($resp_code, $resp_msg) = $client->size(uc("tmp/$test_file"));

      my $expected;

      $expected = 213;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = '14';
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

sub rewrite_map_spaces_underscores {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $sub_dir = File::Spec->rel2abs("$tmpdir/tmp");
  mkpath($sub_dir);

  my $cmd_file = 'test file here.txt';

  my $test_file = 'test_file_here.txt';
  my $test_path = File::Spec->rel2abs("$tmpdir/tmp/$test_file");

  if (open(my $fh, "> $test_path")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_path: $!");
    }

  } else {
    die("Can't open $test_path: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteMap replace int:replaceall',
        'RewriteCondition %m SIZE',
        'RewriteRule ^(.*) "${replace:!$1! !_}"',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      # Send the path with spaces; the rewrite rules should handle it
      ($resp_code, $resp_msg) = $client->size("tmp/$cmd_file");

      my $expected;

      $expected = 213;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = '14';
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

sub rewrite_map_whitespace_underscores {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $sub_dir = File::Spec->rel2abs("$tmpdir/tmp");
  mkpath($sub_dir);

  my $test_file = 'test__file__here.txt';
  my $test_path = File::Spec->rel2abs("$tmpdir/tmp/$test_file");

  if (open(my $fh, "> $test_path")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_path: $!");
    }

  } else {
    die("Can't open $test_path: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteMap replace int:replaceall',
        'RewriteCondition %m SIZE',
        'RewriteRule ^(.*) "${replace:!$1! !_}"',

        # Need a separate rule for matching tabs; the internal replaceall
        # map doesn't understand regex classes like "[:space:]".
        'RewriteCondition %m SIZE',
        'RewriteRule ^(.*) "${replace:!$1!	!_}"',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      # Send the path with spaces; the rewrite rules should handle it
      ($resp_code, $resp_msg) = $client->size("tmp/test  file		here.txt");

      my $expected;

      $expected = 213;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = '14';
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

sub rewrite_rule_append_pid {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteCondition %m SIZE',
        'RewriteRule (.*)  $1.%P',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      eval { $client->size("tmp/test.txt") };
      unless ($@) {
        die("SIZE succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'tmp/test.txt.(\d+): No such file or directory';
      $self->assert(qr/$expected/, $resp_msg,
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

sub rewrite_bug2915 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $sub_dir = File::Spec->rel2abs("$tmpdir/tmp");
  mkpath($sub_dir);

  my $test_file = 'test.txt';
  my $test_path = File::Spec->rel2abs("$tmpdir/tmp/$test_file");

  if (open(my $fh, "> $test_path")) {
    close($fh);

  } else {
    die("Can't open $test_path: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",
        'RewriteMap replace int:replaceall',
        'RewriteCondition %m "^SITE CHMOD$" [NC]',

        # There are four backslashes here so that Perl's handling of the
        # string reduces it to two backslashes in the emitted config
        'RewriteRule "^(.*) +(.*)$" "$1 ${replace:!$2!\\\\!/}"',
      ],
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

      $client->login($user, $passwd);

      # Again, we use four backslashes here, so that Perl puts two
      # backslashes in the actual string
      ($resp_code, $resp_msg) = $client->site("chmod 600 tmp\\\\$test_file");

      my $expected;

      $expected = 200;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "SITE CHMOD command successful";
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

sub rewrite_bug3027 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",
        'RewriteMap replace int:replaceall',

        # Attempt to handle the case where the filename portion of the
        # uploaded path might be prefaced by spaces.  Bug#3027 occurred
        # because unmatched backreferences in RewriteRule were not being
        # substituted properly.

        'RewriteCondition %m ^STOR$',
        'RewriteRule "^(.*/)? ([^/]*)$" "$1$2"',
      ],
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

      $client->login($user, $passwd);

      my $conn = $client->stor_raw(' test.txt');

      my $buf = "Hello, World\n";
      $conn->write($buf, length($buf));
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Transfer complete";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      # Had Bug#3027 been present, the file name would have been "$1test.txt",
      # not "test.txt".
      $self->assert(-f $test_file,
        test_msg("$test_file file does not exist as expected"));
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

sub rewrite_bug3034 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

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

    AllowForeignAddress => 'on',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",
        'RewriteMap replace int:replaceall',

        # Substitute in the IP address of the client, regardless of
        # the address the client tells us to use in the PORT command
        'RewriteCondition %m ^PORT$',
        'RewriteRule ([0-9]+,[0-9]+,[0-9]+,[0-9]+)(.*) ${replace:/$1/$1/%a$2}',

        # Replace the periods in the client address with commas, as per RFC959
        # requirements
        'RewriteCondition %m ^PORT$',
        'RewriteRule (.*) ${replace:/$1/./,}',
      ],
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

      $client->login($user, $passwd);

      # Deliberately send a bad address; the rewrite rules should handle
      # it and do The Right Thing(tm).
      ($resp_code, $resp_msg) = $client->port('1,2,3,4,10,11');

      my $expected;

      $expected = 200;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "PORT command successful";
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

sub rewrite_bug3169 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

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

  my $test_file = File::Spec->rel2abs("$tmpdir/taestoe.txt");

  # I have to build up this string, since the editor I'm currently using
  # does NOT like handling non-ASCII characters.
  my $rewrite_rule1 = 'RewriteRule (.*) ${replace:/$1/' . chr(0xe4) . '/ae}';
  my $rewrite_rule2 = 'RewriteRule (.*) ${replace:/$1/' . chr(0xf6) . '/oe}';

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    AllowForeignAddress => 'on',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",
        'RewriteMap replace int:replaceall',

        # The goal is to substitute away non-ASCII characters, replacing
        # them with transliterations.  See:
        #
        #  http://forums.proftpd.org/smf/index.php/topic,3726.0.html
        #
        # The bug (Bug#3169) was that these multiple RewriteRules *should*
        # work in conjunction, but were not.

        'RewriteCondition %m ^STOR$',
        $rewrite_rule1,
        $rewrite_rule2,
      ],
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

      $client->login($user, $passwd);

      my $filename = 't' . chr(0xe4) . 'st' . chr(0xf6) . '.txt';

      my $conn = $client->stor_raw($filename);
      unless ($conn) {
        die("STOR $filename failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Hello, World\n";
      $conn->write($buf, length($buf));
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $self->assert(-f $test_file,
        test_msg("$test_file file does not exist as expected"));
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

sub rewrite_map_unescape_bug3170 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

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

  my $test_file = File::Spec->rel2abs("$tmpdir/test file.txt");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    AllowForeignAddress => 'on',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",
        'RewriteMap unescape int:unescape',

        'RewriteCondition %m ^STOR$',
        'RewriteRule (.*) ${unescape:$1}',
      ],
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

      $client->login($user, $passwd);

      my $filename = "test%20file.txt";

      my $conn = $client->stor_raw($filename);
      unless ($conn) {
        die("STOR $filename failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Hello, World\n";
      $conn->write($buf, length($buf));
      eval { $conn->close() };

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
        test_msg("$test_file file does not exist as expected"));
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

sub rewrite_cond_env_var_failed {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $sub_dir = File::Spec->rel2abs("$tmpdir/tmp");
  mkpath($sub_dir);

  my $test_file = 'test_file_here.txt';
  my $test_path = File::Spec->rel2abs("$tmpdir/tmp/$test_file");

  if (open(my $fh, "> $test_path")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_path: $!");
    }

  } else {
    die("Can't open $test_path: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteMap replace int:replaceall',

        'RewriteCondition %m SIZE',
        'RewriteCondition %{ENV:PR_TEST_FOO} foo',
        'RewriteRule ^(.*) "${replace:!$1! !_}"',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      my $path = "tmp/test file here.txt";

      # Send the path with spaces; the rewrite rules should handle it
      eval { $client->size($path) };
      unless ($@) {
        die("SIZE $path succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "$path: No such file or directory";
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

sub rewrite_cond_env_var_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $sub_dir = File::Spec->rel2abs("$tmpdir/tmp");
  mkpath($sub_dir);

  my $test_file = 'test_file_here.txt';
  my $test_path = File::Spec->rel2abs("$tmpdir/tmp/$test_file");

  if (open(my $fh, "> $test_path")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_path: $!");
    }

  } else {
    die("Can't open $test_path: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
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

    SetEnv => 'PR_TEST_FOO foo',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteMap replace int:replaceall',

        'RewriteCondition %m SIZE',
        'RewriteCondition %{ENV:PR_TEST_FOO} foo',
        'RewriteRule ^(.*) "${replace:!$1! !_}"',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      # Send the path with spaces; the rewrite rules should handle it
      ($resp_code, $resp_msg) = $client->size("tmp/test file here.txt");

      my $expected;

      $expected = 213;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = '14';
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

sub rewrite_rule_env_var_failed {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $test_file = 'foo.txt';
  my $test_path = File::Spec->rel2abs("$home_dir/$test_file");

  if (open(my $fh, "> $test_path")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_path: $!");
    }

  } else {
    die("Can't open $test_path: $!");
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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteCondition %m SIZE',
        'RewriteRule ^(.*) %{ENV:PR_TEST_FOO}.txt',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      my $path = "foo.txt";

      # Send the path with spaces; the rewrite rules should handle it
      eval { $client->size($path) };
      unless ($@) {
        die("SIZE $path succeeded unexpectedly");
      }

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = ".txt: No such file or directory";
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

sub rewrite_rule_env_var_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $test_file = 'foo.txt';
  my $test_path = File::Spec->rel2abs("$home_dir/$test_file");

  if (open(my $fh, "> $test_path")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_path: $!");
    }

  } else {
    die("Can't open $test_path: $!");
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

    SetEnv => 'PR_TEST_FOO foo',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteCondition %m SIZE',
        'RewriteRule ^(.*) %{ENV:PR_TEST_FOO}.txt',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      # Send the path with spaces; the rewrite rules should handle it
      ($resp_code, $resp_msg) = $client->size("foo.txt");

      my $expected;

      $expected = 213;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = '14';
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

sub rewrite_escape_rule_backref_bug3028 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $test_file = File::Spec->rel2abs("$tmpdir/" . '$100dollars.txt');
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }
 
  } else {
    die("Can't open $test_file: $!");
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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteCondition %m SIZE',
        'RewriteRule (.*) $$100dollars.txt',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      ($resp_code, $resp_msg) = $client->size("tmp/test.txt");

      my $expected;

      $expected = 213;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 14;
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

sub rewrite_escape_cond_backref_bug3028 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $test_file = File::Spec->rel2abs("$tmpdir/" . '%100dollars.txt');
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }
 
  } else {
    die("Can't open $test_file: $!");
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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteCondition %m SIZE',
        'RewriteRule (.*) %%100dollars.txt',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      ($resp_code, $resp_msg) = $client->size("tmp/test.txt");

      my $expected;

      $expected = 213;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 14;
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

sub rewrite_cond_rename_var_bug3029 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $test_file = File::Spec->rel2abs("$tmpdir/" . '%100dollars.txt');
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }
 
  } else {
    die("Can't open $test_file: $!");
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

  my $src_dir = File::Spec->rel2abs("$tmpdir/srcdir");
  mkpath($src_dir);

  my $dst_dir = File::Spec->rel2abs("$tmpdir/dstdir");

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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteMap lowercase int:tolower',
        'RewriteCondition %m ^RNTO$',
        'RewriteCondition %w -d',
        'RewriteRule ^(.*) ${lowercase:$0}',
      ],
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
      $client->rnfr('srcdir');
      $client->rnto('DSTDIR');

      $self->assert(-d $dst_dir,
        test_msg("$dst_dir directory does not exist as expected"));
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

sub rewrite_cond_or_flags_bug3269 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteCondition %m SIZE [OR]',
        'RewriteCondition %m STOU',
        'RewriteRule (.*) $1.%P',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      eval { $client->size("tmp/test.txt") };
      unless ($@) {
        die("SIZE succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'tmp/test.txt.(\d+): No such file or directory';
      $self->assert(qr/$expected/, $resp_msg,
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

sub rewrite_cond_nc_flags {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteCondition %u ^ProFTPD$ [NC]', 
        'RewriteCondition %m SIZE',
        'RewriteRule (.*) $1.%P',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      eval { $client->size("tmp/test.txt") };
      unless ($@) {
        die("SIZE succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'tmp/test.txt.(\d+): No such file or directory';
      $self->assert(qr/$expected/, $resp_msg,
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

sub rewrite_map_fifo_bug3611 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $sub_dir = File::Spec->rel2abs("$tmpdir/tmp");
  mkpath($sub_dir);

  my $test_file = 'test.txt';
  my $test_path = File::Spec->rel2abs("$tmpdir/$test_file");

  if (open(my $fh, "> $test_path")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_path: $!");
    }

  } else {
    die("Can't open $test_path: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $fifo_script = File::Spec->rel2abs('t/etc/modules/mod_rewrite/reverse.pl');

  my $fifo = File::Spec->rel2abs("$home_dir/test.fifo");
  unless (POSIX::mkfifo($fifo, 0666)) {
    die("Can't create fifo $fifo: $!");
  }

  my $fifo_pidfile = File::Spec->rel2abs("$home_dir/fifo.pid");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteCondition %m !PASS',
        "RewriteMap reverse fifo:$fifo",
        'RewriteRule ^(.*) ${reverse:$1}',
      ],
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

      my $name = join('', reverse(split//, $user));
      $client->login($name, $passwd);
      $client->type('binary');

      # Send the path in reverse; the rewrite FIFO should reverse
      # everything.
      my ($resp_code, $resp_msg);

      my $path = join('', reverse(split(//, $test_file)));
      ($resp_code, $resp_msg) = $client->stat($path);
      
      my $expected;

      $expected = 211;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    # Start the FIFO script
    `$fifo_script --verbose --fifo $fifo --pidfile $fifo_pidfile >> $log_file 2>&1 &`;

    eval { server_wait($config_file, $rfh) };
    if ($@) {
      warn($@);

      if (open(my $fh, "< $fifo_pidfile")) {
        my $fifo_pid = <$fh>;
        chomp($fifo_pid);

        kill('TERM', $fifo_pid);
        close($fh);
      }

      exit 1;
    }

    if (open(my $fh, "< $fifo_pidfile")) {
      my $fifo_pid = <$fh>;
      chomp($fifo_pid);

      kill('TERM', $fifo_pid);
      close($fh);
    }

    exit 0;
  }

  # Stop server
  server_stop($pid_file);

  if (open(my $fh, "< $fifo_pidfile")) {
    my $fifo_pid = <$fh>;
    chomp($fifo_pid);

    kill('TERM', $fifo_pid);
    close($fh);
  }

  $self->assert_child_ok($pid);

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub rewrite_rule_replaceall_backslash_with_slash {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteMap replace int:replaceall',
        'RewriteCondition %m SIZE',
        'RewriteRule (.*) "${replace:!$1!\\\\!/}"',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      eval { $client->size("tmp\\test.txt") };
      unless ($@) {
        die("SIZE succeeded unexpectedly");

      } else {
        $resp_code = $client->response_code();
        $resp_msg = $client->response_msg();
      }

      my $expected;

      $expected = 550;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'tmp/test.txt: No such file or directory';
      $self->assert(qr/$expected/, $resp_msg,
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

sub rewrite_map_max_replace_bug3721 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $sub_dir = File::Spec->rel2abs("$tmpdir/tmp");
  mkpath($sub_dir);

  # For Bug#3721, we need to use a pattern which requires more replacements
  # than the default (8).
  my $cmd_file = 'fil       e test 234.jpg';
  my $test_file = 'fil_______e_test_234.jpg';
  my $test_path = File::Spec->rel2abs("$tmpdir/tmp/$test_file");

  if (open(my $fh, "> $test_path")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_path: $!");
    }

  } else {
    die("Can't open $test_path: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteMap replace int:replaceall',
        'RewriteCondition %m SIZE',
        'RewriteRule ^(.*) "${replace:!$1! !_}"',

        'RewriteMaxReplace 32',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      # Send the path with spaces; the rewrite rules should handle it
      ($resp_code, $resp_msg) = $client->size("tmp/$cmd_file");

      my $expected;

      $expected = 213;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = '14';
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

sub rewrite_cond_time_var_bug3673 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $sub_dir = File::Spec->rel2abs("$tmpdir/tmp");
  mkpath($sub_dir);

  my $test_file = 'test_file_here.txt';
  my $test_path = File::Spec->rel2abs("$tmpdir/tmp/$test_file");

  if (open(my $fh, "> $test_path")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_path: $!");
    }

  } else {
    die("Can't open $test_path: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  require DateTime;

  my $dt = DateTime->now();
  $dt->set_time_zone('America/Los_Angeles');
  $dt->subtract(seconds => 3);

  my $timestamp = ($dt->ymd('') . $dt->hms(''));

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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteMap replace int:replaceall',

        'RewriteCondition %m SIZE',
        "RewriteCondition %{TIME} >$timestamp",
        'RewriteRule ^(.*) "${replace:!$1! !_}"',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      # Send the path with spaces; the rewrite rules should handle it
      ($resp_code, $resp_msg) = $client->size("tmp/test file here.txt");

      my $expected;

      $expected = 213;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = '14';
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

sub rewrite_cond_time_year_var_bug3673 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $sub_dir = File::Spec->rel2abs("$tmpdir/tmp");
  mkpath($sub_dir);

  my $test_file = 'test_file_here.txt';
  my $test_path = File::Spec->rel2abs("$tmpdir/tmp/$test_file");

  if (open(my $fh, "> $test_path")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_path: $!");
    }

  } else {
    die("Can't open $test_path: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  require DateTime;

  my $dt = DateTime->now();
  $dt->set_time_zone('America/Los_Angeles');
  my $timestamp = sprintf("%04d", $dt->year());

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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteMap replace int:replaceall',

        'RewriteCondition %m SIZE',
        "RewriteCondition %{TIME_YEAR} =$timestamp",
        'RewriteRule ^(.*) "${replace:!$1! !_}"',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      # Send the path with spaces; the rewrite rules should handle it
      ($resp_code, $resp_msg) = $client->size("tmp/test file here.txt");

      my $expected;

      $expected = 213;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = '14';
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

sub rewrite_cond_time_mon_var_bug3673 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $sub_dir = File::Spec->rel2abs("$tmpdir/tmp");
  mkpath($sub_dir);

  my $test_file = 'test_file_here.txt';
  my $test_path = File::Spec->rel2abs("$tmpdir/tmp/$test_file");

  if (open(my $fh, "> $test_path")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_path: $!");
    }

  } else {
    die("Can't open $test_path: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  require DateTime;

  my $dt = DateTime->now();
  $dt->set_time_zone('America/Los_Angeles');
  my $timestamp = sprintf("%02d", $dt->month());

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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteMap replace int:replaceall',

        'RewriteCondition %m SIZE',
        "RewriteCondition %{TIME_MON} =$timestamp",
        'RewriteRule ^(.*) "${replace:!$1! !_}"',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      # Send the path with spaces; the rewrite rules should handle it
      ($resp_code, $resp_msg) = $client->size("tmp/test file here.txt");

      my $expected;

      $expected = 213;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = '14';
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

sub rewrite_cond_time_day_var_bug3673 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $sub_dir = File::Spec->rel2abs("$tmpdir/tmp");
  mkpath($sub_dir);

  my $test_file = 'test_file_here.txt';
  my $test_path = File::Spec->rel2abs("$tmpdir/tmp/$test_file");

  if (open(my $fh, "> $test_path")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_path: $!");
    }

  } else {
    die("Can't open $test_path: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  require DateTime;

  my $dt = DateTime->now();
  $dt->set_time_zone('America/Los_Angeles');
  my $timestamp = sprintf("%02d", $dt->day());

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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteMap replace int:replaceall',

        'RewriteCondition %m SIZE',
        "RewriteCondition %{TIME_DAY} =$timestamp",
        'RewriteRule ^(.*) "${replace:!$1! !_}"',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      # Send the path with spaces; the rewrite rules should handle it
      ($resp_code, $resp_msg) = $client->size("tmp/test file here.txt");

      my $expected;

      $expected = 213;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = '14';
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

sub rewrite_cond_time_wday_var_bug3673 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $sub_dir = File::Spec->rel2abs("$tmpdir/tmp");
  mkpath($sub_dir);

  my $test_file = 'test_file_here.txt';
  my $test_path = File::Spec->rel2abs("$tmpdir/tmp/$test_file");

  if (open(my $fh, "> $test_path")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_path: $!");
    }

  } else {
    die("Can't open $test_path: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  require DateTime;

  my $dt = DateTime->now();
  $dt->set_time_zone('America/Los_Angeles');
  my $timestamp = sprintf("%02d", $dt->day_of_week());

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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteMap replace int:replaceall',

        'RewriteCondition %m SIZE',
        "RewriteCondition %{TIME_WDAY} =$timestamp",
        'RewriteRule ^(.*) "${replace:!$1! !_}"',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      # Send the path with spaces; the rewrite rules should handle it
      ($resp_code, $resp_msg) = $client->size("tmp/test file here.txt");

      my $expected;

      $expected = 213;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = '14';
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

sub rewrite_cond_time_hour_var_bug3673 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $sub_dir = File::Spec->rel2abs("$tmpdir/tmp");
  mkpath($sub_dir);

  my $test_file = 'test_file_here.txt';
  my $test_path = File::Spec->rel2abs("$tmpdir/tmp/$test_file");

  if (open(my $fh, "> $test_path")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_path: $!");
    }

  } else {
    die("Can't open $test_path: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  require DateTime;

  my $dt = DateTime->now();
  $dt->set_time_zone('America/Los_Angeles');
  my $timestamp = sprintf("%02d", $dt->hour());

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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteMap replace int:replaceall',

        'RewriteCondition %m SIZE',
        "RewriteCondition %{TIME_HOUR} =$timestamp",
        'RewriteRule ^(.*) "${replace:!$1! !_}"',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      # Send the path with spaces; the rewrite rules should handle it
      ($resp_code, $resp_msg) = $client->size("tmp/test file here.txt");

      my $expected;

      $expected = 213;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = '14';
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

sub rewrite_cond_time_min_var_bug3673 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $sub_dir = File::Spec->rel2abs("$tmpdir/tmp");
  mkpath($sub_dir);

  my $test_file = 'test_file_here.txt';
  my $test_path = File::Spec->rel2abs("$tmpdir/tmp/$test_file");

  if (open(my $fh, "> $test_path")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_path: $!");
    }

  } else {
    die("Can't open $test_path: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  require DateTime;

  my $dt = DateTime->now();
  $dt->set_time_zone('America/Los_Angeles');
  my $timestamp = sprintf("%02d", $dt->minute());

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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteMap replace int:replaceall',

        'RewriteCondition %m SIZE',
        "RewriteCondition %{TIME_MIN} =$timestamp",
        'RewriteRule ^(.*) "${replace:!$1! !_}"',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      # Send the path with spaces; the rewrite rules should handle it
      ($resp_code, $resp_msg) = $client->size("tmp/test file here.txt");

      my $expected;

      $expected = 213;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = '14';
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

sub rewrite_cond_time_sec_var_bug3673 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $sub_dir = File::Spec->rel2abs("$tmpdir/tmp");
  mkpath($sub_dir);

  my $test_file = 'test_file_here.txt';
  my $test_path = File::Spec->rel2abs("$tmpdir/tmp/$test_file");

  if (open(my $fh, "> $test_path")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_path: $!");
    }

  } else {
    die("Can't open $test_path: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  require DateTime;

  my $dt = DateTime->now();
  $dt->set_time_zone('America/Los_Angeles');
  my $timestamp = sprintf("%02d", $dt->second());

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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteMap replace int:replaceall',

        'RewriteCondition %m SIZE',
        "RewriteCondition %{TIME_SEC} !=$timestamp",
        'RewriteRule ^(.*) "${replace:!$1! !_}"',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      # Send the path with spaces; the rewrite rules should handle it
      ($resp_code, $resp_msg) = $client->size("tmp/test file here.txt");

      my $expected;

      $expected = 213;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = '14';
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

sub rewrite_rule_time_year_var_bug3673 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $sub_dir = File::Spec->rel2abs("$tmpdir/tmp");
  mkpath($sub_dir);

  require DateTime;

  my $dt = DateTime->now();
  $dt->set_time_zone('America/Los_Angeles');

  my $test_file = sprintf("%04d", $dt->year()) . '.txt';
  my $test_path = File::Spec->rel2abs("$tmpdir/tmp/$test_file");

  if (open(my $fh, "> $test_path")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_path: $!");
    }

  } else {
    die("Can't open $test_path: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteCondition %m SIZE',
        'RewriteRule ^(.*) tmp/%{TIME_YEAR}.txt',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      # Send the path with spaces; the rewrite rules should handle it
      ($resp_code, $resp_msg) = $client->size("tmp/test file here.txt");

      my $expected;

      $expected = 213;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = '14';
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

sub rewrite_rule_time_mon_var_bug3673 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $sub_dir = File::Spec->rel2abs("$tmpdir/tmp");
  mkpath($sub_dir);

  require DateTime;

  my $dt = DateTime->now();
  $dt->set_time_zone('America/Los_Angeles');

  my $test_file = sprintf("%02d", $dt->month()) . '.txt';
  my $test_path = File::Spec->rel2abs("$tmpdir/tmp/$test_file");

  if (open(my $fh, "> $test_path")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_path: $!");
    }

  } else {
    die("Can't open $test_path: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteCondition %m SIZE',
        'RewriteRule ^(.*) tmp/%{TIME_MON}.txt',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      # Send the path with spaces; the rewrite rules should handle it
      ($resp_code, $resp_msg) = $client->size("tmp/test file here.txt");

      my $expected;

      $expected = 213;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = '14';
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

sub rewrite_rule_time_day_var_bug3673 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $sub_dir = File::Spec->rel2abs("$tmpdir/tmp");
  mkpath($sub_dir);

  require DateTime;

  my $dt = DateTime->now();
  $dt->set_time_zone('America/Los_Angeles');

  my $test_file = sprintf("%02d", $dt->day()) . '.txt';
  my $test_path = File::Spec->rel2abs("$tmpdir/tmp/$test_file");

  if (open(my $fh, "> $test_path")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_path: $!");
    }

  } else {
    die("Can't open $test_path: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteCondition %m SIZE',
        'RewriteRule ^(.*) tmp/%{TIME_DAY}.txt',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      # Send the path with spaces; the rewrite rules should handle it
      ($resp_code, $resp_msg) = $client->size("tmp/test file here.txt");

      my $expected;

      $expected = 213;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = '14';
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

sub rewrite_rule_time_wday_var_bug3673 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $sub_dir = File::Spec->rel2abs("$tmpdir/tmp");
  mkpath($sub_dir);

  require DateTime;

  my $dt = DateTime->now();
  $dt->set_time_zone('America/Los_Angeles');

  my $test_file = sprintf("%02d", $dt->day_of_week()) . '.txt';
  my $test_path = File::Spec->rel2abs("$tmpdir/tmp/$test_file");

  if (open(my $fh, "> $test_path")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_path: $!");
    }

  } else {
    die("Can't open $test_path: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteCondition %m SIZE',
        'RewriteRule ^(.*) tmp/%{TIME_WDAY}.txt',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      # Send the path with spaces; the rewrite rules should handle it
      ($resp_code, $resp_msg) = $client->size("tmp/test file here.txt");

      my $expected;

      $expected = 213;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = '14';
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

sub rewrite_rule_time_hour_var_bug3673 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $sub_dir = File::Spec->rel2abs("$tmpdir/tmp");
  mkpath($sub_dir);

  require DateTime;

  my $dt = DateTime->now();
  $dt->set_time_zone('America/Los_Angeles');

  my $test_file = sprintf("%02d", $dt->hour()) . '.txt';
  my $test_path = File::Spec->rel2abs("$tmpdir/tmp/$test_file");

  if (open(my $fh, "> $test_path")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_path: $!");
    }

  } else {
    die("Can't open $test_path: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteCondition %m SIZE',
        'RewriteRule ^(.*) tmp/%{TIME_HOUR}.txt',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      # Send the path with spaces; the rewrite rules should handle it
      ($resp_code, $resp_msg) = $client->size("tmp/test file here.txt");

      my $expected;

      $expected = 213;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = '14';
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

sub rewrite_rule_time_min_var_bug3673 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $sub_dir = File::Spec->rel2abs("$tmpdir/tmp");
  mkpath($sub_dir);

  require DateTime;

  my $dt = DateTime->now();
  $dt->set_time_zone('America/Los_Angeles');

  my $test_file = sprintf("%02d", $dt->minute()) . '.txt';
  my $test_path = File::Spec->rel2abs("$tmpdir/tmp/$test_file");

  if (open(my $fh, "> $test_path")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_path: $!");
    }

  } else {
    die("Can't open $test_path: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",

        'RewriteCondition %m SIZE',
        'RewriteRule ^(.*) tmp/%{TIME_MIN}.txt',
      ],
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

      $client->login($user, $passwd);
      $client->type('binary');

      # Send the path with spaces; the rewrite rules should handle it
      ($resp_code, $resp_msg) = $client->size("tmp/test file here.txt");

      my $expected;

      $expected = 213;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = '14';
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

sub rewrite_bug3767 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;
 
  my $sub_dir = File::Spec->rel2abs("$tmpdir/tmp");
  mkpath($sub_dir);

  my $test_file = 'test.txt';
  my $test_path = File::Spec->rel2abs("$tmpdir/tmp/$test_file");

  if (open(my $fh, "> $test_path")) {
    close($fh);

  } else {
    die("Can't open $test_path: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir, $sub_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $sub_dir)) {
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

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",
        'RewriteMap replace int:replaceall',
        'RewriteCondition %m STOR',
        'RewriteRule ^(.*) "${replace:!$1!ABC!DEF}"',
      ],
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

      eval { $client->site("chgrp") };
      unless ($@) {
        die("SITE CHGRP succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 500;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "SITE not understood";
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

sub rewrite_bug4017 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $test_dir = File::Spec->rel2abs("$tmpdir/foo.d");
  mkpath($test_dir);
 
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
    DefaultRoot => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",
        'RewriteMap replace int:replaceall',

        'RewriteCondition %m !PASS',
        'RewriteCondition %m !USER',
        'RewriteRule (^/[^\\\\]*\\\\) /$1',

        'RewriteCondition %m !PASS',
        'RewriteCondition %m !USER',
        'RewriteRule (.*) ${replace:!$1!\\!/}',
      ],
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

      my ($resp_code, $resp_msg) = $client->stat('/foo.d/\bar.d/\baz.d');

      my $expected;

      $expected = 211;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      ($resp_code, $resp_msg) = $client->stat('/foo.d\bar.d/\baz.d');

      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

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

sub rewrite_using_pcre_bug4017 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/rewrite.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/rewrite.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/rewrite.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/rewrite.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/rewrite.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $test_dir = File::Spec->rel2abs("$tmpdir/foo.d");
  mkpath($test_dir);
 
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
    DefaultRoot => '~',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_rewrite.c' => [
        'RewriteEngine on',
        "RewriteLog $log_file",
        'RewriteMap replace int:replaceall',

        'RewriteCondition %m !PASS',
        'RewriteCondition %m !USER',
        'RewriteRule ^(.*?\\/\\\\)(.*) /$1',

        'RewriteCondition %m !PASS',
        'RewriteCondition %m !USER',
        'RewriteRule (.*) ${replace:!$1!\\!/}',
      ],
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

      my ($resp_code, $resp_msg) = $client->stat("/foo.d/\\bar.d/\\baz.d");

      my $expected;

      $expected = 211;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

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

1;
