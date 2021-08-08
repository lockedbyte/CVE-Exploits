package ProFTPD::Tests::Logging::ExtendedLog;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use Compress::Raw::Zlib;
use Compress::Zlib;
use File::Copy;
use File::Path qw(mkpath);
use File::Spec;
use IO::Handle;
use IPC::Open3;
use POSIX qw(:fcntl_h);
use Sys::HostAddr;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite :features);

$| = 1;

my $order = 0;

my $TESTS = {
  extlog_retr_default => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_retr_bug3137 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_stor_bug3137 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_site_cmds_bug3171 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_mlsd_var_d_D_f_F_bug3950 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_sftp_mlsd_var_d_D_f_F_bug3950 => {
    order => ++$order,
    test_class => [qw(bug forking mod_sftp)],
  },

  extlog_mfmt_var_d_D_f_F => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_protocol => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_remote_port => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_protocol_version_quoted_bug3383 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_rename_from => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_sftp_rename_from => {
    order => ++$order,
    test_class => [qw(bug forking mod_sftp)],
  },

  extlog_ext_sftp_posix_rename_bug3949 => {
    order => ++$order,
    test_class => [qw(bug forking mod_sftp)],
  },

  extlog_orig_user => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_bug1908 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  extlog_file_modified_bug3457 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_dele_bug3469 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_client_dir_bug3395 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_client_dir_chroot_bug3395 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  extlog_device_full => {
    order => ++$order,
    test_class => [qw(forking os_linux)],
  },

  extlog_uid_bug3390 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  extlog_gid_bug3390 => {
    order => ++$order,
    test_class => [qw(bug forking rootprivs)],
  },

  extlog_pass_ok_var_s_bug3528 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_pass_failed_var_s_bug3528 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_ftp_raw_bytes_bug3554 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_ftp_sendfile_raw_bytes_bug3554 => {
    order => ++$order,
    test_class => [qw(bug feature_sendfile forking)],
  },

  extlog_ftp_deflate_raw_bytes_bug3554 => {
    order => ++$order,
    test_class => [qw(bug forking mod_deflate)],
  },

  extlog_ftps_raw_bytes_bug3554 => {
    order => ++$order,
    test_class => [qw(bug forking mod_tls)],
  },

  extlog_sftp_raw_bytes_bug3554 => {
    order => ++$order,
    test_class => [qw(bug forking mod_sftp)],
  },

  extlog_scp_raw_bytes_bug3554 => {
    order => ++$order,
    test_class => [qw(bug forking mod_sftp)],
  },

  extlog_exit_bug3559 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_eos_reason_quit => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_eos_reason_eof => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_eos_reason_timeoutidle => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_eos_reason_timeoutlogin => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_eos_reason_timeoutnotransfer => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_eos_reason_timeoutsession => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_eos_reason_timeoutstalled => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_vars_H_L_matching_server_bug3620 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_vars_H_L_default_server_bug3620 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_user_pass => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_anon_user_pass => {
    order => ++$order,
    test_class => [qw(forking rootprivs)],
  },

  extlog_cmd_resp => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_xfer_timeout_bug3696 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_sftp_xfer_timeout_bug3696 => {
    order => ++$order,
    test_class => [qw(bug forking mod_sftp ssh2)],
  },

  extlog_var_r => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_pass_var_r => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_sftp_pass_var_r => {
    order => ++$order,
    test_class => [qw(forking mod_sftp)],
  },

  extlog_sftp_retr_var_s_bug3948 => {
    order => ++$order,
    test_class => [qw(bug forking mod_sftp)],
  },

  extlog_sftp_stor_var_s_bug3948 => {
    order => ++$order,
    test_class => [qw(bug forking mod_sftp)],
  },

  extlog_abor => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_xfer_status_nonxfer => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_xfer_status_success => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_xfer_status_cancelled => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_xfer_status_failed => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_xfer_status_timeout => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_xfer_failure_none => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_xfer_failure_reason => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_ftps_xfer_status_cancelled => {
    order => ++$order,
    test_class => [qw(forking mod_tls)],
  },

  extlog_ftps_xfer_status_failed => {
    order => ++$order,
    test_class => [qw(forking mod_tls)],
  },

  extlog_login_maxclients_bug3811 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_login_maxclientsperclass_bug3811 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_login_maxclientsperhost_bug3811 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_login_maxclientsperuser_bug3811 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_preauth_var_U_bug3822 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_preauth_var_u_bug3822 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_micros_ts_bug3889 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_millis_ts_bug3889 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_iso8601_ts_bug3889 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_dirs_class_var_f_bug3966 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_var_basename_bug3987 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_exclusion_bug4067 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_sftp_ssh_sftp_bug4067 => {
    order => ++$order,
    test_class => [qw(bug forking mod_sftp)],
  },

  extlog_sftp_ssh_sftp_exclusion_bug4067 => {
    order => ++$order,
    test_class => [qw(bug forking mod_sftp)],
  },

  extlog_sftp_read_write_bug4067 => {
    order => ++$order,
    test_class => [qw(bug forking mod_sftp)],
  },

  extlog_sftp_xfer_status_filtered => {
    order => ++$order,
    test_class => [qw(forking mod_sftp)],
  },

  extlog_var_file_offset => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_var_file_size_retr => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_sftp_var_file_size_retr => {
    order => ++$order,
    test_class => [qw(forking mod_sftp)],
  },

  extlog_var_file_size_stor => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_sftp_var_file_size_stor => {
    order => ++$order,
    test_class => [qw(forking mod_sftp)],
  },

  extlog_var_transfer_type_retr => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_var_transfer_type_stor => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_file_transfer_secs => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  extlog_file_transfer_millisecs_bug4218 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_response_millisecs_bug4218 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_stor_var_f_xfer_timed_out => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  extlog_write_invalid_cmd_bug4313 => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  # XXX Need unit tests for all LogFormat variables
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

sub extlog_retr_default {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'extlog');

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'jot:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},
    ExtendedLog => "$ext_log ALL",

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($setup->{user}, $setup->{passwd});

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

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

  eval {
    if (open(my $fh, "< $ext_log")) {
      while (my $line = <$fh>) {
        chomp($line);

        if ($ENV{TEST_VERBOSE}) { 
          print STDERR "$line\n";
        }

        if ($line !~ /^127\.0\.0\.1 UNKNOWN/) {
          die("Unexpected ExtendedLog first line: $line");
        }

        if ($line =~ /\"USER (\S+)\" (\d+) /) {
          my $logged_user = $1;
          my $resp_code = $2;

          my $expected = $setup->{user};
          $self->assert($expected eq $logged_user,
            "Expected user '$expected', got '$logged_user'");

          $expected = '331';
          $self->assert($expected eq $resp_code,
            "Expected response code '$expected', got '$resp_code'");

        } elsif ($line =~ /\"PASS \(hidden\)\" (\d+) /) {
          my $resp_code = $1;

          my $expected = '230';
          $self->assert($expected eq $resp_code,
            "Expected response code '$expected', got '$resp_code'");

        } elsif ($line =~ /\"PASV\" (\d+) /) {
          my $resp_code = $1;

          my $expected = '227';
          $self->assert($expected eq $resp_code,
            "Expected response code '$expected', got '$resp_code'");

        } elsif ($line =~ /\"RETR (\S+)\" (\d+) (\d+)/) {
          my $logged_path = $1;
          my $resp_code = $2;
          my $xfer_len = $3;

          my $expected = $test_file;
          $self->assert($expected eq $logged_path,
            "Expected transferred path '$expected', got '$logged_path'");

          $expected = '226';
          $self->assert($expected eq $resp_code,
            "Expected response code '$expected', got '$resp_code'");

          $expected = 14;
          $self->assert($expected == $xfer_len,
            "Expected tranferred bytes $expected, got $xfer_len");

        } elsif ($line =~ /\"QUIT\" (\d+) /) {
          my $resp_code = $1;

          my $expected = '221';
          $self->assert($expected eq $resp_code,
            "Expected response code '$expected', got '$resp_code'");

        } else {
          die("Unexpected ExtendedLog line: $line");
        }
      }

      close($fh);

    } else {
      die("Can't read $ext_log: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub extlog_retr_bug3137 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%f"',
    ExtendedLog => "$ext_log READ custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

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

  # Now, read in the ExtendedLog, and see whether the %f variable was
  # properly written out.  Bug#3137 occurred because the session.xfer.path
  # variable was cleared out, as part of cleaning up the data connection,
  # too early.  The fix is to use session.notes, which also has that path
  # information.
  if (open(my $fh, "< $ext_log")) {
    my $line = <$fh>;
    chomp($line);

    if ($ENV{TEST_VERBOSE}) { 
      print STDERR "$line\n";
    }

    close($fh);

    if ($^O eq 'darwin') {
      # MacOSX-specific hack
      $test_file = '/private' . $test_file;
    }

    $self->assert($test_file eq $line,
      test_msg("Expected '$test_file', got '$line'"));

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_stor_bug3137 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs("$tmpdir/foo");

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%f"',
    ExtendedLog => "$ext_log WRITE custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      my $conn = $client->stor_raw('foo');
      unless ($conn) {
        die("Failed to STOR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Foo!\n";
      $conn->write($buf, length($buf));
      eval { $conn->close() };
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

  # Now, read in the ExtendedLog, and see whether the %f variable was
  # properly written out.  Bug#3137 occurred because the session.xfer.path
  # variable was cleared out, as part of cleaning up the data connection,
  # too early.  The fix is to use session.notes, which also has that path
  # information.
  if (open(my $fh, "< $ext_log")) {
    my $line = <$fh>;
    chomp($line);
    close($fh);

    if ($^O eq 'darwin') {
      # MacOSX-specific hack
      $test_file = '/private' . $test_file;
    }

    $self->assert($test_file eq $line,
      test_msg("Expected '$test_file', got '$line'"));

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_site_cmds_bug3171 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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
      die("Can't set owner of $home_dir, $test_file to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%m"',
    ExtendedLog => "$ext_log ALL custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      # Send a SITE command; Bug#3171 occurred because %m was not expanded
      # properly for SITE commands.

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->site('CHMOD', '0644', 'test.txt');

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

  # Now, read in the ExtendedLog, and see whether the %m variable was
  # properly written out.  Bug#3171 occurred because %m, for SITE commands,
  # only contains 'SITE', and not the actual command used.

  if (open(my $fh, "< $ext_log")) {
    my $line;

    while ($line = <$fh>) {
      chomp($line);

      if ($line =~ /^SITE/) {
        last;
      }
    }

    close($fh);

    my $expected = 'SITE CHMOD';
    $self->assert($expected eq $line,
      test_msg("Expected '$expected', got '$line'"));

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_mlsd_var_d_D_f_F_bug3950 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $sub_dir = File::Spec->rel2abs("$home_dir/sub.d");
  mkpath($sub_dir);

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

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%d %D %f %F"',
    ExtendedLog => "$ext_log DIRS custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      my $conn = $client->mlsd_raw('sub.d');
      unless ($conn) {
        die("Failed to MLSD sub.d: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

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

  # Now, read in the ExtendedLog, and see whether the %f variable was
  # properly written out for MLSD.  Specifically, %f should be '-',
  # since this is a directory transfer; %d should have the path in question.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $line = <$fh>;
      chomp($line);
      close($fh);

      if ($line =~ /^(\S+) (\S+) (\S+) (\S+)$/) {
        my $dir_name = $1;
        my $dir_path = $2;
        my $file_name = $3;
        my $file_path = $4;

        $self->assert('sub.d' eq $dir_name,
          test_msg("Expected 'sub.d', got '$dir_name'"));

        if ($^O eq 'darwin') {
          # MacOSX-specific hack
          $sub_dir = '/private' . $sub_dir;
        }

        $self->assert($sub_dir eq $dir_path,
          test_msg("Expected '$sub_dir', got '$dir_path'"));

        $self->assert($sub_dir eq $file_name,
          test_msg("Expected '-', got '$file_name'"));

        $self->assert('-' eq $file_path,
          test_msg("Expected '-', got '$file_path'"));

      } else {
        die("Did not find expected ExtendedLog entries");
      }

    } else {
      die("Can't read $ext_log: $!");
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

sub extlog_sftp_mlsd_var_d_D_f_F_bug3950 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $sub_dir = File::Spec->rel2abs("$home_dir/sub.d");
  mkpath($sub_dir);

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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 ssh2:20 sftp:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%m: %d %D %f %F"',
    ExtendedLog => "$ext_log DIRS custom",

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

      unless ($ssh2->auth_password($user, $passwd)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $sftp = $ssh2->sftp();
      unless ($sftp) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't use SFTP on SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $dir = $sftp->opendir('sub.d');
      unless ($dir) {
        my ($err_code, $err_name) = $sftp->error();
        die("Can't open directory 'sub.d': [$err_name] ($err_code)");
      }

      my $res = {};

      my $file = $dir->read();
      while ($file) {
        $res->{$file->{name}} = $file;
        $file = $dir->read();
      }

      # To issue the FXP_CLOSE, we have to explicitly destroy the dirhandle
      $dir = undef;

      # To close the SFTP channel, we have to explicitly destroy the object
      $sftp = undef;

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

  # Now, read in the ExtendedLog, and see whether the %f variable was
  # properly written out for MLSD.  Specifically, %f should be '-',
  # since this is a directory transfer; %d should have the path in question.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $line;

      while ($line = <$fh>) {
        chomp($line);

        # Look for the MLSD line
        if ($line =~ /^MLSD:/) {
          last;
        }
      }

      close($fh);

      if ($line =~ /^\S+: (\S+) (\S+) (\S+) (\S+)$/) {
        my $dir_name = $1;
        my $dir_path = $2;
        my $file_name = $3;
        my $file_path = $4;

        $self->assert('sub.d' eq $dir_name,
          test_msg("Expected 'sub.d', got '$dir_name'"));

        if ($^O eq 'darwin') {
          # MacOSX-specific hack
          $sub_dir = '/private' . $sub_dir;
        }

        $self->assert($sub_dir eq $dir_path,
          test_msg("Expected '$sub_dir', got '$dir_path'"));

        $self->assert($sub_dir eq $file_name,
          test_msg("Expected '$sub_dir', got '$file_name'"));

        $self->assert('-' eq $file_path,
          test_msg("Expected '-', got '$file_path'"));

      } else {
        die("Did not find expected ExtendedLog entries");
      }

    } else {
      die("Can't read $ext_log: $!");
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

sub extlog_mfmt_var_d_D_f_F {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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
    close($fh);

  } else {
    die("Can't open $test_file: $!");
  }

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%m: %d %D %f %F"',
    ExtendedLog => "$ext_log WRITE custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      my ($resp_code, $resp_msg) = $client->mfmt('20020717210715', 'test.txt');

      my $expected;

      $expected = 213;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'Modify=20020717210715; test.txt';
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

  # Now, read in the ExtendedLog, and see whether the %f variable was
  # properly written out for MFMT.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $ok = 0;

      while (my $line = <$fh>) {
        chomp($line);

        # The %D variable should be empty here, since MFMT is not a directory
        # specific command.
        if ($line =~ /^(\S+): (\S+)  (\S+) (\S+)$/) {
          my $cmd = $1;
          my $dir_path = $2;
          my $file_name = $3;
          my $xfer_path = $4;

          next unless $cmd eq 'MFMT';

          if ($^O eq 'darwin') {
            # MacOSX-specific hack
            $home_dir = '/private' . $home_dir;
          }

          $self->assert($home_dir eq $dir_path,
            test_msg("Expected directory path (%d) '$home_dir', got '$dir_path'"));

          if ($^O eq 'darwin') {
            # MacOSX-specific hack
            $test_file = '/private' . $test_file;
          }

          $self->assert($test_file eq $file_name,
            test_msg("Expected filename (%f) '$test_file', got '$file_name'"));

          $self->assert('-' eq $xfer_path,
            test_msg("Expected transfer path (%F) '-', got '$xfer_path'"));

          $ok = 1;
          last;
        }
      }

      close($fh);

      $self->assert($ok, test_msg("Did not find expected ExtendedLog entries"));

    } else {
      die("Can't read $ext_log: $!");
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

sub extlog_protocol {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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
      die("Can't set owner of $home_dir, $test_file to $uid/$gid: $!");
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%{protocol}"',
    ExtendedLog => "$ext_log ALL custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      # Send a SITE command; Bug#3171 occurred because %m was not expanded
      # properly for SITE commands.

      my ($resp_code, $resp_msg);

      ($resp_code, $resp_msg) = $client->site('CHMOD', '0644', 'test.txt');

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

  if (open(my $fh, "< $ext_log")) {
    my $line;

    while ($line = <$fh>) {
      chomp($line);

      if ($line =~ /^ftp/) {
        last;
      }
    }

    close($fh);

    my $expected = 'ftp';
    $self->assert($expected eq $line,
      test_msg("Expected '$expected', got '$line'"));

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_protocol_version_quoted_bug3383 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'extlog');

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    close($fh);

  } else {
    die("Can't open $test_file: $!");
  }

  # Make sure that, if we're running as root, that the test file has
  # permissions/privs set for the account we create
  if ($< == 0) {
    unless (chown($setup->{uid}, $setup->{gid}, $test_file)) {
      die("Can't set owner of $test_file to $setup->{uid}/$setup->{gid}: $!");
    }
  }

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'jot:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    LogFormat => 'custom "\"%{protocol}\" \"%{version}\""',
    ExtendedLog => "$ext_log ALL custom",

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($setup->{user}, $setup->{passwd});

      # Send a SITE command; Bug#3171 occurred because %m was not expanded
      # properly for SITE commands.

      my ($resp_code, $resp_msg) = $client->site('CHMOD', '0644', 'test.txt');

      my $expected = 200;
      $self->assert($expected == $resp_code,
        "Expected response code $expected, got $resp_code");

      $expected = "SITE CHMOD command successful";
      $self->assert($expected eq $resp_msg,
        "Expected response message '$expected', got '$resp_msg'");
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

  my $server_version = feature_get_version();

  eval {
    if (open(my $fh, "< $ext_log")) {
      my $line;

      while ($line = <$fh>) {
        chomp($line);

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "# ExtendedLog: $line\n";
        }

        if ($line =~ /^"ftp" "(\S+)"/) {
          last;
        }
      }

      close($fh);

      my $expected = "\"ftp\" \"$server_version\"";
      $self->assert($expected eq $line, "Expected '$expected', got '$line'");

    } else {
      die("Can't read $ext_log: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub extlog_remote_port {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'extlog');

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    LogFormat => 'custom "%m: %{remote-port}"',
    ExtendedLog => "$ext_log ALL custom",

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
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

  eval {
    if (open(my $fh, "< $ext_log")) {
      my $ok = 0;
      my $line;

      while ($line = <$fh>) {
        chomp($line);

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "# line: $line\n";
        }

        if ($line =~ /^USER: \d+$/) {
          $ok = 1;
        }
      }

      close($fh);

      $self->assert($ok,
        test_msg("Did not see expected remote port in ExtendedLog"));

    } else {
      die("Can't read $ext_log: $!");
    }
  };
  if ($@) {
    $ex;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub extlog_rename_from {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $src_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $src_file")) {
    close($fh);

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/foo.txt");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%m: %w %f"',
    ExtendedLog => "$ext_log WRITE custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      $client->rnfr('test.txt');
      my ($resp_code, $resp_msg) = $client->rnto('foo.txt');

      my $expected;

      $expected = 250;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Rename successful";
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

  # Now, read in the ExtendedLog, and see whether the %f and %w variables were
  # properly written out.
  if (open(my $fh, "< $ext_log")) {
    my $line = <$fh>;
    chomp($line);

    if ($ENV{TEST_VERBOSE}) {
      print STDERR "logged: $line\n";
    }

    if ($^O eq 'darwin') {
      # MacOSX-specific hack
      $src_file = '/private' . $src_file;
      $dst_file = '/private' . $dst_file;
    }

    my $expected = "RNFR: - $src_file";
    $self->assert($expected eq $line,
      test_msg("Expected '$expected', got '$line'"));

    $line = <$fh>;
    chomp($line);

    if ($ENV{TEST_VERBOSE}) {
      print STDERR "logged: $line\n";
    }

    $expected = "RNTO: $src_file $dst_file";
    $self->assert($expected eq $line,
      test_msg("Expected '$expected', got '$line'"));

    close($fh);

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_sftp_rename_from {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $src_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $src_file")) {
    close($fh);

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/foo.txt");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 ssh2:20 sftp:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%w %f"',
    ExtendedLog => "$ext_log WRITE custom",

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

      unless ($ssh2->auth_password($user, $passwd)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $sftp = $ssh2->sftp();
      unless ($sftp) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't use SFTP on SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $res = $sftp->rename('test.txt', 'foo.txt');
      unless ($res) {
        my ($err_code, $err_name) = $sftp->error();
        die("Can't rename test.txt to foo.txt: [$err_name] ($err_code)");
      }

      $sftp = undef;
      $ssh2->disconnect();

      if (-f $src_file) {
        die("$src_file file exists unexpectedly");
      }

      unless (-f $dst_file) {
        die("$dst_file file does not exist as expected");
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

  # Now, read in the ExtendedLog, and see whether the %f and %w variables were
  # properly written out.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $line = <$fh>;
      chomp($line);

      if ($^O eq 'darwin') {
        # MacOSX-specific hack
        $src_file = '/private' . $src_file;
        $dst_file = '/private' . $dst_file;
      }

      my $expected = "- $src_file";
      $self->assert($expected eq $line,
        test_msg("Expected '$expected', got '$line'"));

      $line = <$fh>;
      chomp($line);

      $expected = "$src_file $dst_file";
      $self->assert($expected eq $line,
        test_msg("Expected '$expected', got '$line'"));

      close($fh);

    } else {
      die("Can't read $ext_log: $!");
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

sub extlog_ext_sftp_posix_rename_bug3949 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

  my $rsa_priv_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/test_rsa_key');
  my $rsa_pub_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/test_rsa_key.pub');
  my $rsa_rfc4716_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/authorized_rsa_keys');

  my $authorized_keys = File::Spec->rel2abs("$tmpdir/.authorized_keys");
  unless (copy($rsa_rfc4716_key, $authorized_keys)) {
    die("Can't copy $rsa_rfc4716_key to $authorized_keys: $!");
  }

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $src_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $src_file")) {
    close($fh);

  } else {
    die("Can't open $src_file: $!");
  }

  my $dst_file = File::Spec->rel2abs("$tmpdir/foo.txt");

  my $batch_file = File::Spec->rel2abs("$tmpdir/sftp-batch.txt");
  if (open(my $fh, "> $batch_file")) {
    print $fh "rename test.txt foo.txt\n";

    unless (close($fh)) {
      die("Can't write $batch_file: $!");
    }

  } else {
    die("Can't open $batch_file: $!");
  }

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 ssh2:20 sftp:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%w %f"',
    ExtendedLog => "$ext_log WRITE custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sftp.c' => [
        "SFTPEngine on",
        "SFTPLog $log_file",
        "SFTPHostKey $rsa_host_key",
        "SFTPHostKey $dsa_host_key",
        "SFTPAuthorizedUserKeys file:~/.authorized_keys",
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

  require Net::SSH2;

  my $ex;

  # Ignore SIGPIPE
  local $SIG{PIPE} = sub { };

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(1);

      my @cmd = (
        'sftp',
        '-oBatchMode=yes',
        '-oCheckHostIP=no',
        '-oCompression=yes',
        "-oPort=$port",
        "-oIdentityFile=$rsa_priv_key",
        '-oPubkeyAuthentication=yes',
        '-oStrictHostKeyChecking=no',
        '-vvv',
        '-b',
        "$batch_file",
        "$user\@127.0.0.1",
      );

      my $sftp_rh = IO::Handle->new();
      my $sftp_wh = IO::Handle->new();
      my $sftp_eh = IO::Handle->new();

      $sftp_wh->autoflush(1);

      local $SIG{CHLD} = 'DEFAULT';

      # Make sure that the perms on the priv key are what OpenSSH wants
      unless (chmod(0400, $rsa_priv_key)) {
        die("Can't set perms on $rsa_priv_key to 0400: $!");
      }

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "Executing: ", join(' ', @cmd), "\n";
      }

      my $sftp_pid = open3($sftp_wh, $sftp_rh, $sftp_eh, @cmd);
      waitpid($sftp_pid, 0);
      my $exit_status = $?;

      # Restore the perms on the priv key
      unless (chmod(0644, $rsa_priv_key)) {
        die("Can't set perms on $rsa_priv_key to 0644: $!");
      }

      my ($res, $errstr);
      if ($exit_status >> 8 == 0) {
        $errstr = join('', <$sftp_eh>);
        $res = 0;

      } else {
        if ($ENV{TEST_VERBOSE}) {
          $errstr = join('', <$sftp_eh>);
          print STDERR "Stderr: $errstr\n";
        }

        $res = 1;
      }

      unless ($res == 0) {
        die("Can't rename $src_file to $dst_file: $errstr");
      }

      if (-f $src_file) {
        die("$src_file file exists unexpectedly");
      }

      unless (-f $dst_file) {
        die("$dst_file file does not exist as expected");
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

  # Now, read in the ExtendedLog, and see whether the %f and %w variables were
  # properly written out.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $line = <$fh>;
      chomp($line);

      if ($^O eq 'darwin') {
        # MacOSX-specific hack
        $src_file = '/private' . $src_file;
        $dst_file = '/private' . $dst_file;
      }

      my $expected = "- $src_file";
      $self->assert($expected eq $line,
        test_msg("Expected '$expected', got '$line'"));

      $line = <$fh>;
      chomp($line);

      $expected = "$src_file $dst_file";
      $self->assert($expected eq $line,
        test_msg("Expected '$expected', got '$line'"));

      close($fh);

    } else {
      die("Can't read $ext_log: $!");
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

sub extlog_orig_user {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%U"',
    ExtendedLog => "$ext_log AUTH custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

  # Now, read in the ExtendedLog, and see whether the %f and %w variables were
  # properly written out.
  if (open(my $fh, "< $ext_log")) {
    my $line = <$fh>;
    chomp($line);

    my $expected = $user;
    $self->assert($expected eq $line,
      test_msg("Expected '$expected', got '$line'"));

    $line = <$fh>;
    chomp($line);

    $expected = $user;
    $self->assert($expected eq $line,
      test_msg("Expected '$expected', got '$line'"));

    close($fh);

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_bug1908 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $ext_log = File::Spec->rel2abs("$tmpdir/ext.log");
  my $anon_ext_log = File::Spec->rel2abs("$tmpdir/anon-ext.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    ExtendedLog => "$ext_log READ",

    Anonymous => {
      $home_dir => [
        "User $user",
        "Group $group",
        "ExtendedLog $anon_ext_log READ",
        "ExtendedLog $ext_log NONE",
      ],
    },

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      my $conn = $client->retr_raw('test.txt');
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

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

  # Now, read in the ExtendedLogs.  Ideally we would NOT see anything in
  # the ExtendedLog defined in the "server config" context, and WOULD see
  # lines in the ExtendedLog defined in the <Anonymous> context.

  my $extlog_nlines = 0;
  if (open(my $fh, "< $ext_log")) {
    while (my $line = <$fh>) {
      $extlog_nlines++;
    }
    close($fh);

  } else {
    die("Can't read $ext_log: $!");
  }

  my $anon_extlog_nlines = 0;
  if (open(my $fh, "< $anon_ext_log")) {
    while (my $line = <$fh>) {
      $anon_extlog_nlines++;
    }
    close($fh);

  } else {
    die("Can't read $anon_ext_log: $!");
  }

  my $expected = 0;
  $self->assert($expected == $extlog_nlines,
    test_msg("Expected $expected, got $extlog_nlines"));

  $expected = 1;
  $self->assert($expected == $anon_extlog_nlines,
    test_msg("Expected $expected, got $anon_extlog_nlines"));

  unlink($log_file);
}

sub extlog_file_modified_bug3457 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $test_file = File::Spec->rel2abs("$home_dir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, world!\n";
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    AllowOverwrite => 'on',
    LogFormat => 'custom "%{file-modified}"',
    ExtendedLog => "$ext_log WRITE custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      my $conn = $client->stor_raw('test.txt');
      unless ($conn) {
        die("Failed to STOR test.txt: " . $client->response_code() . " " .
          $client->response_msg());
      }

      eval { $conn->close() };
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

  # Now, read in the ExtendedLog, and see whether the %{file-modified}
  # variable was properly written out.
  if (open(my $fh, "< $ext_log")) {
    my $line = <$fh>;
    chomp($line);
    close($fh);

    my $expected = 'true';
    $self->assert($expected eq $line,
      test_msg("Expected '$expected', got '$line'"));

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_dele_bug3469 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $test_file = File::Spec->rel2abs("$tmpdir/~test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "Hello, World!\n";

    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%m %f"',
    ExtendedLog => "$ext_log ALL custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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
      $client->dele('~test.txt');
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

  # Now, read in the ExtendedLog, and see whether the %f variable was
  # properly written out.  Bug#3469 occurred because the session.xfer.path
  # variable was cleared out, as part of cleaning up the data connection,
  # too early.  The fix is to use session.notes, which also has that path
  # information.
  if (open(my $fh, "< $ext_log")) {
    if ($^O eq 'darwin') {
      # MacOSX-specific hack
      $test_file = '/private' . $test_file;
    }

    while (my $line = <$fh>) {
      chomp($line);

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "$line\n";
      }

      # We're only interested in the DELE log line
      unless ($line =~ /^DELE (.*)$/i) {
        next;
      }

      my $name = $1;
      my $expected = $test_file;
      $self->assert($expected eq $name,
        test_msg("Expected '$expected', got '$name'"));
    }

    close($fh);

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_client_dir_bug3395 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $sub_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($sub_dir);

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

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%m %d"',
    ExtendedLog => "$ext_log ALL custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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
      $client->cwd('foo');
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

  # Now, read in the ExtendedLog, and see whether the %d variable was
  # properly written out.  Bug#3395 says that even for QUIT, the %d
  # variable should be valid.
  if (open(my $fh, "< $ext_log")) {
    if ($^O eq 'darwin') {
      # MacOSX-specific hack
      $sub_dir = '/private' . $sub_dir;
    }

    while (my $line = <$fh>) {
      chomp($line);

      # We're only interested in the QUIT log line
      unless ($line =~ /^QUIT (.*)$/i) {
        next;
      }

      my $name = $1;
      my $expected = $sub_dir;
      $self->assert($expected eq $name,
        test_msg("Expected '$expected', got '$name'"));
    }

    close($fh);

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_client_dir_chroot_bug3395 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $sub_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($sub_dir);

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

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    DefaultRoot => '~',

    LogFormat => 'custom "%m %d"',
    ExtendedLog => "$ext_log ALL custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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
      $client->cwd('foo');
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

  # Now, read in the ExtendedLog, and see whether the %d variable was
  # properly written out.  Bug#3395 says that even for QUIT, the %d
  # variable should be valid.
  if (open(my $fh, "< $ext_log")) {
    while (my $line = <$fh>) {
      chomp($line);

      # We're only interested in the QUIT log line
      unless ($line =~ /^QUIT (.*)$/i) {
        next;
      }

      my $name = $1;
      my $expected = '/foo';
      $self->assert($expected eq $name,
        test_msg("Expected '$expected', got '$name'"));
    }

    close($fh);

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_device_full {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $sub_dir = File::Spec->rel2abs("$tmpdir/foo");
  mkpath($sub_dir);

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

  # XXX The /dev/full device only exists on Linux, as far as I know
  my $ext_log = File::Spec->rel2abs('/dev/full');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%m %d"',
    ExtendedLog => "$ext_log ALL custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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
      $client->cwd('foo');
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

sub extlog_uid_bug3390 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%{uid}"',
    ExtendedLog => "$ext_log READ custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };
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

  # Now, read in the ExtendedLog, and see whether the %{uid} variable was
  # properly written out.
  if (open(my $fh, "< $ext_log")) {
    my $line = <$fh>;
    chomp($line);
    close($fh);

    $self->assert($uid == $line,
      test_msg("Expected $uid, got '$line'"));

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_gid_bug3390 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%{gid}"',
    ExtendedLog => "$ext_log READ custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };
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

  # Now, read in the ExtendedLog, and see whether the %{gid} variable was
  # properly written out.
  if (open(my $fh, "< $ext_log")) {
    my $line = <$fh>;
    chomp($line);
    close($fh);

    $self->assert($gid == $line,
      test_msg("Expected $gid, got '$line'"));

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_pass_ok_var_s_bug3528 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'response:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%m %s %S"',
    ExtendedLog => "$ext_log AUTH custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

  # Now, read in the ExtendedLog, and see whether the %s variable was
  # properly written out for the PASS command.
  if (open(my $fh, "< $ext_log")) {
    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /^(\S+) (\S+) (.*$)$/) {
        my $cmd = $1;
        my $resp_code = $2;
        my $resp_msg = $3;

        next unless $cmd eq 'PASS';

        my $expected = 230;
        $self->assert($expected == $resp_code,
          test_msg("Expected $expected, got $resp_code"));

        $expected = "User $user logged in";
        $self->assert($expected eq $resp_msg,
          test_msg("Expected '$expected', got '$resp_msg'"));

        last;
      }
    }

    close($fh);

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_pass_failed_var_s_bug3528 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'extlog');

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'extlog:20 jot:20 response:10',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    LogFormat => 'custom "%m %s %S"',
    ExtendedLog => "$ext_log AUTH custom",

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      eval { $client->login($setup->{user}, 'foobar') };
      unless ($@) {
        die("Login succeeded unexpectedly");
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

  # Now, read in the ExtendedLog, and see whether the %s variable was
  # properly written out for the PASS command.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $ok = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "# ExtendedLog: $line\n";
        }

        if ($line =~ /^(\S+) (\S+) (.*$)$/) {
          my $cmd = $1;
          my $resp_code = $2;
          my $resp_msg = $3;

          next unless $cmd eq 'PASS';

          my $expected = 530;
          $self->assert($expected == $resp_code,
            test_msg("Expected $expected, got $resp_code"));

          $expected = "Login incorrect.";
          $self->assert($expected eq $resp_msg,
            test_msg("Expected '$expected', got '$resp_msg'"));

          $ok = 1;
          last;
        }
      }

      close($fh);
      $self->assert($ok, "Did not see expected ExtendedLog lines");

    } else {
      die("Can't read $ext_log: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub extlog_ftp_raw_bytes_bug3554 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'response:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%{protocol} %m \"%S\" %I %O"',
    ExtendedLog => "$ext_log ALL custom",
    ServerIdent => 'on "FTP Server"',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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
      $client->type('ascii');

      my $conn = $client->stor_raw('test.txt');
      unless ($conn) {
        die("STOR test.txt failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "ABCD\n" x 8;
      $conn->write($buf, length($buf), 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $client->quit();

      $self->assert_transfer_ok($resp_code, $resp_msg);
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

  # Now, read in the ExtendedLog, and see whether the %I/%O variables
  # are properly populated
  if (open(my $fh, "< $ext_log")) {
    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /^\S+ (\S+) (.*?) (\d+) (\d+)$/) {
        my $cmd = $1;
        my $resp = $2;
        my $bytes_in = $3;
        my $bytes_out = $4;

        # Only watch for the QUIT command, to get the session total.
        next unless $cmd eq 'QUIT';

        my $expected = 108;
        $self->assert($expected == $bytes_in,
          test_msg("Expected $expected, got $bytes_in"));

        # Why would this number vary so widely?  It's because of the notation
        # used to express the port number in a PASV response.  That port
        # number is ephemeral, chosen by the kernel.

        my $expected_min = 232;
        my $expected_max = 236;
        $self->assert($expected_min <= $bytes_out &&
                      $expected_max >= $bytes_out,
          test_msg("Expected $expected_min - $expected_max, got $bytes_out"));
      }
    }

    close($fh);

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_ftp_sendfile_raw_bytes_bug3554 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "ABCD\n" x 8;
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
    TraceLog => $log_file,
    Trace => 'response:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%{protocol} %m \"%S\" %I %O"',
    ExtendedLog => "$ext_log ALL custom",
    ServerIdent => 'on "FTP Server"',

    UseSendfile => 'on',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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
      $client->type('binary');

      my $conn = $client->retr_raw('test.txt');
      unless ($conn) {
        die("RETR test.txt failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 16382, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $client->quit();

      $self->assert_transfer_ok($resp_code, $resp_msg); 
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

  # Now, read in the ExtendedLog, and see whether the %I/%O variables
  # are properly populated
  if (open(my $fh, "< $ext_log")) {
    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /^\S+ (\S+) (.*?) (\d+) (\d+)$/) {
        my $cmd = $1;
        my $resp = $2;
        my $bytes_in = $3;
        my $bytes_out = $4;

        # Only watch for the QUIT command, to get the session total.
        next unless $cmd eq 'QUIT';

        my $expected = 60;
        $self->assert($expected == $bytes_in,
          test_msg("Expected $expected, got $bytes_in"));

        # Why would this number vary so widely?  It's because of the notation
        # used to express the port number in a PASV response.  That port
        # number is ephemeral, chosen by the kernel.

        my $expected_min = 284;
        my $expected_max = 288;
        $self->assert($expected_min <= $bytes_out &&
                      $expected_max >= $bytes_out,
          test_msg("Expected $expected_min - $expected_max, got $bytes_out"));
      }
    }

    close($fh);

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_ftp_deflate_raw_bytes_bug3554 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 deflate:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutLinger => 1,

    LogFormat => 'custom "%{protocol} %m \"%S\" %I %O"',
    ExtendedLog => "$ext_log ALL custom",
    ServerIdent => 'on "FTP Server"',

    IfModules => {
      'mod_deflate.c' => {
        DeflateEngine => 'on',
        DeflateLog => $log_file,
      },

      'mod_delay.c' => {
        DelayEngine => 'off',
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
      $client->mode('Z');

      my $conn = $client->stor_raw('test.txt');
      unless ($conn) {
        die("STOR test.txt failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "ABCD\n" x 8;
      my $deflated = compress($buf);
      $conn->write($deflated, length($deflated), 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $client->quit();

      $self->assert_transfer_ok($resp_code, $resp_msg);
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

  # Now, read in the ExtendedLog, and see whether the %I/%O variables
  # are properly populated
  if (open(my $fh, "< $ext_log")) {
    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /^\S+ (\S+) (.*?) (\d+) (\d+)$/) {
        my $cmd = $1;
        my $resp = $2;
        my $bytes_in = $3;
        my $bytes_out = $4;

        # Only watch for the QUIT command, to get the session total.
        next unless $cmd eq 'QUIT';

        my $expected = 100;
        $self->assert($expected == $bytes_in,
          test_msg("Expected $expected, got $bytes_in"));

        # Why would this number vary so widely?  It's because of the notation
        # used to express the port number in a PASV response.  That port
        # number is ephemeral, chosen by the kernel.

        my $expected_min = 221;
        my $expected_max = 225;
        $self->assert($expected_min <= $bytes_out &&
                      $expected_max >= $bytes_out,
          test_msg("Expected $expected_min - $expected_max, got $bytes_out"));
      }
    }

    close($fh);

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_ftps_raw_bytes_bug3554 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $src_file = File::Spec->rel2abs("$tmpdir/src.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "ABCD\n" x 8192;
    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'response:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%{protocol} %m \"%S\" %I %O"',
    ExtendedLog => "$ext_log ALL custom",
    ServerIdent => 'on "FTP Server"',

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
        die("Can't set transfer mode to binary: " . $client->last_message());
      }

      unless ($client->put($src_file, 'test.txt')) {
        die("Can't upload '$src_file' to 'test.txt': " .
          $client->last_message());
      }

      $client->quit();

      unless (-f $test_file) {
        die("File $test_file does not exist as expected");
      }
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

  # Now, read in the ExtendedLog, and see whether the %I/%O variables
  # are properly populated
  if (open(my $fh, "< $ext_log")) {
    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /^\S+ (\S+) (.*?) (\d+) (\d+)$/) {
        my $cmd = $1;
        my $resp = $2;
        my $bytes_in = $3;
        my $bytes_out = $4;

        # Only watch for the QUIT command, to get the session total.
        next unless $cmd eq 'QUIT';

        # The expected bytes in/out will vary on the ciphers used, etc.
        my $expected_min = 42240;
        my $expected_max = 42378;
        $self->assert($expected_min <= $bytes_in &&
                      $expected_max >= $bytes_in,
          test_msg("Expected $expected_min - $expected_max, got $bytes_in"));

        $expected_min = 6828;
        $expected_max = 9140;
        $self->assert($expected_min <= $bytes_out &&
                      $expected_max >= $bytes_out,
          test_msg("Expected $expected_min - $expected_max, got $bytes_out"));
      }
    }

    close($fh);

  } else {
    die("Can't read $ext_log: $!");
  }

  unlink($log_file);
}

sub extlog_sftp_raw_bytes_bug3554 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 ssh2:20 sftp:20 scp:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%{protocol} %m \"%S\" %I %O"',
    ExtendedLog => "$ext_log ALL custom",
    ServerIdent => 'on "FTP Server"',

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

      unless ($ssh2->auth_password($user, $passwd)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $sftp = $ssh2->sftp();
      unless ($sftp) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't use SFTP on SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $fh = $sftp->open('test.txt', O_WRONLY|O_CREAT|O_TRUNC, 0644);
      unless ($fh) {
        my ($err_code, $err_name) = $sftp->error();
        die("Can't open test.txt: [$err_name] ($err_code)");
      }

      print $fh "ABCD\n" x 8192;

      # To issue the FXP_CLOSE, we have to explicitly destroy the filehandle
      $fh = undef;

      # To issue the CHANNEL_CLOSE, we have to explicitly destroy the sftp
      # object.  Sigh.
      $sftp = undef;

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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  # Now, read in the ExtendedLog, and see whether the %I/%O variables
  # are properly populated
  if (open(my $fh, "< $ext_log")) {
    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /^\S+ (\S+) (.*?) (\d+) (\d+)$/) {
        my $cmd = $1;
        my $resp = $2;
        my $bytes_in = $3;
        my $bytes_out = $4;

        # Only watch for the CHANNEL_CLOSE command, to get the session total.
        next unless $cmd eq 'CHANNEL_CLOSE';

        # The expected bytes in/out will vary on the ciphers used, etc.
        my $expected_min = 34147;
        my $expected_max = 34147;
        $self->assert($expected_min <= $bytes_in &&
                      $expected_max >= $bytes_in,
          test_msg("Expected $expected_min - $expected_max, got $bytes_in"));

        $expected_min = 2116;
        $expected_max = 2196;
        $self->assert($expected_min <= $bytes_out &&
                      $expected_max >= $bytes_out,
          test_msg("Expected $expected_min - $expected_max, got $bytes_out"));
      }
    }

    close($fh);

  } else {
    die("Can't read $ext_log: $!");
  }

  unlink($log_file);
}

sub extlog_scp_raw_bytes_bug3554 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $src_file = File::Spec->rel2abs("$tmpdir/src.txt");
  if (open(my $fh, "> $src_file")) {
    print $fh "ABCD\n" x 8192;
    unless (close($fh)) {
      die("Can't write $src_file: $!");
    }

  } else {
    die("Can't open $src_file: $!");
  }

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 ssh2:20 sftp:20 scp:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%{protocol} %m \"%S\" %I %O"',
    ExtendedLog => "$ext_log ALL custom",
    ServerIdent => 'on "FTP Server"',

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

      unless ($ssh2->auth_password($user, $passwd)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $res = $ssh2->scp_put($src_file, 'test.txt');
      unless ($res) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't upload $src_file to server: [$err_name] ($err_code) $err_str");
      }

      $ssh2->disconnect();

      unless (-f $test_file) {
        die("File $test_file does not exist as expected");
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

  # Now, read in the ExtendedLog, and see whether the %I/%O variables
  # are properly populated
  if (open(my $fh, "< $ext_log")) {
    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /^\S+ (\S+) (.*?) (\d+) (\d+)$/) {
        my $cmd = $1;
        my $resp = $2;
        my $bytes_in = $3;
        my $bytes_out = $4;

        # Only watch for the CHANNEL_CLOSE command, to get the session total.
        next unless $cmd eq 'CHANNEL_CLOSE';

        # The expected bytes in/out will vary on the ciphers used, etc.
        my $expected_min = 42787;
        my $expected_max = 42787;
        $self->assert($expected_min <= $bytes_in &&
                      $expected_max >= $bytes_in,
          test_msg("Expected $expected_min - $expected_max, got $bytes_in"));

        $expected_min = 1996;
        $expected_max = 2036;
        $self->assert($expected_min <= $bytes_out &&
                      $expected_max >= $bytes_out,
          test_msg("Expected $expected_min - $expected_max, got $bytes_out"));
      }
    }

    close($fh);

  } else {
    die("Can't read $ext_log: $!");
  }

  unlink($log_file);
}

sub extlog_exit_bug3559 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'extlog');

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'jot:20 response:10',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    LogFormat => 'custom "%{protocol} %L %m \"%S\" %I %O"',
    ExtendedLog => "$ext_log EXIT custom",

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($setup->{user}, $setup->{passwd});
      $client->type('ascii');

      my $conn = $client->stor_raw('test.txt');
      unless ($conn) {
        die("STOR test.txt failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "ABCD\n" x 8;
      $conn->write($buf, length($buf), 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $client->quit();

      $self->assert_transfer_ok($resp_code, $resp_msg);
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

  # Now, read in the ExtendedLog, and see whether the %I/%O variables
  # are properly populated
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $ok = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "# ExtendedLog: $line\n";
        }

        if ($line =~ /^\S+ (\S+) (\S+) (.*?) (\d+) (\d+)$/) {
          my $local_addr = $1;
          my $cmd = $2;
          my $resp = $3;
          my $bytes_in = $4;
          my $bytes_out = $5;

          # Only watch for the EXIT command, to get the session total.
          next unless $cmd eq 'EXIT';

          my $expected = '127.0.0.1';
          $self->assert($expected eq $local_addr,
            "Expected %L value $expected, got $local_addr");

          $expected = 108;
          $self->assert($expected == $bytes_in,
            "Expected $expected, got $bytes_in");

          # Why would this number vary so widely?  It's because of the notation
          # used to express the port number in a PASV response.  That port
          # number is ephemeral, chosen by the kernel.

          my $expected_min = 232;
          my $expected_max = 286;
          $self->assert($expected_min <= $bytes_out &&
                        $expected_max >= $bytes_out,
            "Expected $expected_min - $expected_max, got $bytes_out");

          $ok = 1;
        }
      }

      close($fh);
      $self->assert($ok == 1, "Did not find expected ExtendedLog lines");

    } else {
      die("Can't read $ext_log: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub extlog_eos_reason_quit {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%{protocol} %m eos_reason=\"%E\""',
    ExtendedLog => "$ext_log EXIT custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

  # Now, read in the ExtendedLog, and see whether the %I/%O variables
  # are properly populated
  if (open(my $fh, "< $ext_log")) {
    my $ok = 0;

    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /^\S+ (\S+) eos_reason="(.*?)"/) {
        my $cmd = $1;
        my $reason = $2;

        # Only watch for the EXIT command, to get the end-of-session reason.
        next unless $cmd eq 'EXIT';

        my $expected = "Quit";
        $self->assert($expected eq $reason,
          test_msg("Expected '$expected', got '$reason'"));

        $ok = 1;
      }
    }

    close($fh);
    $self->assert($ok == 1,
      test_msg("Did not find expected ExtendedLog lines"));

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_eos_reason_eof {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%{protocol} %m eos_reason=\"%E\""',
    ExtendedLog => "$ext_log EXIT custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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
      $client = undef;
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

  # Now, read in the ExtendedLog, and see whether the %I/%O variables
  # are properly populated
  if (open(my $fh, "< $ext_log")) {
    my $ok = 0;

    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /^\S+ (\S+) eos_reason="(.*?)"/) {
        my $cmd = $1;
        my $reason = $2;

        # Only watch for the EXIT command, to get the end-of-session reason.
        next unless $cmd eq 'EXIT';

        my $expected = "Read EOF from client";
        $self->assert($expected eq $reason,
          test_msg("Expected '$expected', got '$reason'"));

        $ok = 1;
      }
    }

    close($fh);
    $self->assert($ok == 1,
      test_msg("Did not find expected ExtendedLog lines"));

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_eos_reason_timeoutidle {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $timeout_idle = 3;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%{protocol} %m eos_reason=\"%E\""',
    ExtendedLog => "$ext_log EXIT custom",
    TimeoutIdle => $timeout_idle,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      sleep($timeout_idle + 2);

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

  # Now, read in the ExtendedLog, and see whether the %I/%O variables
  # are properly populated
  if (open(my $fh, "< $ext_log")) {
    my $ok = 0;

    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /^\S+ (\S+) eos_reason="(.*?)"/) {
        my $cmd = $1;
        my $reason = $2;

        # Only watch for the EXIT command, to get the end-of-session reason.
        next unless $cmd eq 'EXIT';

        my $expected = "Timeout exceeded: TimeoutIdle";
        $self->assert($expected eq $reason,
          test_msg("Expected '$expected', got '$reason'"));

        $ok = 1;
      }
    }

    close($fh);
    $self->assert($ok == 1,
      test_msg("Did not find expected ExtendedLog lines"));

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_eos_reason_timeoutlogin {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $timeout_login = 3;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%{protocol} %m eos_reason=\"%E\""',
    ExtendedLog => "$ext_log EXIT custom",
    TimeoutLogin => $timeout_login,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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
      sleep($timeout_login + 2);

      eval { $client->login($user, $passwd) };
      unless ($@) {
        die("Login succeeded unexpectedly");
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

  # Now, read in the ExtendedLog, and see whether the %I/%O variables
  # are properly populated
  if (open(my $fh, "< $ext_log")) {
    my $ok = 0;

    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /^\S+ (\S+) eos_reason="(.*?)"/) {
        my $cmd = $1;
        my $reason = $2;

        # Only watch for the EXIT command, to get the end-of-session reason.
        next unless $cmd eq 'EXIT';

        my $expected = "Timeout exceeded: TimeoutLogin";
        $self->assert($expected eq $reason,
          test_msg("Expected '$expected', got '$reason'"));

        $ok = 1;
      }
    }

    close($fh);
    $self->assert($ok == 1,
      test_msg("Did not find expected ExtendedLog lines"));

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_eos_reason_timeoutnotransfer {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $timeout_noxfer = 2;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%{protocol} %m eos_reason=\"%E\""',
    ExtendedLog => "$ext_log EXIT custom",
    TimeoutNoTransfer => $timeout_noxfer,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      # Wait for one second more than the no-transfer period
      sleep($timeout_noxfer + 1);

      my $conn = $client->list_raw($home_dir);
      if ($conn) {
        die("LIST succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 421;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "No transfer timeout ($timeout_noxfer seconds): closing control connection";
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

  # Now, read in the ExtendedLog, and see whether the %I/%O variables
  # are properly populated
  if (open(my $fh, "< $ext_log")) {
    my $ok = 0;

    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /^\S+ (\S+) eos_reason="(.*?)"/) {
        my $cmd = $1;
        my $reason = $2;

        # Only watch for the EXIT command, to get the end-of-session reason.
        next unless $cmd eq 'EXIT';

        my $expected = "Timeout exceeded: TimeoutNoTransfer";
        $self->assert($expected eq $reason,
          test_msg("Expected '$expected', got '$reason'"));

        $ok = 1;
      }
    }

    close($fh);
    $self->assert($ok == 1,
      test_msg("Did not find expected ExtendedLog lines"));

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_eos_reason_timeoutsession {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $timeout_session = 2;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%{protocol} %m eos_reason=\"%E\""',
    ExtendedLog => "$ext_log EXIT custom",
    TimeoutSession => $timeout_session,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      # Wait for one second more than the session lifetime
      sleep($timeout_session + 1);

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

  # Now, read in the ExtendedLog, and see whether the %I/%O variables
  # are properly populated
  if (open(my $fh, "< $ext_log")) {
    my $ok = 0;

    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /^\S+ (\S+) eos_reason="(.*?)"/) {
        my $cmd = $1;
        my $reason = $2;

        # Only watch for the EXIT command, to get the end-of-session reason.
        next unless $cmd eq 'EXIT';

        my $expected = "Timeout exceeded: TimeoutSession";
        $self->assert($expected eq $reason,
          test_msg("Expected '$expected', got '$reason'"));

        $ok = 1;
      }
    }

    close($fh);
    $self->assert($ok == 1,
      test_msg("Did not find expected ExtendedLog lines"));

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_eos_reason_timeoutstalled {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $timeout_stalled = 1;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'response:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%{protocol} %m eos_reason=\"%E\""',
    ExtendedLog => "$ext_log EXIT custom",
    TimeoutStalled => $timeout_stalled,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      my $conn = $client->list_raw($home_dir);
      unless ($conn) {
        die("LIST failed: " . $client->response_code() . " " .
          $client->response_msg());
      }

      # Wait for one second more than the stalled period
      sleep($timeout_stalled + 1);

      my $buf;
      $conn->read($buf, 8192, 25);
      eval { $conn->close() };

      eval { $client->noop() };
      unless ($@) {
        die("NOOP succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      # Perl's Net::Cmd module uses a very non-standard 599 code to
      # indicate that the connection is closed
      $expected = 599;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Connection closed";
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

  # Now, read in the ExtendedLog, and see whether the %I/%O variables
  # are properly populated
  if (open(my $fh, "< $ext_log")) {
    my $ok = 0;

    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /^\S+ (\S+) eos_reason="(.*?)"/) {
        my $cmd = $1;
        my $reason = $2;

        # Only watch for the EXIT command, to get the end-of-session reason.
        next unless $cmd eq 'EXIT';

        my $expected = "TimeoutStalled during data transfer";
        $self->assert(qr/$expected/, $reason,
          test_msg("Expected failure reason '$expected', got '$reason'"));

        $ok = 1;
      }
    }

    close($fh);
    $self->assert($ok == 1,
      test_msg("Did not find expected ExtendedLog lines"));

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_vars_H_L_matching_server_bug3620 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%L %H"',
    ExtendedLog => "$ext_log AUTH custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

  # Now, read in the ExtendedLog, and see what values the %L and %H
  # variables have.
  if (open(my $fh, "< $ext_log")) {
    my $ok = 0;

    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /^(\S+)\s+(\S+)$/) {
        my $conn_addr = $1;
        my $sess_server_addr = $2;

        $self->assert($conn_addr eq '127.0.0.1',
          test_msg("Expected %L value of '127.0.0.1', got '$conn_addr'"));

        $self->assert($sess_server_addr eq '127.0.0.1',
          test_msg("Expected %H value of '127.0.0.1', got '$sess_server_addr'"));

        $ok = 1;
      }
    }

    close($fh);

    $self->assert($ok, test_msg("Expected ExtendedLog lines not found"));

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_vars_H_L_default_server_bug3620 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'extlog');

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    DefaultServer => 'off',
    SocketBindTight => 'off',
    LogFormat => 'custom "%L %H"',
    ExtendedLog => "$ext_log AUTH custom",
    Port => '0',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($setup->{config_file},
    $config);

  my $sysaddr = Sys::HostAddr->new();
  my $real_addr = $sysaddr->main_ip();
  my $real_port = ProFTPD::TestSuite::Utils::get_high_numbered_port();
  my $vhost_addr = '0.0.0.0';

  if (open(my $fh, ">> $setup->{config_file}")) {
    print $fh <<EOC;

<VirtualHost $vhost_addr>
  ServerName "DefaultServer VHost"
  Port $real_port
  DefaultServer on

  AuthUserFile $setup->{auth_user_file}
  AuthGroupFile $setup->{auth_group_file}
  RequireValidShell off
  WtmpLog off

  ExtendedLog $ext_log AUTH custom
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

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new($real_addr, $real_port);
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

  eval {
    # Now, read in the ExtendedLog, and see what values the %L and %H
    # variables have.
    if (open(my $fh, "< $ext_log")) {
      my $ok = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($line =~ /^(\S+)\s+(\S+)$/) {
          my $conn_addr = $1;
          my $sess_server_addr = $2;

          $self->assert($conn_addr eq $real_addr,
            "Expected %L value of '$real_addr', got '$conn_addr'");

          $self->assert($sess_server_addr eq $vhost_addr,
            "Expected %H value of '$vhost_addr', got '$sess_server_addr'");

          $ok = 1;
        }
      }

      close($fh);
      $self->assert($ok, "Expected ExtendedLog lines not found");

    } else {
      die("Can't read $ext_log: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub extlog_user_pass {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%m: %U %A"',
    ExtendedLog => "$ext_log AUTH custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

  # Now, read in the ExtendedLog, and see whether the %U and %A variables were
  # properly written out.
  if (open(my $fh, "< $ext_log")) {
    my $ok = 0;

    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /(\S+): (\S+) (\S+)$/) {
        my $cmd = $1;
        my $log_user = $2;
        my $log_pass = $3;

        if ($cmd eq 'PASS') {
          $self->assert($user eq $log_user,
            test_msg("Expected '$user', got '$log_user'"));

          my $expected = 'UNKNOWN';
          $self->assert($expected eq $log_pass,
            test_msg("Expected '$expected', got '$log_pass'"));

          $ok = 1;
        }
      }
    }

    close($fh);

    $self->assert($ok, test_msg("Expected ExtendedLog lines not found"));

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_anon_user_pass {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

  my ($config_user, $config_group) = config_get_identity();
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

  auth_user_write($auth_user_file, $config_user, 'foo', $uid, $gid, '/tmp',
    '/bin/bash');
  auth_group_write($auth_group_file, $config_group, $gid, $config_user);

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%m: %U %A"',
    ExtendedLog => "$ext_log AUTH custom",

    Anonymous => {
      $home_dir => {
        User => $config_user,
        Group => $config_group,
        UserAlias => "anonymous $config_user",
        RequireValidShell => 'off',
      },
    },

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $user, $group) = config_write($config_file, $config);

  # Open pipes, for use between the parent and child processes.  Specifically,
  # the child will indicate when it's done with its test by writing a message
  # to the parent.
  my ($rfh, $wfh);
  unless (pipe($rfh, $wfh)) {
    die("Can't open pipe: $!");
  }

  my $ex;

  my $anon_user = 'anonymous';
  my $anon_passwd = 'ftp@nospam.org';

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      my ($resp_code, $resp_msg) = $client->login($anon_user, $anon_passwd);

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

  # Now, read in the ExtendedLog, and see whether the %U and %A variables were
  # properly written out.
  if (open(my $fh, "< $ext_log")) {
    my $ok = 0;

    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /(\S+): (\S+) (\S+)$/) {
        my $cmd = $1;
        my $log_user = $2;
        my $log_pass = $3;

        if ($cmd eq 'PASS') {
          $self->assert($anon_user eq $log_user,
            test_msg("Expected '$anon_user', got '$log_user'"));

          $self->assert($anon_passwd eq $log_pass,
            test_msg("Expected '$anon_passwd', got '$log_pass'"));

          $ok = 1;
        }
      }
    }

    close($fh);

    $self->assert($ok, test_msg("Expected ExtendedLog lines not found"));

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_cmd_resp {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%m %J [%r] = %s %S"',
    ExtendedLog => "$ext_log ALL custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 25);
      eval { $conn->close() };

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

  if (open(my $fh, "< $ext_log")) {
    my $ok = 0;

    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /(\S+) (\S+) \[(.*?)\] = (\d+) (.*?)$/) {
        my $cmd = $1;
        my $cmd_args = $2;
        my $full_cmd = $3;
        my $resp_code = $4;
        my $resp_msg = $5;

        my $expected = "$cmd $cmd_args";
        $self->assert($expected eq $full_cmd,
          test_msg("Expected '$expected', got '$full_cmd'"));

        $ok = 1;
      }
    }

    close($fh);

    $self->assert($ok, test_msg("Expected ExtendedLog lines not found"));

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_xfer_timeout_bug3696 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs("$tmpdir/foo.txt");

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

  my $timeout_stalled = 2;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%f"',
    ExtendedLog => "$ext_log WRITE custom",

    TimeoutStalled => $timeout_stalled,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      my $conn = $client->stor_raw('foo.txt');
      unless ($conn) {
        die("Failed to STOR foo.txt: " . $client->response_code() . " " .
          $client->response_msg());
      }

      # Wait for longer than the TimeoutStalled limit
      sleep($timeout_stalled + 2);

      eval {
        my $buf = "Foo!\n";
        $conn->write($buf, length($buf));
        eval { $conn->close() };

        $client->quit();
      };
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

  # Now, read in the ExtendedLog, and see whether the %f variable was
  # properly written out.  Bug#3696 occurred because mod_log would not
  # properly notice that a data transfer was in progress when the
  # session was disconnected due to hitting TimeoutStalled.
  # information.
  if (open(my $fh, "< $ext_log")) {
    my $line = <$fh>;
    chomp($line);
    close($fh);

    if ($^O eq 'darwin') {
      # MacOSX-specific hack
      $test_file = '/private' . $test_file;
    }

    $self->assert($test_file eq $line,
      test_msg("Expected '$test_file', got '$line'"));

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_sftp_xfer_timeout_bug3696 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  my $timeout_stalled = 2;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 ssh2:20 sftp:20 scp:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%f"',
    ExtendedLog => "$ext_log WRITE custom",

    TimeoutStalled => $timeout_stalled,

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

      unless ($ssh2->auth_password($user, $passwd)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $sftp = $ssh2->sftp();
      unless ($sftp) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't use SFTP on SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $fh = $sftp->open('test.txt', O_WRONLY|O_CREAT|O_TRUNC, 0644);
      unless ($fh) {
        my ($err_code, $err_name) = $sftp->error();
        die("Can't open test.txt: [$err_name] ($err_code)");
      }

      print $fh "ABCD\n" x 8;

      # Wait for longer than the TimeoutStalled limit
      sleep($timeout_stalled + 2);

      # To issue the FXP_CLOSE, we have to explicitly destroy the filehandle
      $fh = undef;

      # To issue the CHANNEL_CLOSE, we have to explicitly destroy the sftp
      # object.  Sigh.
      $sftp = undef;

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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  # Now, read in the ExtendedLog, and see whether the %f variable was
  # properly written out.  Bug#3696 occurred because mod_log would not
  # properly notice that a data transfer was in progress when the
  # session was disconnected due to hitting TimeoutStalled.
  # information.
  if (open(my $fh, "< $ext_log")) {
    my $line = <$fh>;
    chomp($line);
    close($fh);

    if ($^O eq 'darwin') {
      # MacOSX-specific hack
      $test_file = '/private' . $test_file;
    }

    $self->assert($test_file eq $line,
      test_msg("Expected '$test_file', got '$line'"));

  } else {
    die("Can't read $ext_log: $!");
  }

  unlink($log_file);
}

sub extlog_var_r {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'response:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%r"',
    ExtendedLog => "$ext_log ALL custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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
      eval { $client->site('CHMOD', '777', 'test.txt') };
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

  # Now, read in the ExtendedLog, and see whether the %s variable was
  # properly written out for the PASS command.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $user_ok = 0;
      my $pass_ok = 0;
      my $site_ok = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($line =~ /^(.*?)$/) {
          my $cmd = $1;

          if ($cmd eq "USER $user") {
            $user_ok = 1;
            next;
          }

          if ($cmd eq 'PASS (hidden)') {
            $pass_ok = 1;
            next;
          }

          if ($cmd eq 'SITE CHMOD 777 test.txt') {
            $site_ok = 1;
            next;
          }
        }
      }

      close($fh);

      $self->assert($user_ok,
        test_msg("Did not see expected USER command in $ext_log"));
      $self->assert($pass_ok,
        test_msg("Did not see expected PASS command in $ext_log"));
      $self->assert($site_ok,
        test_msg("Did not see expected SITE command in $ext_log"));

    } else {
      die("Can't read $ext_log: $!");
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

sub extlog_pass_var_r {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'response:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%r"',
    ExtendedLog => "$ext_log AUTH custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

  # Now, read in the ExtendedLog, and see whether the %s variable was
  # properly written out for the PASS command.
  if (open(my $fh, "< $ext_log")) {
    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /^(\S+) (\S+)$/) {
        my $cmd = $1;
        my $args = $2;

        next unless $cmd eq 'PASS';

        my $expected = '(hidden)';
        $self->assert($expected eq $args,
          test_msg("Expected '$expected', got '$args'"));

        last;
      }
    }

    close($fh);

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_sftp_pass_var_r {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 ssh2:20 sftp:20 scp:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%r"',
    ExtendedLog => "$ext_log AUTH custom",

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

      unless ($ssh2->auth_password($user, $passwd)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $sftp = $ssh2->sftp();
      unless ($sftp) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't use SFTP on SSH2 server: [$err_name] ($err_code) $err_str");
      }

      # To issue the CHANNEL_CLOSE, we have to explicitly destroy the sftp
      # object.  Sigh.
      $sftp = undef;

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

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  # Now, read in the ExtendedLog, and see whether the %I/%O variables
  # are properly populated
  if (open(my $fh, "< $ext_log")) {
    my $ok = 0;

    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /^(\S+) (.*?)$/) {
        my $cmd = $1;
        my $args = $2;

        next unless $cmd eq 'PASS';

        my $expected = '(hidden)';
        $self->assert($expected eq $args,
          test_msg("Expected '$expected', got '$args'"));
        $ok = 1;
        last;
      }
    }

    close($fh);

    $self->assert($ok,
      test_msg("ExtendedLog did not contain expected message"));

  } else {
    die("Can't read $ext_log: $!");
  }

  unlink($log_file);
}

sub extlog_sftp_retr_var_s_bug3948 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    my $count = 20;
    for (my $i = 0; $i < $count; $i++) {
      print $fh "ABCD" x 8192;
    }

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
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 ssh2:20 sftp:20 scp:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%m %s"',
    ExtendedLog => "$ext_log READ custom",

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

      unless ($ssh2->auth_password($user, $passwd)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $sftp = $ssh2->sftp();
      unless ($sftp) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't use SFTP on SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $fh = $sftp->open('test.txt', O_RDONLY);
      unless ($fh) {
        my ($err_code, $err_name) = $sftp->error();
        die("Can't open test.txt: [$err_name] ($err_code)");
      }

      my $buf;
      my $size = 0;

      my $res = $fh->read($buf, 8192);
      while ($res) {
        $size += $res;

        $res = $fh->read($buf, 8192);
      }

      # To issue the FXP_CLOSE, we have to explicitly destroy the filehandle
      $fh = undef;

      # To close the SFTP channel, we have to explicitly destroy the object
      $sftp = undef;

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

  eval {
    if (open(my $fh, "< $ext_log")) {
      my $ok = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($line =~ /^(\S+) (.*?)$/) {
          my $cmd = $1;
          my $status = $2;

          next unless $cmd eq 'RETR';

          my $expected = '226';
          $self->assert($expected eq $status,
            test_msg("Expected response code '$expected', got '$status'"));
          $ok = 1;
          last;
       }
      }

      close($fh);

      $self->assert($ok,
        test_msg("ExtendedLog did not contain expected message"));

    } else {
      die("Can't read $ext_log: $!");
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

sub extlog_sftp_stor_var_s_bug3948 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 ssh2:20 sftp:20 scp:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    AllowOverwrite => 'on',
    LogFormat => 'custom "%m %s"',
    ExtendedLog => "$ext_log WRITE custom",

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

      unless ($ssh2->auth_password($user, $passwd)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $sftp = $ssh2->sftp();
      unless ($sftp) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't use SFTP on SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $fh = $sftp->open('test.txt', O_WRONLY|O_CREAT|O_TRUNC, 0644);
      unless ($fh) {
        my ($err_code, $err_name) = $sftp->error();
        die("Can't open test.txt: [$err_name] ($err_code)");
      }

      my $count = 20;
      for (my $i = 0; $i < $count; $i++) {
        print $fh "ABCD" x 8192;
      }

      # To issue the FXP_CLOSE, we have to explicitly destroy the filehandle
      $fh = undef;

      # To close the SFTP channel, we have to explicitly destroy the object
      $sftp = undef;

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

  eval {
    if (open(my $fh, "< $ext_log")) {
      my $ok = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($line =~ /^(\S+) (.*?)$/) {
          my $cmd = $1;
          my $status = $2;

          next unless $cmd eq 'STOR';

          my $expected = '226';
          $self->assert($expected eq $status,
            test_msg("Expected response code '$expected', got '$status'"));
          $ok = 1;
          last;
       }
      }

      close($fh);

      $self->assert($ok,
        test_msg("ExtendedLog did not contain expected message"));

    } else {
      die("Can't read $ext_log: $!");
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

sub extlog_abor {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "A" x 1024;

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

    LogFormat => 'custom "%m"',
    ExtendedLog => "$ext_log ALL custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 32, 30);
      eval { $conn->abort() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Abort successful";
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

  # Now, read in the ExtendedLog, and see whether the %m variable was
  # properly written out for the ABOR command.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $saw_abor = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($line eq 'ABOR') {
          $saw_abor = 1;
          last;
        }
      }

      close($fh);

      $self->assert($saw_abor,
        test_msg("Expected to see ABOR in ExtendedLog, did not"));

    } else {
      die("Can't read $ext_log: $!");
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

sub extlog_xfer_status_nonxfer {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "A" x 1024;

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

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
LogFormat custom "%m %{transfer-status}"
ExtendedLog $ext_log ALL custom
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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);
      $client->pwd();
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

  # Now, read in the ExtendedLog, and see whether the %{transfer-status}
  # variable was properly written out.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $unexpected_xfer_status = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($line =~ /^(\S+) (.*)?$/) {
          my $cmd = $1;
          my $xfer_status = $2;

          if ($xfer_status ne '-') {
            $unexpected_xfer_status = 1;
            last;
          }
        }
      }

      close($fh);

      $self->assert(!$unexpected_xfer_status,
        test_msg("Saw unexpected transfer status in ExtendedLog"));

    } else {
      die("Can't read $ext_log: $!");
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

sub extlog_xfer_status_success {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "A" x 1024;

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

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
LogFormat custom "%m %{transfer-status}"
ExtendedLog $ext_log ALL custom
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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);

      my $conn = $client->retr_raw('test.txt');
      unless ($conn) {
        die("RETR test.txt failed: " . $client->response_code() . " " .
          $client->response_code());
      }

      my $buf;
      while ($conn->read($buf, 16382, 25)) {
      }
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      $self->assert_transfer_ok($resp_code, $resp_msg);
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

  # Now, read in the ExtendedLog, and see whether the %{transfer-status}
  # variable was properly written out.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $expected_xfer_status = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($line =~ /^(\S+) (.*)?$/) {
          my $cmd = $1;
          my $xfer_status = $2;

          if ($cmd eq 'RETR') {
            if ($xfer_status eq 'success') {
              $expected_xfer_status = 1;
              last;
            }
          }
        }
      }

      close($fh);

      $self->assert($expected_xfer_status,
        test_msg("Did not see expected transfer status in ExtendedLog"));

    } else {
      die("Can't read $ext_log: $!");
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

sub extlog_xfer_status_cancelled {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "ABCDefgh" x 32768;

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

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
LogFormat custom "%m %{transfer-status}"
ExtendedLog $ext_log ALL custom
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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);

      my $conn = $client->retr_raw('test.txt');
      unless ($conn) {
        die("RETR test.txt failed: " . $client->response_code() . " " .
          $client->response_code());
      }

      my $buf;
      $conn->read($buf, 12, 25);
      eval { $conn->abort() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      $self->assert_transfer_ok($resp_code, $resp_msg, 1);
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

  # Now, read in the ExtendedLog, and see whether the %{transfer-status}
  # variable was properly written out.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $expected_xfer_status = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($line =~ /^(\S+) (.*)?$/) {
          my $cmd = $1;
          my $xfer_status = $2;

          if ($cmd eq 'RETR') {
            if ($xfer_status eq 'cancelled') {
              $expected_xfer_status = 1;
              last;
            }
          }
        }
      }

      close($fh);

      $self->assert($expected_xfer_status,
        test_msg("Did not see expected transfer status in ExtendedLog"));

    } else {
      die("Can't read $ext_log: $!");
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

sub extlog_xfer_status_failed {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "ABCDefgh" x 32768;

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

    # This is used to trigger a download failure
    MaxRetrieveFileSize => '12 B',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
LogFormat custom "%m %{transfer-status}"
ExtendedLog $ext_log ALL custom
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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);

      my $conn = $client->retr_raw('test.txt');
      unless ($conn) {
        die("RETR test.txt failed: " . $client->response_code() . " " .
          $client->response_code());
      }

      my $buf;
      $conn->read($buf, 12, 25);
      eval { $conn->abort() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected = 426;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'Transfer aborted';
      $self->assert(qr/$expected/, $resp_msg,
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

  # Now, read in the ExtendedLog, and see whether the %{transfer-status}
  # variable was properly written out.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $expected_xfer_status = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($line =~ /^(\S+) (.*)?$/) {
          my $cmd = $1;
          my $xfer_status = $2;

          if ($cmd eq 'RETR') {
            if ($xfer_status eq 'failed') {
              $expected_xfer_status = 1;
              last;
            }
          }
        }
      }

      close($fh);

      $self->assert($expected_xfer_status,
        test_msg("Did not see expected transfer status in ExtendedLog"));

    } else {
      die("Can't read $ext_log: $!");
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

sub extlog_xfer_status_timeout {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "ABCDefghIJKLmnop" x 65536;

    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $timeout_stalled = 1;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    # This is used to tickle the "timeout" transfer status
    TimeoutStalled => $timeout_stalled,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
LogFormat custom "%m %{transfer-status}"
ExtendedLog $ext_log READ custom
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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);
      $client->type('ascii');

      my $conn = $client->retr_raw('test.txt');
      unless ($conn) {
        die("RETR test.txt failed: " . $client->response_code() . " " .
          $client->response_code());
      }

      sleep($timeout_stalled + 1);

      my $buf;
      $conn->read($buf, 32, 25);
      sleep($timeout_stalled);
      eval { $conn->close() };

      eval { $client->noop() };
      unless ($@) {
        die("NOOP succeeded unexpectedly");
      }

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected;

      # Perl's Net::Cmd module uses a very non-standard 599 code to
      # indicate that the connection is closed
      $expected = 599;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = "Connection closed";
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

  # Now, read in the ExtendedLog, and see whether the %{transfer-status}
  # variable was properly written out.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $expected_xfer_status = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($line =~ /^(\S+) (.*)?$/) {
          my $cmd = $1;
          my $xfer_status = $2;

          if ($cmd eq 'RETR') {
            if ($xfer_status eq 'timeout') {
              $expected_xfer_status = 1;
              last;
            }
          }
        }
      }

      close($fh);

      $self->assert($expected_xfer_status,
        test_msg("Did not see expected transfer status in ExtendedLog"));

    } else {
      die("Can't read $ext_log: $!");
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

sub extlog_xfer_failure_none {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "A" x 1024;

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

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
LogFormat custom "%m %{transfer-failure}"
ExtendedLog $ext_log ALL custom
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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);

      my $conn = $client->retr_raw('test.txt');
      unless ($conn) {
        die("RETR test.txt failed: " . $client->response_code() . " " .
          $client->response_code());
      }

      my $buf;
      while ($conn->read($buf, 16382, 25)) {
      }
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      $self->assert_transfer_ok($resp_code, $resp_msg);
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

  # Now, read in the ExtendedLog, and see whether the %{transfer-failure}
  # variable was properly written out.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $unexpected_xfer_failure = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($line =~ /^(\S+) (.*)?$/) {
          my $cmd = $1;
          my $xfer_failure = $2;

          if ($xfer_failure ne '-') {
            $unexpected_xfer_failure = 1;
            last;
          }
        }
      }

      close($fh);

      $self->assert(!$unexpected_xfer_failure,
        test_msg("Saw unexpected transfer failure/reason in ExtendedLog"));

    } else {
      die("Can't read $ext_log: $!");
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

sub extlog_xfer_failure_reason {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "ABCDefgh" x 32768;

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

    # This is used to trigger a download failure
    MaxRetrieveFileSize => '12 B',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
LogFormat custom "%m %{transfer-failure}"
ExtendedLog $ext_log ALL custom
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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($user, $passwd);

      my $conn = $client->retr_raw('test.txt');
      unless ($conn) {
        die("RETR test.txt failed: " . $client->response_code() . " " .
          $client->response_code());
      }

      my $buf;
      $conn->read($buf, 12, 25);
      eval { $conn->abort() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();

      my $expected = 426;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = 'Transfer aborted';
      $self->assert(qr/$expected/, $resp_msg,
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

  # Now, read in the ExtendedLog, and see whether the %{transfer-failure}
  # variable was properly written out.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $expected_xfer_reason = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($line =~ /^(\S+) (.*)?$/) {
          my $cmd = $1;
          my $xfer_failure = $2;

          if ($cmd eq 'RETR') {
            if ($xfer_failure eq 'Operation not permitted') {
              $expected_xfer_reason = 1;
              last;
            }
          }
        }
      }

      close($fh);

      $self->assert($expected_xfer_reason,
        test_msg("Did not see expected transfer failure/reason in ExtendedLog"));

    } else {
      die("Can't read $ext_log: $!");
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

sub ftps_data_xfer_cancelled_cb {
  my $func_name = shift;
  my $data = shift;
  my $data_len = shift;
  my $total_len = shift;
  my $user_data = shift;

  if ($total_len > 0) {
    $user_data->close();
    die("$func_name failed due to test callback (len $total_len > 0)");
  }
}

sub ftps_data_close_db {
  my $func_name = shift;
  my $data = shift;
  my $data_len = shift;
  my $total_len = shift;
  my $user_data = shift;

  return undef;
}

sub extlog_ftps_xfer_status_cancelled {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "ABCDefgh" x 32768;

    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $timeout_idle = 20;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 data:20 tls:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,

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

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
LogFormat custom "%m %{transfer-status}"
ExtendedLog $ext_log ALL custom
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
        Croak => 1,
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

      $client->set_callback(\&ftps_data_xfer_cancelled_cb, \&ftps_data_close_cb, $client);

      unless ($client->get('test.txt', '/dev/null')) {
        die("Can't download 'test.txt': " .  $client->last_message());
      }

      $client->quit();

      unless (-f $test_file) {
        die("File $test_file does not exist as expected");
      }
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 3) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  # Stop server
  server_stop($pid_file);

  $self->assert_child_ok($pid);

  # Now, read in the ExtendedLog, and see whether the %{transfer-status}
  # variable was properly written out.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $expected_xfer_status = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "$line\n";
        }

        if ($line =~ /^(\S+) (.*)?$/) {
          my $cmd = $1;
          my $xfer_status = $2;

          if ($cmd eq 'RETR') {
            if ($xfer_status eq 'cancelled' ||
                $xfer_status eq 'failed') {
              $expected_xfer_status = 1;
              last;
            }
          }
        }
      }

      close($fh);

      $self->assert($expected_xfer_status,
        test_msg("Did not see expected transfer status in ExtendedLog"));

    } else {
      die("Can't read $ext_log: $!");
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

sub ftps_data_xfer_failed_cb {
  my $func_name = shift;
  my $data = shift;
  my $data_len = shift;
  my $total_len = shift;
  my $user_data = shift;

  if ($total_len > 8192) {
    $user_data->close(SSL_no_shutdown => 1);
    return -1;
  }

  return $$data_len;
}

sub ftps_data_close_cb {
  my $func_name = shift;
  my $data = shift;
  my $data_len = shift;
  my $total_len = shift;
  my $user_data = shift;

  return undef;
}

sub extlog_ftps_xfer_status_failed {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  if (open(my $fh, "> $test_file")) {
    print $fh "ABCDefgh" x 32768;

    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }

  } else {
    die("Can't open $test_file: $!");
  }

  my $timeout_idle = 20;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 data:20 tls:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,
    TimeoutIdle => $timeout_idle,

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

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
LogFormat custom "%m %{transfer-status}"
ExtendedLog $ext_log ALL custom
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

      unless ($client->binary()) {
        die("Can't set transfer mode to binary: " . $client->last_message());
      }

      $client->set_callback(\&ftps_data_xfer_failed_cb, \&ftps_data_close_cb, $client);

      if ($client->get('test.txt', '/dev/null')) {
        die("Download of 'test.txt' succeeded unexpectedly");
      }
    };

    if ($@) {
      $ex = $@;
    }

    $wfh->print("done\n");
    $wfh->flush();

  } else {
    eval { server_wait($config_file, $rfh, $timeout_idle + 3) };
    if ($@) {
      warn($@);
      exit 1;
    }

    exit 0;
  }

  # Stop server
  server_stop($pid_file);

  $self->assert_child_ok($pid);

  # Now, read in the ExtendedLog, and see whether the %{transfer-status}
  # variable was properly written out.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $expected_xfer_status = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($line =~ /^(\S+) (.*)?$/) {
          my $cmd = $1;
          my $xfer_status = $2;

          if ($cmd eq 'RETR') {
            if ($xfer_status eq 'failed') {
              $expected_xfer_status = 1;
              last;
            }
          }
        }
      }

      close($fh);

      $self->assert($expected_xfer_status,
        test_msg("Did not see expected transfer status in ExtendedLog"));

    } else {
      die("Can't read $ext_log: $!");
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

sub extlog_login_maxclients_bug3811 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $max_clients = 1;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%m %s"',
    ExtendedLog => "$ext_log AUTH custom",

    MaxClients => $max_clients,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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
      # First client should be able to log in...
      my $client1 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client1->login($user, $passwd);

      # ...but the second client should fail to login.
      my $client2 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      eval { $client2->login($user, $passwd) };
      unless ($@) {
        die("Second login succeeded unexpectedly");
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

  # Now, read in the ExtendedLog, and see whether the log entries were
  # properly written out.  Bug#3811 occurred because the session was
  # disconnected before mod_log had a chance to do its work.
  if (open(my $fh, "< $ext_log")) {
    my $nuser = 0;
    my $npass = 0;
    my $saw_failed_pass = 0;

    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /^(\S+)\s+(\d+)$/) {
        my $cmd = $1;
        my $resp_code = $2;

        if ($cmd eq 'USER') {
          $nuser++;

        } elsif ($cmd eq 'PASS') {
          $npass++;

          if ($npass == 2) {
            if ($resp_code == 530) {
              $saw_failed_pass = 1;
            }
          }
        }
      }
    }

    close($fh);

    my $expected = 2;
    $self->assert($expected == $nuser,
      test_msg("Expected $expected USER commands, saw $nuser"));

    $self->assert($expected == $npass,
      test_msg("Expected $expected PASS commands, saw $npass"));

    $self->assert($saw_failed_pass,
      test_msg("Did not see second PASS to fail with 530"));

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_login_maxclientsperclass_bug3811 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $class_name = "test";
  my $max_clients = 1;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%m %s"',
    ExtendedLog => "$ext_log AUTH custom",

    MaxClientsPerClass => "$class_name $max_clients",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    print $fh <<EOC;
<Class $class_name>
  From all
</Class>
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
      # First client should be able to log in...
      my $client1 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client1->login($user, $passwd);

      # ...but the second client should fail to login.
      my $client2 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      eval { $client2->login($user, $passwd) };
      unless ($@) {
        die("Second login succeeded unexpectedly");
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

  # Now, read in the ExtendedLog, and see whether the log entries were
  # properly written out.  Bug#3811 occurred because the session was
  # disconnected before mod_log had a chance to do its work.
  if (open(my $fh, "< $ext_log")) {
    my $nuser = 0;
    my $npass = 0;
    my $saw_failed_pass = 0;

    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /^(\S+)\s+(\d+)$/) {
        my $cmd = $1;
        my $resp_code = $2;

        if ($cmd eq 'USER') {
          $nuser++;

        } elsif ($cmd eq 'PASS') {
          $npass++;

          if ($npass == 2) {
            if ($resp_code == 530) {
              $saw_failed_pass = 1;
            }
          }
        }
      }
    }

    close($fh);

    my $expected = 2;
    $self->assert($expected == $nuser,
      test_msg("Expected $expected USER commands, saw $nuser"));

    $self->assert($expected == $npass,
      test_msg("Expected $expected PASS commands, saw $npass"));

    $self->assert($saw_failed_pass,
      test_msg("Did not see second PASS to fail with 530"));

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_login_maxclientsperhost_bug3811 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $max_clients = 1;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%m %s"',
    ExtendedLog => "$ext_log AUTH custom",

    MaxClientsPerHost => $max_clients,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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
      # First client should be able to log in...
      my $client1 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client1->login($user, $passwd);

      # ...but the second client should fail to login.
      my $client2 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      eval { $client2->login($user, $passwd) };
      unless ($@) {
        die("Second login succeeded unexpectedly");
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

  # Now, read in the ExtendedLog, and see whether the log entries were
  # properly written out.  Bug#3811 occurred because the session was
  # disconnected before mod_log had a chance to do its work.
  if (open(my $fh, "< $ext_log")) {
    my $nuser = 0;
    my $npass = 0;
    my $saw_failed_pass = 0;

    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /^(\S+)\s+(\d+)$/) {
        my $cmd = $1;
        my $resp_code = $2;

        if ($cmd eq 'USER') {
          $nuser++;

        } elsif ($cmd eq 'PASS') {
          $npass++;

          if ($npass == 2) {
            if ($resp_code == 530) {
              $saw_failed_pass = 1;
            }
          }
        }
      }
    }

    close($fh);

    my $expected = 2;
    $self->assert($expected == $nuser,
      test_msg("Expected $expected USER commands, saw $nuser"));

    $self->assert($expected == $npass,
      test_msg("Expected $expected PASS commands, saw $npass"));

    $self->assert($saw_failed_pass,
      test_msg("Did not see second PASS to fail with 530"));

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_login_maxclientsperuser_bug3811 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $max_clients = 1;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%m %s"',
    ExtendedLog => "$ext_log AUTH custom",

    MaxClientsPerUser => $max_clients,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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
      # First client should be able to log in...
      my $client1 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client1->login($user, $passwd);

      # ...but the second client should fail to login.
      my $client2 = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      eval { $client2->login($user, $passwd) };
      unless ($@) {
        die("Second login succeeded unexpectedly");
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

  # Now, read in the ExtendedLog, and see whether the log entries were
  # properly written out.  Bug#3811 occurred because the session was
  # disconnected before mod_log had a chance to do its work.
  if (open(my $fh, "< $ext_log")) {
    my $nuser = 0;
    my $npass = 0;
    my $saw_failed_pass = 0;

    while (my $line = <$fh>) {
      chomp($line);

      if ($line =~ /^(\S+)\s+(\d+)$/) {
        my $cmd = $1;
        my $resp_code = $2;

        if ($cmd eq 'USER') {
          $nuser++;

        } elsif ($cmd eq 'PASS') {
          $npass++;

          if ($npass == 2) {
            if ($resp_code == 530) {
              $saw_failed_pass = 1;
            }
          }
        }
      }
    }

    close($fh);

    my $expected = 2;
    $self->assert($expected == $nuser,
      test_msg("Expected $expected USER commands, saw $nuser"));

    $self->assert($expected == $npass,
      test_msg("Expected $expected PASS commands, saw $npass"));

    $self->assert($saw_failed_pass,
      test_msg("Did not see second PASS to fail with 530"));

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_preauth_var_U_bug3822 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%m %U"',
    ExtendedLog => "$ext_log ALL custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      eval { $client->pwd() };
      unless ($@) {
        die("PWD succeeded unexpectedly");
      }

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

  # Now, read in the ExtendedLog, and see whether the %U variable were
  # properly written out.
  if (open(my $fh, "< $ext_log")) {
    while (my $line = <$fh>) {
      chomp($line);

      $line =~ /(\S+) (.*)?$/;
      my $cmd = $1;
      my $name = $2;

      my $expected;
      if ($cmd eq 'PWD') {
        $expected = '-';

      } else {
        $expected = $user;
      }

      $self->assert($expected eq $name,
        test_msg("Expected name '$expected', got '$name'"));
    }

    close($fh);

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_preauth_var_u_bug3822 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%m %u"',
    ExtendedLog => "$ext_log ALL custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      eval { $client->pwd() };
      unless ($@) {
        die("PWD succeeded unexpectedly");
      }

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

  my $config_user = (config_get_identity())[0];
  # Now, read in the ExtendedLog, and see whether the %U variable were
  # properly written out.
  if (open(my $fh, "< $ext_log")) {
    while (my $line = <$fh>) {
      chomp($line);

      $line =~ /(\S+) (.*)?$/;
      my $cmd = $1;
      my $name = $2;

      my $expected;
      if ($cmd eq 'PWD' ||
          $cmd eq 'USER') {
        $expected = '-';

      } else {
        $expected = $user;
      }

      $self->assert($expected eq $name,
        test_msg("Expected name '$expected', got '$name'"));
    }

    close($fh);

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_micros_ts_bug3889 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'extlog');

  my $test_file = File::Spec->rel2abs($setup->{config_file});
  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'extlog:20 jot:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    LogFormat => 'custom "%{%Y-%m-%d %H:%M:%S}t,%{microsecs} %f"',
    ExtendedLog => "$ext_log READ custom",

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($setup->{user}, $setup->{passwd});

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

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
  $self->assert_child_ok($setup->{pid});

  eval {
    if (open(my $fh, "< $ext_log")) {
      my $line = <$fh>;
      chomp($line);

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# ExtendedLog: $line\n";
      }

      close($fh);

      if ($line =~ /^\d{4}\-\d{2}\-\d{2} \d{2}:\d{2}:\d{2},\d{6}\s+(.*)?$/) {
        my $file = $1; 

        # MacOSX hack
        if ($^O eq 'darwin') {
          $test_file = ('/private' . $test_file);
        }

        $self->assert($test_file eq $file,
          "Expected '$test_file', got '$file'");

      } else {
        $self->assert(0, test_msg("Did not see expected ExtendedLog line"));
      }

    } else {
      die("Can't read $ext_log: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub extlog_millis_ts_bug3889 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%{%Y-%m-%d %H:%M:%S}t,%{millisecs} %f"',
    ExtendedLog => "$ext_log READ custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

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

  if (open(my $fh, "< $ext_log")) {
    my $line = <$fh>;
    chomp($line);
    close($fh);

    if ($line =~ /^\d{4}\-\d{2}\-\d{2} \d{2}:\d{2}:\d{2},\d{3}\s+(.*)?$/) {
      my $file = $1; 

      # MacOSX hack
      if ($^O eq 'darwin') {
        $test_file = ('/private' . $test_file);
      }

      $self->assert($test_file eq $file,
        test_msg("Expected '$test_file', got '$file'"));

    } else {
      $self->assert(0, test_msg("Did not see expected ExtendedLog line"));
    }

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_iso8601_ts_bug3889 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'extlog');

  my $test_file = File::Spec->rel2abs($setup->{config_file});
  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'extlog:20 jot:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    LogFormat => 'custom "%{ISO8601} %f"',
    ExtendedLog => "$ext_log READ custom",

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port);
      $client->login($setup->{user}, $setup->{passwd});

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

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

  eval {
    if (open(my $fh, "< $ext_log")) {
      my $line = <$fh>;
      chomp($line);

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# ExtendedLog: $line\n";
      }

      close($fh);

      if ($line =~ /^\d{4}\-\d{2}\-\d{2} \d{2}:\d{2}:\d{2},\d{3}\s+(.*)?$/) {
        my $file = $1; 

        # MacOSX hack
        if ($^O eq 'darwin') {
          $test_file = ('/private' . $test_file);
        }

        $self->assert($test_file eq $file,
          "Expected '$test_file', got '$file'");

      } else {
        $self->assert(0, "Did not see expected ExtendedLog line");
      }

    } else {
      die("Can't read $ext_log: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub extlog_dirs_class_var_f_bug3966 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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
    close($fh);

  } else {
    die("Can't open $test_file: $!");
  }

  my $test_dir = File::Spec->rel2abs("$tmpdir/test.d");
  mkpath($test_dir);

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%m: %f"',
    ExtendedLog => "$ext_log DIRS custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      # Bug#3966 reports that the %f LogFormat variable is not resolved for:
      #
      #  CWD/XCWD, PWD/XPWD, CDUP/XCUP, LIST, MDTM, MLSD, MLST, NLST
      #
      # So run through all of them, then examine the generated log.

      $client->pwd();
      $client->xpwd();
      $client->cwd('test.d');
      $client->cdup();
      $client->xcwd('test.d');
      $client->xcup();
      $client->mdtm('test.txt');
      $client->mlst('test.txt');
      $client->mlsd('test.d');
      $client->list('test.d');
      $client->nlst('test.d');

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

  # Now, read in the ExtendedLog, and see whether the %f variable was
  # properly written out for MFMT.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $ok = 1;

      if ($^O eq 'darwin') {
        # MacOSX-specific hack
        $home_dir = '/private' . $home_dir;
        $test_file = '/private' . $test_file;
        $test_dir = '/private' . $test_dir;
      }

      while (my $line = <$fh>) {
        chomp($line);

        if ($line =~ /^(\S+): (\S+)$/) {
          my $cmd = $1;
          my $file_path = $2;

          # We don't mind if the path ends in a trailing slash; ignore it
          $file_path =~ s/\/$//;

          if ($cmd eq 'CWD' || $cmd eq 'XCWD' ||
              $cmd eq 'LIST' || $cmd eq 'MLSD' || $cmd eq 'NLST') {
            $self->assert($test_dir eq $file_path,
              test_msg("Expected file (%f) '$test_dir' for $cmd, got '$file_path'"));

          } elsif ($cmd eq 'PWD' || $cmd eq 'XPWD' ||
                   $cmd eq 'CDUP' || $cmd eq 'XCUP') {
            $self->assert($home_dir eq $file_path,
              test_msg("Expected file (%f) '$home_dir' for $cmd, got '$file_path'"));

          } elsif ($cmd eq 'MDTM' || $cmd eq 'MLST') {
            $self->assert($test_file eq $file_path,
              test_msg("Expected file (%f) '$test_file' for $cmd, got '$file_path'"));

          } else {
            $ok = 0;
          }
       
          if ($ok == 0) {
            last;
          }

        } else {
          $ok = 0;
          last;
        }
      }

      close($fh);
      $self->assert($ok, test_msg("Did not find expected ExtendedLog entries"));

    } else {
      die("Can't read $ext_log: $!");
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

sub extlog_var_basename_bug3987 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%{basename}"',
    ExtendedLog => "$ext_log READ custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

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

  eval {
    if (open(my $fh, "< $ext_log")) {
      my $line = <$fh>;
      chomp($line);
      close($fh);

      my $expected = 'extlog.conf';
      $self->assert($expected eq $line,
        test_msg("Expected '$expected', got '$line'"));

    } else {
      die("Can't read $ext_log: $!");
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

sub extlog_exclusion_bug4067 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%m"',
    ExtendedLog => "$ext_log ALL,!AUTH custom",

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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
      $client->feat();
      $client->pwd();
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

  # Now, read in the ExtendedLog, and see whether the %f variable was
  # properly written out.  Bug#3137 occurred because the session.xfer.path
  # variable was cleared out, as part of cleaning up the data connection,
  # too early.  The fix is to use session.notes, which also has that path
  # information.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $ok = 1;

      while (my $line = <$fh>) {
        chomp($line);

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "$line\n";
        }

        if ($line eq 'USER' ||
            $line eq 'PASS') {
          $ok = 0;
          last;
        }
      }

      close($fh);

      $self->assert($ok, test_msg("Unexpected ExtendedLog messages logged"));

    } else {
      die("Can't read $ext_log: $!");
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

sub extlog_sftp_ssh_sftp_bug4067 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $sub_dir = File::Spec->rel2abs("$home_dir/sub.d");
  mkpath($sub_dir);

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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 ssh2:20 sftp:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%m"',
    ExtendedLog => "$ext_log SFTP custom",

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

      unless ($ssh2->auth_password($user, $passwd)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $sftp = $ssh2->sftp();
      unless ($sftp) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't use SFTP on SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $dir = $sftp->opendir('sub.d');
      unless ($dir) {
        my ($err_code, $err_name) = $sftp->error();
        die("Can't open directory 'sub.d': [$err_name] ($err_code)");
      }

      my $res = {};

      my $file = $dir->read();
      while ($file) {
        $res->{$file->{name}} = $file;
        $file = $dir->read();
      }

      # To issue the FXP_CLOSE, we have to explicitly destroy the dirhandle
      $dir = undef;

      # To close the SFTP channel, we have to explicitly destroy the object
      $sftp = undef;

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

  eval {
    if (open(my $fh, "< $ext_log")) {
      my $ok = 1;

      while (my $line = <$fh>) {
        chomp($line);

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "$line\n";
        }

        if ($line eq 'USER' ||
            $line eq 'PASS' ||
            $line eq 'MLSD') {
          $ok = 0;
          last;
        }
      }

      close($fh);

      $self->assert($ok, test_msg("Unexpected ExtendedLog lines seen"));

    } else {
      die("Can't read $ext_log: $!");
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

sub extlog_sftp_ssh_sftp_exclusion_bug4067 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $sub_dir = File::Spec->rel2abs("$home_dir/sub.d");
  mkpath($sub_dir);

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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 ssh2:20 sftp:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%m"',
    ExtendedLog => "$ext_log DIRS,!SSH,!SFTP custom",

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

      unless ($ssh2->auth_password($user, $passwd)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $sftp = $ssh2->sftp();
      unless ($sftp) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't use SFTP on SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $dir = $sftp->opendir('sub.d');
      unless ($dir) {
        my ($err_code, $err_name) = $sftp->error();
        die("Can't open directory 'sub.d': [$err_name] ($err_code)");
      }

      my $res = {};

      my $file = $dir->read();
      while ($file) {
        $res->{$file->{name}} = $file;
        $file = $dir->read();
      }

      # To issue the FXP_CLOSE, we have to explicitly destroy the dirhandle
      $dir = undef;

      # To close the SFTP channel, we have to explicitly destroy the object
      $sftp = undef;

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

  eval {
    if (open(my $fh, "< $ext_log")) {
      my $ok = 1;

      while (my $line = <$fh>) {
        chomp($line);

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "$line\n";
        }

        if ($line ne 'USER' &&
            $line ne 'PASS' &&
            $line ne 'MLSD') {
          $ok = 0;
          last;
        }
      }

      close($fh);
      $self->assert($ok, test_msg("Unexpected ExtendedLog lines seen"));

    } else {
      die("Can't read $ext_log: $!");
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

sub extlog_sftp_read_write_bug4067 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $user = 'proftpd';
  my $passwd = 'test';
  my $group = 'ftpd';
  my $home_dir = File::Spec->rel2abs($tmpdir);
  my $uid = 500;
  my $gid = 500;

  my $sub_dir = File::Spec->rel2abs("$home_dir/sub.d");
  mkpath($sub_dir);

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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 ssh2:20 sftp:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%m"',
    ExtendedLog => "$ext_log READ,WRITE custom",

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

      unless ($ssh2->auth_password($user, $passwd)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $sftp = $ssh2->sftp();
      unless ($sftp) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't use SFTP on SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $fh = $sftp->open('test.txt', O_WRONLY|O_CREAT|O_TRUNC, 0644);
      unless ($fh) {
        my ($err_code, $err_name) = $sftp->error();
        die("Can't open test.txt: [$err_name] ($err_code)");
      }

      my $count = 5;
      for (my $i = 0; $i < $count; $i++) {
        print $fh "ABCD" x 1024;
      }

      # To issue the FXP_CLOSE, we have to explicitly destroy the filehandle
      $fh = undef;

      $fh = $sftp->open('test.txt', O_RDONLY);
      unless ($fh) {
        my ($err_code, $err_name) = $sftp->error();
        die("Can't open test.txt: [$err_name] ($err_code)");
      }

      my $buf;
      my $size = 0;

      my $res = $fh->read($buf, 8192);
      while ($res) {
        $size += $res;

        $res = $fh->read($buf, 8192);
      }

      # To issue the FXP_CLOSE, we have to explicitly destroy the filehandle
      $fh = undef;

      # To close the SFTP channel, we have to explicitly destroy the object
      $sftp = undef;

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

  eval {
    if (open(my $fh, "< $ext_log")) {
      my $write_ok = 0;
      my $read_ok = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "$line\n";
        }

        if ($write_ok and $read_ok) {
          last;
        }

        if ($line eq 'WRITE') {
          $write_ok = 1;
          next;
        }

        if ($line eq 'READ') {
          $read_ok = 1;
          next;
        }
      }

      close($fh);

      $self->assert($write_ok and $read_ok,
        test_msg("Unexpected ExtendedLog lines seen"));

    } else {
      die("Can't read $ext_log: $!");
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

sub extlog_sftp_xfer_status_filtered {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

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

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'DEFAULT:10 ssh2:20 sftp:20',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    PathDenyFilter => '^.*\.csv$',
    LogFormat => 'custom "%m %{transfer-status}"',
    ExtendedLog => "$ext_log READ,WRITE custom",

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

      unless ($ssh2->auth_password($user, $passwd)) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $sftp = $ssh2->sftp();
      unless ($sftp) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't use SFTP on SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $fh = $sftp->open('test.csv', O_WRONLY|O_CREAT|O_TRUNC, 0644);
      if ($fh) {
        die("Open of test.csv succeeded unexpectedly");
      }

      my ($err_code, $err_name) = $sftp->error();
      my $expected = 'SSH_FX_PERMISSION_DENIED';
      $self->assert($expected eq $err_name,
        "Expected error $expected, got $err_name");

      # To close the SFTP channel, we have to explicitly destroy the object
      $sftp = undef;

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

  eval {
    if (open(my $fh, "< $ext_log")) {
      my $saw_failed = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "$line\n";
        }

        if ($line eq 'STOR failed') {
          $saw_failed = 1;
          last;
        }
      }

      close($fh);
      $self->assert($saw_failed, "Expected ExtendedLog line not seen");

    } else {
      die("Can't read $ext_log: $!");
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

sub extlog_var_file_offset {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/extlog.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/extlog.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/extlog.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/extlog.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/extlog.group");

  my $test_file = File::Spec->rel2abs($config_file);

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

  my $offset = 1;

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    LogFormat => 'custom "%f: %{file-offset}"',
    ExtendedLog => "$ext_log READ custom",
    AllowRetrieveRestart => 'true',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
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
      $client->type('binary');

      my ($resp_code, $resp_msg) = $client->rest($offset);

      my $expected = 350;
      $self->assert($expected == $resp_code,
        test_msg("Expected response code $expected, got $resp_code"));

      $expected = "Restarting at $offset. Send STORE or RETRIEVE to initiate transfer";
      $self->assert($expected eq $resp_msg,
        test_msg("Expected response message '$expected', got '$resp_msg'"));

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

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

  # Now, read in the ExtendedLog, and see whether the %{note:file-offset}
  # variable was properly written out.
  if (open(my $fh, "< $ext_log")) {
    my $ok = 0;

    my $line = <$fh>;
    chomp($line);
    close($fh);

    if ($line =~ /^(.*?): (\d+)$/) {
      my $path = $1;
      my $pos = $2;

      if ($^O eq 'darwin') {
        # MacOSX-specific hack
        $test_file = '/private' . $test_file;
      }

      $self->assert($test_file eq $path,
        test_msg("Expected '$test_file', got '$path'"));

      $self->assert($pos == $offset,
        test_msg("Expected offset $offset, got $pos"));

      $ok = 1;
    }

    $self->assert($ok,
      test_msg("ExtendedLog message '$line' did not contain expected content"));

  } else {
    die("Can't read $ext_log: $!");
  }

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    die($ex);
  }

  unlink($log_file);
}

sub extlog_var_file_size_retr {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'extlog');

  my $test_file = File::Spec->rel2abs($setup->{config_file});

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    LogFormat => 'custom "%f: %{file-size}"',
    ExtendedLog => "$ext_log READ custom",
    AllowRetrieveRestart => 'true',

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      $client->login($setup->{user}, $setup->{passwd});
      $client->type('binary');

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

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

  # Now, read in the ExtendedLog, and see whether the %{file-size} variable
  # was properly written out.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $ok = 0;

      my $line = <$fh>;
      chomp($line);
      close($fh);

      if ($line =~ /^(.*?): (\d+)$/) {
        my $path = $1;
        my $size = $2;

        if ($^O eq 'darwin') {
          # MacOSX-specific hack
          $test_file = '/private' . $test_file;
        }

        $self->assert($test_file eq $path,
          test_msg("Expected '$test_file', got '$path'"));

        my $expected = -s $setup->{config_file};
        $self->assert($expected == $size,
          test_msg("Expected size $expected, got $size"));

        $ok = 1;
      }

      $self->assert($ok,
        test_msg("ExtendedLog message '$line' did not contain expected content"));

    } else {
      die("Can't read $ext_log: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub extlog_sftp_var_file_size_retr {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'extlog');

  my $test_file = File::Spec->rel2abs($setup->{config_file});

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'DEFAULT:10 sftp:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    LogFormat => 'custom "%m: %f: %{file-size}"',
    ExtendedLog => "$ext_log READ custom",
    AllowRetrieveRestart => 'true',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sftp.c' => [
        "SFTPEngine on",
        "SFTPLog $setup->{log_file}",
        "SFTPHostKey $rsa_host_key",
        "SFTPHostKey $dsa_host_key",
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

  require Net::SSH2;
  my $ex;

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

      unless ($ssh2->auth_password($setup->{user}, $setup->{passwd})) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $sftp = $ssh2->sftp();
      unless ($sftp) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't use SFTP on SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $path = 'extlog.conf';
      my $fh = $sftp->open($path, O_RDONLY);
      unless ($fh) {
        my ($err_code, $err_name) = $sftp->error();
        die("Can't open $path: [$err_name] ($err_code)");
      }

      my $buf;
      my $size = 0;

      my $res = $fh->read($buf, 8192);
      while ($res) {
        $size += $res;
        $res = $fh->read($buf, 8192);
      }

      # To issue the FXP_CLOSE, we have to explicitly destroy the filehandle
      $fh = undef;

      # To close the SFTP channel, we have to explicitly destroy the object
      $sftp = undef;

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

  # Now, read in the ExtendedLog, and see whether the %{file-size} variable
  # was properly written out.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $ok = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($line =~ /^(\S+): (.*?): (\d+)$/) {
          my $req = $1;
          my $path = $2;
          my $size = $3;

          if ($ENV{TEST_VERBOSE}) {
            print STDERR "# line: $line\n";
          }

          if ($req ne 'RETR') {
            next;
          }

          if ($^O eq 'darwin') {
            # MacOSX-specific hack
            $test_file = '/private' . $test_file;
          }

          $self->assert($test_file eq $path,
            test_msg("Expected '$test_file', got '$path'"));

          my $expected = -s $setup->{config_file};
          $self->assert($expected == $size,
            test_msg("Expected size $expected, got $size"));

          $ok = 1;
          last;
        }
      }

      close($fh);

      $self->assert($ok,
        test_msg("ExtendedLog did not contain expected content"));

    } else {
      die("Can't read $ext_log: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub extlog_var_file_size_stor {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'extlog');

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    LogFormat => 'custom "%f: %{file-size}"',
    ExtendedLog => "$ext_log WRITE custom",

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      $client->login($setup->{user}, $setup->{passwd});
      $client->type('binary');

      my $conn = $client->stor_raw($test_file);
      unless ($conn) {
        die("Failed to STOR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Hello, World!\n";
      $conn->write($buf, length($buf), 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

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

  # Now, read in the ExtendedLog, and see whether the %{file-size} variable
  # was properly written out.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $ok = 0;

      my $line = <$fh>;
      chomp($line);
      close($fh);

      if ($line =~ /^(.*?): (\d+)$/) {
        my $path = $1;
        my $size = $2;

        if ($^O eq 'darwin') {
          # MacOSX-specific hack
          $test_file = '/private' . $test_file;
        }

        $self->assert($test_file eq $path,
          test_msg("Expected '$test_file', got '$path'"));

        my $expected = -s $test_file;
        $self->assert($expected == $size,
          test_msg("Expected size $expected, got $size"));

        $ok = 1;
      }

      $self->assert($ok,
        test_msg("ExtendedLog message '$line' did not contain expected content"));

    } else {
      die("Can't read $ext_log: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub extlog_sftp_var_file_size_stor {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'extlog');

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");
  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $rsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_rsa_key');
  my $dsa_host_key = File::Spec->rel2abs('t/etc/modules/mod_sftp/ssh_host_dsa_key');

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'DEFAULT:10 sftp:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    LogFormat => 'custom "%m: %f: %{file-size}"',
    ExtendedLog => "$ext_log WRITE custom",
    AllowRetrieveRestart => 'true',

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },

      'mod_sftp.c' => [
        "SFTPEngine on",
        "SFTPLog $setup->{log_file}",
        "SFTPHostKey $rsa_host_key",
        "SFTPHostKey $dsa_host_key",
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

  require Net::SSH2;
  my $ex;

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

      unless ($ssh2->auth_password($setup->{user}, $setup->{passwd})) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't login to SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $sftp = $ssh2->sftp();
      unless ($sftp) {
        my ($err_code, $err_name, $err_str) = $ssh2->error();
        die("Can't use SFTP on SSH2 server: [$err_name] ($err_code) $err_str");
      }

      my $path = 'test.txt';
      my $fh = $sftp->open($path, O_WRONLY|O_CREAT);
      unless ($fh) {
        my ($err_code, $err_name) = $sftp->error();
        die("Can't open $path: [$err_name] ($err_code)");
      }

      my $buf = "Hello, World!\n";
      my $res = $fh->write($buf);

      # To issue the FXP_CLOSE, we have to explicitly destroy the filehandle
      $fh = undef;

      # To close the SFTP channel, we have to explicitly destroy the object
      $sftp = undef;

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

  # Now, read in the ExtendedLog, and see whether the %{file-size} variable
  # was properly written out.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $ok = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($line =~ /^(\S+): (.*?): (\d+)$/) {
          my $req = $1;
          my $path = $2;
          my $size = $3;

          if ($ENV{TEST_VERBOSE}) {
            print STDERR "# line: $line\n";
          }

          if ($req ne 'STOR') {
            next;
          }

          if ($^O eq 'darwin') {
            # MacOSX-specific hack
            $test_file = '/private' . $test_file;
          }

          $self->assert($test_file eq $path,
            test_msg("Expected '$test_file', got '$path'"));

          my $expected = -s $test_file;
          $self->assert($expected == $size,
            test_msg("Expected size $expected, got $size"));

          $ok = 1;
          last;
        }
      }

      close($fh);

      $self->assert($ok,
        test_msg("ExtendedLog did not contain expected content"));

    } else {
      die("Can't read $ext_log: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub extlog_var_transfer_type_retr {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'extlog');

  my $test_file = File::Spec->rel2abs($setup->{config_file});

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    LogFormat => 'custom "%f: %{transfer-type}"',
    ExtendedLog => "$ext_log READ custom",
    AllowRetrieveRestart => 'true',

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      $client->login($setup->{user}, $setup->{passwd});
      $client->type('binary');

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf;
      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->type('ascii');

      $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      $conn->read($buf, 8192, 30);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

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

  # Now, read in the ExtendedLog, and see whether the %{transfer-type} variable
  # was properly written out.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $ok = 0;

      if ($^O eq 'darwin') {
        # MacOSX-specific hack
        $test_file = '/private' . $test_file;
      }

      while (my $line = <$fh>) {
        chomp($line);

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "# line: $line\n";
        }

        if ($line =~ /^(.*?): (\S+)$/) {
          my $path = $1;
          my $xfer_type = $2;

          $self->assert($test_file eq $path,
            test_msg("Expected '$test_file', got '$path'"));

          my $expected = 'binary';
          if ($ok == 1) {
            $expected = 'ASCII';
          }
          $self->assert($expected eq $xfer_type,
            test_msg("Expected transfer type '$expected', got '$xfer_type'"));

          $ok++;
        }
      }

      close($fh);

      $self->assert($ok == 2,
        test_msg("ExtendedLog did not contain expected content"));

    } else {
      die("Can't read $ext_log: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub extlog_var_transfer_type_stor {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'extlog');

  my $test_file = File::Spec->rel2abs("$tmpdir/test.txt");

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    LogFormat => 'custom "%f: %{transfer-type}"',
    ExtendedLog => "$ext_log WRITE custom",

    AllowOverwrite => 'true',
    AllowStoreRestart => 'true',

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      $client->login($setup->{user}, $setup->{passwd});
      $client->type('binary');

      my $conn = $client->stor_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Hello, World!\n";
      $conn->write($buf, length($buf), 30);
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->type('ascii');

      $conn = $client->stor_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      $conn->write($buf, length($buf), 30);
      eval { $conn->close() };

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

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

  # Now, read in the ExtendedLog, and see whether the %{transfer-type} variable
  # was properly written out.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $ok = 0;

      if ($^O eq 'darwin') {
        # MacOSX-specific hack
        $test_file = '/private' . $test_file;
      }

      while (my $line = <$fh>) {
        chomp($line);

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "# line: $line\n";
        }

        if ($line =~ /^(.*?): (\S+)$/) {
          my $path = $1;
          my $xfer_type = $2;

          $self->assert($test_file eq $path,
            test_msg("Expected '$test_file', got '$path'"));

          my $expected = 'binary';
          if ($ok == 1) {
            $expected = 'ASCII';
          }
          $self->assert($expected eq $xfer_type,
            test_msg("Expected transfer type '$expected', got '$xfer_type'"));

          $ok++;
        }
      }

      close($fh);

      $self->assert($ok == 2,
        test_msg("ExtendedLog did not contain expected content"));

    } else {
      die("Can't read $ext_log: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub extlog_file_transfer_secs {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'extlog');

  my $test_file = File::Spec->rel2abs("$tmpdir/test.dat");
  if (open(my $fh, "> $test_file")) {
    print $fh "ABCDefgh" x 8192;
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }
  } else {
    die("Can't open $test_file: $!");
  }

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    # Throttle the transfer, to aid in the timing
    TransferRate => 'RETR 1',

    LogFormat => 'custom "%f: %T"',
    ExtendedLog => "$ext_log READ custom",

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      $client->login($setup->{user}, $setup->{passwd});
      $client->type('binary');

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my ($buf, $data);
      while ($conn->read($data, 8192, 30)) {
        $buf .= $data;
      }
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();
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

  # Now, read in the ExtendedLog, and see whether the %T variable was properly
  # written out.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $ok = 0;

      my $line = <$fh>;
      chomp($line);
      close($fh);

      if ($line =~ /^(.*?): (\S+)$/) {
        my $path = $1;
        my $secs = $2;

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "# ExtendedLog: $line\n";
        }

        if ($^O eq 'darwin') {
          # MacOSX-specific hack
          $test_file = '/private' . $test_file;
        }

        $self->assert($test_file eq $path,
          test_msg("Expected '$test_file', got '$path'"));

        my $expected_min = 9;
        $self->assert($expected_min < $secs,
          test_msg("Expected at least transfer seconds $expected_min, got $secs"));

        $ok = 1;
      }

      $self->assert($ok,
        test_msg("ExtendedLog message '$line' did not contain expected content"));

    } else {
      die("Can't read $ext_log: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub extlog_file_transfer_millisecs_bug4218 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'extlog');

  my $test_file = File::Spec->rel2abs("$tmpdir/test.dat");
  if (open(my $fh, "> $test_file")) {
    print $fh "ABCDefgh" x 8192;
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }
  } else {
    die("Can't open $test_file: $!");
  }

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    # Throttle the transfer, to aid in the timing
    TransferRate => 'RETR 1',

    LogFormat => 'custom "%f: %{transfer-millisecs}"',
    ExtendedLog => "$ext_log READ custom",

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      $client->login($setup->{user}, $setup->{passwd});
      $client->type('binary');

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my ($buf, $data);
      while ($conn->read($data, 8192, 30)) {
        $buf .= $data;
      }
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();
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

  # Now, read in the ExtendedLog, and see whether the %T variable was properly
  # written out.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $ok = 0;

      my $line = <$fh>;
      chomp($line);
      close($fh);

      if ($line =~ /^(.*?): (\d+)$/) {
        my $path = $1;
        my $secs = $2;

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "# ExtendedLog: $line\n";
        }

        if ($^O eq 'darwin') {
          # MacOSX-specific hack
          $test_file = '/private' . $test_file;
        }

        $self->assert($test_file eq $path,
          test_msg("Expected '$test_file', got '$path'"));

        my $expected_min = 9000;
        $self->assert($expected_min < $secs,
          test_msg("Expected at least transfer seconds $expected_min, got $secs"));

        $ok = 1;
      }

      $self->assert($ok,
        test_msg("ExtendedLog message '$line' did not contain expected content"));

    } else {
      die("Can't read $ext_log: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub extlog_response_millisecs_bug4218 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'extlog');

  my $test_file = File::Spec->rel2abs("$tmpdir/test.dat");
  if (open(my $fh, "> $test_file")) {
    print $fh "ABCDefgh" x 8192;
    unless (close($fh)) {
      die("Can't write $test_file: $!");
    }
  } else {
    die("Can't open $test_file: $!");
  }

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    # Throttle the transfer, to aid in the timing
    TransferRate => 'RETR 1',

    LogFormat => 'custom "%m: %R"',
    ExtendedLog => "$ext_log ALL custom",

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      $client->login($setup->{user}, $setup->{passwd});
      $client->type('binary');

      my $conn = $client->retr_raw($test_file);
      unless ($conn) {
        die("Failed to RETR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my ($buf, $data);
      while ($conn->read($data, 8192, 30)) {
        $buf .= $data;
      }
      eval { $conn->close() };

      my $resp_code = $client->response_code();
      my $resp_msg = $client->response_msg();
      $self->assert_transfer_ok($resp_code, $resp_msg);

      $client->quit();
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

  # Now, read in the ExtendedLog, and see whether the %T variable was properly
  # written out.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $ok = 0;

      while (my $line = <$fh>) {
        chomp($line);

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "# ExtendedLog: $line\n";
        }

        if ($line =~ /^(.*?): (\d+)$/) {
          $ok = 1;
        }
      }

      close($fh);

      $self->assert($ok, test_msg("ExtendedLog contained unexpected content"));

    } else {
      die("Can't read $ext_log: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub extlog_stor_var_f_xfer_timed_out {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'extlog');

  my $sub_dir = File::Spec->rel2abs("$tmpdir/sub.d");
  mkpath($sub_dir);

  my $dst_file = File::Spec->rel2abs("$sub_dir/dst.dat");
  my $timeout_stalled = 2;

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'response:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    LogFormat => 'custom "%m %s: %f"',
    ExtendedLog => "$ext_log ALL custom",
    TimeoutStalled => $timeout_stalled,

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      $client->login($setup->{user}, $setup->{passwd});
      $client->cwd('sub.d');

      my $conn = $client->stor_raw('dst.dat');
      unless ($conn) {
        die("Failed to STOR: " . $client->response_code() . " " .
          $client->response_msg());
      }

      my $buf = "Foo";
      $conn->write($buf, length($buf));

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# Sleeping for $timeout_stalled secs\n";
      }
      sleep($timeout_stalled + 1);

      # Normally we would send a QUIT, but a TimeoutStalled timer would
      # have disconnected us.
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

  # Now, read in the ExtendedLog, and see whether the %f variable was
  # properly written out.
  eval {
    if (open(my $fh, "< $ext_log")) {
      my $expected = $dst_file;
      my $first_ok = 0;
      my $second_ok = 0;

      if ($^O eq 'darwin') {
        # MacOSX-specific hack
        $expected = '/private' . $dst_file;
      }

      while (my $line = <$fh>) {
        chomp($line);

        if ($line =~ /^STOR 150: (\S+)$/) {
          my $path = $1;

          if ($path eq $expected) {
            $first_ok = 1;
          }
        }

        if ($line =~ /^STOR 426: (\S+)$/) {
          my $path = $1;

          if ($path eq $expected) {
            $second_ok = 1;
          }
        }
      }

      close($fh);

      $self->assert($first_ok and $second_ok,
        test_msg("Expected ExtendedLog messages did not appear"));

    } else {
      die("Can't read $ext_log: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

sub extlog_write_invalid_cmd_bug4313 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'extlog');

  my $ext_log = File::Spec->rel2abs("$tmpdir/custom.log");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'response:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

    LogFormat => 'custom "%r"',
    ExtendedLog => "$ext_log WRITE custom",

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
      my $client = ProFTPD::TestSuite::FTP->new('127.0.0.1', $port, 0, 1);
      eval { $client->quote('FOO', 'BAR', 'BAZ') };
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

  eval {
    if (open(my $fh, "< $ext_log")) {
      my $ok = 1;

      while (my $line = <$fh>) {
        chomp($line);

        if ($ENV{TEST_VERBOSE}) {
          print STDERR "$line\n";
        }

        $ok = 0;
      }

      close($fh);
      $self->assert($ok, "Unexpected ExtendedLog messages appeared");

    } else {
      die("Can't read $ext_log: $!");
    }
  };
  if ($@) {
    $ex = $@;
  }

  test_cleanup($setup->{log_file}, $ex);
}

1;
