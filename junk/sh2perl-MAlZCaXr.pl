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

my $port;
my @port;
my %port;
my $INTERFACE;
my @INTERFACE;
my %INTERFACE;
my $BRIDGE_HOTPLUG;
my @BRIDGE_HOTPLUG;
my %BRIDGE_HOTPLUG;
my $i;
my @i;
my %i;

$__set_e = 1;
if ("$INTERFACE" eq q{}) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "missing $INTERFACE";
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
$BRIDGE_HOTPLUG = 'no';
if ((-f '/etc/default/bridge-utils')) {
        $main_exit_code = system('.', '/etc/default/bridge-utils') >> 8;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
if ("$BRIDGE_HOTPLUG" eq "no") {
    exit 0;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
$main_exit_code = system('.', '/lib/bridge-utils/bridge-utils.sh') >> 8;
if ((-d '/run/network')) {
    for my $i (do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'ifquery', '--list', '--allow', 'auto');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
}) {
        my $ports;
        my @ports;
        my %ports;
        $ports = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_1 = q{};
            my $output_printed_1;
            my $pipeline_success_1 = 1;

            my ($in_2, $out_2);
            my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'ifquery', );
            close $in_2 or croak 'Close failed: $OS_ERROR';
            $output_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
            close $out_2 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_2, 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_1 = 0; }
            my @sed_lines_1 = split /\n/msx, $output_1;
            my @sed_result_1;
            foreach my $line (@sed_lines_1) {
            chomp $line;
            push @sed_result_1, $line;
            }
            $output_1 = join "\n", @sed_result_1;

            if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            $output_1 =~ s/\n+\z//msx;
            $output_1;
}; $_pipeline_result; };
        for my $port (do {
    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'bridge_parse_ports', $ports);
    close $in_3 or croak 'Close failed: $OS_ERROR';
    my $result_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;
    $result_3
}) {
if ($port =~ /^$INTERFACE$/msx or $port =~ /^$INTERFACE..*$/msx) {
                                $main_exit_code = system('bash', 'create_vlan_port') >> 8;
                if ((-d '/sys/class/net/$port')) {
if ((!-d /sys/class/net/$i)) {
                        $main_exit_code = system('brctl', 'addbr', $i) >> 8;
                    }
                    if (do {
if (do {
$main_exit_code = system('brctl', 'addif', $i, $port) >> 8;
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('ip', 'link', 'set', 'dev', $port, 'up') >> 8;
}
                        $CHILD_ERROR == 0
                    }) {
                        if ((-e '/proc/sys/net/ipv6/conf/$port')) {
                            $main_exit_code = system('ip', 'link', 'set', $port, 'addrgenmode', 'none') >> 8;
                        }
                    }
if ("$(ifquery "$i"|sed -n -e's/^bridge[_-]hw: //p')" eq "$port") {
                        $main_exit_code = system('ip', 'link', 'set', 'dev', "$i", 'address', (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                            my $output_4 = q{};
                            my $output_printed_4;
                            my $pipeline_success_4 = 1;
                            my ($in_5, $out_5);
                            my $pid_5 = open3($in_5, $out_5, '>&STDERR', 'ip', 'link', 'show', 'dev');
                            close $in_5 or croak 'Close failed: $OS_ERROR';
                            $output_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
                            close $out_5 or croak 'Close failed: $OS_ERROR';
                            waitpid $pid_5, 0;
                            my @sed_lines_4 = split /\n/msx, $output_4;
                            my @sed_result_4;
                            foreach my $line (@sed_lines_4) {
                            chomp $line;
                            push @sed_result_4, $line;
                            }
                            $output_4 = join "\n", @sed_result_4;
                            if ( !$pipeline_success_4 ) { $main_exit_code = 1; }
                            exit $main_exit_code if $__set_e && $main_exit_code != 0;
                            $output_4 =~ s/\n+\z//msx;
                            $output_4;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; })) >> 8;
                    }
                    if (do {
$main_exit_code = system('brctl', 'addif', $i, $port) >> 8;
                        $CHILD_ERROR == 0
                    }) {
                                                $main_exit_code = system('ip', 'link', 'set', 'dev', $port, 'up') >> 8;
                    }
                }
                last;            }
        }
    }
}

exit $main_exit_code;
