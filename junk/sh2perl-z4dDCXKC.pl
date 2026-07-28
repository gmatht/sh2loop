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

my $MAGIC_5       = 5;
my $MAGIC_4       = 4;
my $MAGIC_4080000 = 4_080_000;
my $MAGIC_644     = 644;
my $MAGIC_1000    = 1_000;
my $MAGIC_6       = 6;
my $MAGIC_15      = 15;
my $MAGIC_10      = 10;
my $MAGIC_711     = 711;


sub Main {
$ENV{PATH} = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin';
if ((-t 1)) {
        my $ncolors;
        my @ncolors;
        my %ncolors;
        $ncolors = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'tput', 'colors');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
if ((!(        $main_exit_code = system('test', '-n', "$ncolors") >> 8) && !(        $main_exit_code = system('test', $ncolors, '-ge', q{8}) >> 8))) {
            my $BOLD;
            my @BOLD;
            my %BOLD;
            $BOLD = (do { my $_chomp_temp = do {
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'tput', 'bold');
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    $result_1
}; chomp $_chomp_temp; $_chomp_temp; });
            my $NC;
            my @NC;
            my %NC;
            $NC = "\\033[0m";
            my $LGREEN;
            my @LGREEN;
            my %LGREEN;
            $LGREEN = "\\033[1;32m";
            my $LRED;
            my @LRED;
            my %LRED;
            $LRED = "\\e[0;91m";
        }
    }
    if ((scalar(@ARGV) == 0)) {
                do {
            local %ENV = %ENV;
            my $BOLD = $BOLD;
            my $NC = $NC;
            my $ncolors = $ncolors;
            my $LGREEN = $LGREEN;
            my $LRED = $LRED;
                $main_exit_code = system('bash', 'DisplayUsage') >> 8;
exit 0;
            q{};
        };
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    $main_exit_code = system('ParseOptions', "@ARGV") >> 8;
exit 0;
    $main_exit_code = system('bash', 'PreRequisits') >> 8;
if ((-f '/etc/orangepimonitor/start-monitoring')) {
        my $OrangePiMonitoring;
        my @OrangePiMonitoring;
        my %OrangePiMonitoring;
        $OrangePiMonitoring = 'TRUE';
        do {
open STDIN, '<', '/etc/orangepimonitor/start-monitoring' or croak "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
$DebugMode = <>;
chomp $DebugMode;
$CHILD_ERROR = defined($DebugMode) ? 0 : 1;
        };
    }
    $main_exit_code = system('bash', ':') >> 8;
    $main_exit_code = system('bash', 'CheckDisks') >> 8;
    return;
}

sub ParseOptions {
    my ($file) = @_;
while (     $main_exit_code = system('getopts', 'hHbBuUrRmMsnNd:Dc:C:pPvz', q{c}) >> 8 ) {
if ($c =~ /^H$/msx) {
                        $main_exit_code = system('bash', 'DisplayUsage') >> 8;
            exit 0;
        } elsif ($c =~ /^h$/msx) {
                        $main_exit_code = system('bash', 'DisplayUsage') >> 8;
            exit 0;
        } elsif ($c =~ /^m$/msx or $c =~ /^M$/msx or $c =~ /^s$/msx) {
                        my $interval;
            my @interval;
            my %interval;
            $interval = $2;
                        $main_exit_code = system('MonitorMode', $OPTARG) >> 8;
            exit 0;
        } elsif ($c =~ /^n$/msx or $c =~ /^N$/msx) {
                        my $rf1;
            my @rf1;
            my %rf1;
            $rf1 = $2;
                        $main_exit_code = system('NetworkMonitorMode', $OPTARG) >> 8;
            exit 0;
        } elsif ($c =~ /^u$/msx) {
                        # Original bash: fping ix.io 2>/dev/null | grep -q alive
{
                my $output_3 = q{};
                my $output_printed_3;
                my $pipeline_success_3 = 1;
                                $output = q{};
                                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_4 = q{};

my $cmd_7 = 'fping';
my ($in_6, $out_6);
my $pid_6 = open3($in_6, $out_6, '>&STDERR', $cmd_7, 'ix.io');
print {$in_6} $output_3;
close $in_6 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> };
close $out_6 or croak 'Close failed: $OS_ERROR';
waitpid $pid_6, 0;
$tmp_redirect_4;
                };
                $output_3 = $output;

                                my $grep_result_3_1;
                my @grep_lines_3_1 = split /\n/msx, $output_3;
                my @grep_filtered_3_1 = grep { /alive/msx } @grep_lines_3_1;
                $grep_result_3_1 = join "\n", @grep_filtered_3_1;
                if (!($grep_result_3_1 =~ m{\n\z}msx || $grep_result_3_1 eq q{})) {
                $grep_result_3_1 .= "\n";
                }
                $CHILD_ERROR = scalar @grep_filtered_3_1 > 0 ? 0 : 1;
                $grep_result_3_1 = q{};
                $output_3 = q{};
                if ((scalar @grep_filtered_3_1) == 0) {
                    $pipeline_success_3 = 0;
                }
                if ($output_3 ne q{} && !defined $output_printed_3) {
                    print $output_3;
                    if (!($output_3 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
                }
            if ($? ne 0) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    do {
    my $__echo_line = "\nNetwork/firewall problem detected. Not able to upload debug info.\nPlease fix this or use \"-U\" instead and upload ($ENV{BOLD} // q{})whole output($ENV{NC} // q{}) manually\n";
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
            }
                                    do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $_wa0 = 'curl';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            if ($CHILD_ERROR != 0) {
                                $main_exit_code = system('apt-get', '-f', '-qq', '-y', 'install', 'curl') >> 8;
            }
                        print "\nSystem diagnosis information has been collected at the following URL: \n" . "\n";
            $CHILD_ERROR = 0;
                        # Original bash: CollectSupportInfo \
{
                my $output_9 = q{};
                my $output_printed_9;
                my $pipeline_success_9 = 1;
                                my ($in_10, $out_10);
                my $pid_10 = open3($in_10, $out_10, '>&STDERR', 'CollectSupportInfo', );
                close $in_10 or croak 'Close failed: $OS_ERROR';
                $output_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_10> };
                close $out_10 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_10, 0;

                                my @sed_lines_9 = split /\n/msx, $output_9;
                my @sed_result_9;
                foreach my $line (@sed_lines_9) {
                chomp $line;
                push @sed_result_9, $line;
                }
                $output_9 = join "\n", @sed_result_9;

                                use LWP::UserAgent;
                use HTTP::Request;
                use HTTP::Headers;
                my $ua = LWP::UserAgent->new;
                my $request = HTTP::Request->new('GET', 'f:1=<-');
                my $response = $ua->request($request);
                if ($response->is_success) {
                print $response->content;
                } else {
                die "curl: HTTP error: $response->code $response->message\n";
                }
                if ($output_9 ne q{} && !defined $output_printed_9) {
                    print $output_9;
                    if (!($output_9 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_9 ) { $main_exit_code = 1; }
                }
                        print "\nPlease sent the URL to Orange Pi or post it in the forum where you've been asked for.\n" . "\n";
            $CHILD_ERROR = 0;
            exit 0;
        } elsif ($c =~ /^U$/msx) {
                        # Original bash: CollectSupportInfo \
{
                my $output_11 = q{};
                my $output_printed_11;
                my $pipeline_success_11 = 1;
                                my ($in_12, $out_12);
                my $pid_12 = open3($in_12, $out_12, '>&STDERR', 'CollectSupportInfo', );
                close $in_12 or croak 'Close failed: $OS_ERROR';
                $output_11 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_12> };
                close $out_12 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_12, 0;

                                my @sed_lines_11 = split /\n/msx, $output_11;
                my @sed_result_11;
                foreach my $line (@sed_lines_11) {
                chomp $line;
                push @sed_result_11, $line;
                }
                $output_11 = join "\n", @sed_result_11;

                                my @lines = split /\n/msx, $output_11;
                my @result;
                foreach my $line (@lines) {
                chomp $line;
                if ($line =~ /^\s*$/msx) { next; }
                my @fields = split /\s+/msx, $line;
                if (!(!scalar(@fields))) { next; }
                push @result, ($line . "\n");
                }
                $output_11 = join "", @result;

                                my $cmd_14 = 'nl';
                my ($in_13, $out_13);
                my $pid_13 = open3($in_13, $out_13, '>&STDERR', $cmd_14, q{-});
                print {$in_13} $output_11;
                close $in_13 or croak 'Close failed: $OS_ERROR';
                $output_11 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_13> };
                close $out_13 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_13, 0;
                if ($output_11 ne q{} && !defined $output_printed_11) {
                    print $output_11;
                    if (!($output_11 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_11 ) { $main_exit_code = 1; }
                }
                        do {
    my $__echo_line = "\nPlease upload the ($ENV{BOLD} // q{})whole output($ENV{NC} // q{}) above to an online pasteboard service\nand provide the URL in the forum where you have been asked for this.\n";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            exit 0;
        } elsif ($c =~ /^r$/msx or $c =~ /^R$/msx) {
                        {
                my $output_15 = q{};
                my $output_printed_15;
                my $pipeline_success_15 = 1;
                                $output = q{};
                                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_16 = q{};

my $cmd_19 = 'fping';
my ($in_18, $out_18);
my $pid_18 = open3($in_18, $out_18, '>&STDERR', $cmd_19, 'orangepi.com');
print {$in_18} $output_15;
close $in_18 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_16 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_18> };
close $out_18 or croak 'Close failed: $OS_ERROR';
waitpid $pid_18, 0;
$tmp_redirect_16;
                };
                $output_15 = $output;

                                my $grep_result_15_1;
                my @grep_lines_15_1 = split /\n/msx, $output_15;
                my @grep_filtered_15_1 = grep { /alive/msx } @grep_lines_15_1;
                $grep_result_15_1 = join "\n", @grep_filtered_15_1;
                if (!($grep_result_15_1 =~ m{\n\z}msx || $grep_result_15_1 eq q{})) {
                $grep_result_15_1 .= "\n";
                }
                $CHILD_ERROR = scalar @grep_filtered_15_1 > 0 ? 0 : 1;
                $grep_result_15_1 = q{};
                $output_15 = q{};
                if ((scalar @grep_filtered_15_1) == 0) {
                    $pipeline_success_15 = 0;
                }
                if ($output_15 ne q{} && !defined $output_printed_15) {
                    print $output_15;
                    if (!($output_15 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_15 ) { $main_exit_code = 1; }
                }
            if ($CHILD_ERROR != 0) {
                                do {
                    local %ENV = %ENV;
                    my $rf1 = $rf1;
                    my $interval = $interval;
                        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                            print "Network/firewall problem detected. Please fix this prior to installing RPi-Monitor.\n";
                        };
exit 1;
                    q{};
                };
            }
                        $main_exit_code = system('bash', 'InstallRPiMonitor') >> 8;
            if (do { my @_qx_cmd = ("awk '/Hardware/ {print $arg3$4}' < /proc/cpuinfo"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; } =~ /^.*sun8i.*$/msx) {
                                $main_exit_code = system('bash', 'PatchRPiMonitor_for_sun8i') >> 8;
                if (do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__rel; join(" ", @__parts) . "\n"; } =~ /^3.4..*$/msx) {
                    my @sed_lines_20 = split /\n/msx, $;
my @sed_result_20;
foreach my $line (@sed_lines_20) {
chomp $line;
push @sed_result_20, $line;
}
$ = join "\n", @sed_result_20;

                                        do {
                        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                        my $tmp = do {
                        $main_exit_code = system('systemctl', 'restart', 'rpimonitor') >> 8;
                        };
                        print $tmp;
                        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                    };
                } elsif (1) {
                    my @sed_lines_21 = split /\n/msx, $;
my @sed_result_21;
foreach my $line (@sed_lines_21) {
chomp $line;
push @sed_result_21, $line;
}
$ = join "\n", @sed_result_21;

                                        do {
                        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                        my $tmp = do {
                        $main_exit_code = system('systemctl', 'restart', 'rpimonitor') >> 8;
                        };
                        print $tmp;
                        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                    };
                }
            } elsif (1) {
                                $main_exit_code = system('.', '/etc/orangepi-release') >> 8;
                open STDIN, '<', '/etc/rpimonitor/template/raspbian.conf' or croak "Cannot open file: $OS_ERROR\n";
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', '/etc/rpimonitor/template/orangepi.conf'
      or die "Cannot open file: $OS_ERROR\n";
                    my $tmp = do {
my @sed_lines_22 = split /\n/msx, $;
my @sed_result_22;
foreach my $line (@sed_lines_22) {
chomp $line;
push @sed_result_22, $line;
}
$ = join "\n", @sed_result_22;

                    };
                    print $tmp;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
                                chdir('/etc/rpimonitor/');
                $CHILD_ERROR = 0;
                symlink q{f}, 'data.conf' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
                my @sed_lines_24 = split /\n/msx, $;
my @sed_result_24;
foreach my $line (@sed_lines_24) {
chomp $line;
push @sed_result_24, $line;
}
$ = join "\n", @sed_result_24;

                if ((qx'grep -c '^processor' /proc/cpuinfo' >= $MAGIC_4)) {
my @sed_lines_25 = split /\n/msx, $;
my @sed_result_25;
foreach my $line (@sed_lines_25) {
chomp $line;
push @sed_result_25, $line;
}
$ = join "\n", @sed_result_25;

                }
                my @sed_lines_26 = split /\n/msx, $;
my @sed_result_26;
foreach my $line (@sed_lines_26) {
chomp $line;
push @sed_result_26, $line;
}
$ = join "\n", @sed_result_26;

            }
                        do {
    my $__echo_line = "\nNow you're able to enjoy RPi-Monitor at http://do { local $CHILD_ERROR = 0; my $_pipeline_result = do {\n                my $output_27 = q{};\n                my $output_printed_27;\n                my $pipeline_success_27 = 1;\n\n                my ($in_28, $out_28);\n                my $pid_28 = open3($in_28, $out_28, '>&STDERR', 'ip', q{a});\n                close $in_28 or croak 'Close failed: $OS_ERROR';\n                $output_27 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_28> };\n                close $out_28 or croak 'Close failed: $OS_ERROR';\n                waitpid $pid_28, 0;\n                if ($CHILD_ERROR != 0) { $pipeline_success_27 = 0; }\n                my @lines = split /\\n/msx, $output_27;\n                my @result;\n                foreach my $line (@lines) {\n                    chomp $line;\n                    if ($line =~ /^\\s*$/msx) { next; }\n                    my @fields = split /\\ /msx, $line;\n                    if (!(/inet /)) { next; }\n                    push @result, ($fields[1] . \"\\n\");\n                }\n                $output_27 = join \"\", @result;\n\n                my $grep_result_27_2;\n                my @grep_lines_27_2 = split /\\n/msx, $output_27;\n                my @grep_filtered_27_2 = grep { !/127.0.0.1/msx } @grep_lines_27_2;\n                $grep_result_27_2 = join \"\\n\", @grep_filtered_27_2;\n                                if (!($grep_result_27_2 =~ m{\\n\\z}msx || $grep_result_27_2 eq q{})) {\n                                    $grep_result_27_2 .= \"\\n\";\n                                }\n                $CHILD_ERROR = scalar @grep_filtered_27_2 > 0 ? 0 : 1;\n                $output_27 = $grep_result_27_2;\n                my @lines_29 = split /\\n/msx, $output_27;\n                my @result_29;\n                foreach my $line (@lines_29) {\n                chomp $line;\n                my @fields = split /\\//msx, $line;\n                if (@fields > 0) {\n                    push @result_29, $fields[0];\n                }\n                }\n                $output_27 = join \"\\n\", @result_29;\n                if ($output_27 ne q{} && !($output_27  =~ m{\\n\\z}msx)) { $output_27 .= \"\\n\"; }\n\n                my $num_lines       = 1;\n                my $head_line_count = 0;\n                my $result          = q{};\n                my $input           = $output_27;\n                my $pos             = 0;\n\n                while ( $pos < length $input && $head_line_count < $num_lines ) {\n                    my $line_end = index $input, \"\\n\", $pos;\n                    if ( $line_end == -1 ) {\n                        $line_end = length $input;\n                    }\n                    my $head_line = substr $input, $pos, $line_end - $pos;\n                    $result .= $head_line . \"\\n\";\n                    $pos = $line_end + 1;\n                    ++$head_line_count;\n                }\n                $output_27 = $result;\n\n                if ( !$pipeline_success_27 ) { $main_exit_code = 1; }\n                $output_27 =~ s/\\n+\\z//msx;\n                $output_27;\n}; $_pipeline_result; }:8888";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            exit 0;
        } elsif ($c =~ /^p$/msx or $c =~ /^P$/msx) {
                        {
                my $output_30 = q{};
                my $output_printed_30;
                my $pipeline_success_30 = 1;
                                my ($in_31, $out_31);
                my $pid_31 = open3($in_31, $out_31, '>&STDERR', 'dpkg', '--print-architecture');
                close $in_31 or croak 'Close failed: $OS_ERROR';
                $output_30 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_31> };
                close $out_31 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_31, 0;

                                my $grep_result_30_1;
                my @grep_lines_30_1 = split /\n/msx, $output_30;
                my @grep_filtered_30_1 = grep { /armhf/msx } @grep_lines_30_1;
                $grep_result_30_1 = join "\n", @grep_filtered_30_1;
                if (!($grep_result_30_1 =~ m{\n\z}msx || $grep_result_30_1 eq q{})) {
                $grep_result_30_1 .= "\n";
                }
                $CHILD_ERROR = scalar @grep_filtered_30_1 > 0 ? 0 : 1;
                $grep_result_30_1 = q{};
                $output_30 = q{};
                if ((scalar @grep_filtered_30_1) == 0) {
                    $pipeline_success_30 = 0;
                }
                if ($output_30 ne q{} && !defined $output_printed_30) {
                    print $output_30;
                    if (!($output_30 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_30 ) { $main_exit_code = 1; }
                }
            if ($CHILD_ERROR != 0) {
                                do {
                    local %ENV = %ENV;
                    my $rf1 = $rf1;
                    my $interval = $interval;
                        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                            print "Functionality currently not supported on 64-bit platforms. Exiting\n" . "\n";
                            $CHILD_ERROR = 0;
                        };
exit 1;
                    q{};
                };
            }
                        {
                my $output_32 = q{};
                my $output_printed_32;
                my $pipeline_success_32 = 1;
                                $output = q{};
                                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_33 = q{};

my $cmd_36 = 'fping';
my ($in_35, $out_35);
my $pid_35 = open3($in_35, $out_35, '>&STDERR', $cmd_36, 'orangepi.com');
print {$in_35} $output_32;
close $in_35 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_33 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_35> };
close $out_35 or croak 'Close failed: $OS_ERROR';
waitpid $pid_35, 0;
$tmp_redirect_33;
                };
                $output_32 = $output;

                                my $grep_result_32_1;
                my @grep_lines_32_1 = split /\n/msx, $output_32;
                my @grep_filtered_32_1 = grep { /alive/msx } @grep_lines_32_1;
                $grep_result_32_1 = join "\n", @grep_filtered_32_1;
                if (!($grep_result_32_1 =~ m{\n\z}msx || $grep_result_32_1 eq q{})) {
                $grep_result_32_1 .= "\n";
                }
                $CHILD_ERROR = scalar @grep_filtered_32_1 > 0 ? 0 : 1;
                $grep_result_32_1 = q{};
                $output_32 = q{};
                if ((scalar @grep_filtered_32_1) == 0) {
                    $pipeline_success_32 = 0;
                }
                if ($output_32 ne q{} && !defined $output_printed_32) {
                    print $output_32;
                    if (!($output_32 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_32 ) { $main_exit_code = 1; }
                }
            if ($CHILD_ERROR != 0) {
                                do {
                    local %ENV = %ENV;
                    my $rf1 = $rf1;
                    my $interval = $interval;
                        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                            print "Network/firewall problem detected. Please fix this prior to installing cpuminer.\n";
                        };
exit 1;
                    q{};
                };
            }
                        chdir('/usr/local/src/');
            $CHILD_ERROR = 0;
            use LWP::Simple;
my $url = 'http://downloads.sourceforge.net/project/cpuminer/pooler-cpuminer-2.4.5.tar.gz';
my $content = get($url);
if (defined $content) {
print $content;
} else {
die "Failed to download $url\n";
}
                        if (do {
$main_exit_code = system('tar', 'xf', 'pooler-cpuminer-2.4.5.tar.gz') >> 8;
                $CHILD_ERROR == 0
            }) {
                if ( -e "pooler-cpuminer-2.4.5.tar.gz" ) {
                    if ( -d "pooler-cpuminer-2.4.5.tar.gz" ) {
                        croak "rm: ", "pooler-cpuminer-2.4.5.tar.gz",
          " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink "pooler-cpuminer-2.4.5.tar.gz" ) {
                                                    }
                        else {
                            croak "rm: cannot remove ", "pooler-cpuminer-2.4.5.tar.gz",
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 1;
                    croak "rm: ", "pooler-cpuminer-2.4.5.tar.gz", ": No such file or directory\n";
                }
            }
                        chdir('cpuminer-2.4.5/');
            $CHILD_ERROR = 0;
                        $main_exit_code = system('apt-get', '-f', '-qq', '-y', 'install', 'libcurl4-gnutls-dev') >> 8;
                        $main_exit_code = system('./configure', 'CFLAGS', q{=}, "-O3 -mfpu=neon") >> 8;
                        if (do {
$main_exit_code = system('bash', 'make') >> 8;
                $CHILD_ERROR == 0
            }) {
                                $main_exit_code = system('make', 'install') >> 8;
            }
                        print "\n\nNow you can use /usr/local/bin/minerd to do automated benchmarking.\nIn case you also installed RPi-Monitor you can do a" . "\n";
            $CHILD_ERROR = 0;
                        print "\n    touch /root/.cpuminer\n\nto ensure minerd is running after reboot and results are recorded\nwith RPi-Monitor" . "\n";
            $CHILD_ERROR = 0;
            exit 0;
        } elsif ($c =~ /^d$/msx) {
                        $main_exit_code = system('MonitorIO', ($ENV{OPTARG} // q{})) >> 8;
            exit 0;
        } elsif ($c =~ /^D$/msx) {
                        {
                my $output_38 = q{};
                my $output_printed_38;
                my $pipeline_success_38 = 1;
                                $output = q{};
                                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_39 = q{};

my $cmd_42 = 'fping';
my ($in_41, $out_41);
my $pid_41 = open3($in_41, $out_41, '>&STDERR', $cmd_42, 'ix.io');
print {$in_41} $output_38;
close $in_41 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_39 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_41> };
close $out_41 or croak 'Close failed: $OS_ERROR';
waitpid $pid_41, 0;
$tmp_redirect_39;
                };
                $output_38 = $output;

                                my $grep_result_38_1;
                my @grep_lines_38_1 = split /\n/msx, $output_38;
                my @grep_filtered_38_1 = grep { /alive/msx } @grep_lines_38_1;
                $grep_result_38_1 = join "\n", @grep_filtered_38_1;
                if (!($grep_result_38_1 =~ m{\n\z}msx || $grep_result_38_1 eq q{})) {
                $grep_result_38_1 .= "\n";
                }
                $CHILD_ERROR = scalar @grep_filtered_38_1 > 0 ? 0 : 1;
                $grep_result_38_1 = q{};
                $output_38 = q{};
                if ((scalar @grep_filtered_38_1) == 0) {
                    $pipeline_success_38 = 0;
                }
                if ($output_38 ne q{} && !defined $output_printed_38) {
                    print $output_38;
                    if (!($output_38 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_38 ) { $main_exit_code = 1; }
                }
            if ($CHILD_ERROR != 0) {
                                do {
                    local %ENV = %ENV;
                    my $rf1 = $rf1;
                    my $interval = $interval;
                        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                            print "Network/firewall problem detected. Please fix this prior to installing RPi-Monitor.\n";
                        };
exit 1;
                    q{};
                };
            }
                        my $DebugOutput;
            my @DebugOutput;
            my %DebugOutput;
            $DebugOutput = (do { my $_chomp_temp = do {
    my ($in_43, $out_43);
    my $pid_43 = open3($in_43, $out_43, '>&STDERR', 'mktemp', '/tmp/', basename($_[0]), '.XXXXXX');
    close $in_43 or croak 'Close failed: $OS_ERROR';
    my $result_43 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_43> };
    close $out_43 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_43, 0;
    $result_43
}; chomp $_chomp_temp; $_chomp_temp; });
            # Builtin command 'trap' with dynamic handler not supported
                        do {
local *STDERR;
open STDERR, '>', ${DebugOutput} or croak "Cannot open file: $OS_ERROR\n";
# Builtin command 'exec' not implemented
            };
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                my $tmp = do {
                $main_exit_code = system('bash', 'PreRequisits') >> 8;
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
                        $main_exit_code = system('bash', 'CheckDisks') >> 8;
                                    do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $_wa0 = 'curl';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            if ($CHILD_ERROR != 0) {
                                $main_exit_code = system('apt-get', '-f', '-qq', '-y', 'install', 'curl') >> 8;
            }
                        print "\nDebug output has been collected at the following URL: \n" . "\n";
            $CHILD_ERROR = 0;
                        # Original bash: #!/bin/bash
{
                my $output_45 = q{};
                my $output_printed_45;
                my $pipeline_success_45 = 1;
                                $output_45 = q{};
                my @_pcmd_47 = ('sh', '-c', 'cat "${DebugOutput}"');
                my ($in_46, $out_46);
                my $pid_46 = open3($in_46, $out_46, '>&STDERR', @_pcmd_47);
                close $in_46 or croak 'Close failed: $OS_ERROR';
                $output_45 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_46> };
                close $out_46 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_46, 0;
                $output_45 .= "\n\n\ngdisk.txt contents:\n";
                if ( !($output_45 =~ m{\n\z}msx) ) { $output_45 .= "\n"; }
                $CHILD_ERROR = 0;
                my @_pcmd_49 = ('sh', '-c', 'cat "${MyTempDir}/gdisk.txt"');
                my ($in_48, $out_48);
                my $pid_48 = open3($in_48, $out_48, '>&STDERR', @_pcmd_49);
                close $in_48 or croak 'Close failed: $OS_ERROR';
                $output_45 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_48> };
                close $out_48 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_48, 0;
                $output_45 .= "\n\n\nsmartctl.txt contents:\n";
                if ( !($output_45 =~ m{\n\z}msx) ) { $output_45 .= "\n"; }
                $CHILD_ERROR = 0;
                my @_pcmd_51 = ('sh', '-c', 'cat "${MyTempDir}/smartctl.txt"');
                my ($in_50, $out_50);
                my $pid_50 = open3($in_50, $out_50, '>&STDERR', @_pcmd_51);
                close $in_50 or croak 'Close failed: $OS_ERROR';
                $output_45 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_50> };
                close $out_50 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_50, 0;

                                use LWP::UserAgent;
                use HTTP::Request;
                use HTTP::Headers;
                my $ua = LWP::UserAgent->new;
                my $request = HTTP::Request->new('GET', 'f:1=<-');
                my $response = $ua->request($request);
                if ($response->is_success) {
                print $response->content;
                } else {
                die "curl: HTTP error: $response->code $response->message\n";
                }
                if ($output_45 ne q{} && !defined $output_printed_45) {
                    print $output_45;
                    if (!($output_45 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_45 ) { $main_exit_code = 1; }
                }
                        print "\nPlease post the URL in the OrangePi forum where you've been asked for.\n" . "\n";
            $CHILD_ERROR = 0;
            exit 0;
        } elsif ($c =~ /^c$/msx or $c =~ /^C$/msx) {
                        $main_exit_code = system('CheckCard', ($ENV{OPTARG} // q{})) >> 8;
            exit 0;
        } elsif ($c =~ /^v$/msx) {
                        my $VerifyRepairExcludes;
            my @VerifyRepairExcludes;
            my %VerifyRepairExcludes;
            $VerifyRepairExcludes = "/etc/|/boot/|cache|getty|/var/lib/smartmontools/";
                        $main_exit_code = system('bash', 'VerifyInstallation') >> 8;
            exit 0;
        } elsif ($c =~ /^z$/msx) {
                        my $runs;
            my @runs;
            my %runs;
            $runs = $2;
                        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                $main_exit_code = system('bash', 'Run7ZipBenchmark') >> 8;
            };
            exit 0;
        }
    }
    return;
}

sub DisplayUsage {
    my ($file) = @_;
    do {
    my $__echo_line = "Usage: ($ENV{BOLD} // q{})basename($_[0]) [-h] [-b] [-c $path] [-d $device] [-D] [-m] [-p] [-r] [-u]($ENV{NC} // q{})\n";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    print "############################################################################\n";
if ((${FullUsage} ne q{})) {
        print "\nDetailed Description:" . "\n";
        $CHILD_ERROR = 0;
        # Original bash: grep "^#" "$0" | grep -v "^#\!/bin/bash" | sed 's/^#//'
        my $output_52 = q{};
        my $output_printed_52;
        my $output_53 = q{};
        while (my $line = <>) {
            chomp $line;
                        if (!($line =~ /^\#/msx)) {
                next;
            }
                        if (!($line =~ /^\#\!\/bin\/bash/msx)) {
                next;
            }
            $line =~ 's/^#//';
            print $line . "\n";
        }
        $output_53;
    }
    do {
    my $__echo_line = "\n Use ($ENV{BOLD} // q{})orangepimonitor($ENV{NC} // q{}) for the following tasks:\n";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = " orangepimonitor ($ENV{BOLD} // q{})-c /path/to/test($ENV{NC} // q{}) performs disk health/performance tests";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = " orangepimonitor ($ENV{BOLD} // q{})-d($ENV{NC} // q{}) monitors writes to $device";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = " orangepimonitor ($ENV{BOLD} // q{})-D($ENV{NC} // q{}) tries to upload debug disk info to improve orangepimonitor";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = " orangepimonitor ($ENV{BOLD} // q{})-m($ENV{NC} // q{}) provides simple CLI monitoring - scrolling output";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = " orangepimonitor ($ENV{BOLD} // q{})-M($ENV{NC} // q{}) provides simple CLI monitoring - fixed-line output";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = " orangepimonitor ($ENV{BOLD} // q{})-n($ENV{NC} // q{}) provides simple CLI network monitoring - scrolling output";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = " orangepimonitor ($ENV{BOLD} // q{})-N($ENV{NC} // q{}) provides simple CLI network monitoring - fixed-line output";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = " orangepimonitor ($ENV{BOLD} // q{})-p($ENV{NC} // q{}) tries to install cpuminer for performance measurements";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = " orangepimonitor ($ENV{BOLD} // q{})-r($ENV{NC} // q{}) tries to install RPi-Monitor";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = " orangepimonitor ($ENV{BOLD} // q{})-u($ENV{NC} // q{}) tries to upload orangepi-hardware-monitor.log for support purposes";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = " orangepimonitor ($ENV{BOLD} // q{})-v($ENV{NC} // q{}) tries to verify installed package integrity";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = " orangepimonitor ($ENV{BOLD} // q{})-z($ENV{NC} // q{}) runs a quick 7-zip benchmark to estimate CPU performance\n";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    print "############################################################################\n" . "\n";
    $CHILD_ERROR = 0;
    return;
}

sub MonitorMode {
END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx'echo ; exit 0 2>&1'; print $end_out if $end_out ne q{}; }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('renice', '19', $BASHPID) >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    my $LastUserStat;
    my @LastUserStat;
    my %LastUserStat;
    $LastUserStat = q{0};
    my $LastNiceStat;
    my @LastNiceStat;
    my %LastNiceStat;
    $LastNiceStat = q{0};
    my $LastSystemStat;
    my @LastSystemStat;
    my %LastSystemStat;
    $LastSystemStat = q{0};
    my $LastIdleStat;
    my @LastIdleStat;
    my %LastIdleStat;
    $LastIdleStat = q{0};
    my $LastIOWaitStat;
    my @LastIOWaitStat;
    my %LastIOWaitStat;
    $LastIOWaitStat = q{0};
    my $LastIrqStat;
    my @LastIrqStat;
    my %LastIrqStat;
    $LastIrqStat = q{0};
    my $LastSoftIrqStat;
    my @LastSoftIrqStat;
    my %LastSoftIrqStat;
    $LastSoftIrqStat = q{0};
    my $LastCpuStatCheck;
    my @LastCpuStatCheck;
    my %LastCpuStatCheck;
    $LastCpuStatCheck = q{0};
    my $LastTotal;
    my @LastTotal;
    my %LastTotal;
    $LastTotal = q{0};
    my $SleepInterval;
    my @SleepInterval;
    my %SleepInterval;
    $SleepInterval = (defined ($ENV{interval} // q{}) && ($ENV{interval} // q{}) ne q{} ? ($ENV{interval} // q{}) : '5');
    my $Sensors;
    my @Sensors;
    my %Sensors;
    $Sensors = "/etc/orangepimonitor/datasources/";
if ((-f '/sys/devices/system/cpu/cpu4/cpufreq/cpuinfo_cur_freq')) {
        my $DisplayHeader;
        my @DisplayHeader;
        my %DisplayHeader;
        $DisplayHeader = "Time       big.LITTLE   load %cpu %sys %usr %nice %io %irq";
        my $CPUs;
        my @CPUs;
        my %CPUs;
        $CPUs = 'biglittle';
}
    else {
        if ((-f '/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq')) {
            $DisplayHeader = "Time        CPU    load %cpu %sys %usr %nice %io %irq";
            $CPUs = 'normal';
}
        else {
            $DisplayHeader = "Time      CPU n/a    load %cpu %sys %usr %nice %io %irq";
            $CPUs = 'notavailable';
        }
    }
if ("$(id -u)" ne "0") {
        print "Running unprivileged. CPU frequency will not be displayed.\n";
        $CPUs = 'notavailable';
    }
        if ((-f "${Sensors}/soctemp")) {
                $DisplayHeader = ${DisplayHeader} . "   CPU";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ($CHILD_ERROR != 0) {
                my $SocTemp;
        my @SocTemp;
        my %SocTemp;
        $SocTemp = 'n/a';
    }
        if ((-f "${Sensors}/pmictemp")) {
                $DisplayHeader = ${DisplayHeader} . "   PMIC";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ($CHILD_ERROR != 0) {
                my $PMICTemp;
        my @PMICTemp;
        my %PMICTemp;
        $PMICTemp = 'n/a';
    }
    my $DCIN;
    my @DCIN;
    my %DCIN;
    $DCIN = do {
    my ($in_54, $out_54);
    my $pid_54 = open3($in_54, $out_54, '>&STDERR', 'CheckDCINVoltage');
    close $in_54 or croak 'Close failed: $OS_ERROR';
    my $result_54 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_54> };
    close $out_54 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_54, 0;
    $result_54
};
        if ((-f "${DCIN}")) {
                $DisplayHeader = ${DisplayHeader} . "   DC-IN";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ($CHILD_ERROR != 0) {
                $DCIN = 'n/a';
    }
        if ((-f '/sys/devices/virtual/thermal/cooling_device0/cur_state')) {
                $DisplayHeader = ${DisplayHeader} . "  C.St.";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ($CHILD_ERROR != 0) {
                my $CoolingState;
        my @CoolingState;
        my %CoolingState;
        $CoolingState = 'n/a';
    }
    print "Stop monitoring using [ctrl]-[c]\n";
    if ((qx'echo "${SleepInterval} * 10" | bc | cut -d. -f1' <= 1$MAGIC_52>/dev/null)) {
                do {
    my $__echo_line = "Warning: High update frequency (" . ${SleepInterval} . " sec) might change " . "sys" . "tem" . " behaviour!";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    print ${DisplayHeader};
if ( !( (${DisplayHeader}) =~ m{\n\z}msx ) ) { print "\n"; }
    my $Counter;
    my @Counter;
    my %Counter;
    $Counter = q{0};
while ( 1 ) {
if ("$c" =~ /^"m"$/msx) {
            $CHILD_ERROR = ($main_exit_code = eval { int($Counter++) } // "") ? 0 : 1;
if ((${Counter} == 1$MAGIC_5)) {
                do {
    my $__echo_line = "\n${DisplayHeader}\\c";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                $Counter = q{0};
            }
}
        else {
            if ("$c" =~ /^"s"$/msx) {
                $CHILD_ERROR = ($main_exit_code = eval { int($Counter++) } // "") ? 0 : 1;
if ((${Counter} == $MAGIC_6)) {
exit 0;
                }
}
            else {
printf('x1b[1A');
            }
        }
        my $LoadAvg;
        my @LoadAvg;
        my %LoadAvg;
        $LoadAvg = do { my @_qx_cmd = ("cut -f 1 -d ' ' < /proc/loadavg"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if ($CPUs =~ /^biglittle$/msx) {
                        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                my $BigFreq;
                my @BigFreq;
                my %BigFreq;
                $BigFreq = do { my @_qx_cmd = ("awk '{printf (\"%0.0f\",$1/1000); }' < /sys/devices/system/cpu/cpu4/cpufreq/cpuinfo_cur_freq"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
            };
                        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                my $LittleFreq;
                my @LittleFreq;
                my %LittleFreq;
                $LittleFreq = do { my @_qx_cmd = ("awk '{printf (\"%0.0f\",$1/1000); }' < /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
            };
                        $main_exit_code = system('bash', 'ProcessStats') >> 8;
                        do {
    my $__echo_line = "\ndo {\nrequire POSIX; POSIX::strftime('%H:%M:%S', localtime(time())) . \"\\n\"\n}: sprintf('%4s', $BigFreq);\n/sprintf('%4s', $LittleFreq);\nMHz sprintf('%5s', $LoadAvg);\n ($ENV{procStats} // q{})\\c";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        } elsif ($CPUs =~ /^normal$/msx) {
                        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                my $CpuFreq;
                my @CpuFreq;
                my %CpuFreq;
                $CpuFreq = do { my @_qx_cmd = ("awk '{printf (\"%0.0f\",$1/1000); }' < /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
            };
                        $main_exit_code = system('bash', 'ProcessStats') >> 8;
                        do {
    my $__echo_line = "\ndo {\nrequire POSIX; POSIX::strftime('%H:%M:%S', localtime(time())) . \"\\n\"\n}: sprintf('%4s', $CpuFreq);\nMHz sprintf('%5s', $LoadAvg);\n ($ENV{procStats} // q{})\\c";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        } elsif ($CPUs =~ /^notavailable$/msx) {
                        $main_exit_code = system('bash', 'ProcessStats') >> 8;
                        do {
    my $__echo_line = "\ndo {\nrequire POSIX; POSIX::strftime('%H:%M:%S', localtime(time())) . \"\\n\"\n}:   ---     sprintf('%5s', $LoadAvg);\n ($ENV{procStats} // q{})\\c";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        }
if ("X${SocTemp}" ne "Xn/a") {
open STDIN, '<', ${Sensors} . "/soctemp" or croak "Cannot open file: $OS_ERROR\n";
$SocTemp = <>;
chomp $SocTemp;
$CHILD_ERROR = defined($SocTemp) ? 0 : 1;
if ((${SocTemp} >= $MAGIC_$MAGIC_1000)) {
                $SocTemp = do { my $here_input = $SocTemp; chomp(my $result = qx{echo "$here_input" | awk '{printf ("%0.1f",$1/1000); }'}); $CHILD_ERROR = $? >> 8; $result; };
            }
            do {
    my $__echo_line = " sprintf('%4s', $SocTemp);\n°C\\c";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        }
if ("X${PMICTemp}" ne "Xn/a") {
open STDIN, '<', ${Sensors} . "/pmictemp" or croak "Cannot open file: $OS_ERROR\n";
$PMICTemp = <>;
chomp $PMICTemp;
$CHILD_ERROR = defined($PMICTemp) ? 0 : 1;
if ((${PMICTemp} >= $MAGIC_$MAGIC_1000)) {
                $PMICTemp = do { my $here_input = $PMICTemp; chomp(my $result = qx{echo "$here_input" | awk '{printf ("%0.1f",$1/1000); }'}); $CHILD_ERROR = $? >> 8; $result; };
            }
            do {
    my $__echo_line = " sprintf('%4s', $PMICTemp);\n°C\\c";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        }
if ("X${DCIN}" ne "Xn/a") {
if (( ( basename(${DCIN}) ) =~ s|^.*/||sr ) =~ /^in_voltage2_raw$/msx) {
                open STDIN, '<', ${DCIN} or croak "Cannot open file: $OS_ERROR\n";
$RAWvoltage = <>;
chomp $RAWvoltage;
$CHILD_ERROR = defined($RAWvoltage) ? 0 : 1;
                                my $DCINvoltage;
                my @DCINvoltage;
                my %DCINvoltage;
                $DCINvoltage = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                    my $output_60 = q{};
                    my $output_printed_60;
                    my $pipeline_success_60 = 1;
                    $output_60 .= "(" . ($ENV{RAWvoltage} // q{}) . " / ((82.0/302.0) * 1023.0 / 1.8)) + 0.1\n";
                    if ( !($output_60 =~ m{\n\z}msx) ) { $output_60 .= "\n"; }
                    $CHILD_ERROR = 0;
                    if ($CHILD_ERROR != 0) { $pipeline_success_60 = 0; }

                    my $cmd_62 = 'bc';
                    my ($in_61, $out_61);
                    my $pid_61 = open3($in_61, $out_61, '>&STDERR', $cmd_62, '-l');
                    print {$in_61} $output_60;
                    close $in_61 or croak 'Close failed: $OS_ERROR';
                    $output_60 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_61> };
                    close $out_61 or croak 'Close failed: $OS_ERROR';
                    waitpid $pid_61, 0;
                    if ( !$pipeline_success_60 ) { $main_exit_code = 1; }
                    $output_60 =~ s/\n+\z//msx;
                    $output_60;
}; $_pipeline_result; };
            } elsif (1) {
                                $DCINvoltage = do { my @_qx_cmd = ("awk '{printf (\"%0.2f\",$1/1000000); }' < \"${DCIN}\""); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
            }
            do {
    my $__echo_line = "  sprintf('%5s', $DCINvoltage);\nV\\c";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        }
        if ("X${CoolingState}" ne "Xn/a") {
            printf('  %d/%d', do { my $cat_chunk = q{}; if ( open my $fh, '<', '/sys/devices/virtual/thermal/cooling_device0/cur_state' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/sys/devices/virtual/thermal/cooling_device0/cur_state' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }, do { my $cat_chunk = q{}; if ( open my $fh, '<', '/sys/devices/virtual/thermal/cooling_device0/max_state' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/sys/devices/virtual/thermal/cooling_device0/max_state' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
                if ("$c" =~ /^"s"$/msx) {
            require Time::HiRes; Time::HiRes::sleep('0.3');
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ($CHILD_ERROR != 0) {
            require Time::HiRes; Time::HiRes::sleep($SleepInterval);
        }
    }
    return;
}

sub CheckDCINVoltage {
    my $i;
    for my $i ('/sys/devices/platform/sunxi-i2c.0/i2c-0/0-0034/axp20-supplyer.28/power_supply/usb/voltage_now', '/sys/power/axp_pmu/vbus/voltage', '/sys/devices/platform/sunxi-i2c.0/i2c-0/0-0034/axp20-supplyer.28/power_supply/ac/voltage_now', '/sys/power/axp_pmu/ac/voltage', '/sys/bus/iio/devices/iio:device0/in_voltage2_raw') {
if ((-f $i)) {
            do {
open STDIN, '<', $i or croak "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
$DCINvoltage = <>;
chomp $DCINvoltage;
$CHILD_ERROR = defined($DCINvoltage) ? 0 : 1;
            };
if ((${DCINvoltage} > $MAGIC_$MAGIC_4080000)) {
                print $i;
if ( !( ($i) =~ m{\n\z}msx ) ) { print "\n"; }
last;
            }
        }
    }
    return;
}

sub ProcessStats {
if ((-f '/tmp/cpustat')) {

        my $CPULoad;
        my @CPULoad;
        my %CPULoad;
        $CPULoad = $1;
        my $SystemLoad;
        my @SystemLoad;
        my %SystemLoad;
        $SystemLoad = $2;
        my $UserLoad;
        my @UserLoad;
        my %UserLoad;
        $UserLoad = $3;
        my $NiceLoad;
        my @NiceLoad;
        my %NiceLoad;
        $NiceLoad = $4;
        my $IOWaitLoad;
        my @IOWaitLoad;
        my %IOWaitLoad;
        $IOWaitLoad = $5;
        my $IrqCombinedLoad;
        my @IrqCombinedLoad;
        my %IrqCombinedLoad;
        $IrqCombinedLoad = $6;
}
    else {
        my $procStatLine;
        my @procStatLine = (do { my $_result = `sed -n 's/^cpu\s//p' /proc/stat`; chomp $_result; $CHILD_ERROR = $? >> 8; split("\n", $_result); });
        my %procStatLine;
        my $UserStat;
        my @UserStat;
        my %UserStat;
        $UserStat = $procStatLine[0];
        my $NiceStat;
        my @NiceStat;
        my %NiceStat;
        $NiceStat = $procStatLine[1];
        my $SystemStat;
        my @SystemStat;
        my %SystemStat;
        $SystemStat = $procStatLine[2];
        my $IdleStat;
        my @IdleStat;
        my %IdleStat;
        $IdleStat = $procStatLine[3];
        my $IOWaitStat;
        my @IOWaitStat;
        my %IOWaitStat;
        $IOWaitStat = $procStatLine[4];
        my $IrqStat;
        my @IrqStat;
        my %IrqStat;
        $IrqStat = $procStatLine[5];
        my $SoftIrqStat;
        my @SoftIrqStat;
        my %SoftIrqStat;
        $SoftIrqStat = $procStatLine[6];
        my $Total;
        my @Total;
        my %Total;
        $Total = q{0};
        my $eachstat;
        for my $eachstat ($procStatLine[eval { int(@) } // ""]) {
            $Total = eval { int( $Total + $eachstat ) } // "";
        }
        my $UserDiff;
        my @UserDiff;
        my %UserDiff;
        my $LastUserStat;
        $UserDiff = eval { int( $UserStat - $LastUserStat ) } // "";
        my $NiceDiff;
        my @NiceDiff;
        my %NiceDiff;
        my $LastNiceStat;
        $NiceDiff = eval { int( $NiceStat - $LastNiceStat ) } // "";
        my $SystemDiff;
        my @SystemDiff;
        my %SystemDiff;
        my $LastSystemStat;
        $SystemDiff = eval { int( $SystemStat - $LastSystemStat ) } // "";
        my $IOWaitDiff;
        my @IOWaitDiff;
        my %IOWaitDiff;
        my $LastIOWaitStat;
        $IOWaitDiff = eval { int( $IOWaitStat - $LastIOWaitStat ) } // "";
        my $IrqDiff;
        my @IrqDiff;
        my %IrqDiff;
        my $LastIrqStat;
        $IrqDiff = eval { int( $IrqStat - $LastIrqStat ) } // "";
        my $SoftIrqDiff;
        my @SoftIrqDiff;
        my %SoftIrqDiff;
        my $LastSoftIrqStat;
        $SoftIrqDiff = eval { int( $SoftIrqStat - $LastSoftIrqStat ) } // "";
        my $diffIdle;
        my @diffIdle;
        my %diffIdle;
        my $LastIdleStat;
        $diffIdle = eval { int( $IdleStat - $LastIdleStat ) } // "";
        my $diffTotal;
        my @diffTotal;
        my %diffTotal;
        my $LastTotal;
        $diffTotal = eval { int( $Total - $LastTotal ) } // "";
        my $diffX;
        my @diffX;
        my %diffX;
        $diffX = eval { int( $diffTotal - $diffIdle ) } // "";
        $CPULoad = eval { int( $diffX* 100 / $diffTotal ) } // "";
        $UserLoad = eval { int( $UserDiff* 100 / $diffTotal ) } // "";
        $SystemLoad = eval { int( $SystemDiff* 100 / $diffTotal ) } // "";
        $NiceLoad = eval { int( $NiceDiff* 100 / $diffTotal ) } // "";
        $IOWaitLoad = eval { int( $IOWaitDiff* 100 / $diffTotal ) } // "";
        my $IrqCombined;
        my @IrqCombined;
        my %IrqCombined;
        $IrqCombined = eval { int( $IrqDiff + $SoftIrqDiff ) } // "";
        $IrqCombinedLoad = eval { int( $IrqCombined* 100 / $diffTotal ) } // "";
        $LastUserStat = $UserStat;
        $LastNiceStat = $NiceStat;
        $LastSystemStat = $SystemStat;
        $LastIdleStat = $IdleStat;
        $LastIOWaitStat = $IOWaitStat;
        $LastIrqStat = $IrqStat;
        $LastSoftIrqStat = $SoftIrqStat;
        $LastTotal = $Total;
    }
    my $procStats;
    my @procStats;
    my %procStats;
    $procStats = ('-e' . q{ } . (do { my $_chomp_temp = sprintf('%3s', $CPULoad);
; chomp $_chomp_temp; $_chomp_temp; }) . "%" . (do { my $_chomp_temp = sprintf('%4s', $SystemLoad);
; chomp $_chomp_temp; $_chomp_temp; }) . "%" . (do { my $_chomp_temp = sprintf('%4s', $UserLoad);
; chomp $_chomp_temp; $_chomp_temp; }) . "%" . (do { my $_chomp_temp = sprintf('%4s', $NiceLoad);
; chomp $_chomp_temp; $_chomp_temp; }) . "%" . (do { my $_chomp_temp = sprintf('%4s', $IOWaitLoad);
; chomp $_chomp_temp; $_chomp_temp; }) . "%" . (do { my $_chomp_temp = sprintf('%4s', $IrqCombinedLoad);
; chomp $_chomp_temp; $_chomp_temp; }) . "%");
    return;
}

sub MonitorIO {
    my $LastPagesOut;
    my @LastPagesOut;
    my %LastPagesOut;
    $LastPagesOut = do { my @_qx_cmd = ("awk -F ' ' '/pgpgout/ {print $2}' < /proc/vmstat"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
    my $LastWrite;
    my @LastWrite;
    my %LastWrite;
    $LastWrite = do { my @_qx_cmd = ("awk -F ' ' \"/ $1 / {print $8}\" < /proc/diskstats"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
    my $LastTimeChecked;
    my @LastTimeChecked;
    my %LastTimeChecked;
    $LastTimeChecked = do {
require POSIX; POSIX::strftime('%s', localtime(time())) . "\n"
};
while ( 1 ) {
        my $CurrentWrite;
        my @CurrentWrite;
        my %CurrentWrite;
        $CurrentWrite = do { my @_qx_cmd = ("awk -F ' ' \"/ $1 / {print $8}\" < /proc/diskstats"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if ((${CurrentWrite} > ${LastWrite})) {
            my $PagesOut;
            my @PagesOut;
            my %PagesOut;
            $PagesOut = do { my @_qx_cmd = ("awk -F ' ' '/pgpgout/ {print $2}' < /proc/vmstat"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
            my $TimeNow;
            my @TimeNow;
            my %TimeNow;
            $TimeNow = do {
require POSIX; POSIX::strftime('%s', localtime(time())) . "\n"
};
            my $PagesWritten;
            my @PagesWritten;
            my %PagesWritten;
            $PagesWritten = eval { int($CurrentWrite - $LastWrite) } // "";
            my $PageOuts;
            my @PageOuts;
            my %PageOuts;
            $PageOuts = eval { int($PagesOut - $LastPagesOut) } // "";
            do {
    my $__echo_line = "do {\nlocal $ENV{LANG} = q{C};\nrequire POSIX; POSIX::strftime('%a %b %e %H:%M:%S %Z %Y', localtime(time())) . \"\\n\"\n}sprintf('%8s', $PagesWritten);\n/${PageOuts} pages written after do {\n    my ($in_68, $out_68);\n    my $pid_68 = open3($in_68, $out_68, '>&STDERR', '${TimeNow} - ${LastTimeChecked}');\n    close $in_68 or croak 'Close failed: $OS_ERROR';\n    my $result_68 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_68> };\n    close $out_68 or croak 'Close failed: $OS_ERROR';\n    waitpid $pid_68, 0;\n    $result_68\n} sec";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            $LastTimeChecked = $TimeNow;
            $LastPagesOut = $PagesOut;
            $LastWrite = $CurrentWrite;
        }
require Time::HiRes; Time::HiRes::sleep(q{1});
    }
    return;
}

sub CheckDisks {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my @ls_files_70 = ();
        my $ls_all_found_71 = 1;
        my @ls_inputs_72 = ();
        my @ls_glob_ls_inputs_72_0 = glob('/sys/block/sd*');
        if ( !@ls_glob_ls_inputs_72_0 ) {
            push @ls_inputs_72, '/sys/block/sd*';
            $ls_all_found_71 = 0;
        } else {
            push @ls_inputs_72, @ls_glob_ls_inputs_72_0;
        }
        my @ls_files_73 = ();
        my @ls_dirs_74 = ();
        my $ls_show_headers_75 = scalar(@ls_inputs_72) > 1;
        for my $ls_item_76 (@ls_inputs_72) {
            if ( -f $ls_item_76 ) {
                push @ls_files_73, $ls_item_76;
            }
            elsif ( -d $ls_item_76 ) {
                push @ls_dirs_74, $ls_item_76;
            }
            else {
                $ls_all_found_71 = 0;
            }
        }
        @ls_files_73 = sort { $a cmp $b } @ls_files_73;
        @ls_dirs_74 = sort { $a cmp $b } @ls_dirs_74;
        if (@ls_files_73) {
            push @ls_files_70, join("\n", @ls_files_73);
        }
        for my $ls_dir_77 (@ls_dirs_74) {
            my @ls_dir_entries_78 = ();
            if ( opendir my $dh, $ls_dir_77 ) {
                while ( my $file = readdir $dh ) {
                    next if $file eq q{.} || $file eq q{..} || $file =~ /^[.]/msx;
                    push @ls_dir_entries_78, $file;
                }
                closedir $dh;
                @ls_dir_entries_78 = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, do { (my $s = $_) =~ s{/$}{}msx; $s } ] } @ls_dir_entries_78;
                if ( $ls_show_headers_75 ) {
                    if ( @ls_dir_entries_78 ) {
                        push @ls_files_70, $ls_dir_77 . ":\n" . join("\n", @ls_dir_entries_78);
                    } else {
                        push @ls_files_70, $ls_dir_77 . ':';
                    }
                }
                elsif ( @ls_dir_entries_78 ) {
                    push @ls_files_70, join("\n", @ls_dir_entries_78);
                }
            }
            else {
                $ls_all_found_71 = 0;
            }
        }
        if (@ls_files_70) {
            print join "\n", @ls_files_70;
            print "\n";
        }
        if ( $ls_all_found_71 ) {
            local $CHILD_ERROR = 0;
            $ls_success = 1;
        }
        else {
            local $CHILD_ERROR = 2;
            $ls_success = 0;
            $main_exit_code = $CHILD_ERROR;
        }
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ( !defined $ls_success || $ls_success == 0 ) {
        exit 0;
    }
    $main_exit_code = 0;
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $_wa0 = 'hddtemp';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
                do {
            local %ENV = %ENV;
                print "\n Installing hddtemp" . "\n";
                $CHILD_ERROR = 0;
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
                    my $tmp = do {
                    $main_exit_code = system('apt-get', '-f', '-qq', '-y', 'install', 'hddtemp') >> 8;
                    };
                    print $tmp;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
            q{};
        };
    }
    my $i;
    for my $i ('/sys/block/sd*') {
        my $DeviceNode;
        my @DeviceNode;
        my %DeviceNode;
        $DeviceNode = '/dev/';
        $CHILD_ERROR = 0;
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', ($ENV{MyTempDir} // q{}) . "/gdisk.txt"
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('gdisk', '-l', $DeviceNode) >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        my $GUID;
        my @GUID;
        my %GUID;
        $GUID = do { my @_qx_cmd = ("awk -F ' ' '/^Disk identifier/ {print $4}' < \"${MyTempDir}/gdisk.txt\""); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
        my $CountOfUnavailablePartitionTables;
        my @CountOfUnavailablePartitionTables;
        my %CountOfUnavailablePartitionTables;
        $CountOfUnavailablePartitionTables = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_80 = q{};
            my $output_printed_80;
            my $pipeline_success_80 = 1;
            my $grep_result_80_0;
            my @grep_lines_80_0 = ();
            my @grep_filtered_80_0 = grep { /:\ not\ present/msx } @grep_lines_80_0;
            $grep_result_80_0 = join "\n", @grep_filtered_80_0;
                        if (!($grep_result_80_0 =~ m{\n\z}msx || $grep_result_80_0 eq q{})) {
                            $grep_result_80_0 .= "\n";
                        }
            $CHILD_ERROR = scalar @grep_filtered_80_0 > 0 ? 0 : 1;
            $output_80 = $grep_result_80_0;
            if ($CHILD_ERROR != 0) { $pipeline_success_80 = 0; }
            $output_80 = do {
                            my $_wc_data = $output_80;
                            my $_wc_lines = () = $_wc_data =~ /\n/gsxm;
                            my $_wc_result = q{};
                            $_wc_result .= sprintf q{%d}, $_wc_lines;
                            $_wc_result .= "\n";
                            $_wc_result;
                        };
            if ( !$pipeline_success_80 ) { $main_exit_code = 1; }
            $output_80 =~ s/\n+\z//msx;
            $output_80;
}; $_pipeline_result; };
if ((${CountOfUnavailablePartitionTables} == $MAGIC_4)) {
            do {
    my $__echo_line = "\nSkipping ${DeviceNode} due to missing partition table. Use parted to create one.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
last;
}
        else {
            do {
    my $__echo_line = "\nExamining ${DeviceNode} with GUID ${GUID}\\c";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        }
        my $HddtempName;
        my @HddtempName;
        my %HddtempName;
        $HddtempName = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_81 = q{};
            my $output_printed_81;
            my $pipeline_success_81 = 1;

            my ($in_82, $out_82);
            my $pid_82 = open3($in_82, $out_82, '>&STDERR', 'hddtemp', '--debug');
            close $in_82 or croak 'Close failed: $OS_ERROR';
            $output_81 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_82> };
            close $out_82 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_82, 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_81 = 0; }
            my @lines = split /\n/msx, $output_81;
            my @result;
            foreach my $line (@lines) {
                chomp $line;
                if ($line =~ /^\s*$/msx) { next; }
                my @fields = split /:\ /msx, $line;
                if (!(/^Model: /)) { next; }
                push @result, ($fields[1] . "\n");
            }
            $output_81 = join "", @result;

            my @lines_83 = split /\n/msx, $output_81;
            my @result_83;
            foreach my $line (@lines_83) {
            chomp $line;
            my @fields = split /\t/msx, $line;
            if (@fields > 0) {
                push @result_83, $fields[0];
            }
            }
            $output_81 = join "\n", @result_83;
            if ($output_81 ne q{} && !($output_81  =~ m{\n\z}msx)) { $output_81 .= "\n"; }

            my @sed_lines_81 = split /\n/msx, $output_81;
            my @sed_result_81;
            foreach my $line (@sed_lines_81) {
            chomp $line;
            $line =~ s/^[ \t]*//gmsx;
            push @sed_result_81, $line;
            }
            $output_81 = join "\n", @sed_result_81;

            if ( !$pipeline_success_81 ) { $main_exit_code = 1; }
            $output_81 =~ s/\n+\z//msx;
            $output_81;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', ($ENV{MyTempDir} // q{}) . "/smartctl.txt"
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('smartctl', '-q', 'noserial', '-s', 'on', '-a', $DeviceNode) >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        my $DeviceModel;
        my @DeviceModel;
        my %DeviceModel;
        $DeviceModel = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_84 = q{};
            my $output_printed_84;
            my $pipeline_success_84 = 1;
            open STDIN, '<', ($ENV{MyTempDir} // q{}) . "/smartctl.txt" or croak "Cannot open file: $OS_ERROR\n";
            my @lines = split /\n/msx, $;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /:\ /msx, $line;
            if (!(/^Device Model/)) { next; }
            push @result, ($fields[1] . "\n");
            }
            $ = join "", @result;
            my @sed_lines_84 = split /\n/msx, $output_84;
            my @sed_result_84;
            foreach my $line (@sed_lines_84) {
            chomp $line;
            $line =~ s/^[ \t]*//gmsx;
            push @sed_result_84, $line;
            }
            $output_84 = join "\n", @sed_result_84;
            if ( !$pipeline_success_84 ) { $main_exit_code = 1; }
            $output_84 =~ s/\n+\z//msx;
            $output_84;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
if ("X${DeviceModel}" eq "X") {
            my $SMARTPrefix;
            my @SMARTPrefix;
            my %SMARTPrefix;
            $SMARTPrefix = (do { my $_chomp_temp = do { my @_qx_cmd = ("CheckSMARTModes Variable(\"DeviceNode\", true, None) 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }; chomp $_chomp_temp; $_chomp_temp; });
if ("X${SMARTPrefix}" eq "X") {
                print "\nUnable to query the disk through S.M.A.R.T.\nPlease investigate manually using smartctl\n" . "\n";
                $CHILD_ERROR = 0;
last;
            }
        }
if ("X${SMARTPrefix}" eq "X") {
            print " \n(accessible through S.M.A.R.T.)" . "\n";
            $CHILD_ERROR = 0;
}
        else {
            do {
    my $__echo_line = " \n(can be queried with \"-d ${SMARTPrefix}\" through S.M.A.R.T.)";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        }
        my $CRCAttribute;
        my @CRCAttribute;
        my %CRCAttribute;
        $CRCAttribute = do { my @_qx_cmd = ("awk -F ' ' '/CRC_Error_Count/ {print $1}' < \"${MyTempDir}/smartctl.txt\""); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
        my $LCCAttribute;
        my @LCCAttribute;
        my %LCCAttribute;
        $LCCAttribute = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_86 = q{};
        my $output_printed_86;
        my $output_87 = q{};
        while (my $line = <>) {
            chomp $line;
                        if (!($line =~ /load.cycle/msx)) {
                next;
            }
            # awk doesn't support line-by-line processing
        }
        $output_87; };
}; $_pipeline_result; };
my $grep_result_88;
my @grep_lines_88 = ();
my @grep_filenames_88 = ();
if (-e "/etc/hddtemp.db") {
    open my $fh, '<', "/etc/hddtemp.db" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_88, $line;
        push @grep_filenames_88, "/etc/hddtemp.db";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /etc/hddtemp.db: No such file or directory\n"; }
my @grep_filtered_88 = grep { /${HddtempName}/msx } @grep_lines_88;
$grep_result_88 = join "\n", @grep_filtered_88;
        if (!($grep_result_88 =~ m{\n\z}msx || $grep_result_88 eq q{})) {
            $grep_result_88 .= "\n";
        }
$CHILD_ERROR = scalar @grep_filtered_88 > 0 ? 0 : 1;
$grep_result_88 = q{};
if (($? != 0)) {
            my $DiskTemp;
            my @DiskTemp;
            my %DiskTemp;
            $DiskTemp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_89 = q{};
                my $output_printed_89;
                my $pipeline_success_89 = 1;
                open STDIN, '<', ($ENV{MyTempDir} // q{}) . "/smartctl.txt" or croak "Cannot open file: $OS_ERROR\n";
                my @lines = split /\n/msx, $;
                my @result;
                foreach my $line (@lines) {
                chomp $line;
                if ($line =~ /^\s*$/msx) { next; }
                my @fields = split /\ /msx, $line;
                if (!(/Temperature/)) { next; }
                push @result, ($fields[0] . "\n");
                }
                $ = join "", @result;
                my $num_lines       = 1;
                my $head_line_count = 0;
                my $result          = q{};
                my $input           = $output_89;
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
                $output_89 = $result;
                if ( !$pipeline_success_89 ) { $main_exit_code = 1; }
                $output_89 =~ s/\n+\z//msx;
                $output_89;
}; $_pipeline_result; };
if ((${DiskTemp} > 0)) {
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>>', '/etc/hddtemp.db'
      or die "Cannot open file: $OS_ERROR\n";
                    do {
    my $__echo_line = "\"${HddtempName}\" ${DiskTemp} C \"${DeviceModel}\"";
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
                do {
    my $__echo_line = "\nAdded disk \"${DeviceModel}/${HddtempName}\" to /etc/hddtemp.db using S.M.A.R.T. attribute ${DiskTemp}\nbased on the following available thermal values:";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
my $grep_result_91;
my @grep_lines_91 = ();
my @grep_filtered_91 = grep { /Temperature/msx } @grep_lines_91;
$grep_result_91 = join "\n", @grep_filtered_91;
                if (!($grep_result_91 =~ m{\n\z}msx || $grep_result_91 eq q{})) {
                    $grep_result_91 .= "\n";
                }
print $grep_result_91;
$CHILD_ERROR = scalar @grep_filtered_91 > 0 ? 0 : 1;
                my $HddtempResult;
                my @HddtempResult;
                my %HddtempResult;
                $HddtempResult = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                    my $output_92 = q{};
                    my $output_printed_92;
                    my $pipeline_success_92 = 1;

                    my ($in_93, $out_93);
                    my $pid_93 = open3($in_93, $out_93, '>&STDERR', 'hddtemp', '-n');
                    close $in_93 or croak 'Close failed: $OS_ERROR';
                    $output_92 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_93> };
                    close $out_93 or croak 'Close failed: $OS_ERROR';
                    waitpid $pid_93, 0;
                    if ($CHILD_ERROR != 0) { $pipeline_success_92 = 0; }
                    my $grep_result_92_1;
                    my @grep_lines_92_1 = split /\n/msx, $output_92;
                    my @grep_filtered_92_1 = grep { !/not\ available/msx } @grep_lines_92_1;
                    $grep_result_92_1 = join "\n", @grep_filtered_92_1;
                                        if (!($grep_result_92_1 =~ m{\n\z}msx || $grep_result_92_1 eq q{})) {
                                            $grep_result_92_1 .= "\n";
                                        }
                    $CHILD_ERROR = scalar @grep_filtered_92_1 > 0 ? 0 : 1;
                    $output_92 = $grep_result_92_1;
                    my @lines = split /\n/msx, $output_92;
                    my @result;
                    foreach my $line (@lines) {
                        chomp $line;
                        if ($line =~ /^\s*$/msx) { next; }
                        my @fields = split /\ /msx, $line;
                        push @result, ($fields[0] . "\n");
                    }
                    $output_92 = join "", @result;

                    if ( !$pipeline_success_92 ) { $main_exit_code = 1; }
                    $output_92 =~ s/\n+\z//msx;
                    $output_92;
}; $_pipeline_result; };
if ("X${HddtempResult}" ne "X${DeviceNode}:") {
                    my $HddtempStatus;
                    my @HddtempStatus;
                    my %HddtempStatus;
                    $HddtempStatus = "does not work. Please check with smartctl and adjust config accordingly";
                    do {
    my $__echo_line = "\nhddtemp output: do {\n    my ($in_94, $out_94);\n    my $pid_94 = open3($in_94, $out_94, '>&STDERR', 'hddtemp', $DeviceNode);\n    close $in_94 or croak 'Close failed: $OS_ERROR';\n    my $result_94 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_94> };\n    close $out_94 or croak 'Close failed: $OS_ERROR';\n    waitpid $pid_94, 0;\n    $result_94\n}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                    print "\nIt seems we can not rely on hddtemp to query this disk. Please try smartctl instead\n" . "\n";
                    $CHILD_ERROR = 0;
}
                else {
                    $HddtempStatus = "will work";
                    do {
    my $__echo_line = "\nhddtemp output: ${HddtempResult})";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                    print "\nIn case this seems not to be correct please adjust /etc/hddtemp.db manually\n" . "\n";
                    $CHILD_ERROR = 0;
                }
}
            else {
                $HddtempStatus = "does not work. Please check with smartctl and adjust config accordingly";
            }
}
        else {
            $HddtempStatus = "will work";
        }
        my $FirmwareUpdate;
        my @FirmwareUpdate;
        my %FirmwareUpdate;
        $FirmwareUpdate = (do { my $_chomp_temp = do { my $grep_result_95;
my @grep_lines_95 = ();
my @grep_filtered_95 = grep { /^http/msx } @grep_lines_95;
$grep_result_95 = join "\n", @grep_filtered_95;
        if (!($grep_result_95 =~ m{\n\z}msx || $grep_result_95 eq q{})) {
            $grep_result_95 .= "\n";
        }
$CHILD_ERROR = scalar @grep_filtered_95 > 0 ? 0 : 1;
 $grep_result_95; }; chomp $_chomp_temp; $_chomp_temp; });
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
my $grep_result_96;
my @grep_lines_96 = ();
my @grep_filenames_96 = ();
if (-e "/etc/orangepimonitor/disks.conf") {
    open my $fh, '<', "/etc/orangepimonitor/disks.conf" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_96, $line;
        push @grep_filenames_96, "/etc/orangepimonitor/disks.conf";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /etc/orangepimonitor/disks.conf: No such file or directory\n"; }
my @grep_filtered_96 = grep { /^"\ .\ ${GUID}\ .\ ":/msx } @grep_lines_96;
$grep_result_96 = join "\n", @grep_filtered_96;
            if (!($grep_result_96 =~ m{\n\z}msx || $grep_result_96 eq q{})) {
                $grep_result_96 .= "\n";
            }
$CHILD_ERROR = scalar @grep_filtered_96 > 0 ? 0 : 1;
$grep_result_96 = q{};
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
if ($? =~ /^0$/msx) {
                        do {
    my $__echo_line = "Disk is already configured by the following monitoring config:\ndo { my $grep_result_97;\nmy @grep_lines_97 = ();\nmy @grep_filenames_97 = ();\nif (-e \"/etc/orangepimonitor/disks.conf\") {\n    open my $fh, '<', \"/etc/orangepimonitor/disks.conf\" or croak \"Cannot open file: $ERRNO\";\n    while (my $line = <$fh>) {\n        chomp $line;\n        push @grep_lines_97, $line;\n        push @grep_filenames_97, \"/etc/orangepimonitor/disks.conf\";\n    }\n    close $fh\n        or croak \"Close failed: $OS_ERROR\";\n}\nelse { print {*STDERR} \"grep: /etc/orangepimonitor/disks.conf: No such file or directory\\n\"; }\nmy @grep_filtered_97 = grep { /^\"\\ .\\ ${GUID}\\ .\\ \":/msx } @grep_lines_97;\n$grep_result_97 = join \"\\n\", @grep_filtered_97;\n            if (!($grep_result_97 =~ m{\\n\\z}msx || $grep_result_97 eq q{})) {\n                $grep_result_97 .= \"\\n\";\n            }\n$CHILD_ERROR = scalar @grep_filtered_97 > 0 ? 0 : 1;\n $grep_result_97; }\n";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        } elsif (1) {
                        do {
    my $__echo_line = "Disk not configured for monitoring. We were able to extract the following \ninformation:\n   GUID: ${GUID}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            if ("X${SMARTPrefix}" ne "X") {
                do {
    my $__echo_line = "   QueryMode: -d ${SMARTPrefix}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
            }
                        do {
    my $__echo_line = "   hddtemp: ${HddtempStatus}\n   CRC attribute: ${CRCAttribute}\n   LCC Attribute: ${LCCAttribute}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            if ($HddtempStatus =~ /^will work$/msx) {
                                do {
    my $__echo_line = "If you want to monitor the disk please add to /etc/orangepimonitor/disks.conf:\n${GUID}:${DeviceModel}:${SMARTPrefix}::${CRCAttribute}:${LCCAttribute}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
            } elsif (1) {
                                do {
    my $__echo_line = "Proposal for /etc/orangepimonitor/disks.conf:\n${GUID}:${DeviceModel}:${SMARTPrefix}:FIXME:${CRCAttribute}:${LCCAttribute}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                                print "You have to figure out how to query the disk for its thermal sensor.\n";
                                do {
    my $__echo_line = "Please check the output of \"hddtemp --debug ${DeviceNode}\" and smartctl\n";
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
if ("X${FirmwareUpdate}" ne "X") {
            do {
    my $__echo_line = "\nWARNING: A firmware update seems to be available:\n${FirmwareUpdate}\n";
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
    return;
}

sub CheckSMARTModes {
    my $i;
    for my $i ('auto', 'sat', 'usbcypress', 'usbjmicron', 'usbprolific', 'usbsunplus') {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', ($ENV{MyTempDir} // q{}) . "/smartctl.txt"
      or die "Cannot open file: $OS_ERROR\n";
            print "";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', ($ENV{MyTempDir} // q{}) . "/smartctl.txt"
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('smartctl', '-q', 'noserial', '-s', 'on', '-d', $i, '-a', $1) >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        my $DeviceModel;
        my @DeviceModel;
        my %DeviceModel;
        $DeviceModel = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_98 = q{};
            my $output_printed_98;
            my $pipeline_success_98 = 1;
            open STDIN, '<', ($ENV{MyTempDir} // q{}) . "/smartctl.txt" or croak "Cannot open file: $OS_ERROR\n";
            my @lines = split /\n/msx, $;
            my @result;
            foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /:\ /msx, $line;
            if (!(/^Device Model/)) { next; }
            push @result, ($fields[1] . "\n");
            }
            $ = join "", @result;
            my @sed_lines_98 = split /\n/msx, $output_98;
            my @sed_result_98;
            foreach my $line (@sed_lines_98) {
            chomp $line;
            $line =~ s/^[ \t]*//gmsx;
            push @sed_result_98, $line;
            }
            $output_98 = join "\n", @sed_result_98;
            if ( !$pipeline_success_98 ) { $main_exit_code = 1; }
            $output_98 =~ s/\n+\z//msx;
            $output_98;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
if ("X${DeviceModel}" ne "X") {
            print $i;
if ( !( ($i) =~ m{\n\z}msx ) ) { print "\n"; }
last;
        }
    }
    return;
}

sub PreRequisits {
if ("$(id -u)" ne "0") {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "This script must be run as root\n";
        };
exit 1;
    }
$ENV{PATH} = '/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin';
delete $ENV{LANG};
    my $DISTROCODE;
    my @DISTROCODE;
    my %DISTROCODE;
    $DISTROCODE = do {
    my ($in_100, $out_100);
    my $pid_100 = open3($in_100, $out_100, '>&STDERR', 'lsb_release', '-s', '-c');
    close $in_100 or croak 'Close failed: $OS_ERROR';
    my $result_100 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_100> };
    close $out_100 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_100, 0;
    $result_100
};
    print "Check whether necessary software is available\\c\n";
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $_wa0 = 'gdisk';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
                do {
            local %ENV = %ENV;
            my $DISTROCODE = $DISTROCODE;
                print " Installing gdisk\\c\n";
                $main_exit_code = system('apt-get', '-f', '-qq', '-y', 'install', 'gdisk') >> 8;
            q{};
        };
    }
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $_wa0 = 'smartctl';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
                do {
            local %ENV = %ENV;
            my $DISTROCODE = $DISTROCODE;
                print " Installing smartmontools\\c\n";
                $main_exit_code = system('apt-get', '-f', '-qq', '-y', 'install', 'smartmontools') >> 8;
            q{};
        };
    }
    print " [done]\nUpdating smartmontools' drivedb\\c" . "\n";
    $CHILD_ERROR = 0;
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('bash', '/usr/sbin/update-smart-drivedb') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
if ((($? != 0) && "X${DISTROCODE}" eq "Xwheezy")) {
my @sed_lines_103 = split /\n/msx, $;
my @sed_result_103;
foreach my $line (@sed_lines_103) {
chomp $line;
push @sed_result_103, $line;
}
$ = join "\n", @sed_result_103;

        $main_exit_code = system('bash', '/usr/sbin/update-smart-drivedb') >> 8;
    }
    print " [done]\n";
    $main_exit_code = system('bash', 'CreateTempDir') >> 8;
    return;
}

sub CreateTempDir {
    my $MyTempDir;
    my @MyTempDir;
    my %MyTempDir;
    $MyTempDir = do {
    my ($in_104, $out_104);
    my $pid_104 = open3($in_104, $out_104, '>&STDERR', 'mktemp', '-d', '/tmp/', basename($_[0]), '.XXXXXX');
    close $in_104 or croak 'Close failed: $OS_ERROR';
    my $result_104 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_104> };
    close $out_104 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_104, 0;
    $result_104
};
if ((!-d "${MyTempDir}")) {
        $MyTempDir = '/tmp/';
        $CHILD_ERROR = 0;
                do {
            local %ENV = %ENV;
            my $MyTempDir = $MyTempDir;
            if (do {
$main_exit_code = system('umask', '066') >> 8;
                $CHILD_ERROR == 0
            }) {
                                use File::Path qw(make_path);
                my $err;
                if ( mkdir $MyTempDir ) {
                    }
                else {
                    croak "mkdir: cannot create directory " . $MyTempDir . ": File exists\n";
                }
            }
            q{};
        };
        if ($CHILD_ERROR != 0) {
                        do {
                local %ENV = %ENV;
                my $err = $err;
                my $MyTempDir = $MyTempDir;
                    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                        print "Failed to create temp dir. Aborting\n";
                    };
exit 1;
                q{};
            };
        }
    }
chmod(oct('711'), (${MyTempDir})) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
# Builtin command 'trap' with dynamic handler not supported
    my $file;
    for my $file ('smartctl.txt', 'gdisk.txt') {
        if ( -e "${MyTempDir} . "/" . ${file}" ) {
            my $current_time = time;
            utime $current_time, $current_time, "${MyTempDir} . "/" . ${file}";
        }
        else {
            if ( open my $fh, '>', "${MyTempDir} . "/" . ${file}" ) {
                close $fh or croak "Close failed: $ERRNO";
            }
            else {
                croak "touch: cannot create ", "${MyTempDir} . "/" . ${file}",
                  ": $ERRNO\n";
            }
        }
chmod(oct('644'), (${MyTempDir} . "/" . ${file})) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    }
    return;
}

sub InstallRPiMonitor {
if ("$(id -u)" ne "0") {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "Installing RPi-Monitor requires root privileges, try sudo please. Exiting\n";
        };
exit 1;
    }
    print "Installing RPi-Monitor. This can take up to 5 minutes. Be patient please\\c\n";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/etc/apt/sources.list.d/armbian.list'
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "deb http://mirrors.tuna.tsinghua.edu.cn/armbian " . (do { my $_chomp_temp = do {
    my ($in_109, $out_109);
    my $pid_109 = open3($in_109, $out_109, '>&STDERR', 'lsb_release', '-s', q{c});
    close $in_109 or croak 'Close failed: $OS_ERROR';
    my $result_109 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_109> };
    close $out_109 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_109, 0;
    $result_109
}; chomp $_chomp_temp; $_chomp_temp; }) . " main " . (do { my $_chomp_temp = do {
    my ($in_110, $out_110);
    my $pid_110 = open3($in_110, $out_110, '>&STDERR', 'lsb_release', '-s', q{c});
    close $in_110 or croak 'Close failed: $OS_ERROR';
    my $result_110 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_110> };
    close $out_110 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_110, 0;
    $result_110
}; chomp $_chomp_temp; $_chomp_temp; }) . "-utils " . (do { my $_chomp_temp = do {
    my ($in_111, $out_111);
    my $pid_111 = open3($in_111, $out_111, '>&STDERR', 'lsb_release', '-s', q{c});
    close $in_111 or croak 'Close failed: $OS_ERROR';
    my $result_111 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_111> };
    close $out_111 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_111, 0;
    $result_111
}; chomp $_chomp_temp; $_chomp_temp; }) . "-desktop";
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
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
use LWP::Simple;
my $url = 'http://mirrors.tuna.tsinghua.edu.cn/armbian/armbian.key';
my $content = get($url);
if (defined $content) {
print $content;
} else {
die "Failed to download $url\n";
}
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    # Original bash: cat /tmp/armbian.key | apt-key add - > /dev/null 2>&1
{
        my $output_113 = q{};
        my $output_printed_113;
        my $pipeline_success_113 = 1;
                $output_113 = do { my $cat_chunk = q{}; if ( open my $fh, '<', '/tmp/armbian.key' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/tmp/armbian.key' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };

                my $cmd_115 = 'apt-key';
        my ($in_114, $out_114);
        my $pid_114 = open3($in_114, $out_114, '>&STDERR', $cmd_115, 'add', q{-});
        print {$in_114} $output_113;
        close $in_114 or croak 'Close failed: $OS_ERROR';
        $output_113 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_114> };
        close $out_114 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_114, 0;
        if ( !$pipeline_success_113 ) { $main_exit_code = 1; }
        }
    $main_exit_code = system('apt-get', '-qq', '-y', 'update') >> 8;
    $main_exit_code = system('apt-get', '-f', '-qq', '-y', 'install', 'rpimonitor') >> 8;
if ( -e "/tmp/armbian.key" ) {
        if ( -d "/tmp/armbian.key" ) {
            croak "rm: ", "/tmp/armbian.key",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/tmp/armbian.key" ) {
                            }
            else {
                croak "rm: cannot remove ", "/tmp/armbian.key",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 1;
        croak "rm: ", "/tmp/armbian.key", ": No such file or directory\n";
    }
if ( -e "/etc/apt/sources.list.d/armbian.list" ) {
        if ( -d "/etc/apt/sources.list.d/armbian.list" ) {
            croak "rm: ", "/etc/apt/sources.list.d/armbian.list",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/etc/apt/sources.list.d/armbian.list" ) {
                            }
            else {
                croak "rm: cannot remove ", "/etc/apt/sources.list.d/armbian.list",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 1;
        croak "rm: ", "/etc/apt/sources.list.d/armbian.list", ": No such file or directory\n";
    }
    $main_exit_code = system('apt-get', '-qq', '-y', 'update') >> 8;
    if (my $pid = fork()) {
        # Parent process continues
    } elsif (defined $pid) {
        # Child process executes the background command
        $main_exit_code = system('bash', '/usr/share/rpimonitor/scripts/updatePackagesStatus.pl') >> 8;
        exit(0);
    } else {
        die "Cannot fork: $ERRNO\n";
    }
    return;
}

sub PatchRPiMonitor_for_sun8i {
    print "\nNow patching RPi-Monitor to deal correctly with H3" . "\n";
    $CHILD_ERROR = 0;
    if (do {
chdir(q{/});
$CHILD_ERROR = 0;
        $CHILD_ERROR == 0
    }) {
        {
            my $output_116 = q{};
            my $output_printed_116;
            my $pipeline_success_116 = 1;
            $output_116 .= "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\ngwYNGjRo0KBBw1eEfwH4UoBHAKAAAA==";
if ( !($output_116 =~ m{\n\z}msx) ) { $output_116 .= "\n"; }
$CHILD_ERROR = 0;

                        my $cmd_118 = 'base64';
            my ($in_117, $out_117);
            my $pid_117 = open3($in_117, $out_117, '>&STDERR', $cmd_118, '--decode');
            print {$in_117} $output_116;
            close $in_117 or croak 'Close failed: $OS_ERROR';
            $output_116 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_117> };
            close $out_117 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_117, 0;

                        my $cmd_120 = 'tar';
            my ($in_119, $out_119);
            my $pid_119 = open3($in_119, $out_119, '>&STDERR', $cmd_120, 'xzf', q{-});
            print {$in_119} $output_116;
            close $in_119 or croak 'Close failed: $OS_ERROR';
            $output_116 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_119> };
            close $out_119 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_119, 0;
            if ($output_116 ne q{} && !defined $output_printed_116) {
                print $output_116;
                if (!($output_116 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_116 ) { $main_exit_code = 1; }
            }
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $_wa0 = "sys" . "tem" . "ctl";
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
if ($? =~ /^0$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('systemctl', 'enable', 'rpimonitor-helper') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('systemctl', 'start', 'rpimonitor-helper') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('systemctl', 'restart', 'rpimonitor') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    } elsif (1) {
                        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('insserv', 'rpimonitor-helper') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        if ($CHILD_ERROR != 0) {
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                my $tmp = do {
                $main_exit_code = system('update-rc.d', 'rpimonitor-helper', 'defaults', '90', '10') >> 8;
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
                if (my $pid = fork()) {
            # Parent process continues
        } elsif (defined $pid) {
            # Child process executes the background command
            if (do {
chdir('/tmp');
$CHILD_ERROR = 0;
                $CHILD_ERROR == 0
            }) {
                use POSIX qw(setsid);
use POSIX qw(dup2);
use POSIX qw(open);
my $nohup_out = 'nohup.out';
if (!defined $ENV{NOHUP_OUT}) {
$ENV{NOHUP_OUT} = $nohup_out;
}
my $pid = fork();
if ($pid == 0) {
setsid();
if (open my $fh, '>', $ENV{NOHUP_OUT}) {
dup2(fileno($fh), STDOUT->fileno());
dup2(fileno($fh), STDERR->fileno());
close $fh or croak "Close failed: $ERRNO";
}
exec('/usr/local/sbin/rpimonitor-helper.sh');
exit 1;
} elsif ($pid > 0) {
print "nohup: ignoring input and appending output to '$ENV{NOHUP_OUT}'\n";
print "nohup: process $pid started\n";
} else {
die "nohup: fork failed\n";
}
            }
            exit(0);
        } else {
            die "Cannot fork: $ERRNO\n";
        }
                        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('/etc/init.d/rpimonitor', 'stop') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('/etc/init.d/rpimonitor', 'start') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
    return;
}

sub CollectSupportInfo {
    my ($file) = @_;
        if (((-s '/var/log/orangepi-hardware-monitor.log') > 0)) {
        print do { my $cat_chunk = q{}; if ( open my $fh, '<', '/var/log/orangepi-hardware-monitor.log' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/var/log/orangepi-hardware-monitor.log' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ($CHILD_ERROR != 0) {
        my $filename = '/var/log/orangepi-hardware-monitor.log.1.gz';
if (!-f $filename) {
die "zcat: '/var/log/orangepi-hardware-monitor.log.1.gz': No such file or directory\n";
}
if (open my $fh, '-|', "gunzip -c $filename") {
while (my $line = <$fh>) {
print $line;
}
close $fh or croak "Close failed: $ERRNO";
} else {
die "zcat: '/var/log/orangepi-hardware-monitor.log.1.gz': Cannot open file\n";
}
    }
        if ((-f '/boot/orangepiEnv.txt')) {
                my $LOGLEVEL;
        my @LOGLEVEL;
        my %LOGLEVEL;
        $LOGLEVEL = do { my @_qx_cmd = (q(awk -F = '/^verbosity/ {print $2}' /boot/orangepiEnv.txt)); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ($CHILD_ERROR != 0) {
                $LOGLEVEL = q{1};
    }
if ((${LOGLEVEL} > $MAGIC_4)) {
        my $VERBOSE;
        my @VERBOSE;
        my %VERBOSE;
        $VERBOSE = '-v';
        if (do {
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $_wa0 = 'lshw';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        } == 0) {
                        do {
                local %ENV = %ENV;
                my $LOGLEVEL = $LOGLEVEL;
                my $VERBOSE = $VERBOSE;
                    print "\n### lshw:" . "\n";
                    $CHILD_ERROR = 0;
                    $main_exit_code = system('lshw', '-quiet', '-s', 'anitize', '-n', 'umeric') >> 8;
                q{};
            };
        }
    }
    if (do {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('bash', 'lsusb') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    } == 0) {
                do {
            local %ENV = %ENV;
            my $LOGLEVEL = $LOGLEVEL;
            my $VERBOSE = $VERBOSE;
                print "\n### lsusb:\n" . "\n";
                $CHILD_ERROR = 0;
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                    $main_exit_code = system('lsusb', $VERBOSE) >> 8;
                };
                print "\n";
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                    $main_exit_code = system('lsusb', '-t') >> 8;
                };
            q{};
        };
    }
    if (do {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('bash', 'lspci') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    } == 0) {
                do {
            local %ENV = %ENV;
            my $LOGLEVEL = $LOGLEVEL;
            my $VERBOSE = $VERBOSE;
                print "\n### lspci:\n" . "\n";
                $CHILD_ERROR = 0;
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                    $main_exit_code = system('lspci', $VERBOSE) >> 8;
                };
            q{};
        };
    }
    if (do {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('bash', 'nvme') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    } == 0) {
                do {
            local %ENV = %ENV;
            my $LOGLEVEL = $LOGLEVEL;
            my $VERBOSE = $VERBOSE;
                print "\n### nvme:\n" . "\n";
                $CHILD_ERROR = 0;
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                    $main_exit_code = system('nvme', 'list') >> 8;
                };
            q{};
        };
    }
    if (!($SUDO_USER eq q{})) {
                do {
    my $__echo_line = "\n### Group membership of do {\n    my ($in_126, $out_126);\n    my $pid_126 = open3($in_126, $out_126, '>&STDERR', 'groups', $SUDO_USER);\n    close $in_126 or croak 'Close failed: $OS_ERROR';\n    my $result_126 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_126> };\n    close $out_126 or croak 'Close failed: $OS_ERROR';\n    waitpid $pid_126, 0;\n    $result_126\n}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
    do {
    my $__echo_line = "\n### Installed packages:\n\ndo { local $CHILD_ERROR = 0; my $_pipeline_result = do {\n        my $output_127 = q{};\n        my $output_printed_127;\n        my $pipeline_success_127 = 1;\n\n        my ($in_128, $out_128);\n        my $pid_128 = open3($in_128, $out_128, '>&STDERR', 'dpkg', '-l');\n        close $in_128 or croak 'Close failed: $OS_ERROR';\n        $output_127 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_128> };\n        close $out_128 or croak 'Close failed: $OS_ERROR';\n        waitpid $pid_128, 0;\n        if ($CHILD_ERROR != 0) { $pipeline_success_127 = 0; }\n\n        my $cmd_130 = 'egrep';\n        my ($in_129, $out_129);\n        my $pid_129 = open3($in_129, $out_129, '>&STDERR', $cmd_130, );\n        print {$in_129} $output_127;\n        close $in_129 or croak 'Close failed: $OS_ERROR';\n        $output_127 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_129> };\n        close $out_129 or croak 'Close failed: $OS_ERROR';\n        waitpid $pid_129, 0;\n        if ( !$pipeline_success_127 ) { $main_exit_code = 1; }\n        $output_127 =~ s/\\n+\\z//msx;\n        $output_127;\n}; $_pipeline_result; }";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    my $KernelVersion;
    my @KernelVersion;
    my %KernelVersion;
    $KernelVersion = do { my @_qx_cmd = ("awk -F ' ' '{print $3}' < /proc/version"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if ($KernelVersion =~ /^3..*$/msx) {
                if ((-e '/boot/script.bin')) {
                        do {
    my $__echo_line = "\n### fex settings: do { my @_qx_cmd = ('ls -la /boot/script.bin'); my $result = qx{$_qx_cmd[0]}; $CHILD_ERROR = $? >> 8; $result; }\n\ndo { my @_qx_cmd = (\"bin2fex /boot/script.bin 2> /dev/null\"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
    }
    do {
    my $__echo_line = "\n### Loaded modules:\n\ndo {\n    my ($in_131, $out_131);\n    my $pid_131 = open3($in_131, $out_131, '>&STDERR', 'lsmod');\n    close $in_131 or croak 'Close failed: $OS_ERROR';\n    my $result_131 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_131> };\n    close $out_131 or croak 'Close failed: $OS_ERROR';\n    waitpid $pid_131, 0;\n    $result_131\n}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    if ((-f '/var/log/nand-sata-install.log')) {
                do {
    my $__echo_line = "\n### nand-sata-install.log:\n\ndo { my $cat_chunk = q{}; if ( open my $fh, '<', '/var/log/nand-sata-install.log' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/var/log/nand-sata-install.log' . ': ' . $OS_ERROR . \"\\n\"; } $cat_chunk; }";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    do {
    my $__echo_line = "\n### Current system health:\n\ndo { local $CHILD_ERROR = 0; my $_pipeline_result = do {\n        my $output_132 = q{};\n        my $output_printed_132;\n        my $pipeline_success_132 = 1;\n\n        my ($in_133, $out_133);\n        my $pid_133 = open3($in_133, $out_133, '>&STDERR', 'unknown_command', '-s');\n        close $in_133 or croak 'Close failed: $OS_ERROR';\n        $output_132 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_133> };\n        close $out_133 or croak 'Close failed: $OS_ERROR';\n        waitpid $pid_133, 0;\n        if ($CHILD_ERROR != 0) { $pipeline_success_132 = 0; }\n\n        my $cmd_135 = 'egrep';\n        my ($in_134, $out_134);\n        my $pid_134 = open3($in_134, $out_134, '>&STDERR', $cmd_135, );\n        print {$in_134} $output_132;\n        close $in_134 or croak 'Close failed: $OS_ERROR';\n        $output_132 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_134> };\n        close $out_134 or croak 'Close failed: $OS_ERROR';\n        waitpid $pid_134, 0;\n        if ( !$pipeline_success_132 ) { $main_exit_code = 1; }\n        $output_132 =~ s/\\n+\\z//msx;\n        $output_132;\n}; $_pipeline_result; }";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    if (my $pid = fork()) {
        # Parent process continues
    } elsif (defined $pid) {
        # Child process executes the background command
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('stress', '-t', q{3}, '-c', do { my ($in_136, $out_136); my $pid_136 = open3($in_136, $out_136, '>&STDERR', 'grep', ''-c'', ''processor'', ''/proc/cpuinfo''); close $in_136 or croak 'Close failed: $OS_ERROR'; my $result_136 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_136> }; close $out_136 or croak 'Close failed: $OS_ERROR'; waitpid $pid_136, 0; $result_136 }, '--backoff', '250') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit(0);
    } else {
        die "Cannot fork: $ERRNO\n";
    }
    # Original bash: "$0" -s | grep "^[0-9]"
{
        my $output_137 = q{};
        my $output_printed_137;
        my $pipeline_success_137 = 1;
                my ($in_138, $out_138);
        my $pid_138 = open3($in_138, $out_138, '>&STDERR', 'unknown_command', '-s');
        close $in_138 or croak 'Close failed: $OS_ERROR';
        $output_137 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_138> };
        close $out_138 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_138, 0;

                my $grep_result_137_1;
        my @grep_lines_137_1 = split /\n/msx, $output_137;
        my @grep_filtered_137_1 = grep { /^[0-9]/msx } @grep_lines_137_1;
        $grep_result_137_1 = join "\n", @grep_filtered_137_1;
        if (!($grep_result_137_1 =~ m{\n\z}msx || $grep_result_137_1 eq q{})) {
        $grep_result_137_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_137_1 > 0 ? 0 : 1;
        $output_137 = $grep_result_137_1;
        $output_137 = $grep_result_137_1;
        if ((scalar @grep_filtered_137_1) == 0) {
            $pipeline_success_137 = 0;
        }
        if ($output_137 ne q{} && !defined $output_printed_137) {
            print $output_137;
            if (!($output_137 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_137 ) { $main_exit_code = 1; }
        }
        if (do {
{
    my $output_139 = q{};
    my $output_printed_139;
    my $pipeline_success_139 = 1;
        $output = q{};
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_140 = q{};

my $cmd_143 = 'fping';
my ($in_142, $out_142);
my $pid_142 = open3($in_142, $out_142, '>&STDERR', $cmd_143, 'ix.io');
print {$in_142} $output_139;
close $in_142 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_140 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_142> };
close $out_142 or croak 'Close failed: $OS_ERROR';
waitpid $pid_142, 0;
$tmp_redirect_140;
    };
    $output_139 = $output;

        my $grep_result_139_1;
    my @grep_lines_139_1 = split /\n/msx, $output_139;
    my @grep_filtered_139_1 = grep { /alive/msx } @grep_lines_139_1;
    $grep_result_139_1 = join "\n", @grep_filtered_139_1;
    if (!($grep_result_139_1 =~ m{\n\z}msx || $grep_result_139_1 eq q{})) {
    $grep_result_139_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_139_1 > 0 ? 0 : 1;
    $grep_result_139_1 = q{};
    $output_139 = q{};
    if ((scalar @grep_filtered_139_1) == 0) {
        $pipeline_success_139 = 0;
    }
    if ($output_139 ne q{} && !defined $output_printed_139) {
        print $output_139;
        if (!($output_139 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_139 ) { $main_exit_code = 1; }
    }
if ($CHILD_ERROR != 0) {
    (-f '/etc/resolv.conf')}
        $CHILD_ERROR == 0
    }) {
                do {
    my $__echo_line = "\n### resolv.conf\n\ndo { my @_qx_cmd = ('ls -la /etc/resolv.conf'); my $result = qx{$_qx_cmd[0]}; $CHILD_ERROR = $? >> 8; $result; }";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
    if ($CHILD_ERROR != 0) {
                print "\n### resolv.conf does not exist or readable" . "\n";
        $CHILD_ERROR = 0;
    }
    do {
    my $__echo_line = "\n### Current sysinfo:\n\ndo { local $CHILD_ERROR = 0; my $_pipeline_result = do {\n        my $output_144 = q{};\n        my $output_printed_144;\n        my $pipeline_success_144 = 1;\n\n        my ($in_145, $out_145);\n        my $pid_145 = open3($in_145, $out_145, '>&STDERR', 'iostat', '-p', 'ALL');\n        close $in_145 or croak 'Close failed: $OS_ERROR';\n        $output_144 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_145> };\n        close $out_145 or croak 'Close failed: $OS_ERROR';\n        waitpid $pid_145, 0;\n        if ($CHILD_ERROR != 0) { $pipeline_success_144 = 0; }\n        my $grep_result_144_1;\n        my @grep_lines_144_1 = split /\\n/msx, $output_144;\n        my @grep_filtered_144_1 = grep { !/^loop/msx } @grep_lines_144_1;\n        $grep_result_144_1 = join \"\\n\", @grep_filtered_144_1;\n                if (!($grep_result_144_1 =~ m{\\n\\z}msx || $grep_result_144_1 eq q{})) {\n                    $grep_result_144_1 .= \"\\n\";\n                }\n        $CHILD_ERROR = scalar @grep_filtered_144_1 > 0 ? 0 : 1;\n        $output_144 = $grep_result_144_1;\n        if ((scalar @grep_filtered_144_1) == 0) {\n            $pipeline_success_144 = 0;\n        }\n        if ( !$pipeline_success_144 ) { $main_exit_code = 1; }\n        $output_144 =~ s/\\n+\\z//msx;\n        $output_144;\n}; $_pipeline_result; }\n\ndo {\n    my ($in_146, $out_146);\n    my $pid_146 = open3($in_146, $out_146, '>&STDERR', 'vmstat', '-w');\n    close $in_146 or croak 'Close failed: $OS_ERROR';\n    my $result_146 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_146> };\n    close $out_146 or croak 'Close failed: $OS_ERROR';\n    waitpid $pid_146, 0;\n    $result_146\n}\n\ndo {\n    my ($in_147, $out_147);\n    my $pid_147 = open3($in_147, $out_147, '>&STDERR', 'free', '-h');\n    close $in_147 or croak 'Close failed: $OS_ERROR';\n    my $result_147 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_147> };\n    close $out_147 or croak 'Close failed: $OS_ERROR';\n    waitpid $pid_147, 0;\n    $result_147\n}\n\ndo { my @_qx_cmd = (\"zramctl 2> /dev/null\"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }\n\ndo {\n    my ($in_148, $out_148);\n    my $pid_148 = open3($in_148, $out_148, '>&STDERR', 'uptime');\n    close $in_148 or croak 'Close failed: $OS_ERROR';\n    my $result_148 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_148> };\n    close $out_148 or croak 'Close failed: $OS_ERROR';\n    waitpid $pid_148, 0;\n    $result_148\n}\n\ndo { local $CHILD_ERROR = 0; my $_pipeline_result = do {\n        my $output_149 = q{};\n        my $output_printed_149;\n        my $pipeline_success_149 = 1;\n\n        my ($in_150, $out_150);\n        my $pid_150 = open3($in_150, $out_150, '>&STDERR', 'dmesg', );\n        close $in_150 or croak 'Close failed: $OS_ERROR';\n        $output_149 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_150> };\n        close $out_150 or croak 'Close failed: $OS_ERROR';\n        waitpid $pid_150, 0;\n        if ($CHILD_ERROR != 0) { $pipeline_success_149 = 0; }\n        my @lines = split /\\n/msx, $output_149;\n        my $num_lines = 250;\n        if ($num_lines > scalar @lines) {\n        $num_lines = scalar @lines;\n        }\n        my $start_index = scalar @lines - $num_lines;\n        if ($start_index < 0) { $start_index = 0; }\n        my @result = @lines[$start_index..$#lines];\n        $output_149 = join \"\\n\", @result;\n        if ($output_149 ne q{} && !($output_149  =~ m{\\n\\z}msx)) { $output_149 .= \"\\n\"; }\n\n        if ( !$pipeline_success_149 ) { $main_exit_code = 1; }\n        $output_149 =~ s/\\n+\\z//msx;\n        $output_149;\n}; $_pipeline_result; }";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    print "\n" . "\n";
    $CHILD_ERROR = 0;
    my $sysfsnode;
    for my $sysfsnode ('/proc/sys/vm/*') {
        $main_exit_code = system('sysctl', do { do {
            my $output_151 = q{};
            my $output_printed_151;
            my $pipeline_success_151 = 1;
            $output_151 .= $sysfsnode . "\n";
            if ( !($output_151 =~ m{\n\z}msx) ) { $output_151 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_151 = 0; }
            my @sed_lines_151 = split /\n/msx, $output_151;
            my @sed_result_151;
            foreach my $line (@sed_lines_151) {
            chomp $line;
            push @sed_result_151, $line;
            }
            $output_151 = join "\n", @sed_result_151;

            if ( !$pipeline_success_151 ) { $main_exit_code = 1; }
            $output_151 =~ s/\n+\z//msx;
            $output_151;
} }) >> 8;
    }
    do {
    my $__echo_line = "\n### interrupts:\ndo { my $cat_chunk = q{}; if ( open my $fh, '<', '/proc/interrupts' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/proc/interrupts' . ': ' . $OS_ERROR . \"\\n\"; } $cat_chunk; }";
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
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my @ls_files_152 = ();
        my $ls_all_found_153 = 1;
        my @ls_inputs_154 = ();
        my @ls_glob_ls_inputs_154_0 = glob('/tmp/orangepimonitor_checks_*');
        if ( !@ls_glob_ls_inputs_154_0 ) {
            push @ls_inputs_154, '/tmp/orangepimonitor_checks_*';
            $ls_all_found_153 = 0;
        } else {
            push @ls_inputs_154, @ls_glob_ls_inputs_154_0;
        }
        my @ls_files_155 = ();
        my @ls_dirs_156 = ();
        my $ls_show_headers_157 = scalar(@ls_inputs_154) > 1;
        for my $ls_item_158 (@ls_inputs_154) {
            if ( -f $ls_item_158 ) {
                push @ls_files_155, $ls_item_158;
            }
            elsif ( -d $ls_item_158 ) {
                push @ls_dirs_156, $ls_item_158;
            }
            else {
                $ls_all_found_153 = 0;
            }
        }
        @ls_files_155 = sort { $a cmp $b } @ls_files_155;
        @ls_dirs_156 = sort { $a cmp $b } @ls_dirs_156;
        if (@ls_files_155) {
            push @ls_files_152, join("\n", @ls_files_155);
        }
        for my $ls_dir_159 (@ls_dirs_156) {
            my @ls_dir_entries_160 = ();
            if ( opendir my $dh, $ls_dir_159 ) {
                while ( my $file = readdir $dh ) {
                    next if $file eq q{.} || $file eq q{..} || $file =~ /^[.]/msx;
                    push @ls_dir_entries_160, $file;
                }
                closedir $dh;
                @ls_dir_entries_160 = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, do { (my $s = $_) =~ s{/$}{}msx; $s } ] } @ls_dir_entries_160;
                if ( $ls_show_headers_157 ) {
                    if ( @ls_dir_entries_160 ) {
                        push @ls_files_152, $ls_dir_159 . ":\n" . join("\n", @ls_dir_entries_160);
                    } else {
                        push @ls_files_152, $ls_dir_159 . ':';
                    }
                }
                elsif ( @ls_dir_entries_160 ) {
                    push @ls_files_152, join("\n", @ls_dir_entries_160);
                }
            }
            else {
                $ls_all_found_153 = 0;
            }
        }
        if (@ls_files_152) {
            print join "\n", @ls_files_152;
            print "\n";
        }
        if ( $ls_all_found_153 ) {
            local $CHILD_ERROR = 0;
            $ls_success = 1;
        }
        else {
            local $CHILD_ERROR = 2;
            $ls_success = 0;
            $main_exit_code = $CHILD_ERROR;
        }
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ( !defined $ls_success || $ls_success == 0 ) {
        return;    }
    $main_exit_code = 0;
    my $file;
    for my $file ('/tmp/orangepimonitor_checks_*') {
        print "\n### \\c" . "\n";
        $CHILD_ERROR = 0;
        # Original bash: ls "${file}" | cut -f1 -d.
{
            my $output_161 = q{};
            my $output_printed_161;
            my $pipeline_success_161 = 1;
                        $output_161 = do {
            my @ls_files_162 = ();
            if ( -f q{.} ) {
            push @ls_files_162, q{.};
            }
            elsif ( -d q{.} ) {
            if ( opendir my $dh, q{.} ) {
            while ( my $file = readdir $dh ) {
            next if $file eq q{.} || $file eq q{..} || $file =~ /^[.]/msx;
            push @ls_files_162, $file;
            }
            closedir $dh;
            @ls_files_162 = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, do { (my $s = $_) =~ s{/$}{}msx; $s } ] } @ls_files_162;
            }
            }
            (@ls_files_162 ? join("\n", @ls_files_162) . "\n" : q{});
            };
            ;

                        my @lines_164 = split /\n/msx, $output_161;
            my @result_164;
            foreach my $line (@lines_164) {
            chomp $line;
            my @fields = split /./msx, $line;
            if (@fields > 0) {
            push @result_164, $fields[0];
            }
            }
            $output_161 = join "\n", @result_164;
            if ($output_161 ne q{} && !($output_161  =~ m{\n\z}msx)) { $output_161 .= "\n"; }
            if ($output_161 ne q{} && !defined $output_printed_161) {
                print $output_161;
                if (!($output_161 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_161 ) { $main_exit_code = 1; }
            }
        print "\n";
        $CHILD_ERROR = 0;
print do { my $cat_chunk = q{}; if ( open my $fh, '<', ${file} ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . ${file} . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
    }
    return;
}

sub CheckCard {
    my ($file) = @_;
if ("$(id -u)" eq "0") {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "Checking disks is not permitted as root or through sudo. Exiting\n";
        };
exit 1;
    }
if ((!-d "$1")) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "\"$_[0]\" does not exist or is no directory. Exiting";
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
    }
    my $TargetDir;
    my @TargetDir;
    my %TargetDir;
    $TargetDir = "$_[0]";
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $_wa0 = 'f3write';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
                my $MissingTools;
        my @MissingTools;
        my %MissingTools;
        $MissingTools = " f3";
    }
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $_wa0 = 'iozone';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
                $MissingTools = ${MissingTools} . " iozone3";
    }
if ("X${MissingTools}" ne "X") {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "Some tools are missing, please do an \"sudo apt-get -f -y install" . ${MissingTools} . "\" before and try again";
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
    }
    my $Device;
    my @Device;
    my %Device;
    $Device = (do { my $_chomp_temp = do {
    my ($in_168, $out_168);
    my $pid_168 = open3($in_168, $out_168, '>&STDERR', 'GetDevice', "$_[0]");
    close $in_168 or croak 'Close failed: $OS_ERROR';
    my $result_168 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_168> };
    close $out_168 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_168, 0;
    $result_168
}; chomp $_chomp_temp; $_chomp_temp; });
    my $DeviceName;
    my @DeviceName;
    my %DeviceName;
    $DeviceName = $1;
    my $FileSystem;
    my @FileSystem;
    my %FileSystem;
    $FileSystem = $2;
    {
        my $output_169 = q{};
        my $output_printed_169;
        my $pipeline_success_169 = 1;
        $output_169 .= ${DeviceName} . "\n";
if ( !($output_169 =~ m{\n\z}msx) ) { $output_169 .= "\n"; }
$CHILD_ERROR = 0;

                my $grep_result_169_1;
        my @grep_lines_169_1 = split /\n/msx, $output_169;
        my @grep_filtered_169_1 = grep { /mmcblk0/msx } @grep_lines_169_1;
        $grep_result_169_1 = join "\n", @grep_filtered_169_1;
        if (!($grep_result_169_1 =~ m{\n\z}msx || $grep_result_169_1 eq q{})) {
        $grep_result_169_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_169_1 > 0 ? 0 : 1;
        $grep_result_169_1 = q{};
        $output_169 = q{};
        if ((scalar @grep_filtered_169_1) == 0) {
            $pipeline_success_169 = 0;
        }
        if ($output_169 ne q{} && !defined $output_printed_169) {
            print $output_169;
            if (!($output_169 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_169 ) { $main_exit_code = 1; }
        }
    if ($CHILD_ERROR != 0) {
                do {
    my $__echo_line = "\n($ENV{BOLD} // q{})WARNING:($ENV{NC} // q{}) It seems you're not testing the SD card but instead ${DeviceName} (${FileSystem})\n";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
    my $TestDir;
    my @TestDir;
    my %TestDir;
    $TestDir = (do { my $_chomp_temp = do {
    local $ENV{TargetDir} = $TargetDir;
    my $command = q(mktemp -d "${TargetDir}/cardtest.XXXXXX" || : 'Complex command not supported in bash string generation');
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; });
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', ${TestDir} . "/.starttime"
      or die "Cannot open file: $OS_ERROR\n";
my $date = do {
require POSIX; POSIX::strftime('%s', localtime(time())) . "\n"
};
print $date;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
        exit 1;
    }
# Builtin command 'trap' with dynamic handler not supported
    my $LogFile;
    my @LogFile;
    my %LogFile;
    $LogFile = (do { my $_chomp_temp = do {
    my ($in_171, $out_171);
    my $pid_171 = open3($in_171, $out_171, '>&STDERR', 'mktemp', '/tmp/orangepimonitor_checks_', basename(${DeviceName}), q{_}, $FileSystem, '.XXXXXX');
    close $in_171 or croak 'Close failed: $OS_ERROR';
    my $result_171 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_171> };
    close $out_171 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_171, 0;
    $result_171
}; chomp $_chomp_temp; $_chomp_temp; });
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
        $main_exit_code = system('fallocate', '-l', '32M', ${TestDir} . "/empty.32m") >> 8;
    };
    if ($CHILD_ERROR != 0) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('dd', 'if', q{=}, '/dev/zero', 'of', q{=}, ${TestDir} . "/empty.32m", 'bs', q{=}, '1M', 'count', q{=}, '32', 'status', q{=}, 'noxfer') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
    my $ShowWarning;
    my @ShowWarning;
    my %ShowWarning;
    $ShowWarning = 'false';
    do {
    my $__echo_line = "Starting to fill ${DeviceName} with test patterns, please be patient this might take a very long time";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    # Original bash: f3write "${TestDir}" | tee "${LogFile}"
{
        my $output_172 = q{};
        my $output_printed_172;
        my $pipeline_success_172 = 1;
                my ($in_173, $out_173);
        my $pid_173 = open3($in_173, $out_173, '>&STDERR', 'f3write', );
        close $in_173 or croak 'Close failed: $OS_ERROR';
        $output_172 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_173> };
        close $out_173 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_173, 0;

                use Carp qw(carp croak);
        if ( open my $fh, '>', ${LogFile} ) {
        print {$fh} $output_172;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open ${LogFile}: $ERRNO";
        }
        $output_172 = $output_172;
        if ($output_172 ne q{} && !defined $output_printed_172) {
            print $output_172;
            if (!($output_172 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_172 ) { $main_exit_code = 1; }
        }
        if ( -e "${TestDir} . "/.starttime"" ) {
        my $current_time = time;
        utime $current_time, $current_time, "${TestDir} . "/.starttime"";
    }
    else {
        if ( open my $fh, '>', "${TestDir} . "/.starttime"" ) {
            close $fh or croak "Close failed: $ERRNO";
        }
        else {
            croak "touch: cannot create ", "${TestDir} . "/.starttime"",
              ": $ERRNO\n";
        }
    }
    if ($CHILD_ERROR != 0) {
                $main_exit_code = system('bash', 'ShowDeviceWarning') >> 8;
    }
if ( -e "${TestDir} . "/empty.32m"" ) {
        if ( -d "${TestDir} . "/empty.32m"" ) {
            croak "rm: ", ${TestDir} . "/empty.32m",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "${TestDir} . "/empty.32m"" ) {
                            }
            else {
                croak "rm: cannot remove ", ${TestDir} . "/empty.32m",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 1;
        croak "rm: ", ${TestDir} . "/empty.32m", ": No such file or directory\n";
    }
    print "\nNow verifying the written data:" . "\n";
    $CHILD_ERROR = 0;
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', ${LogFile}
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    # Original bash: f3read "${TestDir}" | tee -a "${LogFile}"
{
        my $output_175 = q{};
        my $output_printed_175;
        my $pipeline_success_175 = 1;
                my ($in_176, $out_176);
        my $pid_176 = open3($in_176, $out_176, '>&STDERR', 'f3read', );
        close $in_176 or croak 'Close failed: $OS_ERROR';
        $output_175 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_176> };
        close $out_176 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_176, 0;

                use Carp qw(carp croak);
        if ( open my $fh, '>>', ${LogFile} ) {
        print {$fh} $output_175;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open ${LogFile}: $ERRNO";
        }
        $output_175 = $output_175;
        if ($output_175 ne q{} && !defined $output_printed_175) {
            print $output_175;
            if (!($output_175 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_175 ) { $main_exit_code = 1; }
        }
        if ( -e "${TestDir} . "/.starttime"" ) {
        my $current_time = time;
        utime $current_time, $current_time, "${TestDir} . "/.starttime"";
    }
    else {
        if ( open my $fh, '>', "${TestDir} . "/.starttime"" ) {
            close $fh or croak "Close failed: $ERRNO";
        }
        else {
            croak "touch: cannot create ", "${TestDir} . "/.starttime"",
              ": $ERRNO\n";
        }
    }
    if ($CHILD_ERROR != 0) {
                $main_exit_code = system('bash', 'ShowDeviceWarning') >> 8;
    }
if ( -e "${TestDir} . "/"" ) {
        if ( -d "${TestDir} . "/"" ) {
            croak "rm: ", ${TestDir} . "/",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "${TestDir} . "/"" ) {
                            }
            else {
                croak "rm: cannot remove ", ${TestDir} . "/",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 1;
        croak "rm: ", ${TestDir} . "/", ": No such file or directory\n";
    }
my @files_to_remove = glob("*.h2w");
foreach my $file_to_remove (@files_to_remove) {
        if ( -e $file_to_remove ) {
            if ( -d $file_to_remove ) {
                croak "rm: ", $file_to_remove,
    " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink $file_to_remove ) {
                }
                else {
                    local $CHILD_ERROR = 1;
                    croak "rm: cannot remove ", $file_to_remove,
    ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 1;
            croak "rm: ", $file_to_remove,
    ": No such file or directory\n";
        }
    }
    print "\nStarting iozone tests. Be patient, this can take a very long time to complete:" . "\n";
    $CHILD_ERROR = 0;
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', ${LogFile}
      or die "Cannot open file: $OS_ERROR\n";
        print "\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    chdir(${TestDir});
    $CHILD_ERROR = 0;
    # Original bash: iozone -e -I -a -s 100M -r 4k -r 512k -r 16M -i 0 -i 1 -i 2 | tee -a "${LogFile}"
{
        my $output_178 = q{};
        my $output_printed_178;
        my $pipeline_success_178 = 1;
                my ($in_179, $out_179);
        my $pid_179 = open3($in_179, $out_179, '>&STDERR', 'iozone', '-e', '-I', '-a', '-s', '100M', '-r', '4k', '-r', '512k', '-r', '16M', '-i', q{0}, '-i', q{1}, '-i', q{2});
        close $in_179 or croak 'Close failed: $OS_ERROR';
        $output_178 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_179> };
        close $out_179 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_179, 0;

                use Carp qw(carp croak);
        if ( open my $fh, '>>', ${LogFile} ) {
        print {$fh} $output_178;
        close $fh or croak "Close failed: $ERRNO";
        }
        else {
        carp "tee: Cannot open ${LogFile}: $ERRNO";
        }
        $output_178 = $output_178;
        if ($output_178 ne q{} && !defined $output_printed_178) {
            print $output_178;
            if (!($output_178 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_178 ) { $main_exit_code = 1; }
        }
        if ( -e "${TestDir} . "/.starttime"" ) {
        my $current_time = time;
        utime $current_time, $current_time, "${TestDir} . "/.starttime"";
    }
    else {
        if ( open my $fh, '>', "${TestDir} . "/.starttime"" ) {
            close $fh or croak "Close failed: $ERRNO";
        }
        else {
            croak "touch: cannot create ", "${TestDir} . "/.starttime"",
              ": $ERRNO\n";
        }
    }
    if ($CHILD_ERROR != 0) {
                $main_exit_code = system('bash', 'ShowDeviceWarning') >> 8;
    }
    do {
    my $__echo_line = "\n($ENV{BOLD} // q{})The results from testing ${DeviceName} (${FileSystem}):($ENV{NC} // q{})";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    # Original bash: egrep "Average|Data" "${LogFile}" | sort -r
{
        my $output_181 = q{};
        my $output_printed_181;
        my $pipeline_success_181 = 1;
                my ($in_182, $out_182);
        my $pid_182 = open3($in_182, $out_182, '>&STDERR', 'egrep', );
        close $in_182 or croak 'Close failed: $OS_ERROR';
        $output_181 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_182> };
        close $out_182 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_182, 0;

                my @sort_lines_181_1 = split /\n/msx, $output_181;
        my @sort_sorted_181_1 = sort @sort_lines_181_1;
        @sort_sorted_181_1 = reverse @sort_sorted_181_1;
        my $output_181_1 = join "\n", @sort_sorted_181_1;
        if ($output_181_1 ne q{} && !($output_181_1 =~ m{\n\z}msx)) {
        $output_181_1 .= "\n";
        }
        $output_181 = $output_181_1;
        $output_181 = $output_181_1;
        if ($output_181 ne q{} && !defined $output_printed_181) {
            print $output_181;
            if (!($output_181 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_181 ) { $main_exit_code = 1; }
        }
    print "                                            random    random\n";
    print "reclen    write  rewrite    read    reread    read     write\\c\n";
open STDIN, '<', ${LogFile} or croak "Cannot open file: $OS_ERROR\n";
my @lines = split /\n/msx, $;
my @result;
foreach my $line (@lines) {
    chomp $line;
    if ($line =~ /^\s*$/msx) { next; }
    my @fields = split /102400\ \ /msx, $line;
    if (!(/102400/)) { next; }
    push @result, ($fields[1] . "\n");
}
$ = join "", @result;

    do {
    my $__echo_line = "\n($ENV{BOLD} // q{})Health summary: \\c";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    if (do {
$main_exit_code = system('egrep', '-q', "Read-only|Input/output error", ${LogFile}) >> 8;
        $CHILD_ERROR == 0
    }) {
                do {
            local %ENV = %ENV;
            my $MissingTools = $MissingTools;
            my $TestDir = $TestDir;
            my $DeviceName = $DeviceName;
            my $TargetDir = $TargetDir;
            my $LogFile = $LogFile;
            my $ShowWarning = $ShowWarning;
            my $Device = $Device;
            my $FileSystem = $FileSystem;
                do {
    my $__echo_line = "($ENV{LRED} // q{})($ENV{BOLD} // q{})${DeviceName} failed($ENV{NC} // q{})";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
exit 0;
            q{};
        };
    }
        if (do {
                my $grep_result_184;
        my @grep_lines_184 = ();
        my @grep_filtered_184 = grep { /Data\ LOST:\ 0.00\ Byte/msx } @grep_lines_184;
        $grep_result_184 = join "\n", @grep_filtered_184;
                if (!($grep_result_184 =~ m{\n\z}msx || $grep_result_184 eq q{})) {
                    $grep_result_184 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_184 > 0 ? 0 : 1;
        $grep_result_184 = q{};
        $CHILD_ERROR == 0
    }) {
                do {
    my $__echo_line = "($ENV{LGREEN} // q{})OK";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
    if ($CHILD_ERROR != 0) {
                do {
            local %ENV = %ENV;
            my $MissingTools = $MissingTools;
            my $TestDir = $TestDir;
            my $DeviceName = $DeviceName;
            my $TargetDir = $TargetDir;
            my $LogFile = $LogFile;
            my $ShowWarning = $ShowWarning;
            my $Device = $Device;
            my $FileSystem = $FileSystem;
                do {
    my $__echo_line = "($ENV{LRED} // q{})($ENV{BOLD} // q{})${DeviceName} failed. Replace it as soon as possible!";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
my $grep_result_185;
my @grep_lines_185 = ();
my @grep_filtered_185 = grep { /^Data\ LOST/msx } @grep_lines_185;
$grep_result_185 = join "\n", @grep_filtered_185;
                if (!($grep_result_185 =~ m{\n\z}msx || $grep_result_185 eq q{})) {
                    $grep_result_185 .= "\n";
                }
print $grep_result_185;
$CHILD_ERROR = scalar @grep_filtered_185 > 0 ? 0 : 1;
            q{};
        };
    }
    my $RandomSpeed;
    my @RandomSpeed;
    my %RandomSpeed;
    $RandomSpeed = do { my @_qx_cmd = ("awk -F ' ' \"/102400       4/ {print \\$7\\\"\\\\t\\\"\\$8}\" < \"${LogFile}\""); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if ("X${RandomSpeed}" ne "X") {

        my $RandomReadSpead;
        my @RandomReadSpead;
        my %RandomReadSpead;
        $RandomReadSpead = $1;
        my $RandomWriteSpead;
        my @RandomWriteSpead;
        my %RandomWriteSpead;
        $RandomWriteSpead = $2;
        my $ReadSpeed;
        my @ReadSpeed;
        my %ReadSpeed;
        $ReadSpeed = do { my @_qx_cmd = ("awk -F ' ' \"/Average reading speed/ {print \\$4\\\"\\\\t\\\"\\$5}\" < \"${LogFile}\""); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if ("X$2" eq "XMB/s") {
            my $RawReadSpead;
            my @RawReadSpead;
            my %RawReadSpead;
            $RawReadSpead = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_186 = q{};
                my $output_printed_186;
                my $pipeline_success_186 = 1;
                $output_186 .= "$_[0] * 1000\n";
                if ( !($output_186 =~ m{\n\z}msx) ) { $output_186 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_186 = 0; }

                my $cmd_188 = 'bc';
                my ($in_187, $out_187);
                my $pid_187 = open3($in_187, $out_187, '>&STDERR', $cmd_188, '-s');
                print {$in_187} $output_186;
                close $in_187 or croak 'Close failed: $OS_ERROR';
                $output_186 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_187> };
                close $out_187 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_187, 0;
                my @lines_189 = split /\n/msx, $output_186;
                my @result_189;
                foreach my $line (@lines_189) {
                chomp $line;
                my @fields = split /./msx, $line;
                if (@fields > 0) {
                    push @result_189, $fields[0];
                }
                }
                $output_186 = join "\n", @result_189;
                if ($output_186 ne q{} && !($output_186  =~ m{\n\z}msx)) { $output_186 .= "\n"; }

                if ( !$pipeline_success_186 ) { $main_exit_code = 1; }
                $output_186 =~ s/\n+\z//msx;
                $output_186;
}; $_pipeline_result; };
}
        else {
            $main_exit_code = system('RawReadSpead', do { do {
                my $output_190 = q{};
                my $output_printed_190;
                my $pipeline_success_190 = 1;
                $output_190 .= $1 . "\n";
                if ( !($output_190 =~ m{\n\z}msx) ) { $output_190 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_190 = 0; }
                my @lines_191 = split /\n/msx, $output_190;
                my @result_191;
                foreach my $line (@lines_191) {
                chomp $line;
                my @fields = split /./msx, $line;
                if (@fields > 0) {
                    push @result_191, $fields[0];
                }
                }
                $output_190 = join "\n", @result_191;
                if ($output_190 ne q{} && !($output_190  =~ m{\n\z}msx)) { $output_190 .= "\n"; }

                if ( !$pipeline_success_190 ) { $main_exit_code = 1; }
                $output_190 =~ s/\n+\z//msx;
                $output_190;
} }) >> 8;
        }
        do {
    my $__echo_line = "\n($ENV{NC} // q{})($ENV{BOLD} // q{})Performance summary:($ENV{NC} // q{})\nSequential reading speed:sprintf('%6s', $1);\n $2 \\c";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
                if ((${RawReadSpead} <= 2$MAGIC_500)) {
                        my $Exclamation;
            my @Exclamation;
            my %Exclamation;
            $Exclamation = ($ENV{LRED} // q{}) . ($ENV{BOLD} // q{}) . "way ";
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ($CHILD_ERROR != 0) {
                        $Exclamation = "";
        }
        if ((${RawReadSpead} <= $MAGIC_5000)) {
                        $Exclamation = ${Exclamation} . ($ENV{BOLD} // q{}) . "too ";
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ((${RawReadSpead} <= 7$MAGIC_500)) {
                        do {
    my $__echo_line = "(${Exclamation}low($ENV{NC} // q{}))\\c";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if (do {
{
    my $output_192 = q{};
    my $output_printed_192;
    my $pipeline_success_192 = 1;
    $output_192 .= ${Exclamation} . "\n";
if ( !($output_192 =~ m{\n\z}msx) ) { $output_192 .= "\n"; }
$CHILD_ERROR = 0;

        my $grep_result_192_1;
    my @grep_lines_192_1 = split /\n/msx, $output_192;
    my @grep_filtered_192_1 = grep { /too/msx } @grep_lines_192_1;
    $grep_result_192_1 = join "\n", @grep_filtered_192_1;
    if (!($grep_result_192_1 =~ m{\n\z}msx || $grep_result_192_1 eq q{})) {
    $grep_result_192_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_192_1 > 0 ? 0 : 1;
    $grep_result_192_1 = q{};
    $output_192 = q{};
    if ((scalar @grep_filtered_192_1) == 0) {
        $pipeline_success_192 = 0;
    }
    if ($output_192 ne q{} && !defined $output_printed_192) {
        print $output_192;
        if (!($output_192 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_192 ) { $main_exit_code = 1; }
    }
            $CHILD_ERROR == 0
        }) {
                        $ShowWarning = 'true';
        }
        do {
    my $__echo_line = "\n 4K random reading speed:sprintf('%6s', $RandomReadSpead);\n KB/s \\c";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
                if ((${RandomReadSpead} <= 700)) {
                        $Exclamation = ($ENV{LRED} // q{}) . ($ENV{BOLD} // q{}) . "way ";
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ($CHILD_ERROR != 0) {
                        $Exclamation = "";
        }
        if ((${RandomReadSpead} <= 1$MAGIC_400)) {
                        $Exclamation = ${Exclamation} . ($ENV{BOLD} // q{}) . "too ";
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ((${RandomReadSpead} <= 2$MAGIC_500)) {
                        do {
    my $__echo_line = "(${Exclamation}low($ENV{NC} // q{}))\\c";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if (do {
{
    my $output_193 = q{};
    my $output_printed_193;
    my $pipeline_success_193 = 1;
    $output_193 .= ${Exclamation} . "\n";
if ( !($output_193 =~ m{\n\z}msx) ) { $output_193 .= "\n"; }
$CHILD_ERROR = 0;

        my $grep_result_193_1;
    my @grep_lines_193_1 = split /\n/msx, $output_193;
    my @grep_filtered_193_1 = grep { /too/msx } @grep_lines_193_1;
    $grep_result_193_1 = join "\n", @grep_filtered_193_1;
    if (!($grep_result_193_1 =~ m{\n\z}msx || $grep_result_193_1 eq q{})) {
    $grep_result_193_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_193_1 > 0 ? 0 : 1;
    $grep_result_193_1 = q{};
    $output_193 = q{};
    if ((scalar @grep_filtered_193_1) == 0) {
        $pipeline_success_193 = 0;
    }
    if ($output_193 ne q{} && !defined $output_printed_193) {
        print $output_193;
        if (!($output_193 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_193 ) { $main_exit_code = 1; }
    }
            $CHILD_ERROR == 0
        }) {
                        $ShowWarning = 'true';
        }
        my $WriteSpeed;
        my @WriteSpeed;
        my %WriteSpeed;
        $WriteSpeed = do { my @_qx_cmd = ("awk -F ' ' \"/Average writing speed/ {print \\$4\\\"\\\\t\\\"\\$5}\" < \"${LogFile}\""); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if ("X$2" eq "XMB/s") {
            my $RawWriteSpeed;
            my @RawWriteSpeed;
            my %RawWriteSpeed;
            $RawWriteSpeed = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_194 = q{};
                my $output_printed_194;
                my $pipeline_success_194 = 1;
                $output_194 .= "$_[0] * 1000\n";
                if ( !($output_194 =~ m{\n\z}msx) ) { $output_194 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_194 = 0; }

                my $cmd_196 = 'bc';
                my ($in_195, $out_195);
                my $pid_195 = open3($in_195, $out_195, '>&STDERR', $cmd_196, '-s');
                print {$in_195} $output_194;
                close $in_195 or croak 'Close failed: $OS_ERROR';
                $output_194 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_195> };
                close $out_195 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_195, 0;
                my @lines_197 = split /\n/msx, $output_194;
                my @result_197;
                foreach my $line (@lines_197) {
                chomp $line;
                my @fields = split /./msx, $line;
                if (@fields > 0) {
                    push @result_197, $fields[0];
                }
                }
                $output_194 = join "\n", @result_197;
                if ($output_194 ne q{} && !($output_194  =~ m{\n\z}msx)) { $output_194 .= "\n"; }

                if ( !$pipeline_success_194 ) { $main_exit_code = 1; }
                $output_194 =~ s/\n+\z//msx;
                $output_194;
}; $_pipeline_result; };
}
        else {
            $RawWriteSpeed = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_198 = q{};
                my $output_printed_198;
                my $pipeline_success_198 = 1;
                $output_198 .= $1 . "\n";
                if ( !($output_198 =~ m{\n\z}msx) ) { $output_198 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_198 = 0; }
                my @lines_199 = split /\n/msx, $output_198;
                my @result_199;
                foreach my $line (@lines_199) {
                chomp $line;
                my @fields = split /./msx, $line;
                if (@fields > 0) {
                    push @result_199, $fields[0];
                }
                }
                $output_198 = join "\n", @result_199;
                if ($output_198 ne q{} && !($output_198  =~ m{\n\z}msx)) { $output_198 .= "\n"; }

                if ( !$pipeline_success_198 ) { $main_exit_code = 1; }
                $output_198 =~ s/\n+\z//msx;
                $output_198;
}; $_pipeline_result; };
        }
        do {
    my $__echo_line = "\nSequential writing speed:sprintf('%6s', $1);\n $2 \\c";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
                if ((${RawWriteSpeed} <= 2$MAGIC_500)) {
                        $Exclamation = ($ENV{LRED} // q{}) . ($ENV{BOLD} // q{}) . "way ";
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ($CHILD_ERROR != 0) {
                        $Exclamation = "";
        }
        if ((${RawWriteSpeed} <= $MAGIC_4000)) {
                        $Exclamation = ${Exclamation} . ($ENV{BOLD} // q{}) . "too ";
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ((${RawWriteSpeed} <= $MAGIC_6000)) {
                        do {
    my $__echo_line = "(${Exclamation}low($ENV{NC} // q{}))\\c";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if (do {
{
    my $output_200 = q{};
    my $output_printed_200;
    my $pipeline_success_200 = 1;
    $output_200 .= ${Exclamation} . "\n";
if ( !($output_200 =~ m{\n\z}msx) ) { $output_200 .= "\n"; }
$CHILD_ERROR = 0;

        my $grep_result_200_1;
    my @grep_lines_200_1 = split /\n/msx, $output_200;
    my @grep_filtered_200_1 = grep { /too/msx } @grep_lines_200_1;
    $grep_result_200_1 = join "\n", @grep_filtered_200_1;
    if (!($grep_result_200_1 =~ m{\n\z}msx || $grep_result_200_1 eq q{})) {
    $grep_result_200_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_200_1 > 0 ? 0 : 1;
    $grep_result_200_1 = q{};
    $output_200 = q{};
    if ((scalar @grep_filtered_200_1) == 0) {
        $pipeline_success_200 = 0;
    }
    if ($output_200 ne q{} && !defined $output_printed_200) {
        print $output_200;
        if (!($output_200 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_200 ) { $main_exit_code = 1; }
    }
            $CHILD_ERROR == 0
        }) {
                        $ShowWarning = 'true';
        }
        do {
    my $__echo_line = "\n 4K random writing speed:sprintf('%6s', $RandomWriteSpead);\n KB/s \\c";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
                if ((${RandomWriteSpead} <= $MAGIC_400)) {
                        $Exclamation = ($ENV{LRED} // q{}) . ($ENV{BOLD} // q{}) . "way ";
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ($CHILD_ERROR != 0) {
                        $Exclamation = "";
        }
        if ((${RandomWriteSpead} <= 7$MAGIC_50)) {
                        $Exclamation = ${Exclamation} . ($ENV{BOLD} // q{}) . "too ";
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ((${RandomWriteSpead} < $MAGIC_$MAGIC_1000)) {
                        do {
    my $__echo_line = "(${Exclamation}low($ENV{NC} // q{}))\\c";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if (do {
{
    my $output_201 = q{};
    my $output_printed_201;
    my $pipeline_success_201 = 1;
    $output_201 .= ${Exclamation} . "\n";
if ( !($output_201 =~ m{\n\z}msx) ) { $output_201 .= "\n"; }
$CHILD_ERROR = 0;

        my $grep_result_201_1;
    my @grep_lines_201_1 = split /\n/msx, $output_201;
    my @grep_filtered_201_1 = grep { /too/msx } @grep_lines_201_1;
    $grep_result_201_1 = join "\n", @grep_filtered_201_1;
    if (!($grep_result_201_1 =~ m{\n\z}msx || $grep_result_201_1 eq q{})) {
    $grep_result_201_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_201_1 > 0 ? 0 : 1;
    $grep_result_201_1 = q{};
    $output_201 = q{};
    if ((scalar @grep_filtered_201_1) == 0) {
        $pipeline_success_201 = 0;
    }
    if ($output_201 ne q{} && !defined $output_printed_201) {
        print $output_201;
        if (!($output_201 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_201 ) { $main_exit_code = 1; }
    }
            $CHILD_ERROR == 0
        }) {
                        $ShowWarning = 'true';
        }
if ("X${ShowWarning}" eq "Xtrue") {
            do {
    my $__echo_line = "\n\n($ENV{BOLD} // q{})The device you tested seems to perform too slow to be used with OrangePi.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            print "This applies especially to desktop images where slow storage is responsible\n";
            print "for sluggish behaviour. If you want to have fun with your device do NOT use\n";
            do {
    my $__echo_line = "this media to put the OS image or the user homedirs on.($ENV{NC} // q{})\\c";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        }
        print "\n\nTo interpret the results above correctly or search for better storage\nalternatives please refer to http://oss.digirati.com.br/f3/ and also\nhttp://www.jeffgeerling.com/blogs/jeff-geerling/raspberry-pi-microsd-card\nand http://thewirecutter.com/reviews/best-microsd-card/" . "\n";
        $CHILD_ERROR = 0;
    }
    return;
}

sub ShowDeviceWarning {
    do {
    my $__echo_line = "\n($ENV{LRED} // q{})($ENV{BOLD} // q{})Test stopped, read-only filesystem\n\n($ENV{NC} // q{})($ENV{LRED} // q{})do { local $CHILD_ERROR = 0; my $_pipeline_result = do {\n        my $output_202 = q{};\n        my $output_printed_202;\n        my $pipeline_success_202 = 1;\n\n        my ($in_203, $out_203);\n        my $pid_203 = open3($in_203, $out_203, '>&STDERR', 'dmesg', );\n        close $in_203 or croak 'Close failed: $OS_ERROR';\n        $output_202 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_203> };\n        close $out_203 or croak 'Close failed: $OS_ERROR';\n        waitpid $pid_203, 0;\n        if ($CHILD_ERROR != 0) { $pipeline_success_202 = 0; }\n        my $grep_result_202_1;\n        my @grep_lines_202_1 = split /\\n/msx, $output_202;\n        my @grep_filtered_202_1 = grep { /I\\/O\\ error/msx } @grep_lines_202_1;\n        $grep_result_202_1 = join \"\\n\", @grep_filtered_202_1;\n                if (!($grep_result_202_1 =~ m{\\n\\z}msx || $grep_result_202_1 eq q{})) {\n                    $grep_result_202_1 .= \"\\n\";\n                }\n        $CHILD_ERROR = scalar @grep_filtered_202_1 > 0 ? 0 : 1;\n        $output_202 = $grep_result_202_1;\n        if ((scalar @grep_filtered_202_1) == 0) {\n            $pipeline_success_202 = 0;\n        }\n        if ( !$pipeline_success_202 ) { $main_exit_code = 1; }\n        $output_202 =~ s/\\n+\\z//msx;\n        $output_202;\n}; $_pipeline_result; }";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "\n($ENV{BOLD} // q{})Please be careful using this media since it seems it's already broken. Exiting test.\n($ENV{NC} // q{})";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
exit 0;
    return;
}

sub GetDevice {
    my ($file) = @_;
    my $TestPath;
    my @TestPath;
    my %TestPath;
    $TestPath = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_204 = q{};
        my $output_printed_204;
        my $pipeline_success_204 = 1;

        my ($in_205, $out_205);
        my $pid_205 = open3($in_205, $out_205, '>&STDERR', 'findmnt', );
        close $in_205 or croak 'Close failed: $OS_ERROR';
        $output_204 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_205> };
        close $out_205 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_205, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_204 = 0; }
        my @lines = split /\n/msx, $output_204;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\ /msx, $line;
            if (!(//dev//)) { next; }
            push @result, ($fields[1]"	"$fields[2] . "\n");
        }
        $output_204 = join "", @result;

        if ( !$pipeline_success_204 ) { $main_exit_code = 1; }
        $output_204 =~ s/\n+\z//msx;
        $output_204;
}; $_pipeline_result; };
if ((${TestPath} eq q{} && "${1%/*}" ne q{})) {
        $main_exit_code = system('GetDevice', ( ( dirname($_[0]) ) =~ s|/[^/]*$||sr )) >> 8;
}
    else {
        if ((${TestPath} eq q{} && "${1%/*}" eq q{})) {
            # Original bash: findmnt / | awk -F" " '/\/dev\// {print $2"\t"$3}'
{
                my $output_206 = q{};
                my $output_printed_206;
                my $pipeline_success_206 = 1;
                                my ($in_207, $out_207);
                my $pid_207 = open3($in_207, $out_207, '>&STDERR', 'findmnt', q{/});
                close $in_207 or croak 'Close failed: $OS_ERROR';
                $output_206 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_207> };
                close $out_207 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_207, 0;

                                my @lines = split /\n/msx, $output_206;
                my @result;
                foreach my $line (@lines) {
                chomp $line;
                if ($line =~ /^\s*$/msx) { next; }
                my @fields = split /\ /msx, $line;
                if (!(//dev//)) { next; }
                push @result, ($fields[1]"	"$fields[2] . "\n");
                }
                $output_206 = join "", @result;
                if ($output_206 ne q{} && !defined $output_printed_206) {
                    print $output_206;
                    if (!($output_206 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_206 ) { $main_exit_code = 1; }
                }
}
        else {
            print ${TestPath};
if ( !( (${TestPath}) =~ m{\n\z}msx ) ) { print "\n"; }
        }
    }
    return;
}

sub VerifyInstallation {
if ("$(id -u)" ne "0") {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "This check must be run as root. Aborting.\n";
        };
exit 1;
    }
    print "Starting package integrity check. This might take some time. Be patient please...\n";
    my $OUTPUT;
    my @OUTPUT;
    my %OUTPUT;
    $OUTPUT = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_208 = q{};
        my $output_printed_208;
        my $pipeline_success_208 = 1;

        my ($in_209, $out_209);
        my $pid_209 = open3($in_209, $out_209, '>&STDERR', 'dpkg', '--verify');
        close $in_209 or croak 'Close failed: $OS_ERROR';
        $output_208 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_209> };
        close $out_209 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_209, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_208 = 0; }

        my $cmd_211 = 'egrep';
        my ($in_210, $out_210);
        my $pid_210 = open3($in_210, $out_210, '>&STDERR', $cmd_211, '-v', '-i');
        print {$in_210} $output_208;
        close $in_210 or croak 'Close failed: $OS_ERROR';
        $output_208 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_210> };
        close $out_210 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_210, 0;
        my @lines = split /\n/msx, $output_208;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\ \//msx, $line;
            push @result, ("/"$fields[1] . "\n");
        }
        $output_208 = join "", @result;

        if ( !$pipeline_success_208 ) { $main_exit_code = 1; }
        $output_208 =~ s/\n+\z//msx;
        $output_208;
}; $_pipeline_result; };
if ($OUTPUT eq q{}) {
        do {
    my $__echo_line = "\n($ENV{LGREEN} // q{})($ENV{BOLD} // q{})It appears you don't have any corrupt files or packages!($ENV{NC} // q{})";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
}
    else {
        do {
    my $__echo_line = "\n($ENV{LRED} // q{})($ENV{BOLD} // q{})It appears you may have corrupt packages.($ENV{NC} // q{})\n";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        print "This is usually a symptom of filesystem corruption caused by SD cards or eMMC\n";
        print "dying or burning the OS image to the installation media went wrong.\n" . "\n";
        $CHILD_ERROR = 0;
        print "The following changes from packaged state files were detected:\n" . "\n";
        $CHILD_ERROR = 0;
        do {
    my $__echo_line = "${OUTPUT}\n";
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

sub NetworkMonitorMode {
END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx'echo ; exit 0 2>&1'; print $end_out if $end_out ne q{}; }
    my $ifacecount;
    my @ifacecount;
    my %ifacecount;
    $ifacecount = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_212 = q{};
        my $output_printed_212;
        my $pipeline_success_212 = 1;

        my ($in_213, $out_213);
        my $pid_213 = open3($in_213, $out_213, '>&STDERR', 'route', '-n');
        close $in_213 or croak 'Close failed: $OS_ERROR';
        $output_212 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_213> };
        close $out_213 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_213, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_212 = 0; }

        my $cmd_215 = 'egrep';
        my ($in_214, $out_214);
        my $pid_214 = open3($in_214, $out_214, '>&STDERR', $cmd_215, 'UG');
        print {$in_214} $output_212;
        close $in_214 or croak 'Close failed: $OS_ERROR';
        $output_212 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_214> };
        close $out_214 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_214, 0;

        my $cmd_217 = 'egrep';
        my ($in_216, $out_216);
        my $pid_216 = open3($in_216, $out_216, '>&STDERR', $cmd_217, '-o', '[^ ]*$');
        print {$in_216} $output_212;
        close $in_216 or croak 'Close failed: $OS_ERROR';
        $output_212 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_216> };
        close $out_216 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_216, 0;
        my @sort_lines_212_3 = split /\n/msx, $output_212;
        my @sort_sorted_212_3 = sort @sort_lines_212_3;
        $output_212 = join "\n", @sort_sorted_212_3;
                if ($output_212 ne q{} && !($output_212 =~ m{\n\z}msx)) {
                    $output_212 .= "\n";
                }
        my @uniq_lines_212_4 = split /\n/msx, $output_212;
        @uniq_lines_212_4 = grep { $_ ne q{} } @uniq_lines_212_4; # Filter out empty lines
        my %uniq_seen_212_4;
        my @uniq_result_212_4;
        foreach my $line (@uniq_lines_212_4) {
        if (!$uniq_seen_212_4{$line}++) { push @uniq_result_212_4, $line; }
        }
        $output_212 = join "\n", @uniq_result_212_4;
                if ($output_212 ne q{} && !($output_212 =~ m{\n\z}msx)) {
                    $output_212 .= "\n";
                }
        if ( !$pipeline_success_212 ) { $main_exit_code = 1; }
        $output_212 =~ s/\n+\z//msx;
        $output_212;
}; $_pipeline_result; };
if ((qx'echo -e $ifacecount | tr ' ' '\n' | wc -l' > 1)) {
        my $ifacemenu;
        my @ifacemenu;
        my %ifacemenu;
        $ifacemenu = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_218 = q{};
            my $output_printed_218;
            my $pipeline_success_218 = 1;

            my ($in_219, $out_219);
            my $pid_219 = open3($in_219, $out_219, '>&STDERR', 'route', '-n');
            close $in_219 or croak 'Close failed: $OS_ERROR';
            $output_218 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_219> };
            close $out_219 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_219, 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_218 = 0; }

            my $cmd_221 = 'egrep';
            my ($in_220, $out_220);
            my $pid_220 = open3($in_220, $out_220, '>&STDERR', $cmd_221, 'UG');
            print {$in_220} $output_218;
            close $in_220 or croak 'Close failed: $OS_ERROR';
            $output_218 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_220> };
            close $out_220 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_220, 0;

            my $cmd_223 = 'egrep';
            my ($in_222, $out_222);
            my $pid_222 = open3($in_222, $out_222, '>&STDERR', $cmd_223, '-o', '[^ ]*$');
            print {$in_222} $output_218;
            close $in_222 or croak 'Close failed: $OS_ERROR';
            $output_218 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_222> };
            close $out_222 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_222, 0;
            my @sort_lines_218_3 = split /\n/msx, $output_218;
            my @sort_sorted_218_3 = sort @sort_lines_218_3;
            $output_218 = join "\n", @sort_sorted_218_3;
                        if ($output_218 ne q{} && !($output_218 =~ m{\n\z}msx)) {
                            $output_218 .= "\n";
                        }
            my @uniq_lines_218_4 = split /\n/msx, $output_218;
            @uniq_lines_218_4 = grep { $_ ne q{} } @uniq_lines_218_4; # Filter out empty lines
            my %uniq_seen_218_4;
            my @uniq_result_218_4;
            foreach my $line (@uniq_lines_218_4) {
            if (!$uniq_seen_218_4{$line}++) { push @uniq_result_218_4, $line; }
            }
            $output_218 = join "\n", @uniq_result_218_4;
                        if ($output_218 ne q{} && !($output_218 =~ m{\n\z}msx)) {
                            $output_218 .= "\n";
                        }
            my @lines = split /\n/msx, $output_218;
            my @result;
            foreach my $line (@lines) {
                chomp $line;
                if ($line =~ /^\s*$/msx) { next; }
                my @fields = split /\s+/msx, $line;
                push @result, ($line . "\n");
            }
            push @result, (f i" "a[i]" " . "\n");
            $output_218 = join "", @result;

            if ( !$pipeline_success_218 ) { $main_exit_code = 1; }
            $output_218 =~ s/\n+\z//msx;
            $output_218;
}; $_pipeline_result; };

sub ifacefunc {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', do { my ($in_224, $out_224); my $pid_224 = open3($in_224, $out_224, '>&STDERR', 'tty'); close $in_224 or croak 'Close failed: $OS_ERROR'; my $result_224 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_224> }; close $out_224 or croak 'Close failed: $OS_ERROR'; waitpid $pid_224, 0; $result_224 }
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                $main_exit_code = system('dialog', '--backtitle', "Interface selector", '--title', "Multiple network interfaces detected", '--menu', "Choose which interface to monitor:", '15', '50', do { do {
                    my $output_225 = q{};
                    my $output_printed_225;
                    my $pipeline_success_225 = 1;

                    my ($in_226, $out_226);
                    my $pid_226 = open3($in_226, $out_226, '>&STDERR', 'route', '-n');
                    close $in_226 or croak 'Close failed: $OS_ERROR';
                    $output_225 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_226> };
                    close $out_226 or croak 'Close failed: $OS_ERROR';
                    waitpid $pid_226, 0;
                    if ($CHILD_ERROR != 0) { $pipeline_success_225 = 0; }

                    my $cmd_228 = 'egrep';
                    my ($in_227, $out_227);
                    my $pid_227 = open3($in_227, $out_227, '>&STDERR', $cmd_228, 'UG');
                    print {$in_227} $output_225;
                    close $in_227 or croak 'Close failed: $OS_ERROR';
                    $output_225 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_227> };
                    close $out_227 or croak 'Close failed: $OS_ERROR';
                    waitpid $pid_227, 0;

                    my $cmd_230 = 'egrep';
                    my ($in_229, $out_229);
                    my $pid_229 = open3($in_229, $out_229, '>&STDERR', $cmd_230, '-o', '[^ ]*$');
                    print {$in_229} $output_225;
                    close $in_229 or croak 'Close failed: $OS_ERROR';
                    $output_225 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_229> };
                    close $out_229 or croak 'Close failed: $OS_ERROR';
                    waitpid $pid_229, 0;
                    my @sort_lines_225_3 = split /\n/msx, $output_225;
                    my @sort_sorted_225_3 = sort @sort_lines_225_3;
                    $output_225 = join "\n", @sort_sorted_225_3;
                                        if ($output_225 ne q{} && !($output_225 =~ m{\n\z}msx)) {
                                            $output_225 .= "\n";
                                        }
                    my @uniq_lines_225_4 = split /\n/msx, $output_225;
                    @uniq_lines_225_4 = grep { $_ ne q{} } @uniq_lines_225_4; # Filter out empty lines
                    my %uniq_seen_225_4;
                    my @uniq_result_225_4;
                    foreach my $line (@uniq_lines_225_4) {
                    if (!$uniq_seen_225_4{$line}++) { push @uniq_result_225_4, $line; }
                    }
                    $output_225 = join "\n", @uniq_result_225_4;
                                        if ($output_225 ne q{} && !($output_225 =~ m{\n\z}msx)) {
                                            $output_225 .= "\n";
                                        }
                    $output_225 = do {
                                            my $_wc_data = $output_225;
                                            my $_wc_lines = () = $_wc_data =~ /\n/gsxm;
                                            my $_wc_result = q{};
                                            $_wc_result .= sprintf q{%d}, $_wc_lines;
                                            $_wc_result .= "\n";
                                            $_wc_result;
                                        };
                    if ( !$pipeline_success_225 ) { $main_exit_code = 1; }
                    $output_225 =~ s/\n+\z//msx;
                    $output_225;
} }, ($ifacemenu) . "\n") >> 8;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            return;
}
        my $iface;
        my @iface;
        my %iface;
        $iface = do {
    my ($in_231, $out_231);
    my $pid_231 = open3($in_231, $out_231, '>&STDERR', 'ifacefunc');
    close $in_231 or croak 'Close failed: $OS_ERROR';
    my $result_231 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_231> };
    close $out_231 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_231, 0;
    $result_231
};
}
    else {
        $iface = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_232 = q{};
            my $output_printed_232;
            my $pipeline_success_232 = 1;

            my ($in_233, $out_233);
            my $pid_233 = open3($in_233, $out_233, '>&STDERR', 'route', '-n');
            close $in_233 or croak 'Close failed: $OS_ERROR';
            $output_232 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_233> };
            close $out_233 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_233, 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_232 = 0; }

            my $cmd_235 = 'egrep';
            my ($in_234, $out_234);
            my $pid_234 = open3($in_234, $out_234, '>&STDERR', $cmd_235, 'UG');
            print {$in_234} $output_232;
            close $in_234 or croak 'Close failed: $OS_ERROR';
            $output_232 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_234> };
            close $out_234 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_234, 0;

            my $cmd_237 = 'egrep';
            my ($in_236, $out_236);
            my $pid_236 = open3($in_236, $out_236, '>&STDERR', $cmd_237, '-o', '[^ ]*$');
            print {$in_236} $output_232;
            close $in_236 or croak 'Close failed: $OS_ERROR';
            $output_232 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_236> };
            close $out_236 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_236, 0;
            if ( !$pipeline_success_232 ) { $main_exit_code = 1; }
            $output_232 =~ s/\n+\z//msx;
            $output_232;
}; $_pipeline_result; };
    }
    $main_exit_code = system('bash', 'timerStart') >> 8;
    $main_exit_code = system('bash', 'kickAllStatsDown') >> 8;
printf("\nruntime network statistics: \n");
printf("network interface: \n");
printf("[tap 'd' to display column headings]\n");
printf("[tap 'z' to reset counters]\n");
printf("[use <ctrl-c> to exit]\n");
printf("[bps: bits/s, Mbps: megabits/s, pps: packets/s, MB: megabytes]\n\n");
printf("%-11s %-66s          %-66s\n", ('-e' . q{ } . q{n} . q{ } . "$iface rx.stats____________________________________________________________ tx.stats____________________________________________________________"));
printf("%-11s %-11s %-11s u01B0.%-11s %-11s u01B0.%-11s u01A9.%-11s %-11s %-11s u01B0.%-11s %-11s u01B0.%-11s u01A9.%-11s\n\n", ('-e' . q{ } . q{n} . q{ } . "count bps Mbps Mbps pps pps MB bps Mbps Mbps pps pps MB"));
while ( 1 ) {
        my $nss;
        my @nss = (do { my $_result = `sed -n 's/'$iface':\s//p' /proc/net/dev`; chomp $_result; $CHILD_ERROR = $? >> 8; split("\n", $_result); });
        my %nss;
        my $rxB;
        my @rxB;
        my %rxB;
        $rxB = $nss[0];
        my $rxP;
        my @rxP;
        my %rxP;
        $rxP = $nss[1];
        my $txB;
        my @txB;
        my %txB;
        $txB = $nss[8];
        my $txP;
        my @txP;
        my %txP;
        $txP = $nss[9];
        my $drxB;
        my @drxB;
        my %drxB;
        my $prxB;
        $drxB = eval { int( $rxB - $prxB ) } // "";
        my $drxb;
        my @drxb;
        my %drxb;
        $drxb = eval { int( $drxB* 8 ) } // "";
        my $drxmb;
        my @drxmb;
        my %drxmb;
        $drxmb = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_247 = q{};
            my $output_printed_247;
            my $pipeline_success_247 = 1;
            $output_247 .= "scale=2;$drxb/1000000\n";
            if ( !($output_247 =~ m{\n\z}msx) ) { $output_247 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_247 = 0; }

            my $cmd_249 = 'bc';
            my ($in_248, $out_248);
            my $pid_248 = open3($in_248, $out_248, '>&STDERR', $cmd_249, );
            print {$in_248} $output_247;
            close $in_248 or croak 'Close failed: $OS_ERROR';
            $output_247 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_248> };
            close $out_248 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_248, 0;
            if ( !$pipeline_success_247 ) { $main_exit_code = 1; }
            $output_247 =~ s/\n+\z//msx;
            $output_247;
}; $_pipeline_result; };
        my $drxP;
        my @drxP;
        my %drxP;
        my $prxP;
        $drxP = eval { int( $rxP - $prxP ) } // "";
        my $dtxB;
        my @dtxB;
        my %dtxB;
        my $ptxB;
        $dtxB = eval { int( $txB - $ptxB ) } // "";
        my $dtxb;
        my @dtxb;
        my %dtxb;
        $dtxb = eval { int( $dtxB* 8 ) } // "";
        my $dtxmb;
        my @dtxmb;
        my %dtxmb;
        $dtxmb = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_250 = q{};
            my $output_printed_250;
            my $pipeline_success_250 = 1;
            $output_250 .= "scale=2;$dtxb/1000000\n";
            if ( !($output_250 =~ m{\n\z}msx) ) { $output_250 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_250 = 0; }

            my $cmd_252 = 'bc';
            my ($in_251, $out_251);
            my $pid_251 = open3($in_251, $out_251, '>&STDERR', $cmd_252, );
            print {$in_251} $output_250;
            close $in_251 or croak 'Close failed: $OS_ERROR';
            $output_250 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_251> };
            close $out_251 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_251, 0;
            if ( !$pipeline_success_250 ) { $main_exit_code = 1; }
            $output_250 =~ s/\n+\z//msx;
            $output_250;
}; $_pipeline_result; };
        my $dtxP;
        my @dtxP;
        my %dtxP;
        my $ptxP;
        $dtxP = eval { int( $txP - $ptxP ) } // "";
if ("$cnt" ne "0") {
if ("$c" =~ /^"N"$/msx) {
printf('x1b[1A');
            }
            my $srxb;
            my @srxb;
            my %srxb;
            $srxb = eval { int( $srxb + $drxb ) } // "";
            my $stxb;
            my @stxb;
            my %stxb;
            $stxb = eval { int( $stxb + $dtxb ) } // "";
            my $srxB;
            my @srxB;
            my %srxB;
            $srxB = eval { int( $srxB + $drxB ) } // "";
            my $stxB;
            my @stxB;
            my %stxB;
            $stxB = eval { int( $stxB + $dtxB ) } // "";
            my $srxP;
            my @srxP;
            my %srxP;
            $srxP = eval { int( $srxP + $drxP ) } // "";
            my $stxP;
            my @stxP;
            my %stxP;
            $stxP = eval { int( $stxP + $dtxP ) } // "";
            my $srxMB;
            my @srxMB;
            my %srxMB;
            $srxMB = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_254 = q{};
                my $output_printed_254;
                my $pipeline_success_254 = 1;
                $output_254 .= "scale=2;$srxB/1024^2\n";
                if ( !($output_254 =~ m{\n\z}msx) ) { $output_254 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_254 = 0; }

                my $cmd_256 = 'bc';
                my ($in_255, $out_255);
                my $pid_255 = open3($in_255, $out_255, '>&STDERR', $cmd_256, );
                print {$in_255} $output_254;
                close $in_255 or croak 'Close failed: $OS_ERROR';
                $output_254 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_255> };
                close $out_255 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_255, 0;
                if ( !$pipeline_success_254 ) { $main_exit_code = 1; }
                $output_254 =~ s/\n+\z//msx;
                $output_254;
}; $_pipeline_result; };
            my $stxMB;
            my @stxMB;
            my %stxMB;
            $stxMB = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_257 = q{};
                my $output_printed_257;
                my $pipeline_success_257 = 1;
                $output_257 .= "scale=2;$stxB/1024^2\n";
                if ( !($output_257 =~ m{\n\z}msx) ) { $output_257 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_257 = 0; }

                my $cmd_259 = 'bc';
                my ($in_258, $out_258);
                my $pid_258 = open3($in_258, $out_258, '>&STDERR', $cmd_259, );
                print {$in_258} $output_257;
                close $in_258 or croak 'Close failed: $OS_ERROR';
                $output_257 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_258> };
                close $out_258 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_258, 0;
                if ( !$pipeline_success_257 ) { $main_exit_code = 1; }
                $output_257 =~ s/\n+\z//msx;
                $output_257;
}; $_pipeline_result; };
            my $arxb;
            my @arxb;
            my %arxb;
            $arxb = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_260 = q{};
                my $output_printed_260;
                my $pipeline_success_260 = 1;
                $output_260 .= "scale=2;$srxb/$ENV{cnt}\n";
                if ( !($output_260 =~ m{\n\z}msx) ) { $output_260 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_260 = 0; }

                my $cmd_262 = 'bc';
                my ($in_261, $out_261);
                my $pid_261 = open3($in_261, $out_261, '>&STDERR', $cmd_262, );
                print {$in_261} $output_260;
                close $in_261 or croak 'Close failed: $OS_ERROR';
                $output_260 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_261> };
                close $out_261 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_261, 0;
                if ( !$pipeline_success_260 ) { $main_exit_code = 1; }
                $output_260 =~ s/\n+\z//msx;
                $output_260;
}; $_pipeline_result; };
            my $atxb;
            my @atxb;
            my %atxb;
            $atxb = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_263 = q{};
                my $output_printed_263;
                my $pipeline_success_263 = 1;
                $output_263 .= "scale=2;$stxb/$ENV{cnt}\n";
                if ( !($output_263 =~ m{\n\z}msx) ) { $output_263 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_263 = 0; }

                my $cmd_265 = 'bc';
                my ($in_264, $out_264);
                my $pid_264 = open3($in_264, $out_264, '>&STDERR', $cmd_265, );
                print {$in_264} $output_263;
                close $in_264 or croak 'Close failed: $OS_ERROR';
                $output_263 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_264> };
                close $out_264 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_264, 0;
                if ( !$pipeline_success_263 ) { $main_exit_code = 1; }
                $output_263 =~ s/\n+\z//msx;
                $output_263;
}; $_pipeline_result; };
            my $arxmb;
            my @arxmb;
            my %arxmb;
            $arxmb = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_266 = q{};
                my $output_printed_266;
                my $pipeline_success_266 = 1;
                $output_266 .= "scale=2;$arxb/1000000\n";
                if ( !($output_266 =~ m{\n\z}msx) ) { $output_266 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_266 = 0; }

                my $cmd_268 = 'bc';
                my ($in_267, $out_267);
                my $pid_267 = open3($in_267, $out_267, '>&STDERR', $cmd_268, );
                print {$in_267} $output_266;
                close $in_267 or croak 'Close failed: $OS_ERROR';
                $output_266 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_267> };
                close $out_267 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_267, 0;
                if ( !$pipeline_success_266 ) { $main_exit_code = 1; }
                $output_266 =~ s/\n+\z//msx;
                $output_266;
}; $_pipeline_result; };
            my $atxmb;
            my @atxmb;
            my %atxmb;
            $atxmb = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_269 = q{};
                my $output_printed_269;
                my $pipeline_success_269 = 1;
                $output_269 .= "scale=2;$atxb/1000000\n";
                if ( !($output_269 =~ m{\n\z}msx) ) { $output_269 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_269 = 0; }

                my $cmd_271 = 'bc';
                my ($in_270, $out_270);
                my $pid_270 = open3($in_270, $out_270, '>&STDERR', $cmd_271, );
                print {$in_270} $output_269;
                close $in_270 or croak 'Close failed: $OS_ERROR';
                $output_269 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_270> };
                close $out_270 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_270, 0;
                if ( !$pipeline_success_269 ) { $main_exit_code = 1; }
                $output_269 =~ s/\n+\z//msx;
                $output_269;
}; $_pipeline_result; };
            my $arxP;
            my @arxP;
            my %arxP;
            $arxP = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_272 = q{};
                my $output_printed_272;
                my $pipeline_success_272 = 1;
                $output_272 .= "scale=0;$srxP/$ENV{cnt}\n";
                if ( !($output_272 =~ m{\n\z}msx) ) { $output_272 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_272 = 0; }

                my $cmd_274 = 'bc';
                my ($in_273, $out_273);
                my $pid_273 = open3($in_273, $out_273, '>&STDERR', $cmd_274, );
                print {$in_273} $output_272;
                close $in_273 or croak 'Close failed: $OS_ERROR';
                $output_272 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_273> };
                close $out_273 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_273, 0;
                if ( !$pipeline_success_272 ) { $main_exit_code = 1; }
                $output_272 =~ s/\n+\z//msx;
                $output_272;
}; $_pipeline_result; };
            my $atxP;
            my @atxP;
            my %atxP;
            $atxP = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_275 = q{};
                my $output_printed_275;
                my $pipeline_success_275 = 1;
                $output_275 .= "scale=0;$stxP/$ENV{cnt}\n";
                if ( !($output_275 =~ m{\n\z}msx) ) { $output_275 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_275 = 0; }

                my $cmd_277 = 'bc';
                my ($in_276, $out_276);
                my $pid_276 = open3($in_276, $out_276, '>&STDERR', $cmd_277, );
                print {$in_276} $output_275;
                close $in_276 or croak 'Close failed: $OS_ERROR';
                $output_275 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_276> };
                close $out_276 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_276, 0;
                if ( !$pipeline_success_275 ) { $main_exit_code = 1; }
                $output_275 =~ s/\n+\z//msx;
                $output_275;
}; $_pipeline_result; };
printf("%-11s %-11s %-11s   %-11s %-11s   %-11s   %-11s %-11s %-11s   %-11s %-11s   %-11s   %-11s\n", ('-e' . q{ } . q{n} . q{ } . "$ENV{cnt} $drxb $drxmb $arxmb $drxP $arxP $srxMB $dtxb $dtxmb $atxmb $dtxP $atxP $stxMB"));
        }
        $prxB = "$rxB";
        $prxP = "$rxP";
        $ptxB = "$txB";
        $ptxP = "$txP";
        $CHILD_ERROR = ($main_exit_code = eval { int($ENV{cnt}++) } // "") ? 0 : 1;
        $main_exit_code = system('bash', 'timerShut') >> 8;
$1 = <>;
chomp $1;
$CHILD_ERROR = defined($1) ? 0 : 1;
        $main_exit_code = system('bash', 'timerStart') >> 8;
if ("$zeroAll" =~ /^'z'$/msx) {
            $main_exit_code = system('bash', 'kickAllStatsDown') >> 8;
        }
if ("$zeroAll" =~ /^'d'$/msx) {
            $main_exit_code = system('bash', 'scrollingHeader') >> 8;
        }
    }
    return;
}

sub scrollingHeader {
printf("%-11s %-66s          %-66s\n", ('-e' . q{ } . q{n} . q{ } . "$ENV{iface} rx.stats____________________________________________________________ tx.stats____________________________________________________________"));
printf("%-11s %-11s %-11s u01B0.%-11s %-11s u01B0.%-11s u01A9.%-11s %-11s %-11s u01B0.%-11s %-11s u01B0.%-11s u01A9.%-11s\n\n", ('-e' . q{ } . q{n} . q{ } . "count bps Mbps Mbps pps pps MB bps Mbps Mbps pps pps MB"));
    return;
}

sub timerStart {
    my $temp_file_ps_fh_1 = q{/tmp} . '/process_sub_fh_1.tmp';
    my $output_ps_fh_1;
    {
        local *STDOUT;
        open STDOUT, '>', \$output_ps_fh_1 or croak "Cannot redirect STDOUT";
        my $output_282 = q{};
        my $output_printed_282;
    my $date = do {
    require POSIX; POSIX::strftime('', localtime(time())) . "\n"
    };
    print $date;
    if ($output_282 ne q{} && !$output_printed_282) {
        print $output_282;
    }
    }
    use File::Path qw(make_path);
    my $temp_dir_fh_1 = dirname($temp_file_ps_fh_1);
    if (!-d $temp_dir_fh_1) { make_path($temp_dir_fh_1); }
    open my $fh_ps_fh_1, '>', $temp_file_ps_fh_1 or croak "Cannot create temp file: $ERRNO\n";
    print {$fh_ps_fh_1} $output_ps_fh_1;
    close $fh_ps_fh_1 or croak "Close failed: $ERRNO\n";
    open STDIN, '<', $temp_file_ps_fh_1 or croak "Cannot open process substitution: $ERRNO\n";
$st0 = <>;
chomp $st0;
$CHILD_ERROR = defined($st0) ? 0 : 1;
    return;
}

sub timerShut {
    my $temp_file_ps_fh_2 = q{/tmp} . '/process_sub_fh_2.tmp';
    my $output_ps_fh_2;
    {
        local *STDOUT;
        open STDOUT, '>', \$output_ps_fh_2 or croak "Cannot redirect STDOUT";
        my $output_285 = q{};
        my $output_printed_285;
    my $date = do {
    require POSIX; POSIX::strftime('', localtime(time())) . "\n"
    };
    print $date;
    if ($output_285 ne q{} && !$output_printed_285) {
        print $output_285;
    }
    }
    use File::Path qw(make_path);
    my $temp_dir_fh_2 = dirname($temp_file_ps_fh_2);
    if (!-d $temp_dir_fh_2) { make_path($temp_dir_fh_2); }
    open my $fh_ps_fh_2, '>', $temp_file_ps_fh_2 or croak "Cannot create temp file: $ERRNO\n";
    print {$fh_ps_fh_2} $output_ps_fh_2;
    close $fh_ps_fh_2 or croak "Close failed: $ERRNO\n";
    open STDIN, '<', $temp_file_ps_fh_2 or croak "Cannot open process substitution: $ERRNO\n";
$sh0 = <>;
chomp $sh0;
$CHILD_ERROR = defined($sh0) ? 0 : 1;
    my $jusquaQuand;
    my @jusquaQuand;
    my %jusquaQuand;
    $jusquaQuand = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_288 = q{};
        my $output_printed_288;
        my $pipeline_success_288 = 1;
        $output_288 .= "scale=2;($ENV{sh0}-$ENV{st0})*1000000000+($ENV{sh1}-$ENV{st1})\n";
        if ( !($output_288 =~ m{\n\z}msx) ) { $output_288 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_288 = 0; }

        my $cmd_290 = 'bc';
        my ($in_289, $out_289);
        my $pid_289 = open3($in_289, $out_289, '>&STDERR', $cmd_290, );
        print {$in_289} $output_288;
        close $in_289 or croak 'Close failed: $OS_ERROR';
        $output_288 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_289> };
        close $out_289 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_289, 0;
        if ( !$pipeline_success_288 ) { $main_exit_code = 1; }
        $output_288 =~ s/\n+\z//msx;
        $output_288;
}; $_pipeline_result; };
    my $procSecs;
    my @procSecs;
    my %procSecs;
    $procSecs = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_291 = q{};
        my $output_printed_291;
        my $pipeline_success_291 = 1;
        $output_291 .= "scale=2;(1000000000-$jusquaQuand)/1000000000\n";
        if ( !($output_291 =~ m{\n\z}msx) ) { $output_291 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_291 = 0; }

        my $cmd_293 = 'bc';
        my ($in_292, $out_292);
        my $pid_292 = open3($in_292, $out_292, '>&STDERR', $cmd_293, );
        print {$in_292} $output_291;
        close $in_292 or croak 'Close failed: $OS_ERROR';
        $output_291 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_292> };
        close $out_292 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_292, 0;
        if ( !$pipeline_success_291 ) { $main_exit_code = 1; }
        $output_291 =~ s/\n+\z//msx;
        $output_291;
}; $_pipeline_result; };
if ("$rf1" =~ /^"debug"$/msx) {
printf("time controller adjustment: \n");
if ("$c" =~ /^"N"$/msx) {
printf('x1b[1A');
        }
    }
    return;
}

sub kickAllStatsDown {
    my $prxB;
    my @prxB;
    my %prxB;
    $prxB = q{0};
    my $prxP;
    my @prxP;
    my %prxP;
    $prxP = q{0};
    my $ptxB;
    my @ptxB;
    my %ptxB;
    $ptxB = q{0};
    my $ptxP;
    my @ptxP;
    my %ptxP;
    $ptxP = q{0};
    my $srxb;
    my @srxb;
    my %srxb;
    $srxb = q{0};
    my $stxb;
    my @stxb;
    my %stxb;
    $stxb = q{0};
    my $srxB;
    my @srxB;
    my %srxB;
    $srxB = q{0};
    my $stxB;
    my @stxB;
    my %stxB;
    $stxB = q{0};
    my $srxMB;
    my @srxMB;
    my %srxMB;
    $srxMB = q{0};
    my $stxMB;
    my @stxMB;
    my %stxMB;
    $stxMB = q{0};
    my $srxP;
    my @srxP;
    my %srxP;
    $srxP = q{0};
    my $stxP;
    my @stxP;
    my %stxP;
    $stxP = q{0};
    my $cnt;
    my @cnt;
    my %cnt;
    $cnt = q{0};
    return;
}

sub Run7ZipBenchmark {
    print "Preparing benchmark. Be patient please...\n";
    my $MyTool;
    my @MyTool;
    my %MyTool;
    $MyTool = do {
    my $command = 'which 7za || which 7zr';
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
};
    if (do {
if ("${MyTool}" eq q{}) {
        $main_exit_code = system('apt-get', '-f', '-qq', '-y', 'install', 'p7zip') >> 8;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
        $CHILD_ERROR == 0
    }) {
                $MyTool = '/usr/bin/7zr';
    }
    if ("${MyTool}" eq q{}) {
                do {
            local %ENV = %ENV;
            my $MyTool = $MyTool;
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    print "No 7-zip binary found and could not be installed. Aborting\n";
                };
exit 1;
            q{};
        };
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    my $MonitoringOutput;
    my @MonitoringOutput;
    my %MonitoringOutput;
    $MonitoringOutput = (do { my $_chomp_temp = do {
    my ($in_296, $out_296);
    my $pid_296 = open3($in_296, $out_296, '>&STDERR', 'mktemp', '/tmp/', basename($_[0]), '.XXXXXX');
    close $in_296 or croak 'Close failed: $OS_ERROR';
    my $result_296 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_296> };
    close $out_296 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_296, 0;
    $result_296
}; chomp $_chomp_temp; $_chomp_temp; });
# Builtin command 'trap' with dynamic handler not supported
    if (my $pid = fork()) {
        # Parent process continues
    } elsif (defined $pid) {
        # Child process executes the background command
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', $MonitoringOutput
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('orangepimonitor', '-m') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit(0);
    } else {
        die "Cannot fork: $ERRNO\n";
    }
    my $MonitoringPID;
    my @MonitoringPID;
    my %MonitoringPID;
    $MonitoringPID = $!;
    my $RunHowManyTimes;
    my @RunHowManyTimes;
    my %RunHowManyTimes;
    $RunHowManyTimes = (defined ($ENV{runs} // q{}) && ($ENV{runs} // q{}) ne q{} ? ($ENV{runs} // q{}) : '1');
require Time::HiRes; Time::HiRes::sleep('10');
    for (eval { int($ENV{i}=1) } // ""; eval { int($ENV{i}<=$RunHowManyTimes) } // ""; eval { int($ENV{i}++) } // "") {
            $CHILD_ERROR = 0;
    }
my $signal = 'TERM';
my @pids = ($MonitoringPID);
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
    print "\nMonitoring output recorded while running the benchmark:\n" . "\n";
    $CHILD_ERROR = 0;
open STDIN, '<', $MonitoringOutput or croak "Cannot open file: $OS_ERROR\n";
my @sed_lines_299 = split /\n/msx, $;
my @sed_result_299;
foreach my $line (@sed_lines_299) {
chomp $line;
push @sed_result_299, $line;
}
$ = join "\n", @sed_result_299;

    print "\n" . "\n";
    $CHILD_ERROR = 0;
    return;
}
Main("@ARGV");

exit $main_exit_code;
