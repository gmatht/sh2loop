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

$__set_e = 1;
if ("$1" eq configure) {
    use File::Path qw(make_path);
    my $err;
    if ( !-d '/var/lib/dbus' ) {
        make_path( '/var/lib/dbus', { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . '/var/lib/dbus' . ": $err->[0]\n";
        }
    }
    $main_exit_code = system('dbus-uuidgen', '--ensure') >> 8;
}
if (((("$1" eq "configure" || "$1" eq "abort-upgrade") || "$1" eq "abort-deconfigure") || "$1" eq "abort-remove")) {
if ((-x "$(command -v systemd-tmpfiles)")) {
                $main_exit_code = system('systemd-tmpfiles', (defined ($ENV{DPKG_ROOT} // q{}) && ($ENV{DPKG_ROOT} // q{}) ne q{} ? ($ENV{DPKG_ROOT} // q{}) : '--root="$DPKG_ROOT"'), '--create', 'dbus.conf') >> 8;
        if ($CHILD_ERROR != 0) {
            1;
        }
    }
}
exit 0;

exit $main_exit_code;
