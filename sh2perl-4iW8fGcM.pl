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


sub validate_cover_letter {
    my $file;
    my @file;
    my %file;
    $file = "$_[0]";
1;
    return;
}

sub validate_patch {
    my $file;
    my @file;
    my %file;
    $file = "$_[0]";
        $main_exit_code = system('git', 'am', '-3', "$file") >> 8;
    if ($CHILD_ERROR != 0) {
        return;    }
1;
    return;
}

sub validate_series {
1;
    return;
}
if (StringInterpolation(StringInterpolation { parts: [Variable("GIT_SENDEMAIL_FILE_COUNTER")] }, None) eq 1) {
    if (do {
if (do {
if (do {
if (do {
my $remote;
my @remote;
my %remote;
$remote = do {
    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'git', 'config', '--default', 'origin', '--get', 'sendemail.validateRemote');
    close $in_3 or croak 'Close failed: $OS_ERROR';
    my $result_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;
    $result_3
};
    $CHILD_ERROR == 0
}) {
        my $ref;
    my @ref;
    my %ref;
    $ref = do {
    my ($in_4, $out_4);
    my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'git', 'config', '--default', 'HEAD', '--get', 'sendemail.validateRemoteRef');
    close $in_4 or croak 'Close failed: $OS_ERROR';
    my $result_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
    close $out_4 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_4, 0;
    $result_4
};
}
    $CHILD_ERROR == 0
}) {
        my $worktree;
    my @worktree;
    my %worktree;
    $worktree = do {
    my ($in_5, $out_5);
    my $pid_5 = open3($in_5, $out_5, '>&STDERR', 'mktemp', '--tmpdir', '-d', 'sendemail-validate.XXXXXXX');
    close $in_5 or croak 'Close failed: $OS_ERROR';
    my $result_5 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
    close $out_5 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_5, 0;
    $result_5
};
}
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('git', 'worktree', 'add', '-f', q{d}, '--checkout', "$worktree", "refs/remotes/$remote/$ref") >> 8;
}
        $CHILD_ERROR == 0
    }) {
                $main_exit_code = system('git', 'config', '--replace-all', 'sendemail.validateWorktree', "$worktree") >> 8;
    }
}
else {
    $worktree = do {
    my ($in_6, $out_6);
    my $pid_6 = open3($in_6, $out_6, '>&STDERR', 'git', 'config', '--get', 'sendemail.validateWorktree');
    close $in_6 or croak 'Close failed: $OS_ERROR';
    my $result_6 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> };
    close $out_6 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_6, 0;
    $result_6
};
}
if ($CHILD_ERROR != 0) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "sendemail-validate: error: failed to prepare worktree\n";
        };
exit 1;
}
delete $ENV{GIT_DIR};
delete $ENV{GIT_WORK_TREE};
if (do {
if (do {
chdir("$worktree");
$CHILD_ERROR = 0;
    $CHILD_ERROR == 0
}) {
    if (!(my $grep_result_7;
my @grep_lines_7 = ();
my @grep_filtered_7 = grep { /^diff\ --git\ /msx } @grep_lines_7;
$grep_result_7 = join "\n", @grep_filtered_7;
    if (!($grep_result_7 =~ m{\n\z}msx || $grep_result_7 eq q{})) {
        $grep_result_7 .= "\n";
    }
$CHILD_ERROR = scalar @grep_filtered_7 > 0 ? 0 : 1;
$grep_result_7 = q{})) {
        validate_patch("$_[0]");
}
    else {
        validate_cover_letter("$_[0]");
    }
}
    $CHILD_ERROR == 0
}) {
    if (StringInterpolation(StringInterpolation { parts: [Variable("GIT_SENDEMAIL_FILE_COUNTER")] }, None) eq StringInterpolation(StringInterpolation { parts: [Variable("GIT_SENDEMAIL_FILE_TOTAL")] }, None)) {
        if (do {
if (do {
$main_exit_code = system('git', 'config', '--unset-all', 'sendemail.validateWorktree') >> 8;
    $CHILD_ERROR == 0
}) {
    END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx'git worktree remove -ff "$worktree" 2>&1'; print $end_out if $end_out ne q{}; }
}
            $CHILD_ERROR == 0
        }) {
                        validate_series();
        }
    }
}

exit $main_exit_code;
