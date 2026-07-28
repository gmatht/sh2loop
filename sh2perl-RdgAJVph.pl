#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

my $xz = 'xz --format=auto';
my $version = 'xzmore (XZ Utils) 5.4.5';
my $usage = "Usage: " . ( ( basename($_[0]) ) =~ s|^.*/||sr ) . " [OPTION]... [FILE]...
Like 'more', but operate on the uncompressed contents of xz compressed FILEs.

Report bugs to <xz\@tukaani.org>.";
if ($arg1 =~ /^--help$/msx) {
        printf("%s\n", "$usage");
    if ($CHILD_ERROR != 0) {
        exit 2;
    }
    exit $main_exit_code;
} elsif ($arg1 =~ /^--version$/msx) {
        printf("%s\n", "$version");
    if ($CHILD_ERROR != 0) {
        exit 2;
    }
    exit $main_exit_code;
}
my $oldtty = do { my @_qx_cmd = ("stty -g 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
my $cb;
my $ncb;
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
printf("%s\n", "$usage");
exit 1;
}
    else {
        # Original bash: $xz -cdfqQ | eval "${PAGER:-more}"
do {
            my $output_3 = q{};
            my $output_printed_3;
            my $pipeline_success_3 = 1;
                        my ($in_4, $out_4);
            my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'unknown_command', '-c', 'dfqQ');
            close $in_4 or croak 'Close failed: $OS_ERROR';
            $output_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
            close $out_4 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_4, 0;

                        my @_pcmd_6 = ('bash', '-c', "echo \"${output_3}\" | : \"Complex command cannot be converted to shell command\"");
            my ($in_5);
            my $pid_5 = open3($in_5, $out_5, '>&STDERR', @_pcmd_6);
            close $in_5 or croak 'Close failed: $OS_ERROR';
            my $temp_result;
            $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
            $output_3 = $temp_result;
            close $out_5 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_5, 0;
            if ($output_3 ne q{} && !defined $output_printed_3) {
                print $output_3;
                if (!($output_3 =~ m{\n\z})) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
            }
;
    }
}
else {
    $FIRST = q{1};
    my $FILE;
    for my $FILE () {
        open STDIN, '<', "$FILE" or croak "Cannot read file: $OS_ERROR\n";
        if ($CHILD_ERROR != 0) {
            next;
        }
;
if ((Variable("FIRST", false, None) == 0)) {
printf('%s--More--(Next file: %s)', "", "$FILE");
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
if ("$ANS" =~ /^\[eq\]$/msx) {
                exit $main_exit_code;
            }
        }
if ((!StringInterpolation(StringInterpolation { parts: [Variable("ANS")] }, None) eq s)) {
printf("%s\n", "------> $FILE <------");
            # Original bash: $xz -cdfqQ -- "$FILE" | eval "${PAGER:-more}"
do {
                my $output_9 = q{};
                my $output_printed_9;
                my $pipeline_success_9 = 1;
                                my ($in_10, $out_10);
                my $pid_10 = open3($in_10, $out_10, '>&STDERR', 'unknown_command', '-c', 'dfqQ', '--');
                close $in_10 or croak 'Close failed: $OS_ERROR';
                $output_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_10> };
                close $out_10 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_10, 0;

                                my @_pcmd_12 = ('bash', '-c', "echo \"${output_9}\" | : \"Complex command cannot be converted to shell command\"");
                my ($in_11);
                my $pid_11 = open3($in_11, $out_11, '>&STDERR', @_pcmd_12);
                close $in_11 or croak 'Close failed: $OS_ERROR';
                my $temp_result;
                $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_11> };
                $output_9 = $temp_result;
                close $out_11 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_11, 0;
                if ($output_9 ne q{} && !defined $output_printed_9) {
                    print $output_9;
                    if (!($output_9 =~ m{\n\z})) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_9 ) { $main_exit_code = 1; }
                }
;
        }
if ((-t 1)) {
            $FIRST = q{0};
        }
    }
;
}
