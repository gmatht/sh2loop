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

if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("1")] }, None)')) {
    print $1;
if ( !( ($1) =~ m{\n\z}msx ) ) { print "\n"; }
}
else {
    print join(" ", grep { length } split /\s+/msx, do { use File::Basename qw(dirname); my $dirname_output = dirname($1); $CHILD_ERROR = 0; $dirname_output; }) . q{ } . q{/} . q{ } . join(" ", grep { length } split /\s+/msx, do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_0 = q{};
    my $output_printed_0;
    my $output_1 = q{};
    while (my $line = <>) {
        chomp $line;
        # basename doesn't support line-by-line processing
        # awk doesn't support line-by-line processing
    }
    $output_1; };
}; $_pipeline_result; }) . q{ } . '.afm' . "\n";
    $CHILD_ERROR = 0;
}

exit $main_exit_code;
