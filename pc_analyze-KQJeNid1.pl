#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use IPC::Open3;
use Digest::SHA   qw(sha256_hex sha512_hex);
use File::Path    qw(make_path remove_tree);
use POSIX qw(time);
sub capture_stdout {
    my ($code) = @_;
    my $captured = q{};
    {
        local *STDOUT;
        open STDOUT, '>', \$captured
          or die "Cannot capture stdout: $OS_ERROR\n";
        $code->();
    }
    return $captured;
}


my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

my $current_user;
my @current_user;
my %current_user;

my $MAGIC_3 = 3;
my $MAGIC_5 = 5;

print "=== Basic Backtick Usage ===\n";
do {
    my $__echo_line = "Current date: " . (do { my $_chomp_temp = do {
require POSIX; POSIX::strftime('%Y', localtime(time())) . "\n"
}; chomp $_chomp_temp; $_chomp_temp; });
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
do {
    my $__echo_line = "Current directory: " . (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do { use Cwd; my $path = getcwd(); $path =~ s/.*\///msx; $path; }; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
my $current_date;
my @current_date;
my %current_date;
$current_date = do {
require POSIX; POSIX::strftime('%Y%m', localtime(time())) . "\n"
};
my $current_dir;
my @current_dir;
my %current_dir;
$current_dir = do { local $CHILD_ERROR = 0; my $_pipeline_result = do { use Cwd; my $path = getcwd(); $path =~ s/.*\///msx; $path; }; $_pipeline_result; };
do {
    my $__echo_line = "Stored date: $current_date";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
do {
    my $__echo_line = "Stored directory: $current_dir";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
print "=== File and Directory Operations ===\n";
my $file_list;
my @file_list;
my %file_list;
$file_list = do {
    my @ls_files_0 = ();
    if ( -f q{.} ) {
        push @ls_files_0, q{.};
    }
    elsif ( -d q{.} ) {
        if ( opendir my $dh, q{.} ) {
            while ( my $file = readdir $dh ) {
                push @ls_files_0, $file;
            }
            closedir $dh;
            @ls_files_0 = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, do { (my $s = $_) =~ s{/$}{}msx; $s } ] } @ls_files_0;
        }
    }
    (@ls_files_0 ? join("\n", @ls_files_0) . "\n" : q{});
};
;
print "File listing:\n";
print $file_list;
if ( !( ($file_list) =~ m{\n\z}msx ) ) { print "\n"; }
my $found_files;
my @found_files;
my %found_files;
$found_files = do {
    require File::Find;
    my @find_results;
    File::Find::find(sub { if (-f $_ && $_ =~ /^.*\.sh$/msx) { push @find_results, $File::Find::name; } }, q{.});
    my $result = join "\n", @find_results;
    if ($result ne q{}) { $result .= "\n"; }
    $CHILD_ERROR = 0;
    $result;
};
print "Found shell scripts:\n";
print $found_files;
if ( !( ($found_files) =~ m{\n\z}msx ) ) { print "\n"; }
print "=== Text Processing Commands ===\n";
my $file_content;
my @file_content;
my %file_content;
$file_content = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_2 = q{};
    my $output_printed_2;
    my $pipeline_success_2 = 1;
    $output_2 = do { my $cat_chunk = q{}; if ( open my $fh, '<', '/etc/passwd' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/etc/passwd' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
    if ($CHILD_ERROR != 0) { $pipeline_success_2 = 0; }
    my $num_lines       = 5;
    my $head_line_count = 0;
    my $result          = q{};
    my $input           = $output_2;
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
    $output_2 = $result;

    if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
    $output_2 =~ s/\n+\z//msx;
    $output_2;
}; $_pipeline_result; };
print "First 5 lines of /etc/passwd:\n";
print $file_content;
if ( !( ($file_content) =~ m{\n\z}msx ) ) { print "\n"; }
my $grep_result;
my @grep_result;
my %grep_result;
$grep_result = do { my $grep_result_3;
my @grep_lines_3 = ();
my @grep_filenames_3 = ();
if (-e "/etc/passwd") {
    open my $fh, '<', "/etc/passwd" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_3, $line;
        push @grep_filenames_3, "/etc/passwd";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /etc/passwd: No such file or directory\n"; }
my @grep_filtered_3 = grep { /bash/msx } @grep_lines_3;
my @grep_numbered_3;
for my $i (0..@grep_lines_3-1) {
    if (scalar grep { $_ eq $grep_lines_3[$i] } @grep_filtered_3) {
        push @grep_numbered_3, sprintf "%d:%s", $i + 1, $grep_lines_3[$i];
    }
}
$grep_result_3 = join "\n", @grep_numbered_3;
$CHILD_ERROR = scalar @grep_filtered_3 > 0 ? 0 : 1;
 $grep_result_3; };
print "Lines containing 'bash':\n";
print $grep_result;
if ( !( ($grep_result) =~ m{\n\z}msx ) ) { print "\n"; }
my $sed_result;
my @sed_result;
my %sed_result;
$sed_result = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_4 = q{};
    my $output_printed_4;
    my $pipeline_success_4 = 1;
    $output_4 .= 'Hello World' . "\n";
    if ( !($output_4 =~ m{\n\z}msx) ) { $output_4 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_4 = 0; }
    my @sed_lines_4 = split /\n/msx, $output_4;
    my @sed_result_4;
    foreach my $line (@sed_lines_4) {
    chomp $line;
    $line =~ s/World/Universe/gmsx;
    push @sed_result_4, $line;
    }
    $output_4 = join "\n", @sed_result_4;

    if ( !$pipeline_success_4 ) { $main_exit_code = 1; }
    $output_4 =~ s/\n+\z//msx;
    $output_4;
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
    my $output_5 = q{};
    my $output_printed_5;
    my $pipeline_success_5 = 1;
    $output_5 .= '1 2 3 4 5' . "\n";
    if ( !($output_5 =~ m{\n\z}msx) ) { $output_5 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_5 = 0; }
    my @lines = split /\n/msx, $output_5;
    my @result;
    foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /^\s*$/msx) { next; }
        my @fields = split /\s+/msx, $line;
        push @result, ($fields[0] + $fields[1] . "\n");
    }
    $output_5 = join "", @result;

    if ( !$pipeline_success_5 ) { $main_exit_code = 1; }
    $output_5 =~ s/\n+\z//msx;
    $output_5;
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
    my $output_6 = q{};
    my $output_printed_6;
    my $pipeline_success_6 = 1;
    $output_6 .= "zebra\napple\nbanana";
    if ( !($output_6 =~ m{\n\z}msx) ) { $output_6 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_6 = 0; }
    my @sort_lines_6_1 = split /\n/msx, $output_6;
    my @sort_sorted_6_1 = sort @sort_lines_6_1;
    $output_6 = join "\n", @sort_sorted_6_1;
        if ($output_6 ne q{} && !($output_6 =~ m{\n\z}msx)) {
            $output_6 .= "\n";
        }
    if ( !$pipeline_success_6 ) { $main_exit_code = 1; }
    $output_6 =~ s/\n+\z//msx;
    $output_6;
}; $_pipeline_result; };
print "Sorted words:\n";
print $sort_result;
if ( !( ($sort_result) =~ m{\n\z}msx ) ) { print "\n"; }
my $uniq_result;
my @uniq_result;
my %uniq_result;
$uniq_result = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_7 = q{};
    my $output_printed_7;
    my $pipeline_success_7 = 1;
    $output_7 .= "apple\napple\nbanana\nbanana\ncherry";
    if ( !($output_7 =~ m{\n\z}msx) ) { $output_7 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_7 = 0; }
    my @uniq_lines_7_1 = split /\n/msx, $output_7;
    @uniq_lines_7_1 = grep { $_ ne q{} } @uniq_lines_7_1; # Filter out empty lines
    my %uniq_seen_7_1;
    my @uniq_result_7_1;
    foreach my $line (@uniq_lines_7_1) {
    if (!$uniq_seen_7_1{$line}++) { push @uniq_result_7_1, $line; }
    }
    $output_7 = join "\n", @uniq_result_7_1;
        if ($output_7 ne q{} && !($output_7 =~ m{\n\z}msx)) {
            $output_7 .= "\n";
        }
    if ( !$pipeline_success_7 ) { $main_exit_code = 1; }
    $output_7 =~ s/\n+\z//msx;
    $output_7;
}; $_pipeline_result; };
print "Unique words:\n";
print $uniq_result;
if ( !( ($uniq_result) =~ m{\n\z}msx ) ) { print "\n"; }
my $word_count;
my @word_count;
my %word_count;
$word_count = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_8 = q{};
    my $output_printed_8;
    my $pipeline_success_8 = 1;
    $output_8 .= 'Hello World' . "\n";
    if ( !($output_8 =~ m{\n\z}msx) ) { $output_8 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_8 = 0; }
    $output_8 = do {
            my $_wc_data = $output_8;
            my $_wc_words = scalar split /\s+/msx, $_wc_data;
            my $_wc_result = q{};
            $_wc_result .= sprintf q{%d}, $_wc_words;
            $_wc_result .= "\n";
            $_wc_result;
        };
    if ( !$pipeline_success_8 ) { $main_exit_code = 1; }
    $output_8 =~ s/\n+\z//msx;
    $output_8;
}; $_pipeline_result; };
my $line_count;
my @line_count;
my %line_count;
$line_count = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_9 = q{};
    my $output_printed_9;
    my $pipeline_success_9 = 1;
    $output_9 .= "line1\nline2\nline3";
    if ( !($output_9 =~ m{\n\z}msx) ) { $output_9 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_9 = 0; }
    $output_9 = do {
            my $_wc_data = $output_9;
            my $_wc_lines = () = $_wc_data =~ /\n/gsxm;
            my $_wc_result = q{};
            $_wc_result .= sprintf q{%d}, $_wc_lines;
            $_wc_result .= "\n";
            $_wc_result;
        };
    if ( !$pipeline_success_9 ) { $main_exit_code = 1; }
    $output_9 =~ s/\n+\z//msx;
    $output_9;
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
    my $head_line_count = 0;
    foreach my $line (@seq_lines_11) {
        chomp $line;
        if ($head_line_count < 3) {
    $output_11 .= $line . "\n";
    ++$head_line_count;
} else {
    $line = q{}; # Clear line to prevent printing
    last; # Break out of the yes loop when head limit is reached
}
    }
    $output_11;
} };
}; $_pipeline_result; };
$main_exit_code = system('bash', ':') >> 8;
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
    do { my $output_12 = q{};
my $output_printed_12;
do {
    my $seq_output_13 = do {
    my $result = q{};
    for my $i (1..10) {
        $result .= "$i\n";
    }
    $result;
};
    my @seq_lines_13 = split /\n/msx, $seq_output_13;
    my $output_13 = q{};
    my @tail_lines = ();
    foreach my $line (@seq_lines_13) {
        chomp $line;
        # tail -3: collecting all lines first (pipeline limitation)
        push @tail_lines, $line;
        $line = q{}; # Clear line to prevent printing
    }
    if (@tail_lines > 0) {
        my @last_lines = @tail_lines[-3..-1];
        $output_13 = join "\n", @last_lines;
        if ($output_13 ne q{}) {
            $output_13 .= "\n";
        }
    }
    $output_13;
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
    my $output_14 = q{};
    my $output_printed_14;
    my $pipeline_success_14 = 1;
    $output_14 .= 'apple:banana:cherry' . "\n";
    if ( !($output_14 =~ m{\n\z}msx) ) { $output_14 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_14 = 0; }
    my @lines_15 = split /\n/msx, $output_14;
    my @result_15;
    foreach my $line (@lines_15) {
    chomp $line;
    my @fields = split /:/msx, $line;
    if (@fields > 1) {
        push @result_15, $fields[1];
    }
    }
    $output_14 = join "\n", @result_15;
    if ($output_14 ne q{} && !($output_14  =~ m{\n\z}msx)) { $output_14 .= "\n"; }

    if ( !$pipeline_success_14 ) { $main_exit_code = 1; }
    $output_14 =~ s/\n+\z//msx;
    $output_14;
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
my $paste_result;
my @paste_result;
my %paste_result;
$paste_result = do { my @_qx_cmd = ("bash -c 'paste <(echo -e \"1\\\\n2\\\\n3\") <(echo -e \"a\\\\nb\\\\nc\")'"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
print "Pasted columns:\n";
print $paste_result;
if ( !( ($paste_result) =~ m{\n\z}msx ) ) { print "\n"; }
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
    my $set1_17 = 'A-Z';
my $set2_17 = 'a-z';
my $input_17 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_17 = $set1_17;
my $expanded_set2_17 = $set2_17;
# Handle a-z range in set1
if ($expanded_set1_17 =~ /a-z/msx) {
    $expanded_set1_17 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_17 =~ /A-Z/msx) {
    $expanded_set1_17 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_17 =~ /\[:upper:\]/msx) {
    $expanded_set1_17 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_17 =~ /\[:lower:\]/msx) {
    $expanded_set1_17 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_17 =~ /a-z/msx) {
    $expanded_set2_17 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_17 =~ /A-Z/msx) {
    $expanded_set2_17 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_17 =~ /\[:upper:\]/msx) {
    $expanded_set2_17 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_17 =~ /\[:lower:\]/msx) {
    $expanded_set2_17 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_16 = q{};
for my $char ( split //msx, $input_17 ) {
    my $pos_17 = index $expanded_set1_17, $char;
    if ( $pos_17 >= 0 && $pos_17 < length $expanded_set2_17 ) {
        $tr_result_16 .= substr $expanded_set2_17, $pos_17, 1;
    } else {
        $tr_result_16 .= $char;
    }
}
$tr_result_16
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
    my $output_18 = q{};
    my $output_printed_18;
    my $pipeline_success_18 = 1;
    $output_18 .= '1 2 3' . "\n";
    if ( !($output_18 =~ m{\n\z}msx) ) { $output_18 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_18 = 0; }
    my @xargs_input_18_1 = grep { $_ ne q{} } split /\s+/msx, $output_18;
    my @xargs_output_18_1;
    for my $i (0..scalar @xargs_input_18_1-1) {
        my @xargs_args_18_1;
        for my $j (0..1-1) {
            push @xargs_args_18_1, $xargs_input_18_1[$i + $j];
        }
        my $xargs_line_18_1 = q{};
        $xargs_line_18_1 .= "Number:";
        foreach my $arg (@xargs_args_18_1) {
            $xargs_line_18_1 .= q{ } . $arg;
        }
        push @xargs_output_18_1, $xargs_line_18_1;
    }
    my $xargs_result_18_1 = join "\n", @xargs_output_18_1;
    if ($xargs_result_18_1 ne q{} && !( $xargs_result_18_1 =~ m{\n\z}msx )) { $xargs_result_18_1 .= "\n"; }
    $output_18 = $xargs_result_18_1;

    if ( !$pipeline_success_18 ) { $main_exit_code = 1; }
    $output_18 =~ s/\n+\z//msx;
    $output_18;
}; $_pipeline_result; };
print "Xargs result:\n";
print $xargs_result;
if ( !( ($xargs_result) =~ m{\n\z}msx ) ) { print "\n"; }
print "=== System Utilities ===\n";
my $timestamp;
my @timestamp;
my %timestamp;
$timestamp = do {
require POSIX; POSIX::strftime('%rms', localtime(time())) . "\n"
};
my $formatted_date;
my @formatted_date;
my %formatted_date;
$formatted_date = do {
require POSIX; POSIX::strftime('%Y-%m-%d %H', localtime(time())) . "\n"
};
do {
    my $__echo_line = "Timestamp: $timestamp";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
do {
    my $__echo_line = "Formatted date: $formatted_date";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
my $time_result;
my @time_result;
my %time_result;
$time_result = do { my @_qx_cmd = ("time sleep 1 2>&1"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
do {
    my $__echo_line = "Time result: $time_result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
my $sleep_duration;
my @sleep_duration;
my %sleep_duration;
$sleep_duration = ("2");
do {
    my $__echo_line = "Sleeping for $sleep_duration seconds...";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
require Time::HiRes; Time::HiRes::sleep($sleep_duration);
my $bash_path;
my @bash_path;
my %bash_path;
$bash_path = do { my $which_cmd = 'which bash'; my $which_output = qx{$which_cmd}; $CHILD_ERROR = $? >> 8; $which_output; };
do {
    my $__echo_line = "Bash path: $bash_path";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
my $yes_result;
my @yes_result;
my %yes_result;
$yes_result = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_20 = q{};
my $output_printed_20;
my $head_line_count = 0;
while (1) {
    my $line = 'Hello';
    if ($head_line_count < 3) {
    $output_20 .= $line . "\n";
    ++$head_line_count;
    } else {
    $line = q{}; # Clear line to prevent printing
    last; # Break out of the yes loop when head limit is reached
    }
}
$output_20 };
}; $_pipeline_result; };
print "Yes command result:\n";
print $yes_result;
if ( !( ($yes_result) =~ m{\n\z}msx ) ) { print "\n"; }
print "=== File Manipulation Commands ===\n";
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', 'test_file.txt'
      or die "Cannot open file: $OS_ERROR\n";
    print "test content\n";
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
my $cp_result;
my @cp_result;
my %cp_result;
$cp_result = do {
    my $left_result_21 = do {
        $CHILD_ERROR = 0;
        my $eval_result = eval {
            use File::Copy qw(copy);
            if ( -e 'test_file.txt' ) {
                if ( -d 'test_file_copy.txt' ) {
                    require File::Copy; File::Copy::copy('test_file.txt', 'test_file_copy.txt' . '/' . ('test_file.txt' =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy('test_file.txt', 'test_file_copy.txt');
                }
            } else {
                croak "cp: cannot stat 'test_file.txt': No such file or directory\n";
            }
            1;
            };
        if ( !$eval_result ) {
            $CHILD_ERROR = 256;
        }
        q{};
};
    if ( $CHILD_ERROR == 0 ) {
        my $right_result_21 = do { ("Copy successful") };
        $left_result_21 . $right_result_21;
    } else {
        q{};
    }
};
do {
    my $__echo_line = "Copy result: $cp_result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
    my @ls_files_22 = ();
    my $ls_all_found_23 = 1;
    my @ls_inputs_24 = ();
    push @ls_inputs_24, 'test_file.txt';
    push @ls_inputs_24, 'test_file_copy.txt';
    push @ls_inputs_24, 'test_file_moved.txt';
    my @ls_files_25 = ();
    my @ls_dirs_26 = ();
    my $ls_show_headers_27 = scalar(@ls_inputs_24) > 1;
    for my $ls_item_28 (@ls_inputs_24) {
        if ( -f $ls_item_28 ) {
            push @ls_files_25, $ls_item_28;
        }
        elsif ( -d $ls_item_28 ) {
            push @ls_dirs_26, $ls_item_28;
        }
        else {
            $ls_all_found_23 = 0;
        }
    }
    @ls_files_25 = sort { $a cmp $b } @ls_files_25;
    @ls_dirs_26 = sort { $a cmp $b } @ls_dirs_26;
    if (@ls_files_25) {
        push @ls_files_22, join("\n", @ls_files_25);
    }
    for my $ls_dir_29 (@ls_dirs_26) {
        my @ls_dir_entries_30 = ();
        if ( opendir my $dh, $ls_dir_29 ) {
            while ( my $file = readdir $dh ) {
                next if $file eq q{.} || $file eq q{..} || $file =~ /^[.]/msx;
                push @ls_dir_entries_30, $file;
            }
            closedir $dh;
            @ls_dir_entries_30 = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, do { (my $s = $_) =~ s{/$}{}msx; $s } ] } @ls_dir_entries_30;
            if ( $ls_show_headers_27 ) {
                if ( @ls_dir_entries_30 ) {
                    push @ls_files_22, $ls_dir_29 . ":\n" . join("\n", @ls_dir_entries_30);
                } else {
                    push @ls_files_22, $ls_dir_29 . ':';
                }
            }
            elsif ( @ls_dir_entries_30 ) {
                push @ls_files_22, join("\n", @ls_dir_entries_30);
            }
        }
        else {
            $ls_all_found_23 = 0;
        }
    }
    if (@ls_files_22) {
        print join "\n\n", @ls_files_22;
        print "\n";
    }
    if ( $ls_all_found_23 ) {
        local $CHILD_ERROR = 0;
        $ls_success = 1;
    }
    else {
        local $CHILD_ERROR = 2;
        $ls_success = 0;
        $main_exit_code = $CHILD_ERROR;
    }
};
if ( !defined $ls_success || $ls_success == 0 ) {
        print "No test files found\n";
}
$main_exit_code = 0;
my $mv_result;
my @mv_result;
my %mv_result;
$mv_result = do {
    my $left_result_31 = do {
        $CHILD_ERROR = 0;
        my $eval_result = eval {
            my $err;
            my $force = 0;
            if ( -e 'test_file_copy.txt' ) {
                my $dest = 'test_file_moved.txt';
                if ( -e $dest && -d $dest ) {
                    my $source_name = 'test_file_copy.txt';
                    $source_name =~ s{^.*[\/]}{};
                    $dest = "$dest/$source_name";
                }
                if ( -e $dest && !$force ) {
                    croak "mv: $dest: File exists (use -f to force overwrite)\n";
                }
                my $dest_dir = $dest;
                $dest_dir =~ s/\/[^\/]*$//msx;
                if ( $dest_dir eq $dest ) {
                    $dest_dir = q{};
                }
                if ( $dest_dir ne q{} && !-d $dest_dir ) {
                    my $err;
                    make_path( $dest_dir, { error => \$err } );
                    if ( @{$err} ) {
                        croak "mv: cannot create directory $dest_dir: $err->[0]\n";
                    }
                }
                require File::Copy;
                if ( File::Copy::move( 'test_file_copy.txt', $dest ) ) {
                } else {
                    croak
              "mv: cannot move 'test_file_copy.txt' to $dest: $ERRNO\n";
                }
            } else {
                croak "mv: 'test_file_copy.txt': No such file or directory\n";
            }
            1;
            };
        if ( !$eval_result ) {
            $CHILD_ERROR = 256;
        }
        q{};
};
    if ( $CHILD_ERROR == 0 ) {
        my $right_result_31 = do { ("Move successful") };
        $left_result_31 . $right_result_31;
    } else {
        q{};
    }
};
do {
    my $__echo_line = "Move result: $mv_result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
    my @ls_files_32 = ();
    my $ls_all_found_33 = 1;
    my @ls_inputs_34 = ();
    push @ls_inputs_34, 'test_file.txt';
    push @ls_inputs_34, 'test_file_copy.txt';
    push @ls_inputs_34, 'test_file_moved.txt';
    my @ls_files_35 = ();
    my @ls_dirs_36 = ();
    my $ls_show_headers_37 = scalar(@ls_inputs_34) > 1;
    for my $ls_item_38 (@ls_inputs_34) {
        if ( -f $ls_item_38 ) {
            push @ls_files_35, $ls_item_38;
        }
        elsif ( -d $ls_item_38 ) {
            push @ls_dirs_36, $ls_item_38;
        }
        else {
            $ls_all_found_33 = 0;
        }
    }
    @ls_files_35 = sort { $a cmp $b } @ls_files_35;
    @ls_dirs_36 = sort { $a cmp $b } @ls_dirs_36;
    if (@ls_files_35) {
        push @ls_files_32, join("\n", @ls_files_35);
    }
    for my $ls_dir_39 (@ls_dirs_36) {
        my @ls_dir_entries_40 = ();
        if ( opendir my $dh, $ls_dir_39 ) {
            while ( my $file = readdir $dh ) {
                next if $file eq q{.} || $file eq q{..} || $file =~ /^[.]/msx;
                push @ls_dir_entries_40, $file;
            }
            closedir $dh;
            @ls_dir_entries_40 = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, do { (my $s = $_) =~ s{/$}{}msx; $s } ] } @ls_dir_entries_40;
            if ( $ls_show_headers_37 ) {
                if ( @ls_dir_entries_40 ) {
                    push @ls_files_32, $ls_dir_39 . ":\n" . join("\n", @ls_dir_entries_40);
                } else {
                    push @ls_files_32, $ls_dir_39 . ':';
                }
            }
            elsif ( @ls_dir_entries_40 ) {
                push @ls_files_32, join("\n", @ls_dir_entries_40);
            }
        }
        else {
            $ls_all_found_33 = 0;
        }
    }
    if (@ls_files_32) {
        print join "\n\n", @ls_files_32;
        print "\n";
    }
    if ( $ls_all_found_33 ) {
        local $CHILD_ERROR = 0;
        $ls_success = 1;
    }
    else {
        local $CHILD_ERROR = 2;
        $ls_success = 0;
        $main_exit_code = $CHILD_ERROR;
    }
};
if ( !defined $ls_success || $ls_success == 0 ) {
        print "No test files found\n";
}
$main_exit_code = 0;
my $rm_result;
my @rm_result;
my %rm_result;
$rm_result = do {
    my $left_result_41 = do {
        $CHILD_ERROR = 0;
        my $eval_result = eval {
            if ( -e "test_file.txt" ) {
                if ( -d "test_file.txt" ) {
                    croak "rm: ", "test_file.txt",
                      " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "test_file.txt" ) {
                                }
                    else {
                        croak "rm: cannot remove ", "test_file.txt",
                          ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 1;
                croak "rm: ", "test_file.txt", ": No such file or directory\n";
            }
            if ( -e "test_file_moved.txt" ) {
                if ( -d "test_file_moved.txt" ) {
                    croak "rm: ", "test_file_moved.txt",
                      " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "test_file_moved.txt" ) {
                                }
                    else {
                        croak "rm: cannot remove ", "test_file_moved.txt",
                          ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 1;
                croak "rm: ", "test_file_moved.txt", ": No such file or directory\n";
            }
            1;
            };
        if ( !$eval_result ) {
            $CHILD_ERROR = 256;
        }
        q{};
};
    if ( $CHILD_ERROR == 0 ) {
        my $right_result_41 = do { ("Remove successful") };
        $left_result_41 . $right_result_41;
    } else {
        q{};
    }
};
do {
    my $__echo_line = "Remove result: $rm_result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
    my @ls_files_42 = ();
    my $ls_all_found_43 = 1;
    my @ls_inputs_44 = ();
    push @ls_inputs_44, 'test_file.txt';
    push @ls_inputs_44, 'test_file_copy.txt';
    push @ls_inputs_44, 'test_file_moved.txt';
    my @ls_files_45 = ();
    my @ls_dirs_46 = ();
    my $ls_show_headers_47 = scalar(@ls_inputs_44) > 1;
    for my $ls_item_48 (@ls_inputs_44) {
        if ( -f $ls_item_48 ) {
            push @ls_files_45, $ls_item_48;
        }
        elsif ( -d $ls_item_48 ) {
            push @ls_dirs_46, $ls_item_48;
        }
        else {
            $ls_all_found_43 = 0;
        }
    }
    @ls_files_45 = sort { $a cmp $b } @ls_files_45;
    @ls_dirs_46 = sort { $a cmp $b } @ls_dirs_46;
    if (@ls_files_45) {
        push @ls_files_42, join("\n", @ls_files_45);
    }
    for my $ls_dir_49 (@ls_dirs_46) {
        my @ls_dir_entries_50 = ();
        if ( opendir my $dh, $ls_dir_49 ) {
            while ( my $file = readdir $dh ) {
                next if $file eq q{.} || $file eq q{..} || $file =~ /^[.]/msx;
                push @ls_dir_entries_50, $file;
            }
            closedir $dh;
            @ls_dir_entries_50 = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, do { (my $s = $_) =~ s{/$}{}msx; $s } ] } @ls_dir_entries_50;
            if ( $ls_show_headers_47 ) {
                if ( @ls_dir_entries_50 ) {
                    push @ls_files_42, $ls_dir_49 . ":\n" . join("\n", @ls_dir_entries_50);
                } else {
                    push @ls_files_42, $ls_dir_49 . ':';
                }
            }
            elsif ( @ls_dir_entries_50 ) {
                push @ls_files_42, join("\n", @ls_dir_entries_50);
            }
        }
        else {
            $ls_all_found_43 = 0;
        }
    }
    if (@ls_files_42) {
        print join "\n\n", @ls_files_42;
        print "\n";
    }
    if ( $ls_all_found_43 ) {
        local $CHILD_ERROR = 0;
        $ls_success = 1;
    }
    else {
        local $CHILD_ERROR = 2;
        $ls_success = 0;
        $main_exit_code = $CHILD_ERROR;
    }
};
if ( !defined $ls_success || $ls_success == 0 ) {
        print "No test files found\n";
}
$main_exit_code = 0;
my $mkdir_result;
my @mkdir_result;
my %mkdir_result;
$mkdir_result = do {
    my $left_result_51 = do {
        $CHILD_ERROR = 0;
        my $eval_result = eval {
            use File::Path qw(make_path);
            if ( mkdir 'test_dir' ) {
                }
            else {
                croak "mkdir: cannot create directory " . 'test_dir' . ": File exists\n";
            }
            $CHILD_ERROR = 0;
            1;
        };
        if ( !$eval_result ) {
            $CHILD_ERROR = 256;
        }
        q{};
};
    if ( $CHILD_ERROR == 0 ) {
        my $right_result_51 = do { ("Directory created") };
        $left_result_51 . $right_result_51;
    } else {
        q{};
    }
};
do {
    my $__echo_line = "Mkdir result: $mkdir_result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
if ( -e "test_dir/file" ) {
    my $current_time = time;
    utime $current_time, $current_time, "test_dir/file";
}
else {
    if ( open my $fh, '>', "test_dir/file" ) {
        close $fh or croak "Close failed: $ERRNO";
    }
    else {
        croak "touch: cannot create ", "test_dir/file",
          ": $ERRNO\n";
    }
}
do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
    my @ls_files_53 = ();
    my $ls_all_found_54 = 1;
    my @ls_inputs_55 = ();
    push @ls_inputs_55, 'test_dir';
    my @ls_files_56 = ();
    my @ls_dirs_57 = ();
    my $ls_show_headers_58 = scalar(@ls_inputs_55) > 1;
    for my $ls_item_59 (@ls_inputs_55) {
        if ( -f $ls_item_59 ) {
            push @ls_files_56, $ls_item_59;
        }
        elsif ( -d $ls_item_59 ) {
            push @ls_dirs_57, $ls_item_59;
        }
        else {
            $ls_all_found_54 = 0;
        }
    }
    @ls_files_56 = sort { $a cmp $b } @ls_files_56;
    @ls_dirs_57 = sort { $a cmp $b } @ls_dirs_57;
    if (@ls_files_56) {
        push @ls_files_53, join("\n", @ls_files_56);
    }
    for my $ls_dir_60 (@ls_dirs_57) {
        my @ls_dir_entries_61 = ();
        if ( opendir my $dh, $ls_dir_60 ) {
            while ( my $file = readdir $dh ) {
                next if $file eq q{.} || $file eq q{..} || $file =~ /^[.]/msx;
                push @ls_dir_entries_61, $file;
            }
            closedir $dh;
            @ls_dir_entries_61 = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, do { (my $s = $_) =~ s{/$}{}msx; $s } ] } @ls_dir_entries_61;
            if ( $ls_show_headers_58 ) {
                if ( @ls_dir_entries_61 ) {
                    push @ls_files_53, $ls_dir_60 . ":\n" . join("\n", @ls_dir_entries_61);
                } else {
                    push @ls_files_53, $ls_dir_60 . ':';
                }
            }
            elsif ( @ls_dir_entries_61 ) {
                push @ls_files_53, join("\n", @ls_dir_entries_61);
            }
        }
        else {
            $ls_all_found_54 = 0;
        }
    }
    if (@ls_files_53) {
        print join "\n", @ls_files_53;
        print "\n";
    }
    if ( $ls_all_found_54 ) {
        local $CHILD_ERROR = 0;
        $ls_success = 1;
    }
    else {
        local $CHILD_ERROR = 2;
        $ls_success = 0;
        $main_exit_code = $CHILD_ERROR;
    }
};
if ( !defined $ls_success || $ls_success == 0 ) {
        print "Directory not found\n";
}
$main_exit_code = 0;
my $touch_result;
my @touch_result;
my %touch_result;
$touch_result = do {
    my $left_result_62 = do {
        $CHILD_ERROR = 0;
        my $eval_result = eval {
            if ( -e "test_file.txt" ) {
                my $current_time = time;
                utime $current_time, $current_time, "test_file.txt";
            }
            else {
                if ( open my $fh, '>', "test_file.txt" ) {
                    close $fh or croak "Close failed: $ERRNO";
                }
                else {
                    croak "touch: cannot create ", "test_file.txt",
                      ": $ERRNO\n";
                }
            }
            $CHILD_ERROR = 0;
            1;
        };
        if ( !$eval_result ) {
            $CHILD_ERROR = 256;
        }
        q{};
};
    if ( $CHILD_ERROR == 0 ) {
        my $right_result_62 = do { ("File touched") };
        $left_result_62 . $right_result_62;
    } else {
        q{};
    }
};
do {
    my $__echo_line = "Touch result: $touch_result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
print "=== Output and Formatting Commands ===\n";
my $echo_result;
my @echo_result;
my %echo_result;
$echo_result = ("Hello from backticks");
do {
    my $__echo_line = "Echo result: $echo_result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
my $printf_result;
my @printf_result;
my %printf_result;
$printf_result = sprintf("Number: %d, String: %s\n", '42', "test");
;
do {
    my $__echo_line = "Printf result: $printf_result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
print "=== Compression Commands ===\n";
print "=== Network Commands ===\n";
print "=== Process Management Commands ===\n";
print "=== Checksum Commands ===\n";
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', 'test_checksum.txt'
      or die "Cannot open file: $OS_ERROR\n";
    print "test content\n";
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
my $sha256_result;
my @sha256_result;
my %sha256_result;
$sha256_result = do {
    my @results;
    if ( -f 'test_checksum.txt' ) {
        my $hash = sha256_hex(
            do {
                local $INPUT_RECORD_SEPARATOR = undef;
                open my $fh, '<', 'test_checksum.txt'
                  or croak "Cannot open 'test_checksum.txt': $ERRNO";
                my $content = <$fh>;
                close $fh
                  or croak "Close failed: $ERRNO";
                $content;
            }
        );
        push @results, "$hash  test_checksum.txt";
    }
    else {
        push @results,
"0000000000000000000000000000000000000000000000000000000000000000  test_checksum.txt  FAILED open or read";
    }
    join("\n", @results) . "\n";
};
;
do {
    my $__echo_line = "SHA256 result: $sha256_result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
my $sha512_result;
my @sha512_result;
my %sha512_result;
$sha512_result = do {
    my @results;
    if ( -f 'test_checksum.txt' ) {
        my $hash = sha512_hex(
            do {
                local $INPUT_RECORD_SEPARATOR = undef;
                open my $fh, '<', 'test_checksum.txt'
                  or croak "Cannot open 'test_checksum.txt': $ERRNO";
                my $content = <$fh>;
                close $fh
                  or croak "Close failed: $ERRNO";
                $content;
            }
        );
        push @results, "$hash  test_checksum.txt";
    }
    else {
        push @results,
"00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000  test_checksum.txt  FAILED open or read";
    }
    join("\n", @results) . "\n";
};
;
do {
    my $__echo_line = "SHA512 result: $sha512_result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
my $strings_result;
my @strings_result;
my %strings_result;
$strings_result = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_63 = q{};
    my $output_printed_63;
    my $pipeline_success_63 = 1;
    my $input_data;
    if ( open my $fh, '<', 'otranspilerl/target/debug/otranspilerl-cli.exe' ) {
        local $INPUT_RECORD_SEPARATOR = undef;    # Read entire file at once
        $input_data = <$fh>;
        close $fh
          or croak "Close failed: $ERRNO";
    }
    else {
        print {*STDERR} "strings: 'otranspilerl/target/debug/otranspilerl-cli.exe': No such file\n";
        $input_data = q{};
    }
    my @result;
    while ($input_data =~ /([\x20-\x7E]{4,})/g) {
        push @result, $1;
    }
    my $line = join "\n", @result;
    if ($line ne q{} && !($line =~ m{\n\z}msx)) { $line .= "\n"; }
    $output_63 = $line;
    if ($CHILD_ERROR != 0) { $pipeline_success_63 = 0; }
    my $num_lines       = 3;
    my $head_line_count = 0;
    my $result          = q{};
    my $input           = $output_63;
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
    $output_63 = $result;

    if ( !$pipeline_success_63 ) { $main_exit_code = 1; }
    $output_63 =~ s/\n+\z//msx;
    $output_63;
}; $_pipeline_result; };
print "Strings result:\n";
print $strings_result;
if ( !( ($strings_result) =~ m{\n\z}msx ) ) { print "\n"; }
print "=== I/O Redirection Commands ===\n";
my $tee_result;
my @tee_result;
my %tee_result;
$tee_result = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_64 = q{};
    my $output_printed_64;
    my $pipeline_success_64 = 1;
    $output_64 .= 'test output' . "\n";
    if ( !($output_64 =~ m{\n\z}msx) ) { $output_64 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_64 = 0; }
    use Carp qw(carp croak);
    if ( open my $fh, '>', 'test_tee.txt' ) {
        print {$fh} $output_64;
        close $fh or croak "Close failed: $ERRNO";
    }
    else {
        carp "tee: Cannot open 'test_tee.txt': $ERRNO";
    }
    $output_64 = $output_64;
    if ( !$pipeline_success_64 ) { $main_exit_code = 1; }
    $output_64 =~ s/\n+\z//msx;
    $output_64;
}; $_pipeline_result; };
do {
    my $__echo_line = "Tee result: $tee_result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
print "=== Perl Command ===\n";
my $perl_result;
my @perl_result;
my %perl_result;
$perl_result = do {
    my $result;
    my $eval_success = eval {
        $result = capture_stdout( sub { print "Hello from Perl\n" } );
        1;
    };
    if ( !$eval_success ) {
        $result = "Error executing Perl code: $EVAL_ERROR";
    }
    $result;
};
do {
    my $__echo_line = "Perl result: $perl_result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
print "=== Complex Backtick Examples ===\n";
my $nested_result;
my @nested_result;
my %nested_result;
$nested_result = ("Current time: " . (do { my $_chomp_temp = do {
require POSIX; POSIX::strftime('%a %b %e %H:%M:%S %Z %Y', localtime(time())) . "\n"
}; chomp $_chomp_temp; $_chomp_temp; }));
do {
    my $__echo_line = "Nested backticks: $nested_result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
my $count;
my @count;
my %count;
$count = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_65 = q{};
    my $output_printed_65;
    my $pipeline_success_65 = 1;
    $output_65 = do {
        my @ls_files_66 = ();
        if ( -f q{.} ) {
            push @ls_files_66, q{.};
        }
        elsif ( -d q{.} ) {
            if ( opendir my $dh, q{.} ) {
                while ( my $file = readdir $dh ) {
                    next if $file eq q{.} || $file eq q{..} || $file =~ /^[.]/msx;
                    push @ls_files_66, $file;
                }
                closedir $dh;
                @ls_files_66 = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, do { (my $s = $_) =~ s{/$}{}msx; $s } ] } @ls_files_66;
            }
        }
        (@ls_files_66 ? join("\n", @ls_files_66) . "\n" : q{});
    };
    ;
    if ($CHILD_ERROR != 0) { $pipeline_success_65 = 0; }
    $output_65 = do {
            my $_wc_data = $output_65;
            my $_wc_lines = () = $_wc_data =~ /\n/gsxm;
            my $_wc_result = q{};
            $_wc_result .= sprintf q{%d}, $_wc_lines;
            $_wc_result .= "\n";
            $_wc_result;
        };
    if ( !$pipeline_success_65 ) { $main_exit_code = 1; }
    $output_65 =~ s/\n+\z//msx;
    $output_65;
}; $_pipeline_result; };
do {
    my $__echo_line = "File count: $count";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
$current_user = do { my $whoami_user = (getpwuid($<))[0]; $whoami_user . "\n"; };
if ("$current_user" eq "root") {
    print "Running as root\n";
}
else {
    print "Not running as root\n";
}
my $system_name;
my @system_name;
my %system_name;
$system_name = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__sys; join(" ", @__parts) . "\n"; };
if ($system_name =~ /^Linux$/msx) {
        print "Running on Linux\n";
} elsif ($system_name =~ /^Darwin$/msx) {
        print "Running on macOS\n";
} elsif (1) {
        print "Running on other " . "sys" . "tem\n";
}

sub get_file_size {
    my $file = $_[0];
    my $size = do {
    my $wc_file = "$file";
    my $wc_file_opened = 0;
    my $content = do {
        my $result = q{};
        if (open my $fh, '<', $wc_file) {
            $wc_file_opened = 1;
            local $INPUT_RECORD_SEPARATOR = undef;
            $result = <$fh>;
            close $fh or warn "Close failed: $OS_ERROR\n";
        } else {
            warn "Cannot open $wc_file: $OS_ERROR\n";
        }
        $result;
    };
    $wc_file_opened ? do {
        my $wc_bytes = length($content);
        $wc_bytes;
    } : q{};
};
    do {
    my $__echo_line = "File $file has $size bytes";
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
get_file_size('000__01_file_directory_operations.sh');
my $files;
my @files = (do { my $_result = `ls -1 *.sh examples/*.sh 2>/dev/null`; chomp $_result; $CHILD_ERROR = $? >> 8; split("\n", $_result); });
my %files;
print "Shell scripts found: " . scalar(@files) . "\n";
$CHILD_ERROR = 0;
my $file;
for my $file (@files) {
    do {
    my $__echo_line = "  - $file";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
}
my $process_result;
my @process_result;
my %process_result;
$process_result = do { my @_qx_cmd = ("bash -c 'comm -23 <(sort file1.txt) <(sort file2.txt)'"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
print "Process substitution result:\n";
print $process_result;
if ( !( ($process_result) =~ m{\n\z}msx ) ) { print "\n"; }
my $here_string_result;
my @here_string_result;
my %here_string_result;
$here_string_result = do { my $input_data = "hello world"; my $set1_69 = 'a-z';
my $set2_69 = 'A-Z';
my $input_69 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_69 = $set1_69;
my $expanded_set2_69 = $set2_69;
# Handle a-z range in set1
if ($expanded_set1_69 =~ /a-z/msx) {
    $expanded_set1_69 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_69 =~ /A-Z/msx) {
    $expanded_set1_69 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_69 =~ /\[:upper:\]/msx) {
    $expanded_set1_69 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_69 =~ /\[:lower:\]/msx) {
    $expanded_set1_69 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_69 =~ /a-z/msx) {
    $expanded_set2_69 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_69 =~ /A-Z/msx) {
    $expanded_set2_69 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_69 =~ /\[:upper:\]/msx) {
    $expanded_set2_69 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_69 =~ /\[:lower:\]/msx) {
    $expanded_set2_69 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_68 = q{};
for my $char ( split //msx, $input_69 ) {
    my $pos_69 = index $expanded_set1_69, $char;
    if ( $pos_69 >= 0 && $pos_69 < length $expanded_set2_69 ) {
        $tr_result_68 .= substr $expanded_set2_69, $pos_69, 1;
    } else {
        $tr_result_68 .= $char;
    }
}
$tr_result_68 };
do {
    my $__echo_line = "Here string result: $here_string_result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
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
if ( -e "test_file.txt" ) {
    if ( -d "test_file.txt" ) {
        carp "rm: carping: ", "test_file.txt",
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "test_file.txt" ) {
                    }
        else {
            carp "rm: carping: could not remove ", "test_file.txt",
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}
if ( -e "test_file_copy.txt" ) {
    if ( -d "test_file_copy.txt" ) {
        carp "rm: carping: ", "test_file_copy.txt",
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "test_file_copy.txt" ) {
                    }
        else {
            carp "rm: carping: could not remove ", "test_file_copy.txt",
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}
if ( -e "test_file_moved.txt" ) {
    if ( -d "test_file_moved.txt" ) {
        carp "rm: carping: ", "test_file_moved.txt",
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "test_file_moved.txt" ) {
                    }
        else {
            carp "rm: carping: could not remove ", "test_file_moved.txt",
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}
if ( -e "test_checksum.txt" ) {
    if ( -d "test_checksum.txt" ) {
        carp "rm: carping: ", "test_checksum.txt",
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "test_checksum.txt" ) {
                    }
        else {
            carp "rm: carping: could not remove ", "test_checksum.txt",
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}
if ( -e "test_tee.txt" ) {
    if ( -d "test_tee.txt" ) {
        carp "rm: carping: ", "test_tee.txt",
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "test_tee.txt" ) {
                    }
        else {
            carp "rm: carping: could not remove ", "test_tee.txt",
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}
do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
if ( -e "test_dir" ) {
        if ( -d "test_dir" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("test_dir", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", "test_dir", ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "test_dir" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "test_dir",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
};
if ($CHILD_ERROR != 0) {
    1;
}
print "=== Backtick Examples Complete ===\n";

exit $main_exit_code;
