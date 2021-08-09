package ProFTPD::TestSuite::Utils;

use strict;

use Carp;
use File::Path;
use File::Spec;
use File::Temp qw(tempdir);
use IO::Socket::INET;

require Exporter;
our @ISA = qw(Exporter);

our @AUTH = qw(
  auth_group_write
  auth_user_write
);

our @CONFIG = qw(
  config_get_identity
  config_write
);

our @FEATURES = qw(
  feature_get_compiled_modules
  feature_get_shared_modules
  feature_get_version
  feature_have_feature_enabled
  feature_have_module_compiled
  feature_have_module_loaded
);

our @RUNNING = qw(
  server_restart
  server_signal
  server_start
  server_stop
  server_wait
);

our @TEST = qw(
  test_append_logfile
  test_cleanup
  test_get_logfile
  test_msg
  test_setup
);

our @TESTSUITE = qw(
  testsuite_empty_test
  testsuite_get_runnable_tests
  testsuite_get_tmp_dir
);

our @EXPORT_OK = (@AUTH, @CONFIG, @FEATURES, @RUNNING, @TEST, @TESTSUITE);

our %EXPORT_TAGS = (
  auth => [@AUTH],
  config => [@CONFIG],
  features => [@FEATURES],
  running => [@RUNNING],
  test => [@TEST],
  testsuite => [@TESTSUITE],
);

my $testno = 0;

sub get_proftpd_bin {
  if ($ENV{PROFTPD_TEST_BIN}) {
    return $ENV{PROFTPD_TEST_BIN};

  } else {
    # Guess.
    return '../proftpd';
  }
}

sub get_high_numbered_port {

  # XXX There's a minor race condition here, between opening a listening
  # socket on a kernel-chosen random port, closing that socket, and returning
  # the port number for use in the proftpd config.

  my $sock = IO::Socket::INET->new(
    LocalAddr => '127.0.0.1',
    Listen => 5,
    Proto => 'tcp',
    ReuseAddr => 1,
  );

  my $port = $sock->sockport();
  $sock->close();

  return $port;
}

sub get_passwd {
  my $user_passwd = shift;

  if ($user_passwd eq '') {
    return '';
  }

  # First, try to use MD5 hashing for passwords
  my $md5_salt = '$1$' . join('', (0..9, 'A'..'Z', 'a'..'z')[rand(62), rand(62), rand(62), rand(62), rand(62), rand(62), rand(62), rand(62)]);

  my $hash = crypt($user_passwd, $md5_salt);

  # If the first three characters of the hash are not "$1$", the crypt()
  # implementation doesn't support MD5.  Some crypt()s will happily use
  # "$1" as a salt even though this is not a valid DES salt.  Humf.

  my @string = split('', $hash);
  my $prefix = $string[0] . $string[1] . $string[2];

  if ($prefix ne '$1$') {
    # OK, fall back to using a DES hash.
    my $des_salt = join('', ('.', '/', 0..9, 'A'..'Z', 'a'..'z')[rand(64), rand(64)]);

    $hash = crypt($user_passwd, $des_salt);
  }

  return $hash;

}

sub auth_group_write {
  my $group_file = shift;
  croak("Missing group file argument") unless $group_file;
  my $group_name = shift;
  croak("Missing group name argument") unless $group_name;
  my $group_id = shift;
  croak("Missing group ID argument") unless defined($group_id);

  my @member_names = @_;

  my $existed = -f $group_file;
  my $prev_mode;

  if ($existed) {
    # Get current permissions
    $prev_mode = (stat($group_file))[2];

    # Set needed permissions
    unless (chmod(0666, $group_file)) {
      croak("Can't set perms on $group_file: $!");
    }
  }

  if (open(my $fh, ">> $group_file")) {
    print $fh "$group_name:*:$group_id:" . join(',', @member_names) . "\n";

    unless (close($fh)) {
      croak("Can't write $group_file: $!");
    }

  } else {
    croak("Can't open $group_file: $!");
  }

  if ($existed) {
    # Restore previous perms
    unless (chmod($prev_mode, $group_file)) {
      croak("Can't set perms on $group_file: $!");
    }

  } else {
    # Set correct perms
    unless (chmod(0440, $group_file)) {
      croak("Can't set perms on $group_file: $!");
    }
  }
}

sub auth_user_write {
  my $user_file = shift;
  croak("Missing user file argument") unless $user_file;
  my $user_name = shift;
  croak("Missing user name argument") unless $user_name;
  my $user_passwd = shift;
  croak("Missing user password argument") unless defined($user_passwd);
  my $user_id = shift;
  croak("Missing user ID argument") unless defined($user_id);
  my $group_id = shift;
  croak("Missing group ID argument") unless defined($group_id);
  my $home = shift;
  croak("Missing home directory argument") unless $home;
  my $shell = shift;
  croak("Missing shell argument") unless $shell;
  my $gecos = shift;
  $gecos = '' unless defined($gecos);

  my $existed = -f $user_file;
  my $prev_mode;

  my $passwd = get_passwd($user_passwd);

  if ($existed) {
    # Get current permissions
    $prev_mode = (stat($user_file))[2];
 
    # Set needed permissions
    unless (chmod(0666, $user_file)) {
      croak("Can't set perms on $user_file: $!");
    }
  }

  if (open(my $fh, ">> $user_file")) {
    my $pw_entry = join(':', ($user_name, $passwd, $user_id, $group_id,
      $gecos, $home, $shell));

    print $fh "$pw_entry\n";
    unless (close($fh)) {
      croak("Can't write $user_file: $!");
    }

  } else {
    croak("Can't open $user_file: $!");
  }

  if ($existed) {
    # Restore previous perms
    unless (chmod($prev_mode, $user_file)) {
      croak("Can't set perms on $user_file: $!");
    }

  } else {
    # Set correct perms
    unless (chmod(0440, $user_file)) {
      croak("Can't set perms on $user_file: $!");
    }
  }
}

sub config_get_identity {
  my ($user, $group);

  unless ($< == 0) {
    # Use $> (effective UID) rather than $< (real UID)
    my $ruid = $>;
    $user = (getpwuid($ruid))[0];

    # Similarly, use $) (effective GID) rather than $( (real GID)
    my $rgid = (split/\s+/, $))[0];
    $group = (getgrgid($rgid))[0];

  } else {
    # If the real user ID is root, try to use some non-root user
    my $users = [qw(daemon www ftp adm nobody)];
    my $groups = [qw(daemon www ftp staff adm nogroup)];
    my $candidate;

    foreach $candidate (@$users) {
      my $candidate_uid = (getpwnam($candidate))[2];

      if ($candidate_uid != 0) {
        $user = $candidate;
        last;
      }
    }

    foreach $candidate (@$groups) {
      my $candidate_gid = (getgrnam($candidate))[2];

      if ($candidate_gid != 0) {
        $group = $candidate;
        last;
      }
    }
  }

  return ($user, $group);
}

sub config_write_subsection {
  my $fh = shift;
  my $type = shift;
  my $config = shift;
  my $indent = shift;

  if ($type eq 'Directory') {
    my $sections = $config;

    foreach my $dir (keys(%$sections)) {
      print $fh "$indent<Directory $dir>\n";

      my $section = $sections->{$dir};

      if (ref($section) eq 'HASH') {
        while (my ($dir_k, $dir_v) = each(%$section)) {
          if (ref($dir_v) eq 'HASH' ||
              ref($dir_v) eq 'ARRAY') {
            config_write_subsection($fh, $dir_k, $dir_v, "$indent  ");

          } else {
            print $fh "$indent  $dir_k $dir_v\n";
          }
        }

      } elsif (ref($section) eq 'ARRAY') {
        foreach my $line (@$section) {
          print $fh "$indent  $line\n";
        }
      }

      print $fh "$indent</Directory>\n";
    }

  } elsif ($type eq 'Limit') {
    my $sections = $config;

    foreach my $limits (keys(%$sections)) {
      print $fh "$indent<Limit $limits>\n";

      my $section = $sections->{$limits};

      if (ref($section) eq 'HASH') {
        while (my ($limit_k, $limit_v) = each(%$section)) {

          if (ref($limit_v) eq 'HASH' ||
              ref($limit_v) eq 'ARRAY') {
            config_write_subsection($fh, $limit_k, $limit_v, "$indent  ");

          } else {
            print $fh "$indent  $limit_k $limit_v\n";
          }
        }

      } elsif (ref($section) eq 'ARRAY') {
        foreach my $line (@$section) {
          print $fh "$indent  $line\n";
        }
      }

      print $fh "$indent</Limit>\n";
    }

  } elsif ($type eq 'Class') {
    my $sections = $config;

    foreach my $class (keys(%$sections)) {
      print $fh "<Class $class>\n";

      my $section = $sections->{$class};

      if (ref($section) eq 'HASH') {
        while (my ($class_k, $class_v) = each(%$section)) {
          print $fh "  $class_k $class_v\n";
        }

      } elsif (ref($section) eq 'ARRAY') {
        foreach my $line (@$section) {
          print $fh "  $line\n";
        }
      }

      print $fh "</Class>\n";
    }
  }
}

sub config_write {
  my $path = shift;
  my $config = shift;

  # The $opts hash can be used to tell this function to NOT write
  # default config values.
  my $opts = shift;
  $opts = {} unless defined($opts);

  my ($user_name, $group_name) = config_get_identity();

  # Set a bunch of defaults, unless overridden by the caller
  my $port;

  if (ref($config) eq 'HASH') {
    unless (defined($config->{Port})) {
      my $dynport = get_high_numbered_port();
      $config->{Port} = $dynport;
    }

    $port = $config->{Port};

    unless (defined($config->{User})) {
      # Handle User names that may contain embedded backslashes and spaces
      $user_name =~ s/\\/\\\\/g;
      $config->{User} = "\"$user_name\"";

      if ($< == 0) {
        $config->{User} = 'root';
      }
    }

    unless (defined($config->{Group})) {
      # Handle Group names that may contain embedded backslashes and spaces
      $group_name =~ s/\\/\\\\/g;
      $config->{Group} = "\"$group_name\"";
    }

    unless ($opts->{NoAllowOverride}) {
      unless (defined($config->{AllowOverride})) {
        $config->{AllowOverride} = 'off';
      }
    }

    unless (defined($config->{DefaultAddress})) {
      $config->{DefaultAddress} = '127.0.0.1';
    }

    unless (defined($config->{DefaultServer})) {
      $config->{DefaultServer} = 'on';
    }

    unless (defined($config->{RequireValidShell})) {
      $config->{RequireValidShell} = 'off';
    }

    unless (defined($config->{ServerType})) {
      $config->{ServerType} = 'standalone';
    }

    unless (defined($config->{TimeoutIdle})) {
      $config->{TimeoutIdle} = '10';
    }

    unless (defined($config->{TimeoutLinger})) {
      $config->{TimeoutLinger} = '1';
    }

    unless (defined($config->{TransferLog})) {
      $config->{TransferLog} = 'none';
    }

    unless (defined($config->{UseFtpUsers})) {
      $config->{UseFtpUsers} = 'off';
    }

    if (feature_have_feature_enabled('ipv6')) {
      unless (defined($config->{UseIPv6})) {
        $config->{UseIPv6} = 'off';
      }
    }

    unless (defined($config->{UseReverseDNS})) {
      $config->{UseReverseDNS} = 'off';
    }

    unless (defined($config->{WtmpLog})) {
      $config->{WtmpLog} = 'off';
    }

  } elsif (ref($config) eq 'ARRAY') {
    unless (grep(/Port /, @$config) > 0) {
      $port = get_high_numbered_port();
      push(@$config, "Port $port");
    }

    unless (grep(/^User /, @$config) > 0) {
      push(@$config, "User $user_name");

      if ($< == 0) {
        push(@$config, "User root");
      }
    }

    unless (grep(/^Group /, @$config) > 0) {
      push(@$config, "Group $group_name");
    }

    unless (grep(/^AlloOverride/, @$config) > 0) {
      push(@$config, "AllowOverride off");
    }

    unless (grep(/^DefaultAddress/, @$config) > 0) {
      push(@$config, "DefaultAddress 127.0.0.1");
    }

    unless (grep(/^DefaultServer/, @$config) > 0) {
      push(@$config, "DefaultServer on");
    }

    unless (grep(/^RequireValidShell/, @$config) > 0) {
      push(@$config, "RequireValidShell off");
    }

    unless (grep(/^ServerType/, @$config) > 0) {
      push(@$config, "ServerType standalone");
    }

    unless (grep(/^TimeoutIdle/, @$config) > 0) {
      push(@$config, "TimeoutIdle 10");
    }

    unless (grep(/^TimeoutLinger/, @$config) > 0) {
      push(@$config, "TimeoutLinger 1");
    }

    unless (grep(/^TransferLog/, @$config) > 0) {
      push(@$config, "TransferLog none");
    }

    unless (grep(/UseFtpUsers/, @$config) > 0) {
      push(@$config, "UseFtpUsers off");
    }

    if (feature_have_feature_enabled('ipv6')) {
      unless (grep(/UseIPv6/, @$config) > 0) {
        push(@$config, "UseIPv6 off");
      }
    }

    unless (grep(/UseReverseDNS/, @$config) > 0) {
      push(@$config, "UseReverseDNS off");
    }

    unless (grep(/WtmpLog/, @$config) > 0) {
      push(@$config, "WtmpLog off");
    }
  }

  my $abs_path = File::Spec->rel2abs($path);

  if (open(my $fh, "> $abs_path")) {
    my $timestamp = scalar(localtime());

    print $fh "# Auto-generated proftpd config file\n";
    print $fh "# Written on: $timestamp\n\n";

    if (ref($config) eq 'HASH') {
      while (my ($k, $v) = each(%$config)) {
        if ($k eq 'IfModules') {
          my $modules = $v;

          foreach my $mod (keys(%$modules)) {
            print $fh "<IfModule $mod>\n";

            my $section = $modules->{$mod};

            if (ref($section) eq 'HASH') {
              while (my ($mod_k, $mod_v) = each(%$section)) {

                if (ref($mod_v) eq 'HASH' ||
                    ref($mod_v) eq 'ARRAY') {
                  config_write_subsection($fh, $mod_k, $mod_v, "  ");

                } else {
                  print $fh "  $mod_k $mod_v\n";
                }
              }

            } elsif (ref($section) eq 'ARRAY') {
              foreach my $line (@$section) {
                print $fh "  $line\n";
              }
            }

            print $fh "</IfModule>\n";
          }

        } elsif ($k eq 'Anonymous') {
          my $sections = $v;

          foreach my $anon (keys(%$sections)) {
            print $fh "<Anonymous $anon>\n";

            my $section = $sections->{$anon};

            if (ref($section) eq 'HASH') {
              while (my ($anon_k, $anon_v) = each(%$section)) {
                if (ref($anon_v) eq 'HASH' ||
                    ref($anon_v) eq 'ARRAY') {
                  config_write_subsection($fh, $anon_k, $anon_v, "  ");

                } else {
                  print $fh "  $anon_k $anon_v\n";
                }
              }

            } elsif (ref($section) eq 'ARRAY') {
              foreach my $line (@$section) {
                print $fh "  $line\n";
              }
            }

            print $fh "</Anonymous>\n";
          }

        } elsif ($k eq 'Directory') {
          my $sections = $v;

          foreach my $dir (keys(%$sections)) {
            print $fh "<Directory $dir>\n";

            my $section = $sections->{$dir};

            if (ref($section) eq 'HASH') {
              while (my ($dir_k, $dir_v) = each(%$section)) {
                if (ref($dir_v) eq 'HASH' ||
                    ref($dir_v) eq 'ARRAY') {
                  config_write_subsection($fh, $dir_k, $dir_v, "  ");

                } else {
                  print $fh "  $dir_k $dir_v\n";
                }
              }

            } elsif (ref($section) eq 'ARRAY') {
              foreach my $line (@$section) {
                print $fh "  $line\n";
              }
            }

            print $fh "</Directory>\n";
          }

        } elsif ($k eq 'Limit') {
          my $sections = $v;

          foreach my $limits (keys(%$sections)) {
            print $fh "<Limit $limits>\n";

            my $section = $sections->{$limits};

            if (ref($section) eq 'HASH') {
              while (my ($limit_k, $limit_v) = each(%$section)) {
                if (ref($limit_v) eq 'HASH' ||
                    ref($limit_v) eq 'ARRAY') {
                  config_write_subsection($fh, $limit_k, $limit_v, "  ");

                } else {
                  print $fh "  $limit_k $limit_v\n";
                }
              }

            } elsif (ref($section) eq 'ARRAY') {
              foreach my $line (@$section) {
                print $fh "  $line\n";
              }
            }

            print $fh "</Limit>\n";
          }

        } elsif ($k eq 'Class') {
          my $sections = $v;

          foreach my $class (keys(%$sections)) {
            print $fh "<Class $class>\n";

            my $section = $sections->{$class};

            if (ref($section) eq 'HASH') {
              while (my ($class_k, $class_v) = each(%$section)) {
                print $fh "  $class_k $class_v\n";
              }

            } elsif (ref($section) eq 'ARRAY') {
              foreach my $line (@$section) {
                print $fh "  $line\n";
              }
            }

            print $fh "</Class>\n";
          }

        } elsif ($k eq 'Global') {
          print $fh "<Global>\n";

          foreach my $name (keys(%$v)) {
            print $fh "  $name $v->{$name}\n";
          }

          print $fh "</Global>\n";
 
        } else {
          print $fh "$k $v\n";
        }
      }

    } elsif (ref($config) eq 'ARRAY') {
      foreach my $line (@$config) {
        print $fh "$line\n";
      }
    }

    unless (close($fh)) {
      croak("Error writing $abs_path: $!");
    }

  } else {
    croak("Error opening $abs_path: $!");
  }

  if (wantarray()) {
    return ($port, $user_name, $group_name);
  }

  return 1;
}

sub feature_get_shared_modules {
  my $proftpd_bin = get_proftpd_bin();

  my $shared_modules = [];

  my $configure_args;
  if (open(my $cmdh, "$proftpd_bin -V |")) {
    while (my $line = <$cmdh>) {
      chomp($line);

      next unless $line =~ /^\s+configure (.*?)$/;

      $configure_args = $1;
      last;
    }

    close($cmdh);

    my $args = [split(' ', $configure_args)];

    foreach my $arg (@$args) {
      $arg =~ s/^'//;
      $arg =~ s/'$//;

      if ($arg =~ /^\-\-with\-shared=(.*?)$/) {
        my $module_list = $1;

        $shared_modules = [split(':', $module_list)];
      }
    }

    return $shared_modules;

  } else {
    croak("Error listing features");
  }
}

sub feature_get_version {
  my $proftpd_bin = get_proftpd_bin();

  my ($version, $label);

  if (open(my $cmdh, "$proftpd_bin -V |")) {

    while (my $line = <$cmdh>) {
      chomp($line);

      next unless $line =~ /\s+Version:\s+(\S+)\s+\(\S+\)$/;

      $version = $1;
      $label = $2;
      last;
    }

    close($cmdh);

    if (wantarray()) {
      return ($version, $label);

    } else {
      return $version;
    }

  } else {
    croak("Error listing features");
  }
}

sub feature_have_feature_enabled {
  my $feat = shift;

  my $proftpd_bin = get_proftpd_bin();

  if (open(my $cmdh, "$proftpd_bin -V |")) {
    my $feat_list;

    while (my $line = <$cmdh>) {
      chomp($line);

      next unless $line =~ /\s+(\-|\+)\s+(\S+)\s+support/;

      my $flag = $1;
      my $feature = $2;

      if ($flag eq '+') {
        push(@$feat_list, $feature);

        # Special-case hack for FIPS-enabled OpenSSL
        if ($feature =~ /OpenSSL/i) {
          if ($line =~ /\(FIPS enabled\)/) {
            push(@$feat_list, "OpenSSL_FIPS");             
          }
        }
      }
    }

    close($cmdh);

    my $matches = grep { /^$feat$/i } @$feat_list;
    return $matches;

  } else {
    croak("Error listing features");
  }
}

sub feature_get_compiled_modules {
  my $proftpd_bin = get_proftpd_bin();
  my $mod_list = [];

  if (open(my $cmdh, "$proftpd_bin -l |")) {
    while (my $line = <$cmdh>) {
      chomp($line);

      next if $line =~ /Compiled\-in/;
      $line =~ s/^\s+//;

      push(@$mod_list, $line);
    }

    close($cmdh);

  } else {
    croak("Error listing compiled modules");
  }

  return $mod_list;
}

sub feature_have_module_compiled {
  my $module = shift;

  my $mod_list = feature_get_compiled_modules();
  my $matches = grep { /^$module$/ } @$mod_list;
  return $matches;
}

sub feature_have_module_loaded {
  my $module = shift;
  my $config_file = shift;

  my $proftpd_bin = get_proftpd_bin();

  if (open(my $cmdh, "$proftpd_bin -vv -c $config_file |")) {
    my $mod_list;

    while (my $line = <$cmdh>) {
      chomp($line);

      next unless $line =~ /^\s+mod_/;
      $line =~ s/^\s+//;

      push(@$mod_list, $line);

      # Need to be able to handle the listing info for a module which
      # includes the module version, rather than a ".c" ending.
      my $alt_module = $module;
      $alt_module =~ s/\.c$/\//g;

      my $res = 0;
      if (grep { /^($module$|$alt_module)/ } @$mod_list) {
        $res = 1;
      }

      close($cmdh);
      return $res;
    }

    close($cmdh);

  } else {
    croak("Error listing loaded modules");
  }
}

sub server_signal {
  my $pid_file = shift;
  croak("Missing PID file argument") unless $pid_file;
  my $signal_name = shift;
  $signal_name = 'HUP' unless $signal_name;

  my $pid;
  if (open(my $fh, "< $pid_file")) {
    $pid = <$fh>;
    chomp($pid);
    close($fh);

  } else {
    croak("Can't read $pid_file: $!");
  }

  my $cmd = "kill -$signal_name $pid";

  if ($ENV{TEST_VERBOSE}) {
    my $label = 'Signalling';
    if ($signal_name eq 'HUP') {
      $label = 'Restarting';
    }

    print STDERR "$label server: $cmd\n";
  }

  my @output = `$cmd`;
  if ($? != 0) {
    return undef;
  }

  return 1;
}

sub server_restart {
  my $pid_file = shift;
  croak("Missing PID file argument") unless $pid_file;

  return server_signal($pid_file, 'HUP');
}

sub server_start {
  my $config_file = shift;
  croak("Missing config file argument") unless $config_file;
  my $pid_file = shift;
  my $server_opts = shift;
  $server_opts = {} unless defined($server_opts);

  # Make sure that the config file is an absolute path
  my $abs_config_file = File::Spec->rel2abs($config_file);

  my $proftpd_bin = get_proftpd_bin();

  my $cmd = '';

  if (defined($server_opts->{env})) {
    my $envs = $server_opts->{env};

    while (my ($key, $value) = each(%$envs)) {
      # Assume Bourne-shell syntax
      $cmd .= "$key=$value ";
    }
  }

  my $quiet = '-q';
  if ($ENV{TEST_VERBOSE}) {
    $quiet = '';
  }

  $cmd .= "$proftpd_bin $quiet -c $abs_config_file";

  if (defined($server_opts->{define})) {
    my $defines = $server_opts->{define};

    foreach my $define (@$defines) {
      $cmd .= " -D$define";
    }
  }

  if ($ENV{TEST_VERBOSE}) {
    $cmd .= " -d10";

  } else {
    $cmd .= " > /dev/null 2>&1";
  }

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Starting server: $cmd\n";
  }

  my @output = `$cmd`;

  # Ideally we would use the return value from the command to determine
  # whether the server started successfully or not.  But proftpd's exit
  # codes are not that nice yet, sadly.  Instead, we'll use the PidFile
  # written out by the server, if provided.
  if ($pid_file) {
    sleep(1);

    my $pid;
    if (open(my $fh, "< $pid_file")) {
      $pid = <$fh>;
      chomp($pid);
      close($fh);

    } else {
      croak("Can't read $pid_file: $!");
    }

    $cmd = "kill -0 $pid";

    if ($ENV{TEST_VERBOSE}) {
      print STDERR "Testing server: $cmd\n";

    } else {
      $cmd .= " 2>/dev/null";
    }

    @output = `$cmd`;
    if ($? != 0) {
      croak("server failed to start");
    }
  }
}

sub server_stop {
  my $pid_file = shift;
  my $nowait = shift;
  $nowait = 0 unless defined($nowait);

  my $pid;
  if (open(my $fh, "< $pid_file")) {
    $pid = <$fh>;
    chomp($pid);
    close($fh);

  } else {
    croak("Can't read $pid_file: $!");
  }

  my $cmd = "kill -TERM $pid";

  if ($ENV{TEST_VERBOSE}) {
    print STDERR "Stopping server: $cmd\n";

  } else {
    $cmd .= " 2>/dev/null";
  }

  my @output = `$cmd`;
  unless ($? == 0) {
    return undef;
  }

  unless ($nowait) {
    # Wait until the PidFile has been deleted by the shutting-down server.
    # We use select(), rather than alarm(), to do sub-second waits.
    #
    # We will wait for a period of up to 2 seconds, but not longer.
    my $now = time();

    while ((time() - $now) < 2 &&
           -e $pid_file) {
      select(undef, undef, undef, 0.5);
    }
  }

  return 1;
}

my $server_wait_timeout = 0;
sub server_wait_alarm {
  croak("Test timed out after $server_wait_timeout secs");
}

sub server_wait {
  my $config_file = shift;
  my $rfh = shift;
  $server_wait_timeout = shift;
  my $server_opts = {};

  # Check to see if the timeout argument is a hashref (for additional
  # server_start parameters) or not.  If not, it's just the timeout.

  if (defined($server_wait_timeout)) {
    if (ref($server_wait_timeout) eq 'HASH') {
      $server_opts = $server_wait_timeout;

      if (defined($server_opts->{timeout})) {
        $server_wait_timeout = $server_opts->{timeout};

      } else {
        $server_wait_timeout = 10;
      }
    }

  } else {
    $server_wait_timeout = 10;
  }

  # Start server
  server_start($config_file, undef, $server_opts);

  $SIG{ALRM} = \&server_wait_alarm;
  alarm($server_wait_timeout);

  # Wait until we receive word from the child that it has finished its test.
  while (my $msg = <$rfh>) {
    chomp($msg);

    if ($msg eq 'done') {
      last;
    }
  }

  alarm(0);
  $SIG{ALRM} = 'DEFAULT';
  return 1;
}

sub test_append_logfile {
  my $log_file = shift;
  my $ex = shift;

  my ($infh, $outfh); 

  my $out_file = File::Spec->rel2abs('tests.log');

  unless (open($outfh, ">> $out_file")) {
    croak("Can't append to $out_file: $!");
  }

  my ($pkg, $filename, $lineno, $func) = (caller(1))[0, 1, 2, 3];
  if ($func =~ /test_cleanup/) {
    ($pkg, $filename, $lineno, $func) = (caller(2))[0, 1, 2, 3];
  }

  print $outfh "-----BEGIN $func-----\n";

  if (open($infh, "+< $log_file")) {
    while (my $line = <$infh>) {
      print $outfh $line;
    }

    close($infh);
  }

  # If an exception was provided, write that out to the log file, too.
  if (defined($ex)) {
    print $outfh "\nException:\n\t$ex\n";
  }

  print $outfh "-----END $func-----\n";

  unless (close($outfh)) {
    croak("Can't write $out_file: $!");
  }
}

sub test_cleanup {
  my $log_file = shift;
  my $ex = shift;
  my $keep_logfile = shift;
  $keep_logfile = 0 unless $keep_logfile;

  if ($ex) {
    test_append_logfile($log_file, $ex);
    unlink($log_file);

    croak($ex);
  }

  unlink($log_file) unless $keep_logfile;
}

sub test_get_logfile {
  # Returns the testcase-specific logfile name to use
  my $depth = shift;
  $depth = 1 unless defined($depth);

  my ($pkg, $filename, $lineno, $func) = (caller($depth))[0, 1, 2, 3];

  # We use the function name as the basis for the testcase-specific log
  # file name.  We ignore the first two parts (which are always 'ProFTPD' and
  # 'Tests'), and merge the rest into a log file name.

  my @parts = split('::', $func);
  my $logfile = File::Spec->rel2abs(join('_', @parts) . '.log');

  return $logfile;
}

sub test_msg {
  my $msg = shift;

  my ($pkg, $file, $lineno) = caller();

  return "$msg (at $file:$lineno)";
}

sub test_setup {
  my $tmpdir = shift;
  croak("Missing temporary directory argument") unless $tmpdir;
  my $name = shift;
  croak("Missing test name argument") unless $name;
  my $user = shift;
  $user = 'proftpd' unless defined($user);
  my $passwd = shift;
  $passwd = 'test' unless defined($passwd);
  my $group = shift;
  $group = 'ftpd' unless defined($group);
  my $uid = shift;
  $uid = 500 unless defined($uid);
  my $gid = shift;
  $gid = 500 unless defined($gid);
  my $home_dir = shift;

  my $config_file = "$tmpdir/$name.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/$name.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/$name.scoreboard");
  my $log_file = test_get_logfile(2);
  my $auth_user_file = File::Spec->rel2abs("$tmpdir/$name.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/$name.group");

  # If the caller provides the home directory, it is ASSUMED that they will
  # have created it.
  unless (defined($home_dir)) {
    $home_dir = File::Spec->rel2abs($tmpdir);

    # Make sure that, if we're running as root, that the home directory has
    # permissions/privs set for the account we create
    if ($< == 0) {
      unless (chmod(0755, $home_dir)) {
        croak("Can't set perms on $home_dir to 0755: $!");
      }

      unless (chown($uid, $gid, $home_dir)) {
        croak("Can't set owner of $home_dir to $uid/$gid: $!");
      }
    }
  }

  auth_user_write($auth_user_file, $user, $passwd, $uid, $gid, $home_dir,
    '/bin/bash');
  auth_group_write($auth_group_file, $group, $gid, $user);

  my $setup = {
    auth_user_file => $auth_user_file,
    auth_group_file => $auth_group_file,
    config_file => $config_file,
    gid => $gid,
    group => $group,
    home_dir => $home_dir,
    log_file => $log_file,
    passwd => $passwd,
    pid_file => $pid_file,
    scoreboard_file => $scoreboard_file,
    uid => $uid,
    user => $user,
  };

  return $setup;
}

sub testsuite_empty_test {
}

sub testsuite_get_runnable_tests {
  my $tests = shift;
  return undef unless $tests;

  # Special handling of any 'feature_*' test classes; if the compiled proftpd
  # has these features enabled, include those tests.
  my $skip_tests = [];
  foreach my $test (keys(%$tests)) {
    foreach my $class (@{ $tests->{$test}->{test_class} }) {
      if ($class =~ /^feature_(\S+)$/) {
        my $feat = $1;

        unless (feature_have_feature_enabled($feat)) {
          push(@$skip_tests, $test);
          last;
        }
      }
    }

    foreach my $skip_test (@$skip_tests) {
      delete($tests->{$skip_test});
    }
  }

  # Special handling of any 'mod_*' test classes; if the compiled proftpd
  # has these as static modules, include those tests.
  $skip_tests = [];
  foreach my $test (keys(%$tests)) {
    foreach my $class (@{ $tests->{$test}->{test_class} }) {
      if ($class =~ /^mod_\S+$/) {
        my $module = $class;

        if ($module !~ /\.c$/) {
          $module .= '.c';
        }

        unless (feature_have_module_compiled($module)) {
          push(@$skip_tests, $test);
          last;
        }
      }
    }

    foreach my $skip_test (@$skip_tests) {
      delete($tests->{$skip_test});
    }
  }

  # Special handling of the 'norootprivs' test class; unless we are running
  # as non-root, we should exclude those test cases.
  if ($< == 0) {
    $skip_tests = [];
    foreach my $test (keys(%$tests)) {
      my $ok = 1;
      foreach my $test_class (@{ $tests->{$test}->{test_class} }) {
        if ($test_class eq 'norootprivs') {
          $ok = 0;
          last;
        }
      }

      unless ($ok) {
        push(@$skip_tests, $test);
      }
    }
 
    foreach my $skip_test (@$skip_tests) {
      delete($tests->{$skip_test});
    }
  }

  # Special handling of any 'os_*' test classes; if the machine running
  # these tests matches the configured OS, include these tests.
  $skip_tests = [];
  foreach my $test (keys(%$tests)) {
    foreach my $class (@{ $tests->{$test}->{test_class} }) {
      if ($class =~ /^os_(\S+)$/) {
        my $os = $1;

        unless ($os =~ /$^O/i) {
          push(@$skip_tests, $test);
          last;
        }
      }
    }

    foreach my $skip_test (@$skip_tests) {
      delete($tests->{$skip_test});
    }
  }

  # Special handling of the 'rootprivs' test class: unless we are running
  # as root, we should exclude those test cases.
  unless ($< == 0) {
    $skip_tests = [];
    foreach my $test (keys(%$tests)) {
      my $ok = 1;
      foreach my $test_class (@{ $tests->{$test}->{test_class} }) {
        if ($test_class eq 'rootprivs') {
          $ok = 0;
          last;
        }
      }

      unless ($ok) {
        push(@$skip_tests, $test);
      }
    }
 
    foreach my $skip_test (@$skip_tests) {
      delete($tests->{$skip_test});
    }
  }

  my $runnables = [];

  if (defined($ENV{PROFTPD_TEST_ENABLE_CLASS})) {
    my $test_classes = [split(':', $ENV{PROFTPD_TEST_ENABLE_CLASS})];

    foreach my $test_class (@$test_classes) {
      foreach my $test (keys(%$tests)) {
        foreach my $class (@{ $tests->{$test}->{test_class} }) {
          if ($class eq $test_class) {
            push(@$runnables, $test);
            last;
          }
        }
      }
    }

  } else {
    $runnables = [keys(%$tests)];
  }

  if (defined($ENV{PROFTPD_TEST_DISABLE_CLASS})) {
    my $test_classes = [split(':', $ENV{PROFTPD_TEST_DISABLE_CLASS})];
    my $new_runnables = [];

    foreach my $test (@$runnables) {
      my $skip_test = 0;

      foreach my $test_class (@$test_classes) {
        foreach my $class (@{ $tests->{$test}->{test_class} }) {
          if ($class eq $test_class) {
            $skip_test = 1;
            last;
          }

          if ($skip_test) {
            last;
          }
        }

        unless ($skip_test) {
          push(@$new_runnables, $test);
        }
      }
    }

    $runnables = $new_runnables;
  }

  if (scalar(@$runnables) > 0) {
    $runnables = [sort { $tests->{$a}->{order} <=> $tests->{$b}->{order} } @$runnables];
  } else { 
    $runnables = [qw(testsuite_empty_test)];
  }

  return @$runnables;
}

sub testsuite_get_tmp_dir {
  ++$testno;

  my $tmpdir = tempdir(
    "proftpd-test-$$-test$testno-XXXXXXXXXX",
    TMPDIR => 1,
    CLEANUP => 0,
  );

  unless (chmod(0755, $tmpdir)) {
    croak("Can't chmod tmp directory $tmpdir: $!");
  }

  return $tmpdir;
}

1;
