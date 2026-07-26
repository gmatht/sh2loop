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

my $result;
my @result;
my %result;
my $var;
my @array;
my $index;
$result = eval { int( (defined $var && $var ne q{} ? $var : 0) + (defined $array[(defined $index && $index ne q{} ? $index : 0)] && $array[(defined $index && $index ne q{} ? $index : 0)] ne q{} ? $array[(defined $index && $index ne q{} ? $index : 0)] : 0) ) } // "";
do {
    my $__echo_line = "Eval result: $result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;

exit $main_exit_code;
