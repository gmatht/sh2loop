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

my $NVIDIA_VISIBLE_DEVICES+x;
my @NVIDIA_VISIBLE_DEVICES+x;
my %NVIDIA_VISIBLE_DEVICES+x;
my $CLI_LOAD_KMODS;
my @CLI_LOAD_KMODS;
my %CLI_LOAD_KMODS;
my $CUDA_VERSION;
my @CUDA_VERSION;
my %CUDA_VERSION;
my $LXC_LOG_LEVEL;
my @LXC_LOG_LEVEL;
my %LXC_LOG_LEVEL;
my $NVIDIA_DISABLE_REQUIRE;
my @NVIDIA_DISABLE_REQUIRE;
my %NVIDIA_DISABLE_REQUIRE;
my $CLI_LDCONFIG;
my @CLI_LDCONFIG;
my %CLI_LDCONFIG;
my $CLI_ROOT;
my @CLI_ROOT;
my %CLI_ROOT;
my $HOOK_SECTION;
my @HOOK_SECTION;
my %HOOK_SECTION;
my $CLI_LDCACHE;
my @CLI_LDCACHE;
my %CLI_LDCACHE;
my $CLI_DEVICES;
my @CLI_DEVICES;
my %CLI_DEVICES;
my $NVIDIA_REQUIRE_CUDA;
my @NVIDIA_REQUIRE_CUDA;
my %NVIDIA_REQUIRE_CUDA;
my $CLI_CAPABILITIES;
my @CLI_CAPABILITIES;
my %CLI_CAPABILITIES;
my $CLI_DISABLE_REQUIRE;
my @CLI_DISABLE_REQUIRE;
my %CLI_DISABLE_REQUIRE;
my $NVIDIA_DRIVER_CAPABILITIES;
my @NVIDIA_DRIVER_CAPABILITIES;
my %NVIDIA_DRIVER_CAPABILITIES;
my $CLI_DEBUG;
my @CLI_DEBUG;
my %CLI_DEBUG;
my $NVIDIA_VISIBLE_DEVICES;
my @NVIDIA_VISIBLE_DEVICES;
my %NVIDIA_VISIBLE_DEVICES;
my $NVIDIA_VISIBLE_DEVICES-x;
my @NVIDIA_VISIBLE_DEVICES-x;
my %NVIDIA_VISIBLE_DEVICES-x;
my $USERNS;
my @USERNS;
my %USERNS;
my $HOOK_TYPE;
my @HOOK_TYPE;
my %HOOK_TYPE;

$__set_e = 1;
# set u not implemented
if (("${NVIDIA_VISIBLE_DEVICES-x}" eq q{} || "${NVIDIA_VISIBLE_DEVICES:-}" eq "void")) {
exit 0;
}
if (("${CUDA_VERSION:-}" ne q{} && "${NVIDIA_REQUIRE_CUDA:-}" eq q{})) {
if ("${NVIDIA_VISIBLE_DEVICES+x}" eq q{}) {
        $NVIDIA_VISIBLE_DEVICES = "all";
    }
if ("${NVIDIA_DRIVER_CAPABILITIES:-}" eq q{}) {
        $NVIDIA_DRIVER_CAPABILITIES = "all";
    }
if ("${CUDA_VERSION}" =~ /^[0-9]+[.][0-9]+/msx) {
        $NVIDIA_REQUIRE_CUDA = "cuda>=" . $BASH_REMATCH[0];
    }
}
else {
if ("${NVIDIA_VISIBLE_DEVICES+x}" eq q{}) {
exit 0;
    }
}
$ENV{PATH} = '$PATH';
$ENV{:/usr/sbin:/usr/bin:/sbin:/bin} = $:/usr/sbin:/usr/bin:/sbin:/bin;
if (!(!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('command', '-v', 'nvidia-container-cli') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};))) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "ERROR: Missing tool nvidia-container-cli, see https://github.com/NVIDIA/libnvidia-container\n";
    };
exit 1;
}

sub in_userns {
    if (!((-e '/proc/self/uid_map'))) {
                    print 'no' . "\n";
            $CHILD_ERROR = 0;
return;
    }
open STDIN, '<', '/proc/self/uid_map' or croak "Cannot open file: $OS_ERROR\n";
    my $line;
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $line = $_fields[0] // q{};
        my $fields;
        my @fields;
        my %fields;
        $fields = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_0 = q{};
            my $output_printed_0;
            my $pipeline_success_0 = 1;
            $output_0 .= $line . "\n";
            if ( !($output_0 =~ m{\n\z}msx) ) { $output_0 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
            my @lines = split /\n/msx, $output_0;
            my @result;
            foreach my $line (@lines) {
                chomp $line;
                if ($line =~ /^\s*$/msx) { next; }
                my @fields = split /\s+/msx, $line;
                push @result, ($fields[0] . " " . $fields[1] . " " . $fields[2] . "\n");
            }
            $output_0 = join "", @result;

            if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            $output_0 =~ s/\n+\z//msx;
            $output_0;
}; $_pipeline_result; };
                if ("$fields" eq "0 0 4294967295") {
                            print 'no' . "\n";
                $CHILD_ERROR = 0;
return;
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ($CHILD_ERROR != 0) {
            1;
        }
                if (do {
{
    my $output_2 = q{};
    my $output_printed_2;
    my $pipeline_success_2 = 1;
    $output_2 .= $fields . "\n";
if ( !($output_2 =~ m{\n\z}msx) ) { $output_2 .= "\n"; }
$CHILD_ERROR = 0;

        my $grep_result_2_1;
    my @grep_lines_2_1 = split /\n/msx, $output_2;
    my @grep_filtered_2_1 = grep { /\ 0\ 1$/msx } @grep_lines_2_1;
    $grep_result_2_1 = join "\n", @grep_filtered_2_1;
    if (!($grep_result_2_1 =~ m{\n\z}msx || $grep_result_2_1 eq q{})) {
    $grep_result_2_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_2_1 > 0 ? 0 : 1;
    $grep_result_2_1 = q{};
    $output_2 = q{};
    if ((scalar @grep_filtered_2_1) == 0) {
        $pipeline_success_2 = 0;
    }
    if ($output_2 ne q{} && !defined $output_printed_2) {
        print $output_2;
        if (!($output_2 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
    }
            $CHILD_ERROR == 0
        }) {
                            print 'userns-root' . "\n";
                $CHILD_ERROR = 0;
return;
        }
        if ($CHILD_ERROR != 0) {
            1;
        }
    }
if ((-e '/proc/1/uid_map')) {
if ("$(cat /proc/self/uid_map)" eq "$(cat /proc/1/uid_map)") {
            print 'userns-root' . "\n";
            $CHILD_ERROR = 0;
return;
        }
    }
    print 'yes' . "\n";
    $CHILD_ERROR = 0;
    return;
}

sub get_ldconfig {
        $main_exit_code = system('command', '-v', "ldconfig.real") >> 8;
    if ($CHILD_ERROR != 0) {
                $main_exit_code = system('command', '-v', "ldconfig") >> 8;
    }
return $?;
    return;
}

sub capability_to_cli {
if ("$_[0]" =~ /^compute$/msx) {
                print "--compute\n";
    } elsif ("$_[0]" =~ /^compat32$/msx) {
                print "--compat32\n";
    } elsif ("$_[0]" =~ /^display$/msx) {
                print "--display\n";
    } elsif ("$_[0]" =~ /^graphics$/msx) {
                print "--graphics\n";
    } elsif ("$_[0]" =~ /^utility$/msx) {
                print "--utility\n";
    } elsif ("$_[0]" =~ /^video$/msx) {
                print "--video\n";
    } elsif (1) {
        exit 1;
    }
return;
    return;
}

sub parse_bool {
if ("$_[0]" =~ /^1$/msx or "$_[0]" =~ /^t$/msx or "$_[0]" =~ /^T$/msx or "$_[0]" =~ /^TRUE$/msx or "$_[0]" =~ /^true$/msx or "$_[0]" =~ /^True$/msx) {
                print "true\n";
    } elsif ("$_[0]" =~ /^0$/msx or "$_[0]" =~ /^f$/msx or "$_[0]" =~ /^F$/msx or "$_[0]" =~ /^FALSE$/msx or "$_[0]" =~ /^false$/msx or "$_[0]" =~ /^False$/msx) {
                print "false\n";
    } elsif (1) {
        exit 1;
    }
return;
    return;
}

sub usage {
print "nvidia-container-cli hook for LXC

Special arguments:
[ -h | --help ]: Print this help message and exit.

Optional arguments:
[ --no-load-kmods ]: Do not try to load the NVIDIA kernel modules.
[ --disable-require ]: Disable all the constraints of the form NVIDIA_REQUIRE_*.
[ --debug <path> ]: The path to the log file.
[ --ldcache <path> ]: The path to the host system's DSO cache.
[ --root <path> ]: The path to the driver root directory.
[ --ldconfig <path> ]: The path to the ldconfig binary, use a '@' prefix for a host path.
";
return q{0};
    return;
}
my $options;
my @options;
my %options;
$options = do {
    my ($in_4, $out_4);
    my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'getopt', '-o', q{h}, '-l', 'help,no-load-kmods,disable-require,debug:,ldcache:,root:,ldconfig:', '--', "@ARGV");
    close $in_4 or croak 'Close failed: $OS_ERROR';
    my $result_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
    close $out_4 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_4, 0;
    $result_4
};
if (($? != 0)) {
    usage();
exit 1;
}
do { my $eval_input = "set" . "--" . $options; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
$CLI_LOAD_KMODS = "true";
$CLI_DISABLE_REQUIRE = "false";
$CLI_DEBUG = q{};
$CLI_LDCACHE = q{};
$CLI_ROOT = q{};
$CLI_LDCONFIG = q{};
while ( $main_exit_code = system('bash', ':') >> 8 ) {
if ("$_[0]" =~ /^--help$/msx) {
                if (do {
usage();
            $CHILD_ERROR == 0
        }) {
            exit 1;
        }
    } elsif ("$_[0]" =~ /^--no-load-kmods$/msx) {
                $CLI_LOAD_KMODS = "false";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--disable-require$/msx) {
                $CLI_DISABLE_REQUIRE = "true";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--debug$/msx) {
                $CLI_DEBUG = $2;
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--ldcache$/msx) {
                $CLI_LDCACHE = $2;
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--root$/msx) {
                $CLI_ROOT = $2;
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--ldconfig$/msx) {
                $CLI_LDCONFIG = $2;
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--$/msx) {
        # Builtin command 'shift' not implemented
        last;    } elsif (1) {
        last;    }
}
$HOOK_SECTION = q{};
$HOOK_TYPE = q{};
if ((defined (defined ($ENV{LXC_HOOK_VERSION} // q{}) && ($ENV{LXC_HOOK_VERSION} // q{}) ne q{} ? ($ENV{LXC_HOOK_VERSION} // q{}) : '0') && (defined ($ENV{LXC_HOOK_VERSION} // q{}) && ($ENV{LXC_HOOK_VERSION} // q{}) ne q{} ? ($ENV{LXC_HOOK_VERSION} // q{}) : '0') ne q{} ? (defined ($ENV{LXC_HOOK_VERSION} // q{}) && ($ENV{LXC_HOOK_VERSION} // q{}) ne q{} ? ($ENV{LXC_HOOK_VERSION} // q{}) : '0') : '0') =~ /^0$/msx) {
        $HOOK_SECTION = (defined (defined $_[1] && $_[1] ne q{} ? $_[1] : '') && (defined $_[1] && $_[1] ne q{} ? $_[1] : '') ne q{} ? (defined $_[1] && $_[1] ne q{} ? $_[1] : '') : '');
        $HOOK_TYPE = (defined (defined $_[2] && $_[2] ne q{} ? $_[2] : '') && (defined $_[2] && $_[2] ne q{} ? $_[2] : '') ne q{} ? (defined $_[2] && $_[2] ne q{} ? $_[2] : '') : '');
} elsif ((defined (defined ($ENV{LXC_HOOK_VERSION} // q{}) && ($ENV{LXC_HOOK_VERSION} // q{}) ne q{} ? ($ENV{LXC_HOOK_VERSION} // q{}) : '0') && (defined ($ENV{LXC_HOOK_VERSION} // q{}) && ($ENV{LXC_HOOK_VERSION} // q{}) ne q{} ? ($ENV{LXC_HOOK_VERSION} // q{}) : '0') ne q{} ? (defined ($ENV{LXC_HOOK_VERSION} // q{}) && ($ENV{LXC_HOOK_VERSION} // q{}) ne q{} ? ($ENV{LXC_HOOK_VERSION} // q{}) : '0') : '0') =~ /^1$/msx) {
        $HOOK_SECTION = (defined (defined ($ENV{LXC_HOOK_SECTION} // q{}) && ($ENV{LXC_HOOK_SECTION} // q{}) ne q{} ? ($ENV{LXC_HOOK_SECTION} // q{}) : '') && (defined ($ENV{LXC_HOOK_SECTION} // q{}) && ($ENV{LXC_HOOK_SECTION} // q{}) ne q{} ? ($ENV{LXC_HOOK_SECTION} // q{}) : '') ne q{} ? (defined ($ENV{LXC_HOOK_SECTION} // q{}) && ($ENV{LXC_HOOK_SECTION} // q{}) ne q{} ? ($ENV{LXC_HOOK_SECTION} // q{}) : '') : '');
        $HOOK_TYPE = (defined (defined ($ENV{LXC_HOOK_TYPE} // q{}) && ($ENV{LXC_HOOK_TYPE} // q{}) ne q{} ? ($ENV{LXC_HOOK_TYPE} // q{}) : '') && (defined ($ENV{LXC_HOOK_TYPE} // q{}) && ($ENV{LXC_HOOK_TYPE} // q{}) ne q{} ? ($ENV{LXC_HOOK_TYPE} // q{}) : '') ne q{} ? (defined ($ENV{LXC_HOOK_TYPE} // q{}) && ($ENV{LXC_HOOK_TYPE} // q{}) ne q{} ? ($ENV{LXC_HOOK_TYPE} // q{}) : '') : '');
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "ERROR: Unsupported hook version: " . ($ENV{LXC_HOOK_VERSION} // q{}) . ".";
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
if ("${HOOK_SECTION}" ne "lxc") {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "ERROR: Not running through LXC.\n";
    };
exit 1;
}
if ("${HOOK_TYPE}" ne "mount") {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "ERROR: This hook must be used as a \"mount\" hook.\n";
    };
exit 1;
}
$USERNS = do {
    my ($in_5, $out_5);
    my $pid_5 = open3($in_5, $out_5, '>&STDERR', 'in_userns');
    close $in_5 or croak 'Close failed: $OS_ERROR';
    my $result_5 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
    close $out_5 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_5, 0;
    $result_5
};
if ("${USERNS}" ne "yes") {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "FIXME: This hook currently only works in unprivileged mode.\n";
    };
exit 1;
}
if ("${USERNS}" eq "yes") {
    $CLI_LOAD_KMODS = "false";
if (!(!(my $grep_result_6;
my @grep_lines_6 = ();
my @grep_filenames_6 = ();
if (-e "/proc/modules") {
    open my $fh, '<', "/proc/modules" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_6, $line;
        push @grep_filenames_6, "/proc/modules";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /proc/modules: No such file or directory\n"; }
my @grep_filtered_6 = grep { /nvidia_uvm/msx } @grep_lines_6;
$grep_result_6 = join "\n", @grep_filtered_6;
    if (!($grep_result_6 =~ m{\n\z}msx || $grep_result_6 eq q{})) {
        $grep_result_6 .= "\n";
    }
$CHILD_ERROR = scalar @grep_filtered_6 > 0 ? 0 : 1;
$grep_result_6 = q{};))) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "WARN: Kernel module nvidia_uvm is not loaded, nvidia-container-cli might fail. Make sure the NVIDIA device driver is installed and loaded.\n";
        };
    }
}
if ("${NVIDIA_DISABLE_REQUIRE:-}" ne q{}) {
if ("$(parse_bool "${NVIDIA_DISABLE_REQUIRE}")" eq "true") {
        $CLI_DISABLE_REQUIRE = "true";
    }
}
if ("${CLI_DEBUG}" eq q{}) {
if (("${LXC_LOG_LEVEL}" eq "DEBUG" || "${LXC_LOG_LEVEL}" eq "TRACE")) {
        my $rootfs_path;
        my @rootfs_path;
        my %rootfs_path;
        $rootfs_path = (($ENV{LXC_ROOTFS_PATH} // q{}) =~ s/^.*?://r =~ s/^.*?://r);
        my $hookdir;
        my @hookdir;
        my %hookdir;
        $hookdir = (scalar reverse( (scalar reverse ($ENV{rootfs_path/} // q{})) =~ s/^kooh/sftoor//r ) =~ s/rootfs/hook$//r);
if (!(        use File::Path qw(make_path);
        my $err;
        if ( !-d ${hookdir} ) {
            make_path( ${hookdir}, { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . ${hookdir} . ": $err->[0]\n";
            }
        })) {
            $CLI_DEBUG = ${hookdir} . "/nvidia.log";
        }
    }
}
if ("${CLI_LDCONFIG}" eq q{}) {
if (!(    my $host_ldconfig;
    my @host_ldconfig;
    my %host_ldconfig;
    $host_ldconfig = do {
    my ($in_8, $out_8);
    my $pid_8 = open3($in_8, $out_8, '>&STDERR', 'get_ldconfig');
    close $in_8 or croak 'Close failed: $OS_ERROR';
    my $result_8 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_8> };
    close $out_8 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_8, 0;
    $result_8
})) {
        $CLI_LDCONFIG = "@" . ${host_ldconfig};
    }
}
$CLI_DEVICES = ${NVIDIA_VISIBLE_DEVICES};
$CLI_CAPABILITIES = q{};
if ("${NVIDIA_DRIVER_CAPABILITIES:-}" ne q{}) {
    $CLI_CAPABILITIES = $NVIDIA_DRIVER_CAPABILITIES =~ s/,/ /grs;
}
if ("${CLI_CAPABILITIES}" eq "all") {
    $CLI_CAPABILITIES = "compute compat32 display graphics utility video";
}
if ("${CLI_CAPABILITIES}" eq q{}) {
    $CLI_CAPABILITIES = "utility";
}
my $global_args;
my @global_args = ();
my %global_args;
my $configure_args;
my @configure_args = ();
my %configure_args;
if ("${CLI_DEBUG}" ne q{}) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "INFO: Writing nvidia-container-cli log at " . ${CLI_DEBUG} . ".";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
    push @global_args, '--debug=${CLI_DEBUG}';
}
if ("${CLI_LOAD_KMODS}" eq "true") {
    push @global_args, '--load-kmods';
}
if ("${USERNS}" eq "yes") {
    push @global_args, '--user';
    push @configure_args, '--no-cgroups';
}
if ("${CLI_LDCACHE}" ne q{}) {
    push @global_args, '--ldcache="${CLI_LDCACHE}"';
}
if ("${CLI_ROOT}" ne q{}) {
    push @global_args, '--root="${CLI_ROOT}"';
}
if ("${CLI_LDCONFIG}" ne q{}) {
    push @configure_args, '--ldconfig="${CLI_LDCONFIG}"';
}
if (("${CLI_DEVICES}" ne q{} && "${CLI_DEVICES}" ne "none")) {
    push @configure_args, '--device="${CLI_DEVICES}"';
}
my $cap;
for my $cap ($CLI_CAPABILITIES) {
if (!(    my $arg;
    my @arg;
    my %arg;
    $arg = do {
    my ($in_9, $out_9);
    my $pid_9 = open3($in_9, $out_9, '>&STDERR', 'capability_to_cli', ${cap});
    close $in_9 or croak 'Close failed: $OS_ERROR';
    my $result_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_9> };
    close $out_9 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_9, 0;
    $result_9
})) {
        push @configure_args, ${arg};
}
    else {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "ERROR: Unknown driver capability \"" . ${cap} . "\".";
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
}
if ("${CLI_DISABLE_REQUIRE}" eq "false") {
    my $req;
    for my $req (do {
    my ($in_10, $out_10);
    my $pid_10 = open3($in_10, $out_10, '>&STDERR', 'compgen', '-e', "NVIDIA_REQUIRE_");
    close $in_10 or croak 'Close failed: $OS_ERROR';
    my $result_10 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_10> };
    close $out_10 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_10, 0;
    $result_10
}) {
        push @configure_args, '--require=${!req}';
    }
}
if ((-d "/sys/kernel/security/apparmor")) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/proc/self/attr/current'
      or die "Cannot open file: $OS_ERROR\n";
        print "changeprofile unconfined\n";
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
}
# set -x not implemented
# Builtin command 'exec' not implemented

exit $main_exit_code;
