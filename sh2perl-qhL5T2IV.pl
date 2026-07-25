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

my $quiet;
my @quiet;
my %quiet;
my $ADDITIONAL_PROFILE_DIR;
my @ADDITIONAL_PROFILE_DIR;
my %ADDITIONAL_PROFILE_DIR;
my $QUIET;
my @QUIET;
my %QUIET;

my $PARSER;
my @PARSER;
my %PARSER;
$PARSER = '/sbin/apparmor_parser';
my $PARSER_OPTS;
my @PARSER_OPTS;
my %PARSER_OPTS;
$PARSER_OPTS = '--write-cache';
if (("${QUIET:-no}" eq yes || "${quiet:-n}" eq y)) {
    $PARSER_OPTS = "$PARSER_OPTS --quiet";
}
if ((-d '/etc/apparmor.d')) {
    my $PROFILE_DIRS;
    my @PROFILE_DIRS;
    my %PROFILE_DIRS;
    $PROFILE_DIRS = '/etc/apparmor.d';
}
else {
    $main_exit_code = system('aa_log_warning_msg', "Unable to find profiles directory, installation problem?") >> 8;
}
$ADDITIONAL_PROFILE_DIR = q{};
if (("$ADDITIONAL_PROFILE_DIR" ne q{} && (-d "$ADDITIONAL_PROFILE_DIR"))) {
    $PROFILE_DIRS = "$PROFILE_DIRS $ADDITIONAL_PROFILE_DIR";
}
my $AA_STATUS;
my @AA_STATUS;
my %AA_STATUS;
$AA_STATUS = '/usr/sbin/aa-status';
my $SECURITYFS;
my @SECURITYFS;
my %SECURITYFS;
$SECURITYFS = '/sys/kernel/security';
my $SFS_MOUNTPOINT;
my @SFS_MOUNTPOINT;
my %SFS_MOUNTPOINT;
$SFS_MOUNTPOINT = ${SECURITYFS} . "/apparmor";
my $STATUS;
my @STATUS;
my %STATUS;
$STATUS = q{0};

sub is_apparmor_present {
(-d '/sys/module/apparmor')
    return;
}

sub is_container_with_internal_policy {
    my $ns_stacked_path = ${SFS_MOUNTPOINT} . "/.ns_stacked";
    my $ns_name_path = ${SFS_MOUNTPOINT} . "/.ns_name";
    my $ns_stacked;
    my $ns_name;
if (((-x '/usr/bin/systemd-detect-virt') && "$(systemd-detect-virt --container)" eq "wsl")) {
return q{0};
    }
if (!(!(if (!((-f "$ns_stacked_path"))) {
        !((-f "$ns_name_path"))
    }))) {
return q{1};
    }
open STDIN, '<', "$ns_stacked_path" or croak "Cannot open file: $OS_ERROR\n";
$ns_stacked = <>;
chomp $ns_stacked;
$CHILD_ERROR = defined($ns_stacked) ? 0 : 1;
if ("$ns_stacked" ne "yes") {
return q{1};
    }
open STDIN, '<', "$ns_name_path" or croak "Cannot open file: $OS_ERROR\n";
$ns_name = <>;
chomp $ns_name;
$CHILD_ERROR = defined($ns_name) ? 0 : 1;
if ((("${ns_name#lxd-*}" eq "$ns_name" && "${ns_name#incus-*}" eq "$ns_name") && "${ns_name#lxc-*}" eq "$ns_name")) {
return q{1};
    }
return q{0};
    return;
}

sub __parse_profiles_dir {
    my $parser_cmd = "$_[0]";
    my $profile_dir = "$_[1]";
    my $status = "0";
if ((!-d "$profile_dir")) {
        $main_exit_code = system('aa_log_failure_msg', "Profile directory not found: $profile_dir") >> 8;
return q{1};
    }
if ("$(ls "$profile_dir"/)" eq q{}) {
        $main_exit_code = system('aa_log_failure_msg', "No profiles found in $profile_dir") >> 8;
return q{1};
    }
if (!(!($CHILD_ERROR = 0;))) {
        $status = q{1};
        $main_exit_code = system('aa_log_failure_msg', "At least one profile failed to load") >> 8;
    }
return "$status";
    return;
}

sub check_userns {
    my $userns_restricted;
    my @userns_restricted;
    my %userns_restricted;
    $userns_restricted = do {
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'sysctl', '-n', 'kernel.apparmor_restrict_unprivileged_userns');
    close $in_2 or croak 'Close failed: $OS_ERROR';
    my $result_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    $result_2
};
    my $unconfined_userns;
    my @unconfined_userns;
    my %unconfined_userns;
    $unconfined_userns = do {
    my $command = q{: 'Complex command not supported in bash string generation' && cat /sys/kernel/security/apparmor/features/policy/unconfined_restrictions/userns || echo 0};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
};
if (("$userns_restricted" ne q{} && ($userns_restricted == 1))) {
if (($unconfined_userns == 0)) {
            $main_exit_code = system('aa_action', "disabling unprivileged userns restrictions since unconfined userns is not supported / enabled", 'sysctl', '-w', 'kernel.apparmor_restrict_unprivileged_userns', q{=}, q{0}) >> 8;
        }
    }
    return;
}

sub parse_profiles {
    check_userns();
if ("$_[0]" =~ /^load$/msx) {
                my $PARSER_CMD;
        my @PARSER_CMD;
        my %PARSER_CMD;
        $PARSER_CMD = "--add";
                my $PARSER_MSG;
        my @PARSER_MSG;
        my %PARSER_MSG;
        $PARSER_MSG = "Loading AppArmor profiles ";
    } elsif ("$_[0]" =~ /^reload$/msx) {
                $PARSER_CMD = "--replace";
                $PARSER_MSG = "Reloading AppArmor profiles ";
    } elsif (1) {
                $main_exit_code = system('aa_log_failure_msg', "required 'load' or 'reload'") >> 8;
        exit 1;
    }
    $main_exit_code = system('aa_log_action_start', "$PARSER_MSG") >> 8;
if ((!-f "$PARSER")) {
        $main_exit_code = system('aa_log_failure_msg', "AppArmor parser not found") >> 8;
exit 1;
    }
    my $profile_dir;
    for my $profile_dir ($PROFILE_DIRS) {
                __parse_profiles_dir("$PARSER_CMD", "$profile_dir");
        if ($CHILD_ERROR != 0) {
                        $STATUS = $?;
        }
    }
    $main_exit_code = system('aa_log_action_end', "$STATUS") >> 8;
return "$STATUS";
    return;
}

sub is_apparmor_loaded {
if (!(!($main_exit_code = system('bash', 'is_securityfs_mounted') >> 8;))) {
        $main_exit_code = system('bash', 'mount_securityfs') >> 8;
    }
if ((-f "${SFS_MOUNTPOINT}/profiles")) {
return q{0};
    }
    is_apparmor_present();
return $?;
    return;
}

sub is_securityfs_mounted {
    if (do {
$main_exit_code = system('test', '-d', "$SECURITYFS", '-a', '-d', "/sys/fs/cgroup/" . "sys" . "tem" . "d") >> 8;
if ($CHILD_ERROR != 0) {
    my $grep_result_3;
my @grep_lines_3 = ();
my @grep_filenames_3 = ();
if (-e "/proc/filesystems") {
    open my $fh, '<', "/proc/filesystems" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_3, $line;
        push @grep_filenames_3, "/proc/filesystems";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /proc/filesystems: No such file or directory\n"; }
my @grep_filtered_3 = grep { /securityfs/msx } @grep_lines_3;
$grep_result_3 = join "\n", @grep_filtered_3;
    if (!($grep_result_3 =~ m{\n\z}msx || $grep_result_3 eq q{})) {
        $grep_result_3 .= "\n";
    }
$CHILD_ERROR = scalar @grep_filtered_3 > 0 ? 0 : 1;
$grep_result_3 = q{};
}
        $CHILD_ERROR == 0
    }) {
        my $grep_result_4;
my @grep_lines_4 = ();
my @grep_filenames_4 = ();
if (-e "/proc/mounts") {
    open my $fh, '<', "/proc/mounts" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_4, $line;
        push @grep_filenames_4, "/proc/mounts";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /proc/mounts: No such file or directory\n"; }
my @grep_filtered_4 = grep { /securityfs/msx } @grep_lines_4;
$grep_result_4 = join "\n", @grep_filtered_4;
        if (!($grep_result_4 =~ m{\n\z}msx || $grep_result_4 eq q{})) {
            $grep_result_4 .= "\n";
        }
$CHILD_ERROR = scalar @grep_filtered_4 > 0 ? 0 : 1;
$grep_result_4 = q{};
    }
return $?;
    return;
}

sub mount_securityfs {
if (!(my $grep_result_5;
my @grep_lines_5 = ();
my @grep_filenames_5 = ();
if (-e "/proc/filesystems") {
    open my $fh, '<', "/proc/filesystems" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_5, $line;
        push @grep_filenames_5, "/proc/filesystems";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /proc/filesystems: No such file or directory\n"; }
my @grep_filtered_5 = grep { /securityfs/msx } @grep_lines_5;
$grep_result_5 = join "\n", @grep_filtered_5;
    if (!($grep_result_5 =~ m{\n\z}msx || $grep_result_5 eq q{})) {
        $grep_result_5 .= "\n";
    }
$CHILD_ERROR = scalar @grep_filtered_5 > 0 ? 0 : 1;
$grep_result_5 = q{})) {
        $main_exit_code = system('aa_action', "Mounting securityfs on $SECURITYFS", 'mount', '-t', 'securityfs', 'securityfs', "$SECURITYFS") >> 8;
return $?;
    }
return q{0};
    return;
}

sub apparmor_start {
    $main_exit_code = system('aa_log_daemon_msg', "Starting AppArmor") >> 8;
if (!(!(is_apparmor_present();))) {
        $main_exit_code = system('aa_log_failure_msg', "Starting AppArmor - failed, To enable AppArmor, ensure your kernel is configured with CONFIG_SECURITY_APPARMOR=y then add 'security=apparmor apparmor=1' to the kernel command line") >> 8;
        $main_exit_code = system('aa_log_end_msg', q{1}) >> 8;
return q{1};
}
    else {
        if (!(!(is_apparmor_loaded();))) {
            $main_exit_code = system('aa_log_failure_msg', "Starting AppArmor - AppArmor control files aren't available under /sys/kernel/security/, please make sure securityfs is mounted.") >> 8;
            $main_exit_code = system('aa_log_end_msg', q{1}) >> 8;
return q{1};
        }
    }
if ((!-w "$SFS_MOUNTPOINT/.load")) {
        $main_exit_code = system('aa_log_failure_msg', "Loading AppArmor profiles - failed, Do you have the correct privileges?") >> 8;
        $main_exit_code = system('aa_log_end_msg', q{1}) >> 8;
return q{1};
    }
if (!(!(open STDIN, '<', "$SFS_MOUNTPOINT/profiles" or croak "Cannot open file: $OS_ERROR\n";
$_ = <>;
chomp $_;
$CHILD_ERROR = defined($_) ? 0 : 1;))) {
        parse_profiles('load');
}
    else {
        $main_exit_code = system('aa_log_skipped_msg', ": already loaded with profiles.") >> 8;
return q{0};
    }
    $main_exit_code = system('aa_log_end_msg', q{0}) >> 8;
return q{0};
    return;
}

sub remove_profiles {
if (!(!(is_apparmor_loaded();))) {
        $main_exit_code = system('aa_log_failure_msg', "AppArmor module is not loaded") >> 8;
return q{1};
    }
if ((!-w "$SFS_MOUNTPOINT/.remove")) {
        $main_exit_code = system('aa_log_failure_msg', "Root privileges not available") >> 8;
return q{1};
    }
if ((!-x "$PARSER")) {
        $main_exit_code = system('aa_log_failure_msg', "Unable to execute AppArmor parser") >> 8;
return q{1};
    }
    my $retval;
    my @retval;
    my %retval;
    $retval = q{0};
    # Original bash: sed -e "s/ (\(enforce\|complain\))$//" "$SFS_MOUNTPOINT/profiles" | \
{
        my $output_7 = q{};
        my $output_printed_7;
        my $pipeline_success_7 = 1;
                my @sed_lines_7 = split /\n/msx, $;
        my @sed_result_7;
        foreach my $line (@sed_lines_7) {
        chomp $line;
        push @sed_result_7, $line;
        }
        $ = join "\n", @sed_result_7;

                my @sort_lines_7_1 = split /\n/msx, $output_7;
        my @sort_sorted_7_1 = sort @sort_lines_7_1;
        my $output_7_1 = join "\n", @sort_sorted_7_1;
        if ($output_7_1 ne q{} && !($output_7_1 =~ m{\n\z}msx)) {
        $output_7_1 .= "\n";
        }
        $output_7 = $output_7_1;
        $output_7 = $output_7_1;

                my $grep_result_7_2;
        my @grep_lines_7_2 = split /\n/msx, $output_7;
        my @grep_filtered_7_2 = grep { !/\/\//msx } @grep_lines_7_2;
        $grep_result_7_2 = join "\n", @grep_filtered_7_2;
        if (!($grep_result_7_2 =~ m{\n\z}msx || $grep_result_7_2 eq q{})) {
        $grep_result_7_2 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_7_2 > 0 ? 0 : 1;
        $output_7 = $grep_result_7_2;
        $output_7 = $grep_result_7_2;

                my @_pcmd_9 = ('bash', '-c', "echo \"${output_7}\" | : \"Complex command cannot be converted to shell command\"");
        my ($in_8);
        my $pid_8 = open3($in_8, $out_8, '>&STDERR', @_pcmd_9);
        close $in_8 or croak 'Close failed: $OS_ERROR';
        my $temp_result;
        $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_8> };
        $output_7 = $temp_result;
        close $out_8 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_8, 0;
        if ($output_7 ne q{} && !defined $output_printed_7) {
            print $output_7;
            if (!($output_7 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_7 ) { $main_exit_code = 1; }
        }
    return;
}

sub apparmor_stop {
    $main_exit_code = system('aa_log_daemon_msg', "Unloading AppArmor profiles") >> 8;
    remove_profiles();
    my $rc;
    my @rc;
    my %rc;
    $rc = $?;
    $main_exit_code = system('aa_log_end_msg', "$rc") >> 8;
return "$rc";
    return;
}

sub apparmor_kill {
if (!(!(is_apparmor_loaded();))) {
        $main_exit_code = system('aa_log_failure_msg', "AppArmor module is not loaded") >> 8;
return q{1};
    }
    $main_exit_code = system('aa_log_failure_msg', "apparmor_kill() is no longer supported because AppArmor can't be built as a module") >> 8;
return q{1};
    return;
}

sub __apparmor_restart {
if ((!-w "$SFS_MOUNTPOINT/.load")) {
        $main_exit_code = system('aa_log_failure_msg', "Loading AppArmor profiles - failed, Do you have the correct privileges?") >> 8;
return q{4};
    }
    $main_exit_code = system('aa_log_daemon_msg', "Restarting AppArmor") >> 8;
    parse_profiles('reload');
    my $rc;
    my @rc;
    my %rc;
    $rc = $?;
    $main_exit_code = system('aa_log_end_msg', "$rc") >> 8;
return "$rc";
    return;
}

sub apparmor_restart {
if (!(!(is_apparmor_loaded();))) {
        apparmor_start();
        my $rc;
        my @rc;
        my %rc;
        $rc = $?;
return "$rc";
    }
    __apparmor_restart();
return $?;
    return;
}

sub apparmor_try_restart {
if (!(!(is_apparmor_loaded();))) {
return q{0};
    }
    __apparmor_restart();
return $?;
    return;
}

sub apparmor_status {
if ((-x 'StringInterpolation(StringInterpolation { parts: [Variable("AA_STATUS")] }, None)')) {
        $CHILD_ERROR = 0;
return $?;
    }
if (!(!(is_apparmor_loaded();))) {
        print "AppArmor is not loaded.\n";
        my $rc;
        my @rc;
        my %rc;
        $rc = q{1};
}
    else {
        print "AppArmor is enabled.\n";
        $rc = q{0};
    }
    print "Install the apparmor-utils package to receive more detailed\n";
    do {
    my $__echo_line = "status information here (or examine $SFS_MOUNTPOINT directly).";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
return "$rc";
    return;
}

exit $main_exit_code;
