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

my $USAGE;
my @USAGE;
my %USAGE;
$USAGE = "[-a] [-r] [-m] [-t] [-n] [-b <newname>] <name>";
my $LONG_USAGE;
my @LONG_USAGE;
my %LONG_USAGE;
$LONG_USAGE = "git-resurrect attempts to find traces of a branch tip
called <name>, and tries to resurrect it.  Currently, the reflog is
searched for checkout messages, and with -r also merge messages.  With
-m and -t, the history of all refs is scanned for Merge <name> into
other/Merge <other> into <name> (respectively) commit subjects, which
is rather slow but allows you to resurrect other people's topic
branches.";
my $OPTIONS_KEEPDASHDASH;
my @OPTIONS_KEEPDASHDASH;
my %OPTIONS_KEEPDASHDASH;
$OPTIONS_KEEPDASHDASH = q{};
my $OPTIONS_STUCKLONG;
my @OPTIONS_STUCKLONG;
my %OPTIONS_STUCKLONG;
$OPTIONS_STUCKLONG = q{};
my $OPTIONS_SPEC;
my @OPTIONS_SPEC;
my %OPTIONS_SPEC;
$OPTIONS_SPEC = "\
git resurrect $USAGE
--
b,branch=            save branch as <newname> instead of <name>
a,all                same as -l -r -m -t
k,keep-going         full rev-list scan (instead of first match)
l,reflog             scan reflog for checkouts (enabled by default)
r,reflog-merges      scan for merges recorded in reflog
m,merges             scan for merges into other branches (slow)
t,merge-targets      scan for merges of other branches into <name>
n,dry-run            don't recreate the branch";
$main_exit_code = system('.', 'git-sh-setup') >> 8;

sub search_reflog {
open STDIN, '<', "$ENV{GIT_DIR}" or croak "Cannot open file: $OS_ERROR\n";
my @sed_lines_0 = split /\n/msx, $;
my @sed_result_0;
foreach my $line (@sed_lines_0) {
chomp $line;
push @sed_result_0, $line;
}
$ = join "\n", @sed_result_0;

    $main_exit_code = system('bash', '/logs/HEAD') >> 8;
    return;
}

sub search_reflog_merges {
    $main_exit_code = system('git', 'rev-parse',  my ($in_1, $out_1); my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'bash', '-c', 'sed -ne "s~^[^ ]* \\\\([^ ]*\\\\) .*	merge " "$1" ":.*~\\\\1^2~p" < "$GIT_DIR"'); close $in_1 or croak 'Close failed: $OS_ERROR'; my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> }; close $out_1 or croak 'Close failed: $OS_ERROR'; waitpid $pid_1, 0; $result_1) >> 8;
    return;
}
my $oid_pattern;
my @oid_pattern;
my %oid_pattern;
$oid_pattern = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_2 = q{};
    my $output_printed_2;
    my $pipeline_success_2 = 1;
    open STDIN, '<', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
    $main_exit_code = system('git', 'hash-object', '--stdin') >> 8;
    my @sed_lines_2 = split /\n/msx, $output_2;
    my @sed_result_2;
    foreach my $line (@sed_lines_2) {
    chomp $line;
    push @sed_result_2, $line;
    }
    $output_2 = join "\n", @sed_result_2;
    if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
    $output_2 =~ s/\n+\z//msx;
    $output_2;
}; $_pipeline_result; };

sub search_merges {
    my ($file) = @_;
    # Original bash: git rev-list --all --grep="Merge branch '$1'" \
{
        my $output_3 = q{};
        my $output_printed_3;
        my $pipeline_success_3 = 1;
                my ($in_4, $out_4);
        my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'git', 'rev-list', '--all', '--grep=Merge branch \'$1\'', '--pretty=tformat:');
        close $in_4 or croak 'Close failed: $OS_ERROR';
        $output_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
        close $out_4 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_4, 0;

                my @sed_lines_3 = split /\n/msx, $output_3;
        my @sed_result_3;
        foreach my $line (@sed_lines_3) {
        chomp $line;
        push @sed_result_3, $line;
        }
        $output_3 = join "\n", @sed_result_3;
        if ($output_3 ne q{} && !defined $output_printed_3) {
            print $output_3;
            if (!($output_3 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
        }
    return;
}

sub search_merge_targets {
    # Original bash: git rev-list --all --grep="Merge branch '[^']*' into $branch\$" \
{
        my $output_5 = q{};
        my $output_printed_5;
        my $pipeline_success_5 = 1;
                my ($in_6, $out_6);
        my $pid_6 = open3($in_6, $out_6, '>&STDERR', 'git', 'rev-list', '--all', "--grep=Merge branch '[^']*' into $branch\\$", '--pretty=tformat:', '--all');
        close $in_6 or croak 'Close failed: $OS_ERROR';
        $output_5 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> };
        close $out_6 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_6, 0;

                my @sed_lines_5 = split /\n/msx, $output_5;
        my @sed_result_5;
        foreach my $line (@sed_lines_5) {
        chomp $line;
        push @sed_result_5, $line;
        }
        $output_5 = join "\n", @sed_result_5;
        if ($output_5 ne q{} && !defined $output_printed_5) {
            print $output_5;
            if (!($output_5 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_5 ) { $main_exit_code = 1; }
        }
    return;
}
my $dry_run;
my @dry_run;
my %dry_run;
$dry_run = q{};
my $early_exit;
my @early_exit;
my %early_exit;
$early_exit = q{q};
my $scan_reflog;
my @scan_reflog;
my %scan_reflog;
$scan_reflog = q{t};
my $scan_reflog_merges;
my @scan_reflog_merges;
my %scan_reflog_merges;
$scan_reflog_merges = q{};
my $scan_merges;
my @scan_merges;
my %scan_merges;
$scan_merges = q{};
my $scan_merge_targets;
my @scan_merge_targets;
my %scan_merge_targets;
$scan_merge_targets = q{};
my $new_name;
my @new_name;
my %new_name;
$new_name = q{};
while ( (!StringInterpolation(StringInterpolation { parts: [Variable("#")] }, None) eq 0) ) {
if ("$_[0]" =~ /^-b$/msx or "$_[0]" =~ /^--branch$/msx) {
        # Builtin command 'shift' not implemented
                $new_name = "$_[0]";
    } elsif ("$_[0]" =~ /^-n$/msx or "$_[0]" =~ /^--dry-run$/msx) {
                $dry_run = q{t};
    } elsif ("$_[0]" =~ /^--no-dry-run$/msx) {
                $dry_run = q{};
    } elsif ("$_[0]" =~ /^-k$/msx or "$_[0]" =~ /^--keep-going$/msx) {
                $early_exit = q{};
    } elsif ("$_[0]" =~ /^--no-keep-going$/msx) {
                $early_exit = q{q};
    } elsif ("$_[0]" =~ /^-m$/msx or "$_[0]" =~ /^--merges$/msx) {
                $scan_merges = q{t};
    } elsif ("$_[0]" =~ /^--no-merges$/msx) {
                $scan_merges = q{};
    } elsif ("$_[0]" =~ /^-l$/msx or "$_[0]" =~ /^--reflog$/msx) {
                $scan_reflog = q{t};
    } elsif ("$_[0]" =~ /^--no-reflog$/msx) {
                $scan_reflog = q{};
    } elsif ("$_[0]" =~ /^-r$/msx or "$_[0]" =~ /^--reflog_merges$/msx) {
                $scan_reflog_merges = q{t};
    } elsif ("$_[0]" =~ /^--no-reflog_merges$/msx) {
                $scan_reflog_merges = q{};
    } elsif ("$_[0]" =~ /^-t$/msx or "$_[0]" =~ /^--merge-targets$/msx) {
                $scan_merge_targets = q{t};
    } elsif ("$_[0]" =~ /^--no-merge-targets$/msx) {
                $scan_merge_targets = q{};
    } elsif ("$_[0]" =~ /^-a$/msx or "$_[0]" =~ /^--all$/msx) {
                $scan_reflog = q{t};
                $scan_reflog_merges = q{t};
                $scan_merges = q{t};
                $scan_merge_targets = q{t};
    } elsif ("$_[0]" =~ /^--$/msx) {
        # Builtin command 'shift' not implemented
        last;    } elsif (1) {
                $main_exit_code = system('bash', 'usage') >> 8;
    }
# Builtin command 'shift' not implemented
}
$main_exit_code = system('test', "${scalar(@ARGV)}", q{=}, q{1}) >> 8;
if ($CHILD_ERROR != 0) {
        $main_exit_code = system('bash', 'usage') >> 8;
}
my $all_strategies;
my @all_strategies;
my %all_strategies;
$all_strategies = "$scan_reflog$scan_reflog_merges$scan_merges$scan_merge_targets";
if (StringInterpolation(StringInterpolation { parts: [Variable("all_strategies")] }, None) eq q{}) {
    $main_exit_code = system('die', "must enable at least one of -lrmt") >> 8;
}
my $branch;
my @branch;
my %branch;
$branch = "$_[0]";
if (do {
$main_exit_code = system('test', '-z', "$new_name") >> 8;
    $CHILD_ERROR == 0
}) {
        $new_name = "$branch";
}
if (! StringInterpolation(StringInterpolation { parts: [Variable("scan_reflog")] }, None) eq q{}) {
if ((-r 'StringInterpolation(StringInterpolation { parts: [Variable("GIT_DIR")] }, None) /logs/HEAD')) {
        my $candidates;
        my @candidates;
        my %candidates;
        $candidates = (do { my $_chomp_temp = do {
    my ($in_7, $out_7);
    my $pid_7 = open3($in_7, $out_7, '>&STDERR', 'search_reflog', $branch);
    close $in_7 or croak 'Close failed: $OS_ERROR';
    my $result_7 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
    close $out_7 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_7, 0;
    $result_7
}; chomp $_chomp_temp; $_chomp_temp; });
}
    else {
        $main_exit_code = system('die', 'reflog scanning requested, but', '$GIT_DIR/logs/HEAD not readable') >> 8;
    }
}
if (! StringInterpolation(StringInterpolation { parts: [Variable("scan_reflog_merges")] }, None) eq q{}) {
if ((-r 'StringInterpolation(StringInterpolation { parts: [Variable("GIT_DIR")] }, None) /logs/HEAD')) {
        $candidates = "$candidates " . (do { my $_chomp_temp = do {
    my ($in_8, $out_8);
    my $pid_8 = open3($in_8, $out_8, '>&STDERR', 'search_reflog_merges', $branch);
    close $in_8 or croak 'Close failed: $OS_ERROR';
    my $result_8 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_8> };
    close $out_8 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_8, 0;
    $result_8
}; chomp $_chomp_temp; $_chomp_temp; });
}
    else {
        $main_exit_code = system('die', 'reflog scanning requested, but', '$GIT_DIR/logs/HEAD not readable') >> 8;
    }
}
if (! StringInterpolation(StringInterpolation { parts: [Variable("scan_merges")] }, None) eq q{}) {
    $candidates = "$candidates " . (do { my $_chomp_temp = do {
    my ($in_9, $out_9);
    my $pid_9 = open3($in_9, $out_9, '>&STDERR', 'search_merges', $branch);
    close $in_9 or croak 'Close failed: $OS_ERROR';
    my $result_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_9> };
    close $out_9 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_9, 0;
    $result_9
}; chomp $_chomp_temp; $_chomp_temp; });
}
if (! StringInterpolation(StringInterpolation { parts: [Variable("scan_merge_targets")] }, None) eq q{}) {
    $candidates = "$candidates " . (do { my $_chomp_temp = do {
    my ($in_10, $out_10);
    my $pid_10 = open3($in_10, $out_10, '>&STDERR', 'search_merge_targets', $branch);
    close $in_10 or croak 'Close failed: $OS_ERROR';
    my $result_10 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_10> };
    close $out_10 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_10, 0;
    $result_10
}; chomp $_chomp_temp; $_chomp_temp; });
}
$candidates = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_11 = q{};
    my $output_printed_11;
    my $pipeline_success_11 = 1;

    my ($in_12, $out_12);
    my $pid_12 = open3($in_12, $out_12, '>&STDERR', 'git', 'rev-parse');
    close $in_12 or croak 'Close failed: $OS_ERROR';
    $output_11 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_12> };
    close $out_12 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_12, 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_11 = 0; }
    my @sort_lines_11_1 = split /\n/msx, $output_11;
    my @sort_sorted_11_1 = sort @sort_lines_11_1;
    $output_11 = join "\n", @sort_sorted_11_1;
        if ($output_11 ne q{} && !($output_11 =~ m{\n\z}msx)) {
            $output_11 .= "\n";
        }
    if ( !$pipeline_success_11 ) { $main_exit_code = 1; }
    $output_11 =~ s/\n+\z//msx;
    $output_11;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
if (StringInterpolation(StringInterpolation { parts: [Variable("candidates")] }, None) eq q{}) {
    my $hint;
    my @hint;
    my %hint;
    $hint = q{};
    if (do {
$main_exit_code = system('test', "z$all_strategies", q{!}, q{=}, "ztttt") >> 8;
        $CHILD_ERROR == 0
    }) {
                $hint = " (maybe try again with -a)";
    }
    $main_exit_code = system('die', "no candidates for $branch found$hint") >> 8;
}
do {
    my $__echo_line = "** Candidates for $branch **";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
# Original bash: #!/bin/sh
{
    my $output_13 = q{};
    my $output_printed_13;
    my $pipeline_success_13 = 1;
        $output_13 = q{};
    my @output_13_items = ($candidates);
    for my $cmt (@output_13_items) {
    my ($in_14, $out_14);
    my @_pcmd_15 = ('bash', '-c', q{git --no-pager log --pretty=tformat: '%ct:%h [%cr] %s' --abbrev-commit -1 $cmt});
    my $pid_14 = open3($in_14, $out_14, '>&STDERR', @_pcmd_15);
    close $in_14 or croak 'Close failed: $OS_ERROR';
    while (my $line = <$out_14>) {
    $output_13 .= $line;
    }
    close $out_14 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_14, 0;
    $CHILD_ERROR = $? >> 8;
    }

        my @sort_lines_13_1 = split /\n/msx, $output_13;
    my @sort_sorted_13_1 = sort {
    my @a_fields = split /\s+/msx, $a;
    my @b_fields = split /\s+/msx, $b;
    my $a_num = 0;
    my $b_num = 0;
    my $a_key = ( scalar @a_fields > 0 ) ? $a_fields[0] : q{}; $a_key =~ s/^\s+|\s+$//g;
    my $b_key = ( scalar @b_fields > 0 ) ? $b_fields[0] : q{}; $b_key =~ s/^\s+|\s+$//g;
    if ( $a_key =~ /^\d+(?:[.]\d+)?$/msx ) { $a_num = $a_key; }
    if ( $b_key =~ /^\d+(?:[.]\d+)?$/msx ) { $b_num = $b_key; }
    $a_num <=> $b_num || $a cmp $b
    } @sort_lines_13_1;
    my $output_13_1 = join "\n", @sort_sorted_13_1;
    if ($output_13_1 ne q{} && !($output_13_1 =~ m{\n\z}msx)) {
    $output_13_1 .= "\n";
    }
    $output_13 = $output_13_1;
    $output_13 = $output_13_1;

        my @lines_16 = split /\n/msx, $output_13;
    my @result_16;
    foreach my $line (@lines_16) {
    chomp $line;
    my @fields = split /:/msx, $line;
    if (@fields > 1) { push @result_16, join(q{:}, @fields[1..@fields-1]); }
    }
    $output_13 = join "\n", @result_16;
    if ($output_13 ne q{} && !($output_13  =~ m{\n\z}msx)) { $output_13 .= "\n"; }
    if ($output_13 ne q{} && !defined $output_printed_13) {
        print $output_13;
        if (!($output_13 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_13 ) { $main_exit_code = 1; }
    }
my $newest;
my @newest;
my %newest;
$newest = (do { my $_chomp_temp = do {
    my ($in_17, $out_17);
    my $pid_17 = open3($in_17, $out_17, '>&STDERR', 'git', 'rev-list', '-1', $candidates);
    close $in_17 or croak 'Close failed: $OS_ERROR';
    my $result_17 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_17> };
    close $out_17 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_17, 0;
    $result_17
}; chomp $_chomp_temp; $_chomp_temp; });
if (! StringInterpolation(StringInterpolation { parts: [Variable("dry_run")] }, None) eq q{}) {
printf('** Most recent: ');
    $main_exit_code = system('git', '--no-pager', 'log', '-1', '--pretty=tformat:', "%h %s", $newest) >> 8;
}
else {
    if (!(!(do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('git', 'rev-parse', '--verify', '--quiet', $new_name) >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };))) {
printf('** Restoring  to ');
        $main_exit_code = system('git', '--no-pager', 'log', '-1', '--pretty=tformat:', "%h %s", $newest) >> 8;
        $main_exit_code = system('git', 'branch', $new_name, $newest) >> 8;
}
    else {
printf('Most recent: ');
        $main_exit_code = system('git', '--no-pager', 'log', '-1', '--pretty=tformat:', "%h %s", $newest) >> 8;
        do {
    my $__echo_line = "** $new_name already exists, doing nothing";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
}

exit $main_exit_code;
