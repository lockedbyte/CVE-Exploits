package ProFTPD::Tests::Modules::mod_facl;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use File::Copy;
use File::Path qw(mkpath);
use File::Spec;
use IO::Handle;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  facl_bug4303 => {
    order => ++$order,
    test_class => [qw(forking os_linux)],
  },

};

sub new {
  return shift()->SUPER::new(@_);
}

sub list_tests {
  return testsuite_get_runnable_tests($TESTS);
}

sub facl_bug4303 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  my $setup = test_setup($tmpdir, 'facl');

  my $sub_dir = File::Spec->rel2abs("$tmpdir/sub.d");
  mkpath($sub_dir);

  # Follow the reproduction recipe in Bug#4303.
  my $cmd = "setfacl -m u:`tail -n1 /etc/passwd | cut -d: -f1`:rwx $sub_dir";
  `$cmd`;

  $cmd = "setfacl -m g::rx $sub_dir";
  `$cmd`;

  $cmd = "setfacl -m g:`tail -n1 /etc/passwd | cut -d: -f1`:rwx $sub_dir";
  `$cmd`;

  $cmd = "setfacl -m m::rwx $sub_dir";
  `$cmd`;

  $cmd = "getfacl --access $sub_dir | setfacl -d -M- $sub_dir";
  `$cmd`;

  $cmd = "getfacl $sub_dir";
  my $results = [`$cmd`];
  if ($ENV{TEST_VERBOSE}) {
    print STDERR "# Results for command: $cmd:\n";
    print STDERR join('', @$results), "\n";
  }

  my $test_dir = File::Spec->rel2abs("$tmpdir/sub.d/test.d");

  my $config = {
    PidFile => $setup->{pid_file},
    ScoreboardFile => $setup->{scoreboard_file},
    SystemLog => $setup->{log_file},
    TraceLog => $setup->{log_file},
    Trace => 'fsio:20 facl:20',

    AuthUserFile => $setup->{auth_user_file},
    AuthGroupFile => $setup->{auth_group_file},

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
      $client->mkd('sub.d/test.d');
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

  $cmd = "getfacl $test_dir";
  $results = [`$cmd`];
  if ($ENV{TEST_VERBOSE}) {
    print STDERR "# Results for command: $cmd:\n";
    print STDERR join('', @$results), "\n";
  }

  my $seen = grep(/^mask::rwx$/, @$results);
  $self->assert($seen == 1,
    "Expected 'mask::rwx' not appearing in getfacl results");
  test_cleanup($setup->{log_file}, $ex);
}

1;
