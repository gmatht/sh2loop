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

my $print_if_bare_repo;
my @print_if_bare_repo;
my %print_if_bare_repo;
$print_if_bare_repo = "\n\tif \"$(git --git-dir=\"$1\" rev-parse --is-bare-repository)\" = true\n\tthen\n\t\tprintf \"%s\\n\" \"${1#./}\"\n\tfi\n";
do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
    require File::Find;
    File::Find::find(sub {     next unless -d $_;     next unless $_ =~ /^.*\.git$/msx;     print "$File::Find::name\n"; }, 'xec');
};

exit $main_exit_code;
