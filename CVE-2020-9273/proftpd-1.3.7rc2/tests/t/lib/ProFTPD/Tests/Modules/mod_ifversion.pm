package ProFTPD::Tests::Modules::mod_ifversion;

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
  ifversion_eq => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ifversion_eq2 => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ifversion_ne => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ifversion_gt => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ifversion_ge => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ifversion_lt => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ifversion_le => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ifversion_regex => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ifversion_regex_eq => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ifversion_skip_section => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ifversion_major_only => {
    order => ++$order,
    test_class => [qw(forking)],
  },

  ifversion_major_minor_only => {
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

sub get_server_version {
  my $proftpd_bin = ProFTPD::TestSuite::Utils::get_proftpd_bin();

  my @res = `$proftpd_bin -v`;
  if ($? != 0) {
    return undef;
  }

  my $res = $res[0];
  chomp($res);

  if ($res =~ /^ProFTPD Version (\S+)$/) {
    return $1;
  }

  return undef;
}

sub ifversion_eq {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ifversion.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ifversion.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ifversion.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    my $version = get_server_version();

    print $fh <<EOC;
<IfVersion = $version>
  Foo bar
</IfVersion>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  server_start($config_file);

  eval { server_stop($pid_file) };
  unless ($@) {
    die("Server started unexpectedly");
  }

  unlink($log_file);
}

sub ifversion_eq2 {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ifversion.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ifversion.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ifversion.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    my $version = get_server_version();

    print $fh <<EOC;
<IfVersion == $version>
  Foo bar
</IfVersion>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  server_start($config_file);

  eval { server_stop($pid_file) };
  unless ($@) {
    die("Server started unexpectedly");
  }

  unlink($log_file);
}

sub ifversion_ne {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ifversion.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ifversion.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ifversion.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {

    # Pick a version that cannot be used by mod_ifversion
    my $version = "1.2.2";

    print $fh <<EOC;
<IfVersion != $version>
  Foo bar
</IfVersion>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  server_start($config_file);

  eval { server_stop($pid_file) };
  unless ($@) {
    die("Server started unexpectedly");
  }

  unlink($log_file);
}

sub ifversion_gt {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ifversion.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ifversion.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ifversion.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {

    # Pick a version that cannot be used by mod_ifversion
    my $version = "1.2.2";

    print $fh <<EOC;
<IfVersion > $version>
  Foo bar
</IfVersion>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  server_start($config_file);

  eval { server_stop($pid_file) };
  unless ($@) {
    die("Server started unexpectedly");
  }

  unlink($log_file);
}

sub ifversion_ge {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ifversion.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ifversion.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ifversion.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    my $version = get_server_version();

    print $fh <<EOC;
<IfVersion >= $version>
  Foo bar
</IfVersion>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  server_start($config_file);

  eval { server_stop($pid_file) };
  unless ($@) {
    die("Server started unexpectedly");
  }

  unlink($log_file);
}

sub ifversion_lt {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ifversion.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ifversion.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ifversion.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {

    # Pick an absurdly high version
    my $version = "10.11.12z";

    print $fh <<EOC;
<IfVersion < $version>
  Foo bar
</IfVersion>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  server_start($config_file);

  eval { server_stop($pid_file) };
  unless ($@) {
    die("Server started unexpectedly");
  }

  unlink($log_file);
}

sub ifversion_le {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ifversion.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ifversion.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ifversion.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    my $version = get_server_version();

    print $fh <<EOC;
<IfVersion <= $version>
  Foo bar
</IfVersion>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  server_start($config_file);

  eval { server_stop($pid_file) };
  unless ($@) {
    die("Server started unexpectedly");
  }

  unlink($log_file);
}

sub ifversion_regex {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ifversion.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ifversion.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ifversion.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    my $version = get_server_version();

    print $fh <<EOC;
<IfVersion ~ \\.*>
  Foo bar
</IfVersion>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  server_start($config_file);

  eval { server_stop($pid_file) };
  unless ($@) {
    die("Server started unexpectedly");
  }

  unlink($log_file);
}

sub ifversion_regex_eq {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ifversion.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ifversion.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ifversion.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    my $version = get_server_version();

    print $fh <<EOC;
<IfVersion = /\\./>
  Foo bar
</IfVersion>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  server_start($config_file);

  eval { server_stop($pid_file) };
  unless ($@) {
    die("Server started unexpectedly");
  }

  unlink($log_file);
}

sub ifversion_skip_section {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ifversion.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ifversion.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ifversion.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    my $version = get_server_version();

    print $fh <<EOC;
<IfVersion != $version>
  Foo bar
  Baz quxx
</IfVersion>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  server_start($config_file);

  # Give the server time to start up
  sleep(2);

  server_stop($pid_file);

  unlink($log_file);
}

sub ifversion_major_only {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ifversion.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ifversion.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ifversion.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    my $version = get_server_version();

    print $fh <<EOC;
<IfVersion < 10>
  Foo bar
</IfVersion>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  server_start($config_file);

  eval { server_stop($pid_file) };
  unless ($@) {
    die("Server started unexpectedly");
  }

  unlink($log_file);
}

sub ifversion_major_minor_only {
  my $self = shift;
  my $tmpdir = $self->{tmpdir};

  my $config_file = "$tmpdir/ifversion.conf";
  my $pid_file = File::Spec->rel2abs("$tmpdir/ifversion.pid");
  my $scoreboard_file = File::Spec->rel2abs("$tmpdir/ifversion.scoreboard");

  my $log_file = File::Spec->rel2abs('tests.log');

  my $config = {
    PidFile => $pid_file,
    ScoreboardFile => $scoreboard_file,
    SystemLog => $log_file,

    IfModules => {
      'mod_delay.c' => {
        DelayEngine => 'off',
      },
    },
  };

  my ($port, $config_user, $config_group) = config_write($config_file, $config);

  if (open(my $fh, ">> $config_file")) {
    my $version = get_server_version();

    print $fh <<EOC;
<IfVersion < 10.11>
  Foo bar
</IfVersion>
EOC
    unless (close($fh)) {
      die("Can't write $config_file: $!");
    }

  } else {
    die("Can't open $config_file: $!");
  }

  server_start($config_file);

  eval { server_stop($pid_file) };
  unless ($@) {
    die("Server started unexpectedly");
  }

  unlink($log_file);
}

1;
