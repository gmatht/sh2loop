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


sub _tqdm {
    my $cur;
    my $prv;
    $cur = $COMP_WORDS[eval { int($ENV{COMP_CWORD}) } // ""];
    $prv = $COMP_WORDS[eval { int($ENV{COMP_CWORD} - 1) } // ""];
if ($prv =~ /^--bar_format$/msx or $prv =~ /^--buf_size$/msx or $prv =~ /^--colour$/msx or $prv =~ /^--comppath$/msx or $prv =~ /^--delay$/msx or $prv =~ /^--delim$/msx or $prv =~ /^--desc$/msx or $prv =~ /^--initial$/msx or $prv =~ /^--lock_args$/msx or $prv =~ /^--manpath$/msx or $prv =~ /^--maxinterval$/msx or $prv =~ /^--mininterval$/msx or $prv =~ /^--miniters$/msx or $prv =~ /^--ncols$/msx or $prv =~ /^--nrows$/msx or $prv =~ /^--position$/msx or $prv =~ /^--postfix$/msx or $prv =~ /^--smoothing$/msx or $prv =~ /^--total$/msx or $prv =~ /^--unit$/msx or $prv =~ /^--unit_divisor$/msx) {
    } elsif ($prv =~ /^--log$/msx) {
                my $COMPREPLY;
        my @COMPREPLY = (do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'compgen', '-W', 'CRITICAL FATAL ERROR WARN WARNING INFO DEBUG NOTSET', '--', $cur);
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
});
        my %COMPREPLY;
    } elsif (1) {
                @COMPREPLY = (do {
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'compgen', '-W', '--ascii --bar_format --buf_size --bytes --colour --comppath --delay --delim --desc --disable --dynamic_ncols --help --initial --leave --lock_args --log --manpath --maxinterval --mininterval --miniters --ncols --nrows --null --position --postfix --smoothing --tee --total --unit --unit_divisor --unit_scale --update --update_to --version --write_bytes -h -v', '--', $cur);
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    $result_1
});
    }
    return;
}
$main_exit_code = system('complete', '-F', '_tqdm', 'tqdm') >> 8;

exit $main_exit_code;
