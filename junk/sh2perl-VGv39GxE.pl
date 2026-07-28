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

my $MAGIC_20 = 20;

$__set_e = 1;

sub slave {
    my $dir;
    my @dir;
    my %dir;
    $dir = $1;
    my $filename;
    my @filename;
    my %filename;
    $filename = $2;
    my $target;
    my @target;
    my %target;
    $target = $3;
    do {
    my $__echo_line = "--slave $dir/$filename $filename $dir/$target";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    return;
}
$main_exit_code = system('update-alternatives', '--install', '/usr/bin/lzma', 'lzma', '/usr/bin/xz', '20', do { my ($in_0, $out_0); my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'slave', ''/usr/share/man/man1'', ''lzma.1.gz'', ''xz.1.gz''); close $in_0 or croak 'Close failed: $OS_ERROR'; my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> }; close $out_0 or croak 'Close failed: $OS_ERROR'; waitpid $pid_0, 0; $result_0 }) >> 8;

exit $main_exit_code;
