package ProFTPD::Tests::HTTP;

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
  http_connect => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  http_delete => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  http_get => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  http_head => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  http_options => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  http_patch => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  http_post => {
    order => ++$order,
    test_class => [qw(bug forking)],
  },

  http_put => {
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
  #  HTTP-Request
  #  LWP-UserAgent

  my $required = [qw(
    HTTP::Request
    LWP::UserAgent
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

sub test_http_req {
  my $self = shift;
  my $tmpdir = shift;
  my $req = shift;

  my $config_file = "$tmpdir/http.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/http.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/http.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/http.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/http.group");

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

  # Open pipes, for use between the parent and child processes.  Specifically,
  # the child will indicate when it's done with its test by writing a message
  # to the parent.
  my ($rfh, $wfh);
  unless (pipe($rfh, $wfh)) {
    die("Can't open pipe: $!");
  }

  require LWP::UserAgent;
  require HTTP::Request;

  my $ex;

  # Fork child
  $self->handle_sigchld();
  defined(my $pid = fork()) or die("Can't fork: $!");
  if ($pid) {
    eval {
      sleep(1);

      # To reproduce Bug#4143, we only need to connect to the server,
      # then issue an HTTP request.

      my $client = LWP::UserAgent->new(
        keep_alive => 1,
        timeout => 10,
      );
      $client->default_header('Host' => "127.0.0.1:$port");

      my $req = HTTP::Request->new($req => "http://127.0.0.1:$port/path/to/some/file");
      my $resp = $client->request($req);

      if ($ENV{TEST_VERBOSE}) {
        print STDERR "# response: ", $resp->as_string, "\n";
      }

      my $conn_count = $client->conn_cache->get_connections();

      $self->assert($conn_count == 0,
        test_msg("Expected connection cache count 0, got $conn_count"));
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

sub http_connect {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  test_http_req($self, $tmpdir, 'CONNECT');
}

sub http_delete {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  test_http_req($self, $tmpdir, 'DELETE');
}

sub http_get {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  test_http_req($self, $tmpdir, 'GET');
}

sub http_head {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  test_http_req($self, $tmpdir, 'HEAD');
}

sub http_options {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  test_http_req($self, $tmpdir, 'OPTIONS');
}

sub http_patch {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  test_http_req($self, $tmpdir, 'PATCH');
}

sub http_post {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  test_http_req($self, $tmpdir, 'POST');
}

sub http_put {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};
  test_http_req($self, $tmpdir, 'PUT');
}

1;
