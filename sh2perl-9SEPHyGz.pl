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

# shopt -s dotglob not implemented
$main_exit_code = system('bash', 'nullglob') >> 8;
my $TOOL;
my @TOOL;
my %TOOL;
$TOOL = 'blkdeactivate';
my $DEV_DIR;
my @DEV_DIR;
my %DEV_DIR;
$DEV_DIR = "/dev";
my $SYS_BLK_DIR;
my @SYS_BLK_DIR;
my %SYS_BLK_DIR;
$SYS_BLK_DIR = "/sys/block";
my $MDADM;
my @MDADM;
my %MDADM;
$MDADM = "/sbin/mdadm";
my $MOUNTPOINT;
my @MOUNTPOINT;
my %MOUNTPOINT;
$MOUNTPOINT = "/bin/mountpoint";
my $MPATHD;
my @MPATHD;
my %MPATHD;
$MPATHD = "/sbin/multipathd";
my $UMOUNT;
my @UMOUNT;
my %UMOUNT;
$UMOUNT = "/bin/umount";
my $VDO;
my @VDO;
my %VDO;
$VDO = "/bin/vdo";
my $sbindir;
my @sbindir;
my %sbindir;
$sbindir = "/usr/sbin";
my $DMSETUP;
my @DMSETUP;
my %DMSETUP;
$DMSETUP = "$sbindir/dmsetup";
my $LVM;
my @LVM;
my %LVM;
$LVM = "$sbindir/lvm";
if (!(# Original bash: "$UMOUNT" --help | grep -- "--all-targets" >"$DEV_DIR/null";
{
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;
        my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'unknown_command', '--help');
    close $in_1 or croak 'Close failed: $OS_ERROR';
    $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;

        do {
    open my $original_stdout, '>&', STDOUT
    or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', "$DEV_DIR/null"
    or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    my $tmp_redirect_2 = q{};
    my $grep_result_3;
    my @grep_lines_3 = split /\n/msx, $output_0;
    my @grep_filtered_3 = grep { /--all-targets/msx } @grep_lines_3;
    $grep_result_3 = join "\n", @grep_filtered_3;
    if (!($grep_result_3 =~ m{\n\z}msx || $grep_result_3 eq q{})) {
    $grep_result_3 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_3 > 0 ? 0 : 1;
    $tmp_redirect_2 = $grep_result_3;
    $tmp_redirect_2;
    };
    print $tmp;
    if ($tmp eq q{}) { print $output_0; }
    $output_printed_0 = 1;
    open STDOUT, '>&', $original_stdout
    or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
    or die "Close failed: $OS_ERROR\n";
    };
    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    })) {
    my $UMOUNT_OPTS;
    my @UMOUNT_OPTS;
    my %UMOUNT_OPTS;
    $UMOUNT_OPTS = "--all-targets ";
}
else {
    $UMOUNT_OPTS = "";
    my $FINDMNT;
    my @FINDMNT;
    my %FINDMNT;
    $FINDMNT = "/bin/findmnt -r --noheadings -u -o TARGET";
    my $FINDMNT_READ;
    my @FINDMNT_READ;
    my %FINDMNT_READ;
    $FINDMNT_READ = "read -r mnt";
}
my $DMSETUP_OPTS;
my @DMSETUP_OPTS;
my %DMSETUP_OPTS;
$DMSETUP_OPTS = "";
my $LVM_OPTS;
my @LVM_OPTS;
my %LVM_OPTS;
$LVM_OPTS = "";
my $MDADM_OPTS;
my @MDADM_OPTS;
my %MDADM_OPTS;
$MDADM_OPTS = "";
my $MPATHD_OPTS;
my @MPATHD_OPTS;
my %MPATHD_OPTS;
$MPATHD_OPTS = "";
my $VDO_OPTS;
my @VDO_OPTS;
my %VDO_OPTS;
$VDO_OPTS = "";
my $LSBLK;
my @LSBLK;
my %LSBLK;
$LSBLK = "/bin/lsblk -r --noheadings -o TYPE,KNAME,NAME,MOUNTPOINT";
my $LSBLK_VARS;
my @LSBLK_VARS;
my %LSBLK_VARS;
$LSBLK_VARS = "local devtype local kname local name local mnt";
my $LSBLK_READ;
my @LSBLK_READ;
my %LSBLK_READ;
$LSBLK_READ = "read -r devtype kname name mnt";
my $SORT_MNT;
my @SORT_MNT;
my %SORT_MNT;
$SORT_MNT = "/bin/sort -r -u -k 4";
my $ERRORS;
my @ERRORS;
my %ERRORS;
$ERRORS = q{0};
my $VERBOSE;
my @VERBOSE;
my %VERBOSE;
$VERBOSE = q{0};
my $DO_UMOUNT;
my @DO_UMOUNT;
my %DO_UMOUNT;
$DO_UMOUNT = q{0};
my $LVM_DO_WHOLE_VG;
my @LVM_DO_WHOLE_VG;
my %LVM_DO_WHOLE_VG;
$LVM_DO_WHOLE_VG = q{0};
my $LVM_CONFIG;
my @LVM_CONFIG;
my %LVM_CONFIG;
$LVM_CONFIG = "activation{retry_deactivation=0}";
my $MDRAID_DO_WAIT;
my @MDRAID_DO_WAIT;
my %MDRAID_DO_WAIT;
$MDRAID_DO_WAIT = q{0};
my $MPATHD_DO_DISABLEQUEUEING;
my @MPATHD_DO_DISABLEQUEUEING;
my %MPATHD_DO_DISABLEQUEUEING;
$MPATHD_DO_DISABLEQUEUEING = q{0};
my %SKIP_DEVICE_LIST = ();
my %SKIP_VG_LIST = ();
my %SKIP_UMOUNT_LIST = ('[/]=1', '[/lib]=1', '[/lib64]=1', '[/bin]=1', '[/sbin]=1', '[/var]=1', '[/var/log]=1', '[/usr]=1', '[/usr/lib]=1', '[/usr/lib64]=1', '[/usr/sbin]=1', '[/usr/bin]=1');
$SKIP_UMOUNT_LIST{"[SWAP"} = q{1};

sub usage {
    print ${TOOL} . ": Utility to deactivate block devices";
if ( !( (${TOOL} . ": Utility to deactivate block devices") =~ m{\n\z}msx ) ) { print "\n"; }
    print "\n";
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "  " . ${TOOL} . " [options] [device...]";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    print "    - Deactivate block device tree.\n";
    print "      If devices are specified, deactivate only supplied devices and their holders.\n";
    print "\n";
    $CHILD_ERROR = 0;
    print "  Options:\n";
    print "    -e | --errors                       Show errors reported from tools\n";
    print "    -h | --help                         Show this help message\n";
    print "    -d | --dmoptions     DM_OPTIONS     Comma separated DM specific options\n";
    print "    -l | --lvmoptions    LVM_OPTIONS    Comma separated LVM specific options\n";
    print "    -m | --mpathoptions  MPATH_OPTIONS  Comma separated DM-multipath specific options\n";
    print "    -r | --mdraidoptions MDRAID_OPTIONS Comma separated MD RAID specific options\n";
    print "    -o | --vdooptions    VDO_OPTIONS    Comma separated VDO specific options\n";
    print "    -u | --umount                       Unmount the device if mounted\n";
    print "    -v | --verbose                      Verbose mode (also implies -e)\n";
    print "\n";
    $CHILD_ERROR = 0;
    print "  Device specific options:\n";
    print "    DM_OPTIONS:\n";
    print "      retry           retry removal several times in case of failure\n";
    print "      force           force device removal\n";
    print "    LVM_OPTIONS:\n";
    print "      retry           retry removal several times in case of failure\n";
    print "      wholevg         deactivate the whole VG when processing an LV\n";
    print "    MDRAID_OPTIONS:\n";
    print "      wait            wait for resync, recovery or reshape to complete first\n";
    print "    MPATH_OPTIONS:\n";
    print "      disablequeueing disable queueing on all DM-multipath devices first\n";
    print "    VDO_OPTIONS:\n";
    print "      configfile=file use specified VDO configuration file\n";
exit $main_exit_code;
    return;
}

sub add_device_to_skip_list {
    push @SKIP_DEVICE_LIST, '[$kname]=1';
return q{1};
    return;
}

sub add_vg_to_skip_list {
    push @SKIP_VG_LIST, '[$DM_VG_NAME]=1';
return q{1};
    return;
}

sub is_top_level_device {
    my $files;
    my @files;
    my %files;
    $files = ("$SYS_BLK_DIR/$ENV{kname}/holders/" . q{ } . q{*});
    $main_exit_code = system('test', '-z', "$files") >> 8;
    return;
}

sub device_umount_one {
    if (do {
$main_exit_code = system('test', '-z', "$ENV{mnt}") >> 8;
        $CHILD_ERROR == 0
    }) {
        return q{0};    }
if ((StringInterpolation(StringInterpolation { parts: [ParameterExpansion(ParameterExpansion { variable: "SKIP_UMOUNT_LIST[\"$mnt\"]", operator: None, is_mutable: true })] }, None) eq q{} && (StringInterpolation(StringInterpolation { parts: [Variable("DO_UMOUNT")] }, None) == StringInterpolation(StringInterpolation { parts: [Literal("1")] }, None)))) {
        print "  [UMOUNT]: unmounting $ENV{name} ($ENV{kname}) mounted on $ENV{mnt}... ";
if (!(do { my $eval_input = $UMOUNT . $UMOUNT_OPTS . q{} . $OUT . $ERR; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; })) {
            print "done\n";
}
        else {
            if (!(            $CHILD_ERROR = 0)) {
                print "skipping\n";
                add_device_to_skip_list();
}
            else {
                print "already unmounted\n";
            }
        }
}
    else {
        do {
    my $__echo_line = "  [SKIP]: unmount of $ENV{name} ($ENV{kname}) mounted on $ENV{mnt}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        add_device_to_skip_list();
    }
    return;
}

sub device_umount {
    if (do {
if (do {
if (do {
$main_exit_code = system('test', "$ENV{devtype}", q{!}, q{=}, "lvm") >> 8;
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('test', substr($ENV{kname}, 0, 3), q{!}, q{=}, "dm-") >> 8;
}
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('test', substr($ENV{kname}, 0, 2), q{!}, q{=}, "md") >> 8;
}
        $CHILD_ERROR == 0
    }) {
        return q{0};    }
if (StringInterpolation(StringInterpolation { parts: [Variable("FINDMNT")] }, None) eq q{}) {
        device_umount_one();
}
    else {
while (         $CHILD_ERROR = 0 ) {
                        device_umount_one();
            if ($CHILD_ERROR != 0) {
                return q{1};            }
        }
    }
    return;
}

sub deactivate_holders {
    my $skip = "1";
    $CHILD_ERROR = 0;
while (     $CHILD_ERROR = 0 ) {
                $main_exit_code = system('test', '-e', "$SYS_BLK_DIR/$ENV{kname}") >> 8;
        if ($CHILD_ERROR != 0) {
            next;        }
                $main_exit_code = system('test', '-z', $SKIP_DEVICE_LIST{'"$kname"'}) >> 8;
        if ($CHILD_ERROR != 0) {
            return q{1};        }
        if (do {
if (do {
$main_exit_code = system('test', "$skip", '-eq', q{1}) >> 8;
    $CHILD_ERROR == 0
}) {
        $skip = q{0};
}
            $CHILD_ERROR == 0
        }) {
            next;        }
                $main_exit_code = system('bash', 'deactivate') >> 8;
        if ($CHILD_ERROR != 0) {
            return q{1};        }
    }
    return;
}

sub deactivate_dm {
    my $xname;
    $xname = sprintf('%s', "$ENV{name}");
;
        $main_exit_code = system('test', '-b', "$DEV_DIR/mapper/$xname") >> 8;
    if ($CHILD_ERROR != 0) {
        return q{0};    }
        $main_exit_code = system('test', '-z', $SKIP_DEVICE_LIST{'"$kname"'}) >> 8;
    if ($CHILD_ERROR != 0) {
        return q{1};    }
        deactivate_holders("$DEV_DIR/mapper/$xname");
    if ($CHILD_ERROR != 0) {
        return q{1};    }
    print "  [DM]: deactivating $ENV{devtype} device $xname ($ENV{kname})... ";
if (!(do { my $eval_input = $DMSETUP . $DMSETUP_OPTS . "remove" . $xname . $OUT . $ERR; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; })) {
        print "done\n";
}
    else {
        print "skipping\n";
        add_device_to_skip_list();
    }
    return;
}

sub deactivate_lvm {
    my $DM_VG_NAME;
    my $DM_LV_NAME;
do { my $eval_input = q{}; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
        $main_exit_code = system('test', '-b', "$DEV_DIR/$DM_VG_NAME/$DM_LV_NAME") >> 8;
    if ($CHILD_ERROR != 0) {
        return q{0};    }
        $main_exit_code = system('test', '-z', $SKIP_VG_LIST{'"$DM_VG_NAME"'}) >> 8;
    if ($CHILD_ERROR != 0) {
        return q{1};    }
if ((StringInterpolation(StringInterpolation { parts: [Variable("LVM_DO_WHOLE_VG")] }, None) == 0)) {
        if (do {
$main_exit_code = system('test', "$ENV{LVM_AVAILABLE}", '-eq', q{0}) >> 8;
            $CHILD_ERROR == 0
        }) {
                            add_device_to_skip_list();
return q{1};
        }
                deactivate_holders("$DEV_DIR/$DM_VG_NAME/$DM_LV_NAME");
        if ($CHILD_ERROR != 0) {
                            add_device_to_skip_list();
return q{1};
        }
        print "  [LVM]: deactivating Logical Volume $DM_VG_NAME/$DM_LV_NAME... ";
if (!(do { my $eval_input = $LVM . "lvchange" . $LVM_OPTS . "--config" . "\\'log\\{prefix" . "=" . "\\\"\\\"\\}" . $LVM_CONFIG . "\\'" . "-aln" . $DM_VG_NAME . "/" . $DM_LV_NAME . $OUT . $ERR; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; })) {
            print "done\n";
}
        else {
            print "skipping\n";
            add_device_to_skip_list();
        }
}
    else {
        if (do {
$main_exit_code = system('test', "$ENV{LVM_AVAILABLE}", '-eq', q{0}) >> 8;
            $CHILD_ERROR == 0
        }) {
                            add_vg_to_skip_list();
return q{1};
        }
        my $lv_list;
        my @lv_list;
        my %lv_list;
        $lv_list = do {
    local $ENV{DM_VG_NAME} = $DM_VG_NAME;
    local $ENV{ERR} = $ERR;
    local $ENV{LVM} = $LVM;
    local $ENV{LVM_CONFIG} = $LVM_CONFIG;
    my $command = q{: 'Complex command not supported in bash string generation'};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
};
        my $lv;
        for my $lv ($lv_list) {
                        $main_exit_code = system('test', '-b', "$DEV_DIR/$DM_VG_NAME/$lv") >> 8;
            if ($CHILD_ERROR != 0) {
                next;            }
                        deactivate_holders("$DEV_DIR/$DM_VG_NAME/$lv");
            if ($CHILD_ERROR != 0) {
                                    add_vg_to_skip_list();
return q{1};
            }
        }
        print "  [LVM]: deactivating Volume Group $DM_VG_NAME... ";
if (!(do { my $eval_input = $LVM . "vgchange" . $LVM_OPTS . "--config" . "\\'log\\{prefix" . "=" . "\\\"" . "\\\"\\}" . $LVM_CONFIG . "\\'" . "-aln" . $DM_VG_NAME . $OUT . $ERR; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; })) {
            print "done\n";
}
        else {
            print "skipping\n";
            add_vg_to_skip_list();
        }
    }
    return;
}

sub deactivate_md {
    my $xname;
    $xname = sprintf('%s', "$ENV{name}");
;
    my $sync_action;
        $main_exit_code = system('test', '-b', "$DEV_DIR/$xname") >> 8;
    if ($CHILD_ERROR != 0) {
        return q{0};    }
        $main_exit_code = system('test', '-z', $SKIP_DEVICE_LIST{'"$kname"'}) >> 8;
    if ($CHILD_ERROR != 0) {
        return q{1};    }
    if (do {
$main_exit_code = system('test', "$ENV{MDADM_AVAILABLE}", '-eq', q{0}) >> 8;
        $CHILD_ERROR == 0
    }) {
                    add_device_to_skip_list();
return q{1};
    }
        deactivate_holders("$DEV_DIR/$xname");
    if ($CHILD_ERROR != 0) {
        return q{1};    }
    print "  [MD]: deactivating $ENV{devtype} device $ENV{kname}... ";
    if (do {
$main_exit_code = system('test', "$MDRAID_DO_WAIT", '-eq', q{1}) >> 8;
        $CHILD_ERROR == 0
    }) {
                    $sync_action = do { my $cat_chunk = q{}; if ( open my $fh, '<', "$SYS_BLK_DIR/$ENV{kname}/md/sync_action" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$SYS_BLK_DIR/$ENV{kname}/md/sync_action" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
            if (do {
$main_exit_code = system('test', "$sync_action", q{!}, q{=}, "idle") >> 8;
                $CHILD_ERROR == 0
            }) {
                                    print "$sync_action action in progress... ";
if (!(do { my $eval_input = $MDADM . $MDADM_OPTS . "-W" . $DEV_DIR . "/" . $kname . $OUT . $ERR; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; })) {
                        print "complete... ";
}
                    else {
                        if (do {
$main_exit_code = system('test', $?, '-ne', q{1}) >> 8;
                            $CHILD_ERROR == 0
                        }) {
                                                        print "failed to wait for $sync_action action... ";
                        }
                    }
            }
    }
if (!(do { my $eval_input = $MDADM . $MDADM_OPTS . "-S" . $xname . $OUT . $ERR; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; })) {
        print "done\n";
}
    else {
        print "skipping\n";
        add_device_to_skip_list();
    }
    return;
}

sub deactivate_vdo {
    my $xname;
    $xname = sprintf('%s', "$ENV{name}");
;
        $main_exit_code = system('test', '-b', "$DEV_DIR/mapper/$xname") >> 8;
    if ($CHILD_ERROR != 0) {
        return q{0};    }
        $main_exit_code = system('test', '-z', $SKIP_DEVICE_LIST{'"$kname"'}) >> 8;
    if ($CHILD_ERROR != 0) {
        return q{1};    }
    if (do {
$main_exit_code = system('test', "$ENV{VDO_AVAILABLE}", '-eq', q{0}) >> 8;
        $CHILD_ERROR == 0
    }) {
                    add_device_to_skip_list();
return q{1};
    }
        deactivate_holders("$DEV_DIR/mapper/$xname");
    if ($CHILD_ERROR != 0) {
        return q{1};    }
    print "  [VDO]: deactivating VDO volume $xname... ";
if (!(do { my $eval_input = $VDO . "stop" . $VDO_OPTS . "--name=$xname" . $OUT . $ERR; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; })) {
        print "done\n";
}
    else {
        print "skipping\n";
        add_device_to_skip_list();
    }
    return;
}

sub deactivate {
if (StringInterpolation(StringInterpolation { parts: [Variable("devtype")] }, None) eq StringInterpolation(StringInterpolation { parts: [Literal("lvm")] }, None)) {
        deactivate_lvm();
}
    else {
        if (StringInterpolation(StringInterpolation { parts: [Variable("devtype")] }, None) eq StringInterpolation(StringInterpolation { parts: [Literal("vdo")] }, None)) {
            deactivate_vdo();
}
        else {
            if (StringInterpolation(StringInterpolation { parts: [ParameterExpansion(ParameterExpansion { variable: "kname:0:3", operator: None, is_mutable: true })] }, None) eq StringInterpolation(StringInterpolation { parts: [Literal("dm-")] }, None)) {
                deactivate_dm();
}
            else {
                if (StringInterpolation(StringInterpolation { parts: [ParameterExpansion(ParameterExpansion { variable: "kname:0:2", operator: None, is_mutable: true })] }, None) eq StringInterpolation(StringInterpolation { parts: [Literal("md")] }, None)) {
                    deactivate_md();
                }
            }
        }
    }
    return;
}

sub deactivate_all {
    my ($file) = @_;
    $CHILD_ERROR = 0;
    my $skip;
    my @skip;
    my %skip;
    $skip = q{0};
    print "Deactivating block devices:\n";
    if (do {
$main_exit_code = system('test', "$ENV{MPATHD_RUNNING}", '-eq', q{1}) >> 8;
        $CHILD_ERROR == 0
    }) {
                    print "  [DM]: disabling queueing on all multipath devices... ";
                        if (do {
{
    my $output_6 = q{};
    my $output_printed_6;
    my $pipeline_success_6 = 1;
        my @_pcmd_8 = ('bash', '-c', ": \"Complex command cannot be converted to shell command\"");
    my ($in_7);
    my $pid_7 = open3($in_7, $out_7, '>&STDERR', @_pcmd_8);
    close $in_7 or croak 'Close failed: $OS_ERROR';
    my $temp_result;
    $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
    $output_6 = $temp_result;
    close $out_7 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_7, 0;

        do {
    open my $original_stdout, '>&', STDOUT
    or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', "$DEV_DIR/null"
    or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    my $tmp_redirect_9 = q{};
    my $grep_result_10;
    my @grep_lines_10 = split /\n/msx, $output_6;
    my @grep_filtered_10 = grep { /^ok$/msx } @grep_lines_10;
    $grep_result_10 = join "\n", @grep_filtered_10;
    if (!($grep_result_10 =~ m{\n\z}msx || $grep_result_10 eq q{})) {
    $grep_result_10 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_10 > 0 ? 0 : 1;
    $tmp_redirect_9 = $grep_result_10;
    $tmp_redirect_9;
    };
    print $tmp;
    if ($tmp eq q{}) { print $output_6; }
    $output_printed_6 = 1;
    open STDOUT, '>&', $original_stdout
    or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
    or die "Close failed: $OS_ERROR\n";
    };
    if ( !$pipeline_success_6 ) { $main_exit_code = 1; }
    }
                $CHILD_ERROR == 0
            }) {
                                print "done\n";
            }
            if ($CHILD_ERROR != 0) {
                                print "failed\n";
            }
    }
if ((Variable("#", false, None) == 0)) {
while (         $CHILD_ERROR = 0 ) {
            device_umount();
        }
while (         $CHILD_ERROR = 0 ) {
            if (do {
$main_exit_code = system('test', "$ENV{devtype}", q{=}, "disk") >> 8;
                $CHILD_ERROR == 0
            }) {
                next;            }
            if (do {
$main_exit_code = system('test', "$skip", '-eq', q{1}) >> 8;
                $CHILD_ERROR == 0
            }) {
                if (!(                    is_top_level_device())) {
                        $skip = q{0};
}
                    else {
next;
                    }
            }
                        $main_exit_code = system('test', '-z', $SKIP_DEVICE_LIST{'"$kname"'}) >> 8;
            if ($CHILD_ERROR != 0) {
                next;            }
                        deactivate();
            if ($CHILD_ERROR != 0) {
                                $skip = q{1};
            }
        }
}
    else {
        my $# = 0;
while ( (Variable("#", false, None) != 0) ) {
while (             $CHILD_ERROR = 0 ) {
                device_umount();
            }
if ((-b StringInterpolation(StringInterpolation { parts: [Variable("1")] }, None))) {
                $CHILD_ERROR = 0;
                                $main_exit_code = system('test', '-z', $SKIP_DEVICE_LIST{'"$kname"'}) >> 8;
                if ($CHILD_ERROR != 0) {
                    # Builtin command 'shift' not implemented
next;
                }
                deactivate();
}
            else {
                do {
    my $__echo_line = "$_[0]: device not found";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
return q{1};
            }
# Builtin command 'shift' not implemented
        }
    }
    return;
}

sub get_dmopts {
    my $ORIG_IFS;
    my @ORIG_IFS;
    my %ORIG_IFS;
    $ORIG_IFS = $IFS;
    my $IFS;
    my @IFS;
    my %IFS;
    $IFS = q{,};
    my $opt;
    for my $opt ($1) {
if ($opt =~ /^$/msx) {
        } elsif ($opt =~ /^retry$/msx) {
                        $DMSETUP_OPTS = "--retry ";
        } elsif ($opt =~ /^force$/msx) {
                        $DMSETUP_OPTS = "--force ";
        } elsif (1) {
                        do {
    my $__echo_line = "$opt: unknown DM option";
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
    $IFS = $ORIG_IFS;
    return;
}

sub get_lvmopts {
    my $ORIG_IFS;
    my @ORIG_IFS;
    my %ORIG_IFS;
    $ORIG_IFS = $IFS;
    my $IFS;
    my @IFS;
    my %IFS;
    $IFS = q{,};
    my $opt;
    for my $opt ($1) {
if ("$opt" =~ /^$/msx) {
        } elsif ("$opt" =~ /^retry$/msx) {
                        $LVM_CONFIG = "activation{retry_deactivation=1}";
        } elsif ("$opt" =~ /^wholevg$/msx) {
                        $LVM_DO_WHOLE_VG = q{1};
        } elsif (1) {
                        do {
    my $__echo_line = "$opt: unknown LVM option";
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
    $IFS = $ORIG_IFS;
    return;
}

sub get_mdraidopts {
    my $ORIG_IFS;
    my @ORIG_IFS;
    my %ORIG_IFS;
    $ORIG_IFS = $IFS;
    my $IFS;
    my @IFS;
    my %IFS;
    $IFS = q{,};
    my $opt;
    for my $opt ($1) {
if ("$opt" =~ /^$/msx) {
        } elsif ("$opt" =~ /^wait$/msx) {
                        $MDRAID_DO_WAIT = q{1};
        } elsif (1) {
                        do {
    my $__echo_line = "$opt: unknown MD RAID option";
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
    $IFS = $ORIG_IFS;
    return;
}

sub get_mpathopts {
    my $ORIG_IFS;
    my @ORIG_IFS;
    my %ORIG_IFS;
    $ORIG_IFS = $IFS;
    my $IFS;
    my @IFS;
    my %IFS;
    $IFS = q{,};
    my $opt;
    for my $opt ($1) {
if ("$opt" =~ /^$/msx) {
        } elsif ("$opt" =~ /^disablequeueing$/msx) {
                        $MPATHD_DO_DISABLEQUEUEING = q{1};
        } elsif (1) {
                        do {
    my $__echo_line = "$opt: unknown DM-multipath option";
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
    $IFS = $ORIG_IFS;
    return;
}

sub get_vdoopts {
    my $ORIG_IFS;
    my @ORIG_IFS;
    my %ORIG_IFS;
    $ORIG_IFS = $IFS;
    my $IFS;
    my @IFS;
    my %IFS;
    $IFS = q{,};
    my $opt;
    for my $opt ($1) {
if ("$opt" =~ /^$/msx) {
        } elsif ("$opt" =~ /^configfile=.*$/msx) {
                        my $tmp;
            my @tmp;
            my %tmp;
            $tmp = ${opt} =~ s/^.*?=//r;
                        $VDO_OPTS = "--confFile=" . (${tmp} =~ s/,.*$//sr =~ s/,.*$//sr) . " ";
        } elsif (1) {
                        do {
    my $__echo_line = "$opt: unknown VDO option";
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
    $IFS = $ORIG_IFS;
    return;
}

sub set_env {
if ((StringInterpolation(StringInterpolation { parts: [Variable("ERRORS")] }, None) == StringInterpolation(StringInterpolation { parts: [Literal("1")] }, None))) {
delete $ENV{ERR};
}
    else {
        my $ERR;
        my @ERR;
        my %ERR;
        $ERR = "2>$DEV_DIR/null";
    }
if ((StringInterpolation(StringInterpolation { parts: [Variable("VERBOSE")] }, None) == StringInterpolation(StringInterpolation { parts: [Literal("1")] }, None))) {
delete $ENV{OUT};
        $UMOUNT_OPTS = "-v";
        $DMSETUP_OPTS = "-vvvv";
        $LVM_OPTS = "-vvvv";
        $MDADM_OPTS = "-vv";
        $MPATHD_OPTS = "-v 3";
        $VDO_OPTS = "--verbose ";
}
    else {
        my $OUT;
        my @OUT;
        my %OUT;
        $OUT = "1>$DEV_DIR/null";
    }
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("LVM")] }, None)')) {
        my $LVM_AVAILABLE;
        my @LVM_AVAILABLE;
        my %LVM_AVAILABLE;
        $LVM_AVAILABLE = q{1};
}
    else {
        $LVM_AVAILABLE = q{0};
    }
if ((-f 'Variable("MDADM", false, None)')) {
        my $MDADM_AVAILABLE;
        my @MDADM_AVAILABLE;
        my %MDADM_AVAILABLE;
        $MDADM_AVAILABLE = q{1};
}
    else {
        $MDADM_AVAILABLE = q{0};
    }
if ((-f 'Variable("VDO", false, None)')) {
        my $VDO_AVAILABLE;
        my @VDO_AVAILABLE;
        my %VDO_AVAILABLE;
        $VDO_AVAILABLE = q{1};
}
    else {
        $VDO_AVAILABLE = q{0};
    }
    my $MPATHD_RUNNING;
    my @MPATHD_RUNNING;
    my %MPATHD_RUNNING;
    $MPATHD_RUNNING = q{0};
    if (do {
$main_exit_code = system('test', "$MPATHD_DO_DISABLEQUEUEING", '-eq', q{1}) >> 8;
        $CHILD_ERROR == 0
    }) {
        if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("MPATHD")] }, None)')) {
if (!(                # Original bash: eval "$MPATHD" show daemon "$ERR" | grep "running" >"$DEV_DIR/null";
{
                    my $output_21 = q{};
                    my $output_printed_21;
                    my $pipeline_success_21 = 1;
                                        my @_pcmd_23 = ('bash', '-c', ": \"Complex command cannot be converted to shell command\"");
                    my ($in_22);
                    my $pid_22 = open3($in_22, $out_22, '>&STDERR', @_pcmd_23);
                    close $in_22 or croak 'Close failed: $OS_ERROR';
                    my $temp_result;
                    $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_22> };
                    $output_21 = $temp_result;
                    close $out_22 or croak 'Close failed: $OS_ERROR';
                    waitpid $pid_22, 0;

                                        do {
                    open my $original_stdout, '>&', STDOUT
                    or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', "$DEV_DIR/null"
                    or die "Cannot open file: $OS_ERROR\n";
                    my $tmp = do {
                    my $tmp_redirect_24 = q{};
                    my $grep_result_25;
                    my @grep_lines_25 = split /\n/msx, $output_21;
                    my @grep_filtered_25 = grep { /running/msx } @grep_lines_25;
                    $grep_result_25 = join "\n", @grep_filtered_25;
                    if (!($grep_result_25 =~ m{\n\z}msx || $grep_result_25 eq q{})) {
                    $grep_result_25 .= "\n";
                    }
                    $CHILD_ERROR = scalar @grep_filtered_25 > 0 ? 0 : 1;
                    $tmp_redirect_24 = $grep_result_25;
                    $tmp_redirect_24;
                    };
                    print $tmp;
                    if ($tmp eq q{}) { print $output_21; }
                    $output_printed_21 = 1;
                    open STDOUT, '>&', $original_stdout
                    or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
                    or die "Close failed: $OS_ERROR\n";
                    };
                    if ( !$pipeline_success_21 ) { $main_exit_code = 1; }
                    })) {
                    $MPATHD_RUNNING = q{1};
                }
            }
    }
    return;
}
my $# = 0;
while ( (Variable("#", false, None) != 0) ) {
if ("$_[0]" =~ /^$/msx) {
    } elsif ("$_[0]" =~ /^-e$/msx or "$_[0]" =~ /^--errors$/msx) {
                $ERRORS = q{1};
    } elsif ("$_[0]" =~ /^-h$/msx or "$_[0]" =~ /^--help$/msx) {
                usage();
    } elsif ("$_[0]" =~ /^-d$/msx or "$_[0]" =~ /^--dmoptions$/msx) {
                get_dmopts("$_[1]");
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-l$/msx or "$_[0]" =~ /^--lvmoptions$/msx) {
                get_lvmopts("$_[1]");
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-m$/msx or "$_[0]" =~ /^--mpathoptions$/msx) {
                get_mpathopts("$_[1]");
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-r$/msx or "$_[0]" =~ /^--mdraidoptions$/msx) {
                get_mdraidopts("$_[1]");
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-o$/msx or "$_[0]" =~ /^--vdooptions$/msx) {
                get_vdoopts("$_[1]");
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-u$/msx or "$_[0]" =~ /^--umount$/msx) {
                $DO_UMOUNT = q{1};
    } elsif ("$_[0]" =~ /^-v$/msx or "$_[0]" =~ /^--verbose$/msx) {
                $VERBOSE = q{1};
                $ERRORS = q{1};
    } elsif ("$_[0]" =~ /^-vv$/msx) {
                $VERBOSE = q{1};
                $ERRORS = q{1};
        # set -x not implemented
    } elsif (1) {
        last;    }
# Builtin command 'shift' not implemented
}
set_env();
deactivate_all("@ARGV");

exit $main_exit_code;
