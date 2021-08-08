package ProFTPD::Tests::Modules::mod_ldap;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use File::Path qw(mkpath rmtree);
use File::Spec;
use IO::Handle;

use Net::LDAP qw(LDAP_NO_SUCH_OBJECT);
use Net::LDAP::Entry;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

# FIXME: we probably can't test these directives without depending
# on OpenLDAP's slapd being installed, and starting our own directory
# instance that we can configure and start/stop as we wish.
#
# LDAPAttr
# LDAPAuthBinds
# LDAPProtocolVersion
# LDAPUseTLS

my $TESTS = {
  ldap_users_authallowed => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ldap_users_authdenied => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ldap_genhomedir_with_username => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ldap_genhomedir_without_username => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ldap_genhomedir_forcegenhdir => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ldap_groups_authdenied => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ldap_groups_authallowed => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ldap_quota_on_user => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ldap_quota_default => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ldap_default_uid => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ldap_default_gid => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ldap_default_force_uid => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ldap_default_force_gid => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ldap_alias_dereference_off => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ldap_alias_dereference_on => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ldap_scope_base => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ldap_scope_sub => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ldap_default_auth_scheme => {
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

sub ldap_auth {
  my $self = shift;
  my $allow_auth = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ldap.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ldap.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ldap.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $server = $ENV{LDAP_SERVER} ? $ENV{LDAP_SERVER} : 'localhost';
  my $bind_dn = $ENV{LDAP_BIND_DN};
  my $bind_pass = $ENV{LDAP_BIND_PASS};
  my $ldap_base = $ENV{LDAP_USER_BASE};
  my $user = 'proftpdtest' . int(rand(4294967296));
  my $passwd = 'foobar';
  my $uid = 1000;
  my $gid = 1000;
  my $home_dir = File::Spec->rel2abs($tmpdir);

  my $ld = Net::LDAP->new([$server]);
  $self->assert($ld);
  $self->assert($ld->bind($bind_dn, password => $bind_pass));

  my $entry = Net::LDAP::Entry->new("uid=$user,$ldap_base");
  $entry->delete();
  my $msg = $entry->update($ld);
  if ($msg->is_error()) {
    $self->annotate($msg->error());
  }
  $self->assert(!$msg->is_error() || $msg->code() == LDAP_NO_SUCH_OBJECT);

  $entry = Net::LDAP::Entry->new(
    "uid=$user,$ldap_base",
    objectClass => ['posixAccount', 'account'],
    uid => $user,
    userPassword => $passwd,
    uidNumber => $uid,
    gidNumber => $gid,
    homeDirectory => $home_dir,
    cn => 'ProFTPD Test',
  );
  $msg = $entry->update($ld);
  $self->assert(!$msg->is_error());

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'auth:10',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_ldap.c' => {
        LDAPServer => $server,
        LDAPBindDN => "$bind_dn $bind_pass",
        LDAPUsers => "$ldap_base (uid=%u)",
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
      if ($allow_auth) {
        $client->login($user, $passwd);
      } else {
        eval { $client->login($user, $passwd . '-') };
        unless ($@) {
          die("Login succeeded unexpectedly");
        }
      }

      my ($resp_code, $resp_msg);
      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      if ($allow_auth) {
        $expected = 230;
        $self->assert($expected == $resp_code,
          test_msg("Expected $expected, got $resp_code"));

        # FIXME: assert() -> assert_str_equals()
        $expected = "User $user logged in";
        $self->assert($expected eq $resp_msg,
          test_msg("Expected '$expected', got '$resp_msg'"));
      } else {
          $expected = 530;
          $self->assert($expected == $resp_code,
            test_msg("Expected $expected, got $resp_code"));

          $expected = 'Login incorrect.';
          $self->assert($expected eq $resp_msg,
            test_msg("Expected '$expected', got '$resp_msg'"));
      }
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

  server_stop($pid_file);

  $self->assert_child_ok($pid);

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub ldap_users_authallowed {
  my $self = shift;

  ldap_auth($self, 1);
}

sub ldap_users_authdenied {
  my $self = shift;

  ldap_auth($self, 0);
}

sub ldap_genhomedir {
  my $self = shift;
  my $with_username = shift;
  my $force_genhdir = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ldap.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ldap.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ldap.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $server = $ENV{LDAP_SERVER} ? $ENV{LDAP_SERVER} : 'localhost';
  my $bind_dn = $ENV{LDAP_BIND_DN};
  my $bind_pass = $ENV{LDAP_BIND_PASS};
  my $ldap_base = $ENV{LDAP_USER_BASE};
  my $user = 'proftpdtest' . int(rand(4294967296));
  my $passwd = 'foobar';
  my $uid = 1000;
  my $gid = 1000;

  my $home_dir;
  if ($with_username) {
    $home_dir = File::Spec->rel2abs($tmpdir) . "/$user";
  } else {
    $home_dir = File::Spec->rel2abs($tmpdir);
  }

  if ($with_username) {
    mkdir($home_dir);
  }

  my $ld = Net::LDAP->new([$server]);
  $self->assert($ld);
  $self->assert($ld->bind($bind_dn, password => $bind_pass));

  my $entry = Net::LDAP::Entry->new("uid=$user,$ldap_base");
  $entry->delete();
  my $msg = $entry->update($ld);
  if ($msg->is_error()) {
    $self->annotate($msg->error());
  }
  $self->assert(!$msg->is_error() || $msg->code() == LDAP_NO_SUCH_OBJECT);

  if ($force_genhdir) {
    $entry = Net::LDAP::Entry->new(
      "uid=$user,$ldap_base",
      objectClass => ['posixAccount', 'account'],
      uid => $user,
      userPassword => $passwd,
      uidNumber => $uid,
      gidNumber => $gid,
      homeDirectory => '/nonexistent',
      cn => 'ProFTPD Test',
    );
  } else {
    $entry = Net::LDAP::Entry->new(
      "uid=$user,$ldap_base",
      objectClass => ['posixAccount', 'account'],
      uid => $user,
      userPassword => $passwd,
      uidNumber => $uid,
      gidNumber => $gid,
      homeDirectory => $home_dir,
      cn => 'ProFTPD Test',
    );
  }
  $msg = $entry->update($ld);
  $self->assert(!$msg->is_error());

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'auth:10',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_ldap.c' => {
        LDAPServer => $server,
        LDAPBindDN => "$bind_dn $bind_pass",
        LDAPUsers => "$ldap_base (uid=%u)",
        LDAPGenerateHomedir => 'on',
        LDAPGenerateHomedirPrefix => $tmpdir,
        LDAPGenerateHomedirPrefixNoUsername =>
          $with_username ? 'off' : 'on',
        LDAPForceGeneratedHomedir =>
          $force_genhdir ? 'on' : 'off',
      },
    },
  };

  open(HDIR_FILE, ">$home_dir/testfile") ||
    die("Unable to open $home_dir/testfile for writing: $!");
  print HDIR_FILE "test file in generated homedir\n";
  close(HDIR_FILE);

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

      my ($resp_code, $resp_msg);
      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user logged in";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $client->retr('testfile');
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

  server_stop($pid_file);

  $self->assert_child_ok($pid);

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub ldap_genhomedir_with_username {
  my $self = shift;

  ldap_genhomedir($self, 1, 0);
}

sub ldap_genhomedir_without_username {
  my $self = shift;

  ldap_genhomedir($self, 0, 0);
}

sub ldap_genhomedir_forcegenhdir {
  my $self = shift;

  ldap_genhomedir($self, 0, 1);
}

sub ldap_groups_auth {
  my $self = shift;
  my $allow_auth = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ldap.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ldap.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ldap.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $server = $ENV{LDAP_SERVER} ? $ENV{LDAP_SERVER} : 'localhost';
  my $bind_dn = $ENV{LDAP_BIND_DN};
  my $bind_pass = $ENV{LDAP_BIND_PASS};
  my $ldap_base = $ENV{LDAP_USER_BASE};
  my $user = 'proftpdtest' . int(rand(4294967296));
  my $passwd = 'foobar';
  my $uid = 1000;
  my $gid = 1000;
  my $home_dir = File::Spec->rel2abs($tmpdir);

  my $group = 'proftpdtestgroup' . int(rand(4294967296));
  my $groupid = 10000;

  my $ld = Net::LDAP->new([$server]);
  $self->assert($ld);
  $self->assert($ld->bind($bind_dn, password => $bind_pass));

  my $entry = Net::LDAP::Entry->new("uid=$user,$ldap_base");
  $entry->delete();
  my $msg = $entry->update($ld);
  $self->assert(!$msg->is_error() || $msg->code() == LDAP_NO_SUCH_OBJECT);

  $entry = Net::LDAP::Entry->new("cn=$group,$ldap_base");
  $entry->delete();
  $msg = $entry->update($ld);
  $self->assert(!$msg->is_error() || $msg->code() == LDAP_NO_SUCH_OBJECT);

  $entry = Net::LDAP::Entry->new(
    "uid=$user,$ldap_base",
    objectClass => ['posixAccount', 'account'],
    uid => $user,
    userPassword => $passwd,
    uidNumber => $uid,
    gidNumber => $gid,
    homeDirectory => $home_dir,
    cn => 'ProFTPD Test',
  );
  $msg = $entry->update($ld);
  $self->assert(!$msg->is_error());

  if ($allow_auth) {
    $entry = Net::LDAP::Entry->new(
      "cn=$group,$ldap_base",
      objectClass => 'posixGroup',
      cn => $group,
      gidNumber => $groupid,
      memberUid => $user,
    );
  } else {
    $entry = Net::LDAP::Entry->new(
      "cn=$group,$ldap_base",
      objectClass => 'posixGroup',
      cn => $group,
      gidNumber => $groupid,
    );
  }
  $msg = $entry->update($ld);
  $self->assert(!$msg->is_error());

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'auth:10',

    Limit => {
      LOGIN => {
        AllowGroup => $group,
        DenyAll => '',
      }
    },

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_ldap.c' => {
        LDAPServer => $server,
        LDAPBindDN => "$bind_dn $bind_pass",
        LDAPUsers => "$ldap_base (uid=%u)",
        LDAPGroups => "$ldap_base (uid=%u)",
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
      if ($allow_auth) {
        $client->login($user, $passwd);
      } else {
        eval { $client->login($user, $passwd) };
        unless ($@) {
          die("Login succeeded unexpectedly");
        }
      }

      my ($resp_code, $resp_msg);
      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      if ($allow_auth) {
        $expected = 230;
        $self->assert($expected == $resp_code,
          test_msg("Expected $expected, got $resp_code"));

        $expected = "User $user logged in";
        $self->assert($expected eq $resp_msg,
          test_msg("Expected '$expected', got '$resp_msg'"));
      } else {
        $expected = 530;
        $self->assert($expected == $resp_code,
          test_msg("Expected $expected, got $resp_code"));

        $expected = 'Login incorrect.';
        $self->assert($expected eq $resp_msg,
          test_msg("Expected '$expected', got '$resp_msg'"));
      }
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

  server_stop($pid_file);

  $self->assert_child_ok($pid);

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub ldap_groups_authdenied {
  my $self = shift;

  ldap_groups_auth($self, 0);
}

sub ldap_groups_authallowed {
  my $self = shift;

  ldap_groups_auth($self, 1);
}

sub ldap_quota {
  my $self = shift;
  my $default_quota = shift;
  my $tmpdir = $self->{tmpdir};
  my $abs_tmpdir = File::Spec->rel2abs($self->{tmpdir});

  my $config_file = "$tmpdir/ldap.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ldap.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ldap.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $server = $ENV{LDAP_SERVER} ? $ENV{LDAP_SERVER} : 'localhost';
  my $bind_dn = $ENV{LDAP_BIND_DN};
  my $bind_pass = $ENV{LDAP_BIND_PASS};
  my $ldap_base = $ENV{LDAP_USER_BASE};
  my $user = 'proftpdtest' . int(rand(4294967296));
  my $passwd = 'foobar';
  my $uid = 1000;
  my $gid = 1000;
  my $home_dir = File::Spec->rel2abs($tmpdir);

  my $ftpquota_path;
  if ($ENV{PROFTPD_TEST_PATH}) {
    $ftpquota_path = "$ENV{PROFTPD_TEST_PATH}/../contrib/ftpquota";
  } else {
    $ftpquota_path = '../contrib/ftpquota';
  }

  my $ld = Net::LDAP->new([$server]);
  $self->assert($ld);
  $self->assert($ld->bind($bind_dn, password => $bind_pass));

  my $entry = Net::LDAP::Entry->new("uid=$user,$ldap_base");
  $entry->delete();
  my $msg = $entry->update($ld);
  if ($msg->is_error()) {
    $self->annotate($msg->error());
  }
  $self->assert(!$msg->is_error() || $msg->code() == LDAP_NO_SUCH_OBJECT);

  if ($default_quota) {
    $entry = Net::LDAP::Entry->new(
      "uid=$user,$ldap_base",
      objectClass => ['posixAccount', 'account'],
      uid => $user,
      userPassword => $passwd,
      uidNumber => $uid,
      gidNumber => $gid,
      homeDirectory => $home_dir,
      cn => 'ProFTPD Test',
    );
  } else {
    $entry = Net::LDAP::Entry->new(
      "uid=$user,$ldap_base",
      objectClass => ['posixAccount', 'account', 'proftpdQuota'],
      uid => $user,
      userPassword => $passwd,
      uidNumber => $uid,
      gidNumber => $gid,
      homeDirectory => $home_dir,
      cn => 'ProFTPD Test',
      ftpQuota => 'false,hard,1048576,0,0,0,0,0',
    );
  }
  $msg = $entry->update($ld);
  $self->assert(!$msg->is_error());

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'auth:10',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_ldap.c' => {
        LDAPServer => $server,
        LDAPBindDN => "$bind_dn $bind_pass",
        LDAPUsers => "$ldap_base (uid=%u)",
        LDAPDefaultQuota => 'false,hard,10485760,0,0,0,0,0',
      },

      'mod_quotatab.c' => {
        QuotaEngine => 'on',
        QuotaShowQuotas => 'on',
        QuotaDisplayUnits => 'Mb',
        QuotaLimitTable => 'ldap:',
        QuotaTallyTable => "file:$abs_tmpdir/quota-tally",
        QuotaLog => '/var/log/quota',
      },
    },
  };

  # FIXME: error checking?
  system("$ftpquota_path --type tally --create-table --table-path \"$tmpdir/quota-tally\"");

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

      my ($resp_code, $resp_msg);
      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user logged in";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));


      $client->quote('SITE QUOTA');
      $resp_code = $client->response_code();
      $resp_msg = join("\n", @{$client->response_msgs()});

      $self->assert_matches(qr/Quota Type:\s*User/mi, $resp_msg,
        test_msg("Expected User quota type, got '$resp_msg'"));
      if ($default_quota) {
        $self->assert_matches(qr/Uploaded Mb:\s*0\.00\/10\.00/mi, $resp_msg,
          test_msg("Expected 0.0/1.0 Mb uploaded, got '$resp_msg'"));
      } else {
        $self->assert_matches(qr/Uploaded Mb:\s*0\.00\/1\.00/mi, $resp_msg,
          test_msg("Expected 0.0/1.0 Mb uploaded, got '$resp_msg'"));
      }

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

  server_stop($pid_file);

  $self->assert_child_ok($pid);

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub ldap_quota_on_user {
  my $self = shift;

  ldap_quota($self, 0);
}

sub ldap_quota_default {
  my $self = shift;

  ldap_quota($self, 1);
}

sub ldap_default_uid_gid {
  my $self = shift;
  my $uid_or_gid = shift;
  my $force_default = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ldap.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ldap.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ldap.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $server = $ENV{LDAP_SERVER} ? $ENV{LDAP_SERVER} : 'localhost';
  my $bind_dn = $ENV{LDAP_BIND_DN};
  my $bind_pass = $ENV{LDAP_BIND_PASS};
  my $ldap_base = $ENV{LDAP_USER_BASE};
  my $user = 'proftpdtest' . int(rand(4294967296));
  my $passwd = 'foobar';
  my $ldap_uid = 1000;
  my $ldap_gid = 1000;
  my $home_dir = File::Spec->rel2abs($tmpdir) . "/$user";

  mkdir($home_dir);

  my $ld = Net::LDAP->new([$server]);
  $self->assert($ld);
  $self->assert($ld->bind($bind_dn, password => $bind_pass));

  my $entry = Net::LDAP::Entry->new("uid=$user,$ldap_base");
  $entry->delete();
  my $msg = $entry->update($ld);
  if ($msg->is_error()) {
    $self->annotate($msg->error());
  }
  $self->assert(!$msg->is_error() || $msg->code() == LDAP_NO_SUCH_OBJECT);

  # FIXME: posixAccount requires [ug]idNumber, so we can't check
  # LDAPDefault[UG]ID behavior when uidNumber/gidNumber are absent.
  # We'll have to declare a dependency on a different (local)
  # objectClass, or have the mod_ldap test suite depend on OpenLDAP's
  # slapd being installed, and start our own directory instance.
  $entry = Net::LDAP::Entry->new(
    "uid=$user,$ldap_base",
    objectClass => ['posixAccount', 'account'],
    uid => $user,
    userPassword => $passwd,
    uidNumber => $ldap_uid,
    gidNumber => $ldap_gid,
    homeDirectory => $home_dir,
    cn => 'ProFTPD Test',
  );
  $msg = $entry->update($ld);
  $self->assert(!$msg->is_error());

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'auth:10',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_ldap.c' => {
        LDAPServer => $server,
        LDAPBindDN => "$bind_dn $bind_pass",
        LDAPUsers => "$ldap_base (uid=%u)",
        LDAPGenerateHomedir => 'on',
        LDAPGenerateHomedirPrefix => $tmpdir,
      },
    },
  };
  # If we're forcing the UID/GID, force a *different* UID/GID so
  # we can determine whether the forcing is in effect.
  my $proftpd_uid = $ldap_uid;
  my $proftpd_gid = $ldap_gid;
  if ($uid_or_gid eq 'uid') {
    if ($force_default) {
      $proftpd_uid = $ldap_uid + 1;
      $config->{IfModules}->{'mod_ldap.c'}->{LDAPForceDefaultUID} = 'on';
    }
    $config->{IfModules}->{'mod_ldap.c'}->{LDAPDefaultUID} = $proftpd_uid;
  } elsif ($uid_or_gid eq 'gid') {
    if ($force_default) {
      $proftpd_gid = $ldap_gid + 1;
      $config->{IfModules}->{'mod_ldap.c'}->{LDAPForceDefaultGID} = 'on';
    }
    $config->{IfModules}->{'mod_ldap.c'}->{LDAPDefaultGID} = $proftpd_gid;
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($proftpd_uid, $proftpd_gid, $home_dir)) {
      die("Can't set owner of $home_dir to $proftpd_uid/$proftpd_gid: $!");
    }
  }

  open(HDIR_FILE, ">$home_dir/testfile") ||
    die("Unable to open $home_dir/testfile for writing: $!");
  print HDIR_FILE "test file\n";
  close(HDIR_FILE);
  unless (chown($proftpd_uid, $proftpd_gid, "$home_dir/testfile")) {
    die("Can't set owner of $home_dir/testfile to $ldap_uid/$ldap_gid: $!");
  }
  unless (chmod(0700, "$home_dir/testfile")) {
    die("Can't set file permission bits on $home_dir/testfile to 0700: $!");
  }

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

      my ($resp_code, $resp_msg);
      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user logged in";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      $client->retr('testfile');
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

  server_stop($pid_file);

  $self->assert_child_ok($pid);

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub ldap_default_uid {
  my $self = shift;

  ldap_default_uid_gid($self, 'uid', 0);
}

sub ldap_default_gid {
  my $self = shift;

  ldap_default_uid_gid($self, 'gid', 0);
}

sub ldap_default_force_uid {
  my $self = shift;

  ldap_default_uid_gid($self, 'uid', 1);
}

sub ldap_default_force_gid {
  my $self = shift;

  ldap_default_uid_gid($self, 'gid', 1);
}

sub ldap_alias_dereference {
  my $self = shift;
  my $dereference_enabled = shift;
  my $tmpdir = $self->{tmpdir};
  my $abs_tmpdir = File::Spec->rel2abs($self->{tmpdir});

  my $config_file = "$tmpdir/ldap.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ldap.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ldap.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $server = $ENV{LDAP_SERVER} ? $ENV{LDAP_SERVER} : 'localhost';
  my $bind_dn = $ENV{LDAP_BIND_DN};
  my $bind_pass = $ENV{LDAP_BIND_PASS};
  my $ldap_base = $ENV{LDAP_USER_BASE};
  my $ldap_base_alias = 'ou=proftpdtest' . int(rand(4294967296)) . ',' .
    $ldap_base;
  my $user = 'proftpdtest' . int(rand(4294967296));
  my $passwd = 'foobar';
  my $uid = 1000;
  my $gid = 1000;
  my $home_dir = File::Spec->rel2abs($tmpdir);

  my $ld = Net::LDAP->new([$server]);
  $self->assert($ld);
  $self->assert($ld->bind($bind_dn, password => $bind_pass));

  my $entry = Net::LDAP::Entry->new("uid=$user,$ldap_base");
  $entry->delete();
  my $msg = $entry->update($ld);
  if ($msg->is_error()) {
    $self->annotate($msg->error());
  }
  $self->assert(!$msg->is_error() || $msg->code() == LDAP_NO_SUCH_OBJECT);

  $entry = Net::LDAP::Entry->new(
    $ldap_base_alias,
    objectClass => ['alias', 'extensibleObject'],
    aliasedObjectName => $ldap_base,
  );
  $msg = $entry->update($ld);
  $self->assert(!$msg->is_error());

  $entry = Net::LDAP::Entry->new(
    "uid=$user,$ldap_base",
    objectClass => ['posixAccount', 'account'],
    uid => $user,
    userPassword => $passwd,
    uidNumber => $uid,
    gidNumber => $gid,
    homeDirectory => $home_dir,
    cn => 'ProFTPD Test',
  );
  $msg = $entry->update($ld);
  $self->assert(!$msg->is_error());

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'auth:10',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_ldap.c' => {
        LDAPServer => $server,
        LDAPBindDN => "$bind_dn $bind_pass",
        LDAPUsers => "$ldap_base_alias (uid=%u)",
      },

      'mod_quotatab.c' => {
        QuotaEngine => 'on',
        QuotaShowQuotas => 'on',
        QuotaDisplayUnits => 'Mb',
        QuotaLimitTable => 'ldap:',
        QuotaTallyTable => "file:$abs_tmpdir/quota-tally",
        QuotaLog => '/var/log/quota',
      },
    },
  };
  if ($dereference_enabled) {
    $config->{IfModules}->{'mod_ldap.c'}->{LDAPAliasDereference} = 'always';
  }

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
      if ($dereference_enabled) {
        $client->login($user, $passwd);
      } else {
        eval { $client->login($user, $passwd) };
        unless ($@) {
          die("Login succeeded unexpectedly");
        }
      }

      my ($resp_code, $resp_msg);
      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      if ($dereference_enabled) {
        $expected = 230;
        $self->assert($expected == $resp_code,
          test_msg("Expected $expected, got $resp_code"));

        $expected = "User $user logged in";
        $self->assert($expected eq $resp_msg,
          test_msg("Expected '$expected', got '$resp_msg'"));
      } else {
        $expected = 530;
        $self->assert($expected == $resp_code,
          test_msg("Expected $expected, got $resp_code"));

        $expected = 'Login incorrect.';
        $self->assert($expected eq $resp_msg,
          test_msg("Expected '$expected', got '$resp_msg'"));
      }

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

  server_stop($pid_file);

  $self->assert_child_ok($pid);

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub ldap_alias_dereference_off {
  my $self = shift;

  ldap_alias_dereference($self, 0);
}

sub ldap_alias_dereference_on {
  my $self = shift;

  ldap_alias_dereference($self, 1);
}

sub ldap_scope {
  my $self = shift;
  my $scope = shift;
  my $tmpdir = $self->{tmpdir};
  my $abs_tmpdir = File::Spec->rel2abs($self->{tmpdir});

  my $config_file = "$tmpdir/ldap.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ldap.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ldap.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $server = $ENV{LDAP_SERVER} ? $ENV{LDAP_SERVER} : 'localhost';
  my $bind_dn = $ENV{LDAP_BIND_DN};
  my $bind_pass = $ENV{LDAP_BIND_PASS};
  my $ldap_base = $ENV{LDAP_USER_BASE};
  my $user = 'proftpdtest' . int(rand(4294967296));
  my $passwd = 'foobar';
  my $uid = 1000;
  my $gid = 1000;
  my $home_dir = File::Spec->rel2abs($tmpdir);

  my $ld = Net::LDAP->new([$server]);
  $self->assert($ld);
  $self->assert($ld->bind($bind_dn, password => $bind_pass));

  my $entry = Net::LDAP::Entry->new("uid=$user,$ldap_base");
  $entry->delete();
  my $msg = $entry->update($ld);
  if ($msg->is_error()) {
    $self->annotate($msg->error());
  }
  $self->assert(!$msg->is_error() || $msg->code() == LDAP_NO_SUCH_OBJECT);

  $entry = Net::LDAP::Entry->new(
    "uid=$user,$ldap_base",
    objectClass => ['posixAccount', 'account'],
    uid => $user,
    userPassword => $passwd,
    uidNumber => $uid,
    gidNumber => $gid,
    homeDirectory => $home_dir,
    cn => 'ProFTPD Test',
  );
  $msg = $entry->update($ld);
  $self->assert(!$msg->is_error());

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'auth:10',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_ldap.c' => {
        LDAPServer => $server,
        LDAPBindDN => "$bind_dn $bind_pass",
        LDAPUsers => "$ldap_base (uid=%u)",
        LDAPSearchScope => $scope,
      },

      'mod_quotatab.c' => {
        QuotaEngine => 'on',
        QuotaShowQuotas => 'on',
        QuotaDisplayUnits => 'Mb',
        QuotaLimitTable => 'ldap:',
        QuotaTallyTable => "file:$abs_tmpdir/quota-tally",
        QuotaLog => '/var/log/quota',
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
      if ($scope eq 'subtree') {
        $client->login($user, $passwd);
      } else {
        eval { $client->login($user, $passwd) };
        unless ($@) {
          die("Login succeeded unexpectedly");
        }
      }

      my ($resp_code, $resp_msg);
      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      if ($scope eq 'subtree') {
        $expected = 230;
        $self->assert($expected == $resp_code,
          test_msg("Expected $expected, got $resp_code"));

        $expected = "User $user logged in";
        $self->assert($expected eq $resp_msg,
          test_msg("Expected '$expected', got '$resp_msg'"));
      } else {
        $expected = 530;
        $self->assert($expected == $resp_code,
          test_msg("Expected $expected, got $resp_code"));

        $expected = 'Login incorrect.';
        $self->assert($expected eq $resp_msg,
          test_msg("Expected '$expected', got '$resp_msg'"));
      }

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

  server_stop($pid_file);

  $self->assert_child_ok($pid);

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

sub ldap_scope_base {
  my $self = shift;

  ldap_scope($self, 'base');
}

sub ldap_scope_sub {
  my $self = shift;

  ldap_scope($self, 'subtree');
}

sub ldap_default_auth_scheme {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $abs_tmpdir = File::Spec->rel2abs($self->{tmpdir});

  my $config_file = "$tmpdir/ldap.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ldap.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ldap.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $server = $ENV{LDAP_SERVER} ? $ENV{LDAP_SERVER} : 'localhost';
  my $bind_dn = $ENV{LDAP_BIND_DN};
  my $bind_pass = $ENV{LDAP_BIND_PASS};
  my $ldap_base = $ENV{LDAP_USER_BASE};
  my $user = 'proftpdtest' . int(rand(4294967296));
  my $passwd = 'foobar';
  my $uid = 1000;
  my $gid = 1000;
  my $home_dir = File::Spec->rel2abs($tmpdir);

  my $ld = Net::LDAP->new([$server]);
  $self->assert($ld);
  $self->assert($ld->bind($bind_dn, password => $bind_pass));

  my $entry = Net::LDAP::Entry->new("uid=$user,$ldap_base");
  $entry->delete();
  my $msg = $entry->update($ld);
  if ($msg->is_error()) {
    $self->annotate($msg->error());
  }
  $self->assert(!$msg->is_error() || $msg->code() == LDAP_NO_SUCH_OBJECT);

  $entry = Net::LDAP::Entry->new(
    "uid=$user,$ldap_base",
    objectClass => ['posixAccount', 'account'],
    uid => $user,
    userPassword => crypt($passwd,
      join '', ('.', '/', 0 .. 9, 'A' .. 'Z', 'a' .. 'z')[rand 64, rand 64]),
    uidNumber => $uid,
    gidNumber => $gid,
    homeDirectory => $home_dir,
    cn => 'ProFTPD Test',
  );
  $msg = $entry->update($ld);
  $self->assert(!$msg->is_error());

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'auth:10',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_ldap.c' => {
        LDAPServer => $server,
        LDAPBindDN => "$bind_dn $bind_pass",
        LDAPUsers => "$ldap_base (uid=%u)",
        LDAPAuthBinds => 'off',
        LDAPDefaultAuthScheme => 'crypt',
      },

      'mod_quotatab.c' => {
        QuotaEngine => 'on',
        QuotaShowQuotas => 'on',
        QuotaDisplayUnits => 'Mb',
        QuotaLimitTable => 'ldap:',
        QuotaTallyTable => "file:$abs_tmpdir/quota-tally",
        QuotaLog => '/var/log/quota',
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

      my ($resp_code, $resp_msg);
      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "User $user logged in";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

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

  server_stop($pid_file);

  $self->assert_child_ok($pid);

  if ($ex) {
    die($ex);
  }

  unlink($log_file);
}

1;
