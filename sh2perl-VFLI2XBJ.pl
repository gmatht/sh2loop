#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

my $main_exit_code = 0;
my $output         = q{};
our $CHILD_ERROR;

$main_exit_code = system('.', 'git-sh-setup') >> 8;
my $LF = "\n";
    my $bases = q{};
    my $head = q{};
    my $remotes = q{};
    my $sep_seen = q{};
my $arg;
for my $arg () {
if (",$sep_seen,$head,$arg," =~ /^.*,--,$/msx) {
                $sep_seen = 'yes';
    } elsif (",$sep_seen,$head,$arg," =~ /^,yes,,.*$/msx) {
                $head = $arg;
    } elsif (",$sep_seen,$head,$arg," =~ /^,yes,.*$/msx) {
                $remotes = "$remotes$arg ";
    } elsif (1) {
                $bases = "$bases$arg ";
    }
}
if ("$remotes" =~ /^..*' '..*$/msx) {
} elsif (1) {
    exit 2;
}
if (system('git', 'diff-index', '--quiet', '--cached', 'HEAD', '--') >> 8) {
    $main_exit_code = system('gettextln', "Error: Your local changes to the following files would be overwritten by merge") >> 8;
    # Original bash: git diff-index --cached --name-only HEAD -- | sed -e 's/^/    /'
do {
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
                my ($in_1, $out_1);
        my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'git', 'diff-index', '--cached', '--name-only', 'HEAD', '--');
        close $in_1 or croak 'Close failed: $OS_ERROR';
        $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
        close $out_1 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_1, 0;

                my @sed_lines_0 = split /\n/, $output_0;
        my @sed_result_0;
        foreach my $line (@sed_lines_0) {
        chomp $line;
        push @sed_result_0, $line;
        }
        $output_0 = join "\n", @sed_result_0;
        if ($output_0 ne q{} && !defined $output_printed_0) {
            print $output_0;
            if (!($output_0 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        }
;
exit 2;
}
my $MRC = do {
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'git', 'rev-parse', '--verify', '-q', $head);
    close $in_2 or croak 'Close failed: $OS_ERROR';
    my $result_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    $result_2
};
my $MRT = do {
    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'git', 'write-tree');
    close $in_3 or croak 'Close failed: $OS_ERROR';
    my $result_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;
    $result_3
};
my $NON_FF_MERGE = q{0};
my $OCTOPUS_FAILURE = q{0};
my $SHA1_UP;
my $next;
my $common;
my $SHA1;
for my $SHA1 ($remotes) {
if ("$OCTOPUS_FAILURE" eq '1') {
                $main_exit_code = system('gettextln', "Automated merge did not work.") >> 8;
                $main_exit_code = system('gettextln', "Should not be doing an octopus.") >> 8;
        exit 2;
    }
do { my $eval_input = "pretty_name" . "=" . "\\${GITHEAD_" . $SHA1 . ":-" . $SHA1 . "}"; system('bash', '-c', $eval_input); $CHILD_ERROR = $? >> 8; };
if (StringInterpolation(StringInterpolation { parts: [Variable("SHA1")] }, None) eq StringInterpolation(StringInterpolation { parts: [Variable("pretty_name")] }, None)) {
        $SHA1_UP = (do { chomp(my $result_4 = qx{echo "$SHA1" | tr a-z A-Z}); $result_4; });
do { my $eval_input = "pretty_name" . "=" . "\\${GITHEAD_" . $SHA1_UP . ":-" . $pretty_name . "}"; system('bash', '-c', $eval_input); $CHILD_ERROR = $? >> 8; };
    }
        $common = do {
    my ($in_5, $out_5);
    my $pid_5 = open3($in_5, $out_5, '>&STDERR', 'git', 'merge-base', '--all', $SHA1, $MRC);
    close $in_5 or croak 'Close failed: $OS_ERROR';
    my $result_5 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
    close $out_5 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_5, 0;
    $result_5
};
    if ($CHILD_ERROR != 0) {
                $main_exit_code = system('die', (do {
    my ($in_6, $out_6);
    my $pid_6 = open3($in_6, $out_6, '>&STDERR', 'eval_gettext', "Unable to find common commit with $pretty_name");
    close $in_6 or croak 'Close failed: $OS_ERROR';
    my $result_6 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> };
    close $out_6 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_6, 0;
    $result_6
})) >> 8;
    }
;
if ("$LF$common$LF" =~ /^.*"$LF$SHA1$LF".*$/msx) {
                $main_exit_code = system('eval_gettextln', "Already up to date with $pretty_name") >> 8;
        next;    }
if (StringInterpolation(StringInterpolation { parts: [Variable("common"), Literal(","), Variable("NON_FF_MERGE")] }, None) eq StringInterpolation(StringInterpolation { parts: [Variable("MRC"), Literal(",0")] }, None)) {
        $main_exit_code = system('eval_gettextln', "Fast-forwarding to: $pretty_name") >> 8;
                $main_exit_code = system('git', 'read-tree', '-u', '-m', $head, $SHA1) >> 8;
        if ($CHILD_ERROR != 0) {
            exit $main_exit_code;
        }
;
            $MRC = $SHA1;
            $MRT = do {
    my ($in_7, $out_7);
    my $pid_7 = open3($in_7, $out_7, '>&STDERR', 'git', 'write-tree');
    close $in_7 or croak 'Close failed: $OS_ERROR';
    my $result_7 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
    close $out_7 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_7, 0;
    $result_7
};
next;
    }
    $NON_FF_MERGE = q{1};
    $main_exit_code = system('eval_gettextln', "Trying simple merge with $pretty_name") >> 8;
        $main_exit_code = system('git', 'read-tree', '-u', '-m', '--aggressive', $common, $MRT, $SHA1) >> 8;
    if ($CHILD_ERROR != 0) {
        exit 2;
    }
;
    $next = do { my @_qx_cmd = ("git write-tree 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if ((Variable("?", false, None) != 0)) {
        $main_exit_code = system('gettextln', "Simple merge did not work, trying automatic merge.") >> 8;
                $main_exit_code = system('git', 'merge-index', '-o', 'git-merge-one-file', '-a') >> 8;
        if ($CHILD_ERROR != 0) {
                        $OCTOPUS_FAILURE = q{1};
        }
;
        $next = do { my @_qx_cmd = ("git write-tree 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
    }
    $MRC = "$MRC $SHA1";
    $MRT = $next;
}


exit $main_exit_code;
