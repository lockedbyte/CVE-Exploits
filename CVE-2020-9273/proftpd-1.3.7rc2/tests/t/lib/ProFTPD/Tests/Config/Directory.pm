package ProFTPD::Tests::Config::Directory;

use lib qw(t/lib);
use base qw(Test::Unit::TestCase ProFTPD::TestSuite::Child);
use strict;

use Data::Dumper;
use File::Path qw(mkpath rmtree);
use File::Spec;
use IO::Handle;
use Time::HiRes qw(gettimeofday tv_interval);

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  dir_wide_layout => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  # dir_deep_layout
  # dir_wide_deep_layout
  #
  # I suspect that, due to the nature of the parser, the order in which
  # the <Directory> sections appear in the config can affect performance.
  # If the _last_ <Directory> section is for the most common path referenced,
  # it could mean longer traversal times (for each lookup) before the
  # match is made.
};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub set_up {
  my $self = shift;
  $self->{tmpdir} = testsuite_get_tmp_dir();

  # Create temporary scratch dir
  eval { mkpath($self->{tmpdir}) };
  if ($@) {
    my $abs_path = File::Spec->rel2abs($self->{tmpdir});
    die("Can't create dir $abs_path: $@");
  }
}

sub tear_down {
  my $self = shift;

  # Remove temporary scratch dir
  if ($self->{tmpdir}) {
    eval { rmtree($self->{tmpdir}) };
  }

  undef $self;
}

my ($prev_name, $prev_namelen);

sub get_name {
  my $name_len = shift;
  my $inc = shift;

  # If the requested name length has changed, start over
  if ($name_len != $prev_namelen) {
    $prev_name = undef;
  }

  if (defined($prev_name)) {
    # Split the name into its individual chars, in reverse order
    my @chars = reverse(split('', $prev_name));

    # Increment the first char, then reassemble the name.  We only want
    # ASCII characters (i.e. A-Za-z inclusive).  So if the incremented first
    # char is outside the range, reset the first char to the range start, and
    # increment the next char.

    for (my $i = 0; $i < $prev_namelen; $i++) {
      my $char = $chars[$i];
      my $val = ord($char);

      $char = chr(++$val);

      my $reset_char = 0;
      while ($char !~ /[A-Za-z]/o) {
        ++$val;
        if ($val > 122) {
          # Too far; reset to 'A'.
          $val = 65;
          $reset_char = 1;
        }

        $char = chr($val);
      }

      $chars[$i] = $char;

      unless ($reset_char) {
        last;
      }
    }

    $prev_name = join('', reverse(@chars));

  } else {
    $prev_name = "A" x $name_len;
    $prev_namelen = $name_len;
  }

  return $prev_name;
}

sub dir_wide_layout {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/dir.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/dir.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/dir.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/dir.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/dir.group");

  my $user = 'proftpd';
  my $passwd = 'test';
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
  auth_group_write($auth_group_file, 'ftpd', $gid, $user);

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,
    TraceLog => $log_file,
    Trace => 'directory:10',

    AuthUserFile => $auth_user_file,
    AuthGroupFile => $auth_group_file,

    DefaultChdir => '~',

    Directory => {
      '/' => {
        Umask => '066 077',
      },
    },

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  # Append our mess of many wide <Directory> sections to the config:
  #
  #  <Directory /path/to/a>
  #    Umask 066 077
  #  </Directory>
  #
  #  <Directory/path/to/b>
  #    Umask 066 077
  #  </Directory>

  my $target_dir;

  if (open(my $fh, ">> $config_file")) {
    my $width = 1000;
    my $namelen = 3;

    for (my $i = 0; $i < $width; $i++) {
      my $target_dir = get_name($namelen, 1);
      my $dir = File::Spec->rel2abs("$tmpdir/$target_dir");
      mkpath($dir);

      print $fh <<EOD;
<Directory ~/$target_dir>
  Umask 066 077
</Directory>
EOD
    }

    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  # To test the worst-case scenario, the target directory (to which we will
  # write a file) should be the _last_ in the list.

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

      my $start_time = [gettimeofday()];

      my $conn = $client->stor_raw("$target_dir/test.txt");
      unless ($conn) {
        die("Failed to STOR $target_dir/test.txt: " . $client->response_code() .
          " " . $client->response_msg());
      }

      my $elapsed = tv_interval($start_time);
print STDERR "Elapsed: ", Dumper($elapsed);

      $conn->close();

      $resp_code = $client->response_code();
      $resp_msg = $client->response_msg();

      my $expected;

      $expected = 226;
      $self->assert($expected == $resp_code,
        test_msg("Expected '$expected', got '$resp_code'"));

      $expected = "Transfer complete";
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

  unlink($log_file);
}

1;
