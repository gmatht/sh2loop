#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

my $PATH = "/usr/bin:$ENV{PATH}";
$ENV{PATH} = $PATH;
my $prog = do {
    do { do {
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;
    $output_0 .= $0 . "\n";
    if ( !($output_0 =~ m{\n\z}) ) { $output_0 .= "\n"; }
    if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
    my @sed_lines_0 = split /\n/, $output_0;
    my @sed_result_0;
    foreach my $line (@sed_lines_0) {
    chomp $line;
    push @sed_result_0, $line;
    }
    $output_0 = join "\n", @sed_result_0;

    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    $output_0 =~ s/\n+\z//msx;
    $output_0;
}; };
};
my $more;
if ("$prog" =~ /^.*less$/msx) {
        $more = 'less';
} elsif (1) {
        $more = 'more';
}
my $n1;
my $n2;
if (StringInterpolation(StringInterpolation { parts: [CommandSubstitution(Simple(SimpleCommand { name: Literal("echo", None), args: [Literal("-n", None), Literal("a", None)], redirects: [], env_vars: {}, stdout_used: true, stderr_used: true }))] }, None) eq StringInterpolation(StringInterpolation { parts: [Literal("-n a")] }, None)) {
    $n1 = q{};
    $n2 = "\\c";
}
else {
    $n1 = '-n';
    $n2 = q{};
}
my $oldtty = do { my @_qx_cmd = ("stty -g 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
my $ncb;
my $cb;
if (!(do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
    $main_exit_code = system('stty', '-c', 'break') >> 8;
};)) {
    $cb = 'cbreak';
    $ncb = '-cbreak';
}
else {
    $cb = 'min 1 -icanon';
    $ncb = 'icanon eof ^d';
}
if ((!(system('test', $?, '-eq', q{0}) >> 8) && !(system('test', '-n', "$oldtty") >> 8))) {
END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx'stty $oldtty 2>/dev/null; exit 2>&1'; print $end_out if $end_out ne q{}; }
;
}
else {
END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx'stty $ncb echo 2>/dev/null; exit 2>&1'; print $end_out if $end_out ne q{}; }
;
}
my $FIRST;
my $ANS;
if (Variable("#", false, None) eq 0) {
if ((-t 0)) {
        say 'usage:' . q{ } . $prog . q{ } . 'files...';
}
    else {
        # Original bash: bzip2 -cdfq | eval $more
do {
            my $output_1 = q{};
            my $output_printed_1;
            my $pipeline_success_1 = 1;
                        my ($in_2, $out_2);
            my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'bzip2', '-c', 'dfq');
            close $in_2 or croak 'Close failed: $OS_ERROR';
            $output_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
            close $out_2 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_2, 0;

                        my @_pcmd_4 = ('bash', '-c', "echo \"${output_1}\" | : \"Complex command cannot be converted to shell command\"");
            my ($in_3);
            my $pid_3 = open3($in_3, $out_3, '>&STDERR', @_pcmd_4);
            close $in_3 or croak 'Close failed: $OS_ERROR';
            my $temp_result;
            $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
            $output_1 = $temp_result;
            close $out_3 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_3, 0;
            if ($output_1 ne q{} && !defined $output_printed_1) {
                print $output_1;
                if (!($output_1 =~ m{\n\z})) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
            }
;
    }
}
else {
    $FIRST = q{1};
    my $FILE;
    for my $FILE () {
if ((Variable("FIRST", false, None) == 0)) {
            say $n1 . q{ } . "--More--(Next file: $FILE)$n2";
            do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
                $main_exit_code = system('stty', $cb, '-e', 'cho') >> 8;
            };
            $ANS = do { my @_qx_cmd = ("dd bs = 1 count = 1 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
            do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
                $main_exit_code = system('stty', $ncb, 'echo') >> 8;
            };
            say " ";
if ((!(system('test', "$ANS", q{=}, q{e}) >> 8) || !(system('test', "$ANS", q{=}, q{q}) >> 8))) {
exit $main_exit_code;
            }
        }
if ((!StringInterpolation(StringInterpolation { parts: [Variable("ANS")] }, None) eq s)) {
            say "------> $FILE <------";
            # Original bash: bzip2 -cdfq "$FILE" | eval $more
do {
                my $output_5 = q{};
                my $output_printed_5;
                my $pipeline_success_5 = 1;
                                my ($in_6, $out_6);
                my $pid_6 = open3($in_6, $out_6, '>&STDERR', 'bzip2', '-c', 'dfq');
                close $in_6 or croak 'Close failed: $OS_ERROR';
                $output_5 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> };
                close $out_6 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_6, 0;

                                my @_pcmd_8 = ('bash', '-c', "echo \"${output_5}\" | : \"Complex command cannot be converted to shell command\"");
                my ($in_7);
                my $pid_7 = open3($in_7, $out_7, '>&STDERR', @_pcmd_8);
                close $in_7 or croak 'Close failed: $OS_ERROR';
                my $temp_result;
                $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
                $output_5 = $temp_result;
                close $out_7 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_7, 0;
                if ($output_5 ne q{} && !defined $output_printed_5) {
                    print $output_5;
                    if (!($output_5 =~ m{\n\z})) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_5 ) { $main_exit_code = 1; }
                }
;
        }
if ((-t)) {
            $FIRST = q{0};
        }
    }
;
}
