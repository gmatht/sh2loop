#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use locale;
use IPC::Open3;
use File::Path qw(make_path remove_tree);

my $main_exit_code = 0;
my $output         = q{};
our $CHILD_ERROR;

my $V1 = $1;
my $V2 = $2;

sub diff_lines {
    my ($file) = @_;
if (!defined $ENV{SHELL_VAR}) { $ENV{SHELL_VAR} = q{}; }
    my $line_num;
    while (<>) {
    # Hunk header?  Grab the beginning in postimage.
    if (/^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@/) {
    $line_num = $_[0];
    next;
    }
    # Have we seen a hunk?  Ignore "diff --git" etc.
    next unless defined $line_num;
    # Deleted line? Ignore.
    if (/^-/) {
    next;
    }
    # Show only the line number of added lines.
    if (/^\+/) {
    print "$line_num\n";
    }
    # Either common context or added line appear in
    # the postimage.  Count it.
    $line_num++;
    }
    return;
}
my $files = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'git', 'diff', '--name-only', "$V1", "$V2", '--', "\\*.c");
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};

my $hash_file;
my $file;
for my $file ($files) {
    # Original bash: git diff "$V1" "$V2" -- "$file" |
do {
        my $output_1 = q{};
        my $output_printed_1;
        my $pipeline_success_1 = 1;
                my ($in_2, $out_2);
        my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'git', 'diff', '--');
        close $in_2 or croak 'Close failed: $OS_ERROR';
        $output_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
        close $out_2 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_2, 0;

                my $cmd_4 = 'diff_lines';
        my ($in_3, $out_3);
        my $pid_3 = open3($in_3, $out_3, '>&STDERR', $cmd_4, );
        print {$in_3} $output_1;
        close $in_3 or croak 'Close failed: $OS_ERROR';
        $output_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
        close $out_3 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_3, 0;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', 'new_lines.txt'
        or die "Cannot access file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_5 = q{};
        my @sort_lines_6 = split /\n/, $output_1;
        my @sort_sorted_6 = sort @sort_lines_6;
        $tmp_redirect_5 = join("\n", @sort_sorted_6);
        $output_1 = $tmp_redirect_5;
        $tmp_redirect_5;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_1; }
        $output_printed_1 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
        }
;
if (system('test', '-s', 'new_lines.txt') >> 8) {
next;
    }
    $hash_file = do {
    do { do {
        my $output_7 = q{};
        my $output_printed_7;
        my $pipeline_success_7 = 1;
        $output_7 .= $file . "\n";
        if ( !($output_7 =~ m{\n\z}) ) { $output_7 .= "\n"; }
        if ($CHILD_ERROR != 0) { $pipeline_success_7 = 0; }
        my @sed_lines_7 = split /\n/, $output_7;
        my @sed_result_7;
        foreach my $line (@sed_lines_7) {
        chomp $line;
        push @sed_result_7, $line;
        }
        $output_7 = join "\n", @sed_result_7;

        if ( !$pipeline_success_7 ) { $main_exit_code = 1; }
        $output_7 =~ s/\n+\z//msx;
        $output_7;
}; };
};
if (system('test', '-s', "$hash_file.gcov") >> 8) {
next;
    }
    # Original bash: sed -ne '/#####:/{
do {
        my $output_8 = q{};
        my $output_printed_8;
        my $pipeline_success_8 = 1;
                my @sed_lines_8 = split /\n/, $;
        my @sed_result_8;
        foreach my $line (@sed_lines_8) {
        chomp $line;
        push @sed_result_8, $line;
        }
        $ = join "\n", @sed_result_8;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', 'uncovered_lines.txt'
        or die "Cannot access file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_9 = q{};
        my @sort_lines_10 = split /\n/, $output_8;
        my @sort_sorted_10 = sort @sort_lines_10;
        $tmp_redirect_9 = join("\n", @sort_sorted_10);
        $output_8 = $tmp_redirect_9;
        $tmp_redirect_9;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_8; }
        $output_printed_8 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_8 ) { $main_exit_code = 1; }
        }
;
    # Original bash: comm -12 uncovered_lines.txt new_lines.txt |
do {
        my $output_11 = q{};
        my $output_printed_11;
        my $pipeline_success_11 = 1;
                my @file1_lines;
        my @file2_lines;
        if (open my $fh1, '<', 'uncovered_lines.txt') {
        while (my $line = <$fh1>) {
        chomp $line;
        push @file1_lines, $line;
        }
        close $fh1 or croak "Close failed: $OS_ERROR";
        }
        if (open my $fh2, '<', 'new_lines.txt') {
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
        $comm_output

                my @sed_lines_11 = split /\n/, $output_11;
        my @sed_result_11;
        foreach my $line (@sed_lines_11) {
        chomp $line;
        push @sed_result_11, $line;
        }
        $output_11 = join "\n", @sed_result_11;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', 'uncovered_new_lines.txt'
        or die "Cannot access file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_12 = q{};
        my @sed_lines_13 = split /\n/, $output_11;
        my @sed_result_13;
        foreach my $line (@sed_lines_13) {
        chomp $line;
        push @sed_result_13, $line;
        }
        $output_11 = join "\n", @sed_result_13;
        $tmp_redirect_12;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_11; }
        $output_printed_11 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_11 ) { $main_exit_code = 1; }
        }
;
    if (do {
if (do {
if (do {
    open STDIN, '<', 'uncovered_new_lines.txt' or croak "Cannot read file: $OS_ERROR\n";
my $grep_result_14;
my @grep_lines_14 = ();
my @grep_filtered_14 = grep { /[^[:space:]]/msx } @grep_lines_14;
$grep_result_14 = join "\n", @grep_filtered_14;
    if (!($grep_result_14 =~ m{\n\z} || $grep_result_14 eq q{})) {
        $grep_result_14 .= "\n";
    }
$CHILD_ERROR = scalar @grep_filtered_14 > 0 ? 0 : 1;
$grep_result_14 = q{};
} == 0) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', 'coverage-data.txt'
      or die "Cannot access file: $OS_ERROR\n";
        my $tmp = do {
        say $file;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
}
    $CHILD_ERROR == 0
}) {
    do {
        my $output_15 = q{};
        my $output_printed_15;
        my $pipeline_success_15 = 1;
                my ($in_16, $out_16);
        my $pid_16 = open3($in_16, $out_16, '>&STDERR', 'git', 'blame', '-s', '--');
        close $in_16 or croak 'Close failed: $OS_ERROR';
        $output_15 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_16> };
        close $out_16 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_16, 0;

                my @sed_lines_15 = split /\n/, $output_15;
        my @sed_result_15;
        foreach my $line (@sed_lines_15) {
        chomp $line;
        $line =~ s/\t//gmsx;
        push @sed_result_15, $line;
        }
        $output_15 = join "\n", @sed_result_15;

                    do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', 'coverage-data.txt'
            or die "Cannot access file: $OS_ERROR\n";
            carp "grep: no pattern specified";
            exit 1;
            if ( !$pipeline_success_15 ) { $main_exit_code = 1; }
            }
    }
        $CHILD_ERROR == 0
    }) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', 'coverage-data.txt'
      or die "Cannot access file: $OS_ERROR\n";
            print "\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
if ( -e "new_lines.txt" ) {
        if ( -d "new_lines.txt" ) {
            carp "rm: carping: ", "new_lines.txt",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "new_lines.txt" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "new_lines.txt",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "uncovered_lines.txt" ) {
        if ( -d "uncovered_lines.txt" ) {
            carp "rm: carping: ", "uncovered_lines.txt",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "uncovered_lines.txt" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "uncovered_lines.txt",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "uncovered_new_lines.txt" ) {
        if ( -d "uncovered_new_lines.txt" ) {
            carp "rm: carping: ", "uncovered_new_lines.txt",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "uncovered_new_lines.txt" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "uncovered_new_lines.txt",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
}
print do { my $cat_chunk = q{}; if ( open my $fh, '<', 'coverage-data.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'coverage-data.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
say "Commits introducing uncovered code:";
my $commit_list = do {
    do { do {
    my $output_18 = q{};
    my $output_printed_18;
    my $pipeline_success_18 = 1;
    $output_18 = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'coverage-data.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'coverage-data.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
    if ($CHILD_ERROR != 0) { $pipeline_success_18 = 0; }
    my $grep_result_18_1;
    my @grep_lines_18_1 = split /\n/msx, $output_18;
    my @grep_filtered_18_1 = grep { /^[0-9a-f]{7,}\ /msx } @grep_lines_18_1;
    $grep_result_18_1 = join "\n", @grep_filtered_18_1;
        if (!($grep_result_18_1 =~ m{\n\z} || $grep_result_18_1 eq q{})) {
            $grep_result_18_1 .= "\n";
        }
    $CHILD_ERROR = scalar @grep_filtered_18_1 > 0 ? 0 : 1;
    $output_18 = $grep_result_18_1;
    my @lines = split /\n/, $output_18;
    my @result;
    foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /^\s*$/msx) { next; }
        my @fields = split /\s+/msx, $line;
        push @result, ($fields[0] . "\n");
    }
    $output_18 = join "", @result;

    my @sort_lines_18_3 = split /\n/, $output_18;
    my @sort_sorted_18_3 = sort @sort_lines_18_3;
        $output_18 = join("\n", @sort_sorted_18_3);
    my @uniq_lines_18_4 = split /\n/, $output_18;
    @uniq_lines_18_4 = grep { $_ ne q{} } @uniq_lines_18_4;;
# Original bash: #!/bin/sh
do {
    my $output_19 = q{};
    my $output_printed_19;
    my $pipeline_success_19 = 1;
        $output_19 = q{};
    my @_pcmd_21 = ('sh', '-c', q[    my $commit;
    for my $commit ($commit_list) {
    $main_exit_code = system('git', 'log', '--no-decorate', '--pretty=format:', '%an      %h: %s', '-1', $commit) >> 8;
    print "\n";
    }
    ]);
    my ($in_20, $out_20);
    my $pid_20 = open3($in_20, $out_20, '>&STDERR', @_pcmd_21);
    close $in_20 or croak 'Close failed: $OS_ERROR';
    $output_19 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> };
    close $out_20 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_20, 0;

        my @sort_lines_19_1 = split /\n/, $output_19;
    my @sort_sorted_19_1 = sort @sort_lines_19_1;
    my $output_19_1 = join("\n", @sort_sorted_19_1);
    $output_19 = $output_19_1;
    $output_19 = $output_19_1;
    if ($output_19 ne q{} && !defined $output_printed_19) {
        print $output_19;
        if (!($output_19 =~ m{\n\z})) {
            print "\n";
        }
    }
    if ( !$pipeline_success_19 ) { $main_exit_code = 1; }
    }
if ( -e "coverage-data.txt" ) {
    if ( -d "coverage-data.txt" ) {
        croak "rm: ", "coverage-data.txt",
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "coverage-data.txt" ) {
                    }
        else {
            croak "rm: cannot remove ", "coverage-data.txt",
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 1;
    croak "rm: ", "coverage-data.txt", ": No such file or directory\n";
}

exit $main_exit_code;
}
}
}
}
}
