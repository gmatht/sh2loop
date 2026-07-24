#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use IPC::Open3;
use File::Path qw(make_path remove_tree);

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/tmp/paste_a.txt'
      or die "Cannot open file: $OS_ERROR\n";
    print q{a} . "\n";
    $CHILD_ERROR = 0;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/tmp/paste_b.txt'
      or die "Cannot open file: $OS_ERROR\n";
    print q{b} . "\n";
    $CHILD_ERROR = 0;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
my $paste_result_1 = do {
my @paste_file1_lines_fh_1;
my @paste_file2_lines_fh_1;
if (open my $fh1, '<', '/tmp/paste_a.txt') {
    while (my $line = <$fh1>) {
        chomp $line;
        push @paste_file1_lines_fh_1, $line;
    }
    close $fh1 or croak "Close failed: $OS_ERROR";
}
if (open my $fh2, '<', '/tmp/paste_b.txt') {
    while (my $line = <$fh2>) {
        chomp $line;
        push @paste_file2_lines_fh_1, $line;
    }
    close $fh2 or croak "Close failed: $OS_ERROR";
}
my $max_lines = scalar @paste_file1_lines_fh_1 > scalar @paste_file2_lines_fh_1 ? scalar @paste_file1_lines_fh_1 : scalar @paste_file2_lines_fh_1;
my $paste_output = q{};
for my $i (0..$max_lines-1) {
    my $line1 = $i < scalar @paste_file1_lines_fh_1 ? $paste_file1_lines_fh_1[$i] : q{};
    my $line2 = $i < scalar @paste_file2_lines_fh_1 ? $paste_file2_lines_fh_1[$i] : q{};
    $paste_output .= "$line1\t$line2\n";
}
$paste_output
}
;
print $paste_result_1;
if ( -e "/tmp/paste_a.txt" ) {
    if ( -d "/tmp/paste_a.txt" ) {
        carp "rm: carping: ", "/tmp/paste_a.txt",
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "/tmp/paste_a.txt" ) {
                    }
        else {
            carp "rm: carping: could not remove ", "/tmp/paste_a.txt",
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}
if ( -e "/tmp/paste_b.txt" ) {
    if ( -d "/tmp/paste_b.txt" ) {
        carp "rm: carping: ", "/tmp/paste_b.txt",
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "/tmp/paste_b.txt" ) {
                    }
        else {
            carp "rm: carping: could not remove ", "/tmp/paste_b.txt",
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}

exit $main_exit_code;
