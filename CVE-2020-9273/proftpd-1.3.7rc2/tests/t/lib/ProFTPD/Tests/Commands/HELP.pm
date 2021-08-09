package ProFTPD::Tests::Commands::HELP;

use lib qw(t/lib);
use base qw(ProFTPD::TestSuite::Child);
use strict;

use File::Spec;
use IO::Handle;

use ProFTPD::TestSuite::FTP;
use ProFTPD::TestSuite::Utils qw(:auth :config :features :running :test :testsuite);

$| = 1;

my $order = 0;

my $TESTS = {
  help_ok => {
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

sub help_ok {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/cmds.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/cmds.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/cmds.scoreboard");

  my $log_file = test_get_logfile();

  my $auth_user_file = File::Spec->rel2abs("$tmpdir/cmds.passwd");
  my $auth_group_file = File::Spec->rel2abs("$tmpdir/cmds.group");

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

  my $auth_helps = [
    ' NOOP    FEAT    OPTS    AUTH*   CCC*    CONF*   ENC*    MIC*    ',
    ' PBSZ*   PROT*   TYPE    STRU    MODE    RETR    STOR    STOU    ',
  ];

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

      $client->help();
      my $resp_code = $client->response_code();
      my $resp_msgs = $client->response_msgs();

      my $expected;

      $expected = 214;
      $self->assert($expected == $resp_code,
        test_msg("Expected $expected, got $resp_code"));

      $expected = 9;
      my $nhelp = scalar(@$resp_msgs);
      $self->assert($expected == $nhelp,
        test_msg("Expected $expected, got $nhelp"));

      my $helps = [(
        'The following commands are recognized (* =>\'s unimplemented):',
        ' CWD     XCWD    CDUP    XCUP    SMNT*   QUIT    PORT    PASV    ',
        ' EPRT    EPSV    ALLO*   RNFR    RNTO    DELE    MDTM    RMD     ',
        ' XRMD    MKD     XMKD    PWD     XPWD    SIZE    SYST    HELP    ',
        @$auth_helps,
        ' APPE    REST    ABOR    USER    PASS    ACCT*   REIN*   LIST    ',
        ' NLST    STAT    SITE    MLSD    MLST    ',
        'Direct comments to root@127.0.0.1',
      )];

      for (my $i = 0; $i < $nhelp; $i++) {
        $expected = $helps->[$i];
        $self->assert($expected eq $resp_msgs->[$i],
          test_msg("Expected '$expected', got '$resp_msgs->[$i]'"));
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

1;
