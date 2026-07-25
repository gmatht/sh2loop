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

if (StringInterpolation(StringInterpolation { parts: [Literal("X"), CommandSubstitution(Redirect(RedirectCommand { command: Subshell(Simple(SimpleCommand { name: Literal("echo", None), args: [Literal("\\t", None)], redirects: [], env_vars: {}, stdout_used: true, stderr_used: true })), redirects: [Redirect { fd: Some(2), operator: StderrOutput, target: Literal("/dev/null", None), heredoc_body: None, heredoc_quoted: false }] }))] }, None) eq X\t) {
    my $echo;
    my @echo;
    my %echo;
    $echo = 'echo';
}
else {
if (StringInterpolation(StringInterpolation { parts: [Literal("X"), CommandSubstitution(Redirect(RedirectCommand { command: Subshell(Simple(SimpleCommand { name: Literal("printf", None), args: [Literal("%s\\n", None), Literal("\\t", None)], redirects: [], env_vars: {}, stdout_used: true, stderr_used: true })), redirects: [Redirect { fd: Some(2), operator: StderrOutput, target: Literal("/dev/null", None), heredoc_body: None, heredoc_quoted: false }] }))] }, None) eq X\t) {
        $echo = "printf %s\\n";
}
    else {

sub echo_func {
print "$*
";
            return;
}
        $echo = 'echo_func';
    }
}
if (StringInterpolation(StringInterpolation { parts: [ParameterExpansion(ParameterExpansion { variable: "ZSH_VERSION+set", operator: None, is_mutable: true })] }, None) eq q{}) {
if ("$PROGRAM_NAME" =~ /^gettext.sh$/msx or "$PROGRAM_NAME" =~ /^.*/gettext.sh$/msx or "$PROGRAM_NAME" =~ /^.*\\gettext.sh$/msx) {
                my $progname;
        my @progname;
        my %progname;
        $progname = $PROGRAM_NAME;
                my $package;
        my @package;
        my %package;
        $package = 'gettext-runtime';
                my $version;
        my @version;
        my %version;
        $version = '0.21';

sub func_usage {
            do {
    my $__echo_line = "GNU gettext shell script function library version $version";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            print "Usage: . gettext.sh\n";
            return;
}

sub func_version {
            do {
    my $__echo_line = "$progname (GNU $package) $version";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            print "Copyright (C) 2003-2020 Free Software Foundation, Inc.
License GPLv2+: GNU GPL version 2 or later <https://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.\n";
            print "Written by" . q{ } . "Bruno Haible" . "\n";
            $CHILD_ERROR = 0;
            return;
}
        if (Variable("#", false, None) eq 1) {
if ("$_[0]" =~ /^--help$/msx or "$_[0]" =~ /^--hel$/msx or "$_[0]" =~ /^--he$/msx or "$_[0]" =~ /^--h$/msx) {
                                func_usage();
                exit 0;
            } elsif ("$_[0]" =~ /^--version$/msx or "$_[0]" =~ /^--versio$/msx or "$_[0]" =~ /^--versi$/msx or "$_[0]" =~ /^--vers$/msx or "$_[0]" =~ /^--ver$/msx or "$_[0]" =~ /^--ve$/msx or "$_[0]" =~ /^--v$/msx) {
                                func_version();
                exit 0;
            }
        }
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            func_usage();
        };
        exit 1;
    }
}

sub eval_gettext {
    my ($file) = @_;
    # Original bash: gettext "$1" | (export PATH `envsubst --variables "$1"`; envsubst "$1")
{
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
                my ($in_1, $out_1);
        my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'gettext', );
        close $in_1 or croak 'Close failed: $OS_ERROR';
        $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
        close $out_1 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_1, 0;

                $output_0 = q{};
        my @_pcmd_3 = ('sh', '-c', ': "Complex command cannot be converted to shell command"');
        my ($in_2, $out_2);
        my $pid_2 = open3($in_2, $out_2, '>&STDERR', @_pcmd_3);
        close $in_2 or croak 'Close failed: $OS_ERROR';
        $output_0 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
        close $out_2 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_2, 0;
        my @_pcmd_5 = ('sh', '-c', 'envsubst "$1"');
        my ($in_4, $out_4);
        my $pid_4 = open3($in_4, $out_4, '>&STDERR', @_pcmd_5);
        close $in_4 or croak 'Close failed: $OS_ERROR';
        $output_0 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
        close $out_4 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_4, 0;
        if ($output_0 ne q{} && !defined $output_printed_0) {
            print $output_0;
            if (!($output_0 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        }
    return;
}

sub eval_ngettext {
    my ($file) = @_;
    # Original bash: ngettext "$1" "$2" "$3" | (export PATH `envsubst --variables "$1 $2"`; envsubst "$1 $2")
{
        my $output_6 = q{};
        my $output_printed_6;
        my $pipeline_success_6 = 1;
                my ($in_7, $out_7);
        my $pid_7 = open3($in_7, $out_7, '>&STDERR', 'ngettext', );
        close $in_7 or croak 'Close failed: $OS_ERROR';
        $output_6 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
        close $out_7 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_7, 0;

                $output_6 = q{};
        my @_pcmd_9 = ('sh', '-c', ': "Complex command cannot be converted to shell command"');
        my ($in_8, $out_8);
        my $pid_8 = open3($in_8, $out_8, '>&STDERR', @_pcmd_9);
        close $in_8 or croak 'Close failed: $OS_ERROR';
        $output_6 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_8> };
        close $out_8 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_8, 0;
        my @_pcmd_11 = ('sh', '-c', 'envsubst "$1 $2"');
        my ($in_10, $out_10);
        my $pid_10 = open3($in_10, $out_10, '>&STDERR', @_pcmd_11);
        close $in_10 or croak 'Close failed: $OS_ERROR';
        $output_6 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_10> };
        close $out_10 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_10, 0;
        if ($output_6 ne q{} && !defined $output_printed_6) {
            print $output_6;
            if (!($output_6 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_6 ) { $main_exit_code = 1; }
        }
    return;
}

sub eval_pgettext {
    my ($file) = @_;
    # Original bash: gettext --context="$1" "$2" | (export PATH `envsubst --variables "$2"`; envsubst "$2")
{
        my $output_12 = q{};
        my $output_printed_12;
        my $pipeline_success_12 = 1;
                my ($in_13, $out_13);
        my $pid_13 = open3($in_13, $out_13, '>&STDERR', 'gettext', '--context=$1');
        close $in_13 or croak 'Close failed: $OS_ERROR';
        $output_12 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_13> };
        close $out_13 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_13, 0;

                $output_12 = q{};
        my @_pcmd_15 = ('sh', '-c', ': "Complex command cannot be converted to shell command"');
        my ($in_14, $out_14);
        my $pid_14 = open3($in_14, $out_14, '>&STDERR', @_pcmd_15);
        close $in_14 or croak 'Close failed: $OS_ERROR';
        $output_12 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_14> };
        close $out_14 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_14, 0;
        my @_pcmd_17 = ('sh', '-c', 'envsubst "$2"');
        my ($in_16, $out_16);
        my $pid_16 = open3($in_16, $out_16, '>&STDERR', @_pcmd_17);
        close $in_16 or croak 'Close failed: $OS_ERROR';
        $output_12 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_16> };
        close $out_16 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_16, 0;
        if ($output_12 ne q{} && !defined $output_printed_12) {
            print $output_12;
            if (!($output_12 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_12 ) { $main_exit_code = 1; }
        }
    return;
}

sub eval_npgettext {
    my ($file) = @_;
    # Original bash: ngettext --context="$1" "$2" "$3" "$4" | (export PATH `envsubst --variables "$2 $3"`; envsubst "$2 $3")
{
        my $output_18 = q{};
        my $output_printed_18;
        my $pipeline_success_18 = 1;
                my ($in_19, $out_19);
        my $pid_19 = open3($in_19, $out_19, '>&STDERR', 'ngettext', '--context=$1');
        close $in_19 or croak 'Close failed: $OS_ERROR';
        $output_18 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_19> };
        close $out_19 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_19, 0;

                $output_18 = q{};
        my @_pcmd_21 = ('sh', '-c', ': "Complex command cannot be converted to shell command"');
        my ($in_20, $out_20);
        my $pid_20 = open3($in_20, $out_20, '>&STDERR', @_pcmd_21);
        close $in_20 or croak 'Close failed: $OS_ERROR';
        $output_18 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> };
        close $out_20 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_20, 0;
        my @_pcmd_23 = ('sh', '-c', 'envsubst "$2 $3"');
        my ($in_22, $out_22);
        my $pid_22 = open3($in_22, $out_22, '>&STDERR', @_pcmd_23);
        close $in_22 or croak 'Close failed: $OS_ERROR';
        $output_18 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_22> };
        close $out_22 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_22, 0;
        if ($output_18 ne q{} && !defined $output_printed_18) {
            print $output_18;
            if (!($output_18 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_18 ) { $main_exit_code = 1; }
        }
    return;
}

exit $main_exit_code;
