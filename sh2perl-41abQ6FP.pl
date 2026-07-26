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

my $KVER_MAJOR;
my @KVER_MAJOR;
my %KVER_MAJOR;
my $file;
my @file;
my %file;
my $KVER_MINOR;
my @KVER_MINOR;
my %KVER_MINOR;
my $MODULEFILE;
my @MODULEFILE;
my %MODULEFILE;
my $HEADERS_CONFIG;
my @HEADERS_CONFIG;
my %HEADERS_CONFIG;
my $f;
my @f;
my %f;
my $CGROUP_V2_MNTS;
my @CGROUP_V2_MNTS;
my %CGROUP_V2_MNTS;
my $CGROUP_FREEZER_MNTPT;
my @CGROUP_FREEZER_MNTPT;
my %CGROUP_FREEZER_MNTPT;
my $CONFIG;
my @CONFIG;
my %CONFIG;
my $BOOT_CONFIG;
my @BOOT_CONFIG;
my %BOOT_CONFIG;
my $CGROUP_SYSTEMD_MNTPT;
my @CGROUP_SYSTEMD_MNTPT;
my %CGROUP_SYSTEMD_MNTPT;
my $CGROUP_MNT_PATH;
my @CGROUP_MNT_PATH;
my %CGROUP_MNT_PATH;

$ENV{LC_ALL} = 'C.UTF-8';
$ENV{LANGUAGE} = 'en';
$main_exit_code = system(':', (defined ${CONFIG} && ${CONFIG} ne q{} ? ${CONFIG} : do { $CONFIG = '/proc/config.gz'; ${CONFIG} })) >> 8;
$main_exit_code = system(':', (defined ($ENV{MODNAME} // q{}) && ($ENV{MODNAME} // q{}) ne q{} ? ($ENV{MODNAME} // q{}) : do { $ENV{MODNAME} = 'configs'; ($ENV{MODNAME} // q{}) })) >> 8;
my $GREP;
my @GREP;
my %GREP;
$GREP = "grep";
if ((-t1)) {
    my $SETCOLOR_SUCCESS;
    my @SETCOLOR_SUCCESS;
    my %SETCOLOR_SUCCESS;
    $SETCOLOR_SUCCESS = "printf \033[1;32m";
    my $SETCOLOR_FAILURE;
    my @SETCOLOR_FAILURE;
    my %SETCOLOR_FAILURE;
    $SETCOLOR_FAILURE = "printf \033[1;31m";
    my $SETCOLOR_WARNING;
    my @SETCOLOR_WARNING;
    my %SETCOLOR_WARNING;
    $SETCOLOR_WARNING = "printf \033[1;33m";
    my $SETCOLOR_NORMAL;
    my @SETCOLOR_NORMAL;
    my %SETCOLOR_NORMAL;
    $SETCOLOR_NORMAL = "printf \033[0;39m";
}
else {
    $SETCOLOR_SUCCESS = ":";
    $SETCOLOR_FAILURE = ":";
    $SETCOLOR_WARNING = ":";
    $SETCOLOR_NORMAL = ":";
}

sub is_set {
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
return $?;
    return;
}

sub show_enabled {
    my $RES;
    my @RES;
    my %RES;
    $RES = $1;
    my $RET;
    my @RET;
    my %RET;
    $RET = q{1};
if (($RES == 0)) {
        if (do {
if (do {
$CHILD_ERROR = 0;
    $CHILD_ERROR == 0
}) {
    printf('enabled');
}
            $CHILD_ERROR == 0
        }) {
                        $CHILD_ERROR = 0;
        }
        $RET = q{0};
}
    else {
if (("$mandatory" ne q{} && "$mandatory" eq yes)) {
            if (do {
if (do {
$CHILD_ERROR = 0;
    $CHILD_ERROR == 0
}) {
    printf('required');
}
                $CHILD_ERROR == 0
            }) {
                                $CHILD_ERROR = 0;
            }
}
        else {
            if (do {
if (do {
$CHILD_ERROR = 0;
    $CHILD_ERROR == 0
}) {
    printf('missing');
}
                $CHILD_ERROR == 0
            }) {
                                $CHILD_ERROR = 0;
            }
        }
    }
return $RET;
    return;
}

sub is_enabled {
    my ($file) = @_;
    my $mandatory;
    my @mandatory;
    my %mandatory;
    $mandatory = $2;
    is_set("$_[0]");
    show_enabled($?);
    return;
}

sub has_cgroup_ns {
    my $mandatory;
    my @mandatory;
    my %mandatory;
    $mandatory = 'no';
if ((-f "/proc/self/ns/cgroup")) {
        show_enabled(q{0});
}
    else {
        show_enabled(q{1});
    }
    return;
}

sub is_probed {
if ((!-f /proc/modules)) {
return;
    }
if (!(    # Original bash: lsmod | grep -wm1 "^${1}" > /dev/null;
{
        my $output_3 = q{};
        my $output_printed_3;
        my $pipeline_success_3 = 1;
                my ($in_4, $out_4);
        my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'lsmod', );
        close $in_4 or croak 'Close failed: $OS_ERROR';
        $output_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
        close $out_4 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_4, 0;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_5 = q{};
        my $grep_result_6;
        my @grep_lines_6 = split /\n/msx, $output_3;
        my @grep_filtered_6 = grep { /m1/msx } @grep_lines_6;
        $grep_result_6 = join "\n", @grep_filtered_6;
        if (!($grep_result_6 =~ m{\n\z}msx || $grep_result_6 eq q{})) {
        $grep_result_6 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_6 > 0 ? 0 : 1;
        $tmp_redirect_5 = $grep_result_6;
        $tmp_redirect_5;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_3; }
        $output_printed_3 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
        })) {
printf(', loaded');
}
    else {
printf(', not loaded');
    }
    return;
}
if (!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('command', '-v', 'lxc-start') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
})) {
    do {
    my $__echo_line = "LXC version " . (do { my $_chomp_temp = do {
    my ($in_9, $out_9);
    my $pid_9 = open3($in_9, $out_9, '>&STDERR', 'lxc-start', '--version');
    close $in_9 or croak 'Close failed: $OS_ERROR';
    my $result_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_9> };
    close $out_9 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_9, 0;
    $result_9
}; chomp $_chomp_temp; $_chomp_temp; });
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
}
if ((!-f "${CONFIG}")) {
    do {
    my $__echo_line = "Kernel configuration not found at $CONFIG; searching...";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    my $KVER;
    my @KVER;
    my %KVER;
    $KVER = (do { my $_chomp_temp = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__rel; join(" ", @__parts) . "\n"; }; chomp $_chomp_temp; $_chomp_temp; });
    $HEADERS_CONFIG = "/lib/modules/$KVER/build/.config";
    $BOOT_CONFIG = "/boot/config-$KVER";
    if ((-f "${HEADERS_CONFIG}")) {
                $CONFIG = $HEADERS_CONFIG;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ((-f "${BOOT_CONFIG}")) {
                $CONFIG = $BOOT_CONFIG;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
if ((!-f "$CONFIG")) {
        $MODULEFILE = (do { my $_chomp_temp = do { my @_qx_cmd = ("modinfo -k \"$KVER\" -n \"$MODNAME\" 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }; chomp $_chomp_temp; $_chomp_temp; });
    }
if ((!-f "$CONFIG")) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename("$PROGRAM_NAME"); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; }) . ": unable to retrieve kernel configuration";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "\n";
            $CHILD_ERROR = 0;
        };
if ((-f "$MODULEFILE")) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "Try modprobe $ENV{MODNAME} module, or";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
            };
        }
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "Try recompiling with IKCONFIG_PROC, installing the kernel headers,\n";
        };
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "or specifying the kernel configuration path with:\n";
        };
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "  CONFIG=<path> " . (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename("$PROGRAM_NAME"); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; });
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
    else {
        do {
    my $__echo_line = "Kernel configuration found at $CONFIG";
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
if (!(open STDIN, '<', "$CONFIG" or croak "Cannot open file: $OS_ERROR\n";
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('gunzip', '-t') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
})) {
    $GREP = "zgrep";
}
$KVER_MAJOR = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_10 = q{};
    my $output_printed_10;
    my $pipeline_success_10 = 1;

    my ($in_11, $out_11);
    my $pid_11 = open3($in_11, $out_11, '>&STDERR', 'unknown_command', '-m1', '^# Linux.*Kernel Configuration');
    close $in_11 or croak 'Close failed: $OS_ERROR';
    $output_10 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_11> };
    close $out_11 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_11, 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_10 = 0; }
    my @sed_lines_10 = split /\n/msx, $output_10;
    my @sed_result_10;
    foreach my $line (@sed_lines_10) {
    chomp $line;
    push @sed_result_10, $line;
    }
    $output_10 = join "\n", @sed_result_10;

    if ( !$pipeline_success_10 ) { $main_exit_code = 1; }
    $output_10 =~ s/\n+\z//msx;
    $output_10;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
if ("$KVER_MAJOR" eq "2") {
    $KVER_MINOR = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_12 = q{};
        my $output_printed_12;
        my $pipeline_success_12 = 1;

        my ($in_13, $out_13);
        my $pid_13 = open3($in_13, $out_13, '>&STDERR', 'unknown_command', '-m1', '^# Linux.*Kernel Configuration');
        close $in_13 or croak 'Close failed: $OS_ERROR';
        $output_12 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_13> };
        close $out_13 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_13, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_12 = 0; }
        my @sed_lines_12 = split /\n/msx, $output_12;
        my @sed_result_12;
        foreach my $line (@sed_lines_12) {
        chomp $line;
        push @sed_result_12, $line;
        }
        $output_12 = join "\n", @sed_result_12;

        if ( !$pipeline_success_12 ) { $main_exit_code = 1; }
        $output_12 =~ s/\n+\z//msx;
        $output_12;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
}
else {
    $KVER_MINOR = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_14 = q{};
        my $output_printed_14;
        my $pipeline_success_14 = 1;

        my ($in_15, $out_15);
        my $pid_15 = open3($in_15, $out_15, '>&STDERR', 'unknown_command', '-m1', '^# Linux.*Kernel Configuration');
        close $in_15 or croak 'Close failed: $OS_ERROR';
        $output_14 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_15> };
        close $out_15 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_15, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_14 = 0; }
        my @sed_lines_14 = split /\n/msx, $output_14;
        my @sed_result_14;
        foreach my $line (@sed_lines_14) {
        chomp $line;
        push @sed_result_14, $line;
        }
        $output_14 = join "\n", @sed_result_14;

        if ( !$pipeline_success_14 ) { $main_exit_code = 1; }
        $output_14 =~ s/\n+\z//msx;
        $output_14;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
}
if ("${KVER_MAJOR}" eq q{}) {
    print "WARNING: Unable to detect version from configuration, assuming latest\n";
    print "\n";
    $CHILD_ERROR = 0;
    $KVER_MAJOR = "100";
    $KVER_MINOR = "0";
}
print "
--- Namespaces ---\n";
if (do {
printf('Namespaces: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_NAMESPACES', 'yes');
}
print "\n";
$CHILD_ERROR = 0;
if (do {
printf('Utsname namespace: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_UTS_NS');
}
print "\n";
$CHILD_ERROR = 0;
if (do {
printf('Ipc namespace: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_IPC_NS', 'yes');
}
print "\n";
$CHILD_ERROR = 0;
if (do {
printf('Pid namespace: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_PID_NS', 'yes');
}
print "\n";
$CHILD_ERROR = 0;
if (do {
printf('User namespace: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_USER_NS');
}
print "\n";
$CHILD_ERROR = 0;
if (!(is_set('CONFIG_USER_NS'))) {
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('command', '-v', 'newuidmap') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
        $f = do {
    my ($in_21, $out_21);
    my $pid_21 = open3($in_21, $out_21, '>&STDERR', 'command', '-v', 'newuidmap');
    close $in_21 or croak 'Close failed: $OS_ERROR';
    my $result_21 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_21> };
    close $out_21 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_21, 0;
    $result_21
};
if ((! -u "${f}")) {
            print "Warning: newuidmap is not setuid-root\n";
        }
}
    else {
        print "newuidmap is not installed\n";
    }
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('command', '-v', 'newgidmap') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
        $f = do {
    my ($in_22, $out_22);
    my $pid_22 = open3($in_22, $out_22, '>&STDERR', 'command', '-v', 'newgidmap');
    close $in_22 or croak 'Close failed: $OS_ERROR';
    my $result_22 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_22> };
    close $out_22 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_22, 0;
    $result_22
};
if ((! -u "${f}")) {
            print "Warning: newgidmap is not setuid-root\n";
        }
}
    else {
        print "newgidmap is not installed\n";
    }
}
if (do {
printf('Network namespace: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_NET_NS');
}
print "\n";
$CHILD_ERROR = 0;
if (((${KVER_MAJOR} < 4) || !(    if ((${KVER_MAJOR} == 4)) {
        (${KVER_MINOR} < 7)        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }))) {
    if (do {
printf('Multiple /dev/pts instances: ');
        $CHILD_ERROR == 0
    }) {
                is_enabled('DEVPTS_MULTIPLE_INSTANCES');
    }
    print "\n";
    $CHILD_ERROR = 0;
}
print "Namespace limits:\n";
for my $file ('/proc/sys/user/max_*_namespaces') {
    if (!((-r "${file}"))) {
        next;    }
    my $ns_name;
    my @ns_name;
    my %ns_name;
    $ns_name = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_25 = q{};
    my $output_printed_25;
    my $output_26 = q{};
    while (my $line = <>) {
        chomp $line;
        # basename doesn't support line-by-line processing
            }
    $output_26; };
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
printf('  %s: %s', ${ns_name}, (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', ${file} ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . ${file} . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; }));
    print "\n";
    $CHILD_ERROR = 0;
}
print "
--- Control groups ---\n";
if (do {
printf('Cgroups: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_CGROUPS');
}
print "\n";
$CHILD_ERROR = 0;
if (do {
printf('Cgroup namespace: ');
    $CHILD_ERROR == 0
}) {
        has_cgroup_ns();
}
print "\n";
$CHILD_ERROR = 0;

sub print_cgroups {
    my ($file) = @_;
my @lines = split /\n/msx, $;
my @result;
foreach my $line (@lines) {
    chomp $line;
    if ($line =~ /^\s*$/msx) { next; }
    my @fields = split /\s+/msx, $line;
    if (!($fields[0] !~ /#/ && $fields[2] == mp)) { next; }
    push @result, ($fields[1] . "\n");
}
$ = join "", @result;

    return;
}
my $CGROUP_V1_MNTS;
my @CGROUP_V1_MNTS;
my %CGROUP_V1_MNTS;
$CGROUP_V1_MNTS = do {
    my ($in_31, $out_31);
    my $pid_31 = open3($in_31, $out_31, '>&STDERR', 'print_cgroups', 'cgroup', '/proc/self/mounts');
    close $in_31 or croak 'Close failed: $OS_ERROR';
    my $result_31 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_31> };
    close $out_31 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_31, 0;
    $result_31
};
$CGROUP_V2_MNTS = do {
    my ($in_32, $out_32);
    my $pid_32 = open3($in_32, $out_32, '>&STDERR', 'print_cgroups', 'cgroup2', '/proc/self/mounts');
    close $in_32 or croak 'Close failed: $OS_ERROR';
    my $result_32 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_32> };
    close $out_32 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_32, 0;
    $result_32
};
print "Cgroup v1 mount points: \n";
my $mnt;
for my $mnt ($CGROUP_V1_MNTS) {
    do {
    my $__echo_line = " - " . ${mnt};
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
}
print "Cgroup v2 mount points: \n";
for my $mnt ($CGROUP_V2_MNTS) {
    do {
    my $__echo_line = " - " . ${mnt};
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
}
if ("${CGROUP_V2_MNTS}" ne "/sys/fs/cgroup") {
    $CGROUP_SYSTEMD_MNTPT = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_33 = q{};
        my $output_printed_33;
        my $pipeline_success_33 = 1;
        $output_33 .= $CGROUP_V1_MNTS . "\n";
        if ( !($output_33 =~ m{\n\z}msx) ) { $output_33 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_33 = 0; }
        my $grep_result_33_1;
        my @grep_lines_33_1 = split /\n/msx, $output_33;
        my @grep_filtered_33_1 = grep { /\/systemd/msx } @grep_lines_33_1;
        $grep_result_33_1 = join "\n", @grep_filtered_33_1;
                if (!($grep_result_33_1 =~ m{\n\z}msx || $grep_result_33_1 eq q{})) {
                    $grep_result_33_1 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_33_1 > 0 ? 0 : 1;
        $output_33 = $grep_result_33_1;
        if ((scalar @grep_filtered_33_1) == 0) {
            $pipeline_success_33 = 0;
        }
        if ( !$pipeline_success_33 ) { $main_exit_code = 1; }
        $output_33 =~ s/\n+\z//msx;
        $output_33;
}; $_pipeline_result; };
if ("$CGROUP_SYSTEMD_MNTPT" eq q{}) {
printf("Cgroup v1 " . "sys" . "tem" . "d controller: ");
        if (do {
if (do {
$CHILD_ERROR = 0;
    $CHILD_ERROR == 0
}) {
        print "missing\n";
}
            $CHILD_ERROR == 0
        }) {
                        $CHILD_ERROR = 0;
        }
    }
    $CGROUP_FREEZER_MNTPT = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_35 = q{};
        my $output_printed_35;
        my $pipeline_success_35 = 1;
        $output_35 .= $CGROUP_V1_MNTS . "\n";
        if ( !($output_35 =~ m{\n\z}msx) ) { $output_35 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_35 = 0; }
        my $grep_result_35_1;
        my @grep_lines_35_1 = split /\n/msx, $output_35;
        my @grep_filtered_35_1 = grep { /\/freezer/msx } @grep_lines_35_1;
        $grep_result_35_1 = join "\n", @grep_filtered_35_1;
                if (!($grep_result_35_1 =~ m{\n\z}msx || $grep_result_35_1 eq q{})) {
                    $grep_result_35_1 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_35_1 > 0 ? 0 : 1;
        $output_35 = $grep_result_35_1;
        if ((scalar @grep_filtered_35_1) == 0) {
            $pipeline_success_35 = 0;
        }
        if ( !$pipeline_success_35 ) { $main_exit_code = 1; }
        $output_35 =~ s/\n+\z//msx;
        $output_35;
}; $_pipeline_result; };
if ("$CGROUP_FREEZER_MNTPT" eq q{}) {
printf('Cgroup v1 freezer controller: ');
        if (do {
if (do {
$CHILD_ERROR = 0;
    $CHILD_ERROR == 0
}) {
        print "missing\n";
}
            $CHILD_ERROR == 0
        }) {
                        $CHILD_ERROR = 0;
        }
    }
    $CGROUP_MNT_PATH = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_37 = q{};
        my $output_printed_37;
        my $pipeline_success_37 = 1;
        $output_37 .= $CGROUP_V1_MNTS . "\n";
        if ( !($output_37 =~ m{\n\z}msx) ) { $output_37 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_37 = 0; }
        my $num_lines       = 1;
        my $head_line_count = 0;
        my $result          = q{};
        my $input           = $output_37;
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
        $output_37 = $result;

        if ( !$pipeline_success_37 ) { $main_exit_code = 1; }
        $output_37 =~ s/\n+\z//msx;
        $output_37;
}; $_pipeline_result; };
if ((-f "$CGROUP_MNT_PATH/cgroup.clone_children")) {
        if (do {
if (do {
if (do {
printf('Cgroup v1 clone_children flag: ');
    $CHILD_ERROR == 0
}) {
        $CHILD_ERROR = 0;
}
    $CHILD_ERROR == 0
}) {
        print "enabled\n";
}
            $CHILD_ERROR == 0
        }) {
                        $CHILD_ERROR = 0;
        }
    }
}
if (do {
printf('Cgroup device: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_CGROUP_DEVICE');
}
print "\n";
$CHILD_ERROR = 0;
if (do {
printf('Cgroup sched: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_CGROUP_SCHED');
}
print "\n";
$CHILD_ERROR = 0;
if (do {
printf('Cgroup cpu account: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_CGROUP_CPUACCT');
}
print "\n";
$CHILD_ERROR = 0;
printf('Cgroup memory controller: ');
if ((!(    if ((${KVER_MAJOR} >= 3)) {
        (${KVER_MINOR} >= 6)        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }) || (${KVER_MAJOR} > 3))) {
    is_enabled('CONFIG_MEMCG');
}
else {
    is_enabled('CONFIG_CGROUP_MEM_RES_CTLR');
}
print "\n";
$CHILD_ERROR = 0;
if (do {
if (do {
if (do {
is_set('CONFIG_SMP');
    $CHILD_ERROR == 0
}) {
    printf('Cgroup cpuset: ');
}
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_CPUSETS');
}
    $CHILD_ERROR == 0
}) {
        print "\n";
    $CHILD_ERROR = 0;
}
print "
--- Misc ---\n";
if (do {
if (do {
printf('Veth pair device: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_VETH');
}
    $CHILD_ERROR == 0
}) {
        is_probed('veth');
}
print "\n";
$CHILD_ERROR = 0;
if (do {
if (do {
printf('Macvlan: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_MACVLAN');
}
    $CHILD_ERROR == 0
}) {
        is_probed('macvlan');
}
print "\n";
$CHILD_ERROR = 0;
if (do {
if (do {
printf('Vlan: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_VLAN_8021Q');
}
    $CHILD_ERROR == 0
}) {
        is_probed('8021q');
}
print "\n";
$CHILD_ERROR = 0;
if (do {
if (do {
printf('Bridges: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_BRIDGE');
}
    $CHILD_ERROR == 0
}) {
        is_probed('bridge');
}
print "\n";
$CHILD_ERROR = 0;
if (do {
if (do {
printf('Advanced netfilter: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_NETFILTER_ADVANCED');
}
    $CHILD_ERROR == 0
}) {
        is_probed('nf_tables');
}
if ((!(    if ((${KVER_MAJOR} > 3)) {
        (${KVER_MINOR} > 6)        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }) && (${KVER_MAJOR} < 5))) {
    print "\n";
    $CHILD_ERROR = 0;
    if (do {
if (do {
printf('CONFIG_NF_NAT_IPV4: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_NF_NAT_IPV4');
}
        $CHILD_ERROR == 0
    }) {
                is_probed('nf_nat_ipv4');
    }
    print "\n";
    $CHILD_ERROR = 0;
    if (do {
if (do {
printf('CONFIG_NF_NAT_IPV6: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_NF_NAT_IPV6');
}
        $CHILD_ERROR == 0
    }) {
                is_probed('nf_nat_ipv6');
    }
}
print "\n";
$CHILD_ERROR = 0;
if (do {
if (do {
printf('CONFIG_IP_NF_TARGET_MASQUERADE: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_IP_NF_TARGET_MASQUERADE');
}
    $CHILD_ERROR == 0
}) {
        is_probed('nf_nat_masquerade_ipv4');
}
print "\n";
$CHILD_ERROR = 0;
if (do {
if (do {
printf('CONFIG_IP6_NF_TARGET_MASQUERADE: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_IP6_NF_TARGET_MASQUERADE');
}
    $CHILD_ERROR == 0
}) {
        is_probed('nf_nat_masquerade_ipv6');
}
print "\n";
$CHILD_ERROR = 0;
if (do {
if (do {
printf('CONFIG_NETFILTER_XT_TARGET_CHECKSUM: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_NETFILTER_XT_TARGET_CHECKSUM');
}
    $CHILD_ERROR == 0
}) {
        is_probed('xt_CHECKSUM');
}
print "\n";
$CHILD_ERROR = 0;
if (do {
if (do {
printf('CONFIG_NETFILTER_XT_MATCH_COMMENT: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_NETFILTER_XT_MATCH_COMMENT');
}
    $CHILD_ERROR == 0
}) {
        is_probed('xt_comment');
}
print "\n";
$CHILD_ERROR = 0;
if (do {
if (do {
printf('FUSE (for use with lxcfs): ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_FUSE_FS');
}
    $CHILD_ERROR == 0
}) {
        is_probed('fuse');
}
print "\n";
$CHILD_ERROR = 0;
print "
--- Checkpoint/Restore ---\n";
if (do {
printf('checkpoint restore: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_CHECKPOINT_RESTORE');
}
print "\n";
$CHILD_ERROR = 0;
if (do {
printf('CONFIG_FHANDLE: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_FHANDLE');
}
print "\n";
$CHILD_ERROR = 0;
if (do {
printf('CONFIG_EVENTFD: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_EVENTFD');
}
print "\n";
$CHILD_ERROR = 0;
if (do {
printf('CONFIG_EPOLL: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_EPOLL');
}
print "\n";
$CHILD_ERROR = 0;
if (do {
printf('CONFIG_UNIX_DIAG: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_UNIX_DIAG');
}
print "\n";
$CHILD_ERROR = 0;
if (do {
printf('CONFIG_INET_DIAG: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_INET_DIAG');
}
print "\n";
$CHILD_ERROR = 0;
if (do {
printf('CONFIG_PACKET_DIAG: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_PACKET_DIAG');
}
print "\n";
$CHILD_ERROR = 0;
if (do {
printf('CONFIG_NETLINK_DIAG: ');
    $CHILD_ERROR == 0
}) {
        is_enabled('CONFIG_NETLINK_DIAG');
}
print "\n";
$CHILD_ERROR = 0;
printf('File capabilities: ');
if (("${KVER_MAJOR}" eq 2 && (${KVER_MINOR} < 33))) {
    is_enabled('CONFIG_SECURITY_FILE_CAPABILITIES');
    print "\n";
    $CHILD_ERROR = 0;
}
else {
    if (do {
if (do {
$CHILD_ERROR = 0;
    $CHILD_ERROR == 0
}) {
        print "enabled\n";
}
        $CHILD_ERROR == 0
    }) {
                $CHILD_ERROR = 0;
    }
}
do {
    my $__echo_line = "
Note: Before booting a new kernel, you can check its configuration with:

  CONFIG=/path/to/config $PROGRAM_NAME

";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;

exit $main_exit_code;
