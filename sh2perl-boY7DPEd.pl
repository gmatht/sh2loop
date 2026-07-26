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

if ((-f '/etc/passwd')) {
    # Original bash: cat /etc/passwd | head -3 | cut -d: -f1
{
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
                $output_0 = do { my $cat_chunk = q{}; if ( open my $fh, '<', '/etc/passwd' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/etc/passwd' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };

                my $num_lines       = 3;
        my $head_line_count = 0;
        my $result          = q{};
        my $input           = $output_0;
        my $pos             = 0;
        while ( $pos < length $input && $head_line_count < $num_lines ) {
        my $line_end = index $input, "\n", $pos;
        if ( $line_end == -1 ) {
        $line_end = length $input;
        }
        my $head_line = substr $input, $pos, $line_end - $pos;
        $result .= $head_line . "\n";
        $pos = $line_end + 1;
        ++$head_line_count;
        }
        $output_0 = $result;

                my @lines_1 = split /\n/msx, $output_0;
        my @result_1;
        foreach my $line (@lines_1) {
        chomp $line;
        my @fields = split /:/msx, $line;
        if (@fields > 0) {
        push @result_1, $fields[0];
        }
        }
        $output_0 = join "\n", @result_1;
        if ($output_0 ne q{} && !($output_0  =~ m{\n\z}msx)) { $output_0 .= "\n"; }
        if ($output_0 ne q{} && !defined $output_printed_0) {
            print $output_0;
            if (!($output_0 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        }
}
else {
    print "not found\n";
}

exit $main_exit_code;
