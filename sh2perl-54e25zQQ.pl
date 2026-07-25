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

if ((-t 1)) {
if (Variable("#", false, None) eq 0) {
if ((-t 0)) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                print "Missing filename\n";
            };
exit $main_exit_code;
        }
        $main_exit_code = system('vim', '--cmd', 'let no_plugin_maps = 1', '-c', 'runtime! macros/less.vim', q{-}) >> 8;
}
    else {
        $main_exit_code = system('vim', '--cmd', 'let no_plugin_maps = 1', '-c', 'runtime! macros/less.vim', "@ARGV") >> 8;
    }
}
else {
if (Variable("#", false, None) eq 0) {
if ((-t 0)) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                print "Missing filename\n";
            };
exit $main_exit_code;
        }
my $cat_stdin = do { local $INPUT_RECORD_SEPARATOR = undef; <STDIN> };
print $cat_stdin;
}
    else {
print do { my $cat_chunk = q{}; if ( open my $fh, '<', "@ARGV" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "@ARGV" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
    }
}

exit $main_exit_code;
