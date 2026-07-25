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

my $ENABLE;
my @ENABLE;
my %ENABLE;
my $MODULE;
my @MODULE;
my %MODULE;

my $PATH;
my @PATH;
my %PATH;
$PATH = '/sbin:/bin:/usr/sbin:/usr/bin';
my $NAME;
my @NAME;
my %NAME;
$NAME = 'loadcpufreq';
$main_exit_code = system('.', '/lib/lsb/init-functions') >> 8;
if ((-f '/etc/default/rcS')) {
        $main_exit_code = system('.', '/etc/default/rcS') >> 8;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
$ENABLE = "true";
if ((-f '/etc/default/loadcpufreq')) {
        $main_exit_code = system('.', '/etc/default/loadcpufreq') >> 8;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
$__set_e = 1;
if (!("$ENABLE" eq "true")) {
    exit 0;
}
my $MODPROBE;
my @MODPROBE;
my %MODPROBE;
$MODPROBE = "modprobe -b";

sub load_detected_cpufreq_modules {
    my $CPUINFO;
    my @CPUINFO;
    my %CPUINFO;
    $CPUINFO = '/proc/cpuinfo';
    my $IOPORTS;
    my @IOPORTS;
    my %IOPORTS;
    $IOPORTS = '/proc/ioports';
if ((!-f $CPUINFO)) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "$CPUINFO not detected...";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
return;
    }
    my $MODEL_NAME;
    my @MODEL_NAME;
    my %MODEL_NAME;
    $MODEL_NAME = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_0 = q{};
    my $output_printed_0;
    my $head_line_count = 0;
    my $output_1 = q{};
    while (my $line = <>) {
        chomp $line;
                if (!($line =~ /^model\ name/msx)) {
            next;
        }
        if ($head_line_count < 1) {
    $output_1 .= $line . "\n";
    ++$head_line_count;
} else {
    $line = q{}; # Clear line to prevent printing
    last; # Break out of the yes loop when head limit is reached
}
        $line =~ 's/^.*: //;';
    }
    $output_1; };
}; $_pipeline_result; };
    my $MODEL_ID;
    my @MODEL_ID;
    my %MODEL_ID;
    $MODEL_ID = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_2 = q{};
    my $output_printed_2;
    my $head_line_count = 0;
    my $output_3 = q{};
    while (my $line = <>) {
        chomp $line;
                if (!($line =~ /^model[[:space:]]+:/msx)) {
            next;
        }
        if ($head_line_count < 1) {
    $output_3 .= $line . "\n";
    ++$head_line_count;
} else {
    $line = q{}; # Clear line to prevent printing
    last; # Break out of the yes loop when head limit is reached
}
        $line =~ 's/^.*: //;';
    }
    $output_3; };
}; $_pipeline_result; };
    my $CPU;
    my @CPU;
    my %CPU;
    $CPU = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_4 = q{};
    my $output_printed_4;
    my $head_line_count = 0;
    my $output_5 = q{};
    while (my $line = <>) {
        chomp $line;
                if (!($line =~ /^cpud[^:]+:/msx)) {
            next;
        }
        if ($head_line_count < 1) {
    $output_5 .= $line . "\n";
    ++$head_line_count;
} else {
    $line = q{}; # Clear line to prevent printing
    last; # Break out of the yes loop when head limit is reached
}
        $line =~ 's/^.*: //;';
    }
    $output_5; };
}; $_pipeline_result; };
    my $VENDOR_ID;
    my @VENDOR_ID;
    my %VENDOR_ID;
    $VENDOR_ID = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_6 = q{};
    my $output_printed_6;
    my $head_line_count = 0;
    my $output_7 = q{};
    while (my $line = <>) {
        chomp $line;
                if (!($line =~ /^vendor_id[^:]+:/msx)) {
            next;
        }
        if ($head_line_count < 1) {
    $output_7 .= $line . "\n";
    ++$head_line_count;
} else {
    $line = q{}; # Clear line to prevent printing
    last; # Break out of the yes loop when head limit is reached
}
        $line =~ 's/^.*: //;';
    }
    $output_7; };
}; $_pipeline_result; };
    my $CPU_FAMILY;
    my @CPU_FAMILY;
    my %CPU_FAMILY;
    $CPU_FAMILY = do { my @_qx_cmd = (q(sed -e '/^cpu family/ {s/.*: //;p;Q};d' $CPUINFO)); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
    $MODULE = q{};
    my $MODULE_FALLBACK;
    my @MODULE_FALLBACK;
    my %MODULE_FALLBACK;
    $MODULE_FALLBACK = 'acpi-cpufreq';
if (((-f $IOPORTS) && !(my $grep_result_8;
my @grep_lines_8 = ();
my @grep_filtered_8 = grep { /Intel\ .*ICH/msx } @grep_lines_8;
$grep_result_8 = join "\n", @grep_filtered_8;
    if (!($grep_result_8 =~ m{\n\z}msx || $grep_result_8 eq q{})) {
        $grep_result_8 .= "\n";
    }
$CHILD_ERROR = scalar @grep_filtered_8 > 0 ? 0 : 1;
$grep_result_8 = q{}))) {
        my $PIII_MODULE;
        my @PIII_MODULE;
        my %PIII_MODULE;
        $PIII_MODULE = 'speedstep-ich';
}
    else {
        $PIII_MODULE = 'speedstep-smi';
    }
if ("$VENDOR_ID" =~ /^GenuineIntel.*$/msx) {
        if ((qx'grep est $CPUINFO' ne q{})) {
            $MODULE = 'acpi-cpufreq';
}
        else {
            if ($CPU_FAMILY eq 15) {
                $MODULE = 'speedstep-ich';
}
            else {
if ("$MODEL_NAME" =~ /^Intel\(R\)\ Pentium\(R\)\ III\ Mobile\ CPU.*$/msx) {
                                        $MODULE = $PIII_MODULE;
                } elsif ("$MODEL_NAME" =~ /^Mobile\ Intel\(R\)\ Pentium\(R\)\ III\ CPU\ -\ M.*$/msx) {
                                        $MODULE = $PIII_MODULE;
                } elsif ("$MODEL_NAME" =~ /^Pentium\ III\ \(Coppermine\).*$/msx) {
                                        $MODULE = $PIII_MODULE;
                }
            }
        }
    } elsif ("$VENDOR_ID" =~ /^AuthenticAMD.*$/msx) {
        if ($CPU_FAMILY =~ /^5$/msx) {
                        $MODULE = 'powernow-k6';
        } elsif ($CPU_FAMILY =~ /^6$/msx) {
                        $MODULE = 'powernow-k7';
        } elsif ($CPU_FAMILY =~ /^15$/msx or $CPU_FAMILY =~ /^16$/msx or $CPU_FAMILY =~ /^17$/msx or $CPU_FAMILY =~ /^18$/msx or $CPU_FAMILY =~ /^20$/msx or $CPU_FAMILY =~ /^21$/msx) {
                        $MODULE = 'powernow-k8';
        }
    } elsif ("$VENDOR_ID" =~ /^CentaurHauls.*$/msx) {
        if ($CPU_FAMILY eq 6) {
if ($MODEL_ID =~ /^10$/msx) {
                                $MODULE = 'acpi_cpufreq';
            } elsif (1) {
                                $MODULE = 'longhaul';
            }
        }
    } elsif ("$VENDOR_ID" =~ /^GenuineTMx86.*$/msx) {
        if ((qx'grep longrun $CPUINFO' ne q{})) {
            $MODULE = 'longrun';
        }
    }
    return;
}

sub load_modules {
    my $LIST;
    my @LIST;
    my %LIST;
    $LIST = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_9 = q{};
        my $output_printed_9;
        my $pipeline_success_9 = 1;

        my ($in_10, $out_10);
        my $pid_10 = open3($in_10, $out_10, '>&STDERR', '/sbin/lsmod', );
        close $in_10 or croak 'Close failed: $OS_ERROR';
        $output_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_10> };
        close $out_10 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_10, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_9 = 0; }
        my @lines = split /\n/msx, $output_9;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\s+/msx, $line;
            if (!(!/Module/)) { next; }
            push @result, ($fields[0] . "\n");
        }
        $output_9 = join "", @result;

        if ( !$pipeline_success_9 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        $output_9 =~ s/\n+\z//msx;
        $output_9;
}; $_pipeline_result; };
    my $LOC;
    my @LOC;
    my %LOC;
    $LOC = "/lib/modules/" . (do { my $_chomp_temp = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__rel; join(" ", @__parts) . "\n"; }; chomp $_chomp_temp; $_chomp_temp; }) . "/kernel/drivers/cpufreq";
if ((-d $LOC)) {
        my $MODAVAIL;
        my @MODAVAIL;
        my %MODAVAIL;
        $MODAVAIL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_11 = q{};
            my $output_printed_11;
            my $pipeline_success_11 = 1;
            $output_11 = q{};
            my @_pcmd_13 = ('sh', '-c', q{find $LOC -type f -name 'cpufreq_*.o' -p rintf "basename %f .o\\n"});
            my ($in_12, $out_12);
            my $pid_12 = open3($in_12, $out_12, '>&STDERR', @_pcmd_13);
            close $in_12 or croak 'Close failed: $OS_ERROR';
            $output_11 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_12> };
            close $out_12 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_12, 0;
            my @_pcmd_15 = ('sh', '-c', q{find $LOC -type f -name 'cpufreq_*.ko' -p rintf "basename %f .ko\\n"});
            my ($in_14, $out_14);
            my $pid_14 = open3($in_14, $out_14, '>&STDERR', @_pcmd_15);
            close $in_14 or croak 'Close failed: $OS_ERROR';
            $output_11 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_14> };
            close $out_14 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_14, 0;
            my $cmd_17 = '/bin/sh';
            my ($in_16, $out_16);
            my $pid_16 = open3($in_16, $out_16, '>&STDERR', $cmd_17, );
            print {$in_16} $output_11;
            close $in_16 or croak 'Close failed: $OS_ERROR';
            $output_11 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_16> };
            close $out_16 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_16, 0;
            if ( !$pipeline_success_11 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            $output_11 =~ s/\n+\z//msx;
            $output_11;
}; $_pipeline_result; };
}
    else {
        $MODAVAIL = "";
    }
    my $mod;
    for my $mod ($MODAVAIL) {
                {
            my $output_18 = q{};
            my $output_printed_18;
            my $pipeline_success_18 = 1;
            $output_18 .= $LIST . "\n";
if ( !($output_18 =~ m{\n\z}msx) ) { $output_18 .= "\n"; }
$CHILD_ERROR = 0;

                        my $grep_result_18_1;
            my @grep_lines_18_1 = split /\n/msx, $output_18;
            my @grep_filtered_18_1 = grep { /$mod/msx } @grep_lines_18_1;
            $grep_result_18_1 = join "\n", @grep_filtered_18_1;
            if (!($grep_result_18_1 =~ m{\n\z}msx || $grep_result_18_1 eq q{})) {
            $grep_result_18_1 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_18_1 > 0 ? 0 : 1;
            $grep_result_18_1 = q{};
            $output_18 = q{};
            if ((scalar @grep_filtered_18_1) == 0) {
                $pipeline_success_18 = 0;
            }
            if ($output_18 ne q{} && !defined $output_printed_18) {
                print $output_18;
                if (!($output_18 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_18 ) { $main_exit_code = 1; }
            }
        if ($CHILD_ERROR != 0) {
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
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
        }
        if ($CHILD_ERROR != 0) {
                        $main_exit_code = system('/bin/', 'true') >> 8;
        }
    }
if ("$(uname -m)" eq "ppc") {
return q{0};
    }
if (!"$FREQDRIVER" eq "") {
        $CHILD_ERROR = 0;
        $MODULE = "$ENV{FREQDRIVER}";
}
    else {
        load_detected_cpufreq_modules();
if ((! "$MODULE" eq q{} || ! "$MODULE_FALLBACK" eq q{})) {
if ((! "$MODULE" eq q{} && !(            do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                $CHILD_ERROR = 0;
            }))) {
                $main_exit_code = system('bash', ':') >> 8;
}
            else {
                if (!(                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                    $CHILD_ERROR = 0;
                })) {
                    $MODULE = "$ENV{MODULE_FALLBACK}";
}
                else {
delete $ENV{MODULE};
                }
            }
        }
    }
    return;
}

sub check_kernel {
    my $CPUFREQ;
    my @CPUFREQ;
    my %CPUFREQ;
    $CPUFREQ = "/sys/devices/" . "sys" . "tem" . "/cpu/cpu0/cpufreq";
if (("$MODULE" eq q{} || !(    do {
        local %ENV = %ENV;
        my $NAME = $NAME;
        my $MODPROBE = $MODPROBE;
        my $PATH = $PATH;
        my $CPUFREQ = $CPUFREQ;
        if ((-f "$CPUFREQ/scaling_governor")) {
            (-f "$CPUFREQ/scaling_available_governors")            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        q{};
    }))) {
return q{0};
}
    else {
return q{1};
    }
    return;
}
if ("$_[0]" =~ /^start$/msx) {
        $main_exit_code = system('log_action_begin_msg', "Loading cpufreq kernel modules") >> 8;
        if ((-f '/proc/modules')) {
                load_modules();
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if (!(    check_kernel())) {
        if ("$MODULE" eq q{}) {
                        $MODULE = "none";
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        $main_exit_code = system('log_action_end_msg', q{0}, "$MODULE") >> 8;
}
    else {
        $main_exit_code = system('log_action_end_msg', q{1}) >> 8;
    }
} elsif ("$_[0]" =~ /^stop$/msx) {
} elsif ("$_[0]" =~ /^restart$/msx or "$_[0]" =~ /^force-reload$/msx) {
        $CHILD_ERROR = 0;
    require Time::HiRes; Time::HiRes::sleep(q{1});
        $CHILD_ERROR = 0;
} elsif (1) {
        my $N;
    my @N;
    my %N;
    $N = '/etc/init.d/';
        $CHILD_ERROR = 0;
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        $main_exit_code = system('log_success_msg', "Usage: $N {start|stop|restart|force-reload}") >> 8;
    };
    exit 1;
}
exit 0;

exit $main_exit_code;
