package ProFTPD::Tests::Modules::mod_tls;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use Carp;
use File::Copy;
use File::Path qw(mkpath);
use File::Spec;
use IO::Handle;
use Socket;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  tls_login_rsa => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_login_dsa => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_double_auth => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_login_pkcs12 => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_dh_ciphersuite => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_crl_file_ok => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_list_no_session_reuse => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_list_with_no_session_reuse_required_opt => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_list_fails_tls_required_by_dir_bug2178 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_list_ok_tls_required_by_dir_bug2178 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_list_fails_tls_required_by_ftpaccess_bug2178 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_list_ok_tls_required_by_ftpaccess_bug2178 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_incompatible_config_bug3247 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  # Note: this test requires rootprivs to bind to port 990
  tls_implicit_ssl_bug3266 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  tls_client_cert_verify_failed_embedded_nul_bug3275 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_opts_std_env_vars => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_opts_std_env_vars_client_vars => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_opts_ipaddr_required_ipv4 => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_opts_ipaddr_required_ipv6 => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_opts_allow_per_user_tlsrequired_on_anon_login_bug3325 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  tls_opts_allow_per_user_tlsrequired_on_user_login_bug3325 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_opts_allow_per_user_tlsrequired_auth_user_login_bug3325 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_opts_allow_per_user_tlsrequired_ctrl_user_login_bug3325 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_opts_allow_per_user_tlsrequired_data_user_login_bug3325 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_opts_allow_per_user_tlsrequired_on_ifsess_login_bug3325 => {
    order => ++$order,
    test_class => [qw(bug forking mod_ifsession)],
  },

  tls_rest_2gb_last_byte => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_rest_4gb_last_byte => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_stor_empty_file => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_retr_empty_file => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_required_on_feat_allowed_bug3420 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  # Note: this test requires rootprivs to bind to port 990
  tls_implicit_ssl_bug3437 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  tls_ccc_list_bug3465 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_ccc_before_login => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_opts_commonname_required_bug3512 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_opts_dns_name_required => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_opts_ip_addr_dns_name_cn_required => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_site_chmod_ok => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_default_tlsrequired => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_protocols_default => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_protocols_with_ftps => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_protocols_without_ftps => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_ifsess_protocols_with_ftps => {
    order => ++$order,
    test_class => [qw(forking mod_ifsession)],
  },

  tls_ifsess_protocols_without_ftps => {
    order => ++$order,
    test_class => [qw(forking mod_ifsession)],
  },

  tls_sess_cache_internal_bug3580 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_passphraseprovider => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_verify_order_crl_bug3658 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_verify_order_ocsp => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  # XXX Need to find a working HTTPS OCSP responder for this test;
  # OpenSSL's ocsp(1) responder does NOT function in HTTPS mode, contrary
  # to the impression given by its docs.
  tls_verify_order_ocsp_https => {
    order => ++$order,
    test_class => [qw(bug forking inprogress)],
  },

  tls_client_cert_verify_failed_selfsigned_cert_only_bug3742 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_client_cert_verify_failed_selfsigned_cert_in_chain_bug3742 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_client_cert_verify_ok_server_selfsigned_cert_in_chain_bug3742 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_opts_allow_dot_login => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_opts_multiple_lines_bug3800 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_config_tlsmasqueradeaddress_bug3862 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_config_tlsdhparamfile_bug3868 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_config_tlsciphersuite_bad_cipher => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_config_tlscacertfile_bad_format => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_config_tlscarevocationfile_bad_format => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_config_tlsdsacertfile_bad_format => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_config_tlsdsacertfile_not_dsa => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_config_tlsdsacertkeyfile_bad_format => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_config_tlsrsacertkeyfile_passphrase => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  tls_session_cache_off_bug3869 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_limit_prot_bug3887 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_config_tlsusername_bug3899 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_sscn_no_args_bug3955 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_sscn_too_many_args_bug3955 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_sscn_bad_arg_bug3955 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_sscn_toggle_bug3955 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_config_limit_sscn_bug3955 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_config_missing_certs => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_stapling_on_bug4175 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_session_tickets_on_bug4176 => {
    order => ++$order,
    test_class => [qw(bug forking inprogress)],
  },

  tls_restart_protected_certs_bug4260 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  tls_fxp_issue618 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  # Check for the required Perl modules:
  #
  #  Net-SSLeay
  #  IO-Socket-SSL
  #  Net-FTPSSL

  my $required = [qw(
    Net::SSLeay
    IO::Socket::SSL
    Net::FTPSSL
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

sub tls_login_rsa {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
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

sub tls_login_dsa {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/dsa-server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/dsa-ca.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSDSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
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

sub tls_double_auth {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      # Sending AUTH after we've established our SSL/TLS session should
      # fail.
      if ($client->auth()) {
        die("Second AUTH succeeded unexpectedly");
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

sub tls_login_pkcs12 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $pkcs12_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.p12');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSPKCS12File => $pkcs12_file,
        TLSCACertificateFile => $ca_file,
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
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

sub tls_dh_ciphersuite {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $ssl_opts = {
        # Results in set_tmp_dh_callback() keylength of 1024 BITS
        SSL_cipher_list => 'DHE-RSA-AES256-SHA',
        SSL_ca_file => $ca_file,
      };

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
        SSL_Client_Certificate => $ssl_opts,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
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

sub tls_crl_file_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $server_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/crl-server-cert.pem');
  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/crl-client-cert.pem');
  my $ca_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/crl-ca.pem');
  my $crl_file = File::Spec->rel2abs('t/etc/modules/mod_tls/crl-ca-revoked.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $server_cert,
        TLSCACertificateFile => $ca_cert,

        # Verifying clients via CRLs only works when verification is
        # explicitly enabled.
        TLSCARevocationFile => $crl_file,
        TLSVerifyClient => 'on',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client;

      eval {
        # IO::Socket::SSL options
        my $ssl_opts = {
          SSL_use_cert => 1,
          SSL_cert_file => $client_cert,
          SSL_key_file => $client_cert,
          SSL_ca_file => $ca_cert,
        };

        $client = Net::FTPSSL->new('127.0.0.1',
          Croak => 1,
          Encryption => 'E',
          Port => $port,
          SSL_Client_Certificate => $ssl_opts,
        );
      };

      my $ex = $@;
      unless ($ex) {
        die("SSL connection succeeded unexpectedly");
      }

      my $errstr = IO::Socket::SSL::errstr();

      my $expected = 'certificate revoked';
      $self->assert(qr/$expected/, $errstr,
        test_msg("Expected '$expected', got '$errstr'"));
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

sub tls_list_no_session_reuse {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
        Croak => 1,
      );

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      # Since we are requiring SSL session reuse for data transfers,
      # and this client is not using SSL session resumption, I expect
      # this data transfer to fail.
      eval { 
        my $res = $client->list('.');
        if ($res) {
          die("LIST succeeded unexpectedly");
        }
      };

      unless ($@) {
        die("LIST succeeded unexpectedly");
      }

      my $resp = $client->message();
      my $expected = '425 Unable to build data connection: Operation not permitted';
      $self->assert($expected eq $resp,
        test_msg("Expected '$expected', got '$resp'"));
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

sub tls_list_with_no_session_reuse_required_opt {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,

        TLSOptions => 'NoSessionReuseRequired',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
        Croak => 1,
      );

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      # Since we are NOT requiring SSL session reuse for data transfers,
      # and this client is not using SSL session resumption, I expect
      # this data transfer to succeed.
      my $res = $client->list('.');
      unless ($res) {
        die("LIST failed unexpectedly: " . $client->message());
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

sub tls_list_fails_tls_required_by_dir_bug2178 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $server_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert.pem');
  my $ca_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    Directory => {
      $home_dir => {
        TLSRequired => 'on',
      },
    },

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'off',
        TLSRSACertificateFile => $server_cert,
        TLSCACertificateFile => $ca_cert,
        TLSOptions => 'NoSessionReuseRequired',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client;

      # IO::Socket::SSL options
      my $ssl_opts = {
        SSL_use_cert => 1,
        SSL_cert_file => $client_cert,
        SSL_key_file => $client_cert,
        SSL_ca_file => $ca_cert,
      };

      $client = Net::FTPSSL->new('127.0.0.1',
        Croak => 1,
        DataProtLevel => 'C',
        Encryption => 'E',
        Port => $port,
        SSL_Client_Certificate => $ssl_opts,
      );

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      my $res;
      eval { $res = $client->list() };
      if (!$@ &&
          defined($res)) {
        die("LIST succeeded unexpectedly");
      }

      my $resp_msg = $client->last_message();

      my $expected = '522 SSL/TLS required on the data channel';
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

sub tls_list_ok_tls_required_by_dir_bug2178 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $server_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert.pem');
  my $ca_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    Directory => {
      $home_dir => {
        TLSRequired => 'on',
      },
    },

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'off',
        TLSRSACertificateFile => $server_cert,
        TLSCACertificateFile => $ca_cert,
        TLSOptions => 'NoSessionReuseRequired',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client;

      # IO::Socket::SSL options
      my $ssl_opts = {
        SSL_use_cert => 1,
        SSL_cert_file => $client_cert,
        SSL_key_file => $client_cert,
        SSL_ca_file => $ca_cert,
      };

      $client = Net::FTPSSL->new('127.0.0.1',
        Croak => 1,
        DataProtLevel => 'P',
        Encryption => 'E',
        Port => $port,
        SSL_Client_Certificate => $ssl_opts,
      );

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      my $res = $client->list();
      unless ($res) {
        die("LIST failed unexpectedly: " . $client->last_message());
      }

      my $resp_msg = $client->last_message();
      $client->quit();

      my $expected = '226 Transfer complete';
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

sub tls_list_fails_tls_required_by_ftpaccess_bug2178 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $server_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert.pem');
  my $ca_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $sub_dir = File::Spec->rel2abs("$home_dir/subdir");
  mkpath($sub_dir);

  my $access_file = File::Spec->rel2abs("$sub_dir/.ftpaccess");
  if (open(my $fh, "> $access_file")) {
    print $fh "TLSRequired on\n";
    unless (close($fh)) {
      die("Can't write $access_file: $!");
    }

  } else {
    die("Can't open $access_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 directory:20 ftpaccess:20',

    AllowOverride => 'on',
    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'off',
        TLSRSACertificateFile => $server_cert,
        TLSCACertificateFile => $ca_cert,
        TLSOptions => 'NoSessionReuseRequired',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client;

      # IO::Socket::SSL options
      my $ssl_opts = {
        SSL_use_cert => 1,
        SSL_cert_file => $client_cert,
        SSL_key_file => $client_cert,
        SSL_ca_file => $ca_cert,
      };

      $client = Net::FTPSSL->new('127.0.0.1',
        Croak => 1,
        DataProtLevel => 'C',
        Encryption => 'E',
        Port => $port,
        SSL_Client_Certificate => $ssl_opts,
      );

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      $client->cwd('subdir');

      my $res;
      eval { $res = $client->list() };
      unless ($@) {
        die("LIST succeeded unexpectedly");
      }

      my $resp_msg = $client->last_message();

      my $expected = '522 SSL/TLS required on the data channel';
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

sub tls_list_ok_tls_required_by_ftpaccess_bug2178 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $server_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert.pem');
  my $ca_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $sub_dir = File::Spec->rel2abs("$home_dir/subdir");
  mkpath($sub_dir);

  my $access_file = File::Spec->rel2abs("$sub_dir/.ftpaccess");
  if (open(my $fh, "> $access_file")) {
    print $fh "TLSRequired on\n";
    unless (close($fh)) {
      die("Can't write $access_file: $!");
    }

  } else {
    die("Can't open $access_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AllowOverride => 'on',
    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'off',
        TLSRSACertificateFile => $server_cert,
        TLSCACertificateFile => $ca_cert,
        TLSOptions => 'NoSessionReuseRequired',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client;

      # IO::Socket::SSL options
      my $ssl_opts = {
        SSL_use_cert => 1,
        SSL_cert_file => $client_cert,
        SSL_key_file => $client_cert,
        SSL_ca_file => $ca_cert,
      };

      $client = Net::FTPSSL->new('127.0.0.1',
        Croak => 1,
        DataProtLevel => 'P',
        Encryption => 'E',
        Port => $port,
        SSL_Client_Certificate => $ssl_opts,
      );

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      $client->cwd('subdir');
      my $res = $client->list();
      if ($res) {
        die("LIST succeeded unexpectedly");
      }

      my $resp_msg = $client->last_message();
      $client->quit();

      my $expected = '226 Transfer complete';
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

sub tls_incompatible_config_bug3247 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $server_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert.pem');
  my $ca_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'auth',
        TLSRSACertificateFile => $server_cert,
        TLSCACertificateFile => $ca_cert,
        TLSOptions => 'AllowPerUser',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  eval { server_start($config_file, $pid_file) };
  unless ($@) {
    test_append_logfile($log_file, "server started unexpectedly");
    unlink($log_file);

    die("server started unexpectedly");
  }

  unlink($log_file);
}

sub tls_implicit_ssl_bug3266 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $config = {

    # The stupid Net::FTPSSL client requires port 990 when implicit
    # FTPS is used, regardless of the port we pass to the constructor.
    # (What kind of client API does not allow the port to be changed??)
    Port => 990,

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSOptions => 'UseImplicitSSL',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client_opts = {
        Encryption => 'I',
        Port => $port,
      };

      if ($ENV{TEST_VERBOSE}) {
        $client_opts->{Debug} = 1;
      }

      my $client = Net::FTPSSL->new('127.0.0.1', %$client_opts);

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
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

sub tls_client_cert_verify_failed_embedded_nul_bug3275 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $server_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
#  my $ca_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');
  my $ca_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-nul-subjaltname.pem');

  # The cert/key with embedded NULs in the subjAltName field were obtained
  # from:
  #
  #  http://people.redhat.com/thoger/certs-with-nuls/

  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/cert-nul-subjaltname.pem');
  my $client_key = File::Spec->rel2abs('t/etc/modules/mod_tls/key-nul-subjaltname.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $server_cert,
        TLSCACertificateFile => $ca_cert,

        TLSVerifyClient => 'on',

        # To trigger Bug#3275, we need to verify the subjAltName field in
        # the present cert, which means enabling DNS resolution
        TLSOptions => 'dNSNameRequired',

        # We need to enable reverse DNS resolution as well, for this to work
        UseReverseDNS => 'on',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client;

      eval {
        # IO::Socket::SSL options
        my $ssl_opts = {
          SSL_use_cert => 1,
          SSL_cert_file => $client_cert,
          SSL_key_file => $client_key,
        };

        $client = Net::FTPSSL->new('127.0.0.1',
          Croak => 1,
          Encryption => 'E',
          Port => $port,
          SSL_Client_Certificate => $ssl_opts,
        );

        # Net::FTPSSL is rather stupid, and treats the initial 234 response
        # code (indicating that the SSL/TLS handshake should proceed) as
        # indicating success _of the handshake_.
        #
        # Thus if we want to test if the handshake succeeded, we have to
        # act as if it did succeed, then try to login (which should fail).
        # Sigh.

        unless ($client->login($user, $passwd)) {
          die("Can't login: " . $client->last_message());
        }
      };

      if ($@) {
        die($@);
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

  # Stop server
  server_stop($pid_file);

  $self->assert_child_ok($pid);

  unless ($ex) {
    die("Test succeeded unexpectedly");
  }

  # Not quite done yet.  To make sure that this test did as expected, we
  # need to examine the log file, and look for the phrase 'spoof attempt'.
  # That indicates that mod_tls saw the embedded NUL.
  if (open(my $fh, "< $log_file")) {
    my $ok = 0;

    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /spoof attempt/) {
        $ok = 1;
        last;
      }
    }

    close($fh);

    unless ($ok) {
      die("Expected TLSLog 'spoof attempt' not found as expected");
    }

  } else {
    die("Can't read $log_file: $!");
  }

  unlink($log_file);
}

sub tls_opts_std_env_vars {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    # Yes, this has a deliberately wrong variable for TLS_CLIENT_S_DN;
    # I use it to make sure that mod_log handles that particular formatting
    # as one would expect (i.e. replace it with an empty string).
    LogFormat => 'custom "FTPS=%{FTPS}e TLS_PROTOCOL=%{TLS_PROTOCOL}e TLS_SESSION_ID=%{TLS_SESSION_ID}e TLS_CIPHER=%{TLS_CIPHER}e TLS_LIBRARY_VERSION=%{TLS_LIBRARY_VERSION}e TLS_CLIENT_S_DN=\'%{env:TLS_CLIENT_S_DN}\'"',
    ExtendedLog => "$ext_log AUTH custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => 'StdEnvVars',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
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

  # Stop server
  server_stop($pid_file);

  $self->assert_child_ok($pid);

  if ($ex) {
    die($ex);
  }

  # Open the ExtendedLog, and check for the expected environment variables
  if (open(my $fh, "< $ext_log")) {
    my $ok = 0;

    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /FTPS=(\d+) TLS_PROTOCOL=(\S+) TLS_SESSION_ID=(\S+) TLS_CIPHER=(\S+) TLS_LIBRARY_VERSION=(.*?) TLS_CLIENT_S_DN=''/) {
        my $ftps = $1;
        my $protocol = $2;
        my $sess_id = $3;
        my $cipher = $4;
        my $libversion = $5;

        $self->assert($ftps eq '1',
          test_msg("Expected '1', got '$ftps'"));
        $self->assert(length($protocol) > 0,
          test_msg("Expected protocol, got '$protocol'"));      
        $self->assert(length($sess_id) > 0,
          test_msg("Expected session ID, got '$sess_id'"));      
        $self->assert(length($cipher) > 0,
          test_msg("Expected cipher, got '$cipher"));      
        $self->assert(length($libversion) > 0,
          test_msg("Expected cipher, got '$libversion"));      

        $ok = 1;
        last;

      } else {
        die("Mismatched ExtendedLog line '$line'");
      }
    }

    close($fh);

    unless ($ok) {
      die("Unexpected environment variable values in ExtendedLog");
    }

  } else {
    die("Can't read $ext_log: $!");
  }

  unlink($log_file);
}

sub tls_opts_std_env_vars_client_vars {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert.pem');
  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "TLS_CLIENT_S_DN=\'%{TLS_CLIENT_S_DN}e\' TLS_CLIENT_I_DN=\'%{TLS_CLIENT_I_DN}e\'"',
    ExtendedLog => "$ext_log AUTH custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => 'StdEnvVars',
        TLSVerifyClient => 'optional',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      # IO::Socket::SSL options
      my $ssl_opts = {
        SSL_use_cert => 1,
        SSL_cert_file => $client_cert,
        SSL_key_file => $client_cert,
        SSL_ca_file => $ca_file,
      };

      my $client = Net::FTPSSL->new('127.0.0.1',
        Croak => 1,
        Encryption => 'E',
        Port => $port,
        SSL_Client_Certificate => $ssl_opts,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
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

  # Stop server
  server_stop($pid_file);

  $self->assert_child_ok($pid);

  if ($ex) {
    die($ex);
  }

  # Open the ExtendedLog, and check for the expected environment variables
  if (open(my $fh, "< $ext_log")) {
    my $ok = 0;

    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /TLS_CLIENT_S_DN='(.*?)' TLS_CLIENT_I_DN='(.*?)'/) {
        my $subj_dn = $1;
        my $issuer_dn = $2;

        $self->assert(length($subj_dn) > 0,
          test_msg("Expected subject DN, got '$subj_dn'"));      
        $self->assert(length($issuer_dn) > 0,
          test_msg("Expected issuer DN, got '$issuer_dn'"));      

        $ok = 1;
        last;

      } else {
        die("Mismatched ExtendedLog line '$line'");
      }
    }

    close($fh);

    unless ($ok) {
      die("Unexpected environment variable values in ExtendedLog");
    }

  } else {
    die("Can't read $ext_log: $!");
  }

  unlink($log_file);
}

sub tls_opts_ipaddr_required_ipv4 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert.pem');
  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => 'iPAddressRequired',
        TLSVerifyClient => 'on',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      # IO::Socket::SSL options
      my $ssl_opts = {
        SSL_use_cert => 1,
        SSL_cert_file => $client_cert,
        SSL_key_file => $client_cert,
        SSL_ca_file => $ca_file,
      };

      my $client;
      eval {
        $client = Net::FTPSSL->new('127.0.0.1',
          Croak => 1,
          Encryption => 'E',
          Port => $port,
        );
      };

      unless ($@) { 
        die("Connection to server succeeded unexpectedly");
      }

      $client = Net::FTPSSL->new('127.0.0.1',
        Croak => 1,
        Encryption => 'E',
        Port => $port,
        SSL_Client_Certificate => $ssl_opts,
      );

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
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

sub tls_opts_ipaddr_required_ipv6 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/ipv6-client-cert2.pem');
  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ipv6-server-cert2.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ipv6-ca.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => 'iPAddressRequired',
        TLSVerifyClient => 'on',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      # IO::Socket::SSL options
      my $ssl_opts = {
        SSL_use_cert => 1,
        SSL_cert_file => $client_cert,
        SSL_key_file => $client_cert,
        SSL_ca_file => $ca_file,
      };

      my $client;
      eval {
        $client = Net::FTPSSL->new('127.0.0.1',
          Croak => 1,
          Encryption => 'E',
          Port => $port,
        );
      };

      unless ($@) { 
        die("Connection to server succeeded unexpectedly");
      }

      $client = Net::FTPSSL->new('127.0.0.1',
        Croak => 1,
        Encryption => 'E',
        Port => $port,
        SSL_Client_Certificate => $ssl_opts,
      );

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
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

  # Stop server
  server_stop($pid_file);

  $self->assert_child_ok($pid);

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

#  unlink($log_file);
}

sub tls_opts_allow_per_user_tlsrequired_on_anon_login_bug3325 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert.pem');
  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => 'AllowPerUser',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  my ($anon_user, $anon_group) = config_get_identity();

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Anonymous $home_dir>
  User $anon_user
  Group $anon_group
  UserAlias anonymous $anon_user
  RequireValidShell off
  TLSRequired off
</Anonymous>
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      # We should be able to connect to the server without SSL, and login
      # anonymously without it.
      my ($resp_code, $resp_msg) = $client->login('anonymous', 'ftp@nospam.org');

      my $expected;

      $expected = 230;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 'Anonymous access granted, restrictions apply';
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

sub tls_opts_allow_per_user_tlsrequired_on_user_login_bug3325 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert.pem');
  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => 'AllowPerUser',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  my ($anon_user, $anon_group) = config_get_identity();

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Anonymous $home_dir>
  User $anon_user
  Group $anon_group
  UserAlias anonymous $anon_user
  RequireValidShell off
  TLSRequired off
</Anonymous>
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      # With this config, we should not be able to login without SSL/TLS
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

      $expected = "Login incorrect.";
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

sub tls_opts_allow_per_user_tlsrequired_auth_user_login_bug3325 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert.pem');
  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'auth',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => 'AllowPerUser',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  my ($anon_user, $anon_group) = config_get_identity();

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Anonymous $home_dir>
  User $anon_user
  Group $anon_group
  UserAlias anonymous $anon_user
  RequireValidShell off
  TLSRequired off
</Anonymous>
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      # With this config, we should not be able to login without SSL/TLS
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

      $expected = "Login incorrect.";
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

sub tls_opts_allow_per_user_tlsrequired_ctrl_user_login_bug3325 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert.pem');
  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'ctrl',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => 'AllowPerUser',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  my ($anon_user, $anon_group) = config_get_identity();

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Anonymous $home_dir>
  User $anon_user
  Group $anon_group
  UserAlias anonymous $anon_user
  RequireValidShell off
  TLSRequired off
</Anonymous>
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      # With this config, we should not be able to login without SSL/TLS
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

      $expected = "Login incorrect.";
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

sub tls_opts_allow_per_user_tlsrequired_data_user_login_bug3325 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert.pem');
  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'data',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => 'AllowPerUser',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  my ($anon_user, $anon_group) = config_get_identity();

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Anonymous $home_dir>
  User $anon_user
  Group $anon_group
  UserAlias anonymous $anon_user
  RequireValidShell off
  TLSRequired off
</Anonymous>
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      # With this config, we should not be able to login without SSL/TLS
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      my ($resp_code, $resp_msg) = $client->login($user, $passwd);

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

sub tls_opts_allow_per_user_tlsrequired_on_ifsess_login_bug3325 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert.pem');
  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => 'AllowPerUser',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  my ($anon_user, $anon_group) = config_get_identity();

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<IfModule mod_ifsession.c>
  <IfUser $user>
    TLSRequired off
  </IfUser>
</IfModule>
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);

      my ($resp_code, $resp_msg) = $client->login($user, $passwd);
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

sub tls_rest_2gb_last_byte {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert.pem');
  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  # According to:
  #
  #  http://trac.filezilla-project.org/ticket/4487
  #
  # FileZilla tests whether servers support resuming transfers over 2GB by
  # (IMHO stupidly) seeking to just before the last byte of the file on the
  # server, and expecting just a single byte.
  #
  # Make sure that proftpd does The Right Thing(tm) in a regression test for
  # this use case.

  # Create a file that is 2GB plus 24 bytes.
  my $test_len = (2 ** 31) + 24;
  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {

    # Seek to the 2GB limit, then fill the rest with 'A'
    unless (seek($fh, (2 ** 31), 0)) {
       die("Can't seek to 2GB length: $!");
    }

    print $fh "A" x 24;

    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $tmp_file = File::Spec->rel2abs("$tmpdir/test.tmp");
  my $tmp_fh;
  unless (open($tmp_fh, "> $tmp_file")) {
    die("Can't open $tmp_file: $!");
  }
 
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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => 'NoSessionReuseRequired',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      unless ($client->binary()) {
        die("Can't set TYPE to binary: " . $client->last_message());
      }

      my $rest_len = $test_len - 1;

      my $res;
      if ($Net::FTPSSL::VERSION == 0.21) {
        # Note: The duplicated arguments here are to work around a bug in
        # Net::FTPSSL, version 0.21, in the quot() function.
        $res = $client->quot('REST', $rest_len, $rest_len);

      } else {
        $res = $client->quot('REST', $rest_len);
      }

      unless ($res) {
        die("Can't REST $rest_len: " . $client->last_message());
      }

      my $resp_msg = $client->last_message();
      my $expected;

      $expected = "350 Restarting at $rest_len. Send STORE or RETRIEVE to initiate transfer";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      unless ($client->get($test_file, $tmp_fh)) {
        die("Can't RETR $test_file: " . $client->last_message());
      }

      $resp_msg = $client->last_message();
      $expected = "226 Transfer complete";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      close($tmp_fh);

      my $buflen = (stat($tmp_file))[7];
      $expected = 1;
      $self->assert($expected == $buflen,
        test_msg("Expected $expected, got $buflen"));
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

sub tls_rest_4gb_last_byte {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert.pem');
  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  # According to:
  #
  #  http://trac.filezilla-project.org/ticket/4487
  #
  # FileZilla tests whether servers support resuming transfers over 4GB by
  # (IMHO stupidly) seeking to just before the last byte of the file on the
  # server, and expecting just a single byte.
  #
  # Make sure that proftpd does The Right Thing(tm) in a regression test for
  # this use case.

  # Create a file that is 4GB plus 24 bytes.
  my $test_len = (2 ** 32) + 24;
  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {

    # Seek to the 4GB limit, then fill the rest with 'A'
    unless (seek($fh, (2 ** 32), 0)) {
       die("Can't seek to 4GB length: $!");
    }

    print $fh "A" x 24;

    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $tmp_file = File::Spec->rel2abs("$tmpdir/test.tmp");
  my $tmp_fh;
  unless (open($tmp_fh, "> $tmp_file")) {
    die("Can't open $tmp_file: $!");
  }
 
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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => 'NoSessionReuseRequired',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      unless ($client->binary()) {
        die("Can't set TYPE to binary: " . $client->last_message());
      }

      my $rest_len = $test_len - 1;

      my $res;
      if ($Net::FTPSSL::VERSION == 0.21) {
        # Note: The duplicated arguments here are to work around a bug in
        # Net::FTPSSL, version 0.21, in the quot() function.
        $res = $client->quot('REST', $rest_len, $rest_len);

      } else {
        $res = $client->quot('REST', $rest_len);
      }

      unless ($res) {
        die("Can't REST $rest_len: " . $client->last_message());
      }

      my $resp_msg = $client->last_message();
      my $expected;

      $expected = "350 Restarting at $rest_len. Send STORE or RETRIEVE to initiate transfer";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      unless ($client->get($test_file, $tmp_fh)) {
        die("Can't RETR $test_file: " . $client->last_message());
      }

      $resp_msg = $client->last_message();
      $expected = "226 Transfer complete";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected '$expected', got '$resp_msg'"));

      close($tmp_fh);

      my $buflen = (stat($tmp_file))[7];
      $expected = 1;
      $self->assert($expected == $buflen,
        test_msg("Expected $expected, got $buflen"));
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

sub tls_stor_empty_file {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'netio:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => 'EnableDiags NoSessionReuseRequired',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  my $empty_file = File::Spec->rel2abs("$tmpdir/empty.txt");
  if (open(my $fh, "> $empty_file")) {
    close($fh);

  } else {
    die("Can't open $empty_file: $!");
  }

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");

  # Open pipes, for use between the parent and child processes.  Specifically,
  # the child will indicate when it's done with its test by writing a message
  # to the parent.
  my ($rfh, $wfh);
  unless (pipe($rfh, $wfh)) {
    die("Can't open pipe: $!");
  }

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      unless ($client->binary()) {
        die("Can't set transfer mode to binary: " . $client->last_message());
      }

      unless ($client->put($empty_file, 'test.txt')) {
        die("Can't upload '$empty_file' to 'test.txt': " .
          $client->last_message());
      }

      $client->quit();

      unless (-f $test_file) {
        die("File $test_file does not exist as expected");
      }

      unless (-z $test_file) {
        die("File $test_file is not empty as expected");
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

sub tls_retr_empty_file {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => 'NoSessionReuseRequired',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  my $empty_file = File::Spec->rel2abs("$tmpdir/empty.txt");
  if (open(my $fh, "> $empty_file")) {
    close($fh);

  } else {
    die("Can't open $empty_file: $!");
  }

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");

  # Open pipes, for use between the parent and child processes.  Specifically,
  # the child will indicate when it's done with its test by writing a message
  # to the parent.
  my ($rfh, $wfh);
  unless (pipe($rfh, $wfh)) {
    die("Can't open pipe: $!");
  }

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      unless ($client->binary()) {
        die("Can't set transfer mode to binary: " . $client->last_message());
      }

      unless ($client->get($empty_file, $test_file)) {
        die("Can't download '$empty_file' to '$test_file': " .
          $client->last_message());
      }

      $client->quit();

      unless (-f $test_file) {
        die("File $test_file does not exist as expected");
      }

      unless (-z $test_file) {
        die("File $test_file is not empty as expected");
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

sub tls_required_on_feat_allowed_bug3420 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      # We use a non-FTPS client here, to make sure that we can at least
      # get the FEAT data, as per Bug#3420.

      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->feat();

      my $resp_msgs = $client->response_msgs();
      my $count = scalar(@$resp_msgs);
      $self->assert($count > 0,
        test_msg("Expected > 0, got $count"));
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

sub tls_implicit_ssl_bug3437 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $config = {

    # The stupid Net::FTPSSL client requires port 990 when implicit
    # FTPS is used, regardless of the port we pass to the constructor.
    # (What kind of client API does not allow the port to be changed??)
    Port => 990,

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'off',
        TLSOptions => 'UseImplicitSSL',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client_opts = {
        Encryption => 'I',
        Port => $port,
      };

      if ($ENV{TEST_VERBOSE}) {
        $client_opts->{Debug} = 1;
      }

      my $client = Net::FTPSSL->new('127.0.0.1', %$client_opts);

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      unless ($client->ccc('P')) {
        die("CCC failed: " . $client->last_message());
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

sub tls_ccc_list_bug3465 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'off',
        TLSOptions => 'NoSessionReuseRequired',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client_opts = {
        Encryption => 'E',
        Port => $port,
      };

      if ($ENV{TEST_VERBOSE}) {
        $client_opts->{Debug} = 1;
      }

      my $client = Net::FTPSSL->new('127.0.0.1', %$client_opts);

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      unless ($client->ccc()) {
        die("CCC failed: " . $client->last_message());
      }

      my $res = $client->list('.');
      unless ($res) {
        die("LIST failed: " . $client->message());
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

sub tls_ccc_before_login {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'tls');

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'DEFAULT:10 tls:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $setup->{log_file},
        TLSProtocol => 'TLSv1',
        TLSRequired => 'off',
        TLSOptions => 'NoSessionReuseRequired',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client_opts = {
        PeerHost => '127.0.0.1',
        PeerPort => $port,
        Proto => 'tcp',
        Type => SOCK_STREAM,
        Timeout => 10
      };

      my $ssl_opts = {
        SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE(),
      };

      my $client = IO::Socket::INET->new(%$client_opts);
      unless ($client) {
        die("Can't connect to 127.0.0.1:$port: $!");
      }

      # Read the banner
      my $banner = <$client>;
      if ($ENV{TEST_VERBOSE}) {
        print STDOUT "# Received banner: $banner";
      }

      # Send the AUTH command
      my $cmd = "AUTH TLS\r\n";
      if ($ENV{TEST_VERBOSE}) {
        print STDOUT "# Sending command: $cmd";
      }
      $client->print($cmd);
      $client->flush();

      # Read the AUTH response
      my $resp = <$client>;
      if ($ENV{TEST_VERBOSE}) {
        print STDOUT "# Received response: $resp";
      }

      my $expected = "234 AUTH TLS successful\r\n";
      unless ($expected eq $resp) {
        die("Expected response '$expected', got '$resp'");
      }

      if ($ENV{TEST_VERBOSE}) {
        $IO::Socket::SSL::DEBUG = 3;
      }

      my $res = IO::Socket::SSL->start_SSL($client, $ssl_opts);
      unless ($res) {
        croak("Failed SSL handshake: " . IO::Socket::SSL::errstr());
      }

      $cmd = "CCC\r\n";
      if ($ENV{TEST_VERBOSE}) {
        print STDOUT "# Sending command: $cmd";
      }
      $client->print($cmd);
      $client->flush();

      $resp = <$client>;
      if ($ENV{TEST_VERBOSE}) {
        print STDOUT "# Received response: $resp";
      }

      $expected = "530 Please login with USER and PASS\r\n";
      unless ($expected eq $resp) {
        die("Expected response '$expected', got '$resp'");
      }

      $res = $client->stop_SSL();
      unless ($res) {
        croak("Failed SSL shutdown: " . IO::Socket::SSL::errstr());
      }

      $cmd = "QUIT\r\n";
      if ($ENV{TEST_VERBOSE}) {
        print STDOUT "# Sending command: $cmd";
      }
      $client->print($cmd);
      $client->flush();

      $resp = <$client>;
      if ($ENV{TEST_VERBOSE}) {
        print STDOUT "# Received response: $resp";
      }

      if ($resp) {
        die("Received response unexpectedly");
      }

      $client->close();
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

sub tls_opts_commonname_required_bug3512 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $bad_client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert.pem');
  my $good_client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert-localhost.pem');

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => 'CommonNameRequired',
        TLSVerifyClient => 'on',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      # IO::Socket::SSL options
      my $ssl_opts = {
        SSL_use_cert => 1,
        SSL_cert_file => $bad_client_cert,
        SSL_key_file => $bad_client_cert,
        SSL_ca_file => $ca_file,
      };

      my $client;
      eval {
        $client = Net::FTPSSL->new('127.0.0.1',
          Croak => 1,
          Encryption => 'E',
          Port => $port,
          SSL_Client_Certificate => $ssl_opts,
        );
      };

      unless ($@) { 
        eval { $client->login($user, $passwd) };
        unless ($@) {
          die("Login succeeded unexpectedly");
        }
      }

      $ssl_opts->{SSL_cert_file} = $good_client_cert;
      $ssl_opts->{SSL_key_file} = $good_client_cert;

      $client = Net::FTPSSL->new('127.0.0.1',
        Croak => 1,
        Encryption => 'E',
        Port => $port,
        SSL_Client_Certificate => $ssl_opts,
      );

      sleep(1);

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      $client->quit();
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, 30) };
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

sub tls_opts_dns_name_required {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $bad_client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert.pem');
  my $good_client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert-localhost.pem');

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => 'dNSNameRequired',
        TLSVerifyClient => 'on',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      # IO::Socket::SSL options
      my $ssl_opts = {
        SSL_use_cert => 1,
        SSL_cert_file => $bad_client_cert,
        SSL_key_file => $bad_client_cert,
        SSL_ca_file => $ca_file,
      };

      my $client;
      eval {
        $client = Net::FTPSSL->new('127.0.0.1',
          Croak => 1,
          Encryption => 'E',
          Port => $port,
          SSL_Client_Certificate => $ssl_opts,
        );
      };

      unless ($@) { 
        eval { $client->login($user, $passwd) };
        unless ($@) {
          die("Login succeeded unexpectedly");
        }
      }

      $ssl_opts->{SSL_cert_file} = $good_client_cert;
      $ssl_opts->{SSL_key_file} = $good_client_cert;

      $client = Net::FTPSSL->new('127.0.0.1',
        Croak => 1,
        Encryption => 'E',
        Port => $port,
        SSL_Client_Certificate => $ssl_opts,
      );

      sleep(1);

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      $client->quit();
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, 30) };
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

sub tls_opts_ip_addr_dns_name_cn_required {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $bad_client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert.pem');
  my $good_client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert-localhost.pem');

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => 'iPAddressRequired dNSNameRequired CommonNameRequired',
        TLSVerifyClient => 'on',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      # IO::Socket::SSL options
      my $ssl_opts = {
        SSL_use_cert => 1,
        SSL_cert_file => $bad_client_cert,
        SSL_key_file => $bad_client_cert,
        SSL_ca_file => $ca_file,
      };

      my $client;
      eval {
        $client = Net::FTPSSL->new('127.0.0.1',
          Croak => 1,
          Encryption => 'E',
          Port => $port,
          SSL_Client_Certificate => $ssl_opts,
        );
      };

      unless ($@) { 
        eval { $client->login($user, $passwd) };
        unless ($@) {
          die("Login succeeded unexpectedly");
        }
      }

      $ssl_opts->{SSL_cert_file} = $good_client_cert;
      $ssl_opts->{SSL_key_file} = $good_client_cert;

      $client = Net::FTPSSL->new('127.0.0.1',
        Croak => 1,
        Encryption => 'E',
        Port => $port,
        SSL_Client_Certificate => $ssl_opts,
      );

      sleep(1);

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      $client->quit();
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, 30) };
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

sub tls_site_chmod_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    close($fh);

  } else {
    die("Can't open $test_file: $!");
  }

  # Make sure that, if we're running as root, that the home directory has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chmod(0755, $home_dir)) {
      die("Can't set perms on $home_dir to 0755: $!");
    }

    unless (chown($uid, $gid, $home_dir, $test_file)) {
      die("Can't set owner of $home_dir to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      unless ($client->site("CHMOD 777 test.txt")) {
        die("SITE CHMOD failed: " . $client->last_message());
      } 

      my $resp = $client->last_message();

      my $expected;

      $expected = '200 SITE CHMOD command successful';
      $self->assert($expected eq $resp,
        test_msg("Expected '$expected', got '$resp'"));

      $client->quit();

      my $perms = ((stat($test_file))[2] &07777);

      $expected = 0777;
      $self->assert($expected == $perms,
        test_msg("Expected '$expected', got '$perms'"));
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

sub tls_default_tlsrequired {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      # Login first with FTPS...
      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      $client->quit();

      # Now log in using plain FTP
      $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
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

sub tls_protocols_default {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      unless ($client->noop()) {
        die("NOOP failed: " . $client->last_message());
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

sub tls_protocols_with_ftps {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    Protocols => 'ftps',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      unless ($client->noop()) {
        die("NOOP failed: " . $client->last_message());
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

sub tls_protocols_without_ftps {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    Protocols => 'ftp',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      if ($client->login($user, $passwd)) {
        die("Login succeeded unexpectedly");
      }

      my $resp_msg = $client->last_message();

      my $expected = '530 Login incorrect.';
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

sub tls_ifsess_protocols_with_ftps {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;

<IfModule mod_ifsession.c>
  <IfUser foo>
    Protocols bar baz
  </IfUser>

  <IfUser $user>
    Protocols ftps
  </IfUser>
</IfModule>
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      unless ($client->noop()) {
        die("NOOP failed: " . $client->last_message());
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

sub tls_ifsess_protocols_without_ftps {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;

<IfModule mod_ifsession.c>
  <IfUser foo>
    Protocols ftps
  </IfUser>

  <IfUser $user>
    Protocols foo bar
  </IfUser>
</IfModule>
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      if ($client->login($user, $passwd)) {
        die("Login succeeded unexpectedly");
      }

      my $resp_msg = $client->last_message();

      my $expected = '530 Login incorrect.';
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

sub tls_sess_cache_internal_bug3580 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,

        TLSSessionCache => 'internal: 1800'
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
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

sub tls_passphraseprovider {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert-passwd.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');
  my $passphrase_provider = File::Spec->rel2abs('t/etc/modules/mod_tls/tls-get-passphrase.pl');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:20 tls:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,

        TLSPassPhraseProvider => $passphrase_provider,
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(5);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
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

sub tls_verify_order_crl_bug3658 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $server_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/crl-server-cert.pem');
  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/crl-client-cert.pem');
  my $ca_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/crl-ca.pem');
  my $crl_file = File::Spec->rel2abs('t/etc/modules/mod_tls/crl-ca-revoked.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $server_cert,
        TLSCACertificateFile => $ca_cert,

        # Verifying clients via CRLs only works when verification is
        # explicitly enabled.
        TLSCARevocationFile => $crl_file,
        TLSVerifyClient => 'on',
        TLSVerifyOrder => 'crl',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client;

      eval {
        # IO::Socket::SSL options
        my $ssl_opts = {
          SSL_use_cert => 1,
          SSL_cert_file => $client_cert,
          SSL_key_file => $client_cert,
          SSL_ca_file => $ca_cert,
        };

        $client = Net::FTPSSL->new('127.0.0.1',
          Croak => 1,
          Encryption => 'E',
          Port => $port,
          SSL_Client_Certificate => $ssl_opts,
        );
      };

      my $ex = $@;
      unless ($ex) {
        die("SSL connection succeeded unexpectedly");
      }

      my $errstr = IO::Socket::SSL::errstr();

      my $expected = 'certificate revoked';
      $self->assert(qr/$expected/, $errstr,
        test_msg("Expected '$expected', got '$errstr'"));
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

sub tls_verify_order_ocsp {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $server_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/ocsp-server.pem');
  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/ocsp-client.pem');
  my $ca_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/ocsp-ca.pem');

  # XXX NOTE: Make sure the OCSP responder is running, at URL:
  #
  #  http://localhost:7777
  #
  # since that is the OCSP URI baked into the OCSP client cert.
  #
  # To do this, go to the cert-tool/ directory, and run:
  #
  #  openssl ocsp -index etc/cert-tool.index -CA ocsp-ca.pem \
  #    -rsigner ocsp-ca.pem -url http://localhost:7777

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $server_cert,
        TLSCACertificateFile => $ca_cert,

        TLSOptions => 'EnableDiags',

        # Verifying clients via OCSP only works when verification is
        # explicitly enabled.
        TLSVerifyClient => 'on',

        TLSVerifyOrder => 'ocsp',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client;

      eval {
        # IO::Socket::SSL options
        my $ssl_opts = {
          SSL_use_cert => 1,
          SSL_cert_file => $client_cert,
          SSL_key_file => $client_cert,
          SSL_ca_file => $ca_cert,
        };

        $client = Net::FTPSSL->new('127.0.0.1',
          Croak => 1,
          Encryption => 'E',
          Port => $port,
          SSL_Client_Certificate => $ssl_opts,
        );
      };

      my $ex = $@;
      unless ($ex) {
        die("SSL connection succeeded unexpectedly");
      }

      my $errstr = IO::Socket::SSL::errstr();

      # In this case, since the CA which is needed to verify the OCSP
      # response has been revoked, the OCSP response can't be verified,
      # which results in a handshake failure.
      my $expected = 'handshake failure';
      $self->assert(qr/$expected/, $errstr,
        test_msg("Expected '$expected', got '$errstr'"));
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

sub tls_verify_order_ocsp_https {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $server_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/ocsp-https-server.pem');
  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/ocsp-https-client.pem');
  my $ca_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/ocsp-https-ca.pem');

  # XXX NOTE: Make sure the OCSP responder is running, at URL:
  #
  #  https://localhost:7777
  #
  # since that is the OCSP URI baked into the OCSP client cert.
  #
  # To do this, go to the cert-tool/ directory, and run:
  #
  #  openssl ocsp -index etc/cert-tool.index -CA ocsp-https-ca.pem \
  #    -rsigner ocsp-https-ca.pem -url https://localhost:7777

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $server_cert,
        TLSCACertificateFile => $ca_cert,

        TLSOptions => 'EnableDiags',

        # Verifying clients via OCSP only works when verification is
        # explicitly enabled.
        TLSVerifyClient => 'on',

        TLSVerifyOrder => 'ocsp',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client;

      eval {
        # IO::Socket::SSL options
        my $ssl_opts = {
          SSL_use_cert => 1,
          SSL_cert_file => $client_cert,
          SSL_key_file => $client_cert,
          SSL_ca_file => $ca_cert,
        };

        $client = Net::FTPSSL->new('127.0.0.1',
          Croak => 1,
          Encryption => 'E',
          Port => $port,
          SSL_Client_Certificate => $ssl_opts,
        );
      };

      my $ex = $@;
      unless ($ex) {
        die("SSL connection succeeded unexpectedly");
      }

      my $errstr = IO::Socket::SSL::errstr();

      # In this case, since the CA which is needed to verify the OCSP
      # response has been revoked, the OCSP response can't be verified,
      # which results in a handshake failure.
      my $expected = 'handshake failure';
      $self->assert(qr/$expected/, $errstr,
        test_msg("Expected '$expected', got '$errstr'"));
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

sub tls_client_cert_verify_failed_selfsigned_cert_only_bug3742 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $server_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  # Deliberately use the bug3742-ca.pem, which is self-signed CA cert, as the
  # client cert.  And we deliberately use a different self-signed CA than
  # the one in ca-cert.pem, since that ca-cert.pem is also used by the
  # server.
  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/bug3742-ca.pem');
  my $client_key = File::Spec->rel2abs('t/etc/modules/mod_tls/bug3742-ca.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $server_cert,
        TLSCACertificateFile => $ca_cert,
        TLSVerifyClient => 'on',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client;

      eval {
        # IO::Socket::SSL options
        my $ssl_opts = {
          SSL_use_cert => 1,
          SSL_cert_file => $client_cert,
          SSL_key_file => $client_key,
          SSL_ca_file => $ca_cert,
        };

        eval {
          $client = Net::FTPSSL->new('127.0.0.1',
            Croak => 1,
            Encryption => 'E',
            Port => $port,
            SSL_Client_Certificate => $ssl_opts,
          );
        };

        # This should die of an exception like:
        #
        #  error:14094418:SSL routines:SSL3_READ_BYTES:tlsv1 alert unknown ca

        unless ($@) { 
          die("Successfully connected to FTPS server unexpectedly");
        }

      };

      if ($@) {
        die($@);
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

sub tls_client_cert_verify_failed_selfsigned_cert_in_chain_bug3742 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $server_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  # To get the client to send a list of certs (including a self-signed CA)
  # to the server, we use a cert file which contains a list of certs
  # (including the client cert).  Easy.

  my $client_cert = File::Spec->rel2abs("$tmpdir/client-cert-chain.pem");
  if (open(my $outfh, "> $client_cert")) {
    # First the client cert
    my $cert = File::Spec->rel2abs('t/etc/modules/mod_tls/bug3742-client.pem');

    if (open(my $infh, "< $cert")) {
      # Slurp in all of the data at once.  Just easier that way.
      local $/;

      my $data = <$infh>;
      close($infh);

      print $outfh $data;

    } else {
      die("Can't read $cert: $!");
    }

    # Next the client CA
    $cert = File::Spec->rel2abs('t/etc/modules/mod_tls/bug3742-ca.pem');

    if (open(my $infh, "< $cert")) {
      # Slurp in all of the data at once.  Just easier that way.
      local $/;

      my $data = <$infh>;
      close($infh);

      print $outfh $data;
    
    } else {
      die("Can't read $cert: $!");
    }

    unless (close($outfh)) {
      die("Can't write $client_cert: $!");
    }

  } else {
    die("Can't open $client_cert: $!");
  }

  my $client_key = File::Spec->rel2abs('t/etc/modules/mod_tls/bug3742-client.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $server_cert,
        TLSCACertificateFile => $ca_cert,
        TLSVerifyClient => 'on',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client;

      eval {
        # IO::Socket::SSL options
        my $ssl_opts = {
          SSL_use_cert => 1,
          SSL_cert_file => $client_cert,
          SSL_key_file => $client_key,
        };

        eval {
          $client = Net::FTPSSL->new('127.0.0.1',
            Croak => 1,
            Encryption => 'E',
            Port => $port,
            SSL_Client_Certificate => $ssl_opts,
          );
        };

        # This should die of an exception like:
        #
        #  error:14094418:SSL routines:SSL3_READ_BYTES:tlsv1 alert unknown ca

        unless ($@) { 
          die("Successfully connected to FTPS server unexpectedly");
        }

      };

      if ($@) {
        die($@);
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

sub tls_client_cert_verify_ok_server_selfsigned_cert_in_chain_bug3742 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $server_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  # To get the client to send a list of certs (including a self-signed CA)
  # to the server, we use a cert file which contains a list of certs
  # (including the client cert).  Easy.

  my $client_cert = File::Spec->rel2abs("$tmpdir/client-cert-chain.pem");
  if (open(my $outfh, "> $client_cert")) {
    # First the client cert
    my $cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert.pem');

    if (open(my $infh, "< $cert")) {
      # Slurp in all of the data at once.  Just easier that way.
      local $/;

      my $data = <$infh>;
      close($infh);

      print $outfh $data;

    } else {
      die("Can't read $cert: $!");
    }

    # Next the client CA.  This time, use the same CA that the server is
    # using (and trusting).
    $cert = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

    if (open(my $infh, "< $cert")) {
      # Slurp in all of the data at once.  Just easier that way.
      local $/;

      my $data = <$infh>;
      close($infh);

      print $outfh $data;
    
    } else {
      die("Can't read $cert: $!");
    }

    unless (close($outfh)) {
      die("Can't write $client_cert: $!");
    }

  } else {
    die("Can't open $client_cert: $!");
  }

  my $client_key = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $server_cert,
        TLSCACertificateFile => $ca_cert,
        TLSVerifyClient => 'on',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client;

      eval {
        # IO::Socket::SSL options
        my $ssl_opts = {
          SSL_use_cert => 1,
          SSL_cert_file => $client_cert,
          SSL_key_file => $client_key,
        };

        $client = Net::FTPSSL->new('127.0.0.1',
          Croak => 1,
          Encryption => 'E',
          Port => $port,
          SSL_Client_Certificate => $ssl_opts,
        );

        # If no exception was thrown at this point, we have succeeded.
      };

      if ($@) {
        die($@);
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

sub tls_opts_allow_dot_login {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $server_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert.pem');
  my $ca_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $tlslogin_file = File::Spec->rel2abs("$tmpdir/.tlslogin");
  unless (copy($client_cert, $tlslogin_file)) {
    die("Can't copy $client_cert to $tlslogin_file: $!");
  }

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $server_cert,
        TLSCACertificateFile => $ca_cert,
        TLSVerifyClient => 'optional',
        TLSOptions => 'AllowDotLogin',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      # IO::Socket::SSL options
      my $ssl_opts = {
        SSL_use_cert => 1,
        SSL_cert_file => $client_cert,
        SSL_key_file => $client_cert,
        SSL_ca_file => $ca_cert,
      };

      my $client = Net::FTPSSL->new('127.0.0.1',
        Croak => 1,
        Encryption => 'E',
        Port => $port,
        SSL_Client_Certificate => $ssl_opts,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->_user($user)) {
        die("USER error: " . $client->last_message());
      }

      my $expected = "232 User $user logged in";
      my $resp = $client->last_message();
      $self->assert($expected eq $resp,
        test_msg("Expected response '$expected', got '$resp'"));

      if ($client->_passwd()) {
        die("PASS succeeded unexpectedly");
      }

      my $expected = "503 You are already logged in";
      my $resp = $client->last_message();
      $self->assert($expected eq $resp,
        test_msg("Expected response '$expected', got '$resp'"));
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

sub tls_opts_multiple_lines_bug3800 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => [
        "TLSEngine on",
        "TLSLog $log_file",
        "TLSProtocol SSLv3 TLSv1",
        "TLSRequired on",
        "TLSRSACertificateFile $cert_file",
        "TLSCACertificateFile $ca_file",

        "TLSOptions StdEnvVars",
        "TLSOptions NoSessionReuseRequired",
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
        Croak => 1,
      );

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      # Since we are NOT requiring SSL session reuse for data transfers,
      # and this client is not using SSL session resumption, I expect
      # this data transfer to succeed.
      my $res = $client->list('.');
      unless ($res) {
        die("LIST failed unexpectedly: " . $client->message());
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

sub tls_config_tlsmasqueradeaddress_bug3862 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $masq_addr = '1.2.3.4';

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

      'mod_tls.c' => [
        "TLSEngine on",
        "TLSLog $log_file",
        "TLSProtocol SSLv3 TLSv1",
        "TLSRequired on",
        "TLSRSACertificateFile $cert_file",
        "TLSCACertificateFile $ca_file",

        "TLSMasqueradeAddress $masq_addr",
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
        Croak => 1,
      );

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      unless ($client->quot('PASV')) {
        die("Can't use PASV: " . $client->last_message());
      }

      my $resp = $client->last_message();

      if ($resp =~ /^227 Entering Passive Mode \((.*)?,\d+,\d+\)/) {
        my $resp_addr = $1;

        my $expected = $masq_addr;
        $expected =~ s/\./,/g;

        $self->assert($expected eq $resp_addr,
          test_msg("Expected PASV address '$expected', got '$resp_addr'"));

      } else {
        die("PASV response '$resp' did not match expected pattern");
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

sub tls_config_tlsdhparamfile_bug3868 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');
  my $dhparam_file = File::Spec->rel2abs('t/etc/modules/mod_tls/dh1024.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSDHParamFile => $dhparam_file,
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $ssl_opts = {
        # Results in set_tmp_dh_callback() keylength of 1024 BITS
        SSL_cipher_list => 'DHE-RSA-AES256-SHA',
        SSL_ca_file => $ca_file,
      };

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
        SSL_Client_Certificate => $ssl_opts,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
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

sub tls_config_tlsciphersuite_bad_cipher {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'tls');

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $setup->{log_file},
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSCipherSuite => 'FOOBAR',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($setup->{config_file},
    $config);

  my $ex;

  # This should silently fail.
  server_start($setup->{config_file});

  # This is where we detect the actual problem.
  eval { server_stop($setup->{pid_file}) };
  unless ($@) {
    $ex = "Server start with bad config unexpectedly";
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub tls_config_tlscacertfile_bad_format {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'tls');

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');

  my $ca_file = File::Spec->rel2abs("$tmpdir/bad-ca.pem");
  if (open(my $fh, "> $ca_file")) {
    print $fh "foobar\n";
    unless (close($fh)) {
      die("Can't write $ca_file: $!");
    }

  } else {
    die("Can't open $ca_file: $!");
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $setup->{log_file},
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($setup->{config_file},
    $config);

  my $ex;

  # This should silently fail.
  server_start($setup->{config_file});

  # This is where we detect the actual problem.
  eval { server_stop($setup->{pid_file}) };
  unless ($@) {
    $ex = "Server start with bad config unexpectedly";
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub tls_config_tlscarevocationfile_bad_format {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'tls');

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $crl_file = File::Spec->rel2abs("$tmpdir/bad-crl.pem");
  if (open(my $fh, "> $crl_file")) {
    print $fh "foobar\n";
    unless (close($fh)) {
      die("Can't write $crl_file: $!");
    }

  } else {
    die("Can't open $crl_file: $!");
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $setup->{log_file},
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSCARevocationFile => $crl_file,
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($setup->{config_file},
    $config);

  my $ex;

  # This should silently fail.
  server_start($setup->{config_file});

  # This is where we detect the actual problem.
  eval { server_stop($setup->{pid_file}) };
  unless ($@) {
    $ex = "Server start with bad config unexpectedly";
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub tls_config_tlscertchainfile_bad_format {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'tls');

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');

  my $cert_chain_file = File::Spec->rel2abs("$tmpdir/cert-chain.pem");
  if (open(my $fh, "> $cert_chain_file")) {
    print $fh "FooBar\n";
    unless (close($fh)) {
      die("Can't write $cert_chain_file: $!");
    }

  } else {
    die("Can't open $cert_chain_file: $!");
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $setup->{log_file},
        TLSRSACertificateFile => $cert_file,
        TLSCertificateChainFile => $cert_chain_file,
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($setup->{config_file},
    $config);

  my $ex;

  # This should silently fail.
  server_start($setup->{config_file});

  # This is where we detect the actual problem.
  eval { server_stop($setup->{pid_file}) };
  unless ($@) {
    $ex = "Server start with bad config unexpectedly";
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub tls_config_tlsdsacertfile_bad_format {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'tls');

  my $cert_file = File::Spec->rel2abs("$tmpdir/bad-dsa.pem");
  if (open(my $fh, "> $cert_file")) {
    print $fh "FooBar\n";
    unless (close($fh)) {
      die("Can't write $cert_file: $!");
    }

  } else {
    die("Can't open $cert_file: $!");
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $setup->{log_file},
        TLSDSACertificateFile => $cert_file,
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($setup->{config_file},
    $config);

  my $ex;

  # This should silently fail.
  server_start($setup->{config_file});

  # This is where we detect the actual problem.
  eval { server_stop($setup->{pid_file}) };
  unless ($@) {
    $ex = "Server start with bad config unexpectedly";
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub tls_config_tlsdsacertfile_not_dsa {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'tls');

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $setup->{log_file},
        TLSDSACertificateFile => $cert_file,
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($setup->{config_file},
    $config);

  my $ex;

  # This should silently fail.
  server_start($setup->{config_file});

  # This is where we detect the actual problem.
  eval { server_stop($setup->{pid_file}) };
  unless ($@) {
    $ex = "Server start with bad config unexpectedly";
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub tls_config_tlsdsacertkeyfile_bad_format {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'tls');

  my $key_file = File::Spec->rel2abs('t/etc/modules/mod_tls/bad-key.pem');
  if (open(my $fh, "> $key_file")) {
    print $fh "FooBar\n";
    unless (close($fh)) {
      die("Can't write $key_file: $!");
    }

  } else {
    die("Can't open $key_file: $!");
  }

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $setup->{log_file},
        TLSDSACertificateKeyFile => $key_file,
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($setup->{config_file},
    $config);

  my $ex;

  # This should silently fail.
  server_start($setup->{config_file});

  # This is where we detect the actual problem.
  eval { server_stop($setup->{pid_file}) };
  unless ($@) {
    $ex = "Server start with bad config unexpectedly";
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub tls_config_tlsrsacertkeyfile_passphrase {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'tls');

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert-passwd.pem');
  my $key_file = $cert_file;
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');
  my $passphrase_provider = File::Spec->rel2abs('t/etc/modules/mod_tls/tls-get-passphrase.pl');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $setup->{log_file},
        TLSRSACertificateFile => $cert_file,
        TLSRSACertificateKeyFile => $key_file,
        TLSPassPhraseProvider => $passphrase_provider,
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($setup->{config_file},
    $config);

  my $ex;

  # This should silently fail.
  server_start($setup->{config_file});

  # This is where we detect the actual problem.
  eval { server_stop($setup->{pid_file}) };
  unless ($@) {
    $ex = "Server start with bad config unexpectedly";
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub tls_session_cache_off_bug3869 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,

        # By turning session caching off, the session reuse requirement
        # should be related.
        TLSSessionCache => 'off',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $debug = 0;
      if ($ENV{TEST_VERBOSE}) {
        $debug = 2;
      }

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
        Croak => 1,
        Debug => $debug,
      );

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      # Since we are NOT requiring SSL session reuse for data transfers,
      # and this client is not using SSL session resumption, I expect
      # this data transfer to succeed.
      my $res = $client->list('.');
      unless ($res) {
        die("LIST failed unexpectedly: " . $client->message());
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

sub tls_limit_prot_bug3887 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $server_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert.pem');
  my $ca_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $server_cert,
        TLSCACertificateFile => $ca_cert,
        TLSOptions => 'NoSessionReuseRequired',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Directory $home_dir>
  <Limit ALL>
    DenyAll
  </Limit>

  <Limit LIST>
    AllowAll
  </Limit>
</Directory>
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client;

      # IO::Socket::SSL options
      my $ssl_opts = {
        SSL_use_cert => 1,
        SSL_cert_file => $client_cert,
        SSL_key_file => $client_cert,
        SSL_ca_file => $ca_cert,
      };

      my $debug = 0;
      if ($ENV{TEST_VERBOSE}) {
        $debug = 2;
      }

      $client = Net::FTPSSL->new('127.0.0.1',
        Croak => 1,
        DataProtLevel => 'P',
        Encryption => 'E',
        Port => $port,
        Debug => $debug,
        SSL_Client_Certificate => $ssl_opts,
      );

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      my $res;
      if ($Net::FTPSSL::VERSION == 0.21) {
        # Note: The duplicated arguments here are to work around a bug in
        # Net::FTPSSL, version 0.21, in the quot() function.
        $res = $client->quot('PROT', 'P', 'P');

      } else {
        $res = $client->quot('PROT', 'P');
      }

      unless ($res) {
        die("PROT failed unexpectedly: " . $client->last_message());
      }

      $res = $client->list();
      unless ($res) {
        die("LIST failed unexpectedly: " . $client->last_message());
      }

      my $resp_msg = $client->last_message();
      $client->quit();

      my $expected = '226 Transfer complete';
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

sub tls_config_tlsusername_bug3899 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

  # Note: This name matches the CN of the client cert used, for purposes
  # of testing the TLSUserName directive.
  my $user = 'client-cert';
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

  my $server_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $client_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/client-cert.pem');
  my $ca_cert = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $server_cert,
        TLSCACertificateFile => $ca_cert,
        TLSVerifyClient => 'optional',

        TLSUserName => 'CommonName',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      # IO::Socket::SSL options
      my $ssl_opts = {
        SSL_use_cert => 1,
        SSL_cert_file => $client_cert,
        SSL_key_file => $client_cert,
        SSL_ca_file => $ca_cert,
      };

      my $client = Net::FTPSSL->new('127.0.0.1',
        Croak => 1,
        Encryption => 'E',
        Port => $port,
        SSL_Client_Certificate => $ssl_opts,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->_user($user)) {
        die("USER error: " . $client->last_message());
      }

      my $expected = "232 User $user logged in";
      my $resp = $client->last_message();
      $self->assert($expected eq $resp,
        test_msg("Expected response '$expected', got '$resp'"));
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

sub tls_sscn_no_args_bug3955 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      my $resp_code = $client->quot('SSCN');
      if ($resp_code != 2) {
        die("SSCN failed: " . $client->last_message());
      }

      my $resp_msg = $client->last_message();

      $client->quit();

      my $expected = '200 SSCN:SERVER METHOD';
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

sub tls_sscn_too_many_args_bug3955 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      my $resp_code = $client->quot('SSCN', 'foo', 'bar', 'baz');
      if ($resp_code == 2) {
        die("SSCN succeeded unexpectedly");
      }

      my $resp_msg = $client->last_message();

      $client->quit();

      my $expected = '504 SSCN: Invalid argument';
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

sub tls_sscn_bad_arg_bug3955 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      my $resp_code;
      if ($Net::FTPSSL::VERSION == 0.21) {
        # Note: The duplicated arguments here are to work around a bug in
        # Net::FTPSSL, version 0.21, in the quot() function.
        $resp_code = $client->quot('SSCN', 'true', 'true');

      } else {
        $resp_code = $client->quot('SSCN', 'true');
      }

      if ($resp_code == 2) {
        die("SSCN succeeded unexpectedly");
      }

      my $resp_msg = $client->last_message();

      $client->quit();

      my $expected = '501 SSCN: Invalid argument';
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

sub tls_sscn_toggle_bug3955 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      my $resp_code;
      if ($Net::FTPSSL::VERSION == 0.21) {
        # Note: The duplicated arguments here are to work around a bug in
        # Net::FTPSSL, version 0.21, in the quot() function.
        $resp_code = $client->quot('SSCN', 'ON', 'ON');

      } else {
        $resp_code = $client->quot('SSCN', 'ON');
      } 
      
      unless ($resp_code == 2) {
        die("SSCN failed: " . $client->last_message());
      }

      my $resp_msg = $client->last_message();

      my $expected = '200 SSCN:CLIENT METHOD';
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      $resp_code = $client->quot('SSCN');
      unless ($resp_code == 2) {
        die("SSCN failed: " . $client->last_message());
      }

      $resp_msg = $client->last_message();

      $expected = '200 SSCN:CLIENT METHOD';
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      if ($Net::FTPSSL::VERSION == 0.21) {
        # Note: The duplicated arguments here are to work around a bug in
        # Net::FTPSSL, version 0.21, in the quot() function.
        $resp_code = $client->quot('SSCN', 'OFF', 'OFF');

      } else {
        $resp_code = $client->quot('SSCN', 'OFF');
      }

      unless ($resp_code == 2) {
        die("SSCN failed: " . $client->last_message());
      }

      $resp_msg = $client->last_message();

      $expected = '200 SSCN:SERVER METHOD';
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      $resp_code = $client->quot('SSCN');
      unless ($resp_code == 2) {
        die("SSCN failed: " . $client->last_message());
      }

      $resp_msg = $client->last_message();

      $expected = '200 SSCN:SERVER METHOD';
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

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

sub tls_config_limit_sscn_bug3955 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/tls.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/tls.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/tls.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/tls.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/tls.group");

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

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

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $log_file,
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
      },
    },

    Limit => {
     SSCN => {
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      unless ($client) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client->login($user, $passwd)) {
        die("Can't login: " . $client->last_message());
      }

      my $resp_code;
      if ($Net::FTPSSL::VERSION == 0.21) {
        # Note: The duplicated arguments here are to work around a bug in
        # Net::FTPSSL, version 0.21, in the quot() function.
        $resp_code = $client->quot('SSCN', 'ON', 'ON');

      } else {
        $resp_code = $client->quot('SSCN', 'ON');
      }

      if ($resp_code == 2) {
        die("SSCN succeeded unexpectedly");
      }

      my $resp_msg = $client->last_message();

      $client->quit();

      my $expected = '550 SSCN: Operation not permitted';
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

sub tls_config_missing_certs {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'tls');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'tls:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $setup->{log_file},
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSOptions => 'EnableDiags',
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

  require Net::FTPSSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $client = Net::FTPSSL->new('127.0.0.1',
        Encryption => 'E',
        Port => $port,
      );

      if ($client) {
        die("Connected via AUTH TLS unexpectedly");
      }

      my $errstr = IO::Socket::SSL::errstr();
      unless ($errstr) {
        $errstr = $Net::FTPSSL::ERRSTR;
      }

      $self->assert(qr/^431/, $errstr, "Expected 431, got '$errstr'");
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

sub starttls_ftp {
  my $port = shift;
  my $ssl_opts = shift;

  my $client = IO::Socket::INET->new(
    PeerHost => '127.0.0.1',
    PeerPort => $port,
    Proto => 'tcp',
    Type => SOCK_STREAM,
    Timeout => 10
  );
  unless ($client) {
    croak("Can't connect to 127.0.0.1:$port: $!");
  }

  # Read the banner
  my $banner = <$client>;

  # Send the AUTH command
  my $cmd = "AUTH TLS\r\n";
  if ($ENV{TEST_VERBOSE}) {
    print STDOUT "# Sending command: $cmd";
  }
  $client->print($cmd);
  $client->flush();

  # Read the AUTH response
  my $resp = <$client>;
  if ($ENV{TEST_VERBOSE}) {
    print STDOUT "# Received response: $resp";
  }

  my $expected = "234 AUTH TLS successful\r\n";
  unless ($expected eq $resp) {
    croak(test_msg("Expected response '$expected', got '$resp'"));
  }

  # Now perform the SSL handshake
  if ($ENV{TEST_VERBOSE}) {
    $IO::Socket::SSL::DEBUG = 3;
  }

  my $res = IO::Socket::SSL->start_SSL($client, $ssl_opts);
  unless ($res) {
    croak("Failed SSL handshake: " . IO::Socket::SSL::errstr());
  }

  $cmd = "QUIT\r\n";
  if ($ENV{TEST_VERBOSE}) {
    print STDOUT "# Sending command: $cmd";
  }

  $client->print($cmd);
  $client->flush();

  $resp = <$client>;
  if ($ENV{TEST_VERBOSE}) {
    print STDOUT "# Received response: $resp";
  }

  $client->close();
}

sub tls_stapling_on_bug4175 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'tls');

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'tls:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $setup->{log_file},
        TLSProtocol => 'SSLv3 TLSv1',
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => 'EnableDiags',
        TLSStapling => 'on',
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

  require IO::Socket::INET;
  require IO::Socket::SSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      # Manually simulate the STARTTLS protocol

      my $ssl_opts = {
        SSL_ocsp_mode => IO::Socket::SSL::SSL_OCSP_TRY_STAPLE(),
        SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE(),
      };

      starttls_ftp($port, $ssl_opts);
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

sub tls_session_tickets_on_bug4176 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'tls');

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'tls:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $setup->{log_file},
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => 'EnableDiags',
        TLSSessionTickets => 'on',
        TLSSessionTicketKeys => 'age 3sec count 2',
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

  require IO::Socket::INET;
  require IO::Socket::SSL;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      # Give the server a chance to start up
      sleep(2);

      my $ssl_opts = {
        SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE(),
      };

      # Manually simulate the STARTTLS protocol

      starttls_ftp($port, $ssl_opts);

      my $delay = 7;
      if ($delay > 0) {
        if ($ENV{TEST_VERBOSE}) {
          print STDOUT "# Delaying for $delay secs\n";
        }

        sleep($delay);
      }

      starttls_ftp($port, $ssl_opts);
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($setup->{config_file}, $rfh, 30) };
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

sub tls_restart_protected_certs_bug4260 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'tls');

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert-passwd.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');
  my $passphrase_provider = File::Spec->rel2abs('t/etc/modules/mod_tls/tls-get-passphrase-once.pl');

  # Note: This lock file path MUST be kept in sync with the path used by
  # the TLSPassPhraseProvider script used in this test.
  my $lock_file = "/tmp/tls-passphrase.lock";

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'tls:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $setup->{log_file},
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,

        TLSPassPhraseProvider => $passphrase_provider,
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($setup->{config_file},
    $config);

  my $ex;

  # Start the server
  server_start($setup->{config_file});
  sleep(4);

  # Restart the server
  server_restart($setup->{pid_file});
  sleep(4);

  # Stop server
  unless (server_stop($setup->{pid_file})) {
    $ex = "Error stopping server";
  }

  unlink($lock_file);
  test_cleanup($setup->{log_file}, $ex);
}

sub tls_fxp_issue618 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'tls');

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

  my $cert_file = File::Spec->rel2abs('t/etc/modules/mod_tls/server-cert.pem');
  my $ca_file = File::Spec->rel2abs('t/etc/modules/mod_tls/ca-cert.pem');

  # For this test, we will ask the servers to do FXP over TLS for the
  # data transfer, but NOT for the control connections.  Net::FTPSSL does
  # not support FXP over TLS.

  my $tls_opts = 'NoSessionReuseRequired';
  if ($ENV{TEST_VERBOSE}) {
    $tls_opts .= ' EnableDiags';
  }

  my $timeout_idle = 15;

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'command:20 response:20 data:20 netio:20 tls:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    AllowForeignAddress => 'on',
    AllowOverwrite => 'on',
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_tls.c' => {
        TLSEngine => 'on',
        TLSLog => $setup->{log_file},
        TLSRequired => 'on',
        TLSRSACertificateFile => $cert_file,
        TLSCACertificateFile => $ca_file,
        TLSOptions => $tls_opts,
        TLSVerifyClient => 'off',
        TLSVerifyServer => 'off',
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
      # Allow server to start up
      sleep(2);

      my $client_opts = {
        Encryption => 'E',
        Port => $port,
      };

      if ($ENV{TEST_VERBOSE}) {
        $client_opts->{Debug} = 1;
      }

      my $client1 = Net::FTPSSL->new('127.0.0.1', $client_opts);
      unless ($client1) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client1->login($setup->{user}, $setup->{passwd})) {
        die("Can't login: " . $client1->last_message());
      }

      my $client2 = Net::FTPSSL->new('127.0.0.1', $client_opts);
      unless ($client2) {
        die("Can't connect to FTPS server: " . IO::Socket::SSL::errstr());
      }

      unless ($client2->login($setup->{user}, $setup->{passwd})) {
        die("Can't login: " . $client2->last_message());
      }

      $client1->binary();
      $client2->binary();

      my ($resp1, $resp2);

      if ($Net::FTPSSL::VERSION == 0.21) {
        # Note: The duplicated arguments here are to work around a bug in
        # Net::FTPSSL, version 0.21, in the quot() function.

        # One of the two servers needs to act as a client; use SSCN to indicate
        # this.  The default SSCN value is to act as a server, thus the need
        # for an explicit SSCN command.
        $client1->quot('SSCN', 'ON', 'ON');

        unless ($client1->quot('PROT', 'P', 'P')) {
          die("PROT P error: " . $client1->last_message());
        }
        unless ($client2->quot('PROT', 'P', 'P')) {
          die("PROT P error: " . $client2->last_message());
        }

        # Get the PASV address from the first connection, and give it
        # to the second connection as a PORT command.
        unless ($client1->quot('PASV', '', '')) {
          die("PASV error: " . $client1->last_message());
        }

        my $resp_msg = $client1->last_message();
        my $expected = 'Entering Passive Mode \(\d+,\d+,\d+,\d+,\d+,\d+\)';
        $self->assert(qr/$expected/, $resp_msg,
          "Expected response message '$expected', got '$resp_msg'");

        # This will actually work, since both our connections are
        # from 127.0.0.1, which means we shouldn't run afoul of the
        # AllowForeignAddress limit.
        $resp_msg =~ /Entering Passive Mode \((\d+,\d+,\d+,\d+,\d+,\d+\))/;
        my $port_addr = $1;

        unless ($client2->quot('PORT', $port_addr, $port_addr)) {
          die("PORT error: " . $client2->last_message());
        }

        $resp_msg = $client2->last_message();
        $expected = 'PORT command successful';
        $self->assert(qr/$expected/, $resp_msg,
          "Expected response message '$expected', got '$resp_msg'");

        # Note that we use command() here, not quot(), as the latter tries
        # to protect users from using data-transfer-causing commands like we
        # are doing.
        $resp1 = $client1->command('RETR', $src_file, $src_file);
        unless ($resp1) {
          die("Can't RETR $src_file: " . $client1->last_message());
        }
        $resp2 = $client2->command('STOR', $dst_file, $dst_file);
        unless ($resp2) {
          die("Can't STOR $dst_file: " . $client2->last_message());
        }

      } else {
        # One of the two servers needs to act as a client; use SSCN to indicate
        # this.  The default SSCN value is to act as a server, thus the need
        # for an explicit SSCN command.
        $client1->quot('SSCN', 'ON');

        unless ($client1->quot('PROT', 'P')) {
          die("PROT P error: " . $client1->last_message());
        }
        unless ($client2->quot('PROT', 'P')) {
          die("PROT P error: " . $client2->last_message());
        }

        # Get the PASV address from the first connection, and give it
        # to the second connection as a PORT command.
        unless ($client1->quot('PASV', '')) {
          die("PASV error: " . $client1->last_message());
        }

        my $resp_msg = $client1->last_message();
        my $expected = 'Entering Passive Mode \(\d+,\d+,\d+,\d+,\d+,\d+\)';
        $self->assert(qr/$expected/, $resp_msg,
          "Expected response message '$expected', got '$resp_msg'");

        # This will actually work, since both our connections are
        # from 127.0.0.1, which means we shouldn't run afoul of the
        # AllowForeignAddress limit.
        $resp_msg =~ /Entering Passive Mode \((\d+,\d+,\d+,\d+,\d+,\d+\))/;
        my $port_addr = $1;

        unless ($client2->quot('PORT', $port_addr)) {
          die("PORT error: " . $client2->last_message());
        }

        $resp_msg = $client2->last_message();
        $expected = 'PORT command successful';
        $self->assert(qr/$expected/, $resp_msg,
          "Expected response message '$expected', got '$resp_msg'");

        # Note that we use command() here, not quot(), as the latter tries
        # to protect users from using data-transfer-causing commands like we
        # are doing.
        $resp1 = $client1->command('RETR', $src_file);
        unless ($resp1) {
          die("Can't RETR $src_file: " . $client1->last_message());
        }
        $resp2 = $client2->command('STOR', $dst_file);
        unless ($resp2) {
          die("Can't STOR $dst_file: " . $client2->last_message());
        }
      }

      # First, we read the 150 responses, then the 226 responses.
      my $res1 = $resp1->response();
      my $res2 = $resp2->response();

      if ($res1 eq '1') {
        $res1 = $resp1->response();
      }
      if ($res2 eq '1') {
        $res2 = $resp2->response();
      }

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
    eval { server_wait($setup->{config_file}, $rfh, $timeout_idle + 5) };
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
