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

my $file;
for my $file ('/usr/share/figlet/*.flf') {
    my $FONT;
    my @FONT;
    my %FONT;
    $FONT = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_0 = q{};
    my $output_printed_0;
    my $output_1 = q{};
    while (my $line = <>) {
        chomp $line;
        # basename doesn't support line-by-line processing
        $line =~ "s|\\(.*\\)\\.\\(.*\\)|\\1|";
    }
    $output_1; };
}; $_pipeline_result; };
printf("Font: \n");
    $main_exit_code = system('figlet', '-f', $FONT, 'Moo') >> 8;
printf("\n");
}

exit $main_exit_code;
