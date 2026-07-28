#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

my $main_exit_code = 0;
my $output         = q{};
our $CHILD_ERROR;

my $REPLY;

print "
Providing additional information can help diagnose problems with cryptsetup.
Specifically, this would include:
- kernel cmdline (copy of /proc/cmdline).
- crypttab configuration (copy of /etc/crypttab).
- fstab configuration (copy of /etc/fstab).
If this information is not relevant for your bug report or you have privacy
concerns, please choose no.

";
$main_exit_code = system('yesno', "Do you want to provide additional information [Y|n]? ", 'yep') >> 8;
if (!("$REPLY" eq yep)) {
    exit 0;
}
do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
# Builtin command 'exec' not implemented
};
say "-- /proc/cmdline";
print do { my $cat_chunk = q{}; if ( open my $fh, '<', '/proc/cmdline' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/proc/cmdline' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
print "\n";
if ((-r '/etc/crypttab')) {
    say "-- /etc/crypttab";
print do { my $cat_chunk = q{}; if ( open my $fh, '<', '/etc/crypttab' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/etc/crypttab' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
    print "\n";
}
if ((-r '/etc/fstab')) {
    say "-- /etc/fstab";
print do { my $cat_chunk = q{}; if ( open my $fh, '<', '/etc/fstab' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/etc/fstab' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
    print "\n";
}
say "-- lsmod";
$main_exit_code = system('bash', 'lsmod') >> 8;
print "\n";

exit $main_exit_code;
