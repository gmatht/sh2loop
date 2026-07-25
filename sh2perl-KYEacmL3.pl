#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

$__set_e = 1;
if ("$_[0]" =~ /^remove$/msx or "$_[0]" =~ /^upgrade$/msx or "$_[0]" =~ /^deconfigure$/msx) {
        $main_exit_code = system('update-alternatives', '--remove', 'tdbbackup', '/usr/bin/tdbbackup.tdbtools') >> 8;
} elsif ("$_[0]" =~ /^failed-upgrade$/msx) {
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "prerm called with unknown argument \\" . chr(96) . "$_[0]'";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
    exit 1;
}
exit 0;

exit $main_exit_code;
