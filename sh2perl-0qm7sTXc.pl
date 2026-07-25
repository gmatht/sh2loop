#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use IPC::Open3;

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

my $DPKG_ROOT;
my @DPKG_ROOT;
my %DPKG_ROOT;

$__set_e = 1;
if ("$_[0]" =~ /^purge$/msx) {
    if ( -e "/etc/alsa/0.9/asound.conf" ) {
        if ( -d "/etc/alsa/0.9/asound.conf" ) {
            carp "rm: carping: ", "/etc/alsa/0.9/asound.conf",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/etc/alsa/0.9/asound.conf" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/etc/alsa/0.9/asound.conf",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "/etc/asound.state" ) {
        if ( -d "/etc/asound.state" ) {
            carp "rm: carping: ", "/etc/asound.state",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/etc/asound.state" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/etc/asound.state",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    if ( -e "/etc/modprobe.d/sound" ) {
        if ( -d "/etc/modprobe.d/sound" ) {
            carp "rm: carping: ", "/etc/modprobe.d/sound",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/etc/modprobe.d/sound" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/etc/modprobe.d/sound",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "/etc/modutils/sound" ) {
        if ( -d "/etc/modutils/sound" ) {
            carp "rm: carping: ", "/etc/modutils/sound",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/etc/modutils/sound" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/etc/modutils/sound",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "/etc/modprobe.d/sound.conf" ) {
        if ( -d "/etc/modprobe.d/sound.conf" ) {
            carp "rm: carping: ", "/etc/modprobe.d/sound.conf",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/etc/modprobe.d/sound.conf" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/etc/modprobe.d/sound.conf",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    if ( -e "/var/lib/alsa/asound.state" ) {
        if ( -d "/var/lib/alsa/asound.state" ) {
            carp "rm: carping: ", "/var/lib/alsa/asound.state",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/var/lib/alsa/asound.state" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/var/lib/alsa/asound.state",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
}
if (("$1" eq "remove" && (-x "/etc/init.d/alsa-utils"))) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
$CHILD_ERROR = 0;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
}
if (("${DPKG_ROOT:-}" eq q{} && "$1" eq "purge")) {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('update-rc.d', 'alsa-utils', 'remove') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
}
if (("$1" eq remove && (-d '/run/systemd/system'))) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('systemctl', "--" . "sys" . "tem", 'daemon-reload') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
}

exit $main_exit_code;
