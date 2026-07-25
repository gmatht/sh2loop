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

if (StringInterpolation(StringInterpolation { parts: [Variable("GIT_PUSH_OPTION_COUNT")] }, None) ne q{}) {
    my $i;
    my @i;
    my %i;
    $i = q{0};
while ( (StringInterpolation(StringInterpolation { parts: [Variable("i")] }, None) < StringInterpolation(StringInterpolation { parts: [Variable("GIT_PUSH_OPTION_COUNT")] }, None)) ) {
do { my $eval_input = "value=$GIT_PUSH_OPTION_" . $i; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
if ("$ENV{value}" =~ /^echoback=.*$/msx) {
                        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "echo from the pre-receive-hook: " . (($ENV{value} // q{}) =~ s/^.*?=//r =~ s/^.*?=//r);
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
            };
        } elsif ("$ENV{value}" =~ /^reject$/msx) {
            exit 1;
        }
        $i = eval { int($i + 1) } // "";
    }
}

exit $main_exit_code;
