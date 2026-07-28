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


sub usage {
print q{usage: git jump [--stdout] <mode> [<args>]

Jump to interesting elements in an editor.
The <mode> parameter is one of:

diff: elements are diff hunks. Arguments are given to diff.

merge: elements are merge conflicts. Arguments are given to ls-files -u.

grep: elements are grep hits. Arguments are given to git grep or, if
      configured, to the command in `jump.grepCmd`.

ws: elements are whitespace errors. Arguments are given to diff --check.

If the optional argument `--stdout` is given, print the quickfix
lines to standard output instead of feeding it to the editor.
};
    return;
}

sub open_editor {
    my $editor;
    my @editor;
    my %editor;
    $editor = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'git', 'var', 'GIT_EDITOR');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
if ("$editor" =~ /^.*emacs.*$/msx) {
        do { my $eval_input = $editor . " --eval \"(let ((buf (grep \\\"cat $1\\\"))) (pop-to-buffer buf) (select-frame-set-input-focus (selected-frame)) (while (get-buffer-process buf) (sleep-for 0.1)))\""; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
    } elsif (1) {
        do { my $eval_input = $editor . " -q $1"; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
    }
    return;
}

sub mode_diff {
    my ($file) = @_;
    # Original bash: git diff --no-prefix --relative "$@" |
{
        my $output_1 = q{};
        my $output_printed_1;
        my $pipeline_success_1 = 1;
                my ($in_2, $out_2);
        my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'git', 'diff', '--no-prefix', '--relative');
        close $in_2 or croak 'Close failed: $OS_ERROR';
        $output_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
        close $out_2 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_2, 0;

                my $perl_output_3 = q{};
        for my $line (split /\n/msx, $output_1) {
        $_ = "$line\n";
        if (!defined $ENV{SHELL_VAR}) { $ENV{SHELL_VAR} = q{}; }
        if (m{^\+\+\+ (.*)}) { $file = $1; next }
        defined($file) or next;
        if (m/^@@ .*?\+(\d+)/) { $line = $1; next }
        defined($line) or next;
        if (/^ /) { $line++; next }
        if (/^[-+]\s*(.*)/) {
        $perl_output_3 .= "$file:$line: $1\n";
        $line = undef;
        }
        }
        $output_1 = $perl_output_3;
        if ($output_1 ne q{} && !defined $output_printed_1) {
            print $output_1;
            if (!($output_1 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
        }
    return;
}

sub mode_merge {
    # Original bash: git ls-files -u "$@" |
{
        my $output_4 = q{};
        my $output_printed_4;
        my $pipeline_success_4 = 1;
                my ($in_5, $out_5);
        my $pid_5 = open3($in_5, $out_5, '>&STDERR', 'git', 'ls-files', '-u');
        close $in_5 or croak 'Close failed: $OS_ERROR';
        $output_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
        close $out_5 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_5, 0;

                my $perl_output_6 = do {
        my $result = qx{perl '-p' q{e} "\"s/^.*?\\\\t//\""};
        chomp $result;
        $result;
        };
        print $perl_output_6;

                my @sort_lines_4_2 = split /\n/msx, $output_4;
        my @sort_sorted_4_2 = sort @sort_lines_4_2;
        my $output_4_2 = join "\n", @sort_sorted_4_2;
        if ($output_4_2 ne q{} && !($output_4_2 =~ m{\n\z}msx)) {
        $output_4_2 .= "\n";
        }
        $output_4 = $output_4_2;
        $output_4 = $output_4_2;

                my @lines = split /\n/msx, $output_4;
        my $result_4_3 = q{};
        for my $line (@lines) {
        chomp $line;
        my $L = $line;
        my $grep_result_7;
        my @grep_lines_7 = ();
        my @grep_filtered_7 = grep { /^<<<<<<</msx } @grep_lines_7;
        my @grep_numbered_7;
        for my $i (0..@grep_lines_7-1) {
        if (scalar grep { $_ eq $grep_lines_7[$i] } @grep_filtered_7) {
        push @grep_numbered_7, sprintf "%d:%s", $i + 1, $grep_lines_7[$i];
        }
        }
        $grep_result_7 = join "\n", @grep_numbered_7;
        print $grep_result_7;
        print "\n";
        $CHILD_ERROR = scalar @grep_filtered_7 > 0 ? 0 : 1;
        }
        $output_4 = $result_4_3;
        if ($output_4 ne q{} && !defined $output_printed_4) {
            print $output_4;
            if (!($output_4 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_4 ) { $main_exit_code = 1; }
        }
    return;
}

sub mode_grep {
    my $cmd;
    my @cmd;
    my %cmd;
    $cmd = do {
    my ($in_8, $out_8);
    my $pid_8 = open3($in_8, $out_8, '>&STDERR', 'git', 'config', 'jump.grepCmd');
    close $in_8 or croak 'Close failed: $OS_ERROR';
    my $result_8 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_8> };
    close $out_8 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_8, 0;
    $result_8
};
        $main_exit_code = system('test', '-n', "$cmd") >> 8;
    if ($CHILD_ERROR != 0) {
                $cmd = "git grep -n --column";
    }
    # Original bash: $cmd "$@" |
{
        my $output_9 = q{};
        my $output_printed_9;
        my $pipeline_success_9 = 1;
                my ($in_10, $out_10);
        my $pid_10 = open3($in_10, $out_10, '>&STDERR', 'unknown_command', );
        close $in_10 or croak 'Close failed: $OS_ERROR';
        $output_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_10> };
        close $out_10 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_10, 0;

                my $perl_output_11 = do {
        my $result = qx{perl '-p' q{e} "\"\n\ts/[ \\\\t]+/ /g;\n\ts/^ *//;\n\t\""};
        chomp $result;
        $result;
        };
        print $perl_output_11;
        if ($output_9 ne q{} && !defined $output_printed_9) {
            print $output_9;
            if (!($output_9 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_9 ) { $main_exit_code = 1; }
        }
    return;
}

sub mode_ws {
    $main_exit_code = system('git', 'diff', '--check', "@ARGV") >> 8;
    return;
}
my $use_stdout;
my @use_stdout;
my %use_stdout;
$use_stdout = q{};
my $# = 0;
while ( (Variable("#", false, None) > 0) ) {
if ("$_[0]" =~ /^--stdout$/msx) {
                $use_stdout = q{t};
    } elsif ("$_[0]" =~ /^--.*$/msx) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            usage();
        };
        exit 1;
    } elsif (1) {
        last;    }
# Builtin command 'shift' not implemented
}
if ((Variable("#", false, None) < 1)) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        usage();
    };
exit 1;
}
my $mode;
my @mode;
my %mode;
$mode = $1;
# Builtin command 'shift' not implemented
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('type', "mode_$mode") >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
if ($CHILD_ERROR != 0) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            usage();
        };
exit 1;
}
if (StringInterpolation(StringInterpolation { parts: [Variable("use_stdout")] }, None) eq StringInterpolation(StringInterpolation { parts: [Literal("t")] }, None)) {
    $CHILD_ERROR = 0;
exit 0;
}
END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx'rm -f "$tmp" 2>&1'; print $end_out if $end_out ne q{}; }
my $tmp;
my @tmp;
my %tmp;
$tmp = do {
    my ($in_12, $out_12);
    my $pid_12 = open3($in_12, $out_12, '>&STDERR', 'mktemp', '-t', 'git-jump.XXXXXX');
    close $in_12 or croak 'Close failed: $OS_ERROR';
    my $result_12 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_12> };
    close $out_12 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_12, 0;
    $result_12
};
if ($CHILD_ERROR != 0) {
    exit 1;
}
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', "$tmp"
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    $CHILD_ERROR = 0;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
$main_exit_code = system('test', '-s', "$tmp") >> 8;
if ($CHILD_ERROR != 0) {
    exit 0;
}
open_editor("$tmp");

exit $main_exit_code;
