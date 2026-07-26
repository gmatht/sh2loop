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

# set -o nounset not implemented
# set nounset not implemented

sub useseclabel {
    my $VER;
    my @VER;
    my %VER;
    $VER = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__rel; join(" ", @__parts) . "\n"; };
    my $SUP;
    my @SUP;
    my %SUP;
    $SUP = '2.6.30';
    $main_exit_code = system('expr', q{(}, "$VER", q{:}, "\\([^.]*\\)", q{)}, q{-}, q{(}, "$SUP", q{:}, "\\([^.]*\\)", q{)}, q{|}, q{(}, "$VER.0", q{:}, "[^.]*[.]\\([^.]*\\)", q{)}, q{-}, q{(}, "$SUP.0", q{:}, "[^.]*[.]\\([^.]*\\)", q{)}, q{|}, q{(}, "$VER.0.0", q{:}, "[^.]*[.][^.]*[.]\\([^.]*\\)", q{)}, q{-}, q{(}, "$SUP.0.0", q{:}, "[^.]*[.][^.]*[.]\\([^.]*\\)", q{)}) >> 8;
    return;
}

sub get_all_labeled_mounts {
    my $FS;
    my @FS;
    my %FS;
    $FS = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
        $output_0 = do { my $cat_chunk = q{}; if ( open my $fh, '<', '/proc/self/mounts' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/proc/self/mounts' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
        if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
        my @sort_lines_0_1 = split /\n/msx, $output_0;
        my @sort_sorted_0_1 = sort @sort_lines_0_1;
        $output_0 = join "\n", @sort_sorted_0_1;
                if ($output_0 ne q{} && !($output_0 =~ m{\n\z}msx)) {
                    $output_0 .= "\n";
                }
        my @uniq_lines_0_2 = split /\n/msx, $output_0;
        @uniq_lines_0_2 = grep { $_ ne q{} } @uniq_lines_0_2; # Filter out empty lines
        my %uniq_seen_0_2;
        my @uniq_result_0_2;
        foreach my $line (@uniq_lines_0_2) {
        if (!$uniq_seen_0_2{$line}++) { push @uniq_result_0_2, $line; }
        }
        $output_0 = join "\n", @uniq_result_0_2;
                if ($output_0 ne q{} && !($output_0 =~ m{\n\z}msx)) {
                    $output_0 .= "\n";
                }
        my @lines = split /\n/msx, $output_0;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\s+/msx, $line;
            push @result, ($fields[1] . "\n");
        }
        $output_0 = join "", @result;

        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        $output_0 =~ s/\n+\z//msx;
        $output_0;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
    my $i;
    for my $i ($FS) {
if ((`useseclabel` >= 0)) {
            if (do {
{
    my $output_1 = q{};
    my $output_printed_1;
    my $pipeline_success_1 = 1;
        my $grep_result_1_0;
    my @grep_lines_1_0 = ();
    my @grep_filenames_1_0 = ();
    if (-e "/proc/self/mounts") {
    open my $fh, '<', "/proc/self/mounts" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
    chomp $line;
    push @grep_lines_1_0, $line;
    push @grep_filenames_1_0, "/proc/self/mounts";
    }
    close $fh
    or croak "Close failed: $OS_ERROR";
    }
    else { print {*STDERR} "grep: /proc/self/mounts: No such file or directory\n"; }
    my @grep_filtered_1_0 = grep { /\ $i\ /msx } @grep_lines_1_0;
    $grep_result_1_0 = join "\n", @grep_filtered_1_0;
    if (!($grep_result_1_0 =~ m{\n\z}msx || $grep_result_1_0 eq q{})) {
    $grep_result_1_0 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_1_0 > 0 ? 0 : 1;
    $output_1 = $grep_result_1_0;
    $output_1 = $grep_result_1_0;

        my $grep_result_1_1;
    my @grep_lines_1_1 = split /\n/msx, $output_1;
    my @grep_filtered_1_1 = grep { !/(tmpfs)|(\ \/sys)|(^devpts)|(^hugetlbfs)|(^mqueue)/msx } @grep_lines_1_1;
    $grep_result_1_1 = join "\n", @grep_filtered_1_1;
    if (!($grep_result_1_1 =~ m{\n\z}msx || $grep_result_1_1 eq q{})) {
    $grep_result_1_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_1_1 > 0 ? 0 : 1;
    $output_1 = $grep_result_1_1;
    $output_1 = $grep_result_1_1;

        my @lines = split /\n/msx, $output_1;
    my @result;
    foreach my $line (@lines) {
    chomp $line;
    if ($line =~ /^\s*$/msx) { next; }
    my @fields = split /\s+/msx, $line;
    push @result, ($fields[3] . "\n");
    }
    $output_1 = join "", @result;

        my $grep_result_1_3;
    my @grep_lines_1_3 = split /\n/msx, $output_1;
    my @grep_filtered_1_3 = grep { /(^|,)seclabel(,|$)/msxi } @grep_lines_1_3;
    my @grep_numbered_1_3;
    for my $i (0..@grep_lines_1_3-1) {
    if (scalar grep { $_ eq $grep_lines_1_3[$i] } @grep_filtered_1_3) {
    push @grep_numbered_1_3, sprintf "%d:%s", $i + 1, $grep_lines_1_3[$i];
    }
    }
    $grep_result_1_3 = join "\n", @grep_numbered_1_3;
    $CHILD_ERROR = scalar @grep_filtered_1_3 > 0 ? 0 : 1;
    $output_1 = q{};
    if ((scalar @grep_filtered_1_3) == 0) {
        $pipeline_success_1 = 0;
    }
    if ($output_1 ne q{} && !defined $output_printed_1) {
        print $output_1;
        if (!($output_1 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
    }
                $CHILD_ERROR == 0
            }) {
                                print $i;
if ( !( ($i) =~ m{\n\z}msx ) ) { print "\n"; }
            }
}
        else {
            if (do {
{
    my $output_2 = q{};
    my $output_printed_2;
    my $pipeline_success_2 = 1;
        my $grep_result_2_0;
    my @grep_lines_2_0 = ();
    my @grep_filenames_2_0 = ();
    if (-e "/proc/self/mounts") {
    open my $fh, '<', "/proc/self/mounts" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
    chomp $line;
    push @grep_lines_2_0, $line;
    push @grep_filenames_2_0, "/proc/self/mounts";
    }
    close $fh
    or croak "Close failed: $OS_ERROR";
    }
    else { print {*STDERR} "grep: /proc/self/mounts: No such file or directory\n"; }
    my @grep_filtered_2_0 = grep { /\ $i\ /msx } @grep_lines_2_0;
    $grep_result_2_0 = join "\n", @grep_filtered_2_0;
    if (!($grep_result_2_0 =~ m{\n\z}msx || $grep_result_2_0 eq q{})) {
    $grep_result_2_0 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_2_0 > 0 ? 0 : 1;
    $output_2 = $grep_result_2_0;
    $output_2 = $grep_result_2_0;

        my $grep_result_2_1;
    my @grep_lines_2_1 = split /\n/msx, $output_2;
    my @grep_filtered_2_1 = grep { !/context=/msx } @grep_lines_2_1;
    $grep_result_2_1 = join "\n", @grep_filtered_2_1;
    if (!($grep_result_2_1 =~ m{\n\z}msx || $grep_result_2_1 eq q{})) {
    $grep_result_2_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_2_1 > 0 ? 0 : 1;
    $output_2 = $grep_result_2_1;
    $output_2 = $grep_result_2_1;

        my $grep_result_2_2;
    my @grep_lines_2_2 = split /\n/msx, $output_2;
    my @grep_filtered_2_2 = grep { /(ext[234]|\ ext4dev\ |\ gfs2\ |\ xfs\ |\ jfs\ |\ btrfs\ )/msxi } @grep_lines_2_2;
    my @grep_numbered_2_2;
    for my $i (0..@grep_lines_2_2-1) {
    if (scalar grep { $_ eq $grep_lines_2_2[$i] } @grep_filtered_2_2) {
    push @grep_numbered_2_2, sprintf "%d:%s", $i + 1, $grep_lines_2_2[$i];
    }
    }
    $grep_result_2_2 = join "\n", @grep_numbered_2_2;
    $CHILD_ERROR = scalar @grep_filtered_2_2 > 0 ? 0 : 1;
    $output_2 = q{};
    if ((scalar @grep_filtered_2_2) == 0) {
        $pipeline_success_2 = 0;
    }
    if ($output_2 ne q{} && !defined $output_printed_2) {
        print $output_2;
        if (!($output_2 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
    }
                $CHILD_ERROR == 0
            }) {
                                print $i;
if ( !( ($i) =~ m{\n\z}msx ) ) { print "\n"; }
            }
        }
    }
    return;
}

sub get_rw_labeled_mounts {
    my $FS;
    my @FS;
    my %FS;
    $FS = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_3 = q{};
        my $output_printed_3;
        my $pipeline_success_3 = 1;

        my ($in_4, $out_4);
        my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'get_all_labeled_mounts', );
        close $in_4 or croak 'Close failed: $OS_ERROR';
        $output_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
        close $out_4 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_4, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_3 = 0; }
        my @sort_lines_3_1 = split /\n/msx, $output_3;
        my @sort_sorted_3_1 = sort @sort_lines_3_1;
        $output_3 = join "\n", @sort_sorted_3_1;
                if ($output_3 ne q{} && !($output_3 =~ m{\n\z}msx)) {
                    $output_3 .= "\n";
                }
        my @uniq_lines_3_2 = split /\n/msx, $output_3;
        @uniq_lines_3_2 = grep { $_ ne q{} } @uniq_lines_3_2; # Filter out empty lines
        my %uniq_seen_3_2;
        my @uniq_result_3_2;
        foreach my $line (@uniq_lines_3_2) {
        if (!$uniq_seen_3_2{$line}++) { push @uniq_result_3_2, $line; }
        }
        $output_3 = join "\n", @uniq_result_3_2;
                if ($output_3 ne q{} && !($output_3 =~ m{\n\z}msx)) {
                    $output_3 .= "\n";
                }
        if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
        $output_3 =~ s/\n+\z//msx;
        $output_3;
}; $_pipeline_result; };
    my $i;
    for my $i ($FS) {
        if (do {
{
    my $output_5 = q{};
    my $output_printed_5;
    my $pipeline_success_5 = 1;
        my $grep_result_5_0;
    my @grep_lines_5_0 = ();
    my @grep_filenames_5_0 = ();
    if (-e "/proc/self/mounts") {
    open my $fh, '<', "/proc/self/mounts" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
    chomp $line;
    push @grep_lines_5_0, $line;
    push @grep_filenames_5_0, "/proc/self/mounts";
    }
    close $fh
    or croak "Close failed: $OS_ERROR";
    }
    else { print {*STDERR} "grep: /proc/self/mounts: No such file or directory\n"; }
    my @grep_filtered_5_0 = grep { /\ $i\ /msx } @grep_lines_5_0;
    $grep_result_5_0 = join "\n", @grep_filtered_5_0;
    if (!($grep_result_5_0 =~ m{\n\z}msx || $grep_result_5_0 eq q{})) {
    $grep_result_5_0 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_5_0 > 0 ? 0 : 1;
    $output_5 = $grep_result_5_0;
    $output_5 = $grep_result_5_0;

        my @lines = split /\n/msx, $output_5;
    my @result;
    foreach my $line (@lines) {
    chomp $line;
    if ($line =~ /^\s*$/msx) { next; }
    my @fields = split /\s+/msx, $line;
    push @result, ($fields[3] . "\n");
    }
    $output_5 = join "", @result;

        my $grep_result_5_2;
    my @grep_lines_5_2 = split /\n/msx, $output_5;
    my @grep_filtered_5_2 = grep { /(^|,)rw(,|$)/msxi } @grep_lines_5_2;
    my @grep_numbered_5_2;
    for my $i (0..@grep_lines_5_2-1) {
    if (scalar grep { $_ eq $grep_lines_5_2[$i] } @grep_filtered_5_2) {
    push @grep_numbered_5_2, sprintf "%d:%s", $i + 1, $grep_lines_5_2[$i];
    }
    }
    $grep_result_5_2 = join "\n", @grep_numbered_5_2;
    $CHILD_ERROR = scalar @grep_filtered_5_2 > 0 ? 0 : 1;
    $output_5 = q{};
    if ((scalar @grep_filtered_5_2) == 0) {
        $pipeline_success_5 = 0;
    }
    if ($output_5 ne q{} && !defined $output_printed_5) {
        print $output_5;
        if (!($output_5 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_5 ) { $main_exit_code = 1; }
    }
            $CHILD_ERROR == 0
        }) {
                        print $i;
if ( !( ($i) =~ m{\n\z}msx ) ) { print "\n"; }
        }
    }
    return;
}

sub get_ro_labeled_mounts {
    my $FS;
    my @FS;
    my %FS;
    $FS = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_6 = q{};
        my $output_printed_6;
        my $pipeline_success_6 = 1;

        my ($in_7, $out_7);
        my $pid_7 = open3($in_7, $out_7, '>&STDERR', 'get_all_labeled_mounts', );
        close $in_7 or croak 'Close failed: $OS_ERROR';
        $output_6 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
        close $out_7 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_7, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_6 = 0; }
        my @sort_lines_6_1 = split /\n/msx, $output_6;
        my @sort_sorted_6_1 = sort @sort_lines_6_1;
        $output_6 = join "\n", @sort_sorted_6_1;
                if ($output_6 ne q{} && !($output_6 =~ m{\n\z}msx)) {
                    $output_6 .= "\n";
                }
        my @uniq_lines_6_2 = split /\n/msx, $output_6;
        @uniq_lines_6_2 = grep { $_ ne q{} } @uniq_lines_6_2; # Filter out empty lines
        my %uniq_seen_6_2;
        my @uniq_result_6_2;
        foreach my $line (@uniq_lines_6_2) {
        if (!$uniq_seen_6_2{$line}++) { push @uniq_result_6_2, $line; }
        }
        $output_6 = join "\n", @uniq_result_6_2;
                if ($output_6 ne q{} && !($output_6 =~ m{\n\z}msx)) {
                    $output_6 .= "\n";
                }
        if ( !$pipeline_success_6 ) { $main_exit_code = 1; }
        $output_6 =~ s/\n+\z//msx;
        $output_6;
}; $_pipeline_result; };
    my $i;
    for my $i ($FS) {
        if (do {
{
    my $output_8 = q{};
    my $output_printed_8;
    my $pipeline_success_8 = 1;
        my $grep_result_8_0;
    my @grep_lines_8_0 = ();
    my @grep_filenames_8_0 = ();
    if (-e "/proc/self/mounts") {
    open my $fh, '<', "/proc/self/mounts" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
    chomp $line;
    push @grep_lines_8_0, $line;
    push @grep_filenames_8_0, "/proc/self/mounts";
    }
    close $fh
    or croak "Close failed: $OS_ERROR";
    }
    else { print {*STDERR} "grep: /proc/self/mounts: No such file or directory\n"; }
    my @grep_filtered_8_0 = grep { /\ $i\ /msx } @grep_lines_8_0;
    $grep_result_8_0 = join "\n", @grep_filtered_8_0;
    if (!($grep_result_8_0 =~ m{\n\z}msx || $grep_result_8_0 eq q{})) {
    $grep_result_8_0 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_8_0 > 0 ? 0 : 1;
    $output_8 = $grep_result_8_0;
    $output_8 = $grep_result_8_0;

        my @lines = split /\n/msx, $output_8;
    my @result;
    foreach my $line (@lines) {
    chomp $line;
    if ($line =~ /^\s*$/msx) { next; }
    my @fields = split /\s+/msx, $line;
    push @result, ($fields[3] . "\n");
    }
    $output_8 = join "", @result;

        my $grep_result_8_2;
    my @grep_lines_8_2 = split /\n/msx, $output_8;
    my @grep_filtered_8_2 = grep { /(^|,)ro(,|$)/msxi } @grep_lines_8_2;
    my @grep_numbered_8_2;
    for my $i (0..@grep_lines_8_2-1) {
    if (scalar grep { $_ eq $grep_lines_8_2[$i] } @grep_filtered_8_2) {
    push @grep_numbered_8_2, sprintf "%d:%s", $i + 1, $grep_lines_8_2[$i];
    }
    }
    $grep_result_8_2 = join "\n", @grep_numbered_8_2;
    $CHILD_ERROR = scalar @grep_filtered_8_2 > 0 ? 0 : 1;
    $output_8 = q{};
    if ((scalar @grep_filtered_8_2) == 0) {
        $pipeline_success_8 = 0;
    }
    if ($output_8 ne q{} && !defined $output_printed_8) {
        print $output_8;
        if (!($output_8 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_8 ) { $main_exit_code = 1; }
    }
            $CHILD_ERROR == 0
        }) {
                        print $i;
if ( !( ($i) =~ m{\n\z}msx ) ) { print "\n"; }
        }
    }
    return;
}

sub get_undefined_type {
    my $SELINUXMNT;
    my @SELINUXMNT;
    my %SELINUXMNT;
    $SELINUXMNT = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_9 = q{};
        my $output_printed_9;
        my $pipeline_success_9 = 1;
        my $grep_result_9_0;
        my @grep_lines_9_0 = ();
        my @grep_filenames_9_0 = ();
        if (-e "/proc/self/mountinfo") {
            open my $fh, '<', "/proc/self/mountinfo" or croak "Cannot open file: $ERRNO";
            while (my $line = <$fh>) {
                chomp $line;
                push @grep_lines_9_0, $line;
                push @grep_filenames_9_0, "/proc/self/mountinfo";
            }
            close $fh
                or croak "Close failed: $OS_ERROR";
        }
        else { print {*STDERR} "grep: /proc/self/mountinfo: No such file or directory\n"; }
        my @grep_filtered_9_0 = grep { /selinuxfs/msx } @grep_lines_9_0;
        $grep_result_9_0 = join "\n", @grep_filtered_9_0;
                if (!($grep_result_9_0 =~ m{\n\z}msx || $grep_result_9_0 eq q{})) {
                    $grep_result_9_0 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_9_0 > 0 ? 0 : 1;
        $output_9 = $grep_result_9_0;
        if ($CHILD_ERROR != 0) { $pipeline_success_9 = 0; }
        my $num_lines       = 1;
        my $head_line_count = 0;
        my $result          = q{};
        my $input           = $output_9;
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
        $output_9 = $result;

        my @lines = split /\n/msx, $output_9;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\s+/msx, $line;
            push @result, ($fields[4] . "\n");
        }
        $output_9 = join "", @result;

        if ( !$pipeline_success_9 ) { $main_exit_code = 1; }
        $output_9 =~ s/\n+\z//msx;
        $output_9;
}; $_pipeline_result; };
    # Original bash: cat ${SELINUXMNT}/initial_contexts/unlabeled | secon -t
{
        my $output_10 = q{};
        my $output_printed_10;
        my $pipeline_success_10 = 1;
                $output_10 = (do { my $cat_chunk = q{}; if ( open my $fh, '<', $SELINUXMNT ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $SELINUXMNT . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/initial_contexts/unlabeled' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/initial_contexts/unlabeled' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });

                my $cmd_12 = 'secon';
        my ($in_11, $out_11);
        my $pid_11 = open3($in_11, $out_11, '>&STDERR', $cmd_12, '-t');
        print {$in_11} $output_10;
        close $in_11 or croak 'Close failed: $OS_ERROR';
        $output_10 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_11> };
        close $out_11 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_11, 0;
        if ($output_10 ne q{} && !defined $output_printed_10) {
            print $output_10;
            if (!($output_10 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_10 ) { $main_exit_code = 1; }
        }
    return;
}

sub get_unlabeled_type {
    my $SELINUXMNT;
    my @SELINUXMNT;
    my %SELINUXMNT;
    $SELINUXMNT = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_13 = q{};
        my $output_printed_13;
        my $pipeline_success_13 = 1;
        my $grep_result_13_0;
        my @grep_lines_13_0 = ();
        my @grep_filenames_13_0 = ();
        if (-e "/proc/self/mountinfo") {
            open my $fh, '<', "/proc/self/mountinfo" or croak "Cannot open file: $ERRNO";
            while (my $line = <$fh>) {
                chomp $line;
                push @grep_lines_13_0, $line;
                push @grep_filenames_13_0, "/proc/self/mountinfo";
            }
            close $fh
                or croak "Close failed: $OS_ERROR";
        }
        else { print {*STDERR} "grep: /proc/self/mountinfo: No such file or directory\n"; }
        my @grep_filtered_13_0 = grep { /selinuxfs/msx } @grep_lines_13_0;
        $grep_result_13_0 = join "\n", @grep_filtered_13_0;
                if (!($grep_result_13_0 =~ m{\n\z}msx || $grep_result_13_0 eq q{})) {
                    $grep_result_13_0 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_13_0 > 0 ? 0 : 1;
        $output_13 = $grep_result_13_0;
        if ($CHILD_ERROR != 0) { $pipeline_success_13 = 0; }
        my $num_lines       = 1;
        my $head_line_count = 0;
        my $result          = q{};
        my $input           = $output_13;
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
        $output_13 = $result;

        my @lines = split /\n/msx, $output_13;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\s+/msx, $line;
            push @result, ($fields[4] . "\n");
        }
        $output_13 = join "", @result;

        if ( !$pipeline_success_13 ) { $main_exit_code = 1; }
        $output_13 =~ s/\n+\z//msx;
        $output_13;
}; $_pipeline_result; };
    # Original bash: cat $SELINUXMNT/initial_contexts/file | secon -t
{
        my $output_14 = q{};
        my $output_printed_14;
        my $pipeline_success_14 = 1;
                $output_14 = (do { my $cat_chunk = q{}; if ( open my $fh, '<', $SELINUXMNT ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $SELINUXMNT . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/initial_contexts/file' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/initial_contexts/file' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });

                my $cmd_16 = 'secon';
        my ($in_15, $out_15);
        my $pid_15 = open3($in_15, $out_15, '>&STDERR', $cmd_16, '-t');
        print {$in_15} $output_14;
        close $in_15 or croak 'Close failed: $OS_ERROR';
        $output_14 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_15> };
        close $out_15 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_15, 0;
        if ($output_14 ne q{} && !defined $output_printed_14) {
            print $output_14;
            if (!($output_14 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_14 ) { $main_exit_code = 1; }
        }
    return;
}

sub exclude_dirs_from_relabelling {
    my $exclude_from_relabelling;
    my @exclude_from_relabelling;
    my %exclude_from_relabelling;
    $exclude_from_relabelling = q{};
if ((-e '/etc/selinux/fixfiles_exclude_dirs')) {
open STDIN, '<', '/etc/selinux/fixfiles_exclude_dirs' or croak "Cannot open file: $OS_ERROR\n";
        my $i;
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $i = $_fields[0] // q{};
            if ("${i}" eq q{}) {
                next;                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
            if ("${i}" =~ /^[[:blank:]]*\#/msx) {
                next;                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
            if (!"${i}" =~ /^\/.*/msx) {
                next;                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
            if ((!-d "${i}")) {
                next;                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
            $exclude_from_relabelling = "$exclude_from_relabelling -e $i";
        }
    }
    print $exclude_from_relabelling;
if ( !( ($exclude_from_relabelling) =~ m{\n\z}msx ) ) { print "\n"; }
    return;
}
my $fullFlag;
my @fullFlag;
my %fullFlag;
$fullFlag = q{0};
my $BOOTTIME;
my @BOOTTIME;
my %BOOTTIME;
$BOOTTIME = "";
my $VERBOSE;
my @VERBOSE;
my %VERBOSE;
$VERBOSE = "-p";
my $FORCEFLAG;
my @FORCEFLAG;
my %FORCEFLAG;
$FORCEFLAG = "";
my $THREADS;
my @THREADS;
my %THREADS;
$THREADS = "-T0";
my $RPMFILES;
my @RPMFILES;
my %RPMFILES;
$RPMFILES = "";
my $PREFC;
my @PREFC;
my %PREFC;
$PREFC = "";
my $RESTORE_MODE;
my @RESTORE_MODE;
my %RESTORE_MODE;
$RESTORE_MODE = "";
my $BIND_MOUNT_FILESYSTEMS;
my @BIND_MOUNT_FILESYSTEMS;
my %BIND_MOUNT_FILESYSTEMS;
$BIND_MOUNT_FILESYSTEMS = "";
my $SETFILES;
my @SETFILES;
my %SETFILES;
$SETFILES = '/sbin/setfiles';
my $RESTORECON;
my @RESTORECON;
my %RESTORECON;
$RESTORECON = '/sbin/restorecon';
my $FILESYSTEMSRW;
my @FILESYSTEMSRW;
my %FILESYSTEMSRW;
$FILESYSTEMSRW = do {
    my ($in_17, $out_17);
    my $pid_17 = open3($in_17, $out_17, '>&STDERR', 'get_rw_labeled_mounts');
    close $in_17 or croak 'Close failed: $OS_ERROR';
    my $result_17 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_17> };
    close $out_17 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_17, 0;
    $result_17
};
my $FILESYSTEMSRO;
my @FILESYSTEMSRO;
my %FILESYSTEMSRO;
$FILESYSTEMSRO = do {
    my ($in_18, $out_18);
    my $pid_18 = open3($in_18, $out_18, '>&STDERR', 'get_ro_labeled_mounts');
    close $in_18 or croak 'Close failed: $OS_ERROR';
    my $result_18 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_18> };
    close $out_18 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_18, 0;
    $result_18
};
my $SELINUXTYPE;
my @SELINUXTYPE;
my %SELINUXTYPE;
$SELINUXTYPE = "targeted";
if ((-e '/etc/selinux/config')) {
    $main_exit_code = system('.', '/etc/selinux/config') >> 8;
    my $FC;
    my @FC;
    my %FC;
    $FC = '/etc/selinux/';
    $CHILD_ERROR = 0;
}
else {
    $FC = '/etc/security/selinux/file_contexts';
}

sub LogReadOnly {
if (! "$FILESYSTEMSRO" eq q{}) {
        print "Warning: Skipping the following R/O file" . "sys" . "tem" . "s:\n";
        print $FILESYSTEMSRO;
if ( !( ($FILESYSTEMSRO) =~ m{\n\z}msx ) ) { print "\n"; }
    }
    return;
}

sub LogExcluded {
    my $i;
    for my $i ($EXCLUDEDIRS//-e / ) {
        do {
    my $__echo_line = "skipping the directory $i";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
    return;
}

sub newer {
    my $DATE;
    my @DATE;
    my %DATE;
    $DATE = $1;
# Builtin command 'shift' not implemented
    LogReadOnly();
    my $m;
    for my $m (($FILESYSTEMSRW)) {
        # Original bash: find $m -mount -newermt $DATE -print0 2>/dev/null | ${RESTORECON} ${FORCEFLAG} ${VERBOSE} ${THREADS} $* -i -0 -f -
{
            my $output_19 = q{};
            my $output_printed_19;
            my $pipeline_success_19 = 1;
                        $output = q{};
                        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_20 = q{};
$tmp_redirect_20 = do {
    require File::Find;
    my @find_results;
    File::Find::find(sub { if (1) { push @find_results, $File::Find::name; } }, 'wermt');
    my $result = join "\n", @find_results;
    if ($result ne q{}) { $result .= "\n"; }
    $CHILD_ERROR = 0;
    $result;
};
$tmp_redirect_20;
            };
            $output_19 = $output;

                        my $cmd_23 = 'unknown_command';
            my ($in_22, $out_22);
            my $pid_22 = open3($in_22, $out_22, '>&STDERR', $cmd_23, '-i', '-0', '-f', q{-});
            print {$in_22} $output_19;
            close $in_22 or croak 'Close failed: $OS_ERROR';
            $output_19 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_22> };
            close $out_22 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_22, 0;
            if ($output_19 ne q{} && !defined $output_printed_19) {
                print $output_19;
                if (!($output_19 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_19 ) { $main_exit_code = 1; }
            }
    }
    return;
}

sub diff_filecontext {
    my $EXCLUDEDIRS;
    my @EXCLUDEDIRS;
    my %EXCLUDEDIRS;
    $EXCLUDEDIRS = (do { my $_chomp_temp = do {
    my ($in_24, $out_24);
    my $pid_24 = open3($in_24, $out_24, '>&STDERR', 'exclude_dirs_from_relabelling');
    close $in_24 or croak 'Close failed: $OS_ERROR';
    my $result_24 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_24> };
    close $out_24 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_24, 0;
    $result_24
}; chomp $_chomp_temp; $_chomp_temp; });
    my $i;
    for my $i ('/sys', '/proc', '/mnt', '/var/tmp', '/var/lib/BackupPC', '/home', '/root', '/tmp') {
        if ((-e $i)) {
                        $EXCLUDEDIRS = ${EXCLUDEDIRS} . " -e $i";
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
    }
    LogExcluded();
if (((-f ${PREFC}) && (-x '/usr/bin/diff'))) {
        my $TEMPFILE;
        my @TEMPFILE;
        my %TEMPFILE;
        $TEMPFILE = do {
    my ($in_25, $out_25);
    my $pid_25 = open3($in_25, $out_25, '>&STDERR', 'mktemp', $FC, '.XXXXXXXXXX');
    close $in_25 or croak 'Close failed: $OS_ERROR';
    my $result_25 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_25> };
    close $out_25 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_25, 0;
    $result_25
};
        if (do {
$main_exit_code = system('test', '-z', "$TEMPFILE") >> 8;
            $CHILD_ERROR == 0
        }) {
            exit $main_exit_code;
        }
        my $PREFCTEMPFILE;
        my @PREFCTEMPFILE;
        my %PREFCTEMPFILE;
        $PREFCTEMPFILE = do {
    my ($in_26, $out_26);
    my $pid_26 = open3($in_26, $out_26, '>&STDERR', 'mktemp', $PREFC, '.XXXXXXXXXX');
    close $in_26 or croak 'Close failed: $OS_ERROR';
    my $result_26 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_26> };
    close $out_26 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_26, 0;
    $result_26
};
        # Original bash: sed -r -e 's,:s0, ,g' $PREFC | sort -u > ${PREFCTEMPFILE}
{
            my $output_27 = q{};
            my $output_printed_27;
            my $pipeline_success_27 = 1;
                        my @sed_lines_27 = split /\n/msx, $;
            my @sed_result_27;
            foreach my $line (@sed_lines_27) {
            chomp $line;
            push @sed_result_27, $line;
            }
            $ = join "\n", @sed_result_27;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', $PREFCTEMPFILE
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_28 = q{};
            my @sort_lines_29 = split /\n/msx, $output_27;
            my @sort_sorted_29 = sort @sort_lines_29;
            $tmp_redirect_28 = join "\n", @sort_sorted_29;
            if ($tmp_redirect_28 ne q{} && !($tmp_redirect_28 =~ m{\n\z}msx)) {
            $tmp_redirect_28 .= "\n";
            }
            $output_27 = $tmp_redirect_28;
            $tmp_redirect_28;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_27; }
            $output_printed_27 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_27 ) { $main_exit_code = 1; }
            }
        # Original bash: sed -r -e 's,:s0, ,g' $FC | sort -u | \
{
            my $output_30 = q{};
            my $output_printed_30;
            my $pipeline_success_30 = 1;
                        my @sed_lines_30 = split /\n/msx, $;
            my @sed_result_30;
            foreach my $line (@sed_lines_30) {
            chomp $line;
            push @sed_result_30, $line;
            }
            $ = join "\n", @sed_result_30;

                        my @sort_lines_30_1 = split /\n/msx, $output_30;
            my @sort_sorted_30_1 = sort @sort_lines_30_1;
            my $output_30_1 = join "\n", @sort_sorted_30_1;
            if ($output_30_1 ne q{} && !($output_30_1 =~ m{\n\z}msx)) {
            $output_30_1 .= "\n";
            }
            $output_30 = $output_30_1;
            $output_30 = $output_30_1;

                        my $cmd_32 = '/usr/bin/diff';
            my ($in_31, $out_31);
            my $pid_31 = open3($in_31, $out_31, '>&STDERR', $cmd_32, '-b', q{-});
            print {$in_31} $output_30;
            close $in_31 or croak 'Close failed: $OS_ERROR';
            $output_30 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_31> };
            close $out_31 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_31, 0;

                        my $grep_result_30_3;
            my @grep_lines_30_3 = split /\n/msx, $output_30;
            my @grep_filtered_30_3 = grep { /^[<>]/msx } @grep_lines_30_3;
            $grep_result_30_3 = join "\n", @grep_filtered_30_3;
            if (!($grep_result_30_3 =~ m{\n\z}msx || $grep_result_30_3 eq q{})) {
            $grep_result_30_3 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_30_3 > 0 ? 0 : 1;
            $output_30 = $grep_result_30_3;
            $output_30 = $grep_result_30_3;

                        my @lines_33 = split /\n/msx, $output_30;
            my @result_33;
            foreach my $line (@lines_33) {
            chomp $line;
            my @fields = split /\t/msx, $line;
            if (@fields > 0) {
            push @result_33, $fields[0];
            }
            }
            $output_30 = join "\n", @result_33;
            if ($output_30 ne q{} && !($output_30  =~ m{\n\z}msx)) { $output_30 .= "\n"; }

                        my $grep_result_30_5;
            my @grep_lines_30_5 = split /\n/msx, $output_30;
            my @grep_filtered_30_5 = grep { /^\//msx } @grep_lines_30_5;
            $grep_result_30_5 = join "\n", @grep_filtered_30_5;
            if (!($grep_result_30_5 =~ m{\n\z}msx || $grep_result_30_5 eq q{})) {
            $grep_result_30_5 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_30_5 > 0 ? 0 : 1;
            $output_30 = $grep_result_30_5;
            $output_30 = $grep_result_30_5;

                        my $grep_result_30_6;
            my @grep_lines_30_6 = split /\n/msx, $output_30;
            my @grep_filtered_30_6 = grep { !/(^\/home|^\/root|^\/tmp)/msx } @grep_lines_30_6;
            $grep_result_30_6 = join "\n", @grep_filtered_30_6;
            if (!($grep_result_30_6 =~ m{\n\z}msx || $grep_result_30_6 eq q{})) {
            $grep_result_30_6 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_30_6 > 0 ? 0 : 1;
            $output_30 = $grep_result_30_6;
            $output_30 = $grep_result_30_6;

                        my @sed_lines_30 = split /\n/msx, $output_30;
            my @sed_result_30;
            foreach my $line (@sed_lines_30) {
            chomp $line;
            push @sed_result_30, $line;
            }
            $output_30 = join "\n", @sed_result_30;

                        my @sort_lines_30_8 = split /\n/msx, $output_30;
            my @sort_sorted_30_8 = sort @sort_lines_30_8;
            my $output_30_8 = join "\n", @sort_sorted_30_8;
            if ($output_30_8 ne q{} && !($output_30_8 =~ m{\n\z}msx)) {
            $output_30_8 .= "\n";
            }
            $output_30 = $output_30_8;
            $output_30 = $output_30_8;

                        my @sort_lines_30_9 = split /\n/msx, $output_30;
            my @sort_sorted_30_9 = sort @sort_lines_30_9;
            my $output_30_9 = join "\n", @sort_sorted_30_9;
            if ($output_30_9 ne q{} && !($output_30_9 =~ m{\n\z}msx)) {
            $output_30_9 .= "\n";
            }
            $output_30 = $output_30_9;
            $output_30 = $output_30_9;

                        my @lines = split /\n/msx, $output_30;
            my $result_30_10 = q{};
            for my $line (@lines) {
            chomp $line;
            my $L = $line;
            if (!(!(# Original bash: echo "$pattern" | grep -q -f ${TEMPFILE} 2>/dev/null;
            {
            my $pipeline_success_30 = 1;
            $output_30 .= $pattern . "\n";
            if ( !($output_30 =~ m{\n\z}msx) ) { $output_30 .= "\n"; }
            $CHILD_ERROR = 0;
            carp "grep: no pattern specified";
            exit 1;
            $output_30 = q{};
            if ($output_30 ne q{} && !defined $output_printed_30) {
            print $output_30;
            if (!($output_30 =~ m{\n\z}msx)) {
            print "\n";
            }
            }
            if ( !$pipeline_success_30 ) { $main_exit_code = 1; }
            }))) {
            print $pattern;
            if ( !( ($pattern) =~ m{\n\z}msx ) ) { print "\n"; }
            if ("$ENV{pattern}" =~ /^.*".*$/msx) {
            # Original bash: echo "$pattern" | sed -e 's,^,^,' -e 's,\*$,,g' >> ${TEMPFILE};;
            {
            my $pipeline_success_30 = 1;
            $output_30 .= $pattern . "\n";
            if ( !($output_30 =~ m{\n\z}msx) ) { $output_30 .= "\n"; }
            $CHILD_ERROR = 0;
            do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $TEMPFILE
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_34 = q{};
            my @sed_lines_35 = split /\n/msx, $output_30;
            my @sed_result_35;
            foreach my $line (@sed_lines_35) {
            chomp $line;
            push @sed_result_35, $line;
            }
            $output_30 = join "\n", @sed_result_35;
            $tmp_redirect_34;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_30; }
            $output_printed_30 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_30 ) { $main_exit_code = 1; }
            }
            }
            }
            }
            $output_30 = $result_30_10;

                        my $cmd_37 = 'unknown_command';
            my ($in_36, $out_36);
            my $pid_36 = open3($in_36, $out_36, '>&STDERR', $cmd_37, '-i', '-R', '-f', q{-});
            print {$in_36} $output_30;
            close $in_36 or croak 'Close failed: $OS_ERROR';
            $output_30 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_36> };
            close $out_36 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_36, 0;
            if ($output_30 ne q{} && !defined $output_printed_30) {
                print $output_30;
                if (!($output_30 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_30 ) { $main_exit_code = 1; }
            }
if ( -e "$TEMPFILE" ) {
            if ( -d "$TEMPFILE" ) {
                carp "rm: carping: ", $TEMPFILE,
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$TEMPFILE" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", $TEMPFILE,
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
if ( -e "$PREFCTEMPFILE" ) {
            if ( -d "$PREFCTEMPFILE" ) {
                carp "rm: carping: ", $PREFCTEMPFILE,
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$PREFCTEMPFILE" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", $PREFCTEMPFILE,
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
    return;
}

sub rpmlist {
    my ($file) = @_;
    # Original bash: rpm -q --qf '[%{FILESTATES} %{FILENAMES}\n]' "$1" | grep '^0 ' | cut -f2- -d ' '
{
        my $output_38 = q{};
        my $output_printed_38;
        my $pipeline_success_38 = 1;
                my ($in_39, $out_39);
        my $pid_39 = open3($in_39, $out_39, '>&STDERR', 'rpm', '-q', '--qf', "[%{FILESTATES} %{FILENAMES}\\n]");
        close $in_39 or croak 'Close failed: $OS_ERROR';
        $output_38 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_39> };
        close $out_39 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_39, 0;

                my $grep_result_38_1;
        my @grep_lines_38_1 = split /\n/msx, $output_38;
        my @grep_filtered_38_1 = grep { /^0\ /msx } @grep_lines_38_1;
        $grep_result_38_1 = join "\n", @grep_filtered_38_1;
        if (!($grep_result_38_1 =~ m{\n\z}msx || $grep_result_38_1 eq q{})) {
        $grep_result_38_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_38_1 > 0 ? 0 : 1;
        $output_38 = $grep_result_38_1;
        $output_38 = $grep_result_38_1;

                my @lines_40 = split /\n/msx, $output_38;
        my @result_40;
        foreach my $line (@lines_40) {
        chomp $line;
        my @fields = split /\ /msx, $line;
        if (@fields > 1) { push @result_40, join(q{ }, @fields[1..@fields-1]); }
        }
        $output_38 = join "\n", @result_40;
        if ($output_38 ne q{} && !($output_38  =~ m{\n\z}msx)) { $output_38 .= "\n"; }
        if ($output_38 ne q{} && !defined $output_printed_38) {
            print $output_38;
            if (!($output_38 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_38 ) { $main_exit_code = 1; }
        }
    if (${PIPESTATUS[0]} ne 0) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/stderr'
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "$_[0] not found";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    return;
}

sub umount_TMP_MOUNT {
if ("$TMP_MOUNT" ne q{}) {
                $main_exit_code = system('umount', ($ENV{TMP_MOUNT} // q{}) . ($ENV{m} // q{})) >> 8;
        if ($CHILD_ERROR != 0) {
            exit 130;
        }
        if ( -e "($ENV{TMP_MOUNT} // q{})" ) {
            if ( -d "($ENV{TMP_MOUNT} // q{})" ) {
                my $err;
                require File::Path;
                File::Path::remove_tree("($ENV{TMP_MOUNT} // q{})", {error => \$err});
                if (@{$err}) {
                    carp "rm: carping: could not remove ", ($ENV{TMP_MOUNT} // q{}), ": $err->[0]\n";
                }
                else {
                                    }
            }
            else {
                if ( unlink "($ENV{TMP_MOUNT} // q{})" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", ($ENV{TMP_MOUNT} // q{}),
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
        if ($CHILD_ERROR != 0) {
                        print "Error cleaning up.\n";
        }
    }
exit 130;
    return;
}

sub fix_labels_on_mountpoint {
    if (do {
if (do {
$main_exit_code = system('test', '-z', $TMP_MOUNT+x) >> 8;
    $CHILD_ERROR == 0
}) {
        print "Unable to find temporary directory!\n";
}
        $CHILD_ERROR == 0
    }) {
        exit 1;
    }
        use File::Path qw(make_path);
    my $err;
    if ( !-d ($ENV{TMP_MOUNT} // q{}) . ($ENV{m} // q{}) ) {
        make_path( ($ENV{TMP_MOUNT} // q{}) . ($ENV{m} // q{}), { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . ($ENV{TMP_MOUNT} // q{}) . ($ENV{m} // q{}) . ": $err->[0]\n";
        }
    }
    if ($CHILD_ERROR != 0) {
        exit 1;
    }
        $main_exit_code = system('mount', '--bind', ($ENV{m} // q{}), ($ENV{TMP_MOUNT} // q{}) . ($ENV{m} // q{})) >> 8;
    if ($CHILD_ERROR != 0) {
        exit 1;
    }
    $CHILD_ERROR = 0;
        $main_exit_code = system('umount', ($ENV{TMP_MOUNT} // q{}) . ($ENV{m} // q{})) >> 8;
    if ($CHILD_ERROR != 0) {
        exit 1;
    }
    if ( -e "($ENV{TMP_MOUNT} // q{})" ) {
        if ( -d "($ENV{TMP_MOUNT} // q{})" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("($ENV{TMP_MOUNT} // q{})", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", ($ENV{TMP_MOUNT} // q{}), ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "($ENV{TMP_MOUNT} // q{})" ) {
                            }
            else {
                carp "rm: carping: could not remove ", ($ENV{TMP_MOUNT} // q{}),
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    if ($CHILD_ERROR != 0) {
                print "Error cleaning up.\n";
    }
    return;
}
$ENV{-f} = $-f;
$ENV{fix_labels_on_mountpoint} = $fix_labels_on_mountpoint;

sub restore {
    my $OPTION;
    my @OPTION;
    my %OPTION;
    $OPTION = $1;
# Builtin command 'shift' not implemented
if ("$BOOTTIME" ne q{}) {
        newer($BOOTTIME, $*);
return;
    }
if ("$RESTORE_MODE" =~ /^PREFC$/msx) {
        diff_filecontext($*);
return;
    }
    if ((-x '/usr/sbin/genhomedircon')) {
                $main_exit_code = system('bash', '/usr/sbin/genhomedircon') >> 8;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    my $EXCLUDEDIRS;
    my @EXCLUDEDIRS;
    my %EXCLUDEDIRS;
    $EXCLUDEDIRS = (do { my $_chomp_temp = do {
    my ($in_42, $out_42);
    my $pid_42 = open3($in_42, $out_42, '>&STDERR', 'exclude_dirs_from_relabelling');
    close $in_42 or croak 'Close failed: $OS_ERROR';
    my $result_42 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_42> };
    close $out_42 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_42, 0;
    $result_42
}; chomp $_chomp_temp; $_chomp_temp; });
    LogExcluded();
if ("$RESTORE_MODE" =~ /^RPMFILES$/msx) {
                my $i;
        for my $i (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_43 = q{};
            my $output_printed_43;
            my $pipeline_success_43 = 1;
            $output_43 .= $RPMFILES . "\n";
            if ( !($output_43 =~ m{\n\z}msx) ) { $output_43 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_43 = 0; }
            my @sed_lines_43 = split /\n/msx, $output_43;
            my @sed_result_43;
            foreach my $line (@sed_lines_43) {
            chomp $line;
            $line =~ s/,/ /gmsx;
            push @sed_result_43, $line;
            }
            $output_43 = join "\n", @sed_result_43;

            if ( !$pipeline_success_43 ) { $main_exit_code = 1; }
            $output_43 =~ s/\n+\z//msx;
            $output_43;
}; $_pipeline_result; }) {
            # Original bash: rpmlist $i | ${RESTORECON} ${VERBOSE} ${EXCLUDEDIRS} ${FORCEFLAG} ${THREADS} $* -i -R -f -
{
                my $output_44 = q{};
                my $output_printed_44;
                my $pipeline_success_44 = 1;
                                my ($in_45, $out_45);
                my $pid_45 = open3($in_45, $out_45, '>&STDERR', 'rpmlist', );
                close $in_45 or croak 'Close failed: $OS_ERROR';
                $output_44 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_45> };
                close $out_45 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_45, 0;

                                my $cmd_47 = 'unknown_command';
                my ($in_46, $out_46);
                my $pid_46 = open3($in_46, $out_46, '>&STDERR', $cmd_47, '-i', '-R', '-f', q{-});
                print {$in_46} $output_44;
                close $in_46 or croak 'Close failed: $OS_ERROR';
                $output_44 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_46> };
                close $out_46 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_46, 0;
                if ($output_44 ne q{} && !defined $output_printed_44) {
                    print $output_44;
                    if (!($output_44 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_44 ) { $main_exit_code = 1; }
                }
        }
    } elsif ("$RESTORE_MODE" =~ /^FILEPATH$/msx) {
                $CHILD_ERROR = 0;
    } elsif (1) {
        if ("${FILESYSTEMSRW}" ne q{}) {
            LogReadOnly();
            print ${OPTION} . "ing " . (do { my $_chomp_temp = ($FILESYSTEMSRW); chomp $_chomp_temp; $_chomp_temp; });
if ( !( (${OPTION} . "ing " . (do { my $_chomp_temp = ($FILESYSTEMSRW); chomp $_chomp_temp; $_chomp_temp; })) =~ m{\n\z}msx ) ) { print "\n"; }
if ("$BIND_MOUNT_FILESYSTEMS" eq q{}) {
                $CHILD_ERROR = 0;
}
            else {
                my $m;
                for my $m (($FILESYSTEMSRW)) {
                    my $TMP_MOUNT;
                    my @TMP_MOUNT;
                    my %TMP_MOUNT;
                    $TMP_MOUNT = (do { my $_chomp_temp = do {
    my ($in_48, $out_48);
    my $pid_48 = open3($in_48, $out_48, '>&STDERR', 'mktemp', '-p', '/run', '-d', 'fixfiles.XXXXXXXXXX');
    close $in_48 or croak 'Close failed: $OS_ERROR';
    my $result_48 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_48> };
    close $out_48 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_48, 0;
    $result_48
}; chomp $_chomp_temp; $_chomp_temp; });
$ENV{SETFILES} = $SETFILES;
$ENV{VERBOSE} = $VERBOSE;
$ENV{EXCLUDEDIRS} = $EXCLUDEDIRS;
$ENV{FORCEFLAG} = $FORCEFLAG;
$ENV{THREADS} = $THREADS;
$ENV{FC} = $FC;
$ENV{TMP_MOUNT} = $TMP_MOUNT;
$ENV{m} = $m;
if (!(                    do {
                        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
                        my $tmp = do {
                        $main_exit_code = system('type', 'unshare') >> 8;
                        };
                        print $tmp;
                        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                    })) {
                                                $main_exit_code = system('unshare', '-m', 'bash', '-c', "fix_labels_on_mountpoint @ARGV") >> 8;
                        if ($CHILD_ERROR != 0) {
                                                    }
}
                    else {
END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx'umount_TMP_MOUNT 2>&1'; print $end_out if $end_out ne q{}; }
                        fix_labels_on_mountpoint($*);
# Builtin command 'trap' with insufficient arguments
                    }
                }
            }
}
        else {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                print "\n";
                $CHILD_ERROR = 0;
            };
            $main_exit_code = system('bash', 'fixfiles: No suitable file systems found') >> 8;
        }
        if (${OPTION} ne "Relabel") {
return;
        }
                print "Cleaning up labels on /tmp\n";
        my @files_to_remove = glob("/tmp/gconfd-*");
foreach my $file_to_remove (@files_to_remove) {
            if ( -e $file_to_remove ) {
                if ( -d $file_to_remove ) {
                    my $err;
                    require File::Path;
                    File::Path::remove_tree($file_to_remove, {error => \$err});
                    if (@{$err}) {
                        carp "rm: carping: could not remove ", $file_to_remove, ": $err->[0]\n";
                    }
                    else {
                    }
                }
                else {
                if ( unlink $file_to_remove ) {
                local $CHILD_ERROR = 0;
                }
                else {
                    local $CHILD_ERROR = 1;
                    carp "rm: carping: could not remove ", $file_to_remove,
    ": $OS_ERROR\n";
                }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
        }
my @files_to_remove = glob("/tmp/pulse-*");
foreach my $file_to_remove (@files_to_remove) {
            if ( -e $file_to_remove ) {
                if ( -d $file_to_remove ) {
                    my $err;
                    require File::Path;
                    File::Path::remove_tree($file_to_remove, {error => \$err});
                    if (@{$err}) {
                        carp "rm: carping: could not remove ", $file_to_remove, ": $err->[0]\n";
                    }
                    else {
                    }
                }
                else {
                if ( unlink $file_to_remove ) {
                local $CHILD_ERROR = 0;
                }
                else {
                    local $CHILD_ERROR = 1;
                    carp "rm: carping: could not remove ", $file_to_remove,
    ": $OS_ERROR\n";
                }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
        }
my @files_to_remove = glob("/tmp/orbit-*");
foreach my $file_to_remove (@files_to_remove) {
            if ( -e $file_to_remove ) {
                if ( -d $file_to_remove ) {
                    my $err;
                    require File::Path;
                    File::Path::remove_tree($file_to_remove, {error => \$err});
                    if (@{$err}) {
                        carp "rm: carping: could not remove ", $file_to_remove, ": $err->[0]\n";
                    }
                    else {
                    }
                }
                else {
                if ( unlink $file_to_remove ) {
                local $CHILD_ERROR = 0;
                }
                else {
                    local $CHILD_ERROR = 1;
                    carp "rm: carping: could not remove ", $file_to_remove,
    ": $OS_ERROR\n";
                }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
        }
                        my $UNDEFINED;
        my @UNDEFINED;
        my %UNDEFINED;
        $UNDEFINED = do {
    my ($in_49, $out_49);
    my $pid_49 = open3($in_49, $out_49, '>&STDERR', 'get_undefined_type');
    close $in_49 or croak 'Close failed: $OS_ERROR';
    my $result_49 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_49> };
    close $out_49 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_49, 0;
    $result_49
};
        if ($CHILD_ERROR != 0) {
                    }
                        my $UNLABELED;
        my @UNLABELED;
        my %UNLABELED;
        $UNLABELED = do {
    my ($in_50, $out_50);
    my $pid_50 = open3($in_50, $out_50, '>&STDERR', 'get_unlabeled_type');
    close $in_50 or croak 'Close failed: $OS_ERROR';
    my $result_50 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_50> };
    close $out_50 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_50, 0;
    $result_50
};
        if ($CHILD_ERROR != 0) {
                    }
                require File::Find;
        File::Find::find(sub {     next unless -e $_;     print "$File::Find::name\n"; }, '/tmp');
                require File::Find;
        File::Find::find(sub {     print "$File::Find::name\n"; }, '/tmp');
                require File::Find;
        File::Find::find(sub {     print "$File::Find::name\n"; }, '/var/tmp');
                require File::Find;
        File::Find::find(sub {     print "$File::Find::name\n"; }, '/var/run');
                if (!((!-e /var/lib/debug))) {
                        require File::Find;
            File::Find::find(sub {     print "$File::Find::name\n"; }, '/var/lib/debug');
        }
    }
    return;
}

sub fullrelabel {
    print "Cleaning out /tmp\n";
    require File::Find;
    File::Find::find(sub {     print "$File::Find::name\n"; }, '/tmp/');
    restore('Relabel');
    return;
}

sub relabel {
if (("$RESTORE_MODE" ne q{} && "$RESTORE_MODE" ne DEFAULT)) {
        $main_exit_code = system('bash', 'usage') >> 8;
exit 1;
    }
if ($fullFlag =~ /^1$/msx) {
        fullrelabel();
return;
    }
    print "
    Files in the /tmp directory may be labeled incorrectly, this command
    can remove all files in /tmp.  If you choose to remove files from /tmp,
    a reboot will be required after completion.

    Do you wish to clean out the /tmp directory [N]? ";
$answer = <>;
chomp $answer;
$CHILD_ERROR = defined($answer) ? 0 : 1;
if (("$answer" eq y || "$answer" eq Y)) {
        fullrelabel();
}
    else {
        restore('Relabel');
    }
    return;
}

sub process {
if ("$_[0]" =~ /^restore$/msx) {
                restore('Relabel');
    } elsif ("$_[0]" =~ /^check$/msx) {
                $VERBOSE = "-v";
                restore('Check', '-n');
    } elsif ("$_[0]" =~ /^verify$/msx) {
                $VERBOSE = "-v";
                restore('Verify', '-n');
    } elsif ("$_[0]" =~ /^relabel$/msx) {
                relabel();
    } elsif ("$_[0]" =~ /^onboot$/msx) {
                        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/.autorelabel'
      or die "Cannot open file: $OS_ERROR\n";
if (("$RESTORE_MODE" ne q{} && "$RESTORE_MODE" ne DEFAULT)) {
                $main_exit_code = system('bash', 'usage') >> 8;
exit 1;
            }
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        if ($CHILD_ERROR != 0) {
                    }
                if (!("$FORCEFLAG" eq q{})) {
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', '/.autorelabel'
      or die "Cannot open file: $OS_ERROR\n";
                print "$FORCEFLAG ";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
                if (!("$BOOTTIME" eq q{})) {
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', '/.autorelabel'
      or die "Cannot open file: $OS_ERROR\n";
                print "-N $BOOTTIME ";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
                if (!("$BIND_MOUNT_FILESYSTEMS" eq q{})) {
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', '/.autorelabel'
      or die "Cannot open file: $OS_ERROR\n";
                print "-M ";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
                if (!("$THREADS" eq q{})) {
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', '/.autorelabel'
      or die "Cannot open file: $OS_ERROR\n";
                print "$THREADS ";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
                        $main_exit_code = system('bash', 'selinuxenabled') >> 8;
        if ($CHILD_ERROR != 0) {
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/.autorelabel'
      or die "Cannot open file: $OS_ERROR\n";
                print '-F' . "\n";
                $CHILD_ERROR = 0;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
                print "System will relabel on next boot\n";
    } elsif (1) {
                $main_exit_code = system('bash', 'usage') >> 8;
        exit 1;
    }
    return;
}

sub usage {
    my ($file) = @_;
    do {
    my $__echo_line = "$\"\"" . q{ } . "
Usage: $PROGRAM_NAME [-v] [-F] [-M] [-f] [-T nthreads] relabel
or
Usage: $PROGRAM_NAME [-v] [-F] [-B | -N time ] [-T nthreads] { check | restore | verify }
or
Usage: $PROGRAM_NAME [-v] [-F] [-T nthreads] { check | restore | verify } dir/file ...
or
Usage: $PROGRAM_NAME [-v] [-F] [-T nthreads] -R rpmpackage[,rpmpackage...] { check | restore | verify }
or
Usage: $PROGRAM_NAME [-v] [-F] [-T nthreads] -C PREVIOUS_FILECONTEXT { check | restore | verify }
or
Usage: $PROGRAM_NAME [-F] [-M] [-B] [-T nthreads] onboot
" . q{ } . "";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    return;
}
if ((scalar(@ARGV) == 0)) {
    usage();
exit 1;
}

sub set_restore_mode {
if ("$RESTORE_MODE" ne q{}) {
        usage();
exit 1;
    }
    $RESTORE_MODE = "$_[0]";
    return;
}
while ( $main_exit_code = system('getopts', "N:BC:FfR:l:vMT:", q{i}) >> 8 ) {
if ("$ENV{i}" =~ /^B$/msx) {
                $BOOTTIME = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_52 = q{};
            my $output_printed_52;
            my $pipeline_success_52 = 1;

            my ($in_53, $out_53);
            my $pid_53 = open3($in_53, $out_53, '>&STDERR', '/bin/who', '-b');
            close $in_53 or croak 'Close failed: $OS_ERROR';
            $output_52 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_53> };
            close $out_53 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_53, 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_52 = 0; }
            my @lines = split /\n/msx, $output_52;
            my @result;
            foreach my $line (@lines) {
                chomp $line;
                if ($line =~ /^\s*$/msx) { next; }
                my @fields = split /\s+/msx, $line;
                push @result, ($fields[2] . "\n");
            }
            $output_52 = join "", @result;

            if ( !$pipeline_success_52 ) { $main_exit_code = 1; }
            $output_52 =~ s/\n+\z//msx;
            $output_52;
}; $_pipeline_result; };
                set_restore_mode('DEFAULT');
    } elsif ("$ENV{i}" =~ /^N$/msx) {
                $BOOTTIME = $OPTARG;
                set_restore_mode('BOOTTIME');
    } elsif ("$ENV{i}" =~ /^R$/msx) {
                $RPMFILES = $OPTARG;
                set_restore_mode('RPMFILES');
    } elsif ("$ENV{i}" =~ /^C$/msx) {
                $PREFC = $OPTARG;
                set_restore_mode('PREFC');
    } elsif ("$ENV{i}" =~ /^v$/msx) {
                $VERBOSE = "-v";
    } elsif ("$ENV{i}" =~ /^l$/msx) {
                do {
    my $__echo_line = "Redirecting output to $ENV{OPTARG}";
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
            open STDOUT, '>>', "$ENV{OPTARG}"
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
# Builtin command 'exec' not implemented
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    } elsif ("$ENV{i}" =~ /^M$/msx) {
                $BIND_MOUNT_FILESYSTEMS = "-M";
    } elsif ("$ENV{i}" =~ /^F$/msx) {
                $FORCEFLAG = "-F";
    } elsif ("$ENV{i}" =~ /^f$/msx) {
                $fullFlag = q{1};
    } elsif ("$ENV{i}" =~ /^T$/msx) {
                $THREADS = "-T $ENV{OPTARG}";
    } elsif (1) {
                usage();
        exit 1;
    }
}
# Builtin command 'shift' not implemented
if ((scalar(@ARGV) == 0)) {
    usage();
exit 1;
}
my $command;
my @command;
my %command;
$command = "$_[0]";
# Builtin command 'shift' not implemented
if ((scalar(@ARGV) > 0)) {
    set_restore_mode('FILEPATH');
while ( scalar(@ARGV) > 0 ) {
        my $FILEPATH;
        my @FILEPATH;
        my %FILEPATH;
        $FILEPATH = "$_[0]";
                process("$command");
        if ($CHILD_ERROR != 0) {
                    }
# Builtin command 'shift' not implemented
    }
}
else {
    process("$command");
}

exit $main_exit_code;
