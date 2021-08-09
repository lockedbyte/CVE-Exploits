package ProFTPD::TestSuite::FTP;

use strict;

use Carp;
use Net::FTP;
use POSIX qw(:sys_wait_h);

my $conn_ex;

sub new {
  my $class = shift;
  my ($addr, $port, $use_port, $conn_timeout, $cmd_timeout) = @_;
  $use_port = 0 unless defined($use_port);
  $conn_timeout = 2 unless defined($conn_timeout);
 
  my $ftp;

  my $now = time();

  # Creating a Net::FTP object involves attempting to connect to the given
  # address/port.  So handle the test cases where the server process may
  # not yet be completely up, retry this connect, once a second, up to the
  # given timeout.

  my %opts = (
    Port => $port,
  );

  if ($use_port) {
    $opts{Passive} = 0;

  } else {
    $opts{Passive} = 1;
  }

  if ($ENV{TEST_VERBOSE}) {
    $opts{Debug} = 10;
  }

  if (defined($cmd_timeout)) {
    $opts{Timeout} = $cmd_timeout;
  }

  while (1) {
    if (time() - $now > $conn_timeout) {
      croak("Unable to connect to $addr:$port: Timed out after $conn_timeout secs");
    }

    $ftp = Net::FTP->new($addr, %opts);
    if ($ftp) {
      last;
    }

    $conn_ex = $@;
    chomp($conn_ex);
    sleep(1);
  }

  # Naughtily invade the Net::FTP internals; it makes for less confusion
  # when writing the unit tests.
  if (exists($ENV{FTP_FIREWALL})) {
    ${*$ftp}{net_ftp_firewall} = $ENV{FTP_FIREWALL};
  }

  if (exists($ENV{FTP_FIREWALL_TYPE})) {
    ${*$ftp}{net_ftp_firewall_type} = $ENV{FTP_FIREWALL_TYPE};
  }

  my $self = {
    addr => $addr,
    ftp => $ftp,
    port => $port,
  };

  $conn_ex = undef;

  bless($self, $class);
  return $self;
}

sub response_code {
  my $self = shift;
  return $self->{ftp}->code;
}

sub response_msg {
  my $self = shift;
  my $req_index = shift;

  my $index = 1;
  if (defined($req_index)) {
    $index = $req_index;
  }

  if (defined($self->{mesg})) {
    my $msg = $self->{mesg};
    delete($self->{mesg});
    chomp($msg);
    return $msg;
  }

  my @msgs = $self->{ftp}->message;
  my $nmsgs = scalar(@msgs);
  if ($nmsgs > 1) {
    if ($index > ($nmsgs - 1)) {
      return undef;
    }

    chomp($msgs[$index]);
    return $msgs[$index];

  } else {
    if (defined($req_index)) {
      if ($index > 0) {
        return undef;
      }
    }
  }

  if (defined($msgs[0])) {
    chomp($msgs[0]);
  }

  return $msgs[0];
}

sub response_msgs {
  my $self = shift;

  my @msgs = $self->{ftp}->message;
  my $msgs = [];
  foreach my $msg (@msgs) {
    chomp($msg);
    push(@$msgs, $msg);
  }

  return $msgs;
}

sub response_uniq {
  my $self = shift;

  my $uniq;
  if (defined($self->{uniq})) {
    $uniq = $self->{uniq};
    delete($self->{uniq});

  } else {
    $uniq = $self->{ftp}->unique_name();
    unless ($uniq) {
      my @msgs = $self->{ftp}->message;
      if (scalar(@msgs) > 1) {
        my $tmp = $msgs[0];

        if ($tmp =~ /^FILE:\s+(\S+)$/) {
          $uniq = $1;
        }
      }
    }
  }

  if ($uniq) {
    chomp($uniq);
  }

  return $uniq;
}

my $login_timeout = 0;
sub login_alarm {
  croak("Login timed out after $login_timeout secs");
}

sub login {
  my $self = shift;
  my $user = shift;
  croak("Missing required user argument") unless defined($user);
  my $pass = shift;
  croak("Missing required password argument") unless defined($pass);
  $login_timeout = shift;
  $login_timeout = 30 unless defined($login_timeout);

  $SIG{ALRM} = \&login_alarm;
  alarm($login_timeout);

  # Work around some (strange? broken?) ness in Net::FTP's handling of
  # the destination server in the login() method for "firewalls"
  # (i.e. proxying).

  my $ftp = $self->{ftp};
  my $net_ftp_host = ${*$ftp}{net_ftp_host};

  if (exists($ENV{FTP_FIREWALL})) {
    ${*$ftp}{net_ftp_host} = $ENV{FTP_FIREWALL};
  }

  unless ($self->{ftp}->login($user, $pass)) {
    if (exists($ENV{FTP_FIREWALL})) {
      ${*$ftp}{net_ftp_host} = $net_ftp_host;
    }

    alarm(0);
    $SIG{ALRM} = 'DEFAULT';

    croak("Failed to login to $self->{addr}:$self->{port}: " .
      $self->{ftp}->code . ' ' . $self->{ftp}->message);
  }

  alarm(0);
  $SIG{ALRM} = 'DEFAULT';

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub user {
  my $self = shift;
  my $user = shift;
  $user = '' unless defined($user);
  my $code;

  $code = $self->{ftp}->quot('USER', $user);
  unless ($code) {
    croak("USER command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("USER command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub pass {
  my $self = shift;
  my $passwd = shift;
  $passwd = '' unless defined($passwd);
  my $code;

  $code = $self->{ftp}->quot('PASS', $passwd);
  unless ($code) {
    croak("PASS command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("PASS command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub pwd {
  my $self = shift;

  unless ($self->{ftp}->pwd()) {
    croak("PWD command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub xpwd {
  my $self = shift;
  my $code;

  $code = $self->{ftp}->quot('XPWD');
  unless ($code) {
    croak("XPWD command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("XPWD command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub cwd {
  my $self = shift;
  my $dir = shift;

  unless ($self->{ftp}->cwd($dir)) {
    croak("CWD command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub xcwd {
  my $self = shift;
  my $dir = shift;
  my $code;

  $code = $self->{ftp}->quot('XCWD', $dir);
  unless ($code) {
    croak("XCWD command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("XCWD command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub cdup {
  my $self = shift;
  my $dir = shift;

  unless ($self->{ftp}->cdup()) {
    croak("CDUP command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub xcup {
  my $self = shift;
  my $code;

  $code = $self->{ftp}->quot('XCUP');
  unless ($code) {
    croak("XCUP command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("XCUP command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub syst {
  my $self = shift;
  my $code;

  $code = $self->{ftp}->quot('SYST');
  unless ($code) {
    croak("SYST command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("SYST command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub mkd {
  my $self = shift;
  my $dir = shift;

  unless ($self->{ftp}->mkdir($dir)) {
    croak("MKD command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub xmkd {
  my $self = shift;
  my $dir = shift;
  my $code;

  $code = $self->{ftp}->quot('XMKD', $dir);
  unless ($code) {
    croak("XMKD command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("XMKD command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub rmd {
  my $self = shift;
  my $dir = shift;

  unless ($self->{ftp}->rmdir($dir)) {
    croak("RMD command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub xrmd {
  my $self = shift;
  my $dir = shift;
  my $code;

  $code = $self->{ftp}->quot('XRMD', $dir);
  unless ($code) {
    croak("XRMD command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("XRMD command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub dele {
  my $self = shift;
  my $path = shift;

  unless ($self->{ftp}->delete($path)) {
    croak("DELE command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub type {
  my $self = shift;
  my $type = shift;

  if ($type =~ /^ascii$/i) {
    unless ($self->{ftp}->ascii()) {
      croak("TYPE command failed: " .  $self->{ftp}->code . ' ' .
        $self->response_msg());
    }

  } elsif ($type =~ /^binary$/i) {
    unless ($self->{ftp}->binary()) {
      croak("TYPE command failed: " .  $self->{ftp}->code . ' ' .
        $self->response_msg());
    }

  } else {
    my $code;

    $code = $self->{ftp}->quot('TYPE', $type);
    unless ($code) {
      croak("TYPE command failed: " .  $self->{ftp}->code . ' ' .
        $self->response_msg());
    }

    if ($code == 4 || $code == 5) {
      croak("TYPE command failed: " .  $self->{ftp}->code . ' ' .
        $self->response_msg());
    }
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub mdtm {
  my $self = shift;
  my $path = shift;

  unless ($self->{ftp}->mdtm($path)) {
    croak("MDTM command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub size {
  my $self = shift;
  my $path = shift;

  unless ($self->{ftp}->size($path)) {
    croak("SIZE command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub pasv {
  my $self = shift;

  unless ($self->{ftp}->pasv()) {
    croak("PASV command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  # Naughtily invade the Net::FTP internals; it makes for less confusion
  # when writing the unit tests.
  my $ftp = $self->{ftp};
  ${*$ftp}{net_ftp_passive} = 1;

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub epsv {
  my $self = shift;
  my $proto = shift;
  $proto = '' unless defined($proto);
  my $code;

  $code = $self->{ftp}->quot('EPSV', $proto);
  unless ($code) {
    croak("EPSV command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("EPSV command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  # Naughtily invade the Net::FTP internals; it makes for less confusion
  # when writing the unit tests.
  my $ftp = $self->{ftp};
  ${*$ftp}{net_ftp_passive} = 1;

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub port {
  my $self = shift;
  my $port = shift;

  unless ($self->{ftp}->port($port)) {
    croak("PORT command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  # Naughtily invade the Net::FTP internals; it makes for less confusion
  # when writing the unit tests.
  my $ftp = $self->{ftp};

  if ($port) {
    # Determine the local port from the given argument.

    my $numbers = [split(',', $port)];
    my $local_port = ($numbers->[4] * 256) + $numbers->[5];

    # If the caller provided an explicit PORT argument, then we need to
    # open the listening socket ourselves.  Net::FTP is braindead that way.
    #
    # The code below is copied from Net::FTP::port().

    ${*$ftp}{net_ftp_listen} ||= IO::Socket::INET->new(
      Listen => 5,
      Proto => 'tcp',
      Timeout => $ftp->timeout,
      LocalAddr => $ftp->sockhost,
      LocalPort => $local_port,
    );

    ${*$ftp}{net_ftp_intern_port} = 1;
  }

  delete(${*$ftp}{net_ftp_passive});

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub eprt {
  my $self = shift;
  my $port = shift;
  $port = '' unless defined($port);
  my $code;

  $code = $self->{ftp}->quot('EPRT', $port);
  unless ($code) {
    croak("EPRT command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("EPRT command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  # Naughtily invade the Net::FTP internals; it makes for less confusion
  # when writing the unit tests.
  my $ftp = $self->{ftp};
  delete(${*$ftp}{net_ftp_passive});

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub mode {
  my $self = shift;
  my $mode = shift;

  if ($mode =~ /^stream$/i) {
    my $code;

    $code = $self->{ftp}->quot('MODE', 'S');
    unless ($code) {
      croak("MODE command failed: " .  $self->{ftp}->code . ' ' .
        $self->response_msg());
    }

    if ($code == 4 || $code == 5) {
      croak("MODE command failed: " .  $self->{ftp}->code . ' ' .
        $self->response_msg());
    }

  } elsif ($mode =~ /^block$/i) {
    my $code;

    $code = $self->{ftp}->quot('MODE', 'B');
    unless ($code) {
      croak("MODE command failed: " .  $self->{ftp}->code . ' ' .
        $self->response_msg());
    }

    if ($code == 4 || $code == 5) {
      croak("MODE command failed: " .  $self->{ftp}->code . ' ' .
        $self->response_msg());
    }

  } elsif ($mode =~ /^compress(ed)?$/i) {
    my $code;

    $code = $self->{ftp}->quot('MODE', 'C');
    unless ($code) {
      croak("MODE command failed: " .  $self->{ftp}->code . ' ' .
        $self->response_msg());
    }

    if ($code == 4 || $code == 5) {
      croak("MODE command failed: " .  $self->{ftp}->code . ' ' .
        $self->response_msg());
    }

  } else {
    my $code;

    $code = $self->{ftp}->quot('MODE', $mode);
    unless ($code) {
      croak("MODE command failed: " .  $self->{ftp}->code . ' ' .
        $self->response_msg());
    }

    if ($code == 4 || $code == 5) {
      croak("MODE command failed: " .  $self->{ftp}->code . ' ' .
        $self->response_msg());
    }
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub stru {
  my $self = shift;
  my $stru = shift;

  if ($stru =~ /^file$/i) {
    my $code;

    $code = $self->{ftp}->quot('STRU', 'F');
    unless ($code) {
      croak("STRU command failed: " .  $self->{ftp}->code . ' ' .
        $self->response_msg());
    }

    if ($code == 4 || $code == 5) {
      croak("STRU command failed: " .  $self->{ftp}->code . ' ' .
        $self->response_msg());
    }

  } elsif ($stru =~ /^record$/i) {
    my $code;

    $code = $self->{ftp}->quot('STRU', 'R');
    unless ($code) {
      croak("STRU command failed: " .  $self->{ftp}->code . ' ' .
        $self->response_msg());
    }

    if ($code == 4 || $code == 5) {
      croak("STRU command failed: " .  $self->{ftp}->code . ' ' .
        $self->response_msg());
    }

  } elsif ($stru =~ /^page$/i) {
    my $code;

    $code = $self->{ftp}->quot('STRU', 'P');
    unless ($code) {
      croak("STRU command failed: " .  $self->{ftp}->code . ' ' .
        $self->response_msg());
    }

    if ($code == 4 || $code == 5) {
      croak("STRU command failed: " .  $self->{ftp}->code . ' ' .
        $self->response_msg());
    }

  } else {
    my $code;

    $code = $self->{ftp}->quot('STRU', $stru);
    unless ($code) {
      croak("STRU command failed: " .  $self->{ftp}->code . ' ' .
        $self->response_msg());
    }

    if ($code == 4 || $code == 5) {
      croak("STRU command failed: " .  $self->{ftp}->code . ' ' .
        $self->response_msg());
    }
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub allo {
  my $self = shift;
  my $size = shift;

  # XXX Net::FTP has a bug with its alloc() method, where a 202 response
  # code is incorrectly handled as an error.
  my $code = 0;

  $self->{ftp}->alloc($size);

  if ($self->{ftp}->code =~ /^(\d)/) {
    $code = $1;
  }

  if ($code == 4 || $code == 5) {
    croak("ALLO command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub noop {
  my $self = shift;
  my $code;

  $code = $self->{ftp}->quot('NOOP');
  unless ($code) {
    croak("NOOP command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("NOOP command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub rnfr {
  my $self = shift;
  my $path = shift;
  my $code;

  $code = $self->{ftp}->quot('RNFR', $path);
  unless ($code) {
    croak("RNFR command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("RNFR command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub rnto {
  my $self = shift;
  my $path = shift;
  my $code;

  $code = $self->{ftp}->quot('RNTO', $path);
  unless ($code) {
    croak("RNTO command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("RNTO command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub quit {
  my $self = shift;

  unless ($self->{ftp}->quit()) {
    croak("QUIT command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub rang {
  my $self = shift;
  my $range_start = shift;
  croak("Missing range start") unless defined($range_start);
  my $range_end = shift;
  croak("Missing range end") unless defined($range_end);
  my $code;

  $code = $self->{ftp}->quot('RANG', $range_start, $range_end);
  unless ($code) {
    croak("RANG command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("RANG command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);
  }

  return $msg;
}

sub rest {
  my $self = shift;
  my $offset = shift;
  $offset = '' unless defined($offset);
  my $code;

  $code = $self->{ftp}->quot('REST', $offset);
  unless ($code) {
    croak("REST command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("REST command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub nlst {
  my $self = shift;
  my $path = shift;
  $path = '' unless defined($path);

  my $res;

  $res = $self->{ftp}->nlst($path);
  unless ($res) {
    croak("NLST command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if (ref($res)) {
    my $buf;
    while ($res->read($buf, 8192) > 0) {
    }

    $res->close();
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub nlst_raw {
  my $self = shift;
  my $path = shift;
  $path = '' unless defined($path);

  return $self->{ftp}->nlst($path);
}

sub list {
  my $self = shift;
  my $path = shift;
  $path = '' unless defined($path);

  my $res;

  $res = $self->{ftp}->list($path);
  unless ($res) {
    croak("LIST command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if (ref($res)) {
    my $buf;
    while ($res->read($buf, 8192) > 0) {
    }

    $res->close();
  }

  # XXX Work around bug in Net::FTP which fails to handle the case where,
  # for data transfers, a 150 response code may be sent (to open the data
  # connection), followed by an error response code.
  my $code = 0;

  if ($self->{ftp}->code =~ /^(\d)/) {
    $code = $1;
  }

  if ($code == 4 || $code == 5) {
    my $msg = $self->response_msg();
    $self->{mesg} = $msg;

    croak("LIST command failed: " .  $self->{ftp}->code . ' ' . $msg);
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub list_raw {
  my $self = shift;
  my $path = shift;
  $path = '' unless defined($path);

  return $self->{ftp}->list($path);
}

sub retr {
  my $self = shift;
  my $src_path = shift;
  $src_path = '' unless defined($src_path);
  my $dst_path = shift;
  $dst_path = '/dev/null' unless defined($dst_path);

  my $res;

  $res = $self->{ftp}->get($src_path, $dst_path);
  unless ($res) {
    croak("RETR command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if (ref($res)) {
    my $buf;
    while ($res->read($buf, 8192) > 0) {
    }

    $res->close();
  }

  # XXX Work around bug in Net::FTP which fails to handle the case where,
  # for data transfers, a 150 response code may be sent (to open the data
  # connection), followed by an error response code.
  my $code = 0;

  if ($self->{ftp}->code =~ /^(\d)/) {
    $code = $1;
  }

  if ($code == 4 || $code == 5) {
    my $msg = $self->response_msg();
    $self->{mesg} = $msg;

    croak("RETR command failed: " .  $self->{ftp}->code . ' ' . $msg);
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub retr_raw {
  my $self = shift;
  my $path = shift;
  $path = '' unless defined($path);

  return $self->{ftp}->retr($path);
}

sub stor {
  my $self = shift;
  my $src_path = shift;
  $src_path = '' unless defined($src_path);
  my $dst_path = shift;
  $dst_path = '/dev/null' unless defined($dst_path);

  my $res;

  $res = $self->{ftp}->put($src_path, $dst_path);
  unless ($res) {
    croak("STOR command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  # XXX Work around bug in Net::FTP which fails to handle the case where,
  # for data transfers, a 150 response code may be sent (to open the data
  # connection), followed by an error response code.
  my $code = 0;

  if ($self->{ftp}->code =~ /^(\d)/) {
    $code = $1;
  }

  if ($code == 4 || $code == 5) {
    my $msg = $self->response_msg();
    $self->{mesg} = $msg;

    croak("STOR command failed: " .  $self->{ftp}->code . ' ' . $msg);
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub stor_raw {
  my $self = shift;
  my $path = shift;
  $path = '' unless defined($path);

  return $self->{ftp}->stor($path);
}

sub stou {
  my $self = shift;
  my $src_path = shift;
  $src_path = '' unless defined($src_path);
  my $dst_path = shift;
  $dst_path = '' unless defined($dst_path);

  my $res;

  $res = $self->{ftp}->put_unique($src_path, $dst_path);
  unless ($res) {
    croak("STOU command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  $self->{uniq} = $res;

  # XXX Work around bug in Net::FTP which fails to handle the case where,
  # for data transfers, a 150 response code may be sent (to open the data
  # connection), followed by an error response code.
  my $code = 0;

  if ($self->{ftp}->code =~ /^(\d)/) {
    $code = $1;
  }

  if ($code == 4 || $code == 5) {
    my $msg = $self->response_msg();
    $self->{mesg} = $msg;

    croak("STOU command failed: " .  $self->{ftp}->code . ' ' . $msg);
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub stou_raw {
  my $self = shift;
  my $path = shift;
  $path = '' unless defined($path);

  return $self->{ftp}->stou($path);
}

sub appe {
  my $self = shift;
  my $src_path = shift;
  $src_path = '' unless defined($src_path);
  my $dst_path = shift;
  $dst_path = '/dev/null' unless defined($dst_path);

  my $res;

  $res = $self->{ftp}->append($src_path, $dst_path);
  unless ($res) {
    croak("APPE command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  # XXX Work around bug in Net::FTP which fails to handle the case where,
  # for data transfers, a 150 response code may be sent (to open the data
  # connection), followed by an error response code.
  my $code = 0;

  if ($self->{ftp}->code =~ /^(\d)/) {
    $code = $1;
  }

  if ($code == 4 || $code == 5) {
    my $msg = $self->response_msg();
    $self->{mesg} = $msg;

    croak("APPE command failed: " .  $self->{ftp}->code . ' ' . $msg);
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub appe_raw {
  my $self = shift;
  my $path = shift;
  $path = '' unless defined($path);

  return $self->{ftp}->appe($path);
}

sub feat {
  my $self = shift;
  my $code;

  $code = $self->{ftp}->quot('FEAT');
  unless ($code) {
    croak("FEAT command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("FEAT command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub help {
  my $self = shift;
  my $code;

  $code = $self->{ftp}->quot('HELP');
  unless ($code) {
    croak("HELP command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("HELP command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub site {
  my $self = shift;
  my $cmd = shift;
  $cmd = '' unless defined($cmd);
  my $code;

  $code = $self->{ftp}->quot('SITE', $cmd, @_);
  unless ($code) {
    croak("SITE command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("SITE command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub quote {
  my $self = shift;
  my $cmd = shift;
  $cmd = '' unless defined($cmd);
  my $code;

  $code = $self->{ftp}->quot($cmd, @_);
  unless ($code) {
    croak("Raw command '$cmd' failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("Raw command '$cmd' failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub mlsd {
  my $self = shift;
  my $path = shift;
  $path = '' unless defined($path);

  my $res;

  $res = $self->{ftp}->_data_cmd('MLSD', $path);
  unless ($res) {
    croak("MLSD command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if (ref($res)) {
    my $buf;
    while ($res->read($buf, 8192) > 0) {
    }

    $res->close();
  }

  # XXX Work around bug in Net::FTP which fails to handle the case where,
  # for data transfers, a 150 response code may be sent (to open the data
  # connection), followed by an error response code.
  my $code = 0;

  if ($self->{ftp}->code =~ /^(\d)/) {
    $code = $1;
  }

  if ($code == 4 || $code == 5) {
    my $msg = $self->response_msg();
    $self->{mesg} = $msg;

    croak("MLSD command failed: " .  $self->{ftp}->code . ' ' . $msg);
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub mlsd_raw {
  my $self = shift;
  my $path = shift;
  $path = '' unless defined($path);
  my $conn;

  $conn = $self->{ftp}->_data_cmd('MLSD', $path);
  return $conn;
}

sub mlst {
  my $self = shift;
  my $path = shift;
  $path = '' unless defined($path);
  my $code;

  $code = $self->{ftp}->quot('MLST', $path);
  unless ($code) {
    croak("MLST command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("MLST command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub mff {
  my $self = shift;
  my $facts = shift;
  $facts = '' unless defined($facts);
  my $path = shift;
  $path = '' unless defined($path);
  my $code;

  $code = $self->{ftp}->quot('MFF', $facts, $path);
  unless ($code) {
    croak("MFF command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("MFF command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub mfmt {
  my $self = shift;
  my $timestamp = shift;
  $timestamp = '' unless defined($timestamp);
  my $path = shift;
  $path = '' unless defined($path);
  my $code;

  $code = $self->{ftp}->quot('MFMT', $timestamp, $path);
  unless ($code) {
    croak("MFMT command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("MFMT command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub lang {
  my $self = shift;
  my $lang = shift;
  $lang = '' unless defined($lang);
  my $code;

  $code = $self->{ftp}->quot('LANG', $lang);
  unless ($code) {
    croak("LANG command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("LANG command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub opts {
  my $self = shift;
  my $cmd = shift;
  $cmd = '' unless defined($cmd);
  my $code;

  $code = $self->{ftp}->quot('OPTS', $cmd, @_);
  unless ($code) {
    croak("OPTS command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("OPTS command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub get_connect_exception {
  return $conn_ex;
}

sub stat {
  my $self = shift;
  my $path = shift;
  $path = '' unless defined($path);
  my $code;

  $code = $self->{ftp}->quot('STAT', $path);
  unless ($code) {
    croak("STAT command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("STAT command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

# From the FTP HOST command RFC 7151
sub host {
  my $self = shift;
  my $host = shift;
  $host = '' unless defined($host);
  my $code;

  $code = $self->{ftp}->quot('HOST', $host);
  unless ($code) {
    croak("HOST command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("HOST command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub clnt {
  my $self = shift;
  my $info = shift;
  $info = 'ProFTPD::TestSuite::FTP' unless defined($info);
  my $code;

  $code = $self->{ftp}->quot('CLNT', $info);
  unless ($code) {
    croak("CLNT command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  if ($code == 4 || $code == 5) {
    croak("CLNT command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

sub abort {
  my $self = shift;

  unless ($self->{ftp}->abort()) {
    croak("ABOR command failed: " .  $self->{ftp}->code . ' ' .
      $self->response_msg());
  }

  my $msg = $self->response_msg();
  if (wantarray()) {
    return ($self->{ftp}->code, $msg);

  } else {
    return $msg;
  }
}

1;
