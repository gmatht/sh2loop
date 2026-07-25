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
if ("$1" eq "purge") {
if ((-x '/etc/init.d/dbus')) {
                $main_exit_code = system('invoke-rc.d', 'dbus', 'force-reload') >> 8;
        if ($CHILD_ERROR != 0) {
            1;
        }
    }
if ( -e "/var/lib/PackageKit" ) {
        if ( -d "/var/lib/PackageKit" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("/var/lib/PackageKit", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", "/var/lib/PackageKit", ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "/var/lib/PackageKit" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/var/lib/PackageKit",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "/var/cache/PackageKit" ) {
        if ( -d "/var/cache/PackageKit" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("/var/cache/PackageKit", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", "/var/cache/PackageKit", ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "/var/cache/PackageKit" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/var/cache/PackageKit",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
}
if ("$1" eq "purge") {
if (("${DPKG_ROOT:-}" eq q{} && (-x "/usr/bin/deb-systemd-helper"))) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('deb-systemd-helper', '--user', 'purge', 'pk-debconf-helper.socket') >> 8;
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
