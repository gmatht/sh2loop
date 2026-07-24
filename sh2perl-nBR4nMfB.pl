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

print "Testing complex parameter expansions...\n";
my $complex_var;
my @complex_var;
my %complex_var;
$complex_var = "hello world";
print ${complex_var} =~ s/^.*?o//r;
if ( !( (${complex_var} =~ s/^.*?o//r) =~ m{\n\z}msx ) ) { print "\n"; }
print ${complex_var} =~ s/^.*o//sr;
if ( !( (${complex_var} =~ s/^.*o//sr) =~ m{\n\z}msx ) ) { print "\n"; }
do {
    my $__echo_line = scalar reverse( (scalar reverse ${complex_var}) =~ s/^.*?o//r );
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
print ${complex_var} =~ s/o.*$//sr;
if ( !( (${complex_var} =~ s/o.*$//sr) =~ m{\n\z}msx ) ) { print "\n"; }

exit $main_exit_code;
