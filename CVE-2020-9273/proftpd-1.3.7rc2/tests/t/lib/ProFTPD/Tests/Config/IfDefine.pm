package ProFTPD::Tests::Config::IfDefine;

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
  ifdefine_exists => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ifdefine_not_exist => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ifdefine_exists_via_define => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ifdefine_exists_via_env => {
    order => ++$order,
    test_class => [qw(forking)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub ifdefine_exists {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");

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
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  my $define = 'FOO';

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<IfDefine $define>
  ServerIdent on
</IfDefine>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  eval { server_start($config_file, undef, { define => [$define] }) };
  if ($@) {
    my $ex = $@;

    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  # Give the daemon a chance to start up
  sleep(1);
  server_stop($pid_file);

  unlink($log_file);
}

sub ifdefine_not_exist {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");

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
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  my $define = 'FOO';

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<IfDefine $define>
  # Use a nonsense directive here; if the server incorrectly see the Define,
  # it will fail to start.
  FooBar baz
</IfDefine>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  eval { server_start($config_file) };
  if ($@) {
    my $ex = $@;

    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  # Give the daemon a chance to start up
  sleep(1);
  server_stop($pid_file);

  unlink($log_file);
}

sub ifdefine_exists_via_define {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");

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
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  my $define = 'FOO';

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
Define $define

<IfDefine $define>
  ServerIdent on
</IfDefine>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  eval { server_start($config_file) };
  if ($@) {
    my $ex = $@;

    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  # Give the daemon a chance to start up
  sleep(1);
  server_stop($pid_file);

  unlink($log_file);
}

sub ifdefine_exists_via_env {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/config.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/config.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/config.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/config.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/config.group");

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
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  my $key = 'FOO';
  my $value = 'BAR';

  $ENV{$key} = $value;

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<IfDefine $key=%{env:$key}>
  ServerIdent on
</IfDefine>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  eval { server_start($config_file, undef,
    { define => [$key . '=$' . $key] }) };
  if ($@) {
    my $ex = $@;

    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  # Give the daemon a chance to start up
  sleep(1);
  server_stop($pid_file);

  unlink($log_file);
}

1;
