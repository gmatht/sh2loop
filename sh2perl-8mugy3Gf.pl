#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

$__set_e = 1;
my $PROGRAM = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'dpkg-divert', '--truename', '/usr/bin/arping');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
if ("$1" eq configure) {
if (!(system('setcap', 'cap_net_raw+ep', $PROGRAM) >> 8)) {
chmod(oct('u-s'), ($PROGRAM)) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    }
}
exit 0;
