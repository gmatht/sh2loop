#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use File::Basename;
use IPC::Open3;

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

use POSIX qw(mkfifo);
my $fifo_ps_fh_1 = q{/tmp} . '/ps_fifo_$$_fh_1';
unlink $fifo_ps_fh_1;
mkfifo($fifo_ps_fh_1, 0700) or croak "mkfifo: $ERRNO\n";
my $child_ps_fh_1 = fork();
if ($child_ps_fh_1 == 0) {
    open STDOUT, '>', $fifo_ps_fh_1 or croak "Cannot open fifo: $ERRNO\n";
    select((select(STDOUT), $| = 1)[0]);
while ( 1 ) {
        print q{.} . "\n";
        $CHILD_ERROR = 0;
require Time::HiRes; Time::HiRes::sleep('0.1');
    }
    close STDOUT;
    exit(0);
}
open STDIN, '<', $fifo_ps_fh_1 or croak "Cannot open fifo: $ERRNO\n";
do { my $__head_count = 10; while (<STDIN>) { print $_; last if --$__head_count <= 0; } };
close STDIN;
waitpid($child_ps_fh_1, 0);
unlink $fifo_ps_fh_1;

exit $main_exit_code;
