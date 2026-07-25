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

my $SELECTED_EDITOR;
my @SELECTED_EDITOR;
my %SELECTED_EDITOR;
my $HOME;
my @HOME;
my %HOME;
my $EDITOR;
my @EDITOR;
my %EDITOR;

my $PATH;
my @PATH;
my %PATH;
$PATH = "$PATH:/usr/share/sensible-utils/bin";
my $program;
my @program;
my %program;
$program = (do { my $_chomp_temp = do {
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'realpath', (do { my $_chomp_temp = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'command', '-v', "$PROGRAM_NAME");
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
}; chomp $_chomp_temp; $_chomp_temp; }));
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    $result_1
}; chomp $_chomp_temp; $_chomp_temp; });

sub Try {
    $CHILD_ERROR = 0;
    my $ret;
    my @ret;
    my %ret;
    $ret = $?;
    if (do {
if (($ret != 126)) {
    ($ret != 127)    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
        $CHILD_ERROR == 0
    }) {
            }
    return;
}

sub TryEnv {
    if ("$candidate" eq q{}) {
        return;        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if (x$(realpath "$(command -v "$candidate" || true)" || true) eq x"$program") {
        return;        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    $main_exit_code = system('sh', '-c', "$ENV{candidate} \"$@\"", 'EDITOR', "@ARGV") >> 8;
    my $ret;
    my @ret;
    my %ret;
    $ret = $?;
    if (do {
if (($ret != 126)) {
    ($ret != 127)    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
        $CHILD_ERROR == 0
    }) {
            }
    return;
}

sub nano {
if ("$TERM" eq q{}) {
return '126';
}
    else {
        $main_exit_code = system('command', 'nano', "@ARGV") >> 8;
    }
    return;
}
my $candidate;
for my $candidate ("$ENV{VISUAL}", "$EDITOR", "$ENV{SENSIBLE_EDITOR}", "$SELECTED_EDITOR") {
    TryEnv("@ARGV");
}
if ("$HOME" ne q{}) {
if ((-r '~/.selected_editor')) {
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
            $main_exit_code = system('.', q{~}, '/.selected_editor') >> 8;
        };
}
    else {
        if ((("$EDITOR" eq q{} && "$SELECTED_EDITOR" eq q{}) && (-t0))) {
            if (do {
$main_exit_code = system('bash', 'select-editor') >> 8;
                $CHILD_ERROR == 0
            }) {
                                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                    $main_exit_code = system('.', q{~}, '/.selected_editor') >> 8;
                };
            }
        }
    }
}
for my $candidate ("$EDITOR", "$SELECTED_EDITOR") {
    TryEnv("@ARGV");
}
for my $candidate ('editor', 'nano', 'nano-tiny', 'vi') {
    Try("@ARGV");
}
do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
    print "Couldn't find an editor!\n";
};
do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
    do {
    my $__echo_line = 'Set the $EDITOR environment variable to your desired editor.';
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
};
exit 1;

exit $main_exit_code;
