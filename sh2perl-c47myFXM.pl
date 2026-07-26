#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use IPC::Open3;
use File::Path qw(make_path remove_tree);
use POSIX qw(time);

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

my $path;
my @path;
my %path;
my $SNAP_BASE;
my @SNAP_BASE;
my %SNAP_BASE;
my $FIRSTRUN;
my @FIRSTRUN;
my %FIRSTRUN;
my $STATE;
my @STATE;
my %STATE;
my $SNAP_DATA;
my @SNAP_DATA;
my %SNAP_DATA;
my $lxcfs_args;
my @lxcfs_args;
my %lxcfs_args;
my $ceph_builtin;
my @ceph_builtin;
my %ceph_builtin;
my $lxcfs_loadavg;
my @lxcfs_loadavg;
my %lxcfs_loadavg;
my $lxcfs_cfs;
my @lxcfs_cfs;
my %lxcfs_cfs;
my $RET;
my @RET;
my %RET;
my $daemon_group;
my @daemon_group;
my %daemon_group;
my $PID;
my @PID;
my %PID;
my $db_trace;
my @db_trace;
my %db_trace;
my $label;
my @label;
my %label;
my $SNAP_COMMON;
my @SNAP_COMMON;
my %SNAP_COMMON;
my $openvswitch_builtin;
my @openvswitch_builtin;
my %openvswitch_builtin;
my $NEW_FUSE;
my @NEW_FUSE;
my %NEW_FUSE;
my $entry;
my @entry;
my %entry;
my $daemon_syslog;
my @daemon_syslog;
my %daemon_syslog;
my $daemon_verbose;
my @daemon_verbose;
my %daemon_verbose;
my $LXD_APPLIANCE;
my @LXD_APPLIANCE;
my %LXD_APPLIANCE;
my $ctr;
my @ctr;
my %ctr;
my $CURRENT_FUSE;
my @CURRENT_FUSE;
my %CURRENT_FUSE;
my $ovn_builtin;
my @ovn_builtin;
my %ovn_builtin;
my $daemon_debug;
my @daemon_debug;
my %daemon_debug;
my $SYSTEMD_OVERRIDE_DIR;
my @SYSTEMD_OVERRIDE_DIR;
my %SYSTEMD_OVERRIDE_DIR;
my $CURRENT_BASE;
my @CURRENT_BASE;
my %CURRENT_BASE;
my $GNUDD_PATH;
my @GNUDD_PATH;
my %GNUDD_PATH;
my $CURRENT_PID;
my @CURRENT_PID;
my %CURRENT_PID;
my $openvswitch_external;
my @openvswitch_external;
my %openvswitch_external;
my $zfs_external;
my @zfs_external;
my %zfs_external;
my $NEW_BASE;
my @NEW_BASE;
my %NEW_BASE;
my $ceph_external;
my @ceph_external;
my %ceph_external;
my $OVS_SYSTEM_ID_FILE;
my @OVS_SYSTEM_ID_FILE;
my %OVS_SYSTEM_ID_FILE;
my $lxcfs_debug;
my @lxcfs_debug;
my %lxcfs_debug;
my $lvm_external;
my @lvm_external;
my %lvm_external;

my $MAGIC_755 = 755;
my $MAGIC_5   = 5;
my $MAGIC_700 = 700;
my $MAGIC_711 = 711;

$__set_e = 1;
# set u not implemented
if ((-d '/sys/kernel/security/apparmor')) {
    $label = (do { my $_chomp_temp = do { my @_qx_cmd = ("cat /proc/self/attr/current 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }; chomp $_chomp_temp; $_chomp_temp; });
if (("$label" ne "unconfined" && "${label##*(unconfined)}" ne q{})) {
# Builtin command 'exec' not implemented
    }
}

sub get_fuse_soname_version {
    # Original bash: ldd "${1}" | sed -n "/libfuse3\?\.so/ s/.*libfuse3\?\.so\.\([^ ]\+\) .*/\1/p"
{
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
                my ($in_1, $out_1);
        my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'ldd', );
        close $in_1 or croak 'Close failed: $OS_ERROR';
        $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
        close $out_1 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_1, 0;

                my @sed_lines_0 = split /\n/msx, $output_0;
        my @sed_result_0;
        foreach my $line (@sed_lines_0) {
        chomp $line;
        push @sed_result_0, $line;
        }
        $output_0 = join "\n", @sed_result_0;
        if ($output_0 ne q{} && !defined $output_printed_0) {
            print $output_0;
            if (!($output_0 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        }
    return;
}

sub get_base_snap_name {
my @sed_lines_2 = split /\n/msx, $;
my @sed_result_2;
foreach my $line (@sed_lines_2) {
chomp $line;
push @sed_result_2, $line;
}
$ = join "\n", @sed_result_2;

    return;
}
do {
    my $__echo_line = "=> Preparing the " . "sys" . "tem" . " (" . ($ENV{SNAP_REVISION} // q{}) . ")";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
$ENV{SNAP_CURRENT} = '';
my $LIB_ARCH;
my @LIB_ARCH;
my %LIB_ARCH;
$LIB_ARCH = (do { my $_chomp_temp = do {
    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'readlink', '-f', ($ENV{SNAP_CURRENT} // q{}), '/lib/*-linux-gnu*/');
    close $in_3 or croak 'Close failed: $OS_ERROR';
    my $result_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;
    $result_3
}; chomp $_chomp_temp; $_chomp_temp; });
$ENV{ARCH} = '';
$ENV{HOME} = '';
$ENV{LXD_DIR} = '';
$ENV{LXD_LXC_TEMPLATE_CONFIG} = '';
$ENV{LXD_LXC_HOOK} = '';
$ENV{LXD_EXEC_PATH} = '';
$ENV{LD_LIBRARY_PATH} = '';
$ENV{PATH} = '';
$ENV{LXD_CLUSTER_UPDATE} = '';
$ENV{LXD_QEMU_FW_PATH} = '';
$ENV{PYTHONPATH} = '/snap/lxd/current/lib/python3/dist-packages/';
$ENV{PYTHONDONTWRITEBYTECODE} = 1;
$LXD_APPLIANCE = "false";
if (!(# Original bash: nsenter -t 1 -m snap model --assertion | grep -q "^model: lxd-core";
{
    my $output_4 = q{};
    my $output_printed_4;
    my $pipeline_success_4 = 1;
        my ($in_5, $out_5);
    my $pid_5 = open3($in_5, $out_5, '>&STDERR', 'nsenter', '-t', q{1}, '-m', 'snap', 'model', '--assertion');
    close $in_5 or croak 'Close failed: $OS_ERROR';
    $output_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
    close $out_5 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_5, 0;

        my $grep_result_4_1;
    my @grep_lines_4_1 = split /\n/msx, $output_4;
    my @grep_filtered_4_1 = grep { /^model:\ lxd-core/msx } @grep_lines_4_1;
    $grep_result_4_1 = join "\n", @grep_filtered_4_1;
    if (!($grep_result_4_1 =~ m{\n\z}msx || $grep_result_4_1 eq q{})) {
    $grep_result_4_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_4_1 > 0 ? 0 : 1;
    $grep_result_4_1 = q{};
    $output_4 = q{};
    if ((scalar @grep_filtered_4_1) == 0) {
        $pipeline_success_4 = 0;
    }
    if ($output_4 ne q{} && !defined $output_printed_4) {
        print $output_4;
        if (!($output_4 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_4 ) { $main_exit_code = 1; }
    })) {
    $LXD_APPLIANCE = "true";
}
$SNAP_BASE = (do { my $_chomp_temp = do {
    my ($in_6, $out_6);
    my $pid_6 = open3($in_6, $out_6, '>&STDERR', 'get_base_snap_name', '/meta/snap.yaml');
    close $in_6 or croak 'Close failed: $OS_ERROR';
    my $result_6 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> };
    close $out_6 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_6, 0;
    $result_6
}; chomp $_chomp_temp; $_chomp_temp; });
if ("${LXD_APPLIANCE}" eq "true") {
while (     $main_exit_code = system('bash', ':') >> 8 ) {
        if ("$(nsenter -t 1 -m snap managed)" eq "true") {
            last;            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
require Time::HiRes; Time::HiRes::sleep(q{5});
    }
}
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('nsenter', '-t', q{1}, '-m', "sys" . "tem" . "d-run", '-u', 'snap.', ($ENV{SNAP_INSTANCE_NAME} // q{}), '.workaround', '-p', 'Delegate', q{=}, 'yes', '-r', '/bin/', 'true') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
if ($CHILD_ERROR != 0) {
    1;
}
$SYSTEMD_OVERRIDE_DIR = "/var/lib/snapd/hostfs/run/" . "sys" . "tem" . "d/" . "sys" . "tem" . "/snap.lxd.daemon.service.d";
if ((!-e "${SYSTEMD_OVERRIDE_DIR}/lxd-shutdown.conf")) {
    use File::Path qw(make_path);
    my $err;
    if ( !-d ${SYSTEMD_OVERRIDE_DIR} ) {
        make_path( ${SYSTEMD_OVERRIDE_DIR}, { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . ${SYSTEMD_OVERRIDE_DIR} . ": $err->[0]\n";
        }
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', ${SYSTEMD_OVERRIDE_DIR} . "/lxd-shutdown.conf"
      or die "Cannot open file: $OS_ERROR\n";
        print "[Unit]
After=snap.microceph.daemon.service snap.microovn.daemon.service\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $main_exit_code = system('nsenter', '-t', q{1}, '-m', "sys" . "tem" . "ctl", 'daemon-reload') >> 8;
}
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', ${SNAP_COMMON} . "/state"
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
1;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
if ((!-e "${SNAP_COMMON}/config")) {
    print "==> Creating missing snap configuration\n";
    $CHILD_ERROR = 0;
}
print "==> Loading snap configuration\n";
$main_exit_code = system('.', ${SNAP_COMMON} . "/config") >> 8;
$daemon_group = (defined (defined ${daemon_group} && ${daemon_group} ne q{} ? ${daemon_group} : '"lxd"') && (defined ${daemon_group} && ${daemon_group} ne q{} ? ${daemon_group} : '"lxd"') ne q{} ? (defined ${daemon_group} && ${daemon_group} ne q{} ? ${daemon_group} : '"lxd"') : '"lxd"');
if ((!-d "${SNAP_COMMON}/lxd")) {
    do {
    my $__echo_line = "==> Creating " . ${SNAP_COMMON} . "/lxd";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    use File::Path qw(make_path);
    if ( !-d ${SNAP_COMMON} . "/lxd" ) {
        make_path( ${SNAP_COMMON} . "/lxd", { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . ${SNAP_COMMON} . "/lxd" . ": $err->[0]\n";
        }
    }
chmod(oct('0711'), (${SNAP_COMMON} . "/lxd")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
if ((!-d "${SNAP_COMMON}/lxd/logs")) {
    do {
    my $__echo_line = "==> Creating " . ${SNAP_COMMON} . "/lxd/logs";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    use File::Path qw(make_path);
    if ( !-d ${SNAP_COMMON} . "/lxd/logs" ) {
        make_path( ${SNAP_COMMON} . "/lxd/logs", { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . ${SNAP_COMMON} . "/lxd/logs" . ": $err->[0]\n";
        }
    }
chmod(oct('0700'), (${SNAP_COMMON} . "/lxd/logs")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
if ((!-d "${SNAP_COMMON}/global-conf")) {
    do {
    my $__echo_line = "==> Creating " . ${SNAP_COMMON} . "/global-conf";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    use File::Path qw(make_path);
    if ( !-d ${SNAP_COMMON} . "/global-conf" ) {
        make_path( ${SNAP_COMMON} . "/global-conf", { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . ${SNAP_COMMON} . "/global-conf" . ": $err->[0]\n";
        }
    }
chmod(oct('0755'), (${SNAP_COMMON} . "/global-conf")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
if (((!-e "${SNAP_COMMON}/mntns") || (-l "${SNAP_COMMON}/mntns"))) {
    do {
    my $__echo_line = "==> Setting up mntns symlink (" . (do { my $_chomp_temp = do {
    my ($in_17, $out_17);
    my $pid_17 = open3($in_17, $out_17, '>&STDERR', 'readlink', '/proc/self/ns/mnt');
    close $in_17 or croak 'Close failed: $OS_ERROR';
    my $result_17 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_17> };
    close $out_17 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_17, 0;
    $result_17
}; chomp $_chomp_temp; $_chomp_temp; }) . ")";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
if ( -e "${SNAP_COMMON} . "/mntns"" ) {
        if ( -d "${SNAP_COMMON} . "/mntns"" ) {
            carp "rm: carping: ", ${SNAP_COMMON} . "/mntns",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "${SNAP_COMMON} . "/mntns"" ) {
                            }
            else {
                carp "rm: carping: could not remove ", ${SNAP_COMMON} . "/mntns",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
symlink '/proc/', ${SNAP_COMMON} . "/mntns" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}

sub is_mounted {
open STDIN, '<', '/proc/self/mountinfo' or croak "Cannot open file: $OS_ERROR\n";
    my $_;
    my $mp;
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $_ = $_fields[0] // q{};
    $_ = $_fields[1] // q{};
    $_ = $_fields[2] // q{};
    $_ = $_fields[3] // q{};
    $mp = $_fields[4] // q{};
    $_ = $_fields[5] // q{};
        if ("${mp}" eq "$1") {
            return q{0};            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
    }
return q{1};
    return;
}
for my $path (${SNAP_COMMON} . "/lxd/storage-pools", ${SNAP_COMMON} . "/lxd/devices") {
    if (do {
is_mounted(${path});
        $CHILD_ERROR == 0
    }) {
        next;    }
    do {
    my $__echo_line = "==> Setting up mount propagation on " . ${path};
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
if ((!-e "${path}")) {
        use File::Path qw(make_path);
        if ( !-d ${path} ) {
            make_path( ${path}, { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . ${path} . ": $err->[0]\n";
            }
        }
chmod(oct('0711'), (${path})) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    }
    $main_exit_code = system('mount', '-o', 'bind', ${path}, ${path}) >> 8;
    $main_exit_code = system('mount', '--make-rshared', ${path}) >> 8;
}
$path = ${SNAP_COMMON} . "/lxd/devices";
if (!(!($main_exit_code = system('mountpoint', '-q', ${SNAP_COMMON} . "/shmounts") >> 8;))) {
    print "==> Setting up persistent shmounts path\n";
if (!(!($main_exit_code = system('mountpoint', '-q', '/media') >> 8;
    if ($CHILD_ERROR != 0) {
        !($main_exit_code = system('bash', 'setup-shmounts') >> 8;)
    }))) {
        print "====> Failed to setup shmounts, continuing without\n";
        use File::Path qw(make_path);
        if ( !-d ${SNAP_COMMON} . "/shmounts" ) {
            make_path( ${SNAP_COMMON} . "/shmounts", { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . ${SNAP_COMMON} . "/shmounts" . ": $err->[0]\n";
            }
        }
        $main_exit_code = system('mount', '-t', 'tmpfs', 'tmpfs', ${SNAP_COMMON} . "/shmounts", '-o', 'size', q{=}, '1M,mode', q{=}, '0711') >> 8;
    }
if (!(!($main_exit_code = system('mountpoint', '-q', ${SNAP_COMMON} . "/lxd/shmounts") >> 8;))) {
        print "====> Making LXD shmounts use the persistent path\n";
        use File::Path qw(make_path);
        if ( !-d ${SNAP_COMMON} . "/shmounts/instances" ) {
            make_path( ${SNAP_COMMON} . "/shmounts/instances", { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . ${SNAP_COMMON} . "/shmounts/instances" . ": $err->[0]\n";
            }
        }
if ((!-L "${SNAP_COMMON}/lxd/shmounts")) {
            use File::Path qw(make_path);
            if ( !-d ${SNAP_COMMON} . "/lxd/" ) {
                make_path( ${SNAP_COMMON} . "/lxd/", { error => \$err } );
                if ( @{$err} ) {
                    croak "mkdir: cannot create directory " . ${SNAP_COMMON} . "/lxd/" . ": $err->[0]\n";
                }
            }
if ( -e "${SNAP_COMMON} . "/lxd/shmounts"" ) {
                if ( -d "${SNAP_COMMON} . "/lxd/shmounts"" ) {
                    my $err;
                    require File::Path;
                    File::Path::remove_tree("${SNAP_COMMON} . "/lxd/shmounts"", {error => \$err});
                    if (@{$err}) {
                        carp "rm: carping: could not remove ", ${SNAP_COMMON} . "/lxd/shmounts", ": $err->[0]\n";
                    }
                    else {
                                            }
                }
                else {
                    if ( unlink "${SNAP_COMMON} . "/lxd/shmounts"" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", ${SNAP_COMMON} . "/lxd/shmounts",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
}
        else {
if ( -e "${SNAP_COMMON} . "/lxd/shmounts"" ) {
                if ( -d "${SNAP_COMMON} . "/lxd/shmounts"" ) {
                    croak "rm: ", ${SNAP_COMMON} . "/lxd/shmounts",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "${SNAP_COMMON} . "/lxd/shmounts"" ) {
                                            }
                    else {
                        croak "rm: cannot remove ", ${SNAP_COMMON} . "/lxd/shmounts",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 1;
                croak "rm: ", ${SNAP_COMMON} . "/lxd/shmounts", ": No such file or directory\n";
            }
        }
symlink ${SNAP_COMMON} . "/shmounts/instances", ${SNAP_COMMON} . "/lxd/shmounts" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    }
if (!(!($main_exit_code = system('mountpoint', '-q', ${SNAP_COMMON} . "/var/lib/lxcfs") >> 8;))) {
        print "====> Making LXCFS use the persistent path\n";
        use File::Path qw(make_path);
        if ( !-d ${SNAP_COMMON} . "/shmounts/lxcfs" ) {
            make_path( ${SNAP_COMMON} . "/shmounts/lxcfs", { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . ${SNAP_COMMON} . "/shmounts/lxcfs" . ": $err->[0]\n";
            }
        }
if ((!-L "${SNAP_COMMON}/var/lib/lxcfs")) {
            use File::Path qw(make_path);
            if ( !-d ${SNAP_COMMON} . "/var/lib/" ) {
                make_path( ${SNAP_COMMON} . "/var/lib/", { error => \$err } );
                if ( @{$err} ) {
                    croak "mkdir: cannot create directory " . ${SNAP_COMMON} . "/var/lib/" . ": $err->[0]\n";
                }
            }
if ( -e "${SNAP_COMMON} . "/var/lib/lxcfs"" ) {
                if ( -d "${SNAP_COMMON} . "/var/lib/lxcfs"" ) {
                    my $err;
                    require File::Path;
                    File::Path::remove_tree("${SNAP_COMMON} . "/var/lib/lxcfs"", {error => \$err});
                    if (@{$err}) {
                        carp "rm: carping: could not remove ", ${SNAP_COMMON} . "/var/lib/lxcfs", ": $err->[0]\n";
                    }
                    else {
                                            }
                }
                else {
                    if ( unlink "${SNAP_COMMON} . "/var/lib/lxcfs"" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", ${SNAP_COMMON} . "/var/lib/lxcfs",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
symlink ${SNAP_COMMON} . "/shmounts/lxcfs", ${SNAP_COMMON} . "/var/lib/lxcfs" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
        }
    }
}
print "==> Setting up kmod wrapper\n";
if (do {
$main_exit_code = system('mountpoint', '-q', '/bin/kmod') >> 8;
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('umount', '-l', '/bin/kmod') >> 8;
}
$main_exit_code = system('mount', '-o', 'ro,bind', ($ENV{SNAP} // q{}) . "/wrappers/kmod", "/bin/kmod") >> 8;
if ((-e '/var/lib/snapd/hostfs/boot')) {
    print "==> Preparing /boot\n";
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('umount', '-l', '/boot') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
    $main_exit_code = system('mount', '-o', 'ro,bind', "/var/lib/snapd/hostfs/boot", "/boot") >> 8;
}
print "==> Preparing a clean copy of /run\n";
if ((-e "/run/.lxd_generated")) {
    $main_exit_code = system('umount', '-l', '/run') >> 8;
}
$main_exit_code = system('mount', '-t', 'tmpfs', 'tmpfs', '/run', '-o', 'mode', q{=}, '0755,nosuid,nodev,size', q{=}, '4M') >> 8;
if ( -e "/run/.lxd_generated" ) {
    my $current_time = time;
    utime $current_time, $current_time, "/run/.lxd_generated";
}
else {
    if ( open my $fh, '>', "/run/.lxd_generated" ) {
        close $fh or croak "Close failed: $ERRNO";
    }
    else {
        croak "touch: cannot create ", "/run/.lxd_generated",
          ": $ERRNO\n";
    }
}
for my $entry ('NetworkManager', 'resolvconf', 'netconfig', 'snapd', 'snapd.socket', 'snapd-snap.socket', 'sysctl.d', "sys" . "tem" . "d", 'udev', 'user') {
        if (!((-e "/var/lib/snapd/hostfs/run/${entry}"))) {
        (-l "/var/lib/snapd/hostfs/run/${entry}")    }
    if ($CHILD_ERROR != 0) {
        next;    }
symlink "/var/lib/snapd/hostfs/run/" . ${entry}, "/run/" . ${entry} or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
$entry = 'user';
print "==> Preparing /run/bin\n";
use File::Path qw(make_path);
if ( !-d "/run/bin" ) {
    make_path( "/run/bin", { error => \$err } );
    if ( @{$err} ) {
        croak "mkdir: cannot create directory " . "/run/bin" . ": $err->[0]\n";
    }
}
$ENV{PATH} = '';
if ((-e "${SNAP_COMMON}/use-qemu-external-snap")) {
    print "==> Setting up external QEMU snap integration\n";
$ENV{SNAP_QEMU_PREFIX} = '';
    my $LD_LPATH_PIPEWIRE;
    my @LD_LPATH_PIPEWIRE;
    my %LD_LPATH_PIPEWIRE;
    $LD_LPATH_PIPEWIRE = (do { my $_chomp_temp = do {
    my ($in_32, $out_32);
    my $pid_32 = open3($in_32, $out_32, '>&STDERR', 'readlink', '-f', ($ENV{SNAP_CURRENT} // q{}) . "/" . ($ENV{SNAP_QEMU_PREFIX} // q{}) . "/lib/" . ($ENV{ARCH} // q{}), '/pipewire-*/');
    close $in_32 or croak 'Close failed: $OS_ERROR';
    my $result_32 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_32> };
    close $out_32 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_32, 0;
    $result_32
}; chomp $_chomp_temp; $_chomp_temp; });
$ENV{LD_LIBRARY_PATH} = '';
}
if ("${ceph_external:-"false"}" eq "true") {
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/ceph" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/radosgw-admin" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/rbd" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
if ("${openvswitch_external:-"false"}" eq "true") {
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/ovs-appctl" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/ovs-vsctl" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
if ("${lvm_external:-"false"}" eq "true") {
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/lvm" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/vgs" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/lvs" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/pvcreate" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/pvremove" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/vgcreate" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/vgchange" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/vgremove" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/lvcreate" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/lvchange" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/lvextend" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/lvrename" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/lvremove" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/lvresize" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
if ("${zfs_external:-"false"}" eq "true") {
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/zfs" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/zpool" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/zvol_id" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
if ((-x "${SNAP_COMMON}/lxd-agent.debug")) {
    print "==> WARNING: Using a custom debug lxd-agent binary!\n";
symlink ${SNAP_COMMON} . "/lxd-agent.debug", "/run/bin/lxd-agent" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/getent" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/journalctl" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/pro" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/iscsiadm" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ($ENV{SNAP} // q{}) . "/wrappers/run-host", "/run/bin/multipath" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ($ENV{SNAP} // q{}) . "/bin/ebtables-legacy", "/run/bin/ebtables" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink '/usr/sbin/xtables-legacy-multi', "/run/bin/ip6tables" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink '/usr/sbin/xtables-legacy-multi', "/run/bin/iptables" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
if ("${SNAP_BASE}" eq "core26") {
if (!(!(if (do {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('command', '-v', 'chroot') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    } == 0) {
        (-e '/usr/lib/cargo/bin/coreutils/chroot')    }))) {
        print "==> Adding missing chroot symlink for core26\n";
symlink '/usr/lib/cargo/bin/coreutils/chroot', '/run/bin/chroot' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    }
if ((-e '/usr/lib/cargo/bin/coreutils/dd')) {
        $GNUDD_PATH = (do { my $_chomp_temp = do {
    my $command = 'command -v gnudd 2> /dev/null || true';
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; });
if ("${GNUDD_PATH}" ne q{}) {
            print "==> Diverting dd to gnudd for core26\n";
symlink ${GNUDD_PATH}, '/run/bin/dd' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
        }
    }
}
print "==> Preparing a clean copy of /etc\n";
if ((-e "/etc/.lxd_generated")) {
    $main_exit_code = system('umount', '-l', '/etc') >> 8;
}
$main_exit_code = system('mount', '-t', 'tmpfs', 'tmpfs', '/etc', '-o', 'mode', q{=}, '0755,nosuid,nodev,size', q{=}, '4M') >> 8;
if ( -e "/etc/.lxd_generated" ) {
    my $current_time = time;
    utime $current_time, $current_time, "/etc/.lxd_generated";
}
else {
    if ( open my $fh, '>', "/etc/.lxd_generated" ) {
        close $fh or croak "Close failed: $ERRNO";
    }
    else {
        croak "touch: cannot create ", "/etc/.lxd_generated",
          ": $ERRNO\n";
    }
}
$main_exit_code = system('bash', 'ldconfig') >> 8;
for my $entry ('hostid', 'hostname', 'hosts', 'nsswitch.conf', 'os-release', 'passwd', 'group', 'localtime', 'pki', 'resolv.conf', 'resolvconf', 'timezone', 'writable') {
        if (!((-e "/var/lib/snapd/hostfs/etc/${entry}"))) {
        (-l "/var/lib/snapd/hostfs/etc/${entry}")    }
    if ($CHILD_ERROR != 0) {
        next;    }
symlink "/var/lib/snapd/hostfs/etc/" . ${entry}, "/etc/" . ${entry} or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
$entry = 'writable';
for my $entry ('apparmor', 'apparmor.d', 'ethertypes', 'protocols') {
symlink "/snap/" . ${SNAP_BASE} . "/current/etc/" . ${entry}, "/etc/" . ${entry} or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
$entry = 'protocols';
symlink "/proc/mounts", "/etc/mtab" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
if (((-e "/var/lib/snapd/hostfs/etc/ssl") && (-e "/var/lib/snapd/hostfs/usr/share/ca-certificates"))) {
symlink "/var/lib/snapd/hostfs/etc/ssl", "/etc/ssl" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
        $main_exit_code = system('mountpoint', '-q', "/usr/share/ca-certificates") >> 8;
    if ($CHILD_ERROR != 0) {
                $main_exit_code = system('mount', '-o', 'ro,bind', "/var/lib/snapd/hostfs/usr/share/ca-certificates", "/usr/share/ca-certificates") >> 8;
    }
}
else {
symlink "/snap/" . ${SNAP_BASE} . "/current/etc/ssl", "/etc/ssl" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
if (((-l '/etc/resolv.conf') && (!-e /etc/resolv.conf))) {
    print "====> Unusual /etc/resolv.conf detected, using workaround\n";
if ( -e "/etc/resolv.conf" ) {
        if ( -d "/etc/resolv.conf" ) {
            carp "rm: carping: ", "/etc/resolv.conf",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/etc/resolv.conf" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/etc/resolv.conf",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/etc/resolv.conf'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('nsenter', '-t', q{1}, '-m', 'cat', '/etc/resolv.conf') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
}
for my $entry ('dev', 'proc', 'sys') {
    if (do {
$main_exit_code = system('mountpoint', '-q', "/var/lib/snapd/hostfs/" . ${entry}) >> 8;
        $CHILD_ERROR == 0
    }) {
        next;    }
    $main_exit_code = system('mount', '-o', 'bind', "/" . ${entry}, "/var/lib/snapd/hostfs/" . ${entry}) >> 8;
}
$entry = 'sys';
if (("${daemon_group}" eq "lxd" && !(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
!($main_exit_code = system('getent', 'group', 'lxd') >> 8;)
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
}))) {
    print "==> Creating \"lxd\" group\n";
if (!(my $grep_result_73;
my @grep_lines_73 = ();
my @grep_filenames_73 = ();
if (-e "/var/lib/snapd/hostfs/etc/nsswitch.conf") {
    open my $fh, '<', "/var/lib/snapd/hostfs/etc/nsswitch.conf" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_73, $line;
        push @grep_filenames_73, "/var/lib/snapd/hostfs/etc/nsswitch.conf";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /var/lib/snapd/hostfs/etc/nsswitch.conf: No such file or directory\n"; }
my @grep_filtered_73 = grep { /^group.*extrausers/msx } @grep_lines_73;
$grep_result_73 = join "\n", @grep_filtered_73;
    if (!($grep_result_73 =~ m{\n\z}msx || $grep_result_73 eq q{})) {
        $grep_result_73 .= "\n";
    }
$CHILD_ERROR = scalar @grep_filtered_73 > 0 ? 0 : 1;
$grep_result_73 = q{})) {
                $main_exit_code = system('nsenter', '-t', q{1}, '-m', 'groupadd', "--" . "sys" . "tem", '--extrausers', 'lxd') >> 8;
        if ($CHILD_ERROR != 0) {
            1;
        }
}
    else {
                $main_exit_code = system('nsenter', '-t', q{1}, '-m', 'groupadd', "--" . "sys" . "tem", 'lxd') >> 8;
        if ($CHILD_ERROR != 0) {
            1;
        }
    }
}
if (!(!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('getent', 'passwd', 'lxd') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};))) {
    print "==> Creating \"lxd\" user\n";
if (!(my $grep_result_76;
my @grep_lines_76 = ();
my @grep_filenames_76 = ();
if (-e "/var/lib/snapd/hostfs/etc/nsswitch.conf") {
    open my $fh, '<', "/var/lib/snapd/hostfs/etc/nsswitch.conf" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_76, $line;
        push @grep_filenames_76, "/var/lib/snapd/hostfs/etc/nsswitch.conf";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /var/lib/snapd/hostfs/etc/nsswitch.conf: No such file or directory\n"; }
my @grep_filtered_76 = grep { /^passwd.*extrausers/msx } @grep_lines_76;
$grep_result_76 = join "\n", @grep_filtered_76;
    if (!($grep_result_76 =~ m{\n\z}msx || $grep_result_76 eq q{})) {
        $grep_result_76 .= "\n";
    }
$CHILD_ERROR = scalar @grep_filtered_76 > 0 ? 0 : 1;
$grep_result_76 = q{})) {
                $main_exit_code = system('nsenter', '-t', q{1}, '-m', 'useradd', "--" . "sys" . "tem", '-M', '-N', '--home', ${SNAP_COMMON} . "/lxd", '--shell', '/bin/', 'false', '--gid', 'lxd', '--extrausers', 'lxd') >> 8;
        if ($CHILD_ERROR != 0) {
            1;
        }
}
    else {
                $main_exit_code = system('nsenter', '-t', q{1}, '-m', 'useradd', "--" . "sys" . "tem", '-M', '-N', '--home', ${SNAP_COMMON} . "/lxd", '--shell', '/bin/', 'false', '--gid', 'lxd', 'lxd') >> 8;
        if ($CHILD_ERROR != 0) {
            1;
        }
    }
}
print "==> Setting up ceph configuration\n";
if ("${ceph_builtin:-"false"}" eq "true") {
    use File::Path qw(make_path);
    if ( !-d ${SNAP_COMMON} . "/ceph" ) {
        make_path( ${SNAP_COMMON} . "/ceph", { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . ${SNAP_COMMON} . "/ceph" . ": $err->[0]\n";
        }
    }
symlink ${SNAP_COMMON} . "/ceph", '/etc/ceph' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
else {
    if ((-d "${SNAP_DATA}/microceph")) {
symlink 'nf', '/etc/ceph' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
    else {
symlink '/var/lib/snapd/hostfs/etc/ceph', '/etc/ceph' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    }
}
if ("${lvm_external:-"false"}" eq "false") {
    print "==> Setting up LVM configuration\n";
    use File::Path qw(make_path);
    if ( !-d '/etc/lvm' ) {
        make_path( '/etc/lvm', { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . '/etc/lvm' . ": $err->[0]\n";
        }
    }
symlink q{f}, '/etc/lvm/' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink q{f}, '/etc/lvm/' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
print "==> Setting up OVN configuration\n";
if ("${ovn_builtin:-"false"}" eq "true") {
    print "=> Using builtin OVN\n";
    use File::Path qw(make_path);
    if ( !-d ${SNAP_COMMON} . "/ovn" ) {
        make_path( ${SNAP_COMMON} . "/ovn", { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . ${SNAP_COMMON} . "/ovn" . ": $err->[0]\n";
        }
    }
symlink ${SNAP_COMMON} . "/ovn", '/etc/ovn' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
else {
    if ((-d "${SNAP_DATA}/microovn/certificates/pki")) {
        print "==> Cleaning up OVN configuration\n";
if ((-l '/etc/ovn')) {
            print "=> Removing /etc/ovn symlink\n";
if ( -e "/etc/ovn" ) {
                if ( -d "/etc/ovn" ) {
                    carp "rm: carping: ", "/etc/ovn",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "/etc/ovn" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "/etc/ovn",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
}
        else {
            if ((-d '/etc/ovn')) {
                print "=> Removing /etc/ovn directory\n";
if ( -e "/etc/ovn" ) {
                    if ( -d "/etc/ovn" ) {
                        my $err;
                        require File::Path;
                        File::Path::remove_tree("/etc/ovn", {error => \$err});
                        if (@{$err}) {
                            carp "rm: carping: could not remove ", "/etc/ovn", ": $err->[0]\n";
                        }
                        else {
                                                    }
                    }
                    else {
                        if ( unlink "/etc/ovn" ) {
                                                    }
                        else {
                            carp "rm: carping: could not remove ", "/etc/ovn",
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 0;
                }
            }
        }
        print "=> Detected MicroOVN Content Interface\n";
        use File::Path qw(make_path);
        if ( !-d '/etc/ovn' ) {
            make_path( '/etc/ovn', { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . '/etc/ovn' . ": $err->[0]\n";
            }
        }
symlink ${SNAP_DATA} . "/microovn/certificates/pki/client-cert.pem", '/etc/ovn/cert_host' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ${SNAP_DATA} . "/microovn/certificates/pki/client-privkey.pem", '/etc/ovn/key_host' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink ${SNAP_DATA} . "/microovn/certificates/pki/cacert.pem", '/etc/ovn/ovn-central.crt' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
    else {
        if ((-d '/var/snap/microovn/')) {
            print "==> Cleaning up OVN configuration\n";
if ((-l '/etc/ovn')) {
                print "=> Removing /etc/ovn symlink\n";
if ( -e "/etc/ovn" ) {
                    if ( -d "/etc/ovn" ) {
                        carp "rm: carping: ", "/etc/ovn",
          " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink "/etc/ovn" ) {
                                                    }
                        else {
                            carp "rm: carping: could not remove ", "/etc/ovn",
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 0;
                }
}
            else {
                if ((-d '/etc/ovn')) {
                    print "=> Removing /etc/ovn directory\n";
if ( -e "/etc/ovn" ) {
                        if ( -d "/etc/ovn" ) {
                            my $err;
                            require File::Path;
                            File::Path::remove_tree("/etc/ovn", {error => \$err});
                            if (@{$err}) {
                                carp "rm: carping: could not remove ", "/etc/ovn", ": $err->[0]\n";
                            }
                            else {
                                                            }
                        }
                        else {
                            if ( unlink "/etc/ovn" ) {
                                                            }
                            else {
                                carp "rm: carping: could not remove ", "/etc/ovn",
              ": $OS_ERROR\n";
                            }
                        }
                    }
                    else {
                        local $CHILD_ERROR = 0;
                    }
                }
            }
            print "=> Detected MicroOVN\n";
            use File::Path qw(make_path);
            if ( !-d '/etc/ovn' ) {
                make_path( '/etc/ovn', { error => \$err } );
                if ( @{$err} ) {
                    croak "mkdir: cannot create directory " . '/etc/ovn' . ": $err->[0]\n";
                }
            }
symlink '/var/snap/microovn/common/data/pki/client-cert.pem', '/etc/ovn/cert_host' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink '/var/snap/microovn/common/data/pki/client-privkey.pem', '/etc/ovn/key_host' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
symlink '/var/snap/microovn/common/data/pki/cacert.pem', '/etc/ovn/ovn-central.crt' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
        else {
symlink '/var/lib/snapd/hostfs/etc/ovn', '/etc/ovn' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
        }
    }
}
print "==> Rotating logs\n";
$main_exit_code = system('logrotate', '-f', ($ENV{SNAP} // q{}) . "/etc/logrotate.conf", '-s', "/etc/logrotate.status") >> 8;
if ($CHILD_ERROR != 0) {
    1;
}
$main_exit_code = system('.', ($ENV{SNAP} // q{}) . "/commands/setup-zfs") >> 8;
print "==> Escaping the " . "sys" . "tem" . "d cgroups\n";
if ((-e "/sys/fs/cgroup/cgroup.procs")) {
    print "====> Detected cgroup V2\n";
if (!(!(do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "/sys/fs/cgroup/cgroup.procs"
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
        print $$;
if ( !( ($$) =~ m{\n\z}msx ) ) { print "\n"; }
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };))) {
if ((!-d "/sys/fs/cgroup/.lxc")) {
            use File::Path qw(make_path);
            if ( mkdir '/sys/fs/cgroup/.lxc' ) {
                }
            else {
                croak "mkdir: cannot create directory " . '/sys/fs/cgroup/.lxc' . ": File exists\n";
            }
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "/sys/fs/cgroup/.lxc/cgroup.procs"
      or die "Cannot open file: $OS_ERROR\n";
            print $$;
if ( !( ($$) =~ m{\n\z}msx ) ) { print "\n"; }
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
}
else {
    print "====> Detected cgroup V1\n";
    for my $ctr ('/sys/fs/cgroup/*') {
        if (!((-e "${ctr}/cgroup.procs"))) {
            next;        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', ${ctr} . "/cgroup.procs"
      or die "Cannot open file: $OS_ERROR\n";
            print $$;
if ( !( ($$) =~ m{\n\z}msx ) ) { print "\n"; }
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
if ((-e '/sys/fs/cgroup/cpuset/cgroup.clone_children')) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/sys/fs/cgroup/cpuset/cgroup.clone_children'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
            print q{1} . "\n";
            $CHILD_ERROR = 0;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        if ($CHILD_ERROR != 0) {
            1;
        }
    }
}

sub manage_apparmor_restrictions {
    my $SYSCTL_FILE;
    my @SYSCTL_FILE;
    my %SYSCTL_FILE;
    $SYSCTL_FILE = "/var/lib/snapd/hostfs/run/sysctl.d/zz-lxd.conf";
    if (!((-d '/sys/kernel/security/apparmor'))) {
        return q{0};    }
if ("${apparmor_unprivileged_restrictions_disable:-"true"}" eq "true") {
        my $KEY_USERNS;
        my @KEY_USERNS;
        my %KEY_USERNS;
        $KEY_USERNS = "kernel.apparmor_restrict_unprivileged_userns";
        my $KEY_UNCONFINED;
        my @KEY_UNCONFINED;
        my %KEY_UNCONFINED;
        $KEY_UNCONFINED = "kernel.apparmor_restrict_unprivileged_unconfined";
        use File::Path qw(make_path);
        if ( !-d '/var/lib/snapd/hostfs/run/sysctl.d' ) {
            make_path( '/var/lib/snapd/hostfs/run/sysctl.d', { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . '/var/lib/snapd/hostfs/run/sysctl.d' . ": $err->[0]\n";
            }
        }
        my $tmpf;
        my @tmpf;
        my %tmpf;
        $tmpf = (do { my $_chomp_temp = do {
    my ($in_101, $out_101);
    my $pid_101 = open3($in_101, $out_101, '>&STDERR', 'mktemp', ${SYSCTL_FILE}, '.XXXXXX');
    close $in_101 or croak 'Close failed: $OS_ERROR';
    my $result_101 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_101> };
    close $out_101 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_101, 0;
    $result_101
}; chomp $_chomp_temp; $_chomp_temp; });
if ("$(sysctl -n -e "${KEY_USERNS}")" eq "1") {
            print "==> Disabling Apparmor unprivileged userns mediation\n";
            $main_exit_code = system('sysctl', '-w', '-e', ${KEY_USERNS} . "=0") >> 8;
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', ${tmpf}
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "-" . ${KEY_USERNS} . " = 0";
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
if ("$(sysctl -n -e "${KEY_UNCONFINED}")" eq "1") {
            print "==> Disabling Apparmor unprivileged unconfined mediation\n";
            $main_exit_code = system('sysctl', '-w', '-e', ${KEY_UNCONFINED} . "=0") >> 8;
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', ${tmpf}
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "-" . ${KEY_UNCONFINED} . " = 0";
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
if (!(!($main_exit_code = system('cmp', '--quiet', ${tmpf}, ${SYSCTL_FILE}) >> 8;))) {
chmod(oct('a+r'), (${tmpf})) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
            my $force = 0;
            if ( -e "${tmpf}" ) {
                my $dest = ${SYSCTL_FILE};
                if ( -e $dest && -d $dest ) {
                    my $source_name = "${tmpf}";
                    $source_name =~ s{^.*[\/]}{};
                    $dest = "$dest/$source_name";
                }
                if ( -e $dest && !$force ) {
                    croak "mv: $dest: File exists (use -f to force overwrite)\n";
                }
                my $dest_dir = $dest;
                $dest_dir =~ s/\/[^\/]*$//msx;
                if ( $dest_dir eq $dest ) {
                    $dest_dir = q{};
                }
                if ( $dest_dir ne q{} && !-d $dest_dir ) {
                    my $err;
                    make_path( $dest_dir, { error => \$err } );
                    if ( @{$err} ) {
                        croak "mv: cannot create directory $dest_dir: $err->[0]\n";
                    }
                }
                require File::Copy;
                if ( File::Copy::move( "${tmpf}", $dest ) ) {
                } else {
                    croak
  "mv: cannot move "${tmpf}" to $dest: $ERRNO\n";
                }
            } else {
                croak "mv: "${tmpf}": No such file or directory\n";
            }
}
        else {
if ( -e "${tmpf}" ) {
                if ( -d "${tmpf}" ) {
                    croak "rm: ", ${tmpf},
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "${tmpf}" ) {
                                            }
                    else {
                        croak "rm: cannot remove ", ${tmpf},
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 1;
                croak "rm: ", ${tmpf}, ": No such file or directory\n";
            }
        }
return q{0};
    }
    if (!((-f "${SYSCTL_FILE}"))) {
        return q{0};    }
    print "==> Restoring Apparmor unprivileged userns and unconfined mediations\n";
if ( -e "${SYSCTL_FILE}" ) {
        if ( -d "${SYSCTL_FILE}" ) {
            croak "rm: ", ${SYSCTL_FILE},
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "${SYSCTL_FILE}" ) {
                            }
            else {
                croak "rm: cannot remove ", ${SYSCTL_FILE},
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 1;
        croak "rm: ", ${SYSCTL_FILE}, ": No such file or directory\n";
    }
        $main_exit_code = system('nsenter', '-t', q{1}, '-m', "sys" . "tem" . "ctl", 'restart', "sys" . "tem" . "d-sysctl.service") >> 8;
    if ($CHILD_ERROR != 0) {
        1;
    }
    return;
}
if ("$(stat -c '%u' /proc)" eq 0) {
    print "==> Escaping the " . "sys" . "tem" . "d process resource limits\n";
        $main_exit_code = system('prlimit', '-p', $$, '--nofile=1048576:1048576') >> 8;
    if ($CHILD_ERROR != 0) {
        1;
    }
        $main_exit_code = system('prlimit', '-p', $$, '--nproc=unlimited:unlimited') >> 8;
    if ($CHILD_ERROR != 0) {
        1;
    }
if ((-e '/proc/sys/fs/inotify/max_user_instances')) {
if ((qx'cat /proc/sys/fs/inotify/max_user_instances' < 1024)) {
            print "==> Increasing the number of inotify user instances\n";
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/proc/sys/fs/inotify/max_user_instances'
      or die "Cannot open file: $OS_ERROR\n";
                print '1024' . "\n";
                $CHILD_ERROR = 0;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            if ($CHILD_ERROR != 0) {
                1;
            }
        }
    }
if ((-e '/proc/sys/fs/inotify/max_user_watches')) {
if ((qx'cat /proc/sys/fs/inotify/max_user_watches' < 1048$MAGIC_576)) {
            print "==> Increasing the number of inotify user watches\n";
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/proc/sys/fs/inotify/max_user_watches'
      or die "Cannot open file: $OS_ERROR\n";
                print '1048576' . "\n";
                $CHILD_ERROR = 0;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            if ($CHILD_ERROR != 0) {
                1;
            }
        }
    }
if ((-e '/proc/sys/kernel/keys/maxkeys')) {
if ((qx'cat /proc/sys/kernel/keys/maxkeys' < 2000)) {
            print "==> Increasing the number of keys for a nonroot user\n";
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/proc/sys/kernel/keys/maxkeys'
      or die "Cannot open file: $OS_ERROR\n";
                print '2000' . "\n";
                $CHILD_ERROR = 0;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            if ($CHILD_ERROR != 0) {
                1;
            }
        }
    }
if ((-e '/proc/sys/kernel/keys/maxbytes')) {
if ((qx'cat /proc/sys/kernel/keys/maxbytes' < 2000000)) {
            print "==> Increasing the number of bytes for a nonroot user\n";
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/proc/sys/kernel/keys/maxbytes'
      or die "Cannot open file: $OS_ERROR\n";
                print '2000000' . "\n";
                $CHILD_ERROR = 0;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            if ($CHILD_ERROR != 0) {
                1;
            }
        }
    }
if ((-e '/proc/sys/kernel/unprivileged_userns_clone')) {
if ("$(cat /proc/sys/kernel/unprivileged_userns_clone)" eq "0") {
            print "==> Enabling unprivileged containers kernel support\n";
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/proc/sys/kernel/unprivileged_userns_clone'
      or die "Cannot open file: $OS_ERROR\n";
                print q{1} . "\n";
                $CHILD_ERROR = 0;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            if ($CHILD_ERROR != 0) {
                1;
            }
        }
    }
    manage_apparmor_restrictions();
}
print "==> Exposing LXD UI\n";
$ENV{LXD_UI} = '';
print "==> Exposing LXD documentation\n";
$ENV{LXD_DOCUMENTATION} = '';
use File::Path qw(make_path);
if ( !-d ${SNAP_COMMON} . "/lxc" ) {
    make_path( ${SNAP_COMMON} . "/lxc", { error => \$err } );
    if ( @{$err} ) {
        croak "mkdir: cannot create directory " . ${SNAP_COMMON} . "/lxc" . ": $err->[0]\n";
    }
}
if (((-d '/sys/kernel/security/apparmor') && !(!(my $grep_result_113;
my @grep_lines_113 = ();
my @grep_filenames_113 = ();
if (-e "/proc/version") {
    open my $fh, '<', "/proc/version" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_113, $line;
        push @grep_filenames_113, "/proc/version";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /proc/version: No such file or directory\n"; }
my @grep_filtered_113 = grep { /-Ubuntu/msx } @grep_lines_113;
$grep_result_113 = join "\n", @grep_filtered_113;
if (!($grep_result_113 =~ m{\n\z}msx || $grep_result_113 eq q{})) {
    $grep_result_113 .= "\n";
}
$CHILD_ERROR = scalar @grep_filtered_113 > 0 ? 0 : 1;
$grep_result_113 = q{};)))) {
    print "==> Detected kernel with partial AppArmor support\n";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', ${SNAP_COMMON} . "/lxc/local.conf"
      or die "Cannot open file: $OS_ERROR\n";
        print "lxc.apparmor.allow_incomplete = 1\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
}
else {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', ${SNAP_COMMON} . "/lxc/local.conf"
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
1;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
}
if ("${openvswitch_builtin:-"false"}" eq "true") {
    print "=> Starting Open vSwitch\n";
$ENV{OVS_RUNDIR} = '';
    do {
        local %ENV = %ENV;
        my $err = $err;
        my $LIB_ARCH = $LIB_ARCH;
        my $LD_LPATH_PIPEWIRE = $LD_LPATH_PIPEWIRE;
$__set_e = 1;
$ENV{OVS_LOGDIR} = '';
$ENV{OVS_DBDIR} = '';
$ENV{OVS_SYSCONFDIR} = '';
$ENV{OVS_PKGDATADIR} = '';
$ENV{OVS_BINDIR} = '';
$ENV{OVS_SBINDIR} = '';
            use File::Path qw(make_path);
            if ( !-d ($ENV{OVS_SYSCONFDIR} // q{}) . "/openvswitch" ) {
                make_path( ($ENV{OVS_SYSCONFDIR} // q{}) . "/openvswitch", { error => \$err } );
                if ( @{$err} ) {
                    croak "mkdir: cannot create directory " . ($ENV{OVS_SYSCONFDIR} // q{}) . "/openvswitch" . ": $err->[0]\n";
                }
            }
            $OVS_SYSTEM_ID_FILE = ($ENV{OVS_SYSCONFDIR} // q{}) . "/openvswitch/" . "sys" . "tem" . "-id.conf";
if (!(!(((-s "${OVS_SYSTEM_ID_FILE}") > 0)))) {
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', ${OVS_SYSTEM_ID_FILE}
      or die "Cannot open file: $OS_ERROR\n";
                    my $tmp = do {
                    $main_exit_code = system('systemd-id128', 'new', '--uuid') >> 8;
                    };
                    print $tmp;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
            }
            do {
                local %ENV = %ENV;
                my $err = $err;
                my $LIB_ARCH = $LIB_ARCH;
                my $LD_LPATH_PIPEWIRE = $LD_LPATH_PIPEWIRE;
                                        do {
open STDERR, '<', q{-} or croak "Cannot open file: $OS_ERROR\n";
# Builtin command 'exec' not implemented
                    };
                    if ($CHILD_ERROR != 0) {
                        1;
                    }
                    $CHILD_ERROR = 0;
                q{};
            };
        q{};
    };
}
else {
    if ((-d "${SNAP_DATA}/microovn/chassis/switch")) {
symlink ${SNAP_DATA} . "/microovn/chassis/switch", '/run/openvswitch' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
    else {
        if ((-d '/var/snap/microovn/')) {
symlink '/var/snap/microovn/common/run/switch', '/run/openvswitch' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
        else {
symlink '/var/lib/snapd/hostfs/run/openvswitch', '/run/openvswitch' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
        }
    }
}
if ((-e "${SNAP_COMMON}/var/lib/lxcfs/cgroup")) {
    print "=> Re-using existing LXCFS\n";
    $NEW_FUSE = (do { my $_chomp_temp = do {
    my ($in_120, $out_120);
    my $pid_120 = open3($in_120, $out_120, '>&STDERR', 'get_fuse_soname_version', ($ENV{SNAP_CURRENT} // q{}) . "/bin/lxcfs");
    close $in_120 or croak 'Close failed: $OS_ERROR';
    my $result_120 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_120> };
    close $out_120 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_120, 0;
    $result_120
}; chomp $_chomp_temp; $_chomp_temp; });
    $CURRENT_FUSE = ${NEW_FUSE};
    $NEW_BASE = ${SNAP_BASE};
    $CURRENT_BASE = ${NEW_BASE};
if ((-e "${SNAP_COMMON}/lxcfs.pid")) {
open STDIN, '<', ${SNAP_COMMON} . "/lxcfs.pid" or croak "Cannot open file: $OS_ERROR\n";
$CURRENT_PID = <>;
chomp $CURRENT_PID;
$CHILD_ERROR = defined($CURRENT_PID) ? 0 : 1;
if ((-e "/proc/${CURRENT_PID}")) {
            $CURRENT_FUSE = (do { my $_chomp_temp = do {
    my ($in_122, $out_122);
    my $pid_122 = open3($in_122, $out_122, '>&STDERR', 'get_fuse_soname_version', "/proc/" . ${CURRENT_PID} . "/exe");
    close $in_122 or croak 'Close failed: $OS_ERROR';
    my $result_122 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_122> };
    close $out_122 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_122, 0;
    $result_122
}; chomp $_chomp_temp; $_chomp_temp; });
            $CURRENT_BASE = (do { my $_chomp_temp = do {
    my ($in_123, $out_123);
    my $pid_123 = open3($in_123, $out_123, '>&STDERR', 'get_base_snap_name', "/proc/" . ${CURRENT_PID} . "/root/meta/snap.yaml");
    close $in_123 or croak 'Close failed: $OS_ERROR';
    my $result_123 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_123> };
    close $out_123 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_123, 0;
    $result_123
}; chomp $_chomp_temp; $_chomp_temp; });
        }
    }
if ("${CURRENT_BASE}" ne "${NEW_BASE}") {
        print "==> snap base has changed, restart " . "sys" . "tem" . " to upgrade LXCFS\n";
}
    else {
        if ("${CURRENT_FUSE}" ne "${NEW_FUSE}") {
            print "==> FUSE version mismatch, restart " . "sys" . "tem" . " to upgrade LXCFS\n";
}
        else {
            if ("${CURRENT_PID:-}" ne q{}) {
                print "==> Reloading LXCFS\n";
                my $signal = 'USR1';
my @pids = (${CURRENT_PID});
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
                if ($CHILD_ERROR != 0) {
                    1;
                }
            }
        }
    }
}
else {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('umount', '-l', ${SNAP_COMMON} . "/var/lib/lxcfs") >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('fusermount', '-u', ${SNAP_COMMON} . "/var/lib/lxcfs") >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
    use File::Path qw(make_path);
    if ( !-d ${SNAP_COMMON} . "/var/lib/lxcfs" ) {
        make_path( ${SNAP_COMMON} . "/var/lib/lxcfs", { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . ${SNAP_COMMON} . "/var/lib/lxcfs" . ": $err->[0]\n";
        }
    }
if ( -e "${SNAP_COMMON} . "/lxcfs.pid"" ) {
        if ( -d "${SNAP_COMMON} . "/lxcfs.pid"" ) {
            carp "rm: carping: ", ${SNAP_COMMON} . "/lxcfs.pid",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "${SNAP_COMMON} . "/lxcfs.pid"" ) {
                            }
            else {
                carp "rm: carping: could not remove ", ${SNAP_COMMON} . "/lxcfs.pid",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    print "=> Starting LXCFS\n";
    do {
        local %ENV = %ENV;
        my $err = $err;
        my $LIB_ARCH = $LIB_ARCH;
        my $LD_LPATH_PIPEWIRE = $LD_LPATH_PIPEWIRE;
                        do {
open STDERR, '<', q{-} or croak "Cannot open file: $OS_ERROR\n";
# Builtin command 'exec' not implemented
            };
            if ($CHILD_ERROR != 0) {
                1;
            }
$ENV{LD_LIBRARY_PATH} = '';
            $lxcfs_args = q{};
            if ("${lxcfs_loadavg:-"false"}" eq "true") {
                                $lxcfs_args = ${lxcfs_args} . " --enable-loadavg";
                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
            if ("${lxcfs_cfs:-"false"}" eq "true") {
                                $lxcfs_args = ${lxcfs_args} . " --enable-cfs";
                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
            if ("${lxcfs_debug:-"false"}" eq "true") {
                                $lxcfs_args = ${lxcfs_args} . " -d";
                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
$ENV{LD_PRELOAD} = '';
$ENV{SEGFAULT_USE_ALTSTACK} = 1;
$ENV{SEGFAULT_SIGNALS} = '';
if ("${lxcfs_args}" ne q{}) {
                if (my $pid = fork()) {
                    # Parent process continues
                } elsif (defined $pid) {
                    # Child process executes the background command
                    $main_exit_code = system('lxcfs', $lxcfs_args, ${SNAP_COMMON} . "/var/lib/lxcfs", '-p', ${SNAP_COMMON} . "/lxcfs.pid") >> 8;
                    exit(0);
                } else {
                    die "Cannot fork: $ERRNO\n";
                }
}
            else {
                if (my $pid = fork()) {
                    # Parent process continues
                } elsif (defined $pid) {
                    # Child process executes the background command
                    $main_exit_code = system('lxcfs', ${SNAP_COMMON} . "/var/lib/lxcfs", '-p', ${SNAP_COMMON} . "/lxcfs.pid") >> 8;
                    exit(0);
                } else {
                    die "Cannot fork: $ERRNO\n";
                }
            }
require Time::HiRes; Time::HiRes::sleep(q{1});
        q{};
    };
}
$PID = "";
if ((-e "${SNAP_COMMON}/lxcfs.pid")) {
    open STDIN, '<', ${SNAP_COMMON} . "/lxcfs.pid" or croak "Cannot open file: $OS_ERROR\n";
$PID = <>;
chomp $PID;
$CHILD_ERROR = defined($PID) ? 0 : 1;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
if (("${PID}" ne q{} && "$(readlink "/proc/self/ns/mnt")" ne "$(readlink "/proc/${PID}/ns/mnt")")) {
    print "==> Cleaning up existing LXCFS namespace\n";
open STDIN, '<', "/proc/" . ${PID} . "/mountinfo" or croak "Cannot open file: $OS_ERROR\n";
    my $_;
    my $mp;
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $_ = $_fields[0] // q{};
    $_ = $_fields[1] // q{};
    $_ = $_fields[2] // q{};
    $_ = $_fields[3] // q{};
    $mp = $_fields[4] // q{};
    $_ = $_fields[5] // q{};
if (${mp} =~ /^${SNAP_COMMON}/shmounts/storage-pools/".*$/msx or ${mp} =~ /^${SNAP_COMMON}/lxd/storage-pools/".*$/msx) {
                                    $main_exit_code = system('nsenter', '-t', ${PID}, '-m', 'umount', '-l', ${mp}) >> 8;
            if ($CHILD_ERROR != 0) {
                1;
            }
        } elsif (1) {
        }
    }
}
my $pid;
for my $pid (do {
    my ($in_133, $out_133);
    my $pid_133 = open3($in_133, $out_133, '>&STDERR', 'pgrep', '--euid', q{0}, '--full', "lxd(\.debug)? --logfile");
    close $in_133 or croak 'Close failed: $OS_ERROR';
    my $result_133 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_133> };
    close $out_133 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_133, 0;
    $result_133
}) {
    my $grep_result_134;
my @grep_lines_134 = ();
my @grep_filtered_134 = grep { /SNAP_NAME=lxd/msxi } @grep_lines_134;
$grep_result_134 = scalar @grep_filtered_134 . "\n";
$CHILD_ERROR = scalar @grep_filtered_134 > 0 ? 0 : 1;
$grep_result_134 = q{};
    if ($CHILD_ERROR != 0) {
        next;    }
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "/proc/" . ${pid} . "/root" . ${SNAP_COMMON} . "/lxd/.validate"
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
        print $$;
if ( !( ($$) =~ m{\n\z}msx ) ) { print "\n"; }
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
if ("$(cat "${SNAP_COMMON}/lxd/.validate" 2>/dev/null)" eq "$$") {
        do {
    my $__echo_line = "=> Killing conflicting LXD (pid=" . ${pid} . ")";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        my $signal = '9';
my @pids = (${pid});
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
        if ($CHILD_ERROR != 0) {
            1;
        }
    }
if ( -e "/proc/" . ${pid} . "/root" . ${SNAP_COMMON} . "/lxd/.validate" ) {
        if ( -d "/proc/" . ${pid} . "/root" . ${SNAP_COMMON} . "/lxd/.validate" ) {
            carp "rm: carping: ", "/proc/" . ${pid} . "/root" . ${SNAP_COMMON} . "/lxd/.validate",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/proc/" . ${pid} . "/root" . ${SNAP_COMMON} . "/lxd/.validate" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/proc/" . ${pid} . "/root" . ${SNAP_COMMON} . "/lxd/.validate",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
}
if ((-l "${SNAP_COMMON}/lxd/lxd.db")) {
    print "=> Moving database from versioned path to common\n";
if ( -e "${SNAP_COMMON} . "/lxd/lxd.db"" ) {
        if ( -d "${SNAP_COMMON} . "/lxd/lxd.db"" ) {
            croak "rm: ", ${SNAP_COMMON} . "/lxd/lxd.db",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "${SNAP_COMMON} . "/lxd/lxd.db"" ) {
                            }
            else {
                croak "rm: cannot remove ", ${SNAP_COMMON} . "/lxd/lxd.db",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 1;
        croak "rm: ", ${SNAP_COMMON} . "/lxd/lxd.db", ": No such file or directory\n";
    }
    my $force = 0;
    if ( -e "${SNAP_DATA} . "/lxd/lxd.db"" ) {
        my $dest = ${SNAP_COMMON} . "/lxd/lxd.db";
        if ( -e $dest && -d $dest ) {
            my $source_name = "${SNAP_DATA} . "/lxd/lxd.db"";
            $source_name =~ s{^.*[\/]}{};
            $dest = "$dest/$source_name";
        }
        if ( -e $dest && !$force ) {
            croak "mv: $dest: File exists (use -f to force overwrite)\n";
        }
        my $dest_dir = $dest;
        $dest_dir =~ s/\/[^\/]*$//msx;
        if ( $dest_dir eq $dest ) {
            $dest_dir = q{};
        }
        if ( $dest_dir ne q{} && !-d $dest_dir ) {
            my $err;
            make_path( $dest_dir, { error => \$err } );
            if ( @{$err} ) {
                croak "mv: cannot create directory $dest_dir: $err->[0]\n";
            }
        }
        require File::Copy;
        if ( File::Copy::move( "${SNAP_DATA} . "/lxd/lxd.db"", $dest ) ) {
        } else {
            croak
  "mv: cannot move "${SNAP_DATA} . "/lxd/lxd.db"" to $dest: $ERRNO\n";
        }
    } else {
        croak "mv: "${SNAP_DATA} . "/lxd/lxd.db"": No such file or directory\n";
    }
}
if ((-x "${SNAP_COMMON}/lxc.debug")) {
    print "==> WARNING: A custom debug LXC binary was found!\n";
}
print "=> Starting LXD\n";
my $LXD;
my @LXD;
my %LXD;
$LXD = "lxd";
if ((-x "${SNAP_COMMON}/lxd.debug")) {
    $LXD = ${SNAP_COMMON} . "/lxd.debug";
$ENV{LXD_EXEC_PATH} = '';
    print "==> WARNING: Using a custom debug LXD binary!\n";
}
my $CMD;
my @CMD;
my %CMD;
$CMD = ${LXD} . " --logfile " . ${SNAP_COMMON} . "/lxd/logs/lxd.log";
if (!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('getent', 'group', ${daemon_group}) >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
})) {
    $CMD = ${CMD} . " --group " . ${daemon_group};
if ((-e "${SNAP_COMMON}/lxd/unix.socket")) {
        $main_exit_code = system('chgrp', ${daemon_group}, ${SNAP_COMMON} . "/lxd/unix.socket") >> 8;
    }
}
else {
    do {
    my $__echo_line = "==> No \"" . ${daemon_group} . "\" group found, only root will be able to use LXD.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
}
if ("${daemon_debug:-"false"}" eq "true") {
    $CMD = ${CMD} . " --debug";
}
if ("${daemon_syslog:-"false"}" eq "true") {
    $CMD = ${CMD} . " --syslog";
}
if ("${daemon_verbose:-"false"}" eq "true") {
    $CMD = ${CMD} . " --verbose";
}
if ("${db_trace:-"false"}" eq "true") {
$ENV{LIBDQLITE_TRACE} = 1;
}
$FIRSTRUN = "false";
if ((!-d "${SNAP_COMMON}/lxd/database")) {
    $FIRSTRUN = "true";
}
# set +e not implemented
if (my $pid = fork()) {
    # Parent process continues
} elsif (defined $pid) {
    # Child process executes the background command
    exec 'bash', '-c', q{(read -r sbpid _ < /proc/self/stat; : 'Complex command not supported in bash string generation'; : 'Complex command not supported in bash string generation')};
    croak "exec failed: $OS_ERROR\n";
} else {
    die "Cannot fork: $ERRNO\n";
}
$PID = $!;
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', ${SNAP_COMMON} . "/lxd.pid"
      or die "Cannot open file: $OS_ERROR\n";
    print ${PID};
if ( !( (${PID}) =~ m{\n\z}msx ) ) { print "\n"; }
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
if (my $pid = fork()) {
    # Parent process continues
} elsif (defined $pid) {
    # Child process executes the background command
    $CHILD_ERROR = 0;
    exit(0);
} else {
    die "Cannot fork: $ERRNO\n";
}
my $WAIT_PID;
my @WAIT_PID;
my %WAIT_PID;
$WAIT_PID = $!;
if (my $pid = fork()) {
    # Parent process continues
} elsif (defined $pid) {
    # Child process executes the background command
    exec 'bash', '-c', q{(: 'Complex command not supported in bash string generation')};
    croak "exec failed: $OS_ERROR\n";
} else {
    die "Cannot fork: $ERRNO\n";
}
1 while wait() > -1;
$CHILD_ERROR = $? == -1 ? 0 : $? >> 8;
$RET = $?;
if ((${RET} > 0)) {
    print "=> LXD failed to start\n";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', ${SNAP_COMMON} . "/state"
      or die "Cannot open file: $OS_ERROR\n";
        print "crashed\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
exit 1;
}
if ("${FIRSTRUN}" eq "true") {
$__set_e = 1;
    print "=> First LXD execution on this " . "sys" . "tem\n";
if ((-e "${SNAP_COMMON}/init.yaml")) {
        print "==> Running LXD preseed file\n";
open STDIN, '<', ${SNAP_COMMON} . "/init.yaml" or croak "Cannot open file: $OS_ERROR\n";
        $CHILD_ERROR = 0;
        if ( -e "${SNAP_COMMON} . "/init.yaml"" ) {
            my $dest = ${SNAP_COMMON} . "/init.yaml.applied";
            if ( -e $dest && -d $dest ) {
                my $source_name = "${SNAP_COMMON} . "/init.yaml"";
                $source_name =~ s{^.*[\/]}{};
                $dest = "$dest/$source_name";
            }
            if ( -e $dest && !$force ) {
                croak "mv: $dest: File exists (use -f to force overwrite)\n";
            }
            my $dest_dir = $dest;
            $dest_dir =~ s/\/[^\/]*$//msx;
            if ( $dest_dir eq $dest ) {
                $dest_dir = q{};
            }
            if ( $dest_dir ne q{} && !-d $dest_dir ) {
                my $err;
                make_path( $dest_dir, { error => \$err } );
                if ( @{$err} ) {
                    croak "mv: cannot create directory $dest_dir: $err->[0]\n";
                }
            }
            require File::Copy;
            if ( File::Copy::move( "${SNAP_COMMON} . "/init.yaml"", $dest ) ) {
            } else {
                croak
  "mv: cannot move "${SNAP_COMMON} . "/init.yaml"" to $dest: $ERRNO\n";
            }
        } else {
            croak "mv: "${SNAP_COMMON} . "/init.yaml"": No such file or directory\n";
        }
}
    else {
        if ("${LXD_APPLIANCE}" eq "true") {
            print "==> Initializing LXD appliance\n";
            my $NIC;
            my @NIC;
            my %NIC;
            $NIC = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_140 = q{};
                my $output_printed_140;
                my $pipeline_success_140 = 1;

                my ($in_141, $out_141);
                my $pid_141 = open3($in_141, $out_141, '>&STDERR', 'ip', '-4', '-o', 'route', 'get', '0.0.0.1');
                close $in_141 or croak 'Close failed: $OS_ERROR';
                $output_140 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_141> };
                close $out_141 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_141, 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_140 = 0; }
                my @lines_142 = split /\n/msx, $output_140;
                my @result_142;
                foreach my $line (@lines_142) {
                chomp $line;
                my @fields = split /\ /msx, $line;
                if (@fields > 4) {
                    push @result_142, $fields[4];
                }
                }
                $output_140 = join "\n", @result_142;
                if ($output_140 ne q{} && !($output_140  =~ m{\n\z}msx)) { $output_140 .= "\n"; }

                if ( !$pipeline_success_140 ) { $main_exit_code = 1; }
                exit $main_exit_code if $__set_e && $main_exit_code != 0;
                $output_140 =~ s/\n+\z//msx;
                $output_140;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
            $main_exit_code = system('lxc', '--force-local', '--quiet', 'profile', 'device', 'add', 'default', 'eth0', 'nic', 'nictype', q{=}, 'macvlan', 'parent', q{=}, ${NIC}, 'name', q{=}, 'eth0') >> 8;
            my $AVAIL;
            my @AVAIL;
            my %AVAIL;
            $AVAIL = (do { my $_chomp_temp = do {
    my ($in_143, $out_143);
    my $pid_143 = open3($in_143, $out_143, '>&STDERR', "$(df --output=avail \"${SNAP_COMMON}\" | tail -1)*1024*80/100");
    close $in_143 or croak 'Close failed: $OS_ERROR';
    my $result_143 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_143> };
    close $out_143 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_143, 0;
    $result_143
}; chomp $_chomp_temp; $_chomp_temp; });
            my $fs;
            for my $fs ('zfs', 'btrfs') {
                if (do {
$main_exit_code = system('lxc', '--force-local', '--quiet', 'storage', 'create', 'local', ${fs}, 'size', q{=}, ${AVAIL}) >> 8;
                    $CHILD_ERROR == 0
                }) {
                    last;                }
            }
            $main_exit_code = system('lxc', '--force-local', '--quiet', 'profile', 'device', 'add', 'default', 'root', 'disk', 'pool', q{=}, 'local', 'path', q{=}, q{/}) >> 8;
            $main_exit_code = system('lxc', '--force-local', '--quiet', 'config', 'set', 'core.https_address', ':8443') >> 8;
        }
    }
# set +e not implemented
}
print "=> LXD is ready\n";
1 while wait() > -1;
$CHILD_ERROR = $? == -1 ? 0 : $? >> 8;
$RET = $?;
if ((${RET} > 0)) {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', ${SNAP_COMMON} . "/state"
      or die "Cannot open file: $OS_ERROR\n";
        print "crashed\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
    my $__echo_line = "=> LXD failed with return code " . ${RET};
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
exit 1;
}
else {
    $STATE = "";
    if ((-e "${SNAP_COMMON}/state")) {
        open STDIN, '<', ${SNAP_COMMON} . "/state" or croak "Cannot open file: $OS_ERROR\n";
$STATE = <>;
chomp $STATE;
$CHILD_ERROR = defined($STATE) ? 0 : 1;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
if ("${STATE}" eq "reload") {
        print "=> LXD is reloading\n";
exit 1;
    }
if ("${STATE}" eq "host-shutdown") {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', ${SNAP_COMMON} . "/state"
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
1;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
}
    else {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', ${SNAP_COMMON} . "/state"
      or die "Cannot open file: $OS_ERROR\n";
            print 'shutdown' . "\n";
            $CHILD_ERROR = 0;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
    print "=> LXD exited cleanly\n";
}
exit 0;

exit $main_exit_code;
