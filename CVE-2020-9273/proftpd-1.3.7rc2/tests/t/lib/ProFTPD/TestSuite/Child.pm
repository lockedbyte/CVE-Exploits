package ProFTPD::TestSuite::Child;

use base qw(Test::Unit::TestCase);
use strict;

use Carp;
use File::Path qw(mkpath rmtree);
use POSIX qw(:sys_wait_h);

use ProFTPD::TestSuite::Utils qw(:testsuite);

my $processes = {};

sub sig_chld {
  my $child;

  while (($child = waitpid(-1, 0)) > 0) {
    $processes->{$child} = ($? >> 8);
  }

  $SIG{CHLD} = \&sig_chld;
}

sub handle_sigchld {
  my $self = shift;
  $SIG{CHLD} = \&sig_chld;
}

sub assert_child_ok {
  my $self = shift;
  my $pid = shift;

  my ($pkg, $file, $lineno, $func, @rest) = caller(1);

  $self->assert($processes->{$pid} == 0,
    "Child test process $pid failed in $func (line $lineno) [see above for possible errors]");
}

sub assert_transfer_ok {
  my $self = shift;
  my $resp_code = shift;
  my $resp_msg = shift;
  my $aborted = shift;
  $aborted = 0 unless $aborted;

  if ($resp_code == 226) {
    my $expected = "Transfer complete";
    if ($aborted) {
      $expected = "Abort successful";
    }

    if ($expected ne $resp_msg) {
      croak("Expected response message '$expected', got '$resp_msg'");
    }

  } elsif ($resp_code == 150) {
    my $expected = "Opening .*? mode data connection";
    if ($resp_msg !~ /$expected/) {
      croak("Expected response message '$expected', got '$resp_msg'");
    }

  } else {
    croak("Expected response code 150 or 226, got $resp_code");
  }
}

sub set_up {
  my $self = shift;

  # Create temporary scratch dir
  $self->{tmpdir} = testsuite_get_tmp_dir();
}

sub tear_down {
  my $self = shift;

  # Remove temporary scratch dir
  if ($self->{tmpdir} &&
      !$ENV{KEEP_TMPFILES}) {
    eval { rmtree($self->{tmpdir}) };
  }
}

1;
