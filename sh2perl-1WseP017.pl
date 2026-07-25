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

my $LKVER;
my @LKVER;
my %LKVER;
my $IF_BRIDGE_AGEING;
my @IF_BRIDGE_AGEING;
my %IF_BRIDGE_AGEING;
my $IF_BRIDGE_HW;
my @IF_BRIDGE_HW;
my %IF_BRIDGE_HW;
my $TRANSITIONED;
my @TRANSITIONED;
my %TRANSITIONED;
my $MAXWAIT;
my @MAXWAIT;
my %MAXWAIT;
my $IF_BRIDGE_FD;
my @IF_BRIDGE_FD;
my %IF_BRIDGE_FD;
my $IFACE;
my @IFACE;
my %IFACE;
my $IF_BRIDGE_VLAN_AWARE;
my @IF_BRIDGE_VLAN_AWARE;
my %IF_BRIDGE_VLAN_AWARE;
my $IF_BRIDGE_BRIDGEPRIO;
my @IF_BRIDGE_BRIDGEPRIO;
my %IF_BRIDGE_BRIDGEPRIO;
my $KVER;
my @KVER;
my %KVER;
my $IF_BRIDGE_WAITPORT;
my @IF_BRIDGE_WAITPORT;
my %IF_BRIDGE_WAITPORT;
my $IF_BRIDGE_STP;
my @IF_BRIDGE_STP;
my %IF_BRIDGE_STP;
my $IF_MTU;
my @IF_MTU;
my %IF_MTU;
my $COUNT;
my @COUNT;
my %COUNT;
my $MMAXWAIT;
my @MMAXWAIT;
my %MMAXWAIT;
my $WAIT;
my @WAIT;
my %WAIT;
my $port;
my @port;
my %port;
my $BREADY;
my @BREADY;
my %BREADY;
my $STARTTIME;
my @STARTTIME;
my %STARTTIME;
my $IF_BRIDGE_GCINT;
my @IF_BRIDGE_GCINT;
my %IF_BRIDGE_GCINT;
my $IF_BRIDGE_HELLO;
my @IF_BRIDGE_HELLO;
my %IF_BRIDGE_HELLO;
my $IF_BRIDGE_MAXAGE;
my @IF_BRIDGE_MAXAGE;
my %IF_BRIDGE_MAXAGE;
my $IF_BRIDGE_PORTPRIO;
my @IF_BRIDGE_PORTPRIO;
my %IF_BRIDGE_PORTPRIO;
my $NOTFOUND;
my @NOTFOUND;
my %NOTFOUND;
my $PHASE;
my @PHASE;
my %PHASE;
my $WAITPORT;
my @WAITPORT;
my %WAITPORT;
my $i;
my @i;
my %i;
my $MODE;
my @MODE;
my %MODE;
my $IF_BRIDGE_PATHCOST;
my @IF_BRIDGE_PATHCOST;
my %IF_BRIDGE_PATHCOST;
my $IF_BRIDGE_MAXWAIT;
my @IF_BRIDGE_MAXWAIT;
my %IF_BRIDGE_MAXWAIT;

if ((!-x /sbin/brctl)) {
exit 0;
}
if ((-f '/etc/default/bridge-utils')) {
        $main_exit_code = system('.', '/etc/default/bridge-utils') >> 8;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
$main_exit_code = system('.', '/lib/bridge-utils/bridge-utils.sh') >> 8;
if ("$ENV{IF_BRIDGE_PORTS}" =~ /^$/msx) {
    exit 0;
} elsif ("$ENV{IF_BRIDGE_PORTS}" =~ /^none$/msx) {
        my $INTERFACES;
    my @INTERFACES;
    my %INTERFACES;
    $INTERFACES = "";
} elsif (1) {
        $INTERFACES = "$ENV{IF_BRIDGE_PORTS}";
}
if ((("$IF_BRIDGE_HW") && !({
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;
        my @_pcmd_2 = ('bash', '-c', ": \"Complex command cannot be converted to shell command\"");
    my ($in_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', @_pcmd_2);
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $temp_result;
    $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    $output_0 = $temp_result;
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;

        my $grep_result_0_1;
    my @grep_lines_0_1 = split /\n/msx, $output_0;
    my @grep_filtered_0_1 = grep { /..:..:..:..:..:../msx } @grep_lines_0_1;
    $grep_result_0_1 = join "\n", @grep_filtered_0_1;
    if (!($grep_result_0_1 =~ m{\n\z}msx || $grep_result_0_1 eq q{})) {
    $grep_result_0_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_0_1 > 0 ? 0 : 1;
    $grep_result_0_1 = q{};
    $output_0 = q{};
    if ((scalar @grep_filtered_0_1) == 0) {
        $pipeline_success_0 = 0;
    }
    if ($output_0 ne q{} && !defined $output_printed_0) {
        print $output_0;
        if (!($output_0 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    }))) {
    $IF_BRIDGE_HW = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_3 = q{};
        my $output_printed_3;
        my $pipeline_success_3 = 1;
        my ($in_4, $out_4);
        my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'ip', 'link', 'show', 'dev');
        close $in_4 or croak 'Close failed: $OS_ERROR';
        $output_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
        close $out_4 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_4, 0;
        my @sed_lines_3 = split /\n/msx, $output_3;
        my @sed_result_3;
        foreach my $line (@sed_lines_3) {
        chomp $line;
        push @sed_result_3, $line;
        }
        $output_3 = join "\n", @sed_result_3;
        if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
        $output_3 =~ s/\n+\z//msx;
        $output_3;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
}
if (("$MODE" eq "start" && (!-d /sys/class/net/$IFACE))) {
        $main_exit_code = system('brctl', 'addbr', $IFACE) >> 8;
    if ($CHILD_ERROR != 0) {
        exit 1;
    }
if (("$IF_BRIDGE_HW")) {
require Time::HiRes; Time::HiRes::sleep(q{1});
        $main_exit_code = system('ip', 'link', 'set', 'dev', $IFACE, 'address', $IF_BRIDGE_HW) >> 8;
    }
if ("$IF_BRIDGE_VLAN_AWARE" eq "yes") {
        $main_exit_code = system('ip', 'link', 'set', 'dev', $IFACE, 'type', 'bridge', 'vlan_filtering', q{1}) >> 8;
}
    else {
        $main_exit_code = system('ip', 'link', 'set', 'dev', $IFACE, 'type', 'bridge', 'vlan_filtering', q{0}) >> 8;
    }
if (("$IF_BRIDGE_WAITPORT")) {
        if (do {
if (do {
if (do {
if (do {
if (do {
if (do {
if (do {
if (do {
if (do {
# set x not implemented
    $CHILD_ERROR == 0
}) {
    # Builtin command 'shift' not implemented
}
    $CHILD_ERROR == 0
}) {
        $WAIT = "$_[0]";
}
    $CHILD_ERROR == 0
}) {
    # Builtin command 'shift' not implemented
}
    $CHILD_ERROR == 0
}) {
        $WAITPORT = "@ARGV";
}
    $CHILD_ERROR == 0
}) {
    if ("$WAITPORT" eq q{}) {
        $WAITPORT = "$ENV{IF_BRIDGE_PORTS}";
    }
}
    $CHILD_ERROR == 0
}) {
        $STARTTIME = do {
require POSIX; POSIX::strftime('%s', localtime(time())) . "\n"
};
}
    $CHILD_ERROR == 0
}) {
        $NOTFOUND = "true";
}
    $CHILD_ERROR == 0
}) {
        do {
    my $__echo_line = "\nWaiting for a max of $WAIT seconds for $WAITPORT to become available.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
}
            $CHILD_ERROR == 0
        }) {
            while (1) {
                last unless ("(eval { int(do { chomp(my $_r eq qx'date +%s'); $_r; }-$STARTTIME) } // "")" -le "$WAIT");
                last unless ("$NOTFOUND" ne q{});
                $NOTFOUND = "";
                for my $i ($WAITPORT) {
if ((!-e "/sys/class/net/$i")) {
                        $NOTFOUND = "true";
                    }
                }
if ("$NOTFOUND" ne q{}) {
require Time::HiRes; Time::HiRes::sleep(q{1});
                }
            }
        }
    }
}
else {
    if ("$MODE" eq "stop") {
if ("$PHASE" eq "pre-down") {
            if (do {
if ((!-d /sys/class/net/$IFACE)) {
        $main_exit_code = system('brctl', 'addbr', $IFACE) >> 8;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
                $CHILD_ERROR == 0
            }) {
                                $main_exit_code = system('ip', 'address', 'add', "$ENV{IF_ADDRESS}", q{/}, "$ENV{IF_NETMASK}", 'dev', $IFACE) >> 8;
            }
}
        else {
            if ("$PHASE" eq "post-down") {
                                $main_exit_code = system('ip', 'link', 'set', 'dev', $IFACE, 'down') >> 8;
                if ($CHILD_ERROR != 0) {
                    exit 1;
                }
            }
        }
    }
}
if (do {
if (do {
my $all_interfaces;
my @all_interfaces;
my %all_interfaces;
$all_interfaces = q{};
    $CHILD_ERROR == 0
}) {
    undef $all_interfaces;
delete $ENV{all_interfaces};
}
    $CHILD_ERROR == 0
}) {
    {
        my $output_7 = q{};
        my $output_printed_7;
        my $pipeline_success_7 = 1;
                my ($in_8, $out_8);
        my $pid_8 = open3($in_8, $out_8, '>&STDERR', 'bridge_parse_ports', );
        close $in_8 or croak 'Close failed: $OS_ERROR';
        $output_7 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_8> };
        close $out_8 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_8, 0;

                my @lines = split /\n/msx, $output_7;
        my $result_7_1 = q{};
        for my $line (@lines) {
        chomp $line;
        my $L = $line;
        for my $port ($i) {
        if (("$MODE" eq "start" && (!-d /sys/class/net/$IFACE/brif/$port))) {
        $main_exit_code = system('bash', 'create_vlan_port') >> 8;
        if ((-e "/sys/class/net/$port")) {
        if (("$IF_BRIDGE_HW")) {
        $KVER = (do { my $_chomp_temp = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__rel; join(" ", @__parts) . "\n"; }; chomp $_chomp_temp; $_chomp_temp; });
        $LKVER = (${KVER} =~ s/^.*?\.//r =~ s/^.*?\.//r);
        $LKVER = (${LKVER} =~ s/-.*$//sr =~ s/-.*$//sr);
        $LKVER = (${LKVER} =~ s/\..*$//sr =~ s/\..*$//sr);
        if ((((${KVER%%.*} < 3) || (${KVER%%.*} == 3)) && ($LKVER < 3))) {
        $main_exit_code = system('ip', 'link', 'set', 'dev', $port, 'address', $IF_BRIDGE_HW) >> 8;
        }
        }
        if ((-e '/proc/sys/net/ipv6/conf/$port')) {
        $main_exit_code = system('ip', 'link', 'set', $port, 'addrgenmode', 'none') >> 8;
        }
        if (("$IF_MTU")) {
        $main_exit_code = system('ip', 'link', 'set', 'dev', $port, 'mtu', "$IF_MTU") >> 8;
        }
        if (do {
        $main_exit_code = system('brctl', 'addif', $IFACE, $port) >> 8;
        $CHILD_ERROR == 0
        }) {
        $main_exit_code = system('ip', 'link', 'set', 'dev', $port, 'up') >> 8;
        }
        }
        }
        else {
        if ((("$MODE" eq "stop" && "$PHASE" eq "post-down") && (-d '/sys/class/net/$IFACE/brif/$port'))) {
        if (do {
        if (do {
        $main_exit_code = system('ip', 'link', 'set', 'dev', $port, 'down') >> 8;
        $CHILD_ERROR == 0
        }) {
        $main_exit_code = system('brctl', 'delif', $IFACE, $port) >> 8;
        }
        $CHILD_ERROR == 0
        }) {
        $main_exit_code = system('bash', 'destroy_vlan_port') >> 8;
        }
        }
        }
        }
        }
        $output_7 = $result_7_1;
        if ($output_7 ne q{} && !defined $output_printed_7) {
            print $output_7;
            if (!($output_7 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_7 ) { $main_exit_code = 1; }
        }
}
if ("$MODE" eq "start") {
if (("$IF_BRIDGE_AGEING")) {
        $main_exit_code = system('brctl', 'setageing', $IFACE, $IF_BRIDGE_AGEING) >> 8;
    }
if (("$IF_BRIDGE_BRIDGEPRIO")) {
        $main_exit_code = system('brctl', 'setbridgeprio', $IFACE, $IF_BRIDGE_BRIDGEPRIO) >> 8;
    }
if (("$IF_BRIDGE_GCINT")) {
        $main_exit_code = system('brctl', 'setgcint', $IFACE, $IF_BRIDGE_GCINT) >> 8;
    }
if (("$IF_BRIDGE_HELLO")) {
        $main_exit_code = system('brctl', 'sethello', $IFACE, $IF_BRIDGE_HELLO) >> 8;
    }
if (("$IF_BRIDGE_MAXAGE")) {
        $main_exit_code = system('brctl', 'setmaxage', $IFACE, $IF_BRIDGE_MAXAGE) >> 8;
    }
if (("$IF_BRIDGE_PATHCOST")) {
        # Original bash: echo "$IF_BRIDGE_PATHCOST" | {
{
            my $output_9 = q{};
            my $output_printed_9;
            my $pipeline_success_9 = 1;
            $output_9 .= $IF_BRIDGE_PATHCOST . "\n";
if ( !($output_9 =~ m{\n\z}msx) ) { $output_9 .= "\n"; }
$CHILD_ERROR = 0;

                        my @_pcmd_11 = ('bash', '-c', "echo \"${output_9}\" | : \"Complex command cannot be converted to shell command\"");
            my ($in_10);
            my $pid_10 = open3($in_10, $out_10, '>&STDERR', @_pcmd_11);
            close $in_10 or croak 'Close failed: $OS_ERROR';
            my $temp_result;
            $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_10> };
            $output_9 = $temp_result;
            close $out_10 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_10, 0;
            if ($output_9 ne q{} && !defined $output_printed_9) {
                print $output_9;
                if (!($output_9 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_9 ) { $main_exit_code = 1; }
            }
    }
if (("$IF_BRIDGE_PORTPRIO")) {
        # Original bash: echo "$IF_BRIDGE_PORTPRIO" | {
{
            my $output_12 = q{};
            my $output_printed_12;
            my $pipeline_success_12 = 1;
            $output_12 .= $IF_BRIDGE_PORTPRIO . "\n";
if ( !($output_12 =~ m{\n\z}msx) ) { $output_12 .= "\n"; }
$CHILD_ERROR = 0;

                        my @_pcmd_14 = ('bash', '-c', "echo \"${output_12}\" | : \"Complex command cannot be converted to shell command\"");
            my ($in_13);
            my $pid_13 = open3($in_13, $out_13, '>&STDERR', @_pcmd_14);
            close $in_13 or croak 'Close failed: $OS_ERROR';
            my $temp_result;
            $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_13> };
            $output_12 = $temp_result;
            close $out_13 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_13, 0;
            if ($output_12 ne q{} && !defined $output_printed_12) {
                print $output_12;
                if (!($output_12 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_12 ) { $main_exit_code = 1; }
            }
    }
if (("$IF_BRIDGE_STP")) {
        $main_exit_code = system('brctl', 'stp', $IFACE, $IF_BRIDGE_STP) >> 8;
    }
if (("$IF_BRIDGE_FD")) {
        $main_exit_code = system('brctl', 'setfd', $IFACE, $IF_BRIDGE_FD) >> 8;
    }
    $main_exit_code = system('ip', 'link', 'set', 'dev', $IFACE, 'up') >> 8;
if (("$IF_BRIDGE_MAXWAIT")) {
        $MAXWAIT = $IF_BRIDGE_MAXWAIT;
}
    else {
        $MAXWAIT = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_15 = q{};
            my $output_printed_15;
            my $pipeline_success_15 = 1;
            my ($in_16, $out_16);
            my $pid_16 = open3($in_16, $out_16, '>&STDERR', 'brctl', 'showstp');
            close $in_16 or croak 'Close failed: $OS_ERROR';
            $output_15 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_16> };
            close $out_16 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_16, 0;
            my @sed_lines_15 = split /\n/msx, $output_15;
            my @sed_result_15;
            foreach my $line (@sed_lines_15) {
            chomp $line;
            push @sed_result_15, $line;
            }
            $output_15 = join "\n", @sed_result_15;
            if ( !$pipeline_success_15 ) { $main_exit_code = 1; }
            $output_15 =~ s/\n+\z//msx;
            $output_15;
}; $_pipeline_result; };
if (("$MAXWAIT")) {
if ((${MAXWAIT% *} > ${MAXWAIT#*)) {
                $MAXWAIT = eval { int(2*(${MAXWAIT% *}+1)))) } // "";
}
            else {
                $MAXWAIT = eval { int(2*(${MAXWAIT#* }+1)))) } // "";
            }
}
        else {
if (("$IF_BRIDGE_FD")) {
                $MAXWAIT = eval { int(2*(${IF_BRIDGE_FD%.*}+1)))) } // "";
}
            else {
                $MAXWAIT = '32';
            }
            do {
    my $__echo_line = "\nWaiting $MAXWAIT seconds for $IFACE to get ready.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
require Time::HiRes; Time::HiRes::sleep($MAXWAIT);
            $MAXWAIT = q{0};
        }
    }
if ("$MAXWAIT" ne 0) {
delete $ENV{BREADY};
delete $ENV{TRANSITIONED};
        $COUNT = q{0};
        $MMAXWAIT = $MAXWAIT;
        if (do {
                        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
require Time::HiRes; Time::HiRes::sleep('0.1');
            };
        } == 0) {
                        $MMAXWAIT = eval { int($MAXWAIT * 10) } // "";
        }
while ( (!"$BREADY") && ($COUNT < $MMAXWAIT) ) {
                        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
require Time::HiRes; Time::HiRes::sleep('0.1');
            };
            if ($CHILD_ERROR != 0) {
                require Time::HiRes; Time::HiRes::sleep(q{1});
            }
            if (defined $COUNT) {
                $COUNT = eval { int($COUNT+1) } // "";
            }
            $BREADY = 'true';
            for my $i (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_21 = q{};
                my $output_printed_21;
                my $pipeline_success_21 = 1;

                my ($in_22, $out_22);
                my $pid_22 = open3($in_22, $out_22, '>&STDERR', 'brctl', 'showstp');
                close $in_22 or croak 'Close failed: $OS_ERROR';
                $output_21 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_22> };
                close $out_22 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_22, 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_21 = 0; }
                my @sed_lines_21 = split /\n/msx, $output_21;
                my @sed_result_21;
                foreach my $line (@sed_lines_21) {
                chomp $line;
                push @sed_result_21, $line;
                }
                $output_21 = join "\n", @sed_result_21;

                if ( !$pipeline_success_21 ) { $main_exit_code = 1; }
                $output_21 =~ s/\n+\z//msx;
                $output_21;
}; $_pipeline_result; }) {
if (0) {
                    $TRANSITIONED = 'true';
                }
if ((("$i" ne "forwarding" && "$i" ne "blocking") && ((!"$TRANSITIONED") || "$i" ne "disabled"))) {
delete $ENV{BREADY};
                }
            }
if (((!"$BREADY") && $COUNT eq 2)) {
                do {
    my $__echo_line = "\nWaiting for $IFACE to get ready (MAXWAIT is $MAXWAIT seconds).";
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
    }
}
else {
    if (("$MODE" eq "stop" && "$PHASE" eq "post-down")) {
        $main_exit_code = system('brctl', 'delbr', $IFACE) >> 8;
    }
}

exit $main_exit_code;
