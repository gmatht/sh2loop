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

my $BRANCH;
my @BRANCH;
my %BRANCH;
my $LINUXFAMILY;
my @LINUXFAMILY;
my %LINUXFAMILY;

my $MAGIC_5       = 5;
my $MAGIC_4000000 = 4_000_000;
my $MAGIC_70      = 70;
my $MAGIC_60      = 60;
my $MAGIC_8       = 8;
my $MAGIC_16      = 16;
my $MAGIC_7       = 7;
my $MAGIC_10      = 10;
my $MAGIC_30      = 30;
my $MAGIC_67      = 67;

if ((-f '/usr/lib/u-boot/platform_install.sh')) {
    # Builtin command 'source' not implemented
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
my $CWD;
my @CWD;
my %CWD;
$CWD = "/usr/lib/nand-sata-install";
my $EX_LIST;
my @EX_LIST;
my %EX_LIST;
$EX_LIST = ${CWD} . "/exclude.txt";
if ((-f '/etc/default/openmediavault')) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', ${EX_LIST}
      or die "Cannot open file: $OS_ERROR\n";
        print '/srv/*' . "\n";
        $CHILD_ERROR = 0;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
my $logfile;
my @logfile;
my %logfile;
$logfile = "/var/log/nand-sata-install.log";
if ((-f '/etc/orangepi-release')) {
    # Builtin command 'source' not implemented
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
my $backtitle;
my @backtitle;
my %backtitle;
$backtitle = "$ENV{BOARD_NAME} install script, http://www.orangepi.org";
my $title;
my @title;
my %title;
$title = "eMMC and USB Orange Pi installer v" . ($ENV{VERSION} // q{});
if (!(my $grep_result_0;
my @grep_lines_0 = ();
my @grep_filenames_0 = ();
if (-e "/proc/cpuinfo") {
    open my $fh, '<', "/proc/cpuinfo" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_0, $line;
        push @grep_filenames_0, "/proc/cpuinfo";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /proc/cpuinfo: No such file or directory\n"; }
my @grep_filtered_0 = grep { /sun4i/msx } @grep_lines_0;
$grep_result_0 = join "\n", @grep_filtered_0;
if (!($grep_result_0 =~ m{\n\z}msx || $grep_result_0 eq q{})) {
    $grep_result_0 .= "\n";
}
$CHILD_ERROR = scalar @grep_filtered_0 > 0 ? 0 : 1;
$grep_result_0 = q{})) {
    my $DEVICE_TYPE;
    my @DEVICE_TYPE;
    my %DEVICE_TYPE;
    $DEVICE_TYPE = "a10";
}
else {
    if (!(my $grep_result_1;
my @grep_lines_1 = ();
my @grep_filenames_1 = ();
if (-e "/proc/cpuinfo") {
    open my $fh, '<', "/proc/cpuinfo" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_1, $line;
        push @grep_filenames_1, "/proc/cpuinfo";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /proc/cpuinfo: No such file or directory\n"; }
my @grep_filtered_1 = grep { /sun5i/msx } @grep_lines_1;
$grep_result_1 = join "\n", @grep_filtered_1;
    if (!($grep_result_1 =~ m{\n\z}msx || $grep_result_1 eq q{})) {
        $grep_result_1 .= "\n";
    }
$CHILD_ERROR = scalar @grep_filtered_1 > 0 ? 0 : 1;
$grep_result_1 = q{})) {
        $DEVICE_TYPE = "a13";
}
    else {
        $DEVICE_TYPE = "a20";
    }
}
my $BOOTLOADER;
my @BOOTLOADER;
my %BOOTLOADER;
$BOOTLOADER = ${CWD} . "/" . ${DEVICE_TYPE} . "/bootloader";
if ($LINUXFAMILY =~ /^rk3328$/msx or $LINUXFAMILY =~ /^rk3399$/msx or $LINUXFAMILY =~ /^rockchip64$/msx) {
        my $FIRSTSECTOR;
    my @FIRSTSECTOR;
    my %FIRSTSECTOR;
    $FIRSTSECTOR = '32768';
} elsif (1) {
        $FIRSTSECTOR = '8192';
}
my $root_uuid;
my @root_uuid;
my %root_uuid;
$root_uuid = do { my @_qx_cmd = ("sed -e 's/^.*root=//' -e 's/ .*$//' < /proc/cmdline"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
my $root_partition;
my @root_partition;
my %root_partition;
$root_partition = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_2 = q{};
    my $output_printed_2;
    my $pipeline_success_2 = 1;

    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'blkid', );
    close $in_3 or croak 'Close failed: $OS_ERROR';
    $output_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_2 = 0; }
    my $set1_4 = "\":";
    my $input_4 = $output_2;
    my $tr_result_2_1 = q{};
    for my $char ( split //msx, $input_4 ) {
        if ( (index $set1_4, $char) == -1 ) {
            $tr_result_2_1 .= $char;
        }
    }
        if (!($tr_result_2_1 =~ m{\n\z}msx || $tr_result_2_1 eq q{})) {
            $tr_result_2_1 .= "\n";
        }
        $output_2 = $tr_result_2_1;
    my $grep_result_2_2;
    my @grep_lines_2_2 = split /\n/msx, $output_2;
    my @grep_filtered_2_2 = grep { /${root_uuid}/msx } @grep_lines_2_2;
    $grep_result_2_2 = join "\n", @grep_filtered_2_2;
        if (!($grep_result_2_2 =~ m{\n\z}msx || $grep_result_2_2 eq q{})) {
            $grep_result_2_2 .= "\n";
        }
    $CHILD_ERROR = scalar @grep_filtered_2_2 > 0 ? 0 : 1;
    $output_2 = $grep_result_2_2;
    my @lines = split /\n/msx, $output_2;
    my @result;
    foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /^\s*$/msx) { next; }
        my @fields = split /\s+/msx, $line;
        push @result, ($fields[0] . "\n");
    }
    $output_2 = join "", @result;

    if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
    $output_2 =~ s/\n+\z//msx;
    $output_2;
}; $_pipeline_result; };
my $root_partition_device;
my @root_partition_device;
my %root_partition_device;
$root_partition_device = (defined (defined ($ENV{root_partition:} // q{}) && ($ENV{root_partition:} // q{}) ne q{} ? ($ENV{root_partition:} // q{}) : '2') && (defined ($ENV{root_partition:} // q{}) && ($ENV{root_partition:} // q{}) ne q{} ? ($ENV{root_partition:} // q{}) : '2') ne q{} ? (defined ($ENV{root_partition:} // q{}) && ($ENV{root_partition:} // q{}) ne q{} ? ($ENV{root_partition:} // q{}) : '2') : '2');
if (( -b /dev/nand)) {
        my $nandcheck;
    my @nandcheck;
    my %nandcheck;
    $nandcheck = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_5 = q{};
        my $output_printed_5;
        my $pipeline_success_5 = 1;
        $output_5 = do {
        my @ls_files_6 = ();
        my $ls_all_found_7 = 1;
        my @ls_inputs_8 = ();
        my @ls_glob_ls_inputs_8_0 = glob('/dev/nand*');
        if ( !@ls_glob_ls_inputs_8_0 ) {
        push @ls_inputs_8, '/dev/nand*';
        $ls_all_found_7 = 0;
        } else {
        push @ls_inputs_8, @ls_glob_ls_inputs_8_0;
        }
        my @ls_files_9 = ();
        my @ls_dirs_10 = ();
        my $ls_show_headers_11 = scalar(@ls_inputs_8) > 1;
        for my $ls_item_12 (@ls_inputs_8) {
        if ( -f $ls_item_12 ) {
        push @ls_files_9, $ls_item_12;
        }
        elsif ( -d $ls_item_12 ) {
        push @ls_dirs_10, $ls_item_12;
        }
        else {
        $ls_all_found_7 = 0;
        }
        }
        @ls_files_9 = sort { $a cmp $b } @ls_files_9;
        @ls_dirs_10 = sort { $a cmp $b } @ls_dirs_10;
        if (@ls_files_9) {
        push @ls_files_6, join("\n", @ls_files_9);
        }
        for my $ls_dir_13 (@ls_dirs_10) {
        my @ls_dir_entries_14 = ();
        if ( opendir my $dh, $ls_dir_13 ) {
        while ( my $file = readdir $dh ) {
        next if $file eq q{.} || $file eq q{..} || $file =~ /^[.]/msx;
        push @ls_dir_entries_14, $file;
        }
        closedir $dh;
        @ls_dir_entries_14 = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, do { (my $s = $_) =~ s{/$}{}msx; $s } ] } @ls_dir_entries_14;
        if ( $ls_show_headers_11 ) {
        if ( @ls_dir_entries_14 ) {
        push @ls_files_6, $ls_dir_13 . ":\n" . join("\n", @ls_dir_entries_14);
        } else {
        push @ls_files_6, $ls_dir_13 . ':';
        }
        }
        elsif ( @ls_dir_entries_14 ) {
        push @ls_files_6, join("\n", @ls_dir_entries_14);
        }
        }
        else {
        $ls_all_found_7 = 0;
        }
        }
        (@ls_files_6 ? join("\n\n", @ls_files_6) . "\n" : q{});
        };
        ;
        my $grep_result_5_1;
        my @grep_lines_5_1 = split /\n/msx, $output_5;
        my @grep_filtered_5_1 = grep { /nand/msx } @grep_lines_5_1;
        $grep_result_5_1 = join "\n", @grep_filtered_5_1;
        if (!($grep_result_5_1 =~ m{\n\z}msx || $grep_result_5_1 eq q{})) {
        $grep_result_5_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_5_1 > 0 ? 0 : 1;
        $output_5 = $grep_result_5_1;
        if ((scalar @grep_filtered_5_1) == 0) {
            $pipeline_success_5 = 0;
        }
        my @lines = split /\n/msx, $output_5;
        my @result;
        foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /^\s*$/msx) { next; }
        my @fields = split /\s+/msx, $line;
        push @result, ($scalar(@fields) . "\n");
        }
        $output_5 = join "", @result;
        if ( !$pipeline_success_5 ) { $main_exit_code = 1; }
                $output_5 =~ s/\n+\z//msx;
        $output_5;
}; $_pipeline_result; };
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
my $emmccheck;
my @emmccheck;
my %emmccheck;
$emmccheck = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_15 = q{};
    my $output_printed_15;
    my $pipeline_success_15 = 1;
    $output_15 = do {
    my @ls_files_16 = ();
    my $ls_all_found_17 = 1;
    my @ls_inputs_18 = ();
    my @ls_glob_ls_inputs_18_0 = glob('/dev/mmcblk*');
    if ( !@ls_glob_ls_inputs_18_0 ) {
    push @ls_inputs_18, '/dev/mmcblk*';
    $ls_all_found_17 = 0;
    } else {
    push @ls_inputs_18, @ls_glob_ls_inputs_18_0;
    }
    my @ls_files_19 = ();
    my @ls_dirs_20 = ();
    my $ls_show_headers_21 = scalar(@ls_inputs_18) > 1;
    for my $ls_item_22 (@ls_inputs_18) {
    if ( -f $ls_item_22 ) {
    push @ls_files_19, $ls_item_22;
    }
    elsif ( -d $ls_item_22 ) {
    push @ls_dirs_20, $ls_item_22;
    }
    else {
    $ls_all_found_17 = 0;
    }
    }
    @ls_files_19 = sort { $a cmp $b } @ls_files_19;
    @ls_dirs_20 = sort { $a cmp $b } @ls_dirs_20;
    if (@ls_files_19) {
    push @ls_files_16, join("\n", @ls_files_19);
    }
    for my $ls_dir_23 (@ls_dirs_20) {
    my @ls_dir_entries_24 = ();
    if ( opendir my $dh, $ls_dir_23 ) {
    while ( my $file = readdir $dh ) {
    next if $file eq q{.} || $file eq q{..} || $file =~ /^[.]/msx;
    push @ls_dir_entries_24, $file;
    }
    closedir $dh;
    @ls_dir_entries_24 = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, do { (my $s = $_) =~ s{/$}{}msx; $s } ] } @ls_dir_entries_24;
    if ( $ls_show_headers_21 ) {
    if ( @ls_dir_entries_24 ) {
    push @ls_files_16, $ls_dir_23 . ":\n" . join("\n", @ls_dir_entries_24);
    } else {
    push @ls_files_16, $ls_dir_23 . ':';
    }
    }
    elsif ( @ls_dir_entries_24 ) {
    push @ls_files_16, join("\n", @ls_dir_entries_24);
    }
    }
    else {
    $ls_all_found_17 = 0;
    }
    }
    (@ls_files_16 ? join("\n\n", @ls_files_16) . "\n" : q{});
    };
    ;
    my $grep_result_15_1;
    my @grep_lines_15_1 = split /\n/msx, $output_15;
    my @grep_filtered_15_1 = grep { /mmcblk[0-9]/msx } @grep_lines_15_1;
    $grep_result_15_1 = join "\n", @grep_filtered_15_1;
    if (!($grep_result_15_1 =~ m{\n\z}msx || $grep_result_15_1 eq q{})) {
    $grep_result_15_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_15_1 > 0 ? 0 : 1;
    $output_15 = $grep_result_15_1;
    if ((scalar @grep_filtered_15_1) == 0) {
        $pipeline_success_15 = 0;
    }
    my $grep_result_15_2;
    my @grep_lines_15_2 = split /\n/msx, $output_15;
    my @grep_filtered_15_2 = grep { !/$root_partition_device/msx } @grep_lines_15_2;
    $grep_result_15_2 = join "\n", @grep_filtered_15_2;
    if (!($grep_result_15_2 =~ m{\n\z}msx || $grep_result_15_2 eq q{})) {
    $grep_result_15_2 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_15_2 > 0 ? 0 : 1;
    $output_15 = $grep_result_15_2;
    $output_15 = $grep_result_15_2;
    if ((scalar @grep_filtered_15_2) == 0) {
        $pipeline_success_15 = 0;
    }
    if ( !$pipeline_success_15 ) { $main_exit_code = 1; }
        $output_15 =~ s/\n+\z//msx;
    $output_15;
}; $_pipeline_result; };
my $diskcheck;
my @diskcheck;
my %diskcheck;
$diskcheck = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_25 = q{};
    my $output_printed_25;
    my $pipeline_success_25 = 1;

    my ($in_26, $out_26);
    my $pid_26 = open3($in_26, $out_26, '>&STDERR', 'lsblk', '-l');
    close $in_26 or croak 'Close failed: $OS_ERROR';
    $output_25 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_26> };
    close $out_26 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_26, 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_25 = 0; }
    my @lines = split /\n/msx, $output_25;
    my @result;
    foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /^\s*$/msx) { next; }
        my @fields = split /\ /msx, $line;
        if (!(/ disk /)) { next; }
        push @result, ($fields[0] . "\n");
    }
    $output_25 = join "", @result;

    my $grep_result_25_2;
    my @grep_lines_25_2 = split /\n/msx, $output_25;
    my @grep_filtered_25_2 = grep { /^sd|^nvme/msx } @grep_lines_25_2;
    $grep_result_25_2 = join "\n", @grep_filtered_25_2;
        if (!($grep_result_25_2 =~ m{\n\z}msx || $grep_result_25_2 eq q{})) {
            $grep_result_25_2 .= "\n";
        }
    $CHILD_ERROR = scalar @grep_filtered_25_2 > 0 ? 0 : 1;
    $output_25 = $grep_result_25_2;
    if ((scalar @grep_filtered_25_2) == 0) {
        $pipeline_success_25 = 0;
    }
    if ( !$pipeline_success_25 ) { $main_exit_code = 1; }
    $output_25 =~ s/\n+\z//msx;
    $output_25;
}; $_pipeline_result; };
my $spicheck;
my @spicheck;
my %spicheck;
$spicheck = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_27 = q{};
    my $output_printed_27;
    my $pipeline_success_27 = 1;
    my $grep_result_27_0;
    my @grep_lines_27_0 = ();
    my @grep_filenames_27_0 = ();
    if (-e "/proc/partitions") {
        open my $fh, '<', "/proc/partitions" or croak "Cannot open file: $ERRNO";
        while (my $line = <$fh>) {
            chomp $line;
            push @grep_lines_27_0, $line;
            push @grep_filenames_27_0, "/proc/partitions";
        }
        close $fh
            or croak "Close failed: $OS_ERROR";
    }
    else { print {*STDERR} "grep: /proc/partitions: No such file or directory\n"; }
    my @grep_filtered_27_0 = grep { /mtd/msx } @grep_lines_27_0;
    $grep_result_27_0 = join "\n", @grep_filtered_27_0;
        if (!($grep_result_27_0 =~ m{\n\z}msx || $grep_result_27_0 eq q{})) {
            $grep_result_27_0 .= "\n";
        }
    $CHILD_ERROR = scalar @grep_filtered_27_0 > 0 ? 0 : 1;
    $output_27 = $grep_result_27_0;
    if ($CHILD_ERROR != 0) { $pipeline_success_27 = 0; }
    my @lines = split /\n/msx, $output_27;
    my @result;
    foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /^\s*$/msx) { next; }
        my @fields = split /\s+/msx, $line;
        push @result, ($scalar(@fields) . "\n");
    }
    $output_27 = join "", @result;

    if ( !$pipeline_success_27 ) { $main_exit_code = 1; }
    $output_27 =~ s/\n+\z//msx;
    $output_27;
}; $_pipeline_result; };
my %mkopts = ();
my %mountopts = ();
if (($LINUXFAMILY =~ /sun50iw6|sun50iw2|sun50iw1/msx && $BRANCH =~ /^legacy$/msx)) {
    $mkopts{"ext2"} = '-O ^64bit -qF';
    $mkopts{"ext3"} = '-O ^64bit -qF';
    $mkopts{"ext4"} = '-O ^64bit -qF';
}
else {
    $mkopts{"ext2"} = '-qF';
    $mkopts{"ext3"} = '-qF';
    $mkopts{"ext4"} = '-qF';
}
$mkopts{"btrfs"} = '-f';
$mkopts{"f2fs"} = '-f';
$mountopts{"ext2"} = "defaults,noatime,commit=600,errors=remount-ro,x-gvfs-hide\t0\t1";
$mountopts{"ext3"} = "defaults,noatime,commit=600,errors=remount-ro,x-gvfs-hide\t0\t1";
$mountopts{"ext4"} = "defaults,noatime,commit=600,errors=remount-ro,x-gvfs-hide\t0\t1";
$mountopts{"btrfs"} = "defaults,noatime,commit=600,compress=lzo,x-gvfs-hide\t\t\t0\t2";
$mountopts{"f2fs"} = "defaults,noatime,x-gvfs-hide\t0\t2";

sub create_orangepi {
    my ($file) = @_;
    my $TempDir;
    my @TempDir;
    my %TempDir;
    $TempDir = do {
    my $command = q(mktemp -d /mnt/ ${${0##*/}} .XXXXXX || : 'Complex command not supported in bash string generation');
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
$main_exit_code = system('bash', 'sync') >> 8;
        $CHILD_ERROR == 0
    }) {
                use File::Path qw(make_path);
        my $err;
        if ( !-d ${TempDir} ) {
            make_path( ${TempDir}, { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . ${TempDir} . ": $err->[0]\n";
            }
        }
        if ( !-d '/bootfs' ) {
            make_path( '/bootfs', { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . '/bootfs' . ": $err->[0]\n";
            }
        }
        if ( !-d ${TempDir} ) {
            make_path( ${TempDir}, { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . ${TempDir} . ": $err->[0]\n";
            }
        }
        if ( !-d '/rootfs' ) {
            make_path( '/rootfs', { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . '/rootfs' . ": $err->[0]\n";
            }
        }
    }
if ($ENV{eMMCFilesystemChoosen} =~ /^(btrfs|f2fs)$/msx) {
        if ($1 ne q{}) {
                        $main_exit_code = system('mount', (defined ($ENV{1:} // q{}) && ($ENV{1:} // q{}) ne q{} ? ($ENV{1:} // q{}) : '1'), "1", ${TempDir}, '/bootfs') >> 8;
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ($2 ne q{}) {
                        do {
                local %ENV = %ENV;
                my $spicheck = $spicheck;
                my $DEVICE_TYPE = $DEVICE_TYPE;
                my $FIRSTSECTOR = $FIRSTSECTOR;
                my $CWD = $CWD;
                my $root_partition = $root_partition;
                my %mkopts = %mkopts;
                my %mountopts = %mountopts;
                my $emmccheck = $emmccheck;
                my $TempDir = $TempDir;
                my $title = $title;
                my $diskcheck = $diskcheck;
                my $EX_LIST = $EX_LIST;
                my $root_partition_device = $root_partition_device;
                my $backtitle = $backtitle;
                my $err = $err;
                my $root_uuid = $root_uuid;
                my $BOOTLOADER = $BOOTLOADER;
                my $logfile = $logfile;
                my $nandcheck = $nandcheck;
                                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                    $main_exit_code = system('mount', '-o', 'compress-force', q{=}, 'zlib', "$_[1]", ${TempDir}, '/rootfs') >> 8;
                };
                if ($CHILD_ERROR != 0) {
                                        $main_exit_code = system('mount', "$_[1]", ${TempDir}, '/rootfs') >> 8;
                }
                q{};
            };
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
}
    else {
        if ($2 ne q{}) {
                        do {
                local %ENV = %ENV;
                my $spicheck = $spicheck;
                my $DEVICE_TYPE = $DEVICE_TYPE;
                my $FIRSTSECTOR = $FIRSTSECTOR;
                my $CWD = $CWD;
                my $root_partition = $root_partition;
                my %mkopts = %mkopts;
                my %mountopts = %mountopts;
                my $emmccheck = $emmccheck;
                my $TempDir = $TempDir;
                my $title = $title;
                my $diskcheck = $diskcheck;
                my $EX_LIST = $EX_LIST;
                my $root_partition_device = $root_partition_device;
                my $backtitle = $backtitle;
                my $err = $err;
                my $root_uuid = $root_uuid;
                my $BOOTLOADER = $BOOTLOADER;
                my $logfile = $logfile;
                my $nandcheck = $nandcheck;
                                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                    $main_exit_code = system('mount', '-o', 'compress-force', q{=}, 'zlib', "$_[1]", ${TempDir}, '/rootfs') >> 8;
                };
                if ($CHILD_ERROR != 0) {
                                        $main_exit_code = system('mount', "$_[1]", ${TempDir}, '/rootfs') >> 8;
                }
                q{};
            };
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if (($1 ne q{} && $1 ne "spi")) {
                        $main_exit_code = system('mount', "$_[0]", ${TempDir}, '/bootfs') >> 8;
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
    }
if ( -e "${TempDir}" ) {
        if ( -d "${TempDir}" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("${TempDir}", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", ${TempDir}, ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "${TempDir}" ) {
                            }
            else {
                carp "rm: carping: could not remove ", ${TempDir},
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
my @files_to_remove = glob("/bootfs/*");
foreach my $file_to_remove (@files_to_remove) {
        if ( -e $file_to_remove ) {
            if ( -d $file_to_remove ) {
                my $err;
                require File::Path;
                File::Path::remove_tree($file_to_remove, {error => \$err});
                if (@{$err}) {
                    carp "rm: carping: could not remove ", $file_to_remove, ": $err->[0]\n";
                }
                else {
                }
            }
            else {
            if ( unlink $file_to_remove ) {
            local $CHILD_ERROR = 0;
            }
            else {
                local $CHILD_ERROR = 1;
                carp "rm: carping: could not remove ", $file_to_remove,
    ": $OS_ERROR\n";
            }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
if ( -e "${TempDir}" ) {
        if ( -d "${TempDir}" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("${TempDir}", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", ${TempDir}, ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "${TempDir}" ) {
                            }
            else {
                carp "rm: carping: could not remove ", ${TempDir},
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
my @files_to_remove = glob("/rootfs/*");
foreach my $file_to_remove (@files_to_remove) {
        if ( -e $file_to_remove ) {
            if ( -d $file_to_remove ) {
                my $err;
                require File::Path;
                File::Path::remove_tree($file_to_remove, {error => \$err});
                if (@{$err}) {
                    carp "rm: carping: could not remove ", $file_to_remove, ": $err->[0]\n";
                }
                else {
                }
            }
            else {
            if ( unlink $file_to_remove ) {
            local $CHILD_ERROR = 0;
            }
            else {
                local $CHILD_ERROR = 1;
                carp "rm: carping: could not remove ", $file_to_remove,
    ": $OS_ERROR\n";
            }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
    my $satauuid;
    my @satauuid;
    my %satauuid;
    $satauuid = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_29 = q{};
        my $output_printed_29;
        my $pipeline_success_29 = 1;

        my ($in_30, $out_30);
        my $pid_30 = open3($in_30, $out_30, '>&STDERR', 'blkid', '-o', 'export');
        close $in_30 or croak 'Close failed: $OS_ERROR';
        $output_29 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_30> };
        close $out_30 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_30, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_29 = 0; }
        my $grep_result_29_1;
        my @grep_lines_29_1 = split /\n/msx, $output_29;
        my @grep_filtered_29_1 = grep { /UUID/msx } @grep_lines_29_1;
        $grep_result_29_1 = join "\n", @grep_filtered_29_1;
                if (!($grep_result_29_1 =~ m{\n\z}msx || $grep_result_29_1 eq q{})) {
                    $grep_result_29_1 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_29_1 > 0 ? 0 : 1;
        $output_29 = $grep_result_29_1;
        if ((scalar @grep_filtered_29_1) == 0) {
            $pipeline_success_29 = 0;
        }
        if ( !$pipeline_success_29 ) { $main_exit_code = 1; }
        $output_29 =~ s/\n+\z//msx;
        $output_29;
}; $_pipeline_result; };
    my $sduuid;
    my @sduuid;
    my %sduuid;
    $sduuid = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_31 = q{};
        my $output_printed_31;
        my $pipeline_success_31 = 1;

        my ($in_32, $out_32);
        my $pid_32 = open3($in_32, $out_32, '>&STDERR', 'blkid', '-o', 'export', '/dev/mmcblk*p1');
        close $in_32 or croak 'Close failed: $OS_ERROR';
        $output_31 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_32> };
        close $out_32 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_32, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_31 = 0; }
        my $grep_result_31_1;
        my @grep_lines_31_1 = split /\n/msx, $output_31;
        my @grep_filtered_31_1 = grep { /UUID/msx } @grep_lines_31_1;
        $grep_result_31_1 = join "\n", @grep_filtered_31_1;
                if (!($grep_result_31_1 =~ m{\n\z}msx || $grep_result_31_1 eq q{})) {
                    $grep_result_31_1 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_31_1 > 0 ? 0 : 1;
        $output_31 = $grep_result_31_1;
        my $grep_result_31_2;
        my @grep_lines_31_2 = split /\n/msx, $output_31;
        my @grep_filtered_31_2 = grep { !/$root_partition_device/msx } @grep_lines_31_2;
        $grep_result_31_2 = join "\n", @grep_filtered_31_2;
                if (!($grep_result_31_2 =~ m{\n\z}msx || $grep_result_31_2 eq q{})) {
                    $grep_result_31_2 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_31_2 > 0 ? 0 : 1;
        $output_31 = $grep_result_31_2;
        if ((scalar @grep_filtered_31_2) == 0) {
            $pipeline_success_31 = 0;
        }
        if ( !$pipeline_success_31 ) { $main_exit_code = 1; }
        $output_31 =~ s/\n+\z//msx;
        $output_31;
}; $_pipeline_result; };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "\nOld UUID:  ${root_uuid}";
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
        open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "SD UUID:   $sduuid";
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
        open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "SATA UUID: $satauuid";
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
        open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "eMMC UUID: $ENV{emmcuuid} $ENV{eMMCFile" . "sys" . "tem" . "Choosen}";
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
        open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "Boot: $1 $_[0] $ENV{eMMCFile" . "sys" . "tem" . "Choosen}";
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
        open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "Root: $2 $_[1] $ENV{File" . "sys" . "tem" . "Choosen}";
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
    my $USAGE;
    my @USAGE;
    my %USAGE;
    $USAGE = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_33 = q{};
        my $output_printed_33;
        my $pipeline_success_33 = 1;

        my ($in_34, $out_34);
        my $pid_34 = open3($in_34, $out_34, '>&STDERR', 'df', '-BM');
        close $in_34 or croak 'Close failed: $OS_ERROR';
        $output_33 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_34> };
        close $out_34 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_34, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_33 = 0; }
        my $grep_result_33_1;
        my @grep_lines_33_1 = split /\n/msx, $output_33;
        my @grep_filtered_33_1 = grep { /^\/dev/msx } @grep_lines_33_1;
        $grep_result_33_1 = join "\n", @grep_filtered_33_1;
                if (!($grep_result_33_1 =~ m{\n\z}msx || $grep_result_33_1 eq q{})) {
                    $grep_result_33_1 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_33_1 > 0 ? 0 : 1;
        $output_33 = $grep_result_33_1;
        my $num_lines       = 1;
        my $head_line_count = 0;
        my $result          = q{};
        my $input           = $output_33;
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
        $output_33 = $result;

        my @lines = split /\n/msx, $output_33;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\s+/msx, $line;
            push @result, ($fields[2] . "\n");
        }
        $output_33 = join "", @result;

        my $set1_35 = '-c';
        my $set2_35 = q{d};
        my $input_35 = $output_33;
        # Expand character ranges for tr command
        my $expanded_set1_35 = $set1_35;
        my $expanded_set2_35 = $set2_35;
        # Handle a-z range in set1
        if ($expanded_set1_35 =~ /a-z/msx) {
            $expanded_set1_35 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set1
        if ($expanded_set1_35 =~ /A-Z/msx) {
            $expanded_set1_35 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set1
        if ($expanded_set1_35 =~ /\[:upper:\]/msx) {
            $expanded_set1_35 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set1
        if ($expanded_set1_35 =~ /\[:lower:\]/msx) {
            $expanded_set1_35 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle a-z range in set2
        if ($expanded_set2_35 =~ /a-z/msx) {
            $expanded_set2_35 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set2
        if ($expanded_set2_35 =~ /A-Z/msx) {
            $expanded_set2_35 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set2
        if ($expanded_set2_35 =~ /\[:upper:\]/msx) {
            $expanded_set2_35 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set2
        if ($expanded_set2_35 =~ /\[:lower:\]/msx) {
            $expanded_set2_35 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        my $tr_result_33_4 = q{};
        for my $char ( split //msx, $input_35 ) {
            my $pos_35 = index $expanded_set1_35, $char;
            if ( $pos_35 >= 0 && $pos_35 < length $expanded_set2_35 ) {
                $tr_result_33_4 .= substr $expanded_set2_35, $pos_35, 1;
            } else {
                $tr_result_33_4 .= $char;
            }
        }
                if (!($tr_result_33_4 =~ m{\n\z}msx || $tr_result_33_4 eq q{})) {
                    $tr_result_33_4 .= "\n";
                }
                $output_33 = $tr_result_33_4;
        if ( !$pipeline_success_33 ) { $main_exit_code = 1; }
        $output_33 =~ s/\n+\z//msx;
        $output_33;
}; $_pipeline_result; };
    my $DEST;
    my @DEST;
    my %DEST;
    $DEST = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_36 = q{};
        my $output_printed_36;
        my $pipeline_success_36 = 1;

        my ($in_37, $out_37);
        my $pid_37 = open3($in_37, $out_37, '>&STDERR', 'df', '-BM');
        close $in_37 or croak 'Close failed: $OS_ERROR';
        $output_36 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_37> };
        close $out_37 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_37, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_36 = 0; }
        my $grep_result_36_1;
        my @grep_lines_36_1 = split /\n/msx, $output_36;
        my @grep_filtered_36_1 = grep { /^\/dev/msx } @grep_lines_36_1;
        $grep_result_36_1 = join "\n", @grep_filtered_36_1;
                if (!($grep_result_36_1 =~ m{\n\z}msx || $grep_result_36_1 eq q{})) {
                    $grep_result_36_1 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_36_1 > 0 ? 0 : 1;
        $output_36 = $grep_result_36_1;
        my $grep_result_36_2;
        my @grep_lines_36_2 = ();
        my @grep_filenames_36_2 = ();
        if (-e "/rootfs") {
            open my $fh, '<', "/rootfs" or croak "Cannot open file: $ERRNO";
            while (my $line = <$fh>) {
                chomp $line;
                push @grep_lines_36_2, $line;
                push @grep_filenames_36_2, "/rootfs";
            }
            close $fh
                or croak "Close failed: $OS_ERROR";
        }
        else { print {*STDERR} "grep: /rootfs: No such file or directory\n"; }
        my @grep_filtered_36_2 = grep { /${TempDir}/msx } @grep_lines_36_2;
        $grep_result_36_2 = join "\n", @grep_filtered_36_2;
                if (!($grep_result_36_2 =~ m{\n\z}msx || $grep_result_36_2 eq q{})) {
                    $grep_result_36_2 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_36_2 > 0 ? 0 : 1;
        $output_36 = $grep_result_36_2;
        my @lines = split /\n/msx, $output_36;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\s+/msx, $line;
            push @result, ($fields[3] . "\n");
        }
        $output_36 = join "", @result;

        my $set1_38 = '-c';
        my $set2_38 = q{d};
        my $input_38 = $output_36;
        # Expand character ranges for tr command
        my $expanded_set1_38 = $set1_38;
        my $expanded_set2_38 = $set2_38;
        # Handle a-z range in set1
        if ($expanded_set1_38 =~ /a-z/msx) {
            $expanded_set1_38 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set1
        if ($expanded_set1_38 =~ /A-Z/msx) {
            $expanded_set1_38 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set1
        if ($expanded_set1_38 =~ /\[:upper:\]/msx) {
            $expanded_set1_38 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set1
        if ($expanded_set1_38 =~ /\[:lower:\]/msx) {
            $expanded_set1_38 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle a-z range in set2
        if ($expanded_set2_38 =~ /a-z/msx) {
            $expanded_set2_38 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set2
        if ($expanded_set2_38 =~ /A-Z/msx) {
            $expanded_set2_38 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set2
        if ($expanded_set2_38 =~ /\[:upper:\]/msx) {
            $expanded_set2_38 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set2
        if ($expanded_set2_38 =~ /\[:lower:\]/msx) {
            $expanded_set2_38 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        my $tr_result_36_4 = q{};
        for my $char ( split //msx, $input_38 ) {
            my $pos_38 = index $expanded_set1_38, $char;
            if ( $pos_38 >= 0 && $pos_38 < length $expanded_set2_38 ) {
                $tr_result_36_4 .= substr $expanded_set2_38, $pos_38, 1;
            } else {
                $tr_result_36_4 .= $char;
            }
        }
                if (!($tr_result_36_4 =~ m{\n\z}msx || $tr_result_36_4 eq q{})) {
                    $tr_result_36_4 .= "\n";
                }
                $output_36 = $tr_result_36_4;
        if ( !$pipeline_success_36 ) { $main_exit_code = 1; }
        $output_36 =~ s/\n+\z//msx;
        $output_36;
}; $_pipeline_result; };
if (($USAGE > $DEST)) {
        $main_exit_code = system('dialog', '--title', "$title", '--backtitle', "$backtitle", '--colors', '--infobox', "\n\Z1Partition too small.\Zn Needed: $USAGE MB Avaliable: $DEST MB", q{5}, '60') >> 8;
        $main_exit_code = system('umount_device', "$_[0]") >> 8;
        $main_exit_code = system('umount_device', "$_[1]") >> 8;
exit 3;
    }
if ($1 =~ /^.*nand.*$/msx) {
        $main_exit_code = system('rsync', '-aqc', $BOOTLOADER, '/*', ${TempDir}, '/bootfs') >> 8;
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "Usage: $USAGE";
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
        open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "Dest: $DEST\n\n/etc/fstab:";
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
        open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
print do { my $cat_chunk = q{}; if ( open my $fh, '<', '/etc/fstab' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/etc/fstab' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
        print "\n/etc/mtab:" . "\n";
        $CHILD_ERROR = 0;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    # Original bash: grep '^/dev/' /etc/mtab | grep -E -v "log2ram|folder2ram" | sort >> $logfile
{
        my $output_40 = q{};
        my $output_printed_40;
        my $pipeline_success_40 = 1;
                my $grep_result_40_0;
        my @grep_lines_40_0 = ();
        my @grep_filenames_40_0 = ();
        if (-e "/etc/mtab") {
        open my $fh, '<', "/etc/mtab" or croak "Cannot open file: $ERRNO";
        while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_40_0, $line;
        push @grep_filenames_40_0, "/etc/mtab";
        }
        close $fh
        or croak "Close failed: $OS_ERROR";
        }
        else { print {*STDERR} "grep: /etc/mtab: No such file or directory\n"; }
        my @grep_filtered_40_0 = grep { /^\/dev\//msx } @grep_lines_40_0;
        $grep_result_40_0 = join "\n", @grep_filtered_40_0;
        if (!($grep_result_40_0 =~ m{\n\z}msx || $grep_result_40_0 eq q{})) {
        $grep_result_40_0 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_40_0 > 0 ? 0 : 1;
        $output_40 = $grep_result_40_0;
        $output_40 = $grep_result_40_0;

                my $grep_result_40_1;
        my @grep_lines_40_1 = split /\n/msx, $output_40;
        my @grep_filtered_40_1 = grep { !/log2ram|folder2ram/msx } @grep_lines_40_1;
        $grep_result_40_1 = join "\n", @grep_filtered_40_1;
        if (!($grep_result_40_1 =~ m{\n\z}msx || $grep_result_40_1 eq q{})) {
        $grep_result_40_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_40_1 > 0 ? 0 : 1;
        $output_40 = $grep_result_40_1;
        $output_40 = $grep_result_40_1;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $logfile
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_41 = q{};
        my @sort_lines_42 = split /\n/msx, $output_40;
        my @sort_sorted_42 = sort @sort_lines_42;
        $tmp_redirect_41 = join "\n", @sort_sorted_42;
        if ($tmp_redirect_41 ne q{} && !($tmp_redirect_41 =~ m{\n\z}msx)) {
        $tmp_redirect_41 .= "\n";
        }
        $output_40 = $tmp_redirect_41;
        $tmp_redirect_41;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_40; }
        $output_printed_40 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_40 ) { $main_exit_code = 1; }
        }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
        print "\nFiles currently open for writing:" . "\n";
        $CHILD_ERROR = 0;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    # Original bash: lsof / | awk 'NR==1 || $4~/[0-9][uw]/' | grep -v "^COMMAND" >> $logfile
{
        my $output_43 = q{};
        my $output_printed_43;
        my $pipeline_success_43 = 1;
                my ($in_44, $out_44);
        my $pid_44 = open3($in_44, $out_44, '>&STDERR', 'lsof', q{/});
        close $in_44 or croak 'Close failed: $OS_ERROR';
        $output_43 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_44> };
        close $out_44 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_44, 0;

                my @lines = split /\n/msx, $output_43;
        my @result;
        foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /^\s*$/msx) { next; }
        my @fields = split /\s+/msx, $line;
        push @result, ($line . "\n");
        }
        $output_43 = join "", @result;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $logfile
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_45 = q{};
        my $grep_result_46;
        my @grep_lines_46 = split /\n/msx, $output_43;
        my @grep_filtered_46 = grep { !/^COMMAND/msx } @grep_lines_46;
        $grep_result_46 = join "\n", @grep_filtered_46;
        if (!($grep_result_46 =~ m{\n\z}msx || $grep_result_46 eq q{})) {
        $grep_result_46 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_46 > 0 ? 0 : 1;
        $tmp_redirect_45 = $grep_result_46;
        $tmp_redirect_45;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_43; }
        $output_printed_43 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_43 ) { $main_exit_code = 1; }
        }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
        print "\nTrying to stop running services to minimize open files:\\c" . "\n";
        $CHILD_ERROR = 0;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('stop_running_services', "nfs-|smbd|nmbd|winbind|ftpd|netatalk|monit|cron|webmin|rrdcached") >> 8;
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
        open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('stop_running_services', "fail2ban|ramlog|folder2ram|postgres|mariadb|mysql|postfix|mail|nginx|apache|snmpd") >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
        $main_exit_code = system('pkill', 'dhclient') >> 8;
    };
        my $LANG = q{C};
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
            print "\n\nChecking again for open files:" . "\n";
            $CHILD_ERROR = 0;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    # Original bash: lsof / | awk 'NR==1 || $4~/[0-9][uw]/' | grep -v "^COMMAND" >> $logfile
{
        my $output_47 = q{};
        my $output_printed_47;
        my $pipeline_success_47 = 1;
                my ($in_48, $out_48);
        my $pid_48 = open3($in_48, $out_48, '>&STDERR', 'lsof', q{/});
        close $in_48 or croak 'Close failed: $OS_ERROR';
        $output_47 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_48> };
        close $out_48 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_48, 0;

                my @lines = split /\n/msx, $output_47;
        my @result;
        foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /^\s*$/msx) { next; }
        my @fields = split /\s+/msx, $line;
        push @result, ($line . "\n");
        }
        $output_47 = join "", @result;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $logfile
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_49 = q{};
        my $grep_result_50;
        my @grep_lines_50 = split /\n/msx, $output_47;
        my @grep_filtered_50 = grep { !/^COMMAND/msx } @grep_lines_50;
        $grep_result_50 = join "\n", @grep_filtered_50;
        if (!($grep_result_50 =~ m{\n\z}msx || $grep_result_50 eq q{})) {
        $grep_result_50 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_50 > 0 ? 0 : 1;
        $tmp_redirect_49 = $grep_result_50;
        $tmp_redirect_49;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_47; }
        $output_printed_47 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_47 ) { $main_exit_code = 1; }
        }
    my $TODO;
    my @TODO;
    my %TODO;
    $TODO = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_51 = q{};
        my $output_printed_51;
        my $pipeline_success_51 = 1;

        my ($in_52, $out_52);
        my $pid_52 = open3($in_52, $out_52, '>&STDERR', 'rsync', '-ahvrltDn', '--delete', '--stats', '--exclude-from=', q{/}, '/rootfs');
        close $in_52 or croak 'Close failed: $OS_ERROR';
        $output_51 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_52> };
        close $out_52 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_52, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_51 = 0; }
        my $grep_result_51_1;
        my @grep_lines_51_1 = split /\n/msx, $output_51;
        my @grep_filtered_51_1 = grep { /Number\ of\ files:/msx } @grep_lines_51_1;
        $grep_result_51_1 = join "\n", @grep_filtered_51_1;
                if (!($grep_result_51_1 =~ m{\n\z}msx || $grep_result_51_1 eq q{})) {
                    $grep_result_51_1 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_51_1 > 0 ? 0 : 1;
        $output_51 = $grep_result_51_1;
        my @lines = split /\n/msx, $output_51;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\s+/msx, $line;
            push @result, ($fields[3] . "\n");
        }
        $output_51 = join "", @result;

        my $set1_53 = '.,';
        my $input_53 = $output_51;
        my $tr_result_51_3 = q{};
        for my $char ( split //msx, $input_53 ) {
            if ( (index $set1_53, $char) == -1 ) {
                $tr_result_51_3 .= $char;
            }
        }
                if (!($tr_result_51_3 =~ m{\n\z}msx || $tr_result_51_3 eq q{})) {
                    $tr_result_51_3 .= "\n";
                }
                $output_51 = $tr_result_51_3;
        if ( !$pipeline_success_51 ) { $main_exit_code = 1; }
        $output_51 =~ s/\n+\z//msx;
        $output_51;
}; $_pipeline_result; };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "\nCopying ${TODO} files to $2. \\c";
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
    my $nsi_conn_path;
    my @nsi_conn_path;
    my %nsi_conn_path;
    $nsi_conn_path = ${TempDir} . "/nand-sata-install";
    my $nsi_conn_done;
    my @nsi_conn_done;
    my %nsi_conn_done;
    $nsi_conn_done = ${nsi_conn_path} . "/done";
    my $nsi_conn_progress;
    my @nsi_conn_progress;
    my %nsi_conn_progress;
    $nsi_conn_progress = ${nsi_conn_path} . "/progress";
    use File::Path qw(make_path);
    if ( !-d ${nsi_conn_path} ) {
        make_path( ${nsi_conn_path}, { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . ${nsi_conn_path} . ": $err->[0]\n";
        }
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', ${nsi_conn_progress}
      or die "Cannot open file: $OS_ERROR\n";
        print q{0} . "\n";
        $CHILD_ERROR = 0;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', ${nsi_conn_done}
      or die "Cannot open file: $OS_ERROR\n";
        print 'no' . "\n";
        $CHILD_ERROR = 0;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if (my $pid = fork()) {
        # Parent process continues
    } elsif (defined $pid) {
        # Child process executes the background command
        exec 'bash', '-c', q[rsync -avrltD --delete --exclude-from= Variable("EX_LIST", false, None) / "${TempDir}" /rootfs | nl | awk "{ printf \"%.0f\\n\", 100*\$1/\"" "$TODO" '" }' > "${nsi_conn_progress}"; echo MapAccess("PIPESTATUS", "0", None) > "${nsi_conn_done}"];
        croak "exec failed: $OS_ERROR\n";
    } else {
        die "Cannot fork: $ERRNO\n";
    }
    my $rsync_copy_finish;
    my @rsync_copy_finish;
    my %rsync_copy_finish;
    $rsync_copy_finish = q{0};
    my $rsync_progress;
    my @rsync_progress;
    my %rsync_progress;
    $rsync_progress = q{0};
    my $prev_progress;
    my @prev_progress;
    my %prev_progress;
    $prev_progress = q{0};
    my $rsync_done;
    my @rsync_done;
    my %rsync_done;
    $rsync_done = "";
    # Original bash: #!/bin/bash
{
        my $output_55 = q{};
        my $output_printed_55;
        my $pipeline_success_55 = 1;
                my @lines = split /\n/msx, $;
        my $result_55_0 = q{};
        for my $line (@lines) {
        chomp $line;
        my $L = $line;
        $prev_progress = $rsync_progress;
        $rsync_progress = do { my @_qx_cmd = ('tail -n 1 "${nsi_conn_progress}"'); qx{$_qx_cmd[0]}; };
        if (${rsync_progress} eq q{}) {
        $rsync_progress = $prev_progress;
        }
        if ((${prev_progress} > ${rsync_progress})) {
        $rsync_progress = $prev_progress;
        }
        print ${rsync_progress};
        if ( !( (${rsync_progress}) =~ m{\n\z}msx ) ) { print "\n"; }
        $rsync_done = do { my $cat_chunk = q{}; if ( open my $fh, '<', $nsi_conn_done ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $nsi_conn_done . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
        if ("${rsync_done}" ne "no") {
        if ((${rsync_done} == 0)) {
        if ( -e "${nsi_conn_path}" ) {
        if ( -d "${nsi_conn_path}" ) {
        my $err;
        require File::Path;
        File::Path::remove_tree("${nsi_conn_path}", {error => \$err});
        if (@{$err}) {
        carp "rm: carping: could not remove ", ${nsi_conn_path}, ": $err->[0]\n";
        }
        else {
        }
        }
        else {
        if ( unlink "${nsi_conn_path}" ) {
        }
        else {
        carp "rm: carping: could not remove ", ${nsi_conn_path},
        ": $OS_ERROR\n";
        }
        }
        }
        else {
        local $CHILD_ERROR = 0;
        }
        $rsync_copy_finish = q{1};
        }
        else {
        print "Error: could not copy rootfs files, exiting\n";
        exit 4;
        }
        }
        else {
        require Time::HiRes; Time::HiRes::sleep('0.5');
        }
        }
        $output_55 = $result_55_0;

                my $cmd_58 = 'rsync';
        my ($in_57, $out_57);
        my $pid_57 = open3($in_57, $out_57, '>&STDERR', $cmd_58, '-avrltD', '--delete', '--exclude-from=', q{/}, '/rootfs');
        print {$in_57} $output_55;
        close $in_57 or croak 'Close failed: $OS_ERROR';
        $output_55 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_57> };
        close $out_57 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_57, 0;
        if ( !$pipeline_success_55 ) { $main_exit_code = 1; }
        }
if ( -e "${TempDir}" ) {
        if ( -d "${TempDir}" ) {
            carp "rm: carping: ", ${TempDir},
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "${TempDir}" ) {
                            }
            else {
                carp "rm: carping: could not remove ", ${TempDir},
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "/rootfs/etc/fstab" ) {
        if ( -d "/rootfs/etc/fstab" ) {
            carp "rm: carping: ", "/rootfs/etc/fstab",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/rootfs/etc/fstab" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/rootfs/etc/fstab",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    use File::Path qw(make_path);
    if ( !-d ${TempDir} ) {
        make_path( ${TempDir}, { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . ${TempDir} . ": $err->[0]\n";
        }
    }
    if ( !-d '/rootfs/etc' ) {
        make_path( '/rootfs/etc', { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . '/rootfs/etc' . ": $err->[0]\n";
        }
    }
    if ( !-d ${TempDir} ) {
        make_path( ${TempDir}, { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . ${TempDir} . ": $err->[0]\n";
        }
    }
    if ( !-d '/rootfs/media/mmcboot' ) {
        make_path( '/rootfs/media/mmcboot', { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . '/rootfs/media/mmcboot' . ": $err->[0]\n";
        }
    }
    if ( !-d ${TempDir} ) {
        make_path( ${TempDir}, { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . ${TempDir} . ": $err->[0]\n";
        }
    }
    if ( !-d '/rootfs/media/mmcroot' ) {
        make_path( '/rootfs/media/mmcroot', { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . '/rootfs/media/mmcroot' . ": $err->[0]\n";
        }
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', ${TempDir}
      or die "Cannot open file: $OS_ERROR\n";
        print "# <file " . "sys" . "tem" . ">					<mount point>	<type>	<options>							<dump>	<pass>\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $main_exit_code = system('bash', '/rootfs/etc/fstab') >> 8;
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', ${TempDir}
      or die "Cannot open file: $OS_ERROR\n";
        print "tmpfs						/tmp		tmpfs	defaults,nosuid							0	0\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $main_exit_code = system('bash', '/rootfs/etc/fstab') >> 8;
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', ${TempDir}
      or die "Cannot open file: $OS_ERROR\n";
my $grep_result_60;
my @grep_lines_60 = ();
my @grep_filenames_60 = ();
if (-e "/etc/fstab") {
    open my $fh, '<', "/etc/fstab" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_60, $line;
        push @grep_filenames_60, "/etc/fstab";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /etc/fstab: No such file or directory\n"; }
my @grep_filtered_60 = grep { /swap/msx } @grep_lines_60;
$grep_result_60 = join "\n", @grep_filtered_60;
        if (!($grep_result_60 =~ m{\n\z}msx || $grep_result_60 eq q{})) {
            $grep_result_60 .= "\n";
        }
print $grep_result_60;
$CHILD_ERROR = scalar @grep_filtered_60 > 0 ? 0 : 1;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $main_exit_code = system('bash', '/rootfs/etc/fstab') >> 8;
my @sed_lines_61 = split /\n/msx, $;
my @sed_result_61;
foreach my $line (@sed_lines_61) {
chomp $line;
push @sed_result_61, $line;
}
$ = join "\n", @sed_result_61;

if ($1 =~ /^.*nand.*$/msx) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
            print "Finishing installation to NAND.\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        my $REMOVESDTXT;
        my @REMOVESDTXT;
        my %REMOVESDTXT;
        $REMOVESDTXT = "and remove SD to boot from NAND";
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', ${TempDir}
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "$_[0] /boot vfat	defaults 0 0";
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
        $main_exit_code = system('bash', '/rootfs/etc/fstab') >> 8;
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', ${TempDir}
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "$_[1] / ext4 defaults,noatime,commit=600,errors=remount-ro 0 1";
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
        $main_exit_code = system('bash', '/rootfs/etc/fstab') >> 8;
        $main_exit_code = system('dialog', '--title', "$title", '--backtitle', "$backtitle", '--infobox', "\nConverting kernel ... few seconds.", q{5}, '60') >> 8;
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('mkimage', '-A', 'arm', '-O', 'linux', '-T', 'kernel', '-C', 'none', '-a', "0x40008000", '-e', "0x40008000", '-n', "Linux kernel", '-d', '/boot/zImage', ${TempDir}, '/bootfs/uImage') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        use File::Copy qw(copy);
        if ( -e '/boot/script.bin' ) {
            if ( -d '/bootfs/' ) {
                require File::Copy; File::Copy::copy('/boot/script.bin', '/bootfs/' . '/' . ('/boot/script.bin' =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy('/boot/script.bin', '/bootfs/');
            }
        } else {
            croak "cp: cannot stat '/boot/script.bin': No such file or directory\n";
        }
        if ( -e ${TempDir} ) {
            if ( -d '/bootfs/' ) {
                require File::Copy; File::Copy::copy(${TempDir}, '/bootfs/' . '/' . (${TempDir} =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy(${TempDir}, '/bootfs/');
            }
        } else {
            croak "cp: cannot stat '/boot/script.bin': No such file or directory\n";
        }
if ($DEVICE_TYPE ne a13) {
open my $fh_cat, '>', '${TempDir}' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "\t\t\tconsole=ttyS0,115200
\t\t\troot=$2 rootwait
\t\t\textraargs=\"console=tty1 hdmi.audio=EDID:0 disp.screen0_output_mode=EDID:0 consoleblank=0 loglevel=1\"
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
            $main_exit_code = system('bash', '/bootfs/uEnv.txt') >> 8;
}
        else {
open my $fh_cat, '>', '${TempDir}' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "\t\t\tconsole=ttyS0,115200
\t\t\troot=$2 rootwait
\t\t\textraargs=\"consoleblank=0 loglevel=1\"
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
            $main_exit_code = system('bash', '/bootfs/uEnv.txt') >> 8;
        }
        $main_exit_code = system('bash', 'sync') >> 8;
        if ($DEVICE_TYPE eq a20) {
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', ${TempDir}
      or die "Cannot open file: $OS_ERROR\n";
                print "machid=10bb\n";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        $main_exit_code = system('bash', '/bootfs/uEnv.txt') >> 8;
if (0) {
            use File::Copy qw(copy);
            if ( -e ${TempDir} ) {
                if ( -d '/rootfs/boot/uEnv.txt' ) {
                    require File::Copy; File::Copy::copy(${TempDir}, '/rootfs/boot/uEnv.txt' . '/' . (${TempDir} =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy(${TempDir}, '/rootfs/boot/uEnv.txt');
                }
            } else {
                croak "cp: cannot stat '${TempDir}': No such file or directory\n";
            }
            if ( -e '/bootfs/uEnv.txt' ) {
                if ( -d '/rootfs/boot/uEnv.txt' ) {
                    require File::Copy; File::Copy::copy('/bootfs/uEnv.txt', '/rootfs/boot/uEnv.txt' . '/' . ('/bootfs/uEnv.txt' =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy('/bootfs/uEnv.txt', '/rootfs/boot/uEnv.txt');
                }
            } else {
                croak "cp: cannot stat '${TempDir}': No such file or directory\n";
            }
            if ( -e ${TempDir} ) {
                if ( -d '/rootfs/boot/uEnv.txt' ) {
                    require File::Copy; File::Copy::copy(${TempDir}, '/rootfs/boot/uEnv.txt' . '/' . (${TempDir} =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy(${TempDir}, '/rootfs/boot/uEnv.txt');
                }
            } else {
                croak "cp: cannot stat '${TempDir}': No such file or directory\n";
            }
            use File::Copy qw(copy);
            if ( -e ${TempDir} ) {
                if ( -d '/rootfs/boot/script.bin' ) {
                    require File::Copy; File::Copy::copy(${TempDir}, '/rootfs/boot/script.bin' . '/' . (${TempDir} =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy(${TempDir}, '/rootfs/boot/script.bin');
                }
            } else {
                croak "cp: cannot stat '${TempDir}': No such file or directory\n";
            }
            if ( -e '/bootfs/script.bin' ) {
                if ( -d '/rootfs/boot/script.bin' ) {
                    require File::Copy; File::Copy::copy('/bootfs/script.bin', '/rootfs/boot/script.bin' . '/' . ('/bootfs/script.bin' =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy('/bootfs/script.bin', '/rootfs/boot/script.bin');
                }
            } else {
                croak "cp: cannot stat '${TempDir}': No such file or directory\n";
            }
            if ( -e ${TempDir} ) {
                if ( -d '/rootfs/boot/script.bin' ) {
                    require File::Copy; File::Copy::copy(${TempDir}, '/rootfs/boot/script.bin' . '/' . (${TempDir} =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy(${TempDir}, '/rootfs/boot/script.bin');
                }
            } else {
                croak "cp: cannot stat '${TempDir}': No such file or directory\n";
            }
            use File::Copy qw(copy);
            if ( -e ${TempDir} ) {
                if ( -d '/rootfs/boot/uImage' ) {
                    require File::Copy; File::Copy::copy(${TempDir}, '/rootfs/boot/uImage' . '/' . (${TempDir} =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy(${TempDir}, '/rootfs/boot/uImage');
                }
            } else {
                croak "cp: cannot stat '${TempDir}': No such file or directory\n";
            }
            if ( -e '/bootfs/uImage' ) {
                if ( -d '/rootfs/boot/uImage' ) {
                    require File::Copy; File::Copy::copy('/bootfs/uImage', '/rootfs/boot/uImage' . '/' . ('/bootfs/uImage' =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy('/bootfs/uImage', '/rootfs/boot/uImage');
                }
            } else {
                croak "cp: cannot stat '${TempDir}': No such file or directory\n";
            }
            if ( -e ${TempDir} ) {
                if ( -d '/rootfs/boot/uImage' ) {
                    require File::Copy; File::Copy::copy(${TempDir}, '/rootfs/boot/uImage' . '/' . (${TempDir} =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy(${TempDir}, '/rootfs/boot/uImage');
                }
            } else {
                croak "cp: cannot stat '${TempDir}': No such file or directory\n";
            }
        }
        $main_exit_code = system('umount_device', "/dev/nand") >> 8;
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('tune2fs', '-o', 'journal_data_writeback', '/dev/nand2') >> 8;
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
            $main_exit_code = system('tune2fs', '-O', '^has_journal', '/dev/nand2') >> 8;
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
            $main_exit_code = system('e2fsck', '-f', '/dev/nand2') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
if (($2 =~ /^[$]{emmccheck}p.*$/msx || $1 =~ /^[$]{emmccheck}p.*$/msx)) {
if ($2 =~ /^[$]{DISK_ROOT_PART}$/msx) {
            my $targetuuid = $satauuid;
            my $choosen_fs = $FilesystemChoosen;
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
                print "Finalizing: boot from eMMC, rootfs on USB/SATA/NVMe.\n";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
if ($ENV{eMMCFilesystemChoosen} =~ /^(btrfs|f2fs)$/msx) {
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>>', ${TempDir}
      or die "Cannot open file: $OS_ERROR\n";
                    do {
    my $__echo_line = "$ENV{emmcuuid}\t/media/mmcroot  $ENV{eMMCFile" . "sys" . "tem" . "Choosen}	" . $mountopts{$eMMCFilesystemChoosen};
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
                $main_exit_code = system('bash', '/rootfs/etc/fstab') >> 8;
            }
}
        else {
            my $targetuuid = $emmcuuid;
            my $choosen_fs = $eMMCFilesystemChoosen;
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
                print "Finishing full install to eMMC.\n";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
        use File::Copy qw(copy);
        if (-d '/bootfs') {
            require File::Path; File::Path::make_path('/bootfs' . '/' . ('/boot' =~ m|([^/]+)$|)[0]);
            require File::Copy; File::Copy::copy('/boot', '/bootfs' . '/' . ('/boot' =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy('/boot', '/bootfs');
        }
        if (-d '/bootfs') {
            require File::Path; File::Path::make_path('/bootfs' . '/' . (${TempDir} =~ m|([^/]+)$|)[0]);
            require File::Copy; File::Copy::copy(${TempDir}, '/bootfs' . '/' . (${TempDir} =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy(${TempDir}, '/bootfs');
        }
        if ((-f "${TempDir}"/bootfs/boot/boot.cmd)) {
            my @sed_lines_67 = split /\n/msx, $;
my @sed_result_67;
foreach my $line (@sed_lines_67) {
chomp $line;
push @sed_result_67, $line;
}
$ = join "\n", @sed_result_67;

            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
if ((-f "${TempDir}"/bootfs/boot/orangepiEnv.txt)) {
my @sed_lines_68 = split /\n/msx, $;
my @sed_result_68;
foreach my $line (@sed_lines_68) {
chomp $line;
push @sed_result_68, $line;
}
$ = join "\n", @sed_result_68;

            my $grep_result_69;
my @grep_lines_69 = ();
my @grep_filenames_69 = ();
if (-e "/bootfs/boot/orangepiEnv.txt") {
    open my $fh, '<', "/bootfs/boot/orangepiEnv.txt" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_69, $line;
        push @grep_filenames_69, "/bootfs/boot/orangepiEnv.txt";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /bootfs/boot/orangepiEnv.txt: No such file or directory\n"; }
my @grep_filtered_69 = grep { /^rootdev/msx } @grep_lines_69;
$grep_result_69 = join "\n", @grep_filtered_69;
            if (!($grep_result_69 =~ m{\n\z}msx || $grep_result_69 eq q{})) {
                $grep_result_69 .= "\n";
            }
$CHILD_ERROR = scalar @grep_filtered_69 > 0 ? 0 : 1;
$grep_result_69 = q{};
            if ($CHILD_ERROR != 0) {
                                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>>', ${TempDir}
      or die "Cannot open file: $OS_ERROR\n";
                    do {
    my $__echo_line = "rootdev=$targetuuid";
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
            }
            $main_exit_code = system('bash', '/bootfs/boot/orangepiEnv.txt') >> 8;
}
        else {
            if ((-f "${TempDir}"/bootfs/boot/boot.cmd)) {
                my @sed_lines_70 = split /\n/msx, $;
my @sed_result_70;
foreach my $line (@sed_lines_70) {
chomp $line;
push @sed_result_70, $line;
}
$ = join "\n", @sed_result_70;

                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
            if ((-f "${TempDir}"/bootfs/boot/boot.ini)) {
                my @sed_lines_71 = split /\n/msx, $;
my @sed_result_71;
foreach my $line (@sed_lines_71) {
chomp $line;
push @sed_result_71, $line;
}
$ = join "\n", @sed_result_71;

                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
            if ((-f "${TempDir}"/rootfs/boot/boot.ini)) {
                my @sed_lines_72 = split /\n/msx, $;
my @sed_result_72;
foreach my $line (@sed_lines_72) {
chomp $line;
push @sed_result_72, $line;
}
$ = join "\n", @sed_result_72;

                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
        }
if ((-f "${TempDir}"/bootfs/boot/extlinux/extlinux.conf)) {
my @sed_lines_73 = split /\n/msx, $;
my @sed_result_73;
foreach my $line (@sed_lines_73) {
chomp $line;
push @sed_result_73, $line;
}
$ = join "\n", @sed_result_73;

            if ((-f "${TempDir}"/bootfs/boot/boot.cmd)) {
                if ( -e "${TempDir}" ) {
                    if ( -d "${TempDir}" ) {
                        croak "rm: ", ${TempDir},
          " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink "${TempDir}" ) {
                                                    }
                        else {
                            croak "rm: cannot remove ", ${TempDir},
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 1;
                    croak "rm: ", ${TempDir}, ": No such file or directory\n";
                }
if ( -e "/bootfs/boot/boot.cmd" ) {
                    if ( -d "/bootfs/boot/boot.cmd" ) {
                        croak "rm: ", "/bootfs/boot/boot.cmd",
          " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink "/bootfs/boot/boot.cmd" ) {
                                                    }
                        else {
                            croak "rm: cannot remove ", "/bootfs/boot/boot.cmd",
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 1;
                    croak "rm: ", "/bootfs/boot/boot.cmd", ": No such file or directory\n";
                }
                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
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
                $main_exit_code = system('mkimage', '-C', 'none', '-A', 'arm', '-T', 'script', '-d', ${TempDir}, '/bootfs/boot/boot.cmd', ${TempDir}, '/bootfs/boot/boot.scr') >> 8;
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            if ($CHILD_ERROR != 0) {
                                do {
                    local %ENV = %ENV;
                    my %mountopts = %mountopts;
                    my $DEVICE_TYPE = $DEVICE_TYPE;
                    my $FIRSTSECTOR = $FIRSTSECTOR;
                    my $CWD = $CWD;
                    my $targetuuid = $targetuuid;
                    my $root_partition = $root_partition;
                    my $LANG = $LANG;
                    my $emmccheck = $emmccheck;
                    my $nsi_conn_path = $nsi_conn_path;
                    my $TempDir = $TempDir;
                    my $REMOVESDTXT = $REMOVESDTXT;
                    my $title = $title;
                    my $EX_LIST = $EX_LIST;
                    my $root_partition_device = $root_partition_device;
                    my $sduuid = $sduuid;
                    my $satauuid = $satauuid;
                    my $root_uuid = $root_uuid;
                    my $TODO = $TODO;
                    my $logfile = $logfile;
                    my $rsync_done = $rsync_done;
                    my %mkopts = %mkopts;
                    my $DEST = $DEST;
                    my $nsi_conn_progress = $nsi_conn_progress;
                    my $rsync_copy_finish = $rsync_copy_finish;
                    my $prev_progress = $prev_progress;
                    my $choosen_fs = $choosen_fs;
                    my $rsync_progress = $rsync_progress;
                    my $USAGE = $USAGE;
                    my $diskcheck = $diskcheck;
                    my $err = $err;
                    my $backtitle = $backtitle;
                    my $spicheck = $spicheck;
                    my $nsi_conn_done = $nsi_conn_done;
                    my $BOOTLOADER = $BOOTLOADER;
                    my $nandcheck = $nandcheck;
                        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                            print 'Error while creating U-Boot loader image with mkimage' . "\n";
                            $CHILD_ERROR = 0;
                        };
exit 5;
                    q{};
                };
            }
        }
if ("$1" ne "$2") {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', ${TempDir}
      or die "Cannot open file: $OS_ERROR\n";
                do {
    my $__echo_line = "$ENV{emmcbootuuid}	/media/mmcboot	ext4    " . $mountopts{'ext4'};
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
            $main_exit_code = system('bash', '/rootfs/etc/fstab') >> 8;
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', ${TempDir}
      or die "Cannot open file: $OS_ERROR\n";
                print "/media/mmcboot/boot   				/boot		none	bind								0       0\n";
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            $main_exit_code = system('bash', '/rootfs/etc/fstab') >> 8;
        }
if (!(!(my $grep_result_74;
my @grep_lines_74 = ();
my @grep_filenames_74 = ();
if (-e "/bootfs/boot/orangepiEnv.txt") {
    open my $fh, '<', "/bootfs/boot/orangepiEnv.txt" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_74, $line;
        push @grep_filenames_74, "/bootfs/boot/orangepiEnv.txt";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /bootfs/boot/orangepiEnv.txt: No such file or directory\n"; }
my @grep_filtered_74 = grep { /^rootfstype=.*/msx } @grep_lines_74;
$grep_result_74 = join "\n", @grep_filtered_74;
        if (!($grep_result_74 =~ m{\n\z}msx || $grep_result_74 eq q{})) {
            $grep_result_74 .= "\n";
        }
$CHILD_ERROR = scalar @grep_filtered_74 > 0 ? 0 : 1;
$grep_result_74 = q{};))) {
            if ((-f "${TempDir}"/bootfs/boot/orangepiEnv.txt)) {
                                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>>', ${TempDir}
      or die "Cannot open file: $OS_ERROR\n";
                    do {
    my $__echo_line = "rootfstype=$choosen_fs";
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
                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
            $main_exit_code = system('bash', '/bootfs/boot/orangepiEnv.txt') >> 8;
        }
if ($ENV{eMMCFilesystemChoosen} =~ /^(btrfs|f2fs)$/msx) {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', ${TempDir}
      or die "Cannot open file: $OS_ERROR\n";
                do {
    my $__echo_line = "$targetuuid	/		$choosen_fs	" . $mountopts{$choosen_fs};
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
            $main_exit_code = system('bash', '/rootfs/etc/fstab') >> 8;
            if (${emmcswapuuid} ne q{}) {
                my @sed_lines_75 = split /\n/msx, $;
my @sed_result_75;
foreach my $line (@sed_lines_75) {
chomp $line;
push @sed_result_75, $line;
}
$ = join "\n", @sed_result_75;

                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
            if ((-f "${TempDir}"/bootfs/boot/orangepiEnv.txt)) {
                my @sed_lines_76 = split /\n/msx, $;
my @sed_result_76;
foreach my $line (@sed_lines_76) {
chomp $line;
push @sed_result_76, $line;
}
$ = join "\n", @sed_result_76;

                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
}
        else {
            if ((-f "${TempDir}"/bootfs/boot/orangepiEnv.txt)) {
                my @sed_lines_77 = split /\n/msx, $;
my @sed_result_77;
foreach my $line (@sed_lines_77) {
chomp $line;
push @sed_result_77, $line;
}
$ = join "\n", @sed_result_77;

                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', ${TempDir}
      or die "Cannot open file: $OS_ERROR\n";
                do {
    my $__echo_line = "$targetuuid	/		$choosen_fs	" . $mountopts{$choosen_fs};
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
            $main_exit_code = system('bash', '/rootfs/etc/fstab') >> 8;
        }
if ($(type -t write_uboot_platform) ne function) {
            print "Error: no u-boot package found, exiting\n";
exit 6;
        }
        $main_exit_code = system('write_uboot_platform', "$ENV{DIR}", $emmccheck) >> 8;
    }
if (($2 =~ /^[$]{DISK_ROOT_PART}$/msx && $1 eq q{})) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
            print "Finishing transfer to disk, boot from SD/eMMC\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        if ((-f '/boot/boot.cmd')) {
            my @sed_lines_78 = split /\n/msx, $;
my @sed_result_78;
foreach my $line (@sed_lines_78) {
chomp $line;
push @sed_result_78, $line;
}
$ = join "\n", @sed_result_78;

            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ((-f '/boot/boot.ini')) {
            my @sed_lines_79 = split /\n/msx, $;
my @sed_result_79;
foreach my $line (@sed_lines_79) {
chomp $line;
push @sed_result_79, $line;
}
$ = join "\n", @sed_result_79;

            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
if ((-f '/boot/orangepiEnv.txt')) {
my @sed_lines_80 = split /\n/msx, $;
my @sed_result_80;
foreach my $line (@sed_lines_80) {
chomp $line;
push @sed_result_80, $line;
}
$ = join "\n", @sed_result_80;

            my $grep_result_81;
my @grep_lines_81 = ();
my @grep_filenames_81 = ();
if (-e "/boot/orangepiEnv.txt") {
    open my $fh, '<', "/boot/orangepiEnv.txt" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_81, $line;
        push @grep_filenames_81, "/boot/orangepiEnv.txt";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /boot/orangepiEnv.txt: No such file or directory\n"; }
my @grep_filtered_81 = grep { /^rootdev/msx } @grep_lines_81;
$grep_result_81 = join "\n", @grep_filtered_81;
            if (!($grep_result_81 =~ m{\n\z}msx || $grep_result_81 eq q{})) {
                $grep_result_81 .= "\n";
            }
$CHILD_ERROR = scalar @grep_filtered_81 > 0 ? 0 : 1;
$grep_result_81 = q{};
            if ($CHILD_ERROR != 0) {
                                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>>', '/boot/orangepiEnv.txt'
      or die "Cannot open file: $OS_ERROR\n";
                    do {
    my $__echo_line = "rootdev=$satauuid";
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
            }
my @sed_lines_82 = split /\n/msx, $;
my @sed_result_82;
foreach my $line (@sed_lines_82) {
chomp $line;
push @sed_result_82, $line;
}
$ = join "\n", @sed_result_82;

            my $grep_result_83;
my @grep_lines_83 = ();
my @grep_filenames_83 = ();
if (-e "/boot/orangepiEnv.txt") {
    open my $fh, '<', "/boot/orangepiEnv.txt" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_83, $line;
        push @grep_filenames_83, "/boot/orangepiEnv.txt";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /boot/orangepiEnv.txt: No such file or directory\n"; }
my @grep_filtered_83 = grep { /^rootfstype/msx } @grep_lines_83;
$grep_result_83 = join "\n", @grep_filtered_83;
            if (!($grep_result_83 =~ m{\n\z}msx || $grep_result_83 eq q{})) {
                $grep_result_83 .= "\n";
            }
$CHILD_ERROR = scalar @grep_filtered_83 > 0 ? 0 : 1;
$grep_result_83 = q{};
            if ($CHILD_ERROR != 0) {
                                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>>', '/boot/orangepiEnv.txt'
      or die "Cannot open file: $OS_ERROR\n";
                    do {
    my $__echo_line = "rootfstype=$ENV{File" . "sys" . "tem" . "Choosen}";
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
            }
}
        else {
my @sed_lines_84 = split /\n/msx, $;
my @sed_result_84;
foreach my $line (@sed_lines_84) {
chomp $line;
push @sed_result_84, $line;
}
$ = join "\n", @sed_result_84;

my @sed_lines_85 = split /\n/msx, $;
my @sed_result_85;
foreach my $line (@sed_lines_85) {
chomp $line;
push @sed_result_85, $line;
}
$ = join "\n", @sed_result_85;

my @sed_lines_86 = split /\n/msx, $;
my @sed_result_86;
foreach my $line (@sed_lines_86) {
chomp $line;
push @sed_result_86, $line;
}
$ = join "\n", @sed_result_86;

my @sed_lines_87 = split /\n/msx, $;
my @sed_result_87;
foreach my $line (@sed_lines_87) {
chomp $line;
push @sed_result_87, $line;
}
$ = join "\n", @sed_result_87;

        }
if ((-f '/bootfs/boot/extlinux/extlinux.conf')) {
my @sed_lines_88 = split /\n/msx, $;
my @sed_result_88;
foreach my $line (@sed_lines_88) {
chomp $line;
push @sed_result_88, $line;
}
$ = join "\n", @sed_result_88;

            if ((-f '/boot/boot.cmd')) {
                if ( -e "/boot/boot.cmd" ) {
                    if ( -d "/boot/boot.cmd" ) {
                        croak "rm: ", "/boot/boot.cmd",
          " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink "/boot/boot.cmd" ) {
                                                    }
                        else {
                            croak "rm: cannot remove ", "/boot/boot.cmd",
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 1;
                    croak "rm: ", "/boot/boot.cmd", ": No such file or directory\n";
                }
                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
        }
                if ((-f '/boot/boot.cmd')) {
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                my $tmp = do {
                $main_exit_code = system('mkimage', '-C', 'none', '-A', 'arm', '-T', 'script', '-d', '/boot/boot.cmd', '/boot/boot.scr') >> 8;
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ($CHILD_ERROR != 0) {
                        do {
                local %ENV = %ENV;
                my %mountopts = %mountopts;
                my $DEVICE_TYPE = $DEVICE_TYPE;
                my $FIRSTSECTOR = $FIRSTSECTOR;
                my $CWD = $CWD;
                my $targetuuid = $targetuuid;
                my $root_partition = $root_partition;
                my $LANG = $LANG;
                my $emmccheck = $emmccheck;
                my $nsi_conn_path = $nsi_conn_path;
                my $TempDir = $TempDir;
                my $REMOVESDTXT = $REMOVESDTXT;
                my $title = $title;
                my $EX_LIST = $EX_LIST;
                my $root_partition_device = $root_partition_device;
                my $sduuid = $sduuid;
                my $satauuid = $satauuid;
                my $root_uuid = $root_uuid;
                my $TODO = $TODO;
                my $logfile = $logfile;
                my $rsync_done = $rsync_done;
                my %mkopts = %mkopts;
                my $DEST = $DEST;
                my $nsi_conn_progress = $nsi_conn_progress;
                my $rsync_copy_finish = $rsync_copy_finish;
                my $prev_progress = $prev_progress;
                my $choosen_fs = $choosen_fs;
                my $rsync_progress = $rsync_progress;
                my $USAGE = $USAGE;
                my $diskcheck = $diskcheck;
                my $err = $err;
                my $backtitle = $backtitle;
                my $spicheck = $spicheck;
                my $nsi_conn_done = $nsi_conn_done;
                my $BOOTLOADER = $BOOTLOADER;
                my $nandcheck = $nandcheck;
                    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                        print 'Error while creating U-Boot loader image with mkimage' . "\n";
                        $CHILD_ERROR = 0;
                    };
exit 7;
                q{};
            };
        }
        use File::Path qw(make_path);
        if ( !-d ${TempDir} ) {
            make_path( ${TempDir}, { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . ${TempDir} . ": $err->[0]\n";
            }
        }
        if ( !-d '/rootfs/media/mmc/boot' ) {
            make_path( '/rootfs/media/mmc/boot', { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . '/rootfs/media/mmc/boot' . ": $err->[0]\n";
            }
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', ${TempDir}
      or die "Cannot open file: $OS_ERROR\n";
            print ${sduuid} . "	/media/mmcboot	ext4    " . $mountopts{'ext4'};
if ( !( (${sduuid} . "	/media/mmcboot	ext4    " . $mountopts{'ext4'}) =~ m{\n\z}msx ) ) { print "\n"; }
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        $main_exit_code = system('bash', '/rootfs/etc/fstab') >> 8;
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', ${TempDir}
      or die "Cannot open file: $OS_ERROR\n";
            print "/media/mmcboot/boot  				/boot		none	bind								0       0\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        $main_exit_code = system('bash', '/rootfs/etc/fstab') >> 8;
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', ${TempDir}
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "$satauuid\t/\t\t$ENV{File" . "sys" . "tem" . "Choosen}	" . $mountopts{$FilesystemChoosen};
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
        $main_exit_code = system('bash', '/rootfs/etc/fstab') >> 8;
if ((-f '/var/swap')) {
                        $main_exit_code = system('fallocate', '-l', '128M', ${TempDir}, '/rootfs/var/swap') >> 8;
            if ($CHILD_ERROR != 0) {
                                $main_exit_code = system('dd', 'if', q{=}, '/dev/zero', 'of', q{=}, ${TempDir}, '/rootfs/var/swap', 'bs', q{=}, '1M', 'count', q{=}, '128', 'status', q{=}, 'noxfer') >> 8;
            }
            $main_exit_code = system('mkswap', ${TempDir}, '/rootfs/var/swap') >> 8;
        }
    }
if ($1 =~ /^.*spi.*$/msx) {
my @sed_lines_90 = split /\n/msx, $;
my @sed_result_90;
foreach my $line (@sed_lines_90) {
chomp $line;
push @sed_result_90, $line;
}
$ = join "\n", @sed_result_90;

        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', ${TempDir}
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "$satauuid\t/\t\t$ENV{File" . "sys" . "tem" . "Choosen}	" . $mountopts{$FilesystemChoosen};
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
        $main_exit_code = system('bash', '/rootfs/etc/fstab') >> 8;
    }
my $grep_result_91;
my @grep_lines_91 = ();
my @grep_filenames_91 = ();
if (-e "/etc/fstab") {
    open my $fh, '<', "/etc/fstab" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_91, $line;
        push @grep_filenames_91, "/etc/fstab";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /etc/fstab: No such file or directory\n"; }
my @grep_filtered_91 = grep { /\ \/srv\//msx } @grep_lines_91;
$grep_result_91 = join "\n", @grep_filtered_91;
    if (!($grep_result_91 =~ m{\n\z}msx || $grep_result_91 eq q{})) {
        $grep_result_91 .= "\n";
    }
$CHILD_ERROR = scalar @grep_filtered_91 > 0 ? 0 : 1;
$grep_result_91 = q{};
if ((($? == 0) && (-f '/etc/default/openmediavault'))) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', ${TempDir}
      or die "Cannot open file: $OS_ERROR\n";
            print "# >>> [openmediavault]\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        $main_exit_code = system('bash', '/rootfs/etc/fstab') >> 8;
        # Original bash: grep ' /srv/' /etc/fstab | while read ; do
{
            my $output_92 = q{};
            my $output_printed_92;
            my $pipeline_success_92 = 1;
                        my $grep_result_92_0;
            my @grep_lines_92_0 = ();
            my @grep_filenames_92_0 = ();
            if (-e "/etc/fstab") {
            open my $fh, '<', "/etc/fstab" or croak "Cannot open file: $ERRNO";
            while (my $line = <$fh>) {
            chomp $line;
            push @grep_lines_92_0, $line;
            push @grep_filenames_92_0, "/etc/fstab";
            }
            close $fh
            or croak "Close failed: $OS_ERROR";
            }
            else { print {*STDERR} "grep: /etc/fstab: No such file or directory\n"; }
            my @grep_filtered_92_0 = grep { /\ \/srv\//msx } @grep_lines_92_0;
            $grep_result_92_0 = join "\n", @grep_filtered_92_0;
            if (!($grep_result_92_0 =~ m{\n\z}msx || $grep_result_92_0 eq q{})) {
            $grep_result_92_0 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_92_0 > 0 ? 0 : 1;
            $output_92 = $grep_result_92_0;
            $output_92 = $grep_result_92_0;

                        my @lines = split /\n/msx, $output_92;
            my $result_92_1 = q{};
            for my $line (@lines) {
            chomp $line;
            my $L = $line;
            do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', ${TempDir}
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_93 = q{};
            $tmp_redirect_93 .= ($ENV{REPLY} // q{}) . "\n";
            if ( !($tmp_redirect_93 =~ m{\n\z}msx) ) { $tmp_redirect_93 .= "\n"; }
            $CHILD_ERROR = 0;
            $tmp_redirect_93;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_92; }
            $output_printed_92 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            $main_exit_code = system('bash', '/rootfs/etc/fstab') >> 8;
            use File::Path qw(make_path);
            if ( !-d ${TempDir} . "/rootfs" . (do { my $_chomp_temp = do { my $here_input = ($ENV{REPLY} // q{}); chomp(my $result = qx{echo "$here_input" | awk -F ' ' '{print $2}'}); $CHILD_ERROR = $? >> 8; $result; }; chomp $_chomp_temp; $_chomp_temp; }) ) {
            make_path( ${TempDir} . "/rootfs" . (do { my $_chomp_temp = do { my $here_input = ($ENV{REPLY} // q{}); chomp(my $result = qx{echo "$here_input" | awk -F ' ' '{print $2}'}); $CHILD_ERROR = $? >> 8; $result; }; chomp $_chomp_temp; $_chomp_temp; }), { error => \$err } );
            if ( @{$err} ) {
            croak "mkdir: cannot create directory " . ${TempDir} . "/rootfs" . (do { my $_chomp_temp = do { my $here_input = ($ENV{REPLY} // q{}); chomp(my $result = qx{echo "$here_input" | awk -F ' ' '{print $2}'}); $CHILD_ERROR = $? >> 8; $result; }; chomp $_chomp_temp; $_chomp_temp; }) . ": $err->[0]\n";
            }
            }
            }
            $output_92 = $result_92_1;
            if ($output_92 ne q{} && !defined $output_printed_92) {
                print $output_92;
                if (!($output_92 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_92 ) { $main_exit_code = 1; }
            }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', ${TempDir}
      or die "Cannot open file: $OS_ERROR\n";
            print "# <<< [openmediavault]\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        $main_exit_code = system('bash', '/rootfs/etc/fstab') >> 8;
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
        print "\nChecking again for open files:" . "\n";
        $CHILD_ERROR = 0;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    # Original bash: lsof / | awk 'NR==1 || $4~/[0-9][uw]/' | grep -v "^COMMAND" >> $logfile
{
        my $output_96 = q{};
        my $output_printed_96;
        my $pipeline_success_96 = 1;
                my ($in_97, $out_97);
        my $pid_97 = open3($in_97, $out_97, '>&STDERR', 'lsof', q{/});
        close $in_97 or croak 'Close failed: $OS_ERROR';
        $output_96 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_97> };
        close $out_97 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_97, 0;

                my @lines = split /\n/msx, $output_96;
        my @result;
        foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /^\s*$/msx) { next; }
        my @fields = split /\s+/msx, $line;
        push @result, ($line . "\n");
        }
        $output_96 = join "", @result;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $logfile
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_98 = q{};
        my $grep_result_99;
        my @grep_lines_99 = split /\n/msx, $output_96;
        my @grep_filtered_99 = grep { !/^COMMAND/msx } @grep_lines_99;
        $grep_result_99 = join "\n", @grep_filtered_99;
        if (!($grep_result_99 =~ m{\n\z}msx || $grep_result_99 eq q{})) {
        $grep_result_99 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_99 > 0 ? 0 : 1;
        $tmp_redirect_98 = $grep_result_99;
        $tmp_redirect_98;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_96; }
        $output_printed_96 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_96 ) { $main_exit_code = 1; }
        }
        $LANG = q{C};
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
            print "\ndo {\nrequire POSIX; POSIX::strftime('%a %b %e %H:%M:%S %Z %Y', localtime(time())) . \"\\n\"\n}: Finished\n\n" . "\n";
            $CHILD_ERROR = 0;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', ${TempDir}
      or die "Cannot open file: $OS_ERROR\n";
print do { my $cat_chunk = q{}; if ( open my $fh, '<', $logfile ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $logfile . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $main_exit_code = system('/rootfs', $logfile) >> 8;
    $main_exit_code = system('bash', 'sync') >> 8;
    $main_exit_code = system('umount', ${TempDir}, '/rootfs') >> 8;
    if ($1 ne "spi") {
                $main_exit_code = system('umount', ${TempDir}, '/bootfs') >> 8;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    return;
}

sub umount_device {
if ($1 ne q{}) {
        my $device;
        my @device;
        my %device;
        $device = "$_[0]";
        my $n;
        for my $n ($device, q{*}) {
if ($device ne "$n") {
if (!(                # Original bash: mount|grep -q "$n";
{
                    my $output_101 = q{};
                    my $output_printed_101;
                    my $pipeline_success_101 = 1;
                                        my ($in_102, $out_102);
                    my $pid_102 = open3($in_102, $out_102, '>&STDERR', 'mount', );
                    close $in_102 or croak 'Close failed: $OS_ERROR';
                    $output_101 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_102> };
                    close $out_102 or croak 'Close failed: $OS_ERROR';
                    waitpid $pid_102, 0;

                                        my $grep_result_101_1;
                    my @grep_lines_101_1 = split /\n/msx, $output_101;
                    my @grep_filtered_101_1 = grep { /$n/msx } @grep_lines_101_1;
                    $grep_result_101_1 = join "\n", @grep_filtered_101_1;
                    if (!($grep_result_101_1 =~ m{\n\z}msx || $grep_result_101_1 eq q{})) {
                    $grep_result_101_1 .= "\n";
                    }
                    $CHILD_ERROR = scalar @grep_filtered_101_1 > 0 ? 0 : 1;
                    $grep_result_101_1 = q{};
                    $output_101 = q{};
                    if ((scalar @grep_filtered_101_1) == 0) {
                        $pipeline_success_101 = 0;
                    }
                    if ($output_101 ne q{} && !defined $output_printed_101) {
                        print $output_101;
                        if (!($output_101 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_101 ) { $main_exit_code = 1; }
                    })) {
                    do {
                        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                        my $tmp = do {
                        $main_exit_code = system('umount', '-l', "$n") >> 8;
                        };
                        print $tmp;
                        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                    };
                }
            }
        }
    }
    return;
}

sub show_nand_warning {
    my $temp_rc = do {
    my ($in_103, $out_103);
    my $pid_103 = open3($in_103, $out_103, '>&STDERR', 'mktemp');
    close $in_103 or croak 'Close failed: $OS_ERROR';
    my $result_103 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_103> };
    close $out_103 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_103, 0;
    $result_103
};
open my $fh_cat, '>', '$temp_rc' or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} q{	screen_color = (WHITE,RED,ON)
};
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    my $warn_text = "You are installing the " . "sys" . "tem" . " to sunxi NAND.

	This is not recommended as NAND has \\Z1worse performance
	and reliability\\Zn than a good SD card.

	You have been warned.";
    my $DIALOGRC = $temp_rc;
    $main_exit_code = system('dialog', '--title', "NAND warning", '--backtitle', "$backtitle", '--colors', '--ok-label', "I understand and agree", '--msgbox', "$warn_text", '10', '70') >> 8;
    return;
}

sub format_nand {
    if (do {
if ((!-e /dev/nand)) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print '/dev/nand does not exist' . "\n";
        $CHILD_ERROR = 0;
    };
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
        $CHILD_ERROR == 0
    }) {
        exit 8;
    }
    show_nand_warning();
    $main_exit_code = system('dialog', '--title', "$title", '--backtitle', "$backtitle", '--infobox', "\n            Formatting ... up to one minute.", q{5}, '60') >> 8;
if ($DEVICE_TYPE eq a20) {
        # Original bash: #!/bin/bash
{
            my $output_104 = q{};
            my $output_printed_104;
            my $pipeline_success_104 = 1;
                        $output_104 = q{};
            $output_104 .= q{y} . "\n";
            if ( !($output_104 =~ m{\n\z}msx) ) { $output_104 .= "\n"; }
            $CHILD_ERROR = 0;

                        my $cmd_106 = 'sunxi-nand-part';
            my ($in_105, $out_105);
            my $pid_105 = open3($in_105, $out_105, '>&STDERR', $cmd_106, '-f', 'a20', '/dev/nand', '65536', 'bootloader 65536', 'linux 0');
            print {$in_105} $output_104;
            close $in_105 or croak 'Close failed: $OS_ERROR';
            $output_104 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_105> };
            close $out_105 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_105, 0;
            if ( !$pipeline_success_104 ) { $main_exit_code = 1; }
            }
}
    else {
        # Original bash: #!/bin/bash
{
            my $output_107 = q{};
            my $output_printed_107;
            my $pipeline_success_107 = 1;
                        $output_107 = q{};
            $output_107 .= q{y} . "\n";
            if ( !($output_107 =~ m{\n\z}msx) ) { $output_107 .= "\n"; }
            $CHILD_ERROR = 0;

                        my $cmd_109 = 'sunxi-nand-part';
            my ($in_108, $out_108);
            my $pid_108 = open3($in_108, $out_108, '>&STDERR', $cmd_109, '-f', 'a10', '/dev/nand', '65536', 'bootloader 65536', 'linux 0');
            print {$in_108} $output_107;
            close $in_108 or croak 'Close failed: $OS_ERROR';
            $output_107 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_108> };
            close $out_108 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_108, 0;
            if ( !$pipeline_success_107 ) { $main_exit_code = 1; }
            }
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('mkfs.vfat', '/dev/nand1') >> 8;
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
        open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('mkfs.ext4', '-qF', '/dev/nand2') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}

sub format_emmc {
    my ($file) = @_;
    my $IFS;
    my @IFS;
    my %IFS;
    $IFS = " ";
    my $BTRFS;
    my @BTRFS;
    my %BTRFS;
    $BTRFS = do { my $grep_result_110;
my @grep_lines_110 = ();
my @grep_filenames_110 = ();
if (-e "/proc/filesystems") {
    open my $fh, '<', "/proc/filesystems" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_110, $line;
        push @grep_filenames_110, "/proc/filesystems";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /proc/filesystems: No such file or directory\n"; }
my @grep_filtered_110 = grep { /btrfs/msx } @grep_lines_110;
my @grep_matches_110;
foreach my $line (@grep_filtered_110) {
    if ($line =~ /(btrfs)/msx) {
        push @grep_matches_110, $1;
    }
}
$grep_result_110 = join "\n", @grep_matches_110;
$CHILD_ERROR = scalar @grep_filtered_110 > 0 ? 0 : 1;
 $grep_result_110; };
    my $FilesystemTargets;
    my @FilesystemTargets;
    my %FilesystemTargets;
    $FilesystemTargets = "1 ext4 2 ext3 3 ext2 4 f2fs";
    if (($BTRFS ne q{} && (-r '!`uname | grep '^3.' `'))) {
                $FilesystemTargets = $FilesystemTargets;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    my $FilesystemOptions;
    my @FilesystemOptions = ($FilesystemTargets);
    my %FilesystemOptions;
    my $FilesystemChoices;
    my @FilesystemChoices;
    my %FilesystemChoices;
    $FilesystemChoices = q{1};
    if (($? != 0)) {
        exit 9;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    my $eMMCFilesystemChoosen;
    my @eMMCFilesystemChoosen;
    my %eMMCFilesystemChoosen;
    $eMMCFilesystemChoosen = $FilesystemOptions[eval { int((2*$FilesystemChoices)-1) } // ""];
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('dd', 'bs', q{=}, q{1}, 'seek', q{=}, '446', 'count', q{=}, '64', 'if', q{=}, '/dev/zero', 'of', q{=}, "$_[0]") >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    my $QUOTED_DEVICE;
    my @QUOTED_DEVICE;
    my %QUOTED_DEVICE;
    $QUOTED_DEVICE = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_111 = q{};
        my $output_printed_111;
        my $pipeline_success_111 = 1;
        $output_111 .= $1 . "\n";
        if ( !($output_111 =~ m{\n\z}msx) ) { $output_111 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_111 = 0; }
        my @sed_lines_111 = split /\n/msx, $output_111;
        my @sed_result_111;
        foreach my $line (@sed_lines_111) {
        chomp $line;
        push @sed_result_111, $line;
        }
        $output_111 = join "\n", @sed_result_111;

        if ( !$pipeline_success_111 ) { $main_exit_code = 1; }
        $output_111 =~ s/\n+\z//msx;
        $output_111;
}; $_pipeline_result; };
    my $CAPACITY;
    my @CAPACITY;
    my %CAPACITY;
    $CAPACITY = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_112 = q{};
        my $output_printed_112;
        my $pipeline_success_112 = 1;

        my ($in_113, $out_113);
        my $pid_113 = open3($in_113, $out_113, '>&STDERR', 'parted', 'unit', q{s}, 'print', '-s', q{m});
        close $in_113 or croak 'Close failed: $OS_ERROR';
        $output_112 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_113> };
        close $out_113 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_113, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_112 = 0; }
        my @lines = split /\n/msx, $output_112;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /:/msx, $line;
            push @result, ($line . "\n");
        }
        $output_112 = join "", @result;

        if ( !$pipeline_success_112 ) { $main_exit_code = 1; }
        $output_112 =~ s/\n+\z//msx;
        $output_112;
}; $_pipeline_result; };
if (($CAPACITY < $MAGIC_4000000)) {
        my $LASTSECTOR;
        my @LASTSECTOR;
        my %LASTSECTOR;
        my $parted;
        my $unit;
        my $s;
        my $print;
        my $sm;
        my $awk;
        my $F;
        my $printf;
        $LASTSECTOR = eval { int( 32768 * do { chomp(my $_r = qx'parted "$1" unit s print -sm | awk -F":" "/^${QUOTED_DEVICE}/ {printf (\"%0d\", ( \$2 * 98 / 3276800))}"'); $_r; } -1 ) } // "";
}
    else {
        $LASTSECTOR = eval { int( 32768 * do { chomp(my $_r = qx'parted "$1" unit s print -sm | awk -F":" "/^${QUOTED_DEVICE}/ {printf (\"%0d\", ( \$2 * 99 / 3276800))}"'); $_r; } -1 ) } // "";
    }
    my $PART_TABLE_TYPE;
    my @PART_TABLE_TYPE;
    my %PART_TABLE_TYPE;
    $PART_TABLE_TYPE = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_114 = q{};
        my $output_printed_114;
        my $pipeline_success_114 = 1;

        my ($in_115, $out_115);
        my $pid_115 = open3($in_115, $out_115, '>&STDERR', 'parted', 'print', '-s', q{m});
        close $in_115 or croak 'Close failed: $OS_ERROR';
        $output_114 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_115> };
        close $out_115 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_115, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_114 = 0; }
        my @lines = split /\n/msx, $output_114;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /:/msx, $line;
            if (!($line ~ pattern)) { next; }
            push @result, ($fields[5] . "\n");
        }
        $output_114 = join "", @result;

        if ( !$pipeline_success_114 ) { $main_exit_code = 1; }
        $output_114 =~ s/\n+\z//msx;
        $output_114;
}; $_pipeline_result; };
    $main_exit_code = system('parted', '-s', "$_[0]", '--', 'mklabel', "$PART_TABLE_TYPE") >> 8;
if ($eMMCFilesystemChoosen =~ /^(btrfs|f2fs)$/msx) {
        my $partedFsType = ${eMMCFilesystemChoosen};
if ($eMMCFilesystemChoosen =~ /^"f2fs"$/msx) {
            $partedFsType = q{};
        }
        my $DEFAULT_BOOTSIZE;
        my @DEFAULT_BOOTSIZE;
        my %DEFAULT_BOOTSIZE;
        $DEFAULT_BOOTSIZE = '256';
        my $DEFAULT_BOOTSIZE_SECTORS;
        my @DEFAULT_BOOTSIZE_SECTORS;
        my %DEFAULT_BOOTSIZE_SECTORS;
        $DEFAULT_BOOTSIZE_SECTORS = eval { int(($DEFAULT_BOOTSIZE * 1024 * 1024) / 512) } // "";
my $grep_result_116;
my @grep_lines_116 = ();
my @grep_filenames_116 = ();
if (-e "/etc/fstab") {
    open my $fh, '<', "/etc/fstab" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_116, $line;
        push @grep_filenames_116, "/etc/fstab";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /etc/fstab: No such file or directory\n"; }
my @grep_filtered_116 = grep { /swap/msx } @grep_lines_116;
$grep_result_116 = join "\n", @grep_filtered_116;
        if (!($grep_result_116 =~ m{\n\z}msx || $grep_result_116 eq q{})) {
            $grep_result_116 .= "\n";
        }
$CHILD_ERROR = scalar @grep_filtered_116 > 0 ? 0 : 1;
$grep_result_116 = q{};
if ($? =~ /^0$/msx) {
                        $main_exit_code = system('parted', '-s', "$_[0]", '--', 'mkpart', 'primary', $partedFsType, $FIRSTSECTOR, q{s}, eval { int( $FIRSTSECTOR + $DEFAULT_BOOTSIZE_SECTORS - 1 ) } // "", q{s}) >> 8;
                        $main_exit_code = system('parted', '-s', "$_[0]", '--', 'mkpart', 'primary', $partedFsType, eval { int( $FIRSTSECTOR + $DEFAULT_BOOTSIZE_SECTORS ) } // "", q{s}, eval { int( $FIRSTSECTOR + 393215 ) } // "", q{s}) >> 8;
                        $main_exit_code = system('parted', '-s', "$_[0]", '--', 'mkpart', 'primary', $partedFsType, eval { int( $FIRSTSECTOR + 393216 ) } // "", q{s}, $LASTSECTOR, q{s}) >> 8;
                        $main_exit_code = system('partprobe', "$_[0]") >> 8;
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                my $tmp = do {
                $main_exit_code = system('mkfs.ext4', $mkopts{'ext4'}, "$_[0]", 'p1') >> 8;
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
                open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                my $tmp = do {
                $main_exit_code = system('mkswap', "$_[0]", 'p2') >> 8;
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
                open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                my $tmp = do {
                $main_exit_code = system('mkfs.', $eMMCFilesystemChoosen, "$_[0]", 'p3', $mkopts{$eMMCFilesystemChoosen}) >> 8;
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
                        my $emmcbootuuid;
            my @emmcbootuuid;
            my %emmcbootuuid;
            $emmcbootuuid = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_117 = q{};
                my $output_printed_117;
                my $pipeline_success_117 = 1;

                my ($in_118, $out_118);
                my $pid_118 = open3($in_118, $out_118, '>&STDERR', 'blkid', '-o', 'export', 'p1');
                close $in_118 or croak 'Close failed: $OS_ERROR';
                $output_117 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_118> };
                close $out_118 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_118, 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_117 = 0; }
                my $grep_result_117_1;
                my @grep_lines_117_1 = split /\n/msx, $output_117;
                my @grep_filtered_117_1 = grep { /UUID/msx } @grep_lines_117_1;
                $grep_result_117_1 = join "\n", @grep_filtered_117_1;
                                if (!($grep_result_117_1 =~ m{\n\z}msx || $grep_result_117_1 eq q{})) {
                                    $grep_result_117_1 .= "\n";
                                }
                $CHILD_ERROR = scalar @grep_filtered_117_1 > 0 ? 0 : 1;
                $output_117 = $grep_result_117_1;
                if ((scalar @grep_filtered_117_1) == 0) {
                    $pipeline_success_117 = 0;
                }
                if ( !$pipeline_success_117 ) { $main_exit_code = 1; }
                $output_117 =~ s/\n+\z//msx;
                $output_117;
}; $_pipeline_result; };
                        my $emmcswapuuid;
            my @emmcswapuuid;
            my %emmcswapuuid;
            $emmcswapuuid = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_119 = q{};
                my $output_printed_119;
                my $pipeline_success_119 = 1;

                my ($in_120, $out_120);
                my $pid_120 = open3($in_120, $out_120, '>&STDERR', 'blkid', '-o', 'export', 'p2');
                close $in_120 or croak 'Close failed: $OS_ERROR';
                $output_119 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_120> };
                close $out_120 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_120, 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_119 = 0; }
                my $grep_result_119_1;
                my @grep_lines_119_1 = split /\n/msx, $output_119;
                my @grep_filtered_119_1 = grep { /UUID/msx } @grep_lines_119_1;
                $grep_result_119_1 = join "\n", @grep_filtered_119_1;
                                if (!($grep_result_119_1 =~ m{\n\z}msx || $grep_result_119_1 eq q{})) {
                                    $grep_result_119_1 .= "\n";
                                }
                $CHILD_ERROR = scalar @grep_filtered_119_1 > 0 ? 0 : 1;
                $output_119 = $grep_result_119_1;
                if ((scalar @grep_filtered_119_1) == 0) {
                    $pipeline_success_119 = 0;
                }
                if ( !$pipeline_success_119 ) { $main_exit_code = 1; }
                $output_119 =~ s/\n+\z//msx;
                $output_119;
}; $_pipeline_result; };
                        my $emmcuuid;
            my @emmcuuid;
            my %emmcuuid;
            $emmcuuid = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_121 = q{};
                my $output_printed_121;
                my $pipeline_success_121 = 1;

                my ($in_122, $out_122);
                my $pid_122 = open3($in_122, $out_122, '>&STDERR', 'blkid', '-o', 'export', 'p3');
                close $in_122 or croak 'Close failed: $OS_ERROR';
                $output_121 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_122> };
                close $out_122 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_122, 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_121 = 0; }
                my $grep_result_121_1;
                my @grep_lines_121_1 = split /\n/msx, $output_121;
                my @grep_filtered_121_1 = grep { /UUID/msx } @grep_lines_121_1;
                $grep_result_121_1 = join "\n", @grep_filtered_121_1;
                                if (!($grep_result_121_1 =~ m{\n\z}msx || $grep_result_121_1 eq q{})) {
                                    $grep_result_121_1 .= "\n";
                                }
                $CHILD_ERROR = scalar @grep_filtered_121_1 > 0 ? 0 : 1;
                $output_121 = $grep_result_121_1;
                if ((scalar @grep_filtered_121_1) == 0) {
                    $pipeline_success_121 = 0;
                }
                if ( !$pipeline_success_121 ) { $main_exit_code = 1; }
                $output_121 =~ s/\n+\z//msx;
                $output_121;
}; $_pipeline_result; };
                        my $dest_root;
            my @dest_root;
            my %dest_root;
            $dest_root = $emmccheck;
        } elsif (1) {
                        $main_exit_code = system('parted', '-s', "$_[0]", '--', 'mkpart', 'primary', $partedFsType, $FIRSTSECTOR, q{s}, eval { int( $FIRSTSECTOR + $DEFAULT_BOOTSIZE_SECTORS - 1 ) } // "", q{s}) >> 8;
                        $main_exit_code = system('parted', '-s', "$_[0]", '--', 'mkpart', 'primary', $partedFsType, eval { int( $FIRSTSECTOR + $DEFAULT_BOOTSIZE_SECTORS ) } // "", q{s}, $LASTSECTOR, q{s}) >> 8;
                        $main_exit_code = system('partprobe', "$_[0]") >> 8;
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                my $tmp = do {
                $main_exit_code = system('mkfs.ext4', $mkopts{'ext4'}, "$_[0]", 'p1') >> 8;
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
                open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                my $tmp = do {
                $main_exit_code = system('mkfs.', $eMMCFilesystemChoosen, "$_[0]", 'p2', $mkopts{$eMMCFilesystemChoosen}) >> 8;
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
                        $emmcbootuuid = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_123 = q{};
                my $output_printed_123;
                my $pipeline_success_123 = 1;

                my ($in_124, $out_124);
                my $pid_124 = open3($in_124, $out_124, '>&STDERR', 'blkid', '-o', 'export', 'p1');
                close $in_124 or croak 'Close failed: $OS_ERROR';
                $output_123 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_124> };
                close $out_124 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_124, 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_123 = 0; }
                my $grep_result_123_1;
                my @grep_lines_123_1 = split /\n/msx, $output_123;
                my @grep_filtered_123_1 = grep { /UUID/msx } @grep_lines_123_1;
                $grep_result_123_1 = join "\n", @grep_filtered_123_1;
                                if (!($grep_result_123_1 =~ m{\n\z}msx || $grep_result_123_1 eq q{})) {
                                    $grep_result_123_1 .= "\n";
                                }
                $CHILD_ERROR = scalar @grep_filtered_123_1 > 0 ? 0 : 1;
                $output_123 = $grep_result_123_1;
                if ((scalar @grep_filtered_123_1) == 0) {
                    $pipeline_success_123 = 0;
                }
                if ( !$pipeline_success_123 ) { $main_exit_code = 1; }
                $output_123 =~ s/\n+\z//msx;
                $output_123;
}; $_pipeline_result; };
                        $emmcuuid = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_125 = q{};
                my $output_printed_125;
                my $pipeline_success_125 = 1;

                my ($in_126, $out_126);
                my $pid_126 = open3($in_126, $out_126, '>&STDERR', 'blkid', '-o', 'export', 'p2');
                close $in_126 or croak 'Close failed: $OS_ERROR';
                $output_125 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_126> };
                close $out_126 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_126, 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_125 = 0; }
                my $grep_result_125_1;
                my @grep_lines_125_1 = split /\n/msx, $output_125;
                my @grep_filtered_125_1 = grep { /UUID/msx } @grep_lines_125_1;
                $grep_result_125_1 = join "\n", @grep_filtered_125_1;
                                if (!($grep_result_125_1 =~ m{\n\z}msx || $grep_result_125_1 eq q{})) {
                                    $grep_result_125_1 .= "\n";
                                }
                $CHILD_ERROR = scalar @grep_filtered_125_1 > 0 ? 0 : 1;
                $output_125 = $grep_result_125_1;
                if ((scalar @grep_filtered_125_1) == 0) {
                    $pipeline_success_125 = 0;
                }
                if ( !$pipeline_success_125 ) { $main_exit_code = 1; }
                $output_125 =~ s/\n+\z//msx;
                $output_125;
}; $_pipeline_result; };
                        $dest_root = $emmccheck;
        }
}
    else {
        $main_exit_code = system('parted', '-s', "$_[0]", '--', 'mkpart', 'primary', $eMMCFilesystemChoosen, $FIRSTSECTOR, q{s}, $LASTSECTOR, q{s}) >> 8;
        $main_exit_code = system('partprobe', "$_[0]") >> 8;
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('mkfs.', $eMMCFilesystemChoosen, $mkopts{$eMMCFilesystemChoosen}, "$_[0]", 'p1') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        $emmcuuid = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_127 = q{};
            my $output_printed_127;
            my $pipeline_success_127 = 1;

            my ($in_128, $out_128);
            my $pid_128 = open3($in_128, $out_128, '>&STDERR', 'blkid', '-o', 'export', 'p1');
            close $in_128 or croak 'Close failed: $OS_ERROR';
            $output_127 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_128> };
            close $out_128 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_128, 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_127 = 0; }
            my $grep_result_127_1;
            my @grep_lines_127_1 = split /\n/msx, $output_127;
            my @grep_filtered_127_1 = grep { /UUID/msx } @grep_lines_127_1;
            $grep_result_127_1 = join "\n", @grep_filtered_127_1;
                        if (!($grep_result_127_1 =~ m{\n\z}msx || $grep_result_127_1 eq q{})) {
                            $grep_result_127_1 .= "\n";
                        }
            $CHILD_ERROR = scalar @grep_filtered_127_1 > 0 ? 0 : 1;
            $output_127 = $grep_result_127_1;
            if ((scalar @grep_filtered_127_1) == 0) {
                $pipeline_success_127 = 0;
            }
            if ( !$pipeline_success_127 ) { $main_exit_code = 1; }
            $output_127 =~ s/\n+\z//msx;
            $output_127;
}; $_pipeline_result; };
        $emmcbootuuid = $emmcuuid;
    }
    return;
}

sub format_disk {
    my ($file) = @_;
    my $IFS;
    my @IFS;
    my %IFS;
    $IFS = " ";
    my $ROOTFSTYPE;
    my @ROOTFSTYPE;
    my %ROOTFSTYPE;
    $ROOTFSTYPE = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_129 = q{};
        my $output_printed_129;
        my $pipeline_success_129 = 1;

        my ($in_130, $out_130);
        my $pid_130 = open3($in_130, $out_130, '>&STDERR', 'lsblk', '-o', 'MOUNTPOINT,FSTYPE');
        close $in_130 or croak 'Close failed: $OS_ERROR';
        $output_129 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_130> };
        close $out_130 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_130, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_129 = 0; }
        my @lines = split /\n/msx, $output_129;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\ /msx, $line;
            if (!(/^/ /)) { next; }
            push @result, ($fields[1] . "\n");
        }
        $output_129 = join "", @result;

        if ( !$pipeline_success_129 ) { $main_exit_code = 1; }
        $output_129 =~ s/\n+\z//msx;
        $output_129;
}; $_pipeline_result; };
if ($ROOTFSTYPE =~ /^btrfs$/msx) {
                my $FilesystemTargets;
        my @FilesystemTargets;
        my %FilesystemTargets;
        $FilesystemTargets = '1 btrfs';
    } elsif (1) {
                my $BTRFS;
        my @BTRFS;
        my %BTRFS;
        $BTRFS = do { my $grep_result_131;
my @grep_lines_131 = ();
my @grep_filenames_131 = ();
if (-e "/proc/filesystems") {
    open my $fh, '<', "/proc/filesystems" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_131, $line;
        push @grep_filenames_131, "/proc/filesystems";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /proc/filesystems: No such file or directory\n"; }
my @grep_filtered_131 = grep { /btrfs/msx } @grep_lines_131;
my @grep_matches_131;
foreach my $line (@grep_filtered_131) {
    if ($line =~ /(btrfs)/msx) {
        push @grep_matches_131, $1;
    }
}
$grep_result_131 = join "\n", @grep_matches_131;
$CHILD_ERROR = scalar @grep_filtered_131 > 0 ? 0 : 1;
 $grep_result_131; };
                $FilesystemTargets = '1 ext4 2 ext3 3 ext2';
                if (0) {
                        $FilesystemTargets = $FilesystemTargets;
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
    }
    my $FilesystemOptions;
    my @FilesystemOptions = ($FilesystemTargets);
    my %FilesystemOptions;
    my $FilesystemCmd;
    my @FilesystemCmd = ('dialog', '--title', 'Select filesystem type for $1', '--backtitle', $backtitle, '--menu', '\n$infos', '10', '60', '16');
    my %FilesystemCmd;
    my $FilesystemChoices;
    my @FilesystemChoices;
    my %FilesystemChoices;
    $FilesystemChoices = do { my @_qx_cmd = ("${FilesystemCmd}:@ \"${FilesystemOptions}\" 2>&1 > /dev/tty"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
    if (($? != 0)) {
        exit 10;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    my $FilesystemChoosen;
    my @FilesystemChoosen;
    my %FilesystemChoosen;
    $FilesystemChoosen = $FilesystemOptions[eval { int((2*$FilesystemChoices)-1) } // ""];
    $main_exit_code = system('dialog', '--title', "$title", '--backtitle', "$backtitle", '--infobox', "\\nFormating $_[0] to $File" . "sys" . "tem" . "Choosen ... please wait.", q{5}, '60') >> 8;
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('mkfs.', $FilesystemChoosen, $mkopts{$FilesystemChoosen}, "$_[0]") >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}

sub check_partitions {
    my $IFS;
    my @IFS;
    my %IFS;
    $IFS = " ";
    my $AvailablePartitions;
    my @AvailablePartitions;
    my %AvailablePartitions;
    $AvailablePartitions = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_132 = q{};
        my $output_printed_132;
        my $pipeline_success_132 = 1;

        my ($in_133, $out_133);
        my $pid_133 = open3($in_133, $out_133, '>&STDERR', 'lsblk', '-l');
        close $in_133 or croak 'Close failed: $OS_ERROR';
        $output_132 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_133> };
        close $out_133 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_133, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_132 = 0; }
        my @lines = split /\n/msx, $output_132;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\ /msx, $line;
            if (!(/ part | raid..? /)) { next; }
            push @result, ($fields[0] . "\n");
        }
        $output_132 = join "", @result;

        my $grep_result_132_2;
        my @grep_lines_132_2 = split /\n/msx, $output_132;
        my @grep_filtered_132_2 = grep { /^sd|^nvme|^md/msx } @grep_lines_132_2;
        $grep_result_132_2 = join "\n", @grep_filtered_132_2;
                if (!($grep_result_132_2 =~ m{\n\z}msx || $grep_result_132_2 eq q{})) {
                    $grep_result_132_2 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_132_2 > 0 ? 0 : 1;
        $output_132 = $grep_result_132_2;
        if ((scalar @grep_filtered_132_2) == 0) {
            $pipeline_success_132 = 0;
        }
        if ( !$pipeline_success_132 ) { $main_exit_code = 1; }
        $output_132 =~ s/\n+\z//msx;
        $output_132;
}; $_pipeline_result; };
if ($AvailablePartitions eq q{}) {
        $main_exit_code = system('dialog', '--title', "$title", '--backtitle', "$backtitle", '--colors', '--msgbox', "\n\Z1There are no avaliable partitions. Please create them.\Zn", q{7}, '60') >> 8;
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('apt-get', '-y', '-q', 'install', 'gdisk') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        $main_exit_code = system('gdisk', '/dev/', $diskcheck) >> 8;
    }
    $AvailablePartitions = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_134 = q{};
        my $output_printed_134;
        my $pipeline_success_134 = 1;

        my ($in_135, $out_135);
        my $pid_135 = open3($in_135, $out_135, '>&STDERR', 'lsblk', '-l');
        close $in_135 or croak 'Close failed: $OS_ERROR';
        $output_134 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_135> };
        close $out_135 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_135, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_134 = 0; }
        my @lines = split /\n/msx, $output_134;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\ /msx, $line;
            if (!(/ part | raid..? /)) { next; }
            push @result, ($fields[0] . "\n");
        }
        $output_134 = join "", @result;

        my $grep_result_134_2;
        my @grep_lines_134_2 = split /\n/msx, $output_134;
        my @grep_filtered_134_2 = grep { /^sd|^nvme|^md/msx } @grep_lines_134_2;
        $grep_result_134_2 = join "\n", @grep_filtered_134_2;
                if (!($grep_result_134_2 =~ m{\n\z}msx || $grep_result_134_2 eq q{})) {
                    $grep_result_134_2 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_134_2 > 0 ? 0 : 1;
        $output_134 = $grep_result_134_2;
        my @uniq_lines_134_3 = split /\n/msx, $output_134;
        @uniq_lines_134_3 = grep { $_ ne q{} } @uniq_lines_134_3; # Filter out empty lines
        my %uniq_seen_134_3;
        my @uniq_result_134_3;
        foreach my $line (@uniq_lines_134_3) {
        if (!$uniq_seen_134_3{$line}++) { push @uniq_result_134_3, $line; }
        }
        $output_134 = join "\n", @uniq_result_134_3;
                if ($output_134 ne q{} && !($output_134 =~ m{\n\z}msx)) {
                    $output_134 .= "\n";
                }
        my @sed_lines_134 = split /\n/msx, $output_134;
        my @sed_result_134;
        foreach my $line (@sed_lines_134) {
        chomp $line;
        push @sed_result_134, $line;
        }
        $output_134 = join "\n", @sed_result_134;


        my $cmd_137 = 'nl';
        my ($in_136, $out_136);
        my $pid_136 = open3($in_136, $out_136, '>&STDERR', $cmd_137, );
        print {$in_136} $output_134;
        close $in_136 or croak 'Close failed: $OS_ERROR';
        $output_134 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_136> };
        close $out_136 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_136, 0;
        my @xargs_input_134_6 = grep { $_ ne q{} } split /\s+/msx, $output_134;
        my @xargs_output_134_6;
        for my $i (0..scalar @xargs_input_134_6-1) {
            my @xargs_args_134_6;
            for my $j (0..1-1) {
                push @xargs_args_134_6, $xargs_input_134_6[$i + $j];
            }
            my $xargs_line_134_6 = q{};
            $xargs_line_134_6 .= "-n";
            foreach my $arg (@xargs_args_134_6) {
                $xargs_line_134_6 .= q{ } . $arg;
            }
            push @xargs_output_134_6, $xargs_line_134_6;
        }
        my $xargs_result_134_6 = join "\n", @xargs_output_134_6;
        if ($xargs_result_134_6 ne q{} && !( $xargs_result_134_6 =~ m{\n\z}msx )) { $xargs_result_134_6 .= "\n"; }
        $output_134 = $xargs_result_134_6;

        if ( !$pipeline_success_134 ) { $main_exit_code = 1; }
        $output_134 =~ s/\n+\z//msx;
        $output_134;
}; $_pipeline_result; };
    my $PartitionOptions;
    my @PartitionOptions = ($AvailablePartitions);
    my %PartitionOptions;
    my $PartitionCmd;
    my @PartitionCmd = ('dialog', '--title', 'Select destination:', '--backtitle', $backtitle, '--menu', '\n$infos', '10', '60', '16');
    my %PartitionCmd;
    my $PartitionChoices;
    my @PartitionChoices;
    my %PartitionChoices;
    $PartitionChoices = do { my @_qx_cmd = ("${PartitionCmd}:@ \"${PartitionOptions}\" 2>&1 > /dev/tty"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
    if (($? != 0)) {
        exit 11;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    my $DISK_ROOT_PART;
    my @DISK_ROOT_PART;
    my %DISK_ROOT_PART;
    $DISK_ROOT_PART = $PartitionOptions[eval { int((2*$PartitionChoices)-1) } // ""];
    return;
}

sub update_bootscript {
if ((-f '/boot/boot.cmd.new')) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            my $err;
            my $force = 1;
            if ( -e '/boot/boot.cmd.new' ) {
                my $dest = '/boot/boot.cmd';
                if ( -e $dest && -d $dest ) {
                    my $source_name = '/boot/boot.cmd.new';
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
                if ( File::Copy::move( '/boot/boot.cmd.new', $dest ) ) {
                } else {
                    croak
  "mv: cannot move '/boot/boot.cmd.new' to $dest: $ERRNO\n";
                }
            } else {
                croak "mv: '/boot/boot.cmd.new': No such file or directory\n";
            }
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
            $main_exit_code = system('mkimage', '-C', 'none', '-A', 'arm', '-T', 'script', '-d', '/boot/boot.cmd', '/boot/boot.scr') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
}
    else {
        if ((-f '/boot/boot.ini.new')) {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                my $tmp = do {
                if ( -e '/boot/boot.ini.new' ) {
                    my $dest = '/boot/boot.ini';
                    if ( -e $dest && -d $dest ) {
                        my $source_name = '/boot/boot.ini.new';
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
                    if ( File::Copy::move( '/boot/boot.ini.new', $dest ) ) {
                    } else {
                        croak
  "mv: cannot move '/boot/boot.ini.new' to $dest: $ERRNO\n";
                    }
                } else {
                    croak "mv: '/boot/boot.ini.new': No such file or directory\n";
                }
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            my $rootdev;
            my @rootdev;
            my %rootdev;
            $rootdev = do { my @_qx_cmd = ("sed -e 's/^.*root=//' -e 's/ .*$//' < /proc/cmdline"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
            my $rootfstype;
            my @rootfstype;
            my %rootfstype;
            $rootfstype = do { my @_qx_cmd = ("sed -e 's/^.*rootfstype=//' -e 's/ .*$//' < /proc/cmdline"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
my @sed_lines_140 = split /\n/msx, $;
my @sed_result_140;
foreach my $line (@sed_lines_140) {
chomp $line;
push @sed_result_140, $line;
}
$ = join "\n", @sed_result_140;

my @sed_lines_141 = split /\n/msx, $;
my @sed_result_141;
foreach my $line (@sed_lines_141) {
chomp $line;
push @sed_result_141, $line;
}
$ = join "\n", @sed_result_141;

        }
    }
    return;
}

sub show_warning {
    my ($file) = @_;
    $main_exit_code = system('dialog', '--title', "$title", '--backtitle', "$backtitle", '--cr-wrap', '--colors', '--yesno', " \Z1" . (do { my $_chomp_temp = do {
    my ($in_142, $out_142);
    my $pid_142 = open3($in_142, $out_142, '>&STDERR', 'toilet', '-W', '-f', 'ascii9', ' WARNING');
    close $in_142 or croak 'Close failed: $OS_ERROR';
    my $result_142 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_142> };
    close $out_142 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_142, 0;
    $result_142
}; chomp $_chomp_temp; $_chomp_temp; }) . "\Zn\n$_[0]", '16', '67') >> 8;
    if (($? != 0)) {
        exit 13;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    return;
}

sub stop_running_services {
    my ($file) = @_;
    # Original bash: systemctl --state=running | awk -F" " '/.service/ {print $1}' | sort -r | \
{
        my $output_143 = q{};
        my $output_printed_143;
        my $pipeline_success_143 = 1;
                my ($in_144, $out_144);
        my $pid_144 = open3($in_144, $out_144, '>&STDERR', 'systemctl', '--state=running');
        close $in_144 or croak 'Close failed: $OS_ERROR';
        $output_143 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_144> };
        close $out_144 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_144, 0;

                my @lines = split /\n/msx, $output_143;
        my @result;
        foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /^\s*$/msx) { next; }
        my @fields = split /\ /msx, $line;
        if (!(/.service/)) { next; }
        push @result, ($fields[0] . "\n");
        }
        $output_143 = join "", @result;

                my @sort_lines_143_2 = split /\n/msx, $output_143;
        my @sort_sorted_143_2 = sort @sort_lines_143_2;
        @sort_sorted_143_2 = reverse @sort_sorted_143_2;
        my $output_143_2 = join "\n", @sort_sorted_143_2;
        if ($output_143_2 ne q{} && !($output_143_2 =~ m{\n\z}msx)) {
        $output_143_2 .= "\n";
        }
        $output_143 = $output_143_2;
        $output_143 = $output_143_2;

                my $grep_result_143_3;
        my @grep_lines_143_3 = split /\n/msx, $output_143;
        my @grep_filtered_143_3 = grep { /$_[0]/msx } @grep_lines_143_3;
        $grep_result_143_3 = join "\n", @grep_filtered_143_3;
        if (!($grep_result_143_3 =~ m{\n\z}msx || $grep_result_143_3 eq q{})) {
        $grep_result_143_3 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_143_3 > 0 ? 0 : 1;
        $output_143 = $grep_result_143_3;
        $output_143 = $grep_result_143_3;

                my @lines = split /\n/msx, $output_143;
        my $result_143_4 = q{};
        for my $line (@lines) {
        chomp $line;
        my $L = $line;
        do {
        my $__echo_line = "\nStopping ($ENV{REPLY} // q{}) \\c";
        if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        $__echo_line .= "\n";
        }
        $output .= $__echo_line;
        };
        $CHILD_ERROR = 0;
        do {
        local *STDERR;
        open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp_redirect_145 = q{};
        my $cmd_148 = 'systemctl';
        my ($in_147, $out_147);
        my $pid_147 = open3($in_147, $out_147, '>&STDERR', $cmd_148, 'stop');
        print {$in_147} $output_143;
        close $in_147 or croak 'Close failed: $OS_ERROR';
        $tmp_redirect_145 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_147> };
        close $out_147 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_147, 0;
        $tmp_redirect_145;
        };
        }
        $output_143 = $result_143_4;
        if ($output_143 ne q{} && !defined $output_printed_143) {
            print $output_143;
            if (!($output_143 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_143 ) { $main_exit_code = 1; }
        }
    return;
}

sub write_uboot_to_spi_flash {
    my $MTD_BLK = "/dev/$_[0]";
    my $DIR = "$_[1]";
    my $MESSAGE = "This script will update the bootloader on SPI Flash $MTD_BLK. Continue?\nIt will take up to a few minutes.";
    $main_exit_code = system('dialog', '--title', "$title", '--backtitle', "$backtitle", '--cr-wrap', '--colors', '--yesno', " \Z1" . (do { my $_chomp_temp = do {
    my ($in_149, $out_149);
    my $pid_149 = open3($in_149, $out_149, '>&STDERR', 'toilet', '-W', '-f', 'ascii9', ' WARNING');
    close $in_149 or croak 'Close failed: $OS_ERROR';
    my $result_149 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_149> };
    close $out_149 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_149, 0;
    $result_149
}; chomp $_chomp_temp; $_chomp_temp; }) . "\Zn\n$MESSAGE", '16', '67') >> 8;
if (($? == 0)) {
        $main_exit_code = system('write_uboot_platform_mtd', "$DIR", $MTD_BLK) >> 8;
        update_bootscript();
        print 'Done' . "\n";
        $CHILD_ERROR = 0;
    }
    return;
}

sub main {
$ENV{PATH} = '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin';
if (($EUID != 0)) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print 'This tool must run as root. Exiting ...' . "\n";
            $CHILD_ERROR = 0;
        };
exit 14;
    }
    if ((-f $logfile)) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
            print "\n\n\n" . "\n";
            $CHILD_ERROR = 0;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
        my $LANG = q{C};
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $logfile
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "do {\nrequire POSIX; POSIX::strftime('%a %b %e %H:%M:%S %Z %Y', localtime(time())) . \"\\n\"\n}: Start basename($_[0]).\n";
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
    my $IFS;
    my @IFS;
    my %IFS;
    $IFS = "'";
    my $options;
    my @options = ();
    my %options;
if ($emmccheck ne q{}) {
        my $ichip;
        my @ichip;
        my %ichip;
        $ichip = 'eMMC';
        my $dest_boot;
        my @dest_boot;
        my %dest_boot;
        $dest_boot = $emmccheck;
        my $dest_root;
        my @dest_root;
        my %dest_root;
        $dest_root = $emmccheck;
}
    else {
        $ichip = 'NAND';
        $dest_boot = '/dev/nand1';
        $dest_root = '/dev/nand2';
    }
    my $choices;
    my @choices;
    my %choices;
    $choices = q{2};
    my $choice;
    for my $choice ($choices) {
if ($choice =~ /^1$/msx) {
                        $title = 'MMC (SD/eMMC) boot | USB/SATA/NVMe root install';
                        my $command;
            my @command;
            my %command;
            $command = 'Reboot';
                        check_partitions();
                        show_warning("This script will erase your device $ENV{DISK_ROOT_PART}. Continue?");
                        format_disk("$ENV{DISK_ROOT_PART}");
                        create_orangepi("", "$ENV{DISK_ROOT_PART}");
        } elsif ($choice =~ /^2$/msx) {
                        $title = "$ichip install";
                        $command = 'Power off';
            if ($emmccheck ne q{}) {
                umount_device("$emmccheck");
                format_emmc("$emmccheck");
}
            else {
                umount_device('/dev/nand');
                format_nand();
            }
                        create_orangepi("$dest_boot", "$dest_root");
        } elsif ($choice =~ /^3$/msx) {
                        $title = "$ichip boot | USB/SATA/NVMe root install";
                        $command = 'Power off';
                        check_partitions();
                        show_warning("This script will erase your $ichip and $ENV{DISK_ROOT_PART}. Continue?");
            if ($emmccheck ne q{}) {
                umount_device("$emmccheck");
                format_emmc("$emmccheck");
}
            else {
                umount_device('/dev/nand');
                format_nand();
            }
                        umount_device(($ENV{DISK_ROOT_PART} // q{}) =~ s/\[0-9\]\*//grs);
                        format_disk("$ENV{DISK_ROOT_PART}");
                        create_orangepi("$dest_boot", "$ENV{DISK_ROOT_PART}");
        } elsif ($choice =~ /^4$/msx) {
                        $title = 'SPI flash boot | USB/SATA/NVMe root install';
                        $command = 'Power off';
            my @sed_lines_150 = split /\n/msx, $;
my @sed_result_150;
foreach my $line (@sed_lines_150) {
chomp $line;
push @sed_result_150, $line;
}
$ = join "\n", @sed_result_150;

                        check_partitions();
                        show_warning("This script will erase your device $ENV{DISK_ROOT_PART}. Continue?");
                        format_disk("$ENV{DISK_ROOT_PART}");
                        create_orangepi('spi', "$ENV{DISK_ROOT_PART}");
            if ($(type -t write_uboot_platform_mtd) =~ /^function$/msx) {
                $main_exit_code = system('dialog', '--title', "$title", '--backtitle', "$backtitle", '--yesno', "Do you want to write the bootloader to SPI flash?\n\nIt is required if you have not done it before or if you have some non-OrangePi bootloader in SPI.", q{8}, '60') >> 8;
if (($? == 0)) {
                    write_uboot_to_spi_flash($spicheck, "$ENV{DIR}");
                }
            }
        } elsif ($choice =~ /^5$/msx) {
                        for my $file (glob('This script will update the bootloader on SD/eMMC. Continue?')) {
                show_warning($file);
            }
                        $main_exit_code = system('write_uboot_platform', "$ENV{DIR}", ${root_partition_device}) >> 8;
                        update_bootscript();
                        $main_exit_code = system('dialog', '--backtitle', "$backtitle", '--title', 'Writing bootloader', '--msgbox', "\\n          Done.", q{7}, '30') >> 8;
            return;        } elsif ($choice =~ /^6$/msx) {
            if (( -b /dev/mmcblk0boot0)) {
                my $BOOTPART;
                my @BOOTPART;
                my %BOOTPART;
                $BOOTPART = '/dev/mmcblk0';
}
            else {
                if (( -b /dev/mmcblk1boot0)) {
                    $BOOTPART = '/dev/mmcblk1';
                }
            }
                        show_warning("This script will update the bootloader on $BOOTPART. Continue?");
                        $main_exit_code = system('write_uboot_platform', "$ENV{DIR}", $BOOTPART) >> 8;
                        print 'Done' . "\n";
            $CHILD_ERROR = 0;
            return;        } elsif ($choice =~ /^7$/msx) {
                        write_uboot_to_spi_flash($spicheck, "$ENV{DIR}");
            return;        }
    }
    $main_exit_code = system('bash', 'poweroff') >> 8;
    return;
}
main("@ARGV");

exit $main_exit_code;
