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

print "Testing mixed arithmetic...\n";
my $hex;
my @hex;
my %hex;
$hex = '255';
my $octal;
my @octal;
my %octal;
$octal = '511';
my $binary;
my @binary;
my %binary;
$binary = '10';
my $result;
my @result;
my %result;
$result = eval { int( $hex + $octal + $binary ) } // "";
do {
    my $__echo_line = "Mixed base result: $result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;

exit $main_exit_code;
