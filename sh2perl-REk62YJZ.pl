#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;
use File::Path qw(make_path remove_tree);

our $CHILD_ERROR;

my $tmp = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'tempfile');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', $tmp
      or die "Cannot access file: $OS_ERROR\n";
my $cat_stdin = do { local $INPUT_RECORD_SEPARATOR = undef; <STDIN> };
print $cat_stdin;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
$main_exit_code = system('run-parts', '--report', '--lsbsysinit', '--arg=', $tmp, '--arg=$1', '--arg=$2', '--arg=$3', '--', '/etc/smartmontools/run.d') >> 8;
if ( -e "$tmp" ) {
    if ( -d "$tmp" ) {
        carp "rm: carping: ", $tmp,
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "$tmp" ) {
                    }
        else {
            carp "rm: carping: could not remove ", $tmp,
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}
