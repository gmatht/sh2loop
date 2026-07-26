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

my $var;
my @var;
my %var;
my $array;
my @array;
my %array;
my $file;
my @file;
my %file;

if ((($var =~ /^[0-9]+$/msx && !($CHILD_ERROR = ($main_exit_code = eval { int($var > 0) } // "") ? 0 : 1)) && (-f "$file"))) {
if ((q{} =~ /"value"/msx || !(    $CHILD_ERROR = ($main_exit_code = eval { int(scalar(@array) > 5) } // "") ? 0 : 1))) {
if ((qx'echo "$var" | grep -q "pattern"' ne q{})) {
            print "Deeply nested condition met\n";
        }
    }
}

exit $main_exit_code;
