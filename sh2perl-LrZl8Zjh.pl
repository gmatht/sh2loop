#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;
use File::Path qw(make_path remove_tree);

my $main_exit_code = 0;
my $output         = q{};
our $CHILD_ERROR;

my $max_score;
my $DEBASHC_FAILED;
my $QX_EXIT;
my $current_score;

my $MAGIC_124 = 124;

# set -o pipefail not implemented in Perl
# set pipefail not implemented
chdir((do { use File::Basename qw(dirname); my $dirname_output = dirname((do {
    my $command = 'readlink -f "$0" || echo "$0"';
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
})); $CHILD_ERROR = 0; $dirname_output; }) . "/sh2perl");
$CHILD_ERROR = 0;
if ($CHILD_ERROR != 0) {
            say "sh2perl/ not found";
exit 1;
}
say "To run this test: ./fail FAILING_TEST_PREFIX";
say "To run a specific test: ./fail TEST_PREFIX";
say "Examples: ./fail 062_02, ./fail 044, ./fail find";
$ENV{LOCALE} = 'C';
$ENV{LC_COLLATE} = 'C';
$ENV{PATH} = '';
use File::Path qw(make_path);
my $err;
if ( !-d 'logs' ) {
    make_path( 'logs', { error => \$err } );
    if ( @{$err} ) {
        croak "mkdir: cannot create directory " . 'logs' . ": $err->[0]\n";
    }
}
my $TIMESTAMP = do {
require POSIX; POSIX::strftime('', localtime())
};
my $LOG_FILE = "logs/fail_run_" . ${TIMESTAMP} . ".log";
# Original bash: echo "Starting test run at $(date)" | tee -a "$LOG_FILE"
do {
    my $output_1 = q{};
    my $output_printed_1;
    my $pipeline_success_1 = 1;
    $output_1 .= "Starting test run at " . (do {
require POSIX; POSIX::strftime('%a %b %e %H:%M:%S %Z %Y', localtime())
}) . "\n";
if ( !($output_1 =~ m{\n\z}) ) { $output_1 .= "\n"; }

        use Carp qw(carp croak);
    if ( open my $fh, '>>', "$LOG_FILE" ) {
    print {$fh} $output_1;
    close $fh or croak "Close failed: $ERRNO";
    }
    else {
    carp "tee: Cannot open "$LOG_FILE": $ERRNO";
    }
    $output_1 = $output_1;
    if ($output_1 ne q{} && !defined $output_printed_1) {
        print $output_1;
        if (!($output_1 =~ m{\n\z})) {
            print "\n";
        }
    }
    if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
    }
# Original bash: echo "Logging to: $LOG_FILE" | tee -a "$LOG_FILE"
do {
    my $output_2 = q{};
    my $output_printed_2;
    my $pipeline_success_2 = 1;
    $output_2 .= "Logging to: $LOG_FILE\n";
if ( !($output_2 =~ m{\n\z}) ) { $output_2 .= "\n"; }

        use Carp qw(carp croak);
    if ( open my $fh, '>>', "$LOG_FILE" ) {
    print {$fh} $output_2;
    close $fh or croak "Close failed: $ERRNO";
    }
    else {
    carp "tee: Cannot open "$LOG_FILE": $ERRNO";
    }
    $output_2 = $output_2;
    if ($output_2 ne q{} && !defined $output_printed_2) {
        print $output_2;
        if (!($output_2 =~ m{\n\z})) {
            print "\n";
        }
    }
    if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
    }
# Original bash: echo "Test arguments: $@" | tee -a "$LOG_FILE"
do {
    my $output_3 = q{};
    my $output_printed_3;
    my $pipeline_success_3 = 1;
    $output_3 .= "Test arguments: \\@ARGV\n";
if ( !($output_3 =~ m{\n\z}) ) { $output_3 .= "\n"; }

        use Carp qw(carp croak);
    if ( open my $fh, '>>', "$LOG_FILE" ) {
    print {$fh} $output_3;
    close $fh or croak "Close failed: $ERRNO";
    }
    else {
    carp "tee: Cannot open "$LOG_FILE": $ERRNO";
    }
    $output_3 = $output_3;
    if ($output_3 ne q{} && !defined $output_printed_3) {
        print $output_3;
        if (!($output_3 =~ m{\n\z})) {
            print "\n";
        }
    }
    if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
    }
# Original bash: echo "----------------------------------------" | tee -a "$LOG_FILE"
do {
    my $output_4 = q{};
    my $output_printed_4;
    my $pipeline_success_4 = 1;
    $output_4 .= '----------------------------------------' . "\n";
if ( !($output_4 =~ m{\n\z}) ) { $output_4 .= "\n"; }

        use Carp qw(carp croak);
    if ( open my $fh, '>>', "$LOG_FILE" ) {
    print {$fh} $output_4;
    close $fh or croak "Close failed: $ERRNO";
    }
    else {
    carp "tee: Cannot open "$LOG_FILE": $ERRNO";
    }
    $output_4 = $output_4;
    if ($output_4 ne q{} && !defined $output_printed_4) {
        print $output_4;
        if (!($output_4 =~ m{\n\z})) {
            print "\n";
        }
    }
    if ( !$pipeline_success_4 ) { $main_exit_code = 1; }
    }

sub run_with_timeout {
    my ($file) = @_;
    my $cmd = "$_[0]";
    my $timeout_seconds = (defined (defined $_[1] && $_[1] ne q{} ? $_[1] : '600') && (defined $_[1] && $_[1] ne q{} ? $_[1] : '600') ne q{} ? (defined $_[1] && $_[1] ne q{} ? $_[1] : '600') : '600');
    my $description = "$_[2]";
    # Original bash: echo "Running: $description" | tee -a "$LOG_FILE"
do {
        my $output_5 = q{};
        my $output_printed_5;
        my $pipeline_success_5 = 1;
        $output_5 .= "Running: $description\n";
if ( !($output_5 =~ m{\n\z}) ) { $output_5 .= "\n"; }

                use Carp qw(carp croak);
        if ( open my $fh, '>>', "$LOG_FILE" ) {
        print {$fh} $output_5;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open "$LOG_FILE": $ERRNO";
        }
        $output_5 = $output_5;
        if ($output_5 ne q{} && !defined $output_printed_5) {
            print $output_5;
            if (!($output_5 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_5 ) { $main_exit_code = 1; }
        }
;
    # Original bash: echo "Command: $cmd" | tee -a "$LOG_FILE"
do {
        my $output_6 = q{};
        my $output_printed_6;
        my $pipeline_success_6 = 1;
        $output_6 .= "Command: $cmd\n";
if ( !($output_6 =~ m{\n\z}) ) { $output_6 .= "\n"; }

                use Carp qw(carp croak);
        if ( open my $fh, '>>', "$LOG_FILE" ) {
        print {$fh} $output_6;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open "$LOG_FILE": $ERRNO";
        }
        $output_6 = $output_6;
        if ($output_6 ne q{} && !defined $output_printed_6) {
            print $output_6;
            if (!($output_6 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_6 ) { $main_exit_code = 1; }
        }
;
    # Original bash: echo "Timeout: ${timeout_seconds}s" | tee -a "$LOG_FILE"
do {
        my $output_7 = q{};
        my $output_printed_7;
        my $pipeline_success_7 = 1;
        $output_7 .= "Timeout: " . ${timeout_seconds} . "s\n";
if ( !($output_7 =~ m{\n\z}) ) { $output_7 .= "\n"; }

                use Carp qw(carp croak);
        if ( open my $fh, '>>', "$LOG_FILE" ) {
        print {$fh} $output_7;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open "$LOG_FILE": $ERRNO";
        }
        $output_7 = $output_7;
        if ($output_7 ne q{} && !defined $output_printed_7) {
            print $output_7;
            if (!($output_7 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_7 ) { $main_exit_code = 1; }
        }
;
    # Original bash: echo "----------------------------------------" | tee -a "$LOG_FILE"
do {
        my $output_8 = q{};
        my $output_printed_8;
        my $pipeline_success_8 = 1;
        $output_8 .= '----------------------------------------' . "\n";
if ( !($output_8 =~ m{\n\z}) ) { $output_8 .= "\n"; }

                use Carp qw(carp croak);
        if ( open my $fh, '>>', "$LOG_FILE" ) {
        print {$fh} $output_8;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open "$LOG_FILE": $ERRNO";
        }
        $output_8 = $output_8;
        if ($output_8 ne q{} && !defined $output_printed_8) {
            print $output_8;
            if (!($output_8 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_8 ) { $main_exit_code = 1; }
        }
;
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('command', '-v', 'powershell.exe') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };)) {
        # Original bash: powershell.exe -ExecutionPolicy Bypass -File "ps_timeout.ps1" -TimeoutSeconds "$timeout_seconds" -Command "$cmd" -Description "$description" 2>&1 | tee -a "$LOG_FILE"
do {
            my $output_9 = q{};
            my $output_printed_9;
            my $pipeline_success_9 = 1;
                        $output = q{};
                        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_10 = q{};

my $cmd_13 = 'powershell.exe';
my ($in_12, $out_12);
my $pid_12 = open3($in_12, $out_12, '>&STDERR', $cmd_13, '-ExecutionPolicy', 'Bypass', '-File', '-TimeoutSeconds', '-Command', '-Description');
print {$in_12} $output_9;
close $in_12 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_10 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_12> };
close $out_12 or croak 'Close failed: $OS_ERROR';
waitpid $pid_12, 0;
$tmp_redirect_10;
            };
            $output_9 = $output;

                        use Carp qw(carp croak);
            if ( open my $fh, '>>', "$LOG_FILE" ) {
            print {$fh} $output_9;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open "$LOG_FILE": $ERRNO";
            }
            $output_9 = $output_9;
            if ($output_9 ne q{} && !defined $output_printed_9) {
                print $output_9;
                if (!($output_9 =~ m{\n\z})) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_9 ) { $main_exit_code = 1; }
            }
;
        my $exit_code = "PIPESTATUS[0]";
if (($exit_code == $MAGIC_124)) {
            # Original bash: echo "Command timed out after ${timeout_seconds}s" | tee -a "$LOG_FILE"
do {
                my $output_14 = q{};
                my $output_printed_14;
                my $pipeline_success_14 = 1;
                $output_14 .= "Command timed out after " . ${timeout_seconds} . "s\n";
if ( !($output_14 =~ m{\n\z}) ) { $output_14 .= "\n"; }

                                use Carp qw(carp croak);
                if ( open my $fh, '>>', "$LOG_FILE" ) {
                print {$fh} $output_14;
                close $fh or croak "Close failed: $ERRNO";
                }
                else {
                carp "tee: Cannot open "$LOG_FILE": $ERRNO";
                }
                $output_14 = $output_14;
                if ($output_14 ne q{} && !defined $output_printed_14) {
                    print $output_14;
                    if (!($output_14 =~ m{\n\z})) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_14 ) { $main_exit_code = 1; }
                }
;
        }
}
    else {
        if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('command', '-v', 'timeout') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };)) {
            # Original bash: timeout --kill-after=5 "$timeout_seconds" bash -c "$cmd" 2>&1 | tee -a "$LOG_FILE"
do {
                my $output_15 = q{};
                my $output_printed_15;
                my $pipeline_success_15 = 1;
                                $output = q{};
                                do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_16 = q{};

my $cmd_19 = 'timeout';
my ($in_18, $out_18);
my $pid_18 = open3($in_18, $out_18, '>&STDERR', $cmd_19, '--kill-after=5', 'bash', '-c');
print {$in_18} $output_15;
close $in_18 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_16 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_18> };
close $out_18 or croak 'Close failed: $OS_ERROR';
waitpid $pid_18, 0;
$tmp_redirect_16;
                };
                $output_15 = $output;

                                use Carp qw(carp croak);
                if ( open my $fh, '>>', "$LOG_FILE" ) {
                print {$fh} $output_15;
                close $fh or croak "Close failed: $ERRNO";
                }
                else {
                carp "tee: Cannot open "$LOG_FILE": $ERRNO";
                }
                $output_15 = $output_15;
                if ($output_15 ne q{} && !defined $output_printed_15) {
                    print $output_15;
                    if (!($output_15 =~ m{\n\z})) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_15 ) { $main_exit_code = 1; }
                }
;
            my $exit_code = "PIPESTATUS[0]";
if (($exit_code == $MAGIC_124)) {
                # Original bash: echo "Command timed out after ${timeout_seconds}s" | tee -a "$LOG_FILE"
do {
                    my $output_20 = q{};
                    my $output_printed_20;
                    my $pipeline_success_20 = 1;
                    $output_20 .= "Command timed out after " . ${timeout_seconds} . "s\n";
if ( !($output_20 =~ m{\n\z}) ) { $output_20 .= "\n"; }

                                        use Carp qw(carp croak);
                    if ( open my $fh, '>>', "$LOG_FILE" ) {
                    print {$fh} $output_20;
                    close $fh or croak "Close failed: $ERRNO";
                    }
                    else {
                    carp "tee: Cannot open "$LOG_FILE": $ERRNO";
                    }
                    $output_20 = $output_20;
                    if ($output_20 ne q{} && !defined $output_printed_20) {
                        print $output_20;
                        if (!($output_20 =~ m{\n\z})) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_20 ) { $main_exit_code = 1; }
                    }
;
            }
}
        else {
            if (my $pid = fork()) {
                # Parent process continues
            } elsif (defined $pid) {
                # Child process executes the background command
                # Original bash: bash -c "$cmd" 2>&1 | tee -a "$LOG_FILE" &
do {
                    my $output_21 = q{};
                    my $output_printed_21;
                    my $pipeline_success_21 = 1;
                                        $output = q{};
                                        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_22 = q{};

my $cmd_25 = 'bash';
my ($in_24, $out_24);
my $pid_24 = open3($in_24, $out_24, '>&STDERR', $cmd_25, '-c');
print {$in_24} $output_21;
close $in_24 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_22 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_24> };
close $out_24 or croak 'Close failed: $OS_ERROR';
waitpid $pid_24, 0;
$tmp_redirect_22;
                    };
                    $output_21 = $output;

                                        use Carp qw(carp croak);
                    if ( open my $fh, '>>', "$LOG_FILE" ) {
                    print {$fh} $output_21;
                    close $fh or croak "Close failed: $ERRNO";
                    }
                    else {
                    carp "tee: Cannot open "$LOG_FILE": $ERRNO";
                    }
                    $output_21 = $output_21;
                    if ($output_21 ne q{} && !defined $output_printed_21) {
                        print $output_21;
                        if (!($output_21 =~ m{\n\z})) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_21 ) { $main_exit_code = 1; }
                    }
                exit(0);
            } else {
                die "Cannot fork: $ERRNO\n";
            }
            my $cmd_pid = $!;
            if (my $pid = fork()) {
                # Parent process continues
            } elsif (defined $pid) {
                # Child process executes the background command
                exec 'bash', '-c', q{(sleep "$timeout_seconds"; : 'Complex command not supported in bash string generation')};
                croak "exec failed: $OS_ERROR\n";
            } else {
                die "Cannot fork: $ERRNO\n";
            }
            my $timeout_pid = $!;
1 while wait() > -1;
$CHILD_ERROR = $? == -1 ? 0 : $? >> 8;
            my $exit_code = $?;
            do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
my $signal = 'TERM';
my @pids = ("$timeout_pid");
foreach my $pid (@pids) {
if ($pid =~ /^\\d+$/msx) {
my $result = kill $signal, $pid;
if ($result) {
print "Sent signal $signal to process $pid\n";
} else {
print {*STDERR} "kill: ($pid) - No such process\n";
}
} else {
print {*STDERR} "kill: invalid process id: $pid\n";
}
}
            };
        }
    }
    # Original bash: echo "----------------------------------------" | tee -a "$LOG_FILE"
do {
        my $output_27 = q{};
        my $output_printed_27;
        my $pipeline_success_27 = 1;
        $output_27 .= '----------------------------------------' . "\n";
if ( !($output_27 =~ m{\n\z}) ) { $output_27 .= "\n"; }

                use Carp qw(carp croak);
        if ( open my $fh, '>>', "$LOG_FILE" ) {
        print {$fh} $output_27;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open "$LOG_FILE": $ERRNO";
        }
        $output_27 = $output_27;
        if ($output_27 ne q{} && !defined $output_printed_27) {
            print $output_27;
            if (!($output_27 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_27 ) { $main_exit_code = 1; }
        }
;
    # Original bash: echo "Command completed with exit code: $exit_code" | tee -a "$LOG_FILE"
do {
        my $output_28 = q{};
        my $output_printed_28;
        my $pipeline_success_28 = 1;
        $output_28 .= "Command completed with exit code: $exit_code\n";
if ( !($output_28 =~ m{\n\z}) ) { $output_28 .= "\n"; }

                use Carp qw(carp croak);
        if ( open my $fh, '>>', "$LOG_FILE" ) {
        print {$fh} $output_28;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open "$LOG_FILE": $ERRNO";
        }
        $output_28 = $output_28;
        if ($output_28 ne q{} && !defined $output_printed_28) {
            print $output_28;
            if (!($output_28 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_28 ) { $main_exit_code = 1; }
        }
;
    # Original bash: echo "----------------------------------------" | tee -a "$LOG_FILE"
do {
        my $output_29 = q{};
        my $output_printed_29;
        my $pipeline_success_29 = 1;
        $output_29 .= '----------------------------------------' . "\n";
if ( !($output_29 =~ m{\n\z}) ) { $output_29 .= "\n"; }

                use Carp qw(carp croak);
        if ( open my $fh, '>>', "$LOG_FILE" ) {
        print {$fh} $output_29;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open "$LOG_FILE": $ERRNO";
        }
        $output_29 = $output_29;
        if ($output_29 ne q{} && !defined $output_printed_29) {
            print $output_29;
            if (!($output_29 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_29 ) { $main_exit_code = 1; }
        }
;
return $exit_code;
    return;
}
# Original bash: echo "Compiling debashc..." | tee -a "$LOG_FILE"
do {
    my $output_30 = q{};
    my $output_printed_30;
    my $pipeline_success_30 = 1;
    $output_30 .= 'Compiling debashc...' . "\n";
if ( !($output_30 =~ m{\n\z}) ) { $output_30 .= "\n"; }

        use Carp qw(carp croak);
    if ( open my $fh, '>>', "$LOG_FILE" ) {
    print {$fh} $output_30;
    close $fh or croak "Close failed: $ERRNO";
    }
    else {
    carp "tee: Cannot open "$LOG_FILE": $ERRNO";
    }
    $output_30 = $output_30;
    if ($output_30 ne q{} && !defined $output_printed_30) {
        print $output_30;
        if (!($output_30 =~ m{\n\z})) {
            print "\n";
        }
    }
    if ( !$pipeline_success_30 ) { $main_exit_code = 1; }
    }
if (# Original bash: cargo build --bin debashc 2>&1 | tee -a "$LOG_FILE";
do {
    my $output_31 = q{};
    my $output_printed_31;
    my $pipeline_success_31 = 1;
        $output = q{};
        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_32 = q{};

my $cmd_35 = 'cargo';
my ($in_34, $out_34);
my $pid_34 = open3($in_34, $out_34, '>&STDERR', $cmd_35, 'build', '--bin', 'debashc');
print {$in_34} $output_31;
close $in_34 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_32 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_34> };
close $out_34 or croak 'Close failed: $OS_ERROR';
waitpid $pid_34, 0;
$tmp_redirect_32;
    };
    $output_31 = $output;

        use Carp qw(carp croak);
    if ( open my $fh, '>>', "$LOG_FILE" ) {
    print {$fh} $output_31;
    close $fh or croak "Close failed: $ERRNO";
    }
    else {
    carp "tee: Cannot open "$LOG_FILE": $ERRNO";
    }
    $output_31 = $output_31;
    if ($output_31 ne q{} && !defined $output_printed_31) {
        print $output_31;
        if (!($output_31 =~ m{\n\z})) {
            print "\n";
        }
    }
    if ( !$pipeline_success_31 ) { $main_exit_code = 1; }
    }) {
    # Original bash: echo "Compilation failed, aborting other commands" | tee -a "$LOG_FILE"
do {
        my $output_36 = q{};
        my $output_printed_36;
        my $pipeline_success_36 = 1;
        $output_36 .= 'Compilation failed, aborting other commands' . "\n";
if ( !($output_36 =~ m{\n\z}) ) { $output_36 .= "\n"; }

                use Carp qw(carp croak);
        if ( open my $fh, '>>', "$LOG_FILE" ) {
        print {$fh} $output_36;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open "$LOG_FILE": $ERRNO";
        }
        $output_36 = $output_36;
        if ($output_36 ne q{} && !defined $output_printed_36) {
            print $output_36;
            if (!($output_36 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_36 ) { $main_exit_code = 1; }
        }
;
exit 1;
}
# Original bash: echo "Running debashc with fine-grained per-test timeouts..." | tee -a "$LOG_FILE"
do {
    my $output_37 = q{};
    my $output_printed_37;
    my $pipeline_success_37 = 1;
    $output_37 .= 'Running debashc with fine-grained per-test timeouts...' . "\n";
if ( !($output_37 =~ m{\n\z}) ) { $output_37 .= "\n"; }

        use Carp qw(carp croak);
    if ( open my $fh, '>>', "$LOG_FILE" ) {
    print {$fh} $output_37;
    close $fh or croak "Close failed: $ERRNO";
    }
    else {
    carp "tee: Cannot open "$LOG_FILE": $ERRNO";
    }
    $output_37 = $output_37;
    if ($output_37 ne q{} && !defined $output_printed_37) {
        print $output_37;
        if (!($output_37 =~ m{\n\z})) {
            print "\n";
        }
    }
    if ( !$pipeline_success_37 ) { $main_exit_code = 1; }
    }
if ((scalar(@ARGV) == 0)) {
    # Original bash: echo "Running: debashc test generation and execution" | tee -a "$LOG_FILE"
do {
        my $output_38 = q{};
        my $output_printed_38;
        my $pipeline_success_38 = 1;
        $output_38 .= 'Running: debashc test generation and execution' . "\n";
if ( !($output_38 =~ m{\n\z}) ) { $output_38 .= "\n"; }

                use Carp qw(carp croak);
        if ( open my $fh, '>>', "$LOG_FILE" ) {
        print {$fh} $output_38;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open "$LOG_FILE": $ERRNO";
        }
        $output_38 = $output_38;
        if ($output_38 ne q{} && !defined $output_printed_38) {
            print $output_38;
            if (!($output_38 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_38 ) { $main_exit_code = 1; }
        }
;
    # Original bash: echo "Command: ./target/debug/debashc.exe fail --perl-critic" | tee -a "$LOG_FILE"
do {
        my $output_39 = q{};
        my $output_printed_39;
        my $pipeline_success_39 = 1;
        $output_39 .= 'Command: ./target/debug/debashc.exe fail --perl-critic' . "\n";
if ( !($output_39 =~ m{\n\z}) ) { $output_39 .= "\n"; }

                use Carp qw(carp croak);
        if ( open my $fh, '>>', "$LOG_FILE" ) {
        print {$fh} $output_39;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open "$LOG_FILE": $ERRNO";
        }
        $output_39 = $output_39;
        if ($output_39 ne q{} && !defined $output_printed_39) {
            print $output_39;
            if (!($output_39 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_39 ) { $main_exit_code = 1; }
        }
;
    # Original bash: echo "Timeout: Per-test timeouts (30s shell, 10s parse, 5s generate)" | tee -a "$LOG_FILE"
do {
        my $output_40 = q{};
        my $output_printed_40;
        my $pipeline_success_40 = 1;
        $output_40 .= 'Timeout: Per-test timeouts (30s shell, 10s parse, 5s generate)' . "\n";
if ( !($output_40 =~ m{\n\z}) ) { $output_40 .= "\n"; }

                use Carp qw(carp croak);
        if ( open my $fh, '>>', "$LOG_FILE" ) {
        print {$fh} $output_40;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open "$LOG_FILE": $ERRNO";
        }
        $output_40 = $output_40;
        if ($output_40 ne q{} && !defined $output_printed_40) {
            print $output_40;
            if (!($output_40 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_40 ) { $main_exit_code = 1; }
        }
;
    # Original bash: echo "----------------------------------------" | tee -a "$LOG_FILE"
do {
        my $output_41 = q{};
        my $output_printed_41;
        my $pipeline_success_41 = 1;
        $output_41 .= '----------------------------------------' . "\n";
if ( !($output_41 =~ m{\n\z}) ) { $output_41 .= "\n"; }

                use Carp qw(carp croak);
        if ( open my $fh, '>>', "$LOG_FILE" ) {
        print {$fh} $output_41;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open "$LOG_FILE": $ERRNO";
        }
        $output_41 = $output_41;
        if ($output_41 ne q{} && !defined $output_printed_41) {
            print $output_41;
            if (!($output_41 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_41 ) { $main_exit_code = 1; }
        }
;
if (    # Original bash: ./target/debug/debashc fail --perl-critic 2>&1 | tee -a "$LOG_FILE"
do {
        my $output_42 = q{};
        my $output_printed_42;
        my $pipeline_success_42 = 1;
                $output = q{};
                do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_43 = q{};

my $cmd_46 = './target/debug/debashc';
my ($in_45, $out_45);
my $pid_45 = open3($in_45, $out_45, '>&STDERR', $cmd_46, 'fail', '--perl-critic');
print {$in_45} $output_42;
close $in_45 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_43 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_45> };
close $out_45 or croak 'Close failed: $OS_ERROR';
waitpid $pid_45, 0;
$tmp_redirect_43;
        };
        $output_42 = $output;

                use Carp qw(carp croak);
        if ( open my $fh, '>>', "$LOG_FILE" ) {
        print {$fh} $output_42;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open "$LOG_FILE": $ERRNO";
        }
        $output_42 = $output_42;
        if ($output_42 ne q{} && !defined $output_printed_42) {
            print $output_42;
            if (!($output_42 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_42 ) { $main_exit_code = 1; }
        }) {
        # Original bash: echo "debashc tests failed (exit code $?)" | tee -a "$LOG_FILE"
do {
            my $output_47 = q{};
            my $output_printed_47;
            my $pipeline_success_47 = 1;
            $output_47 .= "debashc tests failed (exit code ${\($? >> 8)})\n";
if ( !($output_47 =~ m{\n\z}) ) { $output_47 .= "\n"; }

                        use Carp qw(carp croak);
            if ( open my $fh, '>>', "$LOG_FILE" ) {
            print {$fh} $output_47;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open "$LOG_FILE": $ERRNO";
            }
            $output_47 = $output_47;
            if ($output_47 ne q{} && !defined $output_printed_47) {
                print $output_47;
                if (!($output_47 =~ m{\n\z})) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_47 ) { $main_exit_code = 1; }
            }
;
        $DEBASHC_FAILED = q{1};
    }
}
else {
    # Original bash: echo "Running: debashc test generation and execution" | tee -a "$LOG_FILE"
do {
        my $output_48 = q{};
        my $output_printed_48;
        my $pipeline_success_48 = 1;
        $output_48 .= 'Running: debashc test generation and execution' . "\n";
if ( !($output_48 =~ m{\n\z}) ) { $output_48 .= "\n"; }

                use Carp qw(carp croak);
        if ( open my $fh, '>>', "$LOG_FILE" ) {
        print {$fh} $output_48;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open "$LOG_FILE": $ERRNO";
        }
        $output_48 = $output_48;
        if ($output_48 ne q{} && !defined $output_printed_48) {
            print $output_48;
            if (!($output_48 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_48 ) { $main_exit_code = 1; }
        }
;
    # Original bash: echo "Command: ./target/debug/debashc.exe fail --perl-critic \"$@\"" | tee -a "$LOG_FILE"
do {
        my $output_49 = q{};
        my $output_printed_49;
        my $pipeline_success_49 = 1;
        $output_49 .= "Command: ./target/debug/debashc.exe fail --perl-critic \"\\@ARGV\"\n";
if ( !($output_49 =~ m{\n\z}) ) { $output_49 .= "\n"; }

                use Carp qw(carp croak);
        if ( open my $fh, '>>', "$LOG_FILE" ) {
        print {$fh} $output_49;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open "$LOG_FILE": $ERRNO";
        }
        $output_49 = $output_49;
        if ($output_49 ne q{} && !defined $output_printed_49) {
            print $output_49;
            if (!($output_49 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_49 ) { $main_exit_code = 1; }
        }
;
    # Original bash: echo "Timeout: Per-test timeouts (30s shell, 10s parse, 5s generate)" | tee -a "$LOG_FILE"
do {
        my $output_50 = q{};
        my $output_printed_50;
        my $pipeline_success_50 = 1;
        $output_50 .= 'Timeout: Per-test timeouts (30s shell, 10s parse, 5s generate)' . "\n";
if ( !($output_50 =~ m{\n\z}) ) { $output_50 .= "\n"; }

                use Carp qw(carp croak);
        if ( open my $fh, '>>', "$LOG_FILE" ) {
        print {$fh} $output_50;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open "$LOG_FILE": $ERRNO";
        }
        $output_50 = $output_50;
        if ($output_50 ne q{} && !defined $output_printed_50) {
            print $output_50;
            if (!($output_50 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_50 ) { $main_exit_code = 1; }
        }
;
    # Original bash: echo "----------------------------------------" | tee -a "$LOG_FILE"
do {
        my $output_51 = q{};
        my $output_printed_51;
        my $pipeline_success_51 = 1;
        $output_51 .= '----------------------------------------' . "\n";
if ( !($output_51 =~ m{\n\z}) ) { $output_51 .= "\n"; }

                use Carp qw(carp croak);
        if ( open my $fh, '>>', "$LOG_FILE" ) {
        print {$fh} $output_51;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open "$LOG_FILE": $ERRNO";
        }
        $output_51 = $output_51;
        if ($output_51 ne q{} && !defined $output_printed_51) {
            print $output_51;
            if (!($output_51 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_51 ) { $main_exit_code = 1; }
        }
;
if (    # Original bash: ./target/debug/debashc fail --perl-critic "$@" 2>&1 | tee -a "$LOG_FILE"
do {
        my $output_52 = q{};
        my $output_printed_52;
        my $pipeline_success_52 = 1;
                $output = q{};
                do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_53 = q{};

my $cmd_56 = './target/debug/debashc';
my ($in_55, $out_55);
my $pid_55 = open3($in_55, $out_55, '>&STDERR', $cmd_56, 'fail', '--perl-critic');
print {$in_55} $output_52;
close $in_55 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_53 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_55> };
close $out_55 or croak 'Close failed: $OS_ERROR';
waitpid $pid_55, 0;
$tmp_redirect_53;
        };
        $output_52 = $output;

                use Carp qw(carp croak);
        if ( open my $fh, '>>', "$LOG_FILE" ) {
        print {$fh} $output_52;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open "$LOG_FILE": $ERRNO";
        }
        $output_52 = $output_52;
        if ($output_52 ne q{} && !defined $output_printed_52) {
            print $output_52;
            if (!($output_52 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_52 ) { $main_exit_code = 1; }
        }) {
        # Original bash: echo "debashc tests failed (exit code $?)" | tee -a "$LOG_FILE"
do {
            my $output_57 = q{};
            my $output_printed_57;
            my $pipeline_success_57 = 1;
            $output_57 .= "debashc tests failed (exit code ${\($? >> 8)})\n";
if ( !($output_57 =~ m{\n\z}) ) { $output_57 .= "\n"; }

                        use Carp qw(carp croak);
            if ( open my $fh, '>>', "$LOG_FILE" ) {
            print {$fh} $output_57;
            close $fh or croak "Close failed: $ERRNO";
            }
            else {
            carp "tee: Cannot open "$LOG_FILE": $ERRNO";
            }
            $output_57 = $output_57;
            if ($output_57 ne q{} && !defined $output_printed_57) {
                print $output_57;
                if (!($output_57 =~ m{\n\z})) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_57 ) { $main_exit_code = 1; }
            }
;
        $DEBASHC_FAILED = q{1};
    }
}
# Original bash: echo "Running qx{}/system() check on generated Perl..." | tee -a "$LOG_FILE"
do {
    my $output_58 = q{};
    my $output_printed_58;
    my $pipeline_success_58 = 1;
    $output_58 .= "Running qx{}/" . "sys" . "tem" . "() check on generated Perl...\n";
if ( !($output_58 =~ m{\n\z}) ) { $output_58 .= "\n"; }

        use Carp qw(carp croak);
    if ( open my $fh, '>>', "$LOG_FILE" ) {
    print {$fh} $output_58;
    close $fh or croak "Close failed: $ERRNO";
    }
    else {
    carp "tee: Cannot open "$LOG_FILE": $ERRNO";
    }
    $output_58 = $output_58;
    if ($output_58 ne q{} && !defined $output_printed_58) {
        print $output_58;
        if (!($output_58 =~ m{\n\z})) {
            print "\n";
        }
    }
    if ( !$pipeline_success_58 ) { $main_exit_code = 1; }
    }
# Original bash: perl "$(dirname "$(readlink -f "$0" || echo "$0")")/check_qx.pl" 2>&1 | tee -a "$LOG_FILE"
do {
    my $output_59 = q{};
    my $output_printed_59;
    my $pipeline_success_59 = 1;
        $output = q{};
        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_60 = q{};
my $perl_output_62 = do {
                my $result = qx{perl "\"\$(dirname \"\$(: \"Complex command cannot be converted to shell command\")\")/check_qx.pl\""};
                chomp $result;
                $result;
            };
print $perl_output_62;
$tmp_redirect_60;
    };
    $output_59 = $output;

        use Carp qw(carp croak);
    if ( open my $fh, '>>', "$LOG_FILE" ) {
    print {$fh} $output_59;
    close $fh or croak "Close failed: $ERRNO";
    }
    else {
    carp "tee: Cannot open "$LOG_FILE": $ERRNO";
    }
    $output_59 = $output_59;
    if ($output_59 ne q{} && !defined $output_printed_59) {
        print $output_59;
        if (!($output_59 =~ m{\n\z})) {
            print "\n";
        }
    }
    if ( !$pipeline_success_59 ) { $main_exit_code = 1; }
    }
$QX_EXIT = $PIPESTATUS[0];
if (($QX_EXIT > 0)) {
    # Original bash: echo "FAILED: $QX_EXIT qx{}/system() violation(s) found in generated Perl" | tee -a "$LOG_FILE"
do {
        my $output_63 = q{};
        my $output_printed_63;
        my $pipeline_success_63 = 1;
        $output_63 .= "FAILED: $QX_EXIT qx{}/" . "sys" . "tem" . "() violation(s) found in generated Perl\n";
if ( !($output_63 =~ m{\n\z}) ) { $output_63 .= "\n"; }

                use Carp qw(carp croak);
        if ( open my $fh, '>>', "$LOG_FILE" ) {
        print {$fh} $output_63;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open "$LOG_FILE": $ERRNO";
        }
        $output_63 = $output_63;
        if ($output_63 ne q{} && !defined $output_printed_63) {
            print $output_63;
            if (!($output_63 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_63 ) { $main_exit_code = 1; }
        }
;
}
if ("$DEBASHC_FAILED" eq 1) {
    # Original bash: echo "debashc test suite had failures." | tee -a "$LOG_FILE"
do {
        my $output_64 = q{};
        my $output_printed_64;
        my $pipeline_success_64 = 1;
        $output_64 .= 'debashc test suite had failures.' . "\n";
if ( !($output_64 =~ m{\n\z}) ) { $output_64 .= "\n"; }

                use Carp qw(carp croak);
        if ( open my $fh, '>>', "$LOG_FILE" ) {
        print {$fh} $output_64;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open "$LOG_FILE": $ERRNO";
        }
        $output_64 = $output_64;
        if ($output_64 ne q{} && !defined $output_printed_64) {
            print $output_64;
            if (!($output_64 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_64 ) { $main_exit_code = 1; }
        }
;
}
if (($QX_EXIT > 0)) {

}
else {
    if ("$DEBASHC_FAILED" eq 1) {
exit 1;
    }
}
if ((-f "first_n_tests_passed.txt")) {
if ((!-f "first_n_tests_passed.MAX.txt")) {
        use File::Copy qw(copy);
        if ( -e 'first_n_tests_passed.txt' ) {
            if ( -d 'first_n_tests_passed.MAX.txt' ) {
                require File::Copy; File::Copy::copy('first_n_tests_passed.txt', 'first_n_tests_passed.MAX.txt' . '/' . ('first_n_tests_passed.txt' =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy('first_n_tests_passed.txt', 'first_n_tests_passed.MAX.txt');
            }
        } else {
            croak "cp: cannot stat 'first_n_tests_passed.txt': No such file or directory\n";
        }
;
        say "Created MAX file from current result (first run)";
}
    else {
        $current_score = do { local $CHILD_ERROR = 0; do {
    do { do {
            my $output_66 = q{};
            my $output_printed_66;
            my $pipeline_success_66 = 1;
            $output_66 = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'first_n_tests_passed.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'first_n_tests_passed.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
            if ($CHILD_ERROR != 0) { $pipeline_success_66 = 0; }
            my @sed_lines_66 = split /\n/, $output_66;
            my @sed_result_66;
            foreach my $line (@sed_lines_66) {
            chomp $line;
            $line =~ s/.*:y\([0-9]*\)/\1/gmsx;
            push @sed_result_66, $line;
            }
            $output_66 = join "\n", @sed_result_66;

            my @sed_lines_66 = split /\n/, $output_66;
            my @sed_result_66;
            foreach my $line (@sed_lines_66) {
            chomp $line;
            $line =~ s/.*:n\([0-9]*\)/\1/gmsx;
            push @sed_result_66, $line;
            }
            $output_66 = join "\n", @sed_result_66;

            my $num_lines       = 1;
            my $head_line_count = 0;
            my $result          = q{};
            my $input           = $output_66;
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
            $output_66 = $result;

            if ( !$pipeline_success_66 ) { $main_exit_code = 1; }
            $output_66 =~ s/\n+\z//msx;
            $output_66;
}; };
}; };
        $max_score = do { local $CHILD_ERROR = 0; do {
    do { do {
            my $output_67 = q{};
            my $output_printed_67;
            my $pipeline_success_67 = 1;
            $output_67 = do { my $cat_chunk = q{}; if ( open my $fh, '<', 'first_n_tests_passed.MAX.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'first_n_tests_passed.MAX.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
            if ($CHILD_ERROR != 0) { $pipeline_success_67 = 0; }
            my @sed_lines_67 = split /\n/, $output_67;
            my @sed_result_67;
            foreach my $line (@sed_lines_67) {
            chomp $line;
            $line =~ s/.*:y\([0-9]*\)/\1/gmsx;
            push @sed_result_67, $line;
            }
            $output_67 = join "\n", @sed_result_67;

            my @sed_lines_67 = split /\n/, $output_67;
            my @sed_result_67;
            foreach my $line (@sed_lines_67) {
            chomp $line;
            $line =~ s/.*:n\([0-9]*\)/\1/gmsx;
            push @sed_result_67, $line;
            }
            $output_67 = join "\n", @sed_result_67;

            my $num_lines       = 1;
            my $head_line_count = 0;
            my $result          = q{};
            my $input           = $output_67;
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
            $output_67 = $result;

            if ( !$pipeline_success_67 ) { $main_exit_code = 1; }
            $output_67 =~ s/\n+\z//msx;
            $output_67;
}; };
}; };
if (($current_score > $max_score)) {
            say "Progress detected! New high score: $current_score (was $max_score)";
            say "Committing changes...";
            $main_exit_code = system('git', 'commit', q{.}, '-m', "Reached " . (do { my $cat_chunk = q{}; if ( open my $fh, '<', 'first_n_tests_passed.txt' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . 'first_n_tests_passed.txt' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; })) >> 8;
            use File::Copy qw(copy);
            if ( -e 'first_n_tests_passed.txt' ) {
                if ( -d 'first_n_tests_passed.MAX.txt' ) {
                    require File::Copy; File::Copy::copy('first_n_tests_passed.txt', 'first_n_tests_passed.MAX.txt' . '/' . ('first_n_tests_passed.txt' =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy('first_n_tests_passed.txt', 'first_n_tests_passed.MAX.txt');
                }
            } else {
                croak "cp: cannot stat 'first_n_tests_passed.txt': No such file or directory\n";
            }
;
            say "Committed and updated MAX file";
}
        else {
            say "No progress detected (current: $current_score, max: $max_score), skipping commit";
        }
    }
}
else {
    say "No first_n_tests_passed.txt file found";
}
# Original bash: echo "Test run completed at $(date)" | tee -a "$LOG_FILE"
do {
    my $output_69 = q{};
    my $output_printed_69;
    my $pipeline_success_69 = 1;
    $output_69 .= "Test run completed at " . (do {
require POSIX; POSIX::strftime('%a %b %e %H:%M:%S %Z %Y', localtime())
}) . "\n";
if ( !($output_69 =~ m{\n\z}) ) { $output_69 .= "\n"; }

        use Carp qw(carp croak);
    if ( open my $fh, '>>', "$LOG_FILE" ) {
    print {$fh} $output_69;
    close $fh or croak "Close failed: $ERRNO";
    }
    else {
    carp "tee: Cannot open "$LOG_FILE": $ERRNO";
    }
    $output_69 = $output_69;
    if ($output_69 ne q{} && !defined $output_printed_69) {
        print $output_69;
        if (!($output_69 =~ m{\n\z})) {
            print "\n";
        }
    }
    if ( !$pipeline_success_69 ) { $main_exit_code = 1; }
    }
say "Log file saved to: $LOG_FILE";

exit $main_exit_code;
