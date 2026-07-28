#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

$__set_e = 1;
my $MESSAGEUSER = 'messagebus';

sub in_sysroot {
if ("${DPKG_ROOT:-}" eq q{}) {
        $CHILD_ERROR = 0;
}
    else {
        $main_exit_code = system('chroot', ($ENV{DPKG_ROOT} // q{}), "\@ARGV") >> 8;
    }
    return;
}
if ("$1" eq configure) {
    in_sysroot('adduser', "--" . "sys" . "tem", '--quiet', '--home', '/nonexistent', '--no-create-home', '--disabled-password', '--group', "$MESSAGEUSER");
}
