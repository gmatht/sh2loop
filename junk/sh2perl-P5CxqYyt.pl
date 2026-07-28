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

my $debugfd;
my @debugfd;
my %debugfd;

$ENV{LD_PRELOAD} = '';
while ( $main_exit_code = system('getopts', "n:D:f", 'opt') >> 8 ) {
if ("$ENV{opt}" =~ /^n$/msx) {
        $ENV{NOCACHE_NR_FADVISE} = '';
    } elsif ("$ENV{opt}" =~ /^f$/msx) {
        $ENV{NOCACHE_FLUSHALL} = 1;
    } elsif ("$ENV{opt}" =~ /^D$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$ENV{OPTARG}"
      or die "Cannot open file: $OS_ERROR\n";
# Builtin command 'exec' not implemented
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        $ENV{NOCACHE_DEBUGFD} = '';
    }
}
# Builtin command 'shift' not implemented
if (! "$debugfd" eq q{}) {
        do {
local *STDERR;
open STDERR, '>', $debugfd or croak "Cannot open file: $OS_ERROR\n";
        print "[nocache] DEBUG: Executing: @ARGV\n";
    };
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
# Builtin command 'exec' not implemented

exit $main_exit_code;
