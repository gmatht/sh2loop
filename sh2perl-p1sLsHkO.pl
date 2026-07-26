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

my $MAGIC_5 = 5;
my $MAGIC_3 = 3;

print "=== Text Processing Commands ===\n";
my $file_content;
my @file_content;
my %file_content;
$file_content = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;
    $output_0 = do { my $cat_chunk = q{}; if ( open my $fh, '<', '000__04c_text_processing_commands.sh' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '000__04c_text_processing_commands.sh' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
    if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
    my $num_lines       = 5;
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

    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    $output_0 =~ s/\n+\z//msx;
    $output_0;
}; $_pipeline_result; };
print "First 5 lines of this file:\n";
print $file_content;
if ( !( ($file_content) =~ m{\n\z}msx ) ) { print "\n"; }
my $grep_result;
my @grep_result;
my %grep_result;
$grep_result = do { my $grep_result_1;
my @grep_lines_1 = ();
my @grep_filenames_1 = ();
if (-e "000__04c_text_processing_commands.sh") {
    open my $fh, '<', "000__04c_text_processing_commands.sh" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_1, $line;
        push @grep_filenames_1, "000__04c_text_processing_commands.sh";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: 000__04c_text_processing_commands.sh: No such file or directory\n"; }
my @grep_filtered_1 = grep { /echo/msx } @grep_lines_1;
my @grep_numbered_1;
for my $i (0..@grep_lines_1-1) {
    if (scalar grep { $_ eq $grep_lines_1[$i] } @grep_filtered_1) {
        push @grep_numbered_1, sprintf "%d:%s", $i + 1, $grep_lines_1[$i];
    }
}
$grep_result_1 = join "\n", @grep_numbered_1;
$CHILD_ERROR = scalar @grep_filtered_1 > 0 ? 0 : 1;
 $grep_result_1; };
print "Lines containing 'echo':\n";
print $grep_result;
if ( !( ($grep_result) =~ m{\n\z}msx ) ) { print "\n"; }
my $sed_result;
my @sed_result;
my %sed_result;
$sed_result = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_2 = q{};
    my $output_printed_2;
    my $pipeline_success_2 = 1;
    $output_2 .= 'Hello World' . "\n";
    if ( !($output_2 =~ m{\n\z}msx) ) { $output_2 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_2 = 0; }
    my @sed_lines_2 = split /\n/msx, $output_2;
    my @sed_result_2;
    foreach my $line (@sed_lines_2) {
    chomp $line;
    $line =~ s/World/Universe/gmsx;
    push @sed_result_2, $line;
    }
    $output_2 = join "\n", @sed_result_2;

    if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
    $output_2 =~ s/\n+\z//msx;
    $output_2;
}; $_pipeline_result; };
do {
    my $__echo_line = "Sed result: $sed_result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
my $awk_result;
my @awk_result;
my %awk_result;
$awk_result = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_3 = q{};
    my $output_printed_3;
    my $pipeline_success_3 = 1;
    $output_3 .= '1 2 3 4 5' . "\n";
    if ( !($output_3 =~ m{\n\z}msx) ) { $output_3 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_3 = 0; }
    my @lines = split /\n/msx, $output_3;
    my @result;
    foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /^\s*$/msx) { next; }
        my @fields = split /\s+/msx, $line;
        push @result, ($fields[0] + $fields[1] . "\n");
    }
    $output_3 = join "", @result;

    if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
    $output_3 =~ s/\n+\z//msx;
    $output_3;
}; $_pipeline_result; };
do {
    my $__echo_line = "Awk sum result: $awk_result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
my $sort_result;
my @sort_result;
my %sort_result;
$sort_result = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_4 = q{};
    my $output_printed_4;
    my $pipeline_success_4 = 1;
    $output_4 .= "zebra\napple\nbanana";
    if ( !($output_4 =~ m{\n\z}msx) ) { $output_4 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_4 = 0; }
    my @sort_lines_4_1 = split /\n/msx, $output_4;
    my @sort_sorted_4_1 = sort @sort_lines_4_1;
    $output_4 = join "\n", @sort_sorted_4_1;
        if ($output_4 ne q{} && !($output_4 =~ m{\n\z}msx)) {
            $output_4 .= "\n";
        }
    if ( !$pipeline_success_4 ) { $main_exit_code = 1; }
    $output_4 =~ s/\n+\z//msx;
    $output_4;
}; $_pipeline_result; };
print "Sorted words:\n";
print $sort_result;
if ( !( ($sort_result) =~ m{\n\z}msx ) ) { print "\n"; }
my $uniq_result;
my @uniq_result;
my %uniq_result;
$uniq_result = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_5 = q{};
    my $output_printed_5;
    my $pipeline_success_5 = 1;
    $output_5 .= "apple\napple\nbanana\nbanana\ncherry";
    if ( !($output_5 =~ m{\n\z}msx) ) { $output_5 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_5 = 0; }
    my @uniq_lines_5_1 = split /\n/msx, $output_5;
    @uniq_lines_5_1 = grep { $_ ne q{} } @uniq_lines_5_1; # Filter out empty lines
    my %uniq_seen_5_1;
    my @uniq_result_5_1;
    foreach my $line (@uniq_lines_5_1) {
    if (!$uniq_seen_5_1{$line}++) { push @uniq_result_5_1, $line; }
    }
    $output_5 = join "\n", @uniq_result_5_1;
        if ($output_5 ne q{} && !($output_5 =~ m{\n\z}msx)) {
            $output_5 .= "\n";
        }
    if ( !$pipeline_success_5 ) { $main_exit_code = 1; }
    $output_5 =~ s/\n+\z//msx;
    $output_5;
}; $_pipeline_result; };
print "Unique words:\n";
print $uniq_result;
if ( !( ($uniq_result) =~ m{\n\z}msx ) ) { print "\n"; }
my $word_count;
my @word_count;
my %word_count;
$word_count = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_6 = q{};
    my $output_printed_6;
    my $pipeline_success_6 = 1;
    $output_6 .= 'Hello World' . "\n";
    if ( !($output_6 =~ m{\n\z}msx) ) { $output_6 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_6 = 0; }
    $output_6 = do {
            my $_wc_data = $output_6;
            my $_wc_words = scalar split /\s+/msx, $_wc_data;
            my $_wc_result = q{};
            $_wc_result .= sprintf q{%d}, $_wc_words;
            $_wc_result .= "\n";
            $_wc_result;
        };
    if ( !$pipeline_success_6 ) { $main_exit_code = 1; }
    $output_6 =~ s/\n+\z//msx;
    $output_6;
}; $_pipeline_result; };
my $line_count;
my @line_count;
my %line_count;
$line_count = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_7 = q{};
    my $output_printed_7;
    my $pipeline_success_7 = 1;
    $output_7 .= "line1\nline2\nline3";
    if ( !($output_7 =~ m{\n\z}msx) ) { $output_7 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_7 = 0; }
    $output_7 = do {
            my $_wc_data = $output_7;
            my $_wc_lines = () = $_wc_data =~ /\n/gsxm;
            my $_wc_result = q{};
            $_wc_result .= sprintf q{%d}, $_wc_lines;
            $_wc_result .= "\n";
            $_wc_result;
        };
    if ( !$pipeline_success_7 ) { $main_exit_code = 1; }
    $output_7 =~ s/\n+\z//msx;
    $output_7;
}; $_pipeline_result; };
do {
    my $__echo_line = "Word count: $word_count";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
do {
    my $__echo_line = "Line count: $line_count";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
my $head_result;
my @head_result;
my %head_result;
$head_result = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_8 = q{};
my $output_printed_8;
do {
    my $seq_output_9 = do {
    my $result = q{};
    for my $i (1..10) {
        $result .= "$i\n";
    }
    $result;
};
    my @seq_lines_9 = split /\n/msx, $seq_output_9;
    my $output_9 = q{};
    my $head_line_count = 0;
    foreach my $line (@seq_lines_9) {
        chomp $line;
        if ($head_line_count < 3) {
    $output_9 .= $line . "\n";
    ++$head_line_count;
} else {
    $line = q{}; # Clear line to prevent printing
    last; # Break out of the yes loop when head limit is reached
}
    }
    $output_9;
} };
}; $_pipeline_result; };
do {
    my $__echo_line = "First 3 numbers: $head_result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
my $tail_result;
my @tail_result;
my %tail_result;
$tail_result = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_10 = q{};
my $output_printed_10;
do {
    my $seq_output_11 = do {
    my $result = q{};
    for my $i (1..10) {
        $result .= "$i\n";
    }
    $result;
};
    my @seq_lines_11 = split /\n/msx, $seq_output_11;
    my $output_11 = q{};
    my @tail_lines = ();
    foreach my $line (@seq_lines_11) {
        chomp $line;
        # tail -3: collecting all lines first (pipeline limitation)
        push @tail_lines, $line;
        $line = q{}; # Clear line to prevent printing
    }
    if (@tail_lines > 0) {
        my @last_lines = @tail_lines[-3..-1];
        $output_11 = join "\n", @last_lines;
        if ($output_11 ne q{}) {
            $output_11 .= "\n";
        }
    }
    $output_11;
} };
}; $_pipeline_result; };
do {
    my $__echo_line = "Last 3 numbers: $tail_result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
my $cut_result;
my @cut_result;
my %cut_result;
$cut_result = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_12 = q{};
    my $output_printed_12;
    my $pipeline_success_12 = 1;
    $output_12 .= 'apple:banana:cherry' . "\n";
    if ( !($output_12 =~ m{\n\z}msx) ) { $output_12 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_12 = 0; }
    my @lines_13 = split /\n/msx, $output_12;
    my @result_13;
    foreach my $line (@lines_13) {
    chomp $line;
    my @fields = split /:/msx, $line;
    if (@fields > 1) {
        push @result_13, $fields[1];
    }
    }
    $output_12 = join "\n", @result_13;
    if ($output_12 ne q{} && !($output_12  =~ m{\n\z}msx)) { $output_12 .= "\n"; }

    if ( !$pipeline_success_12 ) { $main_exit_code = 1; }
    $output_12 =~ s/\n+\z//msx;
    $output_12;
}; $_pipeline_result; };
do {
    my $__echo_line = "Second field: $cut_result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', 'temp1.txt'
      or die "Cannot open file: $OS_ERROR\n";
    print "1\n2\n3" . "\n";
    $CHILD_ERROR = 0;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', 'temp2.txt'
      or die "Cannot open file: $OS_ERROR\n";
    print "a\nb\nc" . "\n";
    $CHILD_ERROR = 0;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
my $paste_result;
my @paste_result;
my %paste_result;
$paste_result = do {
my @paste_file1_lines_fh_1;
my @paste_file2_lines_fh_1;
if (open my $fh1, '<', 'temp1.txt') {
    while (my $line = <$fh1>) {
        chomp $line;
        push @paste_file1_lines_fh_1, $line;
    }
    close $fh1 or croak "Close failed: $OS_ERROR";
}
if (open my $fh2, '<', 'temp2.txt') {
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
print "Pasted columns:\n";
print $paste_result;
if ( !( ($paste_result) =~ m{\n\z}msx ) ) { print "\n"; }
if ( -e "temp1.txt" ) {
    if ( -d "temp1.txt" ) {
        carp "rm: carping: ", "temp1.txt",
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "temp1.txt" ) {
                    }
        else {
            carp "rm: carping: could not remove ", "temp1.txt",
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}
if ( -e "temp2.txt" ) {
    if ( -d "temp2.txt" ) {
        carp "rm: carping: ", "temp2.txt",
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "temp2.txt" ) {
                    }
        else {
            carp "rm: carping: could not remove ", "temp2.txt",
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', 'file1.txt'
      or die "Cannot open file: $OS_ERROR\n";
    print "apple\nbanana\ncherry" . "\n";
    $CHILD_ERROR = 0;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', 'file2.txt'
      or die "Cannot open file: $OS_ERROR\n";
    print "banana\ncherry\ndate" . "\n";
    $CHILD_ERROR = 0;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
my $comm_result;
my @comm_result;
my %comm_result;
$comm_result = do { my @file1_lines;
my @file2_lines;
if (open my $fh1, '<', 'file1.txt') {
    while (my $line = <$fh1>) {
        chomp $line;
        push @file1_lines, $line;
    }
    close $fh1 or croak "Close failed: $OS_ERROR";
}
if (open my $fh2, '<', 'file2.txt') {
    while (my $line = <$fh2>) {
        chomp $line;
        push @file2_lines, $line;
    }
    close $fh2 or croak "Close failed: $OS_ERROR";
}
my %file1_set = map { $_ => 1 } @file1_lines;
my %file2_set = map { $_ => 1 } @file2_lines;
my @common_lines;
foreach my $line (@file1_lines) {
    if (exists $file2_set{$line}) {
        push @common_lines, $line;
    }
}
my $comm_output = q{};
foreach my $line (@common_lines) {
    $comm_output .= $line . "\n";
}
$comm_output =~ s/\n$//msx;
$comm_output };
print "Common lines:\n";
print $comm_result;
if ( !( ($comm_result) =~ m{\n\z}msx ) ) { print "\n"; }
my $diff_result;
my @diff_result;
my %diff_result;
$diff_result = do { my $diff_output = q{};
{
    my $diff_cmd = 'diff';
    my @diff_args = ('file1.txt', 'file2.txt');
    my $diff_pid = open my $diff_fh, q{-|}, $diff_cmd, @diff_args;
    if ($diff_pid) {
        local $INPUT_RECORD_SEPARATOR = undef;
        $diff_output = <$diff_fh>;
        close $diff_fh;
        $CHILD_ERROR = $? >> 8;
    } else {
        carp "Cannot execute diff command: $OS_ERROR";
        $diff_output = q{};
        $CHILD_ERROR = 1;
    }
}
$diff_output;
 };
print "File differences:\n";
print $diff_result;
if ( !( ($diff_result) =~ m{\n\z}msx ) ) { print "\n"; }
my $tr_result;
my @tr_result;
my %tr_result;
$tr_result = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("HELLO WORLD") . "\n";
    my $set1_15 = 'A-Z';
my $set2_15 = 'a-z';
my $input_15 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_15 = $set1_15;
my $expanded_set2_15 = $set2_15;
# Handle a-z range in set1
if ($expanded_set1_15 =~ /a-z/msx) {
    $expanded_set1_15 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_15 =~ /A-Z/msx) {
    $expanded_set1_15 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_15 =~ /\[:upper:\]/msx) {
    $expanded_set1_15 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_15 =~ /\[:lower:\]/msx) {
    $expanded_set1_15 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_15 =~ /a-z/msx) {
    $expanded_set2_15 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_15 =~ /A-Z/msx) {
    $expanded_set2_15 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_15 =~ /\[:upper:\]/msx) {
    $expanded_set2_15 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_15 =~ /\[:lower:\]/msx) {
    $expanded_set2_15 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_14 = q{};
for my $char ( split //msx, $input_15 ) {
    my $pos_15 = index $expanded_set1_15, $char;
    if ( $pos_15 >= 0 && $pos_15 < length $expanded_set2_15 ) {
        $tr_result_14 .= substr $expanded_set2_15, $pos_15, 1;
    } else {
        $tr_result_14 .= $char;
    }
}
$tr_result_14
}; $_pipeline_result; };
do {
    my $__echo_line = "Lowercase: $tr_result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
my $xargs_result;
my @xargs_result;
my %xargs_result;
$xargs_result = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_16 = q{};
    my $output_printed_16;
    my $pipeline_success_16 = 1;
    $output_16 .= '1 2 3' . "\n";
    if ( !($output_16 =~ m{\n\z}msx) ) { $output_16 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_16 = 0; }
    my @xargs_input_16_1 = grep { $_ ne q{} } split /\s+/msx, $output_16;
    my @xargs_output_16_1;
    for my $i (0..scalar @xargs_input_16_1-1) {
        my @xargs_args_16_1;
        for my $j (0..1-1) {
            push @xargs_args_16_1, $xargs_input_16_1[$i + $j];
        }
        my $xargs_line_16_1 = q{};
        $xargs_line_16_1 .= "Number:";
        foreach my $arg (@xargs_args_16_1) {
            $xargs_line_16_1 .= q{ } . $arg;
        }
        push @xargs_output_16_1, $xargs_line_16_1;
    }
    my $xargs_result_16_1 = join "\n", @xargs_output_16_1;
    if ($xargs_result_16_1 ne q{} && !( $xargs_result_16_1 =~ m{\n\z}msx )) { $xargs_result_16_1 .= "\n"; }
    $output_16 = $xargs_result_16_1;

    if ( !$pipeline_success_16 ) { $main_exit_code = 1; }
    $output_16 =~ s/\n+\z//msx;
    $output_16;
}; $_pipeline_result; };
print "Xargs result:\n";
print $xargs_result;
if ( !( ($xargs_result) =~ m{\n\z}msx ) ) { print "\n"; }
if ( -e "file1.txt" ) {
    if ( -d "file1.txt" ) {
        carp "rm: carping: ", "file1.txt",
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "file1.txt" ) {
                    }
        else {
            carp "rm: carping: could not remove ", "file1.txt",
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}
if ( -e "file2.txt" ) {
    if ( -d "file2.txt" ) {
        carp "rm: carping: ", "file2.txt",
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "file2.txt" ) {
                    }
        else {
            carp "rm: carping: could not remove ", "file2.txt",
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}
print "=== Text Processing Commands Complete ===\n";

exit $main_exit_code;
