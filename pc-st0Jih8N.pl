#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use File::Basename;
use IPC::Open3;
use File::Path qw(make_path remove_tree);

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

my $action_re;
my @action_re;
my %action_re;
my $module;
my @module;
my %module;
my $action;
my @action;
my %action;
my $source_only;
my @source_only;
my %source_only;
my $all;
my @all;
my %all;
my $weak_modules;
my @weak_modules;
my %weak_modules;
my $parallel_jobs;
my @parallel_jobs;
my %parallel_jobs;
my $kernelver;
my @kernelver;
my %kernelver;
my $tmpfile;
my @tmpfile;
my %tmpfile;
my $binaries_only;
my @binaries_only;
my %binaries_only;
my $line;
my @line;
my %line;
my $ADDON_MODULES_DIR;
my @ADDON_MODULES_DIR;
my %ADDON_MODULES_DIR;
my $arch;
my @arch;
my %arch;
my $force;
my @force;
my %force;

my $MAGIC_8   = 8;
my $MAGIC_3   = 3;
my $MAGIC_200 = 200;
my $MAGIC_7   = 7;
my $MAGIC_4   = 4;
my $MAGIC_22  = 22;
my $MAGIC_6   = 6;
my $MAGIC_10  = 10;
my $MAGIC_5   = 5;
my $MAGIC_9   = 9;
my $MAGIC_11  = 11;

# extglob option enabled
# readonly dkms_conf_variables not implemented in Perl
# readonly = not implemented in Perl
# readonly dkms_framework_nonsigning_variables not implemented in Perl
# readonly = not implemented in Perl
# readonly dkms_framework_signing_variables not implemented in Perl
# readonly = not implemented in Perl
# readonly mv_re not implemented in Perl
# readonly = not implemented in Perl
# readonly ^([^/]*)/(.*)$ not implemented in Perl

sub _get_kernel_dir {
if ($ksourcedir_fromcli eq q{}) {
        my $KVER;
        my @KVER;
        my %KVER;
        $KVER = $1;
if ($current_os =~ /^Linux$/msx) {
                        my $DIR;
            my @DIR;
            my %DIR;
            $DIR = "/lib/modules/$KVER/build";
        } elsif ($current_os =~ /^GNU/kFreeBSD$/msx) {
                        $DIR = "/usr/src/kfreebsd-headers-$KVER/sys";
        }
        print $DIR;
if ( !( ($DIR) =~ m{\n\z}msx ) ) { print "\n"; }
}
    else {
        print $kernel_source_dir;
if ( !( ($kernel_source_dir) =~ m{\n\z}msx ) ) { print "\n"; }
    }
    return;
}

sub _check_kernel_dir {
    my $DIR;
    my @DIR;
    my %DIR;
    $DIR = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', '_get_kernel_dir', $1);
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
if ($current_os =~ /^Linux$/msx) {
                $main_exit_code = system('test', '-e', $DIR, '/include') >> 8;
    } elsif ($current_os =~ /^GNU/kFreeBSD$/msx) {
                if (do {
$main_exit_code = system('test', '-e', $DIR, '/kern') >> 8;
            $CHILD_ERROR == 0
        }) {
                        $main_exit_code = system('test', '-e', $DIR, '/conf/kmod.mk') >> 8;
        }
    } elsif (1) {
        return q{1};    }
return $?;
    return;
}

sub invoke_command {
    my $exitval = "0";
        if (($verbose ne q{})) {
                print $1;
if ( !( ($1) =~ m{\n\z}msx ) ) { print "\n"; }
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ($CHILD_ERROR != 0) {
                do {
    my $__echo_line = "n" . q{ } . "$2...";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
if (($3 eq background && (!$verbose))) {
        my $pid;
        my $progresspid;
        if (my $pid = fork()) {
            # Parent process continues
        } elsif (defined $pid) {
            # Child process executes the background command
            exec 'bash', '-c', q{(: 'Complex command not supported in bash string generation' > /dev/null 2>&1)};
            croak "exec failed: $OS_ERROR\n";
        } else {
            die "Cannot fork: $ERRNO\n";
        }
        $pid = $!;
        if (my $pid = fork()) {
            # Parent process continues
        } elsif (defined $pid) {
            # Child process executes the background command
            exec 'bash', '-c', q{: 'Complex command not supported in bash string generation'; : 'Complex command not supported in bash string generation'; : 'Complex command not supported in bash string generation'};
            croak "exec failed: $OS_ERROR\n";
        } else {
            die "Cannot fork: $ERRNO\n";
        }
        $progresspid = $!;
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
1 while wait() > -1;
$CHILD_ERROR = $? == -1 ? 0 : $? >> 8;
        };
        $exitval = $?;
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $signal = 'TERM';
my @pids = ($progresspid);
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
        };
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
1 while wait() > -1;
$CHILD_ERROR = $? == -1 ? 0 : $? >> 8;
        };
}
    else {
do { my $eval_input = $1; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
        $exitval = $?;
    }
    if (do {
$CHILD_ERROR = ($main_exit_code = eval { int($exitval > 0) } // "") ? 0 : 1;
        $CHILD_ERROR == 0
    }) {
                do {
    my $__echo_line = "n" . q{ } . "(bad exit status: $exitval)";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
    print "n" . q{ } . "\n" . "\n";
    $CHILD_ERROR = 0;
return $exitval;
    return;
}
$main_exit_code = system('error', q{}, "\n    exec >&2\n    echo -n $\"Error! \"\n    for s in \"$@\"; do echo \"$s\"; done\n") >> 8;
$main_exit_code = system('warn', q{}, "\n    exec >&2\n    echo -n $\"Warning: \"\n    for s in \"$@\"; do echo \"$s\"; done\n") >> 8;
$main_exit_code = system('deprecated', q{}, "\n    exec >&2\n    echo -n $\"Deprecated feature: \"\n    for s in \"$@\"; do echo \"$s\"; done\n") >> 8;

sub die {
    my $ret;
    my @ret;
    my %ret;
    $ret = $1;
# Builtin command 'shift' not implemented
    $main_exit_code = system('error', "@ARGV") >> 8;
        if ($die_is_fatal eq yes) {
                $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ($CHILD_ERROR != 0) {
        return $ret;    }
    return;
}

sub mktemp_or_die {
    my $t;
    if (do {
if (do {
$t = do {
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'mktemp', "@ARGV");
    close $in_2 or croak 'Close failed: $OS_ERROR';
    my $result_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    $result_2
};
    $CHILD_ERROR == 0
}) {
        print $t;
if ( !( ($t) =~ m{\n\z}msx ) ) { print "\n"; }
}
        $CHILD_ERROR == 0
    }) {
        return;    }
    if ($* eq *-d *) {
                die(q{1}, "$\"Unable to make temporary directory\"");
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    die(q{1}, "Unable to make temporary file.");
    return;
}

sub show_usage {
    my ($file) = @_;
    do {
    my $__echo_line = "$\"Usage: $PROGRAM_NAME [action] [options]\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "$\"  [action]  = { add | remove | build | install | uninstall | match | autoinstall |\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "$\"                mktarball | ldtarball | status }\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "$\"  [options] = [-m module] [-v module-version] [-k kernel-version] [-a arch]\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "$\"              [-c dkms.conf-location] [-q] [--force] [--force-version-override] [--all]\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "$\"              [--templatekernel=kernel] [--directive='cli-directive=cli-value']\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "$\"              [--config=kernel-.config-location] [--archive=tarball-location]\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "$\"              [--kernelsourcedir=source-location]\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "$\"              [--binaries-only] [--source-only] [--verbose]\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "$\"              [--no-depmod] [--modprobe-on-install] [-j number] [--version]\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    return;
}

sub VER {
    # Original bash: echo $1 | sed -e 's:\([^0-9]\)\([0-9]\):\1 \2:g' \
{
        my $output_3 = q{};
        my $output_printed_3;
        my $pipeline_success_3 = 1;
        $output_3 .= $1 . "\n";
if ( !($output_3 =~ m{\n\z}msx) ) { $output_3 .= "\n"; }
$CHILD_ERROR = 0;

                my @sed_lines_3 = split /\n/msx, $output_3;
        my @sed_result_3;
        foreach my $line (@sed_lines_3) {
        chomp $line;
        push @sed_result_3, $line;
        }
        $output_3 = join "\n", @sed_result_3;
        if ($output_3 ne q{} && !defined $output_printed_3) {
            print $output_3;
            if (!($output_3 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
        }
    return;
}

sub get_num_cpus {
if ((-x '/usr/bin/nproc')) {
        $main_exit_code = system('bash', 'nproc') >> 8;
}
    else {
        print "1\n";
    }
    return;
}

sub compressed_or_uncompressed {
    my $test1 = "$_[0]/$_[1]$ENV{module_uncompressed_suffix}";
    my $test2 = "$_[0]/$_[1]$ENV{module_uncompressed_suffix}$ENV{module_compressed_suffix}";
if ((-e "$test1")) {
        print $test1;
if ( !( ($test1) =~ m{\n\z}msx ) ) { print "\n"; }
}
    else {
        if ((-e "$test2")) {
            print $test2;
if ( !( ($test2) =~ m{\n\z}msx ) ) { print "\n"; }
        }
    }
    return;
}

sub find_module {
    my ($file) = @_;
    require File::Find;
    File::Find::find(sub {     next unless -f $_;     print "$File::Find::name\n"; }, './');
return $?;
    return;
}

sub set_module_suffix {
    my $kernel_test;
    my @kernel_test;
    my %kernel_test;
    $kernel_test = (defined (defined $_[0] && $_[0] ne q{} ? $_[0] : do { my $_result = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__rel; join(" ", @__parts) . "\n"; }; $_result; }) && (defined $_[0] && $_[0] ne q{} ? $_[0] : do { my $_result = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__rel; join(" ", @__parts) . "\n"; }; $_result; }) ne q{} ? (defined $_[0] && $_[0] ne q{} ? $_[0] : do { my $_result = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__rel; join(" ", @__parts) . "\n"; }; $_result; }) : do { my $_result = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__rel; join(" ", @__parts) . "\n"; }; $_result; });
    my $module_uncompressed_suffix;
    my @module_uncompressed_suffix;
    my %module_uncompressed_suffix;
    $module_uncompressed_suffix = ".ko";
    if (do {
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $grep_result_4;
my @grep_lines_4 = ();
my @grep_filenames_4 = ();
if (-e "/lib/modules/") {
    open my $fh, '<', "/lib/modules/" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_4, $line;
        push @grep_filenames_4, "/lib/modules/";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /lib/modules/: No such file or directory\n"; }
if (-e "/modules.dep") {
    open my $fh, '<', "/modules.dep" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_4, $line;
        push @grep_filenames_4, "/modules.dep";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /modules.dep: No such file or directory\n"; }
my @grep_filtered_4 = grep { /[.]gz:/msx } @grep_lines_4;
$grep_result_4 = join "\n", @grep_filtered_4;
            if (!($grep_result_4 =~ m{\n\z}msx || $grep_result_4 eq q{})) {
                $grep_result_4 .= "\n";
            }
$CHILD_ERROR = scalar @grep_filtered_4 > 0 ? 0 : 1;
$grep_result_4 = q{};
        };
    } == 0) {
                my $module_compressed_suffix;
        my @module_compressed_suffix;
        my %module_compressed_suffix;
        $module_compressed_suffix = ".gz";
    }
    if (do {
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $grep_result_5;
my @grep_lines_5 = ();
my @grep_filenames_5 = ();
if (-e "/lib/modules/") {
    open my $fh, '<', "/lib/modules/" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_5, $line;
        push @grep_filenames_5, "/lib/modules/";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /lib/modules/: No such file or directory\n"; }
if (-e "/modules.dep") {
    open my $fh, '<', "/modules.dep" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_5, $line;
        push @grep_filenames_5, "/modules.dep";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /modules.dep: No such file or directory\n"; }
my @grep_filtered_5 = grep { /[.]xz:/msx } @grep_lines_5;
$grep_result_5 = join "\n", @grep_filtered_5;
            if (!($grep_result_5 =~ m{\n\z}msx || $grep_result_5 eq q{})) {
                $grep_result_5 .= "\n";
            }
$CHILD_ERROR = scalar @grep_filtered_5 > 0 ? 0 : 1;
$grep_result_5 = q{};
        };
    } == 0) {
                $module_compressed_suffix = ".xz";
    }
    if (do {
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $grep_result_6;
my @grep_lines_6 = ();
my @grep_filenames_6 = ();
if (-e "/lib/modules/") {
    open my $fh, '<', "/lib/modules/" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_6, $line;
        push @grep_filenames_6, "/lib/modules/";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /lib/modules/: No such file or directory\n"; }
if (-e "/modules.dep") {
    open my $fh, '<', "/modules.dep" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_6, $line;
        push @grep_filenames_6, "/modules.dep";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /modules.dep: No such file or directory\n"; }
my @grep_filtered_6 = grep { /[.]zst:/msx } @grep_lines_6;
$grep_result_6 = join "\n", @grep_filtered_6;
            if (!($grep_result_6 =~ m{\n\z}msx || $grep_result_6 eq q{})) {
                $grep_result_6 .= "\n";
            }
$CHILD_ERROR = scalar @grep_filtered_6 > 0 ? 0 : 1;
$grep_result_6 = q{};
        };
    } == 0) {
                $module_compressed_suffix = ".zst";
    }
    my $module_suffix;
    my @module_suffix;
    my %module_suffix;
    $module_suffix = "$module_uncompressed_suffix$module_compressed_suffix";
    return;
}

sub set_kernel_source_dir_and_kconfig {
if ("${ksourcedir_fromcli}" eq q{}) {
        my $kernel_source_dir;
        my @kernel_source_dir;
        my %kernel_source_dir;
        $kernel_source_dir = (do { my $_chomp_temp = do {
    my ($in_7, $out_7);
    my $pid_7 = open3($in_7, $out_7, '>&STDERR', '_get_kernel_dir', "$_[0]");
    close $in_7 or croak 'Close failed: $OS_ERROR';
    my $result_7 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
    close $out_7 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_7, 0;
    $result_7
}; chomp $_chomp_temp; $_chomp_temp; });
    }
if ("${kconfig_fromcli}" eq q{}) {
        my $kernel_config;
        my @kernel_config;
        my %kernel_config;
        $kernel_config = ${kernel_source_dir} . "/.config";
    }
    return;
}

sub check_all_is_banned {
    my ($file) = @_;
if (($all ne q{})) {
        die(q{5}, "$\"The action $_[0] does not support the --all parameter.\"");
    }
    return;
}

sub have_one_kernel {
    my ($file) = @_;
if (eval { int(scalar(@kernelver) != 1) } // "") {
        die(q{4}, "$\"The action $_[0] does not support multiple kernel version parameters on the command line.\"");
    }
    check_all_is_banned($1);
    return;
}

sub setup_kernels_arches {
if ((($all ne q{}) && $1 ne status)) {
        my $i = "0";
        my $temp_file_ps_fh_1 = q{/tmp} . '/process_sub_fh_1.tmp';
        my $output_ps_fh_1;
        {
        my ($in, $out);
        my $pid = open3($in, $out, '>&STDERR', 'bash', '-c', 'module_status_built "$module" "$module_version" | sort -V');
        close $in or croak 'Close failed: $OS_ERROR';
        $output_ps_fh_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
        close $out or croak 'Close failed: $OS_ERROR';
        waitpid $pid, 0;
$CHILD_ERROR = $? >> 8;
        }
        use File::Path qw(make_path);
        my $temp_dir_fh_1 = dirname($temp_file_ps_fh_1);
        if (!-d $temp_dir_fh_1) { make_path($temp_dir_fh_1); }
        open my $fh_ps_fh_1, '>', $temp_file_ps_fh_1 or croak "Cannot create temp file: $ERRNO\n";
        print {$fh_ps_fh_1} $output_ps_fh_1;
        close $fh_ps_fh_1 or croak "Close failed: $ERRNO\n";
        open STDIN, '<', $temp_file_ps_fh_1 or croak "Cannot open process substitution: $ERRNO\n";
        my $line;
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $line = $_fields[0] // q{};
            $line = ${line} =~ s/^.*?///r;
            $line = ${line} =~ s/^.*?///r;
            $kernelver{"$i"} = dirname(${line});
            $arch{"$i"} = ${line} =~ s/^.*?///r;
            if (defined $i) {
                $i = eval { int($i + 1) } // "";
            }
        }
    }
if ($1 ne status) {
if (((!$kernelver) && (!$all))) {
            $kernelver[0] = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__rel; join(" ", @__parts) . "\n"; };
        }
if ((!$arch)) {
if ("$ENV{running_distribution}" =~ /^debian.*$/msx or "$ENV{running_distribution}" =~ /^ubuntu.*$/msx or "$ENV{running_distribution}" =~ /^arch.*$/msx) {
                                $arch[0] = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__mach; join(" ", @__parts) . "\n"; };
            } elsif (1) {
                                my $kernelver_rpm;
                my @kernelver_rpm;
                my %kernelver_rpm;
                $kernelver_rpm = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                    my $output_8 = q{};
                    my $output_printed_8;
                    my $pipeline_success_8 = 1;
                    my ($in_9, $out_9);
                    my $pid_9 = open3($in_9, $out_9, '>&STDERR', 'rpm', '-qf');
                    close $in_9 or croak 'Close failed: $OS_ERROR';
                    $output_8 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_9> };
                    close $out_9 or croak 'Close failed: $OS_ERROR';
                    waitpid $pid_9, 0;
                    my $grep_result_8_1;
                    my @grep_lines_8_1 = split /\n/msx, $output_8;
                    my @grep_filtered_8_1 = grep { !/not\ owned\ by\ any\ package/msx } @grep_lines_8_1;
                    $grep_result_8_1 = join "\n", @grep_filtered_8_1;
                    if (!($grep_result_8_1 =~ m{\n\z}msx || $grep_result_8_1 eq q{})) {
                    $grep_result_8_1 .= "\n";
                    }
                    $CHILD_ERROR = scalar @grep_filtered_8_1 > 0 ? 0 : 1;
                    $output_8 = $grep_result_8_1;
                    $output_8 = $grep_result_8_1;
                    my $grep_result_8_2;
                    my @grep_lines_8_2 = split /\n/msx, $output_8;
                    my @grep_filtered_8_2 = grep { /kernel/msx } @grep_lines_8_2;
                    $grep_result_8_2 = join "\n", @grep_filtered_8_2;
                    if (!($grep_result_8_2 =~ m{\n\z}msx || $grep_result_8_2 eq q{})) {
                    $grep_result_8_2 .= "\n";
                    }
                    $CHILD_ERROR = scalar @grep_filtered_8_2 > 0 ? 0 : 1;
                    $output_8 = $grep_result_8_2;
                    $output_8 = $grep_result_8_2;
                    my $num_lines       = 1;
                    my $head_line_count = 0;
                    my $result          = q{};
                    my $input           = $output_8;
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
                    $output_8 = $result;
                    if ( !$pipeline_success_8 ) { $main_exit_code = 1; }
                    $output_8 =~ s/\n+\z//msx;
                    $output_8;
}; $_pipeline_result; };
                if (!(!($arch[0] = do { my @_qx_cmd = ("rpm -q --queryformat %{ARCH} \"$kernelver_rpm\" 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };))) {
                    $arch[0] = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__mach; join(" ", @__parts) . "\n"; };
if ((($arch eq x86_64 && !(my $grep_result_10;
my @grep_lines_10 = ();
my @grep_filenames_10 = ();
if (-e "/proc/cpuinfo") {
    open my $fh, '<', "/proc/cpuinfo" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_10, $line;
        push @grep_filenames_10, "/proc/cpuinfo";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /proc/cpuinfo: No such file or directory\n"; }
my @grep_filtered_10 = grep { /Intel/msx } @grep_lines_10;
$grep_result_10 = join "\n", @grep_filtered_10;
                    if (!($grep_result_10 =~ m{\n\z}msx || $grep_result_10 eq q{})) {
                        $grep_result_10 .= "\n";
                    }
$CHILD_ERROR = scalar @grep_filtered_10 > 0 ? 0 : 1;
$grep_result_10 = q{})) && !({
                        my $output_11 = q{};
                        my $output_printed_11;
                        my $pipeline_success_11 = 1;
                                                $output = q{};
                                                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_12 = q{};
$tmp_redirect_12 = do {
    my @ls_files_14 = ();
    my $ls_all_found_15 = 1;
    my @ls_inputs_16 = ();
    push @ls_inputs_16, '/';
    push @ls_inputs_16, '/build/configs';
    my @ls_files_17 = ();
    my @ls_dirs_18 = ();
    my $ls_show_headers_19 = scalar(@ls_inputs_16) > 1;
    for my $ls_item_20 (@ls_inputs_16) {
        if ( -f $ls_item_20 ) {
            push @ls_files_17, $ls_item_20;
        }
        elsif ( -d $ls_item_20 ) {
            push @ls_dirs_18, $ls_item_20;
        }
        else {
            $ls_all_found_15 = 0;
        }
    }
    @ls_files_17 = sort { $a cmp $b } @ls_files_17;
    @ls_dirs_18 = sort { $a cmp $b } @ls_dirs_18;
    if (@ls_files_17) {
        push @ls_files_14, join("\n", @ls_files_17);
    }
    for my $ls_dir_21 (@ls_dirs_18) {
        my @ls_dir_entries_22 = ();
        if ( opendir my $dh, $ls_dir_21 ) {
            while ( my $file = readdir $dh ) {
                next if $file eq q{.} || $file eq q{..} || $file =~ /^[.]/msx;
                push @ls_dir_entries_22, $file;
            }
            closedir $dh;
            @ls_dir_entries_22 = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, do { (my $s = $_) =~ s{/$}{}msx; $s } ] } @ls_dir_entries_22;
            if ( $ls_show_headers_19 ) {
                if ( @ls_dir_entries_22 ) {
                    push @ls_files_14, $ls_dir_21 . ":\n" . join("\n", @ls_dir_entries_22);
                } else {
                    push @ls_files_14, $ls_dir_21 . ':';
                }
            }
            elsif ( @ls_dir_entries_22 ) {
                push @ls_files_14, join("\n", @ls_dir_entries_22);
            }
        }
        else {
            $ls_all_found_15 = 0;
        }
    }
    (@ls_files_14 ? join("\n\n", @ls_files_14) . "\n" : q{});
};
;
$tmp_redirect_12;
                        };
                        $output_11 = $output;

                                                my $grep_result_11_1;
                        my @grep_lines_11_1 = split /\n/msx, $output_11;
                        my @grep_filtered_11_1 = grep { /ia32e/msx } @grep_lines_11_1;
                        $grep_result_11_1 = join "\n", @grep_filtered_11_1;
                        if (!($grep_result_11_1 =~ m{\n\z}msx || $grep_result_11_1 eq q{})) {
                        $grep_result_11_1 .= "\n";
                        }
                        $CHILD_ERROR = scalar @grep_filtered_11_1 > 0 ? 0 : 1;
                        $grep_result_11_1 = q{};
                        $output_11 = q{};
                        if ((scalar @grep_filtered_11_1) == 0) {
                            $pipeline_success_11 = 0;
                        }
                        if ($output_11 ne q{} && !defined $output_printed_11) {
                            print $output_11;
                            if (!($output_11 =~ m{\n\z}msx)) {
                                print "\n";
                            }
                        }
                        if ( !$pipeline_success_11 ) { $main_exit_code = 1; }
                        }))) {
                        $arch[0] = "ia32e";
                    }
                }
            }
        }
    }
if (eval { int(scalar(@arch) == 1 && scalar(@kernelver) > 1) } // "") {
while ( !(        $CHILD_ERROR = ($main_exit_code = eval { int(scalar(@arch) < scalar(@kernelver)) } // "") ? 0 : 1) ) {
            $arch{"${#arch[@"} = $arch;
        }
    }
    my $multi_arch;
    my @multi_arch;
    my %multi_arch;
    $multi_arch = "";
    my $i = "0";
    for (eval { int($i=0) } // ""; eval { int($i < scalar(@arch)) } // ""; eval { int($i++) } // "") {
            if ($arch ne ${arch[$i]}) {
                                    $multi_arch = "true";
last;
                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
    }
    return;
}

sub do_depmod {
    my ($file) = @_;
if (($no_depmod ne q{})) {
return;
    }
if ("${current_os}" ne "Linux") {
return;
    }
if ((-f '/boot/System.map-$1')) {
        $main_exit_code = system('depmod', '-a', "$_[0]", '-F', "/boot/System.map-$_[0]") >> 8;
}
    else {
        $main_exit_code = system('depmod', '-a', "$_[0]") >> 8;
    }
    return;
}

sub distro_version {
if ((-r '/etc/os-release')) {
        $main_exit_code = system('.', '/etc/os-release') >> 8;
if ("$ID" eq "ubuntu") {
            print $ID;
if ( !( ($ID) =~ m{\n\z}msx ) ) { print "\n"; }
}
        else {
            if (${#ID_LIKE[@]} ne 0) {
                print $ID_LIKE[0];
if ( !( ($ID_LIKE[0]) =~ m{\n\z}msx ) ) { print "\n"; }
}
            else {
                print $ID;
if ( !( ($ID) =~ m{\n\z}msx ) ) { print "\n"; }
            }
        }
return;
    }
    my $DISTRIB_ID;
if ((-r '/etc/lsb-release')) {
        $main_exit_code = system('.', '/etc/lsb-release') >> 8;
}
    else {
        if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('type', 'lsb_release') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
            $DISTRIB_ID = do {
    my ($in_23, $out_23);
    my $pid_23 = open3($in_23, $out_23, '>&STDERR', 'lsb_release', '-i', '-s');
    close $in_23 or croak 'Close failed: $OS_ERROR';
    my $result_23 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_23> };
    close $out_23 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_23, 0;
    $result_23
};
        }
    }
if ($DISTRIB_ID =~ /^Fedora$/msx) {
                print 'fedora' . "\n";
        $CHILD_ERROR = 0;
    } elsif ($DISTRIB_ID =~ /^RedHatEnterprise.*$/msx or $DISTRIB_ID =~ /^CentOS$/msx or $DISTRIB_ID =~ /^ScientificSL$/msx) {
                print 'rhel' . "\n";
        $CHILD_ERROR = 0;
    } elsif ($DISTRIB_ID =~ /^SUSE.*$/msx) {
                print 'sles' . "\n";
        $CHILD_ERROR = 0;
    } elsif (1) {
        if ((${DISTRIB_ID} ne q{})) {
            print ${DISTRIB_ID};
if ( !( (${DISTRIB_ID}) =~ m{\n\z}msx ) ) { print "\n"; }
}
        else {
            print 'unknown' . "\n";
            $CHILD_ERROR = 0;
        }
    }
    return;
}

sub override_dest_module_location {
    my $orig_location = "$_[0]";
    if (do {
if ((${addon_modules_dir} ne q{})) {
        do {
    my $__echo_line = "/" . ($ENV{addon_modules_dir} // q{});
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
        $CHILD_ERROR == 0
    }) {
        return;    }
if ("$current_os" eq "GNU/kFreeBSD") {
        if (do {
print "\n";
            $CHILD_ERROR == 0
        }) {
            return;        }
    }
if ("$ENV{running_distribution}" =~ /^fedora.*$/msx or "$ENV{running_distribution}" =~ /^rhel.*$/msx or "$ENV{running_distribution}" =~ /^ovm.*$/msx) {
                if (do {
print "/extra\n";
            $CHILD_ERROR == 0
        }) {
            return;        }
    } elsif ("$ENV{running_distribution}" =~ /^sles.*$/msx or "$ENV{running_distribution}" =~ /^suse.*$/msx or "$ENV{running_distribution}" =~ /^opensuse.*$/msx) {
                if (do {
print "/updates\n";
            $CHILD_ERROR == 0
        }) {
            return;        }
    } elsif ("$ENV{running_distribution}" =~ /^debian.*$/msx or "$ENV{running_distribution}" =~ /^ubuntu.*$/msx) {
                if (do {
print "/updates/dkms\n";
            $CHILD_ERROR == 0
        }) {
            return;        }
    } elsif ("$ENV{running_distribution}" =~ /^arch.*$/msx) {
                if (do {
print "/updates/dkms\n";
            $CHILD_ERROR == 0
        }) {
            return;        }
    } elsif (1) {
    }
    print $orig_location;
if ( !( ($orig_location) =~ m{\n\z}msx ) ) { print "\n"; }
    return;
}

sub safe_source {
    my $to_source_file = "$_[0]";
# Builtin command 'shift' not implemented
    my @export_envs = ('$@');
    my $tmpfile = do {
    my ($in_24, $out_24);
    my $pid_24 = open3($in_24, $out_24, '>&STDERR', 'mktemp_or_die');
    close $in_24 or croak 'Close failed: $OS_ERROR';
    my $result_24 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_24> };
    close $out_24 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_24, 0;
    $result_24
};
    do {
        local %ENV = %ENV;
        my $to_source_file = $to_source_file;
        my $tmpfile = $tmpfile;
        my $export_envs = $export_envs;
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', "$tmpfile"
      or die "Cannot open file: $OS_ERROR\n";
# Builtin command 'exec' not implemented
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
                my $tmp = do {
                $main_exit_code = system('.', "$to_source_file") >> 8;
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            my $_export_env;
            for my $_export_env (@export_envs) {
                my $_i;
                for my $_i (do {
    local $ENV{_export_env} = $_export_env;
    my $command = q{: 'Complex command not supported in bash string generation'};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}) {
do { my $eval_input = "echo" . "$_export_env[$_i]=\\\"${" . $_export_env . "[$_i]}\\\""; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
                }
            }
            my $directive;
            for my $directive (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_25 = q{};
                my $output_printed_25;
                my $pipeline_success_25 = 1;
                my @_pcmd_27 = ('bash', '-c', ": \"Complex command cannot be converted to shell command\"");
                my ($in_26);
                my $pid_26 = open3($in_26, $out_26, '>&STDERR', @_pcmd_27);
                close $in_26 or croak 'Close failed: $OS_ERROR';
                my $temp_result;
                $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_26> };
                $output_25 = $temp_result;
                close $out_26 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_26, 0;
                my $grep_result_25_1;
                my @grep_lines_25_1 = split /\n/msx, $output_25;
                my @grep_filtered_25_1 = grep { /^DKMS_DIRECTIVE/msx } @grep_lines_25_1;
                $grep_result_25_1 = join "\n", @grep_filtered_25_1;
                if (!($grep_result_25_1 =~ m{\n\z}msx || $grep_result_25_1 eq q{})) {
                $grep_result_25_1 .= "\n";
                }
                $CHILD_ERROR = scalar @grep_filtered_25_1 > 0 ? 0 : 1;
                $output_25 = $grep_result_25_1;
                $output_25 = $grep_result_25_1;
                my @lines_28 = split /\n/msx, $output_25;
                my @result_28;
                foreach my $line (@lines_28) {
                chomp $line;
                my @fields = split /=/msx, $line;
                if (@fields > 0) {
                push @result_28, $fields[0];
                }
                }
                $output_25 = join "\n", @result_28;
                if ($output_25 ne q{} && !($output_25  =~ m{\n\z}msx)) { $output_25 .= "\n"; }
                if ( !$pipeline_success_25 ) { $main_exit_code = 1; }
                $output_25 =~ s/\n+\z//msx;
                $output_25;
}; $_pipeline_result; }) {
                my $directive_name;
                my @directive_name;
                my %directive_name;
                $directive_name = ${directive} =~ s/=.*$//sr;
                my $directive_value;
                my @directive_value;
                my %directive_value;
                $directive_value = ${directive} =~ s/^.*?=//r;
                do {
    my $__echo_line = "$directive_name=\"$directive_value\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
            }
        q{};
    };
    $main_exit_code = system('.', "$tmpfile") >> 8;
if ( -e "$tmpfile" ) {
        if ( -d "$tmpfile" ) {
            croak "rm: ", "$tmpfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$tmpfile" ) {
                            }
            else {
                croak "rm: cannot remove ", "$tmpfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 1;
        croak "rm: ", "$tmpfile", ": No such file or directory\n";
    }
    if (do {
$CHILD_ERROR = ($main_exit_code = eval { int(0) } // "") ? 0 : 1;
        $CHILD_ERROR == 0
    }) {
                $main_exit_code = system('deprecated', "REMAKE_INITRD ($to_source_file)") >> 8;
    }
    if (do {
$CHILD_ERROR = ($main_exit_code = eval { int(0) } // "") ? 0 : 1;
        $CHILD_ERROR == 0
    }) {
                $main_exit_code = system('deprecated', "MODULES_CONF ($to_source_file)") >> 8;
    }
    if (do {
$CHILD_ERROR = ($main_exit_code = eval { int(0) } // "") ? 0 : 1;
        $CHILD_ERROR == 0
    }) {
                $main_exit_code = system('deprecated', "MODULES_CONF_OBSOLETES ($to_source_file)") >> 8;
    }
    if (do {
$CHILD_ERROR = ($main_exit_code = eval { int(0) } // "") ? 0 : 1;
        $CHILD_ERROR == 0
    }) {
                $main_exit_code = system('deprecated', "MODULES_CONF_ALIAS_TYPE ($to_source_file)") >> 8;
    }
    if (do {
$CHILD_ERROR = ($main_exit_code = eval { int(0) } // "") ? 0 : 1;
        $CHILD_ERROR == 0
    }) {
                $main_exit_code = system('deprecated', "MODULES_CONF_OBSOLETE_ONLY ($to_source_file)") >> 8;
    }
    return;
}

sub read_conf {
    my $return_value = "0";
    my $read_conf_file = "$ENV{dkms_tree}/$module/$ENV{module_version}/source/dkms.conf";
    my $kernelver = "$_[0]";
    my $arch = "$_[1]";
    set_kernel_source_dir_and_kconfig("$_[0]");
    if (($conf ne q{})) {
                $read_conf_file = "$ENV{conf}";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if (($MAGIC_3 ne q{})) {
                $read_conf_file = "$_[2]";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if (!((-r $read_conf_file))) {
                die(q{4}, "$\"Could not locate dkms.conf file.\"", "$\"File: $read_conf_file does not exist.\"");
    }
    if (($last_mvka eq $module/$module_version/$1/$2 && $last_mvka_conf eq $(readlink -f $read_conf_file))) {
        return;        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    my $var;
    for my $var ($dkms_conf_variables) {

    }
    my $_conf_file;
    for my $_conf_file ("$read_conf_file", "/etc/dkms/$module.conf", "/etc/dkms/$module-$ENV{module_version}.conf", "/etc/dkms/$module-$ENV{module_version}-$_[0].conf", "/etc/dkms/$module-$ENV{module_version}-$_[0]-$_[1].conf") {
        if ((-e "$_conf_file")) {
                        safe_source("$_conf_file", $dkms_conf_variables);
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
    }
    my $directive;
    for my $directive (@directive_array) {
        my $directive_name;
        my @directive_name;
        my %directive_name;
        $directive_name = ${directive} =~ s/=.*$//sr;
        my $directive_value;
        my @directive_value;
        my %directive_value;
        $directive_value = ${directive} =~ s/^.*?=//r;
$ENV{} = '';
        do {
    my $__echo_line = "$\"DIRECTIVE: $directive_name=\"$directive_value\"\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
    my $clean;
    my @clean;
    my %clean;
    $clean = "$ENV{CLEAN}";
    my $package_name;
    my @package_name;
    my %package_name;
    $package_name = "$ENV{PACKAGE_NAME}";
    my $package_version;
    my @package_version;
    my %package_version;
    $package_version = "$ENV{PACKAGE_VERSION}";
    my $post_add;
    my @post_add;
    my %post_add;
    $post_add = "$ENV{POST_ADD}";
    my $post_build;
    my @post_build;
    my %post_build;
    $post_build = "$ENV{POST_BUILD}";
    my $post_install;
    my @post_install;
    my %post_install;
    $post_install = "$ENV{POST_INSTALL}";
    my $post_remove;
    my @post_remove;
    my %post_remove;
    $post_remove = "$ENV{POST_REMOVE}";
    my $pre_build;
    my @pre_build;
    my %pre_build;
    $pre_build = "$ENV{PRE_BUILD}";
    my $pre_install;
    my @pre_install;
    my %pre_install;
    $pre_install = "$ENV{PRE_INSTALL}";
    my $obsolete_by;
    my @obsolete_by;
    my %obsolete_by;
    $obsolete_by = "$ENV{OBSOLETE_BY}";
if ((!$package_name)) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "$\"dkms.conf: Error! No 'PACKAGE_NAME' directive specified.\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
        $return_value = q{1};
    }
if ((!$package_version)) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "$\"dkms.conf: Error! No 'PACKAGE_VERSION' directive specified.\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
        $return_value = q{1};
    }
    my $index;
    my $array_size = "0";
    my $s;
    for my $s (0, 0, 0, 0) {
        if (do {
$CHILD_ERROR = ($main_exit_code = eval { int($s > $array_size) } // "") ? 0 : 1;
            $CHILD_ERROR == 0
        }) {
                        $array_size = $s;
        }
    }
    for (eval { int($index=0) } // ""; eval { int($index < $array_size) } // ""; eval { int($index++) } // "") {
            $built_module_name{"$index"} = q{};
            $built_module_location{"$index"} = q{};
            $dest_module_name{"$index"} = q{};
            $dest_module_location{"$index"} = q{};
if (q{} =~ /^\[nN\].*$/msx) {
                                $strip{"$index"} = "no";
            } elsif (q{} =~ /^\[yY\].*$/msx) {
                                $strip{"$index"} = "yes";
            } elsif (q{} =~ /^$/msx) {
                                $strip{"$index"} = (defined $ENV{'strip[0]'} && $ENV{'strip[0]'} ne q{} ? $ENV{'strip[0]'} : 'yes');
            }
            if (do {
if ((!${built_module_name[$index]})) {
        $CHILD_ERROR = ($main_exit_code = eval { int($array_size == 1) } // "") ? 0 : 1;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
                $CHILD_ERROR == 0
            }) {
                                $built_module_name{"$index"} = $PACKAGE_NAME;
            }
            if ((!${dest_module_name[$index]})) {
                                $dest_module_name{"$index"} = q{};
                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
            if (((${built_module_location[$index]} ne q{}) && ${built_module_location[$index]:(-1)} ne /)) {
                                $built_module_location{"$index"} = $built_module_location[eval { int($index) } // ""] . "/";
                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
if ((!${built_module_name[$index]})) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    do {
    my $__echo_line = "$\"dkms.conf: Error! No 'BUILT_MODULE_NAME' directive specified for record #$index.\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                };
                $return_value = q{1};
            }
if (q{} =~ /^.*.o$/msx or q{} =~ /^.*.ko$/msx) {
                                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    do {
    my $__echo_line = "$\"dkms.conf: Error! 'BUILT_MODULE_NAME' directive ends in '.o' or '.ko' in record #$index.\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                };
                                $return_value = q{1};
            }
if (q{} =~ /^.*.o$/msx or q{} =~ /^.*.ko$/msx) {
                                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    do {
    my $__echo_line = "$\"dkms.conf: Error! 'DEST_MODULE_NAME' directive ends in '.o' or '.ko' in record #$index.\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                };
                                $return_value = q{1};
            }
            $dest_module_location{"$index"} = (do { my $_chomp_temp = do {
    my ($in_29, $out_29);
    my $pid_29 = open3($in_29, $out_29, '>&STDERR', 'override_dest_module_location', q{});
    close $in_29 or croak 'Close failed: $OS_ERROR';
    my $result_29 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_29> };
    close $out_29 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_29, 0;
    $result_29
}; chomp $_chomp_temp; $_chomp_temp; });
if ((!${DEST_MODULE_LOCATION[$index]})) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    do {
    my $__echo_line = "$\"dkms.conf: Error! No 'DEST_MODULE_LOCATION' directive specified for record #$index.\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                };
                $return_value = q{1};
            }
if (q{} =~ /^/kernel.*$/msx) {
            } elsif (q{} =~ /^/updates.*$/msx) {
            } elsif (q{} =~ /^/extra.*$/msx) {
            } elsif (1) {
                                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    do {
    my $__echo_line = "$\"dkms.conf: Error! Directive 'DEST_MODULE_LOCATION' does not begin with\"";
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
                    do {
    my $__echo_line = "$\"'/kernel', '/updates', or '/extra' in record #$index.\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                };
                                $return_value = q{1};
            }
    }
if (eval { int($array_size == 0) } // "") {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "$\"dkms.conf: Warning! Zero modules specified.\"";
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
    if (!((${MAKE_MATCH[0]} ne q{}))) {
                my $make_command;
        my @make_command;
        my %make_command;
        $make_command = $MAKE[0];
    }
    for (eval { int($index=0) } // ""; eval { int($index < 0) } // ""; eval { int($index++) } // "") {
            if (0) {
                                $make_command = $MAKE[eval { int($index) } // ""];
                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
    }
    if ((!$make_command)) {
                $make_command = "make -C $ENV{kernel_source_dir} M=$ENV{dkms_tree}/$module/$ENV{module_version}/build";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ((!$clean)) {
                $clean = "make -C $ENV{kernel_source_dir} M=$ENV{dkms_tree}/$module/$ENV{module_version}/build clean";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
if ((-e $kernel_source_dir/vmlinux)) {
if (!(        # Original bash: readelf -p .comment $kernel_source_dir/vmlinux | grep -q clang;
{
            my $output_30 = q{};
            my $output_printed_30;
            my $pipeline_success_30 = 1;
                        my ($in_31, $out_31);
            my $pid_31 = open3($in_31, $out_31, '>&STDERR', 'readelf', '-p', '.comment', '/vmlinux');
            close $in_31 or croak 'Close failed: $OS_ERROR';
            $output_30 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_31> };
            close $out_31 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_31, 0;

                        my $grep_result_30_1;
            my @grep_lines_30_1 = split /\n/msx, $output_30;
            my @grep_filtered_30_1 = grep { /clang/msx } @grep_lines_30_1;
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
            })) {
            $make_command = ${make_command} . " CC=clang";
        }
if (!(        # Original bash: readelf -p .comment $kernel_source_dir/vmlinux | grep -q LLD;
{
            my $output_32 = q{};
            my $output_printed_32;
            my $pipeline_success_32 = 1;
                        my ($in_33, $out_33);
            my $pid_33 = open3($in_33, $out_33, '>&STDERR', 'readelf', '-p', '.comment', '/vmlinux');
            close $in_33 or croak 'Close failed: $OS_ERROR';
            $output_32 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_33> };
            close $out_33 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_33, 0;

                        my $grep_result_32_1;
            my @grep_lines_32_1 = split /\n/msx, $output_32;
            my @grep_filtered_32_1 = grep { /LLD/msx } @grep_lines_32_1;
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
            })) {
            $make_command = ${make_command} . " LD=ld.lld";
        }
}
    else {
        if ((-e "${kernel_config}")) {
if (!(my $grep_result_34;
my @grep_lines_34 = ();
my @grep_filenames_34 = ();
if (-e "=") {
    open my $fh, '<', "=" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_34, $line;
        push @grep_filenames_34, "=";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: =: No such file or directory\n"; }
if (-e "y") {
    open my $fh, '<', "y" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_34, $line;
        push @grep_filenames_34, "y";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: y: No such file or directory\n"; }
my @grep_filtered_34 = grep { /CONFIG_CC_IS_CLANG/msx } @grep_lines_34;
$grep_result_34 = join "\n", @grep_filtered_34;
            if (!($grep_result_34 =~ m{\n\z}msx || $grep_result_34 eq q{})) {
                $grep_result_34 .= "\n";
            }
$CHILD_ERROR = scalar @grep_filtered_34 > 0 ? 0 : 1;
$grep_result_34 = q{})) {
                $make_command = ${make_command} . " CC=clang";
            }
if (!(my $grep_result_35;
my @grep_lines_35 = ();
my @grep_filenames_35 = ();
if (-e "=") {
    open my $fh, '<', "=" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_35, $line;
        push @grep_filenames_35, "=";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: =: No such file or directory\n"; }
if (-e "y") {
    open my $fh, '<', "y" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_35, $line;
        push @grep_filenames_35, "y";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: y: No such file or directory\n"; }
my @grep_filtered_35 = grep { /CONFIG_LD_IS_LLD/msx } @grep_lines_35;
$grep_result_35 = join "\n", @grep_filtered_35;
            if (!($grep_result_35 =~ m{\n\z}msx || $grep_result_35 eq q{})) {
                $grep_result_35 .= "\n";
            }
$CHILD_ERROR = scalar @grep_filtered_35 > 0 ? 0 : 1;
$grep_result_35 = q{})) {
                $make_command = ${make_command} . " LD=ld.lld";
            }
        }
    }
    my $count;
    my @count;
    my %count;
    $count = q{0};
    for (eval { int($index=0) } // ""; eval { int($index < 0) } // ""; eval { int($index++) } // "") {
if (((${PATCH[$index]} ne q{}) && (((!${PATCH_MATCH[$index]}) || $ENV{1} =~ /${PATCH_MATCH[$index]})/msx))) {
                $patch_array{"$count"} = $PATCH[eval { int($index) } // ""];
                $count = eval { int($count+1) } // "";
            }
    }
    if ((($BUILD_EXCLUSIVE_KERNEL ne q{}) && !$1 =~ /$BUILD_EXCLUSIVE_KERNEL/msx)) {
                my $build_exclude;
        my @build_exclude;
        my %build_exclude;
        $build_exclude = "yes";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ((($BUILD_EXCLUSIVE_KERNEL_MIN ne q{}) && (qx'VER "$1"'"<"qx'VER "$BUILD_EXCLUSIVE_KERNEL_MIN"' ne q{}))) {
                $build_exclude = "yes";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ((($BUILD_EXCLUSIVE_KERNEL_MAX ne q{}) && (qx'VER "$1"'">"qx'VER "$BUILD_EXCLUSIVE_KERNEL_MAX"' ne q{}))) {
                $build_exclude = "yes";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ((($BUILD_EXCLUSIVE_ARCH ne q{}) && !$2 =~ /$BUILD_EXCLUSIVE_ARCH/msx)) {
                $build_exclude = "yes";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
if ((($BUILD_EXCLUSIVE_CONFIG ne q{}) && (-e "${kernel_config}"))) {
        my $kconf;
        for my $kconf ($BUILD_EXCLUSIVE_CONFIG) {
if ("$kconf" =~ /^!.*$/msx) {
                                if (do {
                                        my $grep_result_36;
                    my @grep_lines_36 = ();
                    my @grep_filtered_36 = grep { /^"\ .\ (${kconf}\ =~\ s\/^!\/\/r\ =~\ s\/^!\/\/r)\ .\ "=[ym]/msx } @grep_lines_36;
                    $grep_result_36 = join "\n", @grep_filtered_36;
                                        if (!($grep_result_36 =~ m{\n\z}msx || $grep_result_36 eq q{})) {
                                            $grep_result_36 .= "\n";
                                        }
                    $CHILD_ERROR = scalar @grep_filtered_36 > 0 ? 0 : 1;
                    $grep_result_36 = q{};
                    $CHILD_ERROR == 0
                }) {
                                        $build_exclude = "yes";
                }
            } elsif (1) {
                                my $grep_result_37;
my @grep_lines_37 = ();
my @grep_filtered_37 = grep { /^"\ .\ ${kconf}\ .\ "=[ym]/msx } @grep_lines_37;
$grep_result_37 = join "\n", @grep_filtered_37;
                if (!($grep_result_37 =~ m{\n\z}msx || $grep_result_37 eq q{})) {
                    $grep_result_37 .= "\n";
                }
$CHILD_ERROR = scalar @grep_filtered_37 > 0 ? 0 : 1;
$grep_result_37 = q{};
                if ($CHILD_ERROR != 0) {
                                        $build_exclude = "yes";
                }
            }
        }
    }
    if (!(($clean ne q{}))) {
                $clean = "make clean";
    }
    if (do {
if (do {
$CHILD_ERROR = ($main_exit_code = eval { int($return_value == 0) } // "") ? 0 : 1;
    $CHILD_ERROR == 0
}) {
        my $last_mvka;
    my @last_mvka;
    my %last_mvka;
    $last_mvka = "$module/$ENV{module_version}/$_[0]/$_[1]";
}
        $CHILD_ERROR == 0
    }) {
                my $last_mvka_conf;
        my @last_mvka_conf;
        my %last_mvka_conf;
        $last_mvka_conf = (do { my $_chomp_temp = do {
    my ($in_38, $out_38);
    my $pid_38 = open3($in_38, $out_38, '>&STDERR', 'readlink', '-f', "$read_conf_file");
    close $in_38 or croak 'Close failed: $OS_ERROR';
    my $result_38 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_38> };
    close $out_38 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_38, 0;
    $result_38
}; chomp $_chomp_temp; $_chomp_temp; });
    }
return $return_value;
    return;
}

sub read_framework_conf {
    my $i;
    for my $i ('/etc/dkms/framework.conf', '/etc/dkms/framework.conf.d/*.conf') {
        if ((-e "$i")) {
                        safe_source("$i", "@ARGV");
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
    }
    return;
}

sub get_module_verinfo {
    my $ver;
    my $srcver;
    my $checksum;
    my $vals = q{};
    my $temp_file_ps_fh_2 = q{/tmp} . '/process_sub_fh_2.tmp';
    my $output_ps_fh_2;
    {
    my ($in, $out);
    my $pid = open3($in, $out, '>&STDERR', 'bash', '-c', 'modinfo "$1"');
    close $in or croak 'Close failed: $OS_ERROR';
    $output_ps_fh_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
$CHILD_ERROR = $? >> 8;
    }
    use File::Path qw(make_path);
    my $temp_dir_fh_2 = dirname($temp_file_ps_fh_2);
    if (!-d $temp_dir_fh_2) { make_path($temp_dir_fh_2); }
    open my $fh_ps_fh_2, '>', $temp_file_ps_fh_2 or croak "Cannot create temp file: $ERRNO\n";
    print {$fh_ps_fh_2} $output_ps_fh_2;
    close $fh_ps_fh_2 or croak "Close failed: $ERRNO\n";
    open STDIN, '<', $temp_file_ps_fh_2 or croak "Cannot open process substitution: $ERRNO\n";
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $vals = $_fields[0] // q{};
if ($vals[0] =~ /^version:$/msx) {
                        $ver = $vals[1];
                        $checksum = $vals[2];
        } elsif ($vals[0] =~ /^srcversion:$/msx) {
                        $srcver = $vals[1];
        }
    }
    print '-E' . q{ } . ${ver} . "\n";
    $CHILD_ERROR = 0;
    print '-E' . q{ } . (defined ${srcver} && ${srcver} ne q{} ? ${srcver} : '$checksum') . "\n";
    $CHILD_ERROR = 0;
    return;
}

sub compare_module_version {
    $main_exit_code = system('readarray', '-t', 'ver1') >> 8;
    $main_exit_code = system('readarray', '-t', 'ver2') >> 8;
if ("${ver1[0]}" eq "${ver2[0]}") {
if ("${ver1[1]}" eq "${ver2[1]}") {
            print "==\n";
}
        else {
            print "=\n";
        }
return q{0};
}
    else {
        if (((!"$ver1") || (!"$ver2"))) {
            print "?\n";
}
        else {
            if ((qx'VER "${ver1[0]}"'">"qx'VER "${ver2[0]}"' ne q{})) {
                print ">\n";
}
            else {
                print "<\n";
            }
        }
    }
return q{1};
    return;
}

sub check_version_sanity {
    my $lib_tree = "$ENV{install_tree}/$_[0]";
    my $res = q{};
    do {
    my $__echo_line = "$\"Running module version sanity check.\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    my $i = "0";
if ("$3" ne q{}) {
        my @obs = ('${3//-/', '}');
        my @my = ('${1//-/', '}');
        my $obsolete = "0";
if (((${obs} ne q{}) && (${my} ne q{}))) {
if (($(VER ${obs}) =~ /[$][(]VER\ [$]{my}[)]/msx && (!$force))) {
if ((!${obs[1]})) {
                    $obsolete = q{1};
}
                else {
                    if ((qx'VER ${my[1]}'>qx'VER ${obs[1]}' ne q{})) {
                        $obsolete = q{1};
}
                    else {
                        if ($(VER ${my[1]}) eq $(VER ${obs[1]})) {
                            $obsolete = q{1};
                        }
                    }
                }
}
            else {
                if (((qx'VER ${my}'>qx'VER ${obs}' ne q{}) && (!$force))) {
                    $obsolete = q{1};
                }
            }
        }
if (eval { int($obsolete == 1) } // "") {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "$\"\"";
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
                do {
    my $__echo_line = "$\"Module has been obsoleted due to being included\"";
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
                do {
    my $__echo_line = "$\"in kernel $_[2].  We will avoid installing\"";
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
                do {
    my $__echo_line = "$\"for future kernels above $_[2].\"";
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
                do {
    my $__echo_line = "$\"You may override by specifying --force.\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
            };
return q{1};
        }
    }
    set_module_suffix("$_[0]");
    my $temp_file_ps_fh_3 = q{/tmp} . '/process_sub_fh_3.tmp';
    my $output_ps_fh_3;
    {
    my ($in, $out);
    my $pid = open3($in, $out, '>&STDERR', 'bash', '-c', 'find_module "$lib_tree" "${4}"');
    close $in or croak 'Close failed: $OS_ERROR';
    $output_ps_fh_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
$CHILD_ERROR = $? >> 8;
    }
    use File::Path qw(make_path);
    my $temp_dir_fh_3 = dirname($temp_file_ps_fh_3);
    if (!-d $temp_dir_fh_3) { make_path($temp_dir_fh_3); }
    open my $fh_ps_fh_3, '>', $temp_file_ps_fh_3 or croak "Cannot create temp file: $ERRNO\n";
    print {$fh_ps_fh_3} $output_ps_fh_3;
    close $fh_ps_fh_3 or croak "Close failed: $ERRNO\n";
    open STDIN, '<', $temp_file_ps_fh_3 or croak "Cannot open process substitution: $ERRNO\n";
$kernels_module = <>;
chomp $kernels_module;
$CHILD_ERROR = defined($kernels_module) ? 0 : 1;
    if ($kernels_module eq q{}) {
        return q{0};        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
if ("$force_version_override" =~ /"true"/msx) {
return q{0};
    }
if ((${kernels_module[1]} ne q{})) {
        $main_exit_code = system('warn', "$\"Warning! Cannot do version sanity checking because multiple " . $_[3] . "$ENV{module_suffix}\"", "$\"modules were found in kernel $_[0].\"") >> 8;
return q{0};
    }
    my $dkms_module = do {
    my ($in_42, $out_42);
    my $pid_42 = open3($in_42, $out_42, '>&STDERR', 'compressed_or_uncompressed', "$ENV{dkms_tree}/$module/$ENV{module_version}/$_[0]/$_[1]/module/", $_[3]);
    close $in_42 or croak 'Close failed: $OS_ERROR';
    my $result_42 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_42> };
    close $out_42 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_42, 0;
    $result_42
};
    my $cmp_res = (do { my $_chomp_temp = do {
    my ($in_43, $out_43);
    my $pid_43 = open3($in_43, $out_43, '>&STDERR', 'compare_module_version', ($ENV{kernels_module} // q{}), ${dkms_module});
    close $in_43 or croak 'Close failed: $OS_ERROR';
    my $result_43 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_43> };
    close $out_43 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_43, 0;
    $result_43
}; chomp $_chomp_temp; $_chomp_temp; });
if ("${cmp_res}" eq ">") {
if ((!"$force")) {
            $main_exit_code = system('error', "$\"Module version $(get_module_verinfo \"", $dkms_module, " | head -n 1) for $_[3]" . ($ENV{module_suffix} // q{}), "$\"is not newer than what is already found in kernel $_[0] ($(get_module_verinfo \"", $kernels_module, " | head -n 1)).", "$\"You may override by specifying --force.\"") >> 8;
return q{1};
        }
}
    else {
        if ("${cmp_res}"=" =~ /"/msx) {
if ((!"$force")) {
                my $verinfo = (do { my $_chomp_temp = do {
    my ($in_44, $out_44);
    my $pid_44 = open3($in_44, $out_44, '>&STDERR', 'get_module_verinfo', ${dkms_module});
    close $in_44 or croak 'Close failed: $OS_ERROR';
    my $result_44 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_44> };
    close $out_44 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_44, 0;
    $result_44
}; chomp $_chomp_temp; $_chomp_temp; });
if (((-d "$(echo "$verinfo" | tr '[:space:]')") || !(                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
                    my $tmp = do {
                    my $diff_output = q{};
                    {
                        my $diff_cmd = 'diff';
                        my @diff_args = (($ENV{kernels_module} // q{}), ${dkms_module});
                        my $diff_pid = open my $diff_fh, q{-|}, $diff_cmd, @diff_args;
                        if ($diff_pid) {
                            local $INPUT_RECORD_SEPARATOR = undef;
                            $diff_output = <$diff_fh>;
                            close $diff_fh;
                            $CHILD_ERROR = $? >> 8;
                        } else {
                            carp "Cannot execute diff command: $OS_ERROR";
                            $diff_output = q{};
                            $CHILD_ERROR = 1;
                        }
                    }
                    $diff_output;
                    };
                    print $tmp;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                }))) {
                    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                        do {
    my $__echo_line = "$\"Module version $(echo \"" . q{ } . $verinfo . q{ } . " | head -n 1) for $_[3]" . ($ENV{module_suffix} // q{});
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
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
                        do {
    my $__echo_line = "$\"exactly matches what is already found in kernel $_[0].\"";
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
                        do {
    my $__echo_line = "$\"DKMS will not replace this module.\"";
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
                        do {
    my $__echo_line = "$\"You may override by specifying --force.\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                        $CHILD_ERROR = 0;
                    };
return q{1};
                }
            }
        }
    }
return q{0};
    return;
}

sub check_module_args {
    my ($file) = @_;
    if ((($module ne q{}) && ($module_version ne q{}))) {
        return;        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    die(q{1}, "$\"Arguments <module> and <module-version> are not specified.\"", "$\"Usage: $_[0] <module>/<module-version> or\"", "$\"       $_[0] -m <module>/<module-version> or\"", "$\"       $_[0] -m <module> -v <module-version>\"");
    return;
}

sub read_conf_or_die {
    if (do {
read_conf("@ARGV");
        $CHILD_ERROR == 0
    }) {
        return;    }
    die(q{8}, "$\"Bad conf file.\"", "$\"File: " . (defined (defined $_[2] && $_[2] ne q{} ? $_[2] : '$conf') && (defined $_[2] && $_[2] ne q{} ? $_[2] : '$conf') ne q{} ? (defined $_[2] && $_[2] ne q{} ? $_[2] : '$conf') : '$conf') . " does not represent a valid dkms.conf file.\"");
    return;
}

sub run_build_script {
    my $script_type;
    my $run;
    if (!(($2 ne q{}))) {
        return q{0};    }
if ("$_[0]" =~ /^pre_build$/msx or "$_[0]" =~ /^post_build$/msx) {
                $script_type = 'build';
    } elsif (1) {
                $script_type = 'source';
    }
    $run = "$ENV{dkms_tree}/$module/$ENV{module_version}/$script_type/$_[1]";
if ((-x ${run%% *})) {
        do {
    my $__echo_line = "$\"\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        do {
    my $__echo_line = "$\"Running the $_[0] script:\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        do {
            local %ENV = %ENV;
            my $run = $run;
            my $script_type = $script_type;
                chdir("$ENV{dkms_tree}/$module/$ENV{module_version}/$script_type/");
                $CHILD_ERROR = 0;
# Builtin command 'exec' not implemented
            q{};
        };
}
    else {
        do {
    my $__echo_line = "$\"\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        $main_exit_code = system('warn', "$\"The $_[0] script is not executable.\"") >> 8;
    }
    return;
}

sub add_module {
    my ($file) = @_;
if (0) {
        $main_exit_code = system('bash', 'load_tarball') >> 8;
}
    else {
        if (0) {
            $main_exit_code = system('add_source_tree', "$ENV{try_source_tree}") >> 8;
        }
    }
    check_module_args('add');
if (($rpm_safe_upgrade ne q{})) {
        my $pppid = do { my @_qx_cmd = (q(awk '/PPid:/ {print $2}' /proc/ $PPID /status)); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
        my $lock_name = do {
    my ($in_46, $out_46);
    my $pid_46 = open3($in_46, $out_46, '>&STDERR', 'mktemp_or_die', $tmp_location, '/dkms_rpm_safe_upgrade_lock.', "$pppid.XXXXXX");
    close $in_46 or croak 'Close failed: $OS_ERROR';
    my $result_46 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_46> };
    close $out_46 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_46, 0;
    $result_46
};
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $lock_name
      or die "Cannot open file: $OS_ERROR\n";
            do {
    my $__echo_line = "$module-$ENV{module_version}";
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
            open STDOUT, '>>', $lock_name
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('/bin/ps', '-o', 'lstart', '--no-headers', '-p', $pppid) >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
if (!(    $main_exit_code = system('is_module_added', "$module", "$ENV{module_version}") >> 8)) {
        die(q{3}, "$\"DKMS tree already contains: $module-$ENV{module_version}\"", "$\"You cannot add the same module/version combo more than once.\"");
    }
    if (!(($conf ne q{}))) {
                my $conf;
        my @conf;
        my %conf;
        $conf = "$ENV{source_tree}/$module-$ENV{module_version}/dkms.conf";
    }
if (!(!((-d $source_tree/$module-$module_version)))) {
        die(q{2}, "$\"Could not find module source directory.\"", "$\"Directory: $ENV{source_tree}/$module-$ENV{module_version} does not exist.\"");
    }
    read_conf_or_die("$kernelver", "$arch", "$conf");
    do {
    my $__echo_line = "$\"Creating symlink $ENV{dkms_tree}/$module/$ENV{module_version}/source -> $ENV{source_tree}/$module-$ENV{module_version}\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    use File::Path qw(make_path);
    my $err;
    if ( !-d "$ENV{dkms_tree}/$module/$ENV{module_version}/build" ) {
        make_path( "$ENV{dkms_tree}/$module/$ENV{module_version}/build", { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . "$ENV{dkms_tree}/$module/$ENV{module_version}/build" . ": $err->[0]\n";
        }
    }
symlink "$ENV{source_tree}/$module-$ENV{module_version}", "$ENV{dkms_tree}/$module/$ENV{module_version}/source" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    run_build_script('post_add', "$ENV{post_add}");
    return;
}

sub prepare_kernel {
    my ($file) = @_;
    set_kernel_source_dir_and_kconfig("$_[0]");
        _check_kernel_dir("$_[0]");
    if ($CHILD_ERROR != 0) {
                    die(q{1}, "$\"Your kernel headers for kernel $_[0] cannot be found at /lib/modules/$_[0]/build or /lib/modules/$_[0]/source.\"", "$\"Please install the linux-headers-$_[0] package or use the --kernelsourcedir option to tell DKMS where it's located.\"");
    }
    return;
}

sub prepare_signing {
    my $do_signing;
    my @do_signing;
    my %do_signing;
    $do_signing = q{0};
if ((!-f "${kernel_config}")) {
        do {
    my $__echo_line = "Kernel config " . ($ENV{kernel_config} // q{}) . " not found, modules won't be signed";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
return;
    }
if (!(!(my $grep_result_49;
my @grep_lines_49 = ();
my @grep_filtered_49 = grep { /^CONFIG_MODULE_SIG_HASH=/msx } @grep_lines_49;
$grep_result_49 = join "\n", @grep_filtered_49;
    if (!($grep_result_49 =~ m{\n\z}msx || $grep_result_49 eq q{})) {
        $grep_result_49 .= "\n";
    }
$CHILD_ERROR = scalar @grep_filtered_49 > 0 ? 0 : 1;
$grep_result_49 = q{};))) {
        print "The kernel is be built without module signing facility, modules won't be signed\n";
return;
    }
    my $sign_hash;
    my @sign_hash;
    my %sign_hash;
    $sign_hash = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_50 = q{};
    my $output_printed_50;
    my $output_51 = q{};
    while (my $line = <>) {
        chomp $line;
                if (!($line =~ /^CONFIG_MODULE_SIG_HASH=/msx)) {
            next;
        }
        my @fields = split /=/msx, $line;
if (@fields > 1) {
    $line = $fields[1];
}
        $line =~ "s/\"//g";
    }
    $output_51; };
}; $_pipeline_result; };
    read_framework_conf($dkms_framework_signing_variables);
if ((!"${sign_file}")) {
if ("$ENV{running_distribution}" =~ /^debian.*$/msx) {
                        my $sign_file;
            my @sign_file;
            my %sign_file;
            $sign_file = "/usr/lib/linux-kbuild-" . (scalar reverse( (scalar reverse ${kernelver}) =~ s/^.*?\.//r ) =~ s/\..*?$//r) . "/scripts/sign-file";
        } elsif ("$ENV{running_distribution}" =~ /^ubuntu.*$/msx) {
                        $sign_file = (do { my $_chomp_temp = do {
    my ($in_52, $out_52);
    my $pid_52 = open3($in_52, $out_52, '>&STDERR', 'command', '-v', 'kmodsign');
    close $in_52 or croak 'Close failed: $OS_ERROR';
    my $result_52 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_52> };
    close $out_52 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_52, 0;
    $result_52
}; chomp $_chomp_temp; $_chomp_temp; });
            if ((!-x "${sign_file}")) {
                $sign_file = "/usr/src/linux-headers-$kernelver/scripts/sign-file";
            }
        }
if ((!-f "${sign_file}")) {
            $sign_file = "/lib/modules/$kernelver/build/scripts/sign-file";
        }
    }
    do {
    my $__echo_line = "Sign command: $sign_file";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
if (((!-f "${sign_file}") || (!-x "${sign_file}"))) {
        do {
    my $__echo_line = "Binary " . ${sign_file} . " not found, modules won't be signed";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
return;
    }
if ("${mok_signing_key}" eq q{}) {
if ("$ENV{running_distribution}" =~ /^ubuntu.*$/msx) {
                        my $mok_signing_key;
            my @mok_signing_key;
            my %mok_signing_key;
            $mok_signing_key = "/var/lib/shim-signed/mok/MOK.priv";
                        my $mok_certificate;
            my @mok_certificate;
            my %mok_certificate;
            $mok_certificate = "/var/lib/shim-signed/mok/MOK.der";
            if (((!-f "${mok_signing_key}") || (!-f "${mok_certificate}"))) {
if ((!-x "qx'command -v update-secureboot-policy'" ne q{})) {
                    print "Binary update-secureboot-policy not found, modules won't be signed\n";
return;
                }
if ((-f "${mok_certificate}")) {
if ( -e "${mok_certificate}" ) {
                        if ( -d "${mok_certificate}" ) {
                            carp "rm: carping: ", ${mok_certificate},
          " is a directory (use -r to remove recursively)\n";
                        }
                        else {
                            if ( unlink "${mok_certificate}" ) {
                                                            }
                            else {
                                carp "rm: carping: could not remove ", ${mok_certificate},
              ": $OS_ERROR\n";
                            }
                        }
                    }
                    else {
                        local $CHILD_ERROR = 0;
                    }
                }
                print "Certificate or key are missing, generating them using update-secureboot-policy...\n";
                    my $SHIM_NOTRIGGER = q{y};
                    do {
                        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
                        my $tmp = do {
                        $main_exit_code = system('update-secureboot-policy', '--new-key') >> 8;
                        };
                        print $tmp;
                        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                    };
                $main_exit_code = system('update-secureboot-policy', '--enroll-key') >> 8;
            }
        }
    }
if ((!"${mok_signing_key}")) {
        $mok_signing_key = "/var/lib/dkms/mok.key";
    }
    do {
    my $__echo_line = "Signing key: $mok_signing_key";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
if ((!"${mok_certificate}")) {
        $mok_certificate = "/var/lib/dkms/mok.pub";
    }
    do {
    my $__echo_line = "Public certificate (MOK): $mok_certificate";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
if (("$mok_signing_key" ne "pkcs11:"* && !(    do {
        local %ENV = %ENV;
        my $SHIM_NOTRIGGER = $SHIM_NOTRIGGER;
        my $do_signing = $do_signing;
        my $mok_certificate = $mok_certificate;
        my $sign_hash = $sign_hash;
        my $sign_file = $sign_file;
        my $mok_signing_key = $mok_signing_key;
        if (!((!-f "$mok_signing_key"))) {
            (!-f "$mok_certificate")        }
        q{};
    }))) {
        print "Certificate or key are missing, generating self signed certificate for MOK...\n";
if (!(!(do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('command', '-v', 'openssl') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };))) {
            print "openssl not found, can't generate key and certificate.\n";
return;
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('openssl', 'req', '-ne', q{w}, '-x', '509', '-n', 'odes', '-d', 'ays', '36500', '-s', 'ubj', "/CN=DKMS module signing key", '-ne', 'wkey', 'rsa:2048', '-k', 'eyout', "$mok_signing_key", '-outform', 'DER', '-out', "$mok_certificate") >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
if ((!-f "${mok_signing_key}")) {
            do {
    my $__echo_line = "Key file " . ${mok_signing_key} . " not found and can't be generated, modules won't be signed";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
return;
        }
    }
if ((!-f "${mok_certificate}")) {
        do {
    my $__echo_line = "Certificate file " . ${mok_certificate} . " not found and can't be generated, modules won't be signed";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
return;
    }
    $do_signing = q{1};
    return;
}

sub prepare_build {
        $main_exit_code = system('is_module_added', "$module", "$ENV{module_version}") >> 8;
    if ($CHILD_ERROR != 0) {
                add_module();
    }
    my $base_dir = "$ENV{dkms_tree}/$module/$ENV{module_version}/$kernelver/$arch";
    my $build_dir = "$ENV{dkms_tree}/$module/$ENV{module_version}/build";
    my $source_dir = "$ENV{dkms_tree}/$module/$ENV{module_version}/source";
    if ((-d $base_dir)) {
                die(q{3}, "$\"This module/version has already been built on: $kernelver\"", "$\"Directory $base_dir already exists. Use the dkms remove function before trying to build again.\"");
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    set_module_suffix("$kernelver");
    read_conf_or_die("$kernelver", "$arch");
    if (($build_exclude ne q{})) {
                die('77', "$\"The $base_dir/dkms.conf for module $module includes a BUILD_EXCLUSIVE directive which does not match this kernel/arch/config.\"", "$\"This indicates that it should not be built.\"");
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if (do {
$CHILD_ERROR = ($main_exit_code = eval { int(do { chomp(my $_r = qx'ls $source_dir | wc -l | awk {'\''print $1'\''}'); $_r; } < 2) } // "") ? 0 : 1;
        $CHILD_ERROR == 0
    }) {
                die(q{8}, "$\"The directory $source_dir does not appear to have module source located within it.\"", "$\"Build halted.\"");
    }
if ( -e "$build_dir" ) {
        if ( -d "$build_dir" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("$build_dir", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", "$build_dir", ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "$build_dir" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$build_dir",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    use File::Copy qw(copy);
    if ( -e "$source_dir/" ) {
        if ( -d "$build_dir" ) {
            require File::Copy; File::Copy::copy("$source_dir/", "$build_dir" . '/' . ("$source_dir/" =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy("$source_dir/", "$build_dir");
        }
    } else {
        croak "cp: cannot stat '-a': No such file or directory\n";
    }
    chdir("$build_dir");
    $CHILD_ERROR = 0;
    my $p;
    for my $p (@patch_array) {
        if ((!-e $build_dir/patches/$p)) {
                        $main_exit_code = system('report_build_problem', q{5}, "$\" Patch $p as specified in dkms.conf cannot be\"", "$\"found in $build_dir/patches/.\"") >> 8;
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
                invoke_command("patch -p1 < ./patches/$p", "applying patch $p");
        if ($CHILD_ERROR != 0) {
                        $main_exit_code = system('report_build_problem', q{6}, "$\"Application of patch $p failed.\"", "$\"Check $build_dir for more information.\"") >> 8;
        }
    }
if ((-e "${kernel_config}")) {
if (!(my $grep_result_54;
my @grep_lines_54 = ();
my @grep_filtered_54 = grep { /CONFIG_CC_IS_CLANG=y/msx } @grep_lines_54;
$grep_result_54 = join "\n", @grep_filtered_54;
        if (!($grep_result_54 =~ m{\n\z}msx || $grep_result_54 eq q{})) {
            $grep_result_54 .= "\n";
        }
$CHILD_ERROR = scalar @grep_filtered_54 > 0 ? 0 : 1;
$grep_result_54 = q{})) {
            my $cc = "clang";
if (!(            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
                $main_exit_code = system('command', '-v', "$cc") >> 8;
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            })) {
$ENV{CC} = '';
$ENV{KERNEL_CC} = '';
            }
        }
if (!(my $grep_result_55;
my @grep_lines_55 = ();
my @grep_filtered_55 = grep { /CONFIG_LD_IS_LLD=y/msx } @grep_lines_55;
$grep_result_55 = join "\n", @grep_filtered_55;
        if (!($grep_result_55 =~ m{\n\z}msx || $grep_result_55 eq q{})) {
            $grep_result_55 .= "\n";
        }
$CHILD_ERROR = scalar @grep_filtered_55 > 0 ? 0 : 1;
$grep_result_55 = q{})) {
            my $ld = "ld.lld";
if (!(            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
                $main_exit_code = system('command', '-v', "$ld") >> 8;
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            })) {
$ENV{LD} = '';
$ENV{KERNEL_LD} = '';
            }
        }
    }
    run_build_script('pre_build', "$ENV{pre_build}");
    return;
}

sub actual_build {
    my $base_dir = "$ENV{dkms_tree}/$module/$ENV{module_version}/$kernelver/$arch";
    my $build_dir = "$ENV{dkms_tree}/$module/$ENV{module_version}/build";
    my $build_log = "$build_dir/make.log";
    do {
    my $__echo_line = "$\"\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "$\"Building module:\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
if ((-f "$kernel_source_dir/.kernelvariables")) {
$ENV{CC} = '';
}
    else {
delete $ENV{CC};
    }
    invoke_command("$ENV{clean}", "Cleaning build area", 'background');
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', "$build_log"
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "$\"DKMS make.log for $module-$ENV{module_version} for kernel $kernelver ($arch)\"";
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
        open STDOUT, '>>', "$build_log"
      or die "Cannot open file: $OS_ERROR\n";
my $date = do {
require POSIX; POSIX::strftime('%a %b %e %H:%M:%S %Z %Y', localtime(time())) . "\n"
};
print $date;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    my $the_make_command = (($ENV{make_command/} // q{}) =~ s/^make/make -j\$parallel_jobs KERNELRELEASE=\$kernelver//r =~ s/^make/make -j\$parallel_jobs KERNELRELEASE=\$kernelver//r);
        invoke_command("{ $the_make_command; } >> $build_log 2>&1", "$the_make_command", 'background');
    if ($CHILD_ERROR != 0) {
                $main_exit_code = system('report_build_problem', '10', "$\"Bad return status for module build on kernel: $kernelver ($arch)\"", "$\"Consult $build_log for more information.\"") >> 8;
    }
    for (eval { int($ENV{count}=0) } // ""; eval { int($ENV{count} < 0) } // ""; eval { int($ENV{count}++) } // "") {
            if ((-e ${built_module_location[$count]}${built_module_name[$count]}$module_uncompressed_suffix)) {
                next;                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
            $main_exit_code = system('report_build_problem', q{7}, "$\" Build of " . $built_module_name[eval { int($count) } // ""] . "$ENV{module_uncompressed_suffix} failed for: $kernelver ($arch)\"", "$\"Make sure the name of the generated module is correct and at the root of the\"", "$\"build directory, or consult make.log in the build directory\"", "$\"$build_dir for more information.\"") >> 8;
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        chdir(q{-});
        $CHILD_ERROR = 0;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    use File::Path qw(make_path);
    my $err;
    if ( !-d "$base_dir/log" ) {
        make_path( "$base_dir/log", { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . "$base_dir/log" . ": $err->[0]\n";
        }
    }
    if (($kernel_config ne q{})) {
                use File::Copy qw(copy);
        if ( -e "$ENV{kernel_config}" ) {
            if ( -d "$base_dir/log/" ) {
                require File::Copy; File::Copy::copy("$ENV{kernel_config}", "$base_dir/log/" . '/' . ("$ENV{kernel_config}" =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy("$ENV{kernel_config}", "$base_dir/log/");
            }
        } else {
            croak "cp: cannot stat '-f': No such file or directory\n";
        }
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
        my $force = 1;
        if ( -e "$build_log" ) {
            my $dest = "$base_dir/log/make.log";
            if ( -e $dest && -d $dest ) {
                my $source_name = "$build_log";
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
            if ( File::Copy::move( "$build_log", $dest ) ) {
            } else {
                croak
  "mv: cannot move "$build_log" to $dest: $ERRNO\n";
            }
        } else {
            croak "mv: "$build_log": No such file or directory\n";
        }
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        use File::Path qw(make_path);
        if ( mkdir "$base_dir/module" ) {
            }
        else {
            croak "mkdir: cannot create directory " . "$base_dir/module" . ": File exists\n";
        }
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    for (eval { int($ENV{count}=0) } // ""; eval { int($ENV{count} < 0) } // ""; eval { int($ENV{count}++) } // "") {
            my $the_module = "$build_dir/" . $built_module_location[eval { int($count) } // ""] . $built_module_name[eval { int($count) } // ""];
            my $built_module = "$the_module$ENV{module_uncompressed_suffix}";
            my $compressed_module = "$the_module$ENV{module_suffix}";
            if (${strip[$count]} ne no) {
                                $main_exit_code = system('strip', '-g', "$built_module") >> 8;
                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
if (eval { int($ENV{do_signing}) } // "") {
                do {
    my $__echo_line = "Signing module $built_module";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                $CHILD_ERROR = 0;
            }
if ("$module_compressed_suffix" eq ".gz") {
                my @results;
if (-f "$built_module") {
my ($in_62);
my $pid_62 = open3($in_62, $out_62, $err_62, 'bash', '-c', 'gzip "$built_module"');
close $in_62 or croak 'Close failed: $OS_ERROR';
my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_62> };
close $out_62 or croak 'Close failed: $OS_ERROR';
waitpid $pid_62, 0;
if ( $CHILD_ERROR == 0 ) {
push @results, "Compressed: "$built_module"";
} else {
push @results, "Failed to compress: "$built_module"";
}
} else {
push @results, "File not found: "$built_module"";
}
 = join "\n", @results;

                if ($CHILD_ERROR != 0) {
                                        $compressed_module = "";
                }
}
            else {
                if ("$module_compressed_suffix" eq ".xz") {
                                        $main_exit_code = system('xz', '-f', "$built_module") >> 8;
                    if ($CHILD_ERROR != 0) {
                                                $compressed_module = "";
                    }
}
                else {
                    if ("$module_compressed_suffix" eq ".zst") {
                                                $main_exit_code = system('zstd', '-q', '-f', '-T0', '-20', '--ultra', "$built_module") >> 8;
                        if ($CHILD_ERROR != 0) {
                                                        $compressed_module = "";
                        }
                    }
                }
            }
if ("$compressed_module" ne q{}) {
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
                    my $tmp = do {
                    use File::Copy qw(copy);
                    if ( -e "$compressed_module" ) {
                        if ( -d "$base_dir/module/" . $dest_module_name[eval { int($count) } // ""] . "$ENV{module_suffix}" ) {
                            require File::Copy; File::Copy::copy("$compressed_module", "$base_dir/module/" . $dest_module_name[eval { int($count) } // ""] . "$ENV{module_suffix}" . '/' . ("$compressed_module" =~ m|([^/]+)$|)[0]);
                        } else {
                            require File::Copy; File::Copy::copy("$compressed_module", "$base_dir/module/" . $dest_module_name[eval { int($count) } // ""] . "$ENV{module_suffix}");
                        }
                    } else {
                        croak "cp: cannot stat '-f': No such file or directory\n";
                    }
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
                    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
                    my $tmp = do {
                    use File::Copy qw(copy);
                    if ( -e "$built_module" ) {
                        if ( -d "$base_dir/module/" . $dest_module_name[eval { int($count) } // ""] . "$ENV{module_uncompressed_suffix}" ) {
                            require File::Copy; File::Copy::copy("$built_module", "$base_dir/module/" . $dest_module_name[eval { int($count) } // ""] . "$ENV{module_uncompressed_suffix}" . '/' . ("$built_module" =~ m|([^/]+)$|)[0]);
                        } else {
                            require File::Copy; File::Copy::copy("$built_module", "$base_dir/module/" . $dest_module_name[eval { int($count) } // ""] . "$ENV{module_uncompressed_suffix}");
                        }
                    } else {
                        croak "cp: cannot stat '-f': No such file or directory\n";
                    }
                    };
                    print $tmp;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
            }
    }
    run_build_script('post_build', "$ENV{post_build}");
    return;
}

sub clean_build {
    chdir("$ENV{dkms_tree}/$module/$ENV{module_version}/build");
    $CHILD_ERROR = 0;
    invoke_command("$ENV{clean}", "Cleaning build area", 'background');
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        chdir(q{-});
        $CHILD_ERROR = 0;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
if ( -e "$ENV{dkms_tree}/$module/$ENV{module_version}/build" ) {
        if ( -d "$ENV{dkms_tree}/$module/$ENV{module_version}/build" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("$ENV{dkms_tree}/$module/$ENV{module_version}/build", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", "$ENV{dkms_tree}/$module/$ENV{module_version}/build", ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "$ENV{dkms_tree}/$module/$ENV{module_version}/build" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$ENV{dkms_tree}/$module/$ENV{module_version}/build",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    return;
}

sub do_build {
    set_kernel_source_dir_and_kconfig("$kernelver");
    prepare_kernel("$kernelver", "$arch");
    prepare_signing();
    prepare_build();
    actual_build();
    clean_build();
    return;
}

sub force_installation {
    my $forced_modules_dir;
    my @forced_modules_dir;
    my %forced_modules_dir;
    $forced_modules_dir = "/usr/share/dkms/modules_to_force_install";
    my $to_force;
    my @to_force;
    my %to_force;
    $to_force = "";
if ((-d $forced_modules_dir)) {
        my $elem;
        for my $elem ($forced_modules_dir, '/*') {
if ((-e $elem)) {
                $to_force = "$to_force " . (do { my $_chomp_temp = do { my $cat_chunk = q{}; if ( open my $fh, '<', $elem ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $elem . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }; chomp $_chomp_temp; $_chomp_temp; });
            }
        }
        for my $elem ($to_force) {
if ("${1}" eq "${elem}") {
                print "force\n";
return q{0};
}
            else {
                if ("${1}_version-override" eq "${elem}") {
                    print "version-override\n";
return q{0};
                }
            }
        }
    }
return q{1};
    return;
}

sub do_install {
        $main_exit_code = system('is_module_built', "$module", "$ENV{module_version}", "$kernelver", "$arch") >> 8;
    if ($CHILD_ERROR != 0) {
                do_build();
    }
    my $base_dir = "$ENV{dkms_tree}/$module/$ENV{module_version}/$kernelver/$arch";
    my $tmp_force;
    my @tmp_force;
    my %tmp_force;
    $tmp_force = "$force";
    my $ret = do {
    my ($in_65, $out_65);
    my $pid_65 = open3($in_65, $out_65, '>&STDERR', 'force_installation', $module);
    close $in_65 or croak 'Close failed: $OS_ERROR';
    my $result_65 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_65> };
    close $out_65 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_65, 0;
    $result_65
};
if ("$ret" =~ /"force"/msx) {
        $force = "true";
        do {
    my $__echo_line = "Forcing installation of $module";
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
        if ("$ret" =~ /"version-override"/msx) {
            my $force_version_override;
            my @force_version_override;
            my %force_version_override;
            $force_version_override = "true";
            do {
    my $__echo_line = "Forcing version override of $module";
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
    if (!((-e $install_tree/$kernelver))) {
                die(q{6}, "$\"The directory $ENV{install_tree}/$kernelver doesn't exist.\"", "$\"You cannot install a module onto a non-existant kernel.\"");
    }
    read_conf_or_die("$kernelver", "$arch");
    if (do {
$main_exit_code = system('is_module_installed', "$module", "$ENV{module_version}", "$kernelver", "$arch") >> 8;
        $CHILD_ERROR == 0
    }) {
                die(q{5}, "$\"This module/version combo is already installed for kernel $kernelver ($arch).\"");
    }
    if (($rpm_safe_upgrade ne q{})) {
                $force = "true";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    my $lib_tree = "$ENV{install_tree}/$kernelver";
    my $any_module_installed;
    my $count;
    for (eval { int($count=0) } // ""; eval { int($count < 0) } // ""; eval { int($count++) } // "") {
            do {
    my $__echo_line = "$\"\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            do {
    my $__echo_line = "$\"" . $dest_module_name[eval { int($count) } // ""] . "$ENV{module_suffix}:\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
if (!(!(check_version_sanity("$kernelver", "$arch", "$ENV{obsolete_by}", $dest_module_name[eval { int($count) } // ""]);))) {
                $any_module_installed = q{1};
next;
            }
if (((!(            $CHILD_ERROR = ($main_exit_code = eval { int($count == 0) } // "") ? 0 : 1) && !(!(run_build_script('pre_install', "$ENV{pre_install}");))) && !(!(($force ne q{}))))) {
                die('101', "$\"pre_install failed, aborting install.\"", "$\"You may override by specifying --force.\"");
            }
            my $m = "dest_module_name[$count]";
            my $installed_modules = do {
    my ($in_66, $out_66);
    my $pid_66 = open3($in_66, $out_66, '>&STDERR', 'find_module', "$lib_tree", "$m");
    close $in_66 or croak 'Close failed: $OS_ERROR';
    my $result_66 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_66> };
    close $out_66 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_66, 0;
    $result_66
};
            my $module_count = "#installed_modules[@]";
            do {
    my $__echo_line = "$\" - Original module\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            my $original_copy = do {
    my ($in_67, $out_67);
    my $pid_67 = open3($in_67, $out_67, '>&STDERR', 'compressed_or_uncompressed', "$ENV{dkms_tree}/$module/original_module/$kernelver/$arch", "$m");
    close $in_67 or croak 'Close failed: $OS_ERROR';
    my $result_67 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_67> };
    close $out_67 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_67, 0;
    $result_67
};
if (((-l $dkms_tree/$module/kernel-$kernelver-$arch) && "$original_copy" ne q{})) {
                do {
    my $__echo_line = "$\"   - An original module was already stored during a previous install\"";
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
                if (!(!((-l $dkms_tree/$module/kernel-$kernelver-$arch)))) {
                    my $archive_pref1 = do {
    my ($in_68, $out_68);
    my $pid_68 = open3($in_68, $out_68, '>&STDERR', 'compressed_or_uncompressed', "$lib_tree/extra", "$m");
    close $in_68 or croak 'Close failed: $OS_ERROR';
    my $result_68 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_68> };
    close $out_68 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_68, 0;
    $result_68
};
                    my $archive_pref2 = do {
    my ($in_69, $out_69);
    my $pid_69 = open3($in_69, $out_69, '>&STDERR', 'compressed_or_uncompressed', "$lib_tree/updates", "$m");
    close $in_69 or croak 'Close failed: $OS_ERROR';
    my $result_69 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_69> };
    close $out_69 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_69, 0;
    $result_69
};
                    my $archive_pref3 = do {
    my ($in_70, $out_70);
    my $pid_70 = open3($in_70, $out_70, '>&STDERR', 'compressed_or_uncompressed', "$lib_tree" . $dest_module_location[eval { int($count) } // ""], "$m");
    close $in_70 or croak 'Close failed: $OS_ERROR';
    my $result_70 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_70> };
    close $out_70 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_70, 0;
    $result_70
};
                    my $archive_pref4 = "";
                    if (do {
$CHILD_ERROR = ($main_exit_code = eval { int($module_count == 1) } // "") ? 0 : 1;
                        $CHILD_ERROR == 0
                    }) {
                                                $archive_pref4 = $installed_modules[0];
                    }
                    my $original_module = "";
                    my $found_orginal = "";
                    for my $original_module ($archive_pref1, $archive_pref2, $archive_pref3, $archive_pref4) {
                        if (!((-f $original_module))) {
                            next;                        }
if ("$ENV{running_distribution}" =~ /^debian.*$/msx or "$ENV{running_distribution}" =~ /^ubuntu.*$/msx) {
                        } elsif (1) {
                                                        do {
    my $__echo_line = "$\"   - Found $original_module\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                            $CHILD_ERROR = 0;
                                                        do {
    my $__echo_line = "$\"   - Storing in $ENV{dkms_tree}/$module/original_module/$kernelver/$arch/\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                            $CHILD_ERROR = 0;
                                                        do {
    my $__echo_line = "$\"   - Archiving for uninstallation purposes\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                            $CHILD_ERROR = 0;
                                                        use File::Path qw(make_path);
                            my $err;
                            if ( !-d "$ENV{dkms_tree}/$module/original_module/$kernelver/$arch" ) {
                                make_path( "$ENV{dkms_tree}/$module/original_module/$kernelver/$arch", { error => \$err } );
                                if ( @{$err} ) {
                                    croak "mkdir: cannot create directory " . "$ENV{dkms_tree}/$module/original_module/$kernelver/$arch" . ": $err->[0]\n";
                                }
                            }
                                                        my $force = 1;
                            if ( -e "$original_module" ) {
                                my $dest = "$ENV{dkms_tree}/$module/original_module/$kernelver/$arch/";
                                if ( -e $dest && -d $dest ) {
                                    my $source_name = "$original_module";
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
                                if ( File::Copy::move( "$original_module", $dest ) ) {
                                } else {
                                    croak
  "mv: cannot move "$original_module" to $dest: $ERRNO\n";
                                }
                            } else {
                                croak "mv: "$original_module": No such file or directory\n";
                            }
                        }
                        my $found_original;
                        my @found_original;
                        my %found_original;
                        $found_original = "yes";
last;
                    }
                    $original_module = $archive_pref4;
if (((!$found_original) && !(                    $CHILD_ERROR = ($main_exit_code = eval { int($module_count > 1) } // "") ? 0 : 1))) {
                        do {
    my $__echo_line = "$\"   - Multiple original modules exist but DKMS does not know which to pick\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                        $CHILD_ERROR = 0;
                        do {
    my $__echo_line = "$\"   - Due to the confusion, none will be considered during a later uninstall\"";
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
                        if ((!$found_original)) {
                            do {
    my $__echo_line = "$\"   - No original module exists within this kernel\"";
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
                else {
                    do {
    my $__echo_line = "$\"   - This kernel never originally had a module by this name\"";
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
if (eval { int($module_count > 1) } // "") {
                do {
    my $__echo_line = "$\" - Multiple same named modules!\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                do {
    my $__echo_line = "$\"   - $module_count named $m$ENV{module_suffix} in $lib_tree/\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
if ("$ENV{running_distribution}" =~ /^debian.*$/msx or "$ENV{running_distribution}" =~ /^ubuntu.*$/msx) {
                } elsif (1) {
                                        do {
    my $__echo_line = "$\"   - All instances of this module will now be stored for reference purposes ONLY\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                                        do {
    my $__echo_line = "$\"   - Storing in $ENV{dkms_tree}/$module/original_module/$kernelver/$arch/collisions/\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                }
                my $module_dup;
                for my $module_dup (do {
    my ($in_73, $out_73);
    my $pid_73 = open3($in_73, $out_73, '>&STDERR', 'find_module', "$lib_tree", "$m");
    close $in_73 or croak 'Close failed: $OS_ERROR';
    my $result_73 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_73> };
    close $out_73 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_73, 0;
    $result_73
}) {
                    my $dup_tree;
                    my @dup_tree;
                    my %dup_tree;
                    $dup_tree = (${module_dup} =~ s/^\$lib_tree//r =~ s/^\$lib_tree//r);
                    my $dup_name;
                    my @dup_name;
                    my %dup_name;
                    $dup_name = ( ( basename(${module_dup}) ) =~ s|^.*/||sr );
                    $dup_tree = $ENV{'dup_tree/${dup_name}'};
if ("$ENV{running_distribution}" =~ /^debian.*$/msx or "$ENV{running_distribution}" =~ /^ubuntu.*$/msx) {
                    } elsif (1) {
                                                do {
    my $__echo_line = "$\"     - Stored $module_dup\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                        $CHILD_ERROR = 0;
                                                use File::Path qw(make_path);
                        if ( !-d "$ENV{dkms_tree}/$module/original_module/$kernelver/$arch/collisions/$dup_tree" ) {
                            make_path( "$ENV{dkms_tree}/$module/original_module/$kernelver/$arch/collisions/$dup_tree", { error => \$err } );
                            if ( @{$err} ) {
                                croak "mkdir: cannot create directory " . "$ENV{dkms_tree}/$module/original_module/$kernelver/$arch/collisions/$dup_tree" . ": $err->[0]\n";
                            }
                        }
                                                if ( -e "$module_dup" ) {
                            my $dest = "$ENV{dkms_tree}/$module/original_module/$kernelver/$arch/collisions/$dup_tree";
                            if ( -e $dest && -d $dest ) {
                                my $source_name = "$module_dup";
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
                            if ( File::Copy::move( "$module_dup", $dest ) ) {
                            } else {
                                croak
  "mv: cannot move "$module_dup" to $dest: $ERRNO\n";
                            }
                        } else {
                            croak "mv: "$module_dup": No such file or directory\n";
                        }
                    }
                }
            }
            do {
    my $__echo_line = "$\" - Installation\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            do {
    my $__echo_line = "$\"   - Installing to $ENV{install_tree}/$kernelver" . $dest_module_location[eval { int($count) } // ""] . "/\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            use File::Path qw(make_path);
            if ( !-d $install_tree ) {
                make_path( $install_tree, { error => \$err } );
                if ( @{$err} ) {
                    croak "mkdir: cannot create directory " . $install_tree . ": $err->[0]\n";
                }
            }
            if ( !-d q{/} ) {
                make_path( q{/}, { error => \$err } );
                if ( @{$err} ) {
                    croak "mkdir: cannot create directory " . q{/} . ": $err->[0]\n";
                }
            }
            if ( !-d $kernelver ) {
                make_path( $kernelver, { error => \$err } );
                if ( @{$err} ) {
                    croak "mkdir: cannot create directory " . $kernelver . ": $err->[0]\n";
                }
            }
            if ( !-d q{} ) {
                make_path( q{}, { error => \$err } );
                if ( @{$err} ) {
                    croak "mkdir: cannot create directory " . q{} . ": $err->[0]\n";
                }
            }
            if (($symlink_modules ne q{})) {
                                my $symlink;
                my @symlink;
                my %symlink;
                $symlink = "-s";
                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
            my $toinstall = do {
    my ($in_77, $out_77);
    my $pid_77 = open3($in_77, $out_77, '>&STDERR', 'compressed_or_uncompressed', "$base_dir/module", "$m");
    close $in_77 or croak 'Close failed: $OS_ERROR';
    my $result_77 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_77> };
    close $out_77 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_77, 0;
    $result_77
};
            use File::Copy qw(copy);
            if ( -e $symlink ) {
                if ( -d "$ENV{install_tree}/$kernelver" . $dest_module_location[eval { int($count) } // ""] . "/" . ( ( basename(${toinstall}) ) =~ s|^.*/||sr ) ) {
                    require File::Copy; File::Copy::copy($symlink, "$ENV{install_tree}/$kernelver" . $dest_module_location[eval { int($count) } // ""] . "/" . ( ( basename(${toinstall}) ) =~ s|^.*/||sr ) . '/' . ($symlink =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy($symlink, "$ENV{install_tree}/$kernelver" . $dest_module_location[eval { int($count) } // ""] . "/" . ( ( basename(${toinstall}) ) =~ s|^.*/||sr ));
                }
            } else {
                croak "cp: cannot stat '-f': No such file or directory\n";
            }
            if ( -e "$toinstall" ) {
                if ( -d "$ENV{install_tree}/$kernelver" . $dest_module_location[eval { int($count) } // ""] . "/" . ( ( basename(${toinstall}) ) =~ s|^.*/||sr ) ) {
                    require File::Copy; File::Copy::copy("$toinstall", "$ENV{install_tree}/$kernelver" . $dest_module_location[eval { int($count) } // ""] . "/" . ( ( basename(${toinstall}) ) =~ s|^.*/||sr ) . '/' . ("$toinstall" =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy("$toinstall", "$ENV{install_tree}/$kernelver" . $dest_module_location[eval { int($count) } // ""] . "/" . ( ( basename(${toinstall}) ) =~ s|^.*/||sr ));
                }
            } else {
                croak "cp: cannot stat '-f': No such file or directory\n";
            }
            $any_module_installed = q{1};
    }
if ((!(    $CHILD_ERROR = ($main_exit_code = eval { int(0 > 0) } // "") ? 0 : 1) && (!"${any_module_installed}"))) {
        die(q{6}, "$\"Installation aborted.\"");
    }
    do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
if ( -e "$ENV{dkms_tree}/$module/kernel-$kernelver-$arch" ) {
            if ( -d "$ENV{dkms_tree}/$module/kernel-$kernelver-$arch" ) {
                carp "rm: carping: ", "$ENV{dkms_tree}/$module/kernel-$kernelver-$arch",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$ENV{dkms_tree}/$module/kernel-$kernelver-$arch" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$ENV{dkms_tree}/$module/kernel-$kernelver-$arch",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    };
    do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
symlink "$ENV{module_version}/$kernelver/$arch", "$ENV{dkms_tree}/$module/kernel-$kernelver-$arch" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    };
if ("$NO_WEAK_MODULES" eq q{}) {
if ((${weak_modules} ne q{})) {
            do {
    my $__echo_line = "$\"Adding any weak-modules\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            # Original bash: list_each_installed_module "$module" "$kernelver" "$arch" | ${weak_modules} ${weak_modules_no_initrd} --add-modules
{
                my $output_80 = q{};
                my $output_printed_80;
                my $pipeline_success_80 = 1;
                                my ($in_81, $out_81);
                my $pid_81 = open3($in_81, $out_81, '>&STDERR', 'list_each_installed_module', );
                close $in_81 or croak 'Close failed: $OS_ERROR';
                $output_80 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_81> };
                close $out_81 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_81, 0;

                                my $cmd_83 = 'unknown_command';
                my ($in_82, $out_82);
                my $pid_82 = open3($in_82, $out_82, '>&STDERR', $cmd_83, '--add-modules');
                print {$in_82} $output_80;
                close $in_82 or croak 'Close failed: $OS_ERROR';
                $output_80 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_82> };
                close $out_82 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_82, 0;
                if ($output_80 ne q{} && !defined $output_printed_80) {
                    print $output_80;
                    if (!($output_80 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_80 ) { $main_exit_code = 1; }
                }
        }
    }
    run_build_script('post_install', "$ENV{post_install}");
        invoke_command("do_depmod $kernelver", "depmod", 'background');
    if ($CHILD_ERROR != 0) {
                    $main_exit_code = system('do_uninstall', "$kernelver", "$arch") >> 8;
            die(q{6}, "$\"Problems with depmod detected. Automatically uninstalling this module.\"", "$\"Install Failed (depmod problems). Module rolled back to built state.\"");
exit 6;
    }
if (($modprobe_on_install ne q{})) {
        # Original bash: find /sys/devices -name modalias -print0 | xargs -0 cat | sort -u | xargs modprobe -a -b -q
{
            my $output_84 = q{};
            my $output_printed_84;
            my $pipeline_success_84 = 1;
                        $output_84 = do {
            require File::Find;
            my @find_results;
            File::Find::find(sub { if ($_ =~ /^modalias$/msx) { push @find_results, $File::Find::name; } }, '/sys/devices');
            my $result = join "\n", @find_results;
            if ($result ne q{}) { $result .= "\n"; }
            $CHILD_ERROR = 0;
            $result;
            };

                        my @xargs_input_84_1 = grep { $_ ne q{} } split /\s+/msx, $output_84;
            my @xargs_output_84_1;
            for my $i (0..scalar @xargs_input_84_1-1) {
            my @xargs_args_84_1;
            for my $j (0..1-1) {
            push @xargs_args_84_1, $xargs_input_84_1[$i + $j];
            }
            my ($in_84_1, $out_84_1, $err_84_1);
            my $cmd_xargs_84_1 = 'cat';
            my $pid_84_1 = open3($in_84_1, $out_84_1, $err_84_1, $cmd_xargs_84_1, @xargs_args_84_1);
            close $in_84_1 or croak 'Close failed: $OS_ERROR';
            my $xargs_result_84_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_84_1> };
            close $out_84_1 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_84_1, 0;
            chomp $xargs_result_84_1;
            push @xargs_output_84_1, $xargs_result_84_1;
            }
            my $xargs_result_84_1 = join "\n", @xargs_output_84_1;
            if ($xargs_result_84_1 ne q{} && !( $xargs_result_84_1 =~ m{\n\z}msx )) { $xargs_result_84_1 .= "\n"; }
            $output_84 = $xargs_result_84_1;
            $output_84 = $xargs_result_84_1;

                        my @sort_lines_84_2 = split /\n/msx, $output_84;
            my @sort_sorted_84_2 = sort @sort_lines_84_2;
            my $output_84_2 = join "\n", @sort_sorted_84_2;
            if ($output_84_2 ne q{} && !($output_84_2 =~ m{\n\z}msx)) {
            $output_84_2 .= "\n";
            }
            $output_84 = $output_84_2;
            $output_84 = $output_84_2;

                        my @xargs_input_84_3 = grep { $_ ne q{} } split /\s+/msx, $output_84;
            my @xargs_output_84_3;
            for my $i (0..scalar @xargs_input_84_3-1) {
            my @xargs_args_84_3;
            for my $j (0..1-1) {
            push @xargs_args_84_3, $xargs_input_84_3[$i + $j];
            }
            my ($in_84_3, $out_84_3, $err_84_3);
            my $cmd_xargs_84_3 = 'modprobe';
            my $pid_84_3 = open3($in_84_3, $out_84_3, $err_84_3, $cmd_xargs_84_3, '-a', '-b', '-q', @xargs_args_84_3);
            close $in_84_3 or croak 'Close failed: $OS_ERROR';
            my $xargs_result_84_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_84_3> };
            close $out_84_3 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_84_3, 0;
            chomp $xargs_result_84_3;
            push @xargs_output_84_3, $xargs_result_84_3;
            }
            my $xargs_result_84_3 = join "\n", @xargs_output_84_3;
            if ($xargs_result_84_3 ne q{} && !( $xargs_result_84_3 =~ m{\n\z}msx )) { $xargs_result_84_3 .= "\n"; }
            $output_84 = $xargs_result_84_3;
            $output_84 = $xargs_result_84_3;
            if ($output_84 ne q{} && !defined $output_printed_84) {
                print $output_84;
                if (!($output_84 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_84 ) { $main_exit_code = 1; }
            }
if ((-f '/lib/systemd/system/systemd-modules-load.service')) {
            $main_exit_code = system('systemctl', 'restart', "sys" . "tem" . "d-modules-load.service") >> 8;
        }
    }
    $force = "$tmp_force";
    return;
}

sub list_each_installed_module {
    my $count;
    my $real_dest_module_location;
    my $mod;
    for (eval { int($count=0) } // ""; eval { int($count < 0) } // ""; eval { int($count++) } // "") {
            $real_dest_module_location = (do { my $_chomp_temp = do {
    my ($in_85, $out_85);
    my $pid_85 = open3($in_85, $out_85, '>&STDERR', 'find_actual_dest_module_location', $1, $count, $2, $3);
    close $in_85 or croak 'Close failed: $OS_ERROR';
    my $result_85 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_85> };
    close $out_85 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_85, 0;
    $result_85
}; chomp $_chomp_temp; $_chomp_temp; });
            $mod = do {
    my ($in_86, $out_86);
    my $pid_86 = open3($in_86, $out_86, '>&STDERR', 'compressed_or_uncompressed', "$ENV{install_tree}/$_[1]" . ${real_dest_module_location}, $dest_module_name[eval { int($count) } // ""]);
    close $in_86 or croak 'Close failed: $OS_ERROR';
    my $result_86 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_86> };
    close $out_86 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_86, 0;
    $result_86
};
            print $mod;
if ( !( ($mod) =~ m{\n\z}msx ) ) { print "\n"; }
    }
    return;
}

sub is_module_added {
    if (!((($1 ne q{}) && ($2 ne q{})))) {
        return q{1};    }
    if (!((-d $dkms_tree/$1/$2))) {
        return q{2};    }
((-l $dkms_tree/$1/$2/source) || (-d $dkms_tree/$1/$2/source))
    return;
}

sub is_module_built {
    if (!(0)) {
        return q{1};    }
    my $d = "$ENV{dkms_tree}/$_[0]/$_[1]/$_[2]/$_[3]";
    my $m = q{};
    if (!((-d $d/module))) {
        return q{1};    }
    my $default_conf = "$ENV{dkms_tree}/$_[0]/$_[1]/source/dkms.conf";
    my $real_conf = (defined (defined ($ENV{conf} // q{}) && ($ENV{conf} // q{}) ne q{} ? ($ENV{conf} // q{}) : ${default_conf}) && (defined ($ENV{conf} // q{}) && ($ENV{conf} // q{}) ne q{} ? ($ENV{conf} // q{}) : ${default_conf}) ne q{} ? (defined ($ENV{conf} // q{}) && ($ENV{conf} // q{}) ne q{} ? ($ENV{conf} // q{}) : ${default_conf}) : ${default_conf});
    read_conf_or_die("$_[2]", "$_[3]", "$real_conf");
    set_module_suffix("$_[2]");
    for my $m (@dest_module_name) {
        my $t = do {
    my ($in_87, $out_87);
    my $pid_87 = open3($in_87, $out_87, '>&STDERR', 'compressed_or_uncompressed', "$d/module", "$m");
    close $in_87 or croak 'Close failed: $OS_ERROR';
    my $result_87 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_87> };
    close $out_87 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_87, 0;
    $result_87
};
                $main_exit_code = system('test', '-n', "$t") >> 8;
        if ($CHILD_ERROR != 0) {
            return q{1};        }
    }
    return;
}

sub _is_module_installed {
    if (!(0)) {
        return q{1};    }
    my $d = "$ENV{dkms_tree}/$_[0]/$_[1]/$_[2]/$_[3]";
    my $k = "$ENV{dkms_tree}/$_[0]/kernel-$_[2]-$_[3]";
((-l $k) && $(readlink -f $k) eq $d)
    return;
}

sub is_module_installed {
    if (do {
is_module_built("@ARGV");
        $CHILD_ERROR == 0
    }) {
                _is_module_installed("@ARGV");
    }
    return;
}
$main_exit_code = system('maybe_add_module', q{}, "\n    is_module_added \"$1\" \"$2\" && {\n        echo $\"Module $1/$2 already added.\"\n        return 0\n    }\n    module=\"$1\" module_version=\"$2\" add_module\n") >> 8;
$main_exit_code = system('maybe_build_module', q{}, "\n    is_module_built \"$1\" \"$2\" \"$3\" \"$4\" && {\n        if [[ \"$force\" = \"true\" ]]; then\n            do_unbuild \"$3\" \"$4\"\n        else\n            echo $\"Module $1/$2 already built for kernel $3 ($4), skip.\"                  $\"You may override by specifying --force.\"\n            return 0\n        fi\n    }\n    module=\"$1\" module_version=\"$2\" kernelver=\"$3\" arch=\"$4\" do_build\n") >> 8;
$main_exit_code = system('maybe_install_module', q{}, "\n    is_module_installed \"$1\" \"$2\" \"$3\" \"$4\" && {\n        if [[ \"$force\" = \"true\" ]]; then\n            do_uninstall \"$3\" \"$4\"\n        else\n            echo $\"Module $1/$2 already installed on kernel $3 ($4), skip.\"                  $\"You may override by specifying --force.\"\n            return 0\n        fi\n    }\n    module=\"$1\" module_version=\"$2\" kernelver=\"$3\" arch=\"$4\" do_install\n") >> 8;

sub build_module {
    my $i = "0";
    for (eval { int($i=0) } // ""; eval { int($i < scalar(@kernelver)) } // ""; eval { int($i++) } // "") {
            $main_exit_code = system('maybe_build_module', "$module", "$ENV{module_version}", $kernelver[eval { int($i) } // ""], $arch[eval { int($i) } // ""]) >> 8;
    }
    return;
}

sub install_module {
    my $i = "0";
    for (eval { int($i=0) } // ""; eval { int($i < scalar(@kernelver)) } // ""; eval { int($i++) } // "") {
            $main_exit_code = system('maybe_install_module', "$module", "$ENV{module_version}", $kernelver[eval { int($i) } // ""], $arch[eval { int($i) } // ""]) >> 8;
    }
    return;
}

sub possible_dest_module_locations {
    my $location;
    $location[0] = $dest_module_location[eval { int($count) } // ""];
    if (${DEST_MODULE_LOCATION[$count]} ne ${dest_module_location[$count]}) {
                $location[1] = $DEST_MODULE_LOCATION[eval { int($count) } // ""];
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    print @location . "\n";
    $CHILD_ERROR = 0;
    return;
}

sub find_actual_dest_module_location {
    my $module = "$_[0]";
    my $count = "$_[1]";
    my $kernelver = "$_[2]";
    my $arch = "$_[3]";
    my $locations = (do { my $_chomp_temp = do {
    my ($in_88, $out_88);
    my $pid_88 = open3($in_88, $out_88, '>&STDERR', 'possible_dest_module_locations', $count);
    close $in_88 or croak 'Close failed: $OS_ERROR';
    my $result_88 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_88> };
    close $out_88 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_88, 0;
    $result_88
}; chomp $_chomp_temp; $_chomp_temp; });
    my $l;
    my $dkms_owned;
    my $installed;
    $dkms_owned = do {
    my ($in_89, $out_89);
    my $pid_89 = open3($in_89, $out_89, '>&STDERR', 'compressed_or_uncompressed', ($ENV{dkms_tree} // q{}) . "/" . ${module} . "/kernel-" . ${kernelver} . "-" . ${arch} . "/module", $dest_module_name[eval { int($count) } // ""]);
    close $in_89 or croak 'Close failed: $OS_ERROR';
    my $result_89 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_89> };
    close $out_89 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_89, 0;
    $result_89
};
    for my $l ($locations) {
        $installed = do {
    my ($in_90, $out_90);
    my $pid_90 = open3($in_90, $out_90, '>&STDERR', 'compressed_or_uncompressed', ($ENV{install_tree} // q{}) . "/" . ${kernelver} . ${l}, $dest_module_name[eval { int($count) } // ""]);
    close $in_90 or croak 'Close failed: $OS_ERROR';
    my $result_90 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_90> };
    close $out_90 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_90, 0;
    $result_90
};
if (("${installed}" ne q{} && !(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            compare_module_version(${dkms_owned}, ${installed});
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        }))) {
            print ${l};
if ( !( (${l}) =~ m{\n\z}msx ) ) { print "\n"; }
return q{0};
        }
    }
    return;
}

sub do_uninstall {
    do {
    my $__echo_line = "$\"Module $module-$ENV{module_version} for kernel $_[0] ($_[1]).\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    set_module_suffix("$_[0]");
    my $was_active = "";
    my $kernel_symlink = do {
    my ($in_91, $out_91);
    my $pid_91 = open3($in_91, $out_91, '>&STDERR', 'readlink', '-f', "$ENV{dkms_tree}/$module/kernel-$_[0]-$_[1]");
    close $in_91 or croak 'Close failed: $OS_ERROR';
    my $result_91 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_91> };
    close $out_91 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_91, 0;
    $result_91
};
    my $real_dest_module_location;
if ($kernel_symlink eq $dkms_tree/$module/$module_version/$1/$2) {
        $was_active = "true";
        do {
    my $__echo_line = "$\"Before uninstall, this module version was ACTIVE on this kernel.\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
if ("$NO_WEAK_MODULES" eq q{}) {
if (((${weak_modules} ne q{}) && !(            do {
                local %ENV = %ENV;
                my $was_active = $was_active;
                my $kernel_symlink = $kernel_symlink;
                my $real_dest_module_location = $real_dest_module_location;
                # Original bash: module_status_built $module $module_version |grep -q "installed")
{
                    my $output_92 = q{};
                    my $output_printed_92;
                    my $pipeline_success_92 = 1;
                                        my ($in_93, $out_93);
                    my $pid_93 = open3($in_93, $out_93, '>&STDERR', 'module_status_built', );
                    close $in_93 or croak 'Close failed: $OS_ERROR';
                    $output_92 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_93> };
                    close $out_93 or croak 'Close failed: $OS_ERROR';
                    waitpid $pid_93, 0;

                                        my $grep_result_92_1;
                    my @grep_lines_92_1 = split /\n/msx, $output_92;
                    my @grep_filtered_92_1 = grep { /installed/msx } @grep_lines_92_1;
                    $grep_result_92_1 = join "\n", @grep_filtered_92_1;
                    if (!($grep_result_92_1 =~ m{\n\z}msx || $grep_result_92_1 eq q{})) {
                    $grep_result_92_1 .= "\n";
                    }
                    $CHILD_ERROR = scalar @grep_filtered_92_1 > 0 ? 0 : 1;
                    $grep_result_92_1 = q{};
                    $output_92 = q{};
                    if ((scalar @grep_filtered_92_1) == 0) {
                        $pipeline_success_92 = 0;
                    }
                    if ($output_92 ne q{} && !defined $output_printed_92) {
                        print $output_92;
                        if (!($output_92 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_92 ) { $main_exit_code = 1; }
                    }
                q{};
            }))) {
                do {
    my $__echo_line = "$\"Removing any linked weak-modules\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                # Original bash: list_each_installed_module "$module" "$1" "$2" | ${weak_modules} ${weak_modules_no_initrd} --remove-modules
{
                    my $output_94 = q{};
                    my $output_printed_94;
                    my $pipeline_success_94 = 1;
                                        my ($in_95, $out_95);
                    my $pid_95 = open3($in_95, $out_95, '>&STDERR', 'list_each_installed_module', );
                    close $in_95 or croak 'Close failed: $OS_ERROR';
                    $output_94 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_95> };
                    close $out_95 or croak 'Close failed: $OS_ERROR';
                    waitpid $pid_95, 0;

                                        my $cmd_97 = 'unknown_command';
                    my ($in_96, $out_96);
                    my $pid_96 = open3($in_96, $out_96, '>&STDERR', $cmd_97, '--remove-modules');
                    print {$in_96} $output_94;
                    close $in_96 or croak 'Close failed: $OS_ERROR';
                    $output_94 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_96> };
                    close $out_96 or croak 'Close failed: $OS_ERROR';
                    waitpid $pid_96, 0;
                    if ($output_94 ne q{} && !defined $output_printed_94) {
                        print $output_94;
                        if (!($output_94 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_94 ) { $main_exit_code = 1; }
                    }
            }
        }
        for (eval { int($ENV{count}=0) } // ""; eval { int($ENV{count} < 0) } // ""; eval { int($ENV{count}++) } // "") {
                $real_dest_module_location = (do { my $_chomp_temp = do {
    my ($in_98, $out_98);
    my $pid_98 = open3($in_98, $out_98, '>&STDERR', 'find_actual_dest_module_location', $module, $count, $1, $2);
    close $in_98 or croak 'Close failed: $OS_ERROR';
    my $result_98 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_98> };
    close $out_98 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_98, 0;
    $result_98
}; chomp $_chomp_temp; $_chomp_temp; });
                do {
    my $__echo_line = "$\"\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                do {
    my $__echo_line = "$\"" . $dest_module_name[eval { int($count) } // ""] . "$ENV{module_suffix}:\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                do {
    my $__echo_line = "$\" - Uninstallation\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
if (("${real_dest_module_location}")) {
                    do {
    my $__echo_line = "$\"   - Deleting from: $ENV{install_tree}/$_[0]" . ${real_dest_module_location} . "/\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
if ( -e "$ENV{install_tree}/$_[0]" . ${real_dest_module_location} . "/" . $dest_module_name[eval { int($count) } // ""] . "$ENV{module_uncompressed_suffix}" ) {
                        if ( -d "$ENV{install_tree}/$_[0]" . ${real_dest_module_location} . "/" . $dest_module_name[eval { int($count) } // ""] . "$ENV{module_uncompressed_suffix}" ) {
                            carp "rm: carping: ", "$ENV{install_tree}/$_[0]" . ${real_dest_module_location} . "/" . $dest_module_name[eval { int($count) } // ""] . "$ENV{module_uncompressed_suffix}",
          " is a directory (use -r to remove recursively)\n";
                        }
                        else {
                            if ( unlink "$ENV{install_tree}/$_[0]" . ${real_dest_module_location} . "/" . $dest_module_name[eval { int($count) } // ""] . "$ENV{module_uncompressed_suffix}" ) {
                                                            }
                            else {
                                carp "rm: carping: could not remove ", "$ENV{install_tree}/$_[0]" . ${real_dest_module_location} . "/" . $dest_module_name[eval { int($count) } // ""] . "$ENV{module_uncompressed_suffix}",
              ": $OS_ERROR\n";
                            }
                        }
                    }
                    else {
                        local $CHILD_ERROR = 0;
                    }
my @files_to_remove = glob("*");
foreach my $file_to_remove (@files_to_remove) {
                        if ( -e $file_to_remove ) {
                            if ( -d $file_to_remove ) {
                                carp "rm: carping: ", $file_to_remove,
    " is a directory (use -r to remove recursively)\n";
                            }
                            else {
                                if ( unlink $file_to_remove ) {
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
                    my $dir_to_remove;
                    my @dir_to_remove;
                    my %dir_to_remove;
                    $dir_to_remove = (${real_dest_module_location} =~ s/^///r =~ s/^///r);
while ( "${dir_to_remove}" ne "${dir_to_remove#/}" ) {
                        $dir_to_remove = (${dir_to_remove} =~ s/^///r =~ s/^///r);
                    }
if ("$ENV{running_distribution}" =~ /^debian.*$/msx or "$ENV{running_distribution}" =~ /^ubuntu.*$/msx or "$ENV{running_distribution}" =~ /^arch.*$/msx) {
                                                do {
                            local %ENV = %ENV;
                            my $kernel_symlink = $kernel_symlink;
                            my $was_active = $was_active;
                            my $dir_to_remove = $dir_to_remove;
                            my $real_dest_module_location = $real_dest_module_location;
                            if (!(                            chdir("$ENV{install_tree}/$_[0]");
                            $CHILD_ERROR = 0)) {
rmdir (${dir_to_remove}) or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
                            }
                            if ($CHILD_ERROR != 0) {
                                1;
                            }
                            q{};
                        };
                    } elsif (1) {
                                                do {
                            local %ENV = %ENV;
                            my $kernel_symlink = $kernel_symlink;
                            my $was_active = $was_active;
                            my $dir_to_remove = $dir_to_remove;
                            my $real_dest_module_location = $real_dest_module_location;
                            if (!(                            chdir("$ENV{install_tree}/$_[0]");
                            $CHILD_ERROR = 0)) {
                                                                do {
                                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                                    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                                    my $tmp = do {
                                    $main_exit_code = system('rpm', '-qf', ${dir_to_remove}) >> 8;
                                    };
                                    print $tmp;
                                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                                };
                                if ($CHILD_ERROR != 0) {
                                    rmdir (${dir_to_remove}) or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
                                }
                            }
                            if ($CHILD_ERROR != 0) {
                                1;
                            }
                            q{};
                        };
                    }
}
                else {
                    do {
    my $__echo_line = "$\"   - Module was not found within $ENV{install_tree}/$_[0]/\"";
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
    my $__echo_line = "$\" - Original module\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                my $origmod = do {
    my ($in_103, $out_103);
    my $pid_103 = open3($in_103, $out_103, '>&STDERR', 'compressed_or_uncompressed', "$ENV{dkms_tree}/$module/original_module/$_[0]/$_[1]", $dest_module_name[eval { int($count) } // ""]);
    close $in_103 or croak 'Close failed: $OS_ERROR';
    my $result_103 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_103> };
    close $out_103 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_103, 0;
    $result_103
};
if ("$origmod" ne q{}) {
if ("$ENV{running_distribution}" =~ /^debian.*$/msx or "$ENV{running_distribution}" =~ /^ubuntu.*$/msx) {
                    } elsif (1) {
                                                do {
    my $__echo_line = "$\"   - Archived original module found in the DKMS tree\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                        $CHILD_ERROR = 0;
                                                do {
    my $__echo_line = "$\"   - Moving it to: $ENV{install_tree}/$_[0]" . $DEST_MODULE_LOCATION[eval { int($count) } // ""] . "/\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                        $CHILD_ERROR = 0;
                                                use File::Path qw(make_path);
                        my $err;
                        if ( !-d "$ENV{install_tree}/$_[0]" . $DEST_MODULE_LOCATION[eval { int($count) } // ""] . "/" ) {
                            make_path( "$ENV{install_tree}/$_[0]" . $DEST_MODULE_LOCATION[eval { int($count) } // ""] . "/", { error => \$err } );
                            if ( @{$err} ) {
                                croak "mkdir: cannot create directory " . "$ENV{install_tree}/$_[0]" . $DEST_MODULE_LOCATION[eval { int($count) } // ""] . "/" . ": $err->[0]\n";
                            }
                        }
                                                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                            my $force = 1;
                            if ( -e "$origmod" ) {
                                my $dest = "$ENV{install_tree}/$_[0]" . $DEST_MODULE_LOCATION[eval { int($count) } // ""] . "/";
                                if ( -e $dest && -d $dest ) {
                                    my $source_name = "$origmod";
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
                                if ( File::Copy::move( "$origmod", $dest ) ) {
                                } else {
                                    croak
  "mv: cannot move "$origmod" to $dest: $ERRNO\n";
                                }
                            } else {
                                croak "mv: "$origmod": No such file or directory\n";
                            }
                        };
                    }
}
                else {
                    do {
    my $__echo_line = "$\"   - No original module was found for this module on this kernel.\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                    do {
    my $__echo_line = "$\"   - Use the dkms install command to reinstall any previous module version.\"";
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
if ( -e "$ENV{dkms_tree}/$module/kernel-$_[0]-$_[1]" ) {
            if ( -d "$ENV{dkms_tree}/$module/kernel-$_[0]-$_[1]" ) {
                carp "rm: carping: ", "$ENV{dkms_tree}/$module/kernel-$_[0]-$_[1]",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$ENV{dkms_tree}/$module/kernel-$_[0]-$_[1]" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$ENV{dkms_tree}/$module/kernel-$_[0]-$_[1]",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
}
    else {
        do {
    my $__echo_line = "$\"This module version was INACTIVE for this kernel.\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
    run_build_script('post_remove', "$ENV{post_remove}");
    invoke_command("do_depmod $_[0]", "depmod", 'background');
if (0) {
        do {
    my $__echo_line = "$\"\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        do {
    my $__echo_line = "$\"Removing original_module from DKMS tree for kernel $_[0] ($_[1])\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
if ( -e "$ENV{dkms_tree}/$module/original_module/$_[0]/$_[1]" ) {
                if ( -d "$ENV{dkms_tree}/$module/original_module/$_[0]/$_[1]" ) {
                    my $err;
                    require File::Path;
                    File::Path::remove_tree("$ENV{dkms_tree}/$module/original_module/$_[0]/$_[1]", {error => \$err});
                    if (@{$err}) {
                        carp "rm: carping: could not remove ", "$ENV{dkms_tree}/$module/original_module/$_[0]/$_[1]", ": $err->[0]\n";
                    }
                    else {
                                            }
                }
                else {
                    if ( unlink "$ENV{dkms_tree}/$module/original_module/$_[0]/$_[1]" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "$ENV{dkms_tree}/$module/original_module/$_[0]/$_[1]",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
        };
        if (!((qx'find $dkms_tree/$module/original_module/$1/* -maxdepth 0 -type d 2>/dev/null' ne q{}))) {
            if ( -e "$ENV{dkms_tree}/$module/original_module/$_[0]" ) {
                if ( -d "$ENV{dkms_tree}/$module/original_module/$_[0]" ) {
                    my $err;
                    require File::Path;
                    File::Path::remove_tree("$ENV{dkms_tree}/$module/original_module/$_[0]", {error => \$err});
                    if (@{$err}) {
                        carp "rm: carping: could not remove ", "$ENV{dkms_tree}/$module/original_module/$_[0]", ": $err->[0]\n";
                    }
                    else {
                                            }
                }
                else {
                    if ( unlink "$ENV{dkms_tree}/$module/original_module/$_[0]" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "$ENV{dkms_tree}/$module/original_module/$_[0]",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
        }
}
    else {
        if ((($was_active ne q{}) && (-d $dkms_tree/$module/original_module/$1/$2/collisions))) {
            do {
    my $__echo_line = "$\"\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            do {
    my $__echo_line = "$\"Keeping directory $ENV{dkms_tree}/$module/original_module/$_[0]/$_[1]/collisions/\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            do {
    my $__echo_line = "$\"for your reference purposes.  Your kernel originally contained multiple\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            do {
    my $__echo_line = "$\"same-named modules and this directory is now where these are located.\"";
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
    if (!((qx'find $dkms_tree/$module/original_module/* -maxdepth 0 -type d 2>/dev/null' ne q{}))) {
        if ( -e "$ENV{dkms_tree}/$module/original_module" ) {
            if ( -d "$ENV{dkms_tree}/$module/original_module" ) {
                my $err;
                require File::Path;
                File::Path::remove_tree("$ENV{dkms_tree}/$module/original_module", {error => \$err});
                if (@{$err}) {
                    carp "rm: carping: could not remove ", "$ENV{dkms_tree}/$module/original_module", ": $err->[0]\n";
                }
                else {
                                    }
            }
            else {
                if ( unlink "$ENV{dkms_tree}/$module/original_module" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$ENV{dkms_tree}/$module/original_module",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
    return;
}

sub module_is_added_or_die {
        is_module_added("$module", "$ENV{module_version}");
    if ($CHILD_ERROR != 0) {
                die(q{3}, "$\"The module/version combo: $module-$ENV{module_version} is not located in the DKMS tree.\"");
    }
    return;
}

sub maybe_unbuild_module {
    my ($file) = @_;
        is_module_built("$module", "$ENV{module_version}", "$_[0]", "$_[1]");
    if ($CHILD_ERROR != 0) {
                    do {
    my $__echo_line = "$\"Module $module $ENV{module_version} is not built for kernel $_[0] ($_[1]).\"" . q{ } . "$\"Skipping...\"";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
return q{0};
    }
    $main_exit_code = system('do_unbuild', "$_[0]", "$_[1]") >> 8;
    return;
}

sub maybe_uninstall_module {
    my ($file) = @_;
        is_module_installed("$module", "$ENV{module_version}", "$_[0]", "$_[1]");
    if ($CHILD_ERROR != 0) {
                    do {
    my $__echo_line = "$\"Module $module $ENV{module_version} is not installed for kernel $_[0] ($_[1]).\"" . q{ } . "$\"Skipping...\"";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
return q{0};
    }
    do_uninstall("$_[0]", "$_[1]");
    return;
}

sub uninstall_module {
    my $i;
    for (eval { int($i=0) } // ""; eval { int($i < scalar(@kernelver)) } // ""; eval { int($i++) } // "") {
            maybe_uninstall_module($kernelver[eval { int($i) } // ""], $arch[eval { int($i) } // ""]);
    }
    return;
}

sub do_unbuild {
    my ($file) = @_;
if ( -e "$ENV{dkms_tree}/$module/$ENV{module_version}/$_[0]/$_[1]" ) {
        if ( -d "$ENV{dkms_tree}/$module/$ENV{module_version}/$_[0]/$_[1]" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("$ENV{dkms_tree}/$module/$ENV{module_version}/$_[0]/$_[1]", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", "$ENV{dkms_tree}/$module/$ENV{module_version}/$_[0]/$_[1]", ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "$ENV{dkms_tree}/$module/$ENV{module_version}/$_[0]/$_[1]" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$ENV{dkms_tree}/$module/$ENV{module_version}/$_[0]/$_[1]",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    if (!((qx'find $dkms_tree/$module/$module_version/$1/* -maxdepth 0 -type d 2>/dev/null' ne q{}))) {
        if ( -e "$ENV{dkms_tree}/$module/$ENV{module_version}/$_[0]" ) {
            if ( -d "$ENV{dkms_tree}/$module/$ENV{module_version}/$_[0]" ) {
                my $err;
                require File::Path;
                File::Path::remove_tree("$ENV{dkms_tree}/$module/$ENV{module_version}/$_[0]", {error => \$err});
                if (@{$err}) {
                    carp "rm: carping: could not remove ", "$ENV{dkms_tree}/$module/$ENV{module_version}/$_[0]", ": $err->[0]\n";
                }
                else {
                                    }
            }
            else {
                if ( unlink "$ENV{dkms_tree}/$module/$ENV{module_version}/$_[0]" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$ENV{dkms_tree}/$module/$ENV{module_version}/$_[0]",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
    return;
}

sub unbuild_module {
    my $i;
    for (eval { int($i=0) } // ""; eval { int($i < scalar(@kernelver)) } // ""; eval { int($i++) } // "") {
            maybe_uninstall_module($kernelver[eval { int($i) } // ""], $arch[eval { int($i) } // ""]);
            maybe_unbuild_module($kernelver[eval { int($i) } // ""], $arch[eval { int($i) } // ""]);
    }
    return;
}

sub remove_module {
if (($rpm_safe_upgrade ne q{})) {
        my $pppid = do { my @_qx_cmd = (q(awk '/PPid:/ {print $2}' /proc/ $PPID /status)); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
        my $time_stamp = do { my @_qx_cmd = ("ps -o lstart --no-headers -p Variable(\"pppid\", false, None) 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
        my $lock_file;
        for my $lock_file ($tmp_location, '/dkms_rpm_safe_upgrade_lock.', "$pppid.", q{*}) {
            if (!((-f $lock_file))) {
                next;            }
            my $lock_head;
            my @lock_head;
            my %lock_head;
            $lock_head = do { my @_qx_cmd = ("head -n 1 Variable(\"lock_file\", false, None) 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
            my $lock_tail;
            my @lock_tail;
            my %lock_tail;
            $lock_tail = do { my @_qx_cmd = ("tail -n 1 Variable(\"lock_file\", false, None) 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
            if (!(0)) {
                next;            }
if ( -e "$lock_file" ) {
                if ( -d "$lock_file" ) {
                    carp "rm: carping: ", $lock_file,
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$lock_file" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", $lock_file,
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
            die(q{0}, "$\"Remove cancelled because --rpm_safe_upgrade scenario detected.\"");
        }
    }
    my $i;
    for (eval { int($i=0) } // ""; eval { int($i < scalar(@kernelver)) } // ""; eval { int($i++) } // "") {
            maybe_uninstall_module($kernelver[eval { int($i) } // ""], $arch[eval { int($i) } // ""]);
            maybe_unbuild_module($kernelver[eval { int($i) } // ""], $arch[eval { int($i) } // ""]);
    }
if (!(!(# Original bash: find $dkms_tree/$module/$module_version/* -maxdepth 0 -type d 2>/dev/null | grep -Eqv "(build|tarball|driver_disk|rpm|deb|source)$";
{
        my $output_106 = q{};
        my $output_printed_106;
        my $pipeline_success_106 = 1;
                $output = q{};
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_107 = q{};
$tmp_redirect_107 = do {
    require File::Find;
    my @find_results;
    File::Find::find(sub { my $maxdepth = 0; my $depth = ($File::Find::dir =~ tr/\///) + 1; next if $depth > $maxdepth; if (-d $_) { push @find_results, $File::Find::name; } }, q{/});
    my $result = join "\n", @find_results;
    if ($result ne q{}) { $result .= "\n"; }
    $CHILD_ERROR = 0;
    $result;
};
$tmp_redirect_107;
        };
        $output_106 = $output;

                my $grep_result_106_1;
        my @grep_lines_106_1 = split /\n/msx, $output_106;
        my @grep_filtered_106_1 = grep { !/(build|tarball|driver_disk|rpm|deb|source)$/msx } @grep_lines_106_1;
        $grep_result_106_1 = join "\n", @grep_filtered_106_1;
        if (!($grep_result_106_1 =~ m{\n\z}msx || $grep_result_106_1 eq q{})) {
        $grep_result_106_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_106_1 > 0 ? 0 : 1;
        $grep_result_106_1 = q{};
        $output_106 = q{};
        if ((scalar @grep_filtered_106_1) == 0) {
            $pipeline_success_106 = 0;
        }
        if ($output_106 ne q{} && !defined $output_printed_106) {
            print $output_106;
            if (!($output_106 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_106 ) { $main_exit_code = 1; }
        }))) {
        do {
    my $__echo_line = "$\"Deleting module $module-$ENV{module_version} completely from the DKMS tree.\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
if ( -e "$ENV{dkms_tree}/$module/$ENV{module_version}" ) {
            if ( -d "$ENV{dkms_tree}/$module/$ENV{module_version}" ) {
                my $err;
                require File::Path;
                File::Path::remove_tree("$ENV{dkms_tree}/$module/$ENV{module_version}", {error => \$err});
                if (@{$err}) {
                    carp "rm: carping: could not remove ", "$ENV{dkms_tree}/$module/$ENV{module_version}", ": $err->[0]\n";
                }
                else {
                                    }
            }
            else {
                if ( unlink "$ENV{dkms_tree}/$module/$ENV{module_version}" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$ENV{dkms_tree}/$module/$ENV{module_version}",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
if (eval { int(do { chomp(my $_r = qx'ls "$dkms_tree/$module" | wc -w | awk '\''{print $1}'\'''); $_r; } == 0) } // "") {
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
if ( -e "$ENV{dkms_tree}/$module" ) {
                if ( -d "$ENV{dkms_tree}/$module" ) {
                    my $err;
                    require File::Path;
                    File::Path::remove_tree("$ENV{dkms_tree}/$module", {error => \$err});
                    if (@{$err}) {
                        carp "rm: carping: could not remove ", "$ENV{dkms_tree}/$module", ": $err->[0]\n";
                    }
                    else {
                                            }
                }
                else {
                    if ( unlink "$ENV{dkms_tree}/$module" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "$ENV{dkms_tree}/$module",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
        };
    }
    return;
}

sub find_module_from_ko {
    my $ko = "$_[0]";
    my $basename_ko = ( ( basename(${ko}) ) =~ s|^.*/||sr );
    my $module;
    my $kernellink;
    for my $kernellink ("$ENV{dkms_tree}", '/*/kernel-*') {
        if (!((-l $kernellink))) {
            next;        }
        $module = ${kernellink} =~ s/^\$dkms_tree///r;
        $module = scalar reverse( (scalar reverse ${module}) =~ s/^.*?-lenrek///r );
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            my $diff_output = q{};
            {
                my $diff_cmd = 'diff';
                my @diff_args = ("$kernellink/module/" . ${basename_ko}, ${ko});
                my $diff_pid = open my $diff_fh, q{-|}, $diff_cmd, @diff_args;
                if ($diff_pid) {
                    local $INPUT_RECORD_SEPARATOR = undef;
                    $diff_output = <$diff_fh>;
                    close $diff_fh;
                    $CHILD_ERROR = $? >> 8;
                } else {
                    carp "Cannot execute diff command: $OS_ERROR";
                    $diff_output = q{};
                    $CHILD_ERROR = 1;
                }
            }
            $diff_output;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        if ($CHILD_ERROR != 0) {
            next;        }
        my $rest;
        my @rest;
        my %rest;
        $rest = do {
    my ($in_110, $out_110);
    my $pid_110 = open3($in_110, $out_110, '>&STDERR', 'readlink', $kernellink);
    close $in_110 or croak 'Close failed: $OS_ERROR';
    my $result_110 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_110> };
    close $out_110 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_110, 0;
    $result_110
};
        do {
    my $__echo_line = "$module/$rest";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
return q{0};
    }
return q{1};
    return;
}

sub module_status_weak {
    if (!("$NO_WEAK_MODULES" eq q{})) {
        return q{1};    }
    if (!(($weak_modules ne q{}))) {
        return q{1};    }
    my $m;
    my $v;
    my $k;
    my $a;
    my $kern;
    my $weak_ko;
    my $mod;
    my $installed_ko;
    my $f;
    my $ret = "1";
    my $oifs = $IFS;
    my %already_found = ();
    for my $weak_ko ("$ENV{install_tree}/", '*/weak-updates/*') {
        if (!((-e $weak_ko))) {
            next;        }
                if ((-l $weak_ko)) {
                        $installed_ko = (do { my $_chomp_temp = do {
    my ($in_111, $out_111);
    my $pid_111 = open3($in_111, $out_111, '>&STDERR', 'readlink', '-f', "$weak_ko");
    close $in_111 or croak 'Close failed: $OS_ERROR';
    my $result_111 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_111> };
    close $out_111 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_111, 0;
    $result_111
}; chomp $_chomp_temp; $_chomp_temp; });
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        if ($CHILD_ERROR != 0) {
            next;        }
            my $IFS = q{/};
                        my $temp_file_ps_fh_4 = q{/tmp} . '/process_sub_fh_4.tmp';
            my $output_ps_fh_4;
            {
            my ($in, $out);
            my $pid = open3($in, $out, '>&STDERR', 'bash', '-c', 'find_module_from_ko "$weak_ko"');
            close $in or croak 'Close failed: $OS_ERROR';
            $output_ps_fh_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
            close $out or croak 'Close failed: $OS_ERROR';
            waitpid $pid, 0;
$CHILD_ERROR = $? >> 8;
            }
            use File::Path qw(make_path);
            my $temp_dir_fh_4 = dirname($temp_file_ps_fh_4);
            if (!-d $temp_dir_fh_4) { make_path($temp_dir_fh_4); }
            open my $fh_ps_fh_4, '>', $temp_file_ps_fh_4 or croak "Cannot create temp file: $ERRNO\n";
            print {$fh_ps_fh_4} $output_ps_fh_4;
            close $fh_ps_fh_4 or croak "Close failed: $ERRNO\n";
            open STDIN, '<', $temp_file_ps_fh_4 or croak "Cannot open process substitution: $ERRNO\n";
$m = <>;
chomp $m;
$CHILD_ERROR = defined($m) ? 0 : 1;
            if ($CHILD_ERROR != 0) {
                next;            }
        $kern = ${weak_ko} =~ s/^\$install_tree///r;
        $kern = scalar reverse( (scalar reverse ${kern}) =~ s/^.*?/setadpu-kaew///r );
        if (!(0)) {
            next;        }
        $already_found{"$m/$v/$kern/$a/$k"} += basename(${weak_ko});
        $main_exit_code = system('bash', ' ') >> 8;
    }
    for my $mod (keys %already_found) {
            $IFS = q{/};
$m = <>;
chomp $m;
$CHILD_ERROR = defined($m) ? 0 : 1;
        for my $installed_ko (do {
    require File::Find;
    my @find_results;
    File::Find::find(sub { if (-f $_) { push @find_results, $File::Find::name; } }, q{/});
    my $result = join "\n", @find_results;
    if ($result ne q{}) { $result .= "\n"; }
    $CHILD_ERROR = 0;
    $result;
}) {
            if (${already_found[$mod]} ne *"$installed_ko"*) {
                next LABEL2;                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
        }
        $ret = q{0};
        do {
    my $__echo_line = "installed-weak $mod";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
return $ret;
    return;
}

sub do_status_weak {
    my $mvka;
    my $m;
    my $v;
    my $k;
    my $a;
    my $kern;
    my $status;
    my $temp_file_ps_fh_5 = q{/tmp} . '/process_sub_fh_5.tmp';
    my $output_ps_fh_5;
    {
    my ($in, $out);
    my $pid = open3($in, $out, '>&STDERR', 'bash', '-c', 'module_status_weak "$@"');
    close $in or croak 'Close failed: $OS_ERROR';
    $output_ps_fh_5 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
$CHILD_ERROR = $? >> 8;
    }
    use File::Path qw(make_path);
    my $temp_dir_fh_5 = dirname($temp_file_ps_fh_5);
    if (!-d $temp_dir_fh_5) { make_path($temp_dir_fh_5); }
    open my $fh_ps_fh_5, '>', $temp_file_ps_fh_5 or croak "Cannot create temp file: $ERRNO\n";
    print {$fh_ps_fh_5} $output_ps_fh_5;
    close $fh_ps_fh_5 or croak "Close failed: $ERRNO\n";
    open STDIN, '<', $temp_file_ps_fh_5 or croak "Cannot open process substitution: $ERRNO\n";
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $status = $_fields[0] // q{};
    $mvka = $_fields[1] // q{};
            my $IFS = q{/};
$m = <>;
chomp $m;
$CHILD_ERROR = defined($m) ? 0 : 1;
        do {
    my $__echo_line = "$m, $v, $k, $a: installed-weak from $kern";
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
$main_exit_code = system('module_status_built_extra', q{}, "\n    set_module_suffix \"$3\"\n    read_conf \"$3\" \"$4\" \"$dkms_tree/$1/$2/source/dkms.conf\" 2>/dev/null\n    [[ -d $dkms_tree/$1/original_module/$3/$4 ]] && echo -n \" (original_module exists)\"\n    for ((count=0; count < ${#dest_module_name[@]}; count++)); do\n        tree_mod=$(compressed_or_uncompressed \"$dkms_tree/$1/$2/$3/$4/module\" \"${dest_module_name[$count]}\")\n        if ! [[ -n \"$tree_mod\" ]]; then\n            echo -n \" (WARNING! Missing some built modules!)\"\n        elif _is_module_installed \"$@\"; then\n            real_dest=\"$(find_actual_dest_module_location \"$1\" $count \"$3\" \"$4\")\"\n            real_dest_mod=$(compressed_or_uncompressed \"$install_tree/$3${real_dest}\" \"${dest_module_name[$count]}\")\n            if ! diff -q \"$tree_mod\" \"$real_dest_mod\" >/dev/null 2>&1; then\n                echo -n \" (WARNING! Diff between built and installed module!)\"\n            fi\n        fi\n    done\n") >> 8;

sub module_status_built {
    my $ret = "1";
    my $directory;
    my $ka;
    my $k;
    my $a;
    my $state;
    my $oifs = "$ENV{IFS}";
    my $IFS = q{};
    for my $directory ("$ENV{dkms_tree}/$_[0]/$_[1]/", (defined $_[2] && $_[2] ne q{} ? $_[2] : '+([0-9]).*'), q{/}, (defined $_[3] && $_[3] ne q{} ? $_[3] : '*')) {
        $IFS = "$oifs";
        $ka = (${directory} =~ s/^\$dkms_tree/\$1/\$2///r =~ s/^\$dkms_tree/\$1/\$2///r);
        $k = ( ( dirname(${ka}) ) =~ s|/[^/]*$||sr );
        $a = (${ka} =~ s/^.*?///r =~ s/^.*?///r);
                is_module_built("$_[0]", "$_[1]", "$k", "$a");
        if ($CHILD_ERROR != 0) {
            next;        }
        $ret = q{0};
        $state = "built";
        if (do {
_is_module_installed("$_[0]", "$_[1]", "$k", "$a");
            $CHILD_ERROR == 0
        }) {
                        $state = "installed";
        }
        do {
    my $__echo_line = "$state $_[0]/$_[1]/$k/$a";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        $IFS = q{};
    }
    $IFS = "$oifs";
return $ret;
    return;
}

sub module_status {
    my $oifs = "$ENV{IFS}";
    my $IFS = q{};
    my $mv;
    my $m;
    my $v;
    my $directory;
    my $ret = "1";
    for my $directory ("$ENV{dkms_tree}/", (defined $_[0] && $_[0] ne q{} ? $_[0] : '*'), q{/}, (defined $_[1] && $_[1] ne q{} ? $_[1] : '*')) {
        $IFS = "$oifs";
        $mv = (${directory} =~ s/^\$dkms_tree///r =~ s/^\$dkms_tree///r);
        $m = ( ( dirname(${mv}) ) =~ s|/[^/]*$||sr );
        $v = (${mv} =~ s/^.*?///r =~ s/^.*?///r);
                is_module_added("$m", "$v");
        if ($CHILD_ERROR != 0) {
            next;        }
        $ret = q{0};
                module_status_built("$m", "$v", "$_[2]", "$_[3]");
        if ($CHILD_ERROR != 0) {
                        do {
    my $__echo_line = "added $m/$v";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        }
        $IFS = q{};
    }
    $IFS = "$oifs";
return $ret;
    return;
}

sub do_status {
    my $status;
    my $mvka;
    my $m;
    my $v;
    my $k;
    my $a;
    my $tmpfile = do {
    my ($in_115, $out_115);
    my $pid_115 = open3($in_115, $out_115, '>&STDERR', 'mktemp_or_die');
    close $in_115 or croak 'Close failed: $OS_ERROR';
    my $result_115 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_115> };
    close $out_115 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_115, 0;
    $result_115
};
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$tmpfile"
      or die "Cannot open file: $OS_ERROR\n";
        do {
            local %ENV = %ENV;
            my $status = $status;
            my $mvka = $mvka;
            my $m = $m;
            my $k = $k;
            my $a = $a;
            my $tmpfile = $tmpfile;
            my $v = $v;
            module_status("@ARGV");
            q{};
        };
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
open STDIN, '<', "$tmpfile" or croak "Cannot open file: $OS_ERROR\n";
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $status = $_fields[0] // q{};
    $mvka = $_fields[1] // q{};
            my $IFS = q{/};
$m = <>;
chomp $m;
$CHILD_ERROR = defined($m) ? 0 : 1;
if ($status =~ /^added$/msx) {
                        do {
    my $__echo_line = "$m/$v: $status";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        } elsif ($status =~ /^built$/msx or $status =~ /^installed$/msx) {
                        print "$m/$v, $k, $a: $status";
                        $main_exit_code = system('module_status_built_extra', "$m", "$v", "$k", "$a") >> 8;
                        print "\n";
            $CHILD_ERROR = 0;
        }
    }
if ( -e "$tmpfile" ) {
        if ( -d "$tmpfile" ) {
            croak "rm: ", "$tmpfile",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$tmpfile" ) {
                            }
            else {
                croak "rm: cannot remove ", "$tmpfile",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 1;
        croak "rm: ", "$tmpfile", ": No such file or directory\n";
    }
    return;
}

sub show_status {
    my $j;
    my $state_array;
if (eval { int(scalar(@kernelver) == 0) } // "") {
        do_status("$module", "$ENV{module_version}", "$kernelver", "$arch");
        do_status_weak("$module", "$ENV{module_version}", "$kernelver", "$arch");
}
    else {
        for (eval { int($j=0) } // ""; eval { int($j < scalar(@kernelver)) } // ""; eval { int($j++) } // "") {
                do_status("$module", "$ENV{module_version}", $kernelver[eval { int($j) } // ""], $arch[eval { int($j) } // ""]);
                do_status_weak("$module", "$ENV{module_version}", $kernelver[eval { int($j) } // ""], $arch[eval { int($j) } // ""]);
        }
    }
    return;
}

sub make_tarball {
    read_conf_or_die("$kernelver", "$arch");
    my $temp_dir_name = do {
    my ($in_117, $out_117);
    my $pid_117 = open3($in_117, $out_117, '>&STDERR', 'mktemp_or_die', '-d', $tmp_location, '/dkms.XXXXXX');
    close $in_117 or croak 'Close failed: $OS_ERROR';
    my $result_117 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_117> };
    close $out_117 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_117, 0;
    $result_117
};
# Builtin command 'trap' with dynamic handler not supported
    use File::Path qw(make_path);
    my $err;
    if ( !-d $temp_dir_name ) {
        make_path( $temp_dir_name, { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . $temp_dir_name . ": $err->[0]\n";
        }
    }
    if ( !-d '/dkms_main_tree' ) {
        make_path( '/dkms_main_tree', { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . '/dkms_main_tree' . ": $err->[0]\n";
        }
    }
if (($source_only ne q{})) {
        my $kernel_version_list;
        my @kernel_version_list;
        my %kernel_version_list;
        $kernel_version_list = "source-only";
}
    else {
        my $i;
        for (eval { int($i=0) } // ""; eval { int($i<scalar(@kernelver)) } // ""; eval { int($i++) } // "") {
                my $intree_module_dir = "$ENV{dkms_tree}/$module/$ENV{module_version}/" . $kernelver[eval { int($i) } // ""] . "/" . $arch[eval { int($i) } // ""];
                my $temp_module_dir = "$temp_dir_name/dkms_main_tree/" . $kernelver[eval { int($i) } // ""];
if (!(!((-d "$intree_module_dir")))) {
                    die(q{6}, "$\"No modules built for " . $kernelver[eval { int($i) } // ""] . " (" . $arch[eval { int($i) } // ""] . ").\"", "$\"Modules must already be in the built state before using mktarball.\"");
                }
                set_module_suffix($kernelver[eval { int($i) } // ""]);
                do {
    my $__echo_line = "Marking modules for " . $kernelver[eval { int($i) } // ""] . " (" . $arch[eval { int($i) } // ""] . ") for archiving...";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
if ((!$kernel_version_list)) {
                    $kernel_version_list = "kernel" . $kernelver[eval { int($i) } // ""] . "-" . $arch[eval { int($i) } // ""];
}
                else {
                    $kernel_version_list = ${kernel_version_list} . "-kernel" . $kernelver[eval { int($i) } // ""] . "-" . $arch[eval { int($i) } // ""];
                }
                use File::Path qw(make_path);
                if ( !-d "$temp_module_dir" ) {
                    make_path( "$temp_module_dir", { error => \$err } );
                    if ( @{$err} ) {
                        croak "mkdir: cannot create directory " . "$temp_module_dir" . ": $err->[0]\n";
                    }
                }
                use File::Copy qw(copy);
                if (-d "$temp_module_dir") {
                    require File::Path; File::Path::make_path("$temp_module_dir" . '/' . (q{f} =~ m|([^/]+)$|)[0]);
                    require File::Copy; File::Copy::copy(q{f}, "$temp_module_dir" . '/' . (q{f} =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy(q{f}, "$temp_module_dir");
                }
                if (-d "$temp_module_dir") {
                    require File::Path; File::Path::make_path("$temp_module_dir" . '/' . ("$intree_module_dir" =~ m|([^/]+)$|)[0]);
                    require File::Copy; File::Copy::copy("$intree_module_dir", "$temp_module_dir" . '/' . ("$intree_module_dir" =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy("$intree_module_dir", "$temp_module_dir");
                }
        }
    }
    my $source_dir = "$ENV{dkms_tree}/$module/$ENV{module_version}/source";
if (($binaries_only ne q{})) {
        my $binary_only_dir = "$temp_dir_name/dkms_binaries_only";
        do {
    my $__echo_line = "$\"\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        do {
    my $__echo_line = "$\"Creating tarball structure to specifically accomodate binaries.\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        use File::Path qw(make_path);
        if ( mkdir "$binary_only_dir" ) {
            }
        else {
            croak "mkdir: cannot create directory " . "$binary_only_dir" . ": File exists\n";
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$binary_only_dir/PACKAGE_NAME"
      or die "Cannot open file: $OS_ERROR\n";
            print $module;
if ( !( ($module) =~ m{\n\z}msx ) ) { print "\n"; }
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$binary_only_dir/PACKAGE_VERSION"
      or die "Cannot open file: $OS_ERROR\n";
            print $module_version;
if ( !( ($module_version) =~ m{\n\z}msx ) ) { print "\n"; }
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        if ((!$conf)) {
                        my $conf;
            my @conf;
            my %conf;
            $conf = "$source_dir/dkms.conf";
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
            use File::Copy qw(copy);
            if ( -e $conf ) {
                if ( -d "$binary_only_dir/" ) {
                    require File::Copy; File::Copy::copy($conf, "$binary_only_dir/" . '/' . ($conf =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy($conf, "$binary_only_dir/");
                }
            } else {
                croak "cp: cannot stat '-f': No such file or directory\n";
            }
        };
}
    else {
        do {
    my $__echo_line = "$\"\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        do {
    my $__echo_line = "$\"Marking $source_dir for archiving...\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        use File::Path qw(make_path);
        if ( !-d $temp_dir_name ) {
            make_path( $temp_dir_name, { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . $temp_dir_name . ": $err->[0]\n";
            }
        }
        if ( !-d '/dkms_source_tree' ) {
            make_path( '/dkms_source_tree', { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . '/dkms_source_tree' . ": $err->[0]\n";
            }
        }
        use File::Copy qw(copy);
        if (-d '/dkms_source_tree') {
            require File::Path; File::Path::make_path('/dkms_source_tree' . '/' . (q{f} =~ m|([^/]+)$|)[0]);
            require File::Copy; File::Copy::copy(q{f}, '/dkms_source_tree' . '/' . (q{f} =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy(q{f}, '/dkms_source_tree');
        }
        if (-d '/dkms_source_tree') {
            require File::Path; File::Path::make_path('/dkms_source_tree' . '/' . ($source_dir =~ m|([^/]+)$|)[0]);
            require File::Copy; File::Copy::copy($source_dir, '/dkms_source_tree' . '/' . ($source_dir =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy($source_dir, '/dkms_source_tree');
        }
        if (-d '/dkms_source_tree') {
            require File::Path; File::Path::make_path('/dkms_source_tree' . '/' . ('/*' =~ m|([^/]+)$|)[0]);
            require File::Copy; File::Copy::copy('/*', '/dkms_source_tree' . '/' . ('/*' =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy('/*', '/dkms_source_tree');
        }
        if (-d '/dkms_source_tree') {
            require File::Path; File::Path::make_path('/dkms_source_tree' . '/' . ($temp_dir_name =~ m|([^/]+)$|)[0]);
            require File::Copy; File::Copy::copy($temp_dir_name, '/dkms_source_tree' . '/' . ($temp_dir_name =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy($temp_dir_name, '/dkms_source_tree');
        }
    }
if (eval { int(do { chomp(my $_r = qx'echo $kernel_version_list | wc -m | awk {'\''print $1'\''}'); $_r; } > 200) } // "") {
        $kernel_version_list = "manykernels";
    }
    my $tarball_name = "$module-$ENV{module_version}-$kernel_version_list.dkms.tar.gz";
    my $tarball_dest = "$ENV{dkms_tree}/$module/$ENV{module_version}/tarball/";
if (($archive_location ne q{})) {
        $tarball_name = ( ( basename(($ENV{archive_location} // q{})) ) =~ s|^.*/||sr );
if (${archive_location%/*} ne $archive_location) {
            $tarball_dest = ( ( dirname(($ENV{archive_location} // q{})) ) =~ s|/[^/]*$||sr );
        }
    }
    do {
    my $__echo_line = "$\"\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "$\"Tarball location: $tarball_dest/$tarball_name\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
if ((!-d $tarball_dest)) {
if (!(!(do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
            use File::Path qw(make_path);
            if ( !-d "$tarball_dest" ) {
                make_path( "$tarball_dest", { error => \$err } );
                if ( @{$err} ) {
                    croak "mkdir: cannot create directory " . "$tarball_dest" . ": $err->[0]\n";
                }
            }
        };))) {
            die(q{9}, "$\"Missing write permissions for $tarball_dest.\"");
        }
    }
    if (!((-w $tarball_dest))) {
                die(q{9}, "$\"Missing write permissions for $tarball_dest.\"");
    }
if (!(!(do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
        $main_exit_code = system('tar', '-C', $temp_dir_name, '-c', 'af', $tarball_dest, q{/}, $tarball_name, q{.}) >> 8;
    };))) {
        die(q{6}, "$\"Failed to make tarball.\"");
    }
    return;
}

sub get_pkginfo_from_conf {
    my ($file) = @_;
    if (!(((-f $1) && $1 eq *dkms.conf))) {
        return;    }
    read_conf_or_die("$kernelver", "$arch", "$_[0]");
(($PACKAGE_NAME ne q{}) && ($PACKAGE_VERSION ne q{}))
    return;
}

sub load_tarball {
if ((!-e $archive_location)) {
        die(q{2}, "$\"$ENV{archive_location} does not exist.\"");
    }
if ($archive_location eq *.rpm) {
if (!(        $main_exit_code = system('rpm', '-Uvh', "$ENV{archive_location}") >> 8)) {
            $main_exit_code = system('bash', 'autoinstall') >> 8;
}
        else {
            die(q{9}, "$\"Unable to install $ENV{archive_location} using rpm.\"", "$\"Check to ensure that your " . "sys" . "tem" . " can install .rpm files.\"");
        }
    }
    my $temp_dir_name = do {
    my ($in_126, $out_126);
    my $pid_126 = open3($in_126, $out_126, '>&STDERR', 'mktemp_or_die', '-d', $tmp_location, '/dkms.XXXXXX');
    close $in_126 or croak 'Close failed: $OS_ERROR';
    my $result_126 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_126> };
    close $out_126 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_126, 0;
    $result_126
};
# Builtin command 'trap' with dynamic handler not supported
    $main_exit_code = system('tar', '-x', 'af', $archive_location, '-C', $temp_dir_name) >> 8;
if ((!-d $temp_dir_name/dkms_main_tree)) {
        my $conf;
        my @conf;
        my %conf;
        $conf = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_127 = q{};
            my $output_printed_127;
            my $pipeline_success_127 = 1;
            $output_127 = do {
            require File::Find;
            my @find_results;
            File::Find::find(sub { if ($_ =~ /^dkms\.conf$/msx) { push @find_results, $File::Find::name; } }, q{/});
            my $result = join "\n", @find_results;
            if ($result ne q{}) { $result .= "\n"; }
            $CHILD_ERROR = 0;
            $result;
            };
            my $num_lines       = 1;
            my $head_line_count = 0;
            my $result          = q{};
            my $input           = $output_127;
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
            $output_127 = $result;
            if ( !$pipeline_success_127 ) { $main_exit_code = 1; }
            $output_127 =~ s/\n+\z//msx;
            $output_127;
}; $_pipeline_result; };
if ((!$conf)) {
            die(q{3}, "$\"Tarball does not appear to be a correctly formed DKMS archive. No dkms.conf found within it.\"");
        }
        $main_exit_code = system('add_source_tree', (scalar reverse( (scalar reverse ${conf}) =~ s/^fnoc\.smkd//r ) =~ s/dkms\.conf$//r)) >> 8;
return;
    }
    my $loc;
    for my $loc ('dkms_source_tree', 'dkms_binaries_only', q{}) {
if ((!$loc)) {
            die(q{7}, "$\"No valid dkms.conf in dkms_source_tree or dkms_binaries_only.\"", "$\"$ENV{archive_location} is not a valid DKMS tarball.\"");
        }
        my $conf = "$temp_dir_name/$loc/dkms.conf";
        if (!((-f $conf))) {
            next;        }
if (!(!(get_pkginfo_from_conf("$conf");))) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                print "\n";
                $CHILD_ERROR = 0;
            };
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "$\"Malformed dkms.conf, refusing to load.\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
            };
next;
        }
if ((!(        is_module_added("$ENV{PACKAGE_NAME}", "$ENV{PACKAGE_VERSION}")) && (!$force))) {
            die(q{8}, "$\"$ENV{PACKAGE_NAME}-$ENV{PACKAGE_VERSION} is already added!\"", "$\"Aborting.\"");
        }
last;
    }
    $module = "$ENV{PACKAGE_NAME}";
    my $module_version;
    my @module_version;
    my %module_version;
    $module_version = "$ENV{PACKAGE_VERSION}";
    do {
    my $__echo_line = "$\"\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "$\"Loading tarball for $module-$module_version\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
if ($loc =~ /^dkms_source_tree$/msx) {
                $main_exit_code = system('add_source_tree', "$temp_dir_name/dkms_source_tree") >> 8;
    } elsif ($loc =~ /^dkms_binaries_only$/msx) {
        if ((!-d $source_tree/$module-$module_version)) {
            my $source_dir = "$ENV{dkms_tree}/$module/$module_version/source";
            do {
    my $__echo_line = "$\"Creating $source_dir\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            use File::Path qw(make_path);
            my $err;
            if ( !-d "$source_dir" ) {
                make_path( "$source_dir", { error => \$err } );
                if ( @{$err} ) {
                    croak "mkdir: cannot create directory " . "$source_dir" . ": $err->[0]\n";
                }
            }
            do {
    my $__echo_line = "$\"Copying dkms.conf to $source_dir ...\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            use File::Copy qw(copy);
            if (-d "$source_dir") {
                require File::Path; File::Path::make_path("$source_dir" . '/' . (q{f} =~ m|([^/]+)$|)[0]);
                require File::Copy; File::Copy::copy(q{f}, "$source_dir" . '/' . (q{f} =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy(q{f}, "$source_dir");
            }
            if (-d "$source_dir") {
                require File::Path; File::Path::make_path("$source_dir" . '/' . ("$temp_dir_name/dkms_binaries_only/dkms.conf" =~ m|([^/]+)$|)[0]);
                require File::Copy; File::Copy::copy("$temp_dir_name/dkms_binaries_only/dkms.conf", "$source_dir" . '/' . ("$temp_dir_name/dkms_binaries_only/dkms.conf" =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy("$temp_dir_name/dkms_binaries_only/dkms.conf", "$source_dir");
            }
        }
    }
    my $directory;
    for my $directory ("$temp_dir_name/dkms_main_tree", '/*/*') {
        if (!((-d $directory))) {
            next;        }
        my $kernel_arch_to_load = $directory =~ s/\*dkms_main_tree\\//grs;
        my $dkms_dir_location = "$ENV{dkms_tree}/$module/$module_version/$kernel_arch_to_load";
if (((-d $dkms_dir_location) && (!$force))) {
            $main_exit_code = system('warn', "$\"$dkms_dir_location already exists. Skipping...\"") >> 8;
}
        else {
            do {
    my $__echo_line = "$\"Loading $dkms_dir_location...\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
if ( -e "$dkms_dir_location" ) {
                if ( -d "$dkms_dir_location" ) {
                    my $err;
                    require File::Path;
                    File::Path::remove_tree("$dkms_dir_location", {error => \$err});
                    if (@{$err}) {
                        carp "rm: carping: could not remove ", $dkms_dir_location, ": $err->[0]\n";
                    }
                    else {
                                            }
                }
                else {
                    if ( unlink "$dkms_dir_location" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", $dkms_dir_location,
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
            use File::Path qw(make_path);
            if ( !-d $dkms_dir_location ) {
                make_path( $dkms_dir_location, { error => \$err } );
                if ( @{$err} ) {
                    croak "mkdir: cannot create directory " . $dkms_dir_location . ": $err->[0]\n";
                }
            }
            use File::Copy qw(copy);
            if (-d q{/}) {
                require File::Path; File::Path::make_path(q{/} . '/' . (q{f} =~ m|([^/]+)$|)[0]);
                require File::Copy; File::Copy::copy(q{f}, q{/} . '/' . (q{f} =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy(q{f}, q{/});
            }
            if (-d q{/}) {
                require File::Path; File::Path::make_path(q{/} . '/' . ($directory =~ m|([^/]+)$|)[0]);
                require File::Copy; File::Copy::copy($directory, q{/} . '/' . ($directory =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy($directory, q{/});
            }
            if (-d q{/}) {
                require File::Path; File::Path::make_path(q{/} . '/' . ('/*' =~ m|([^/]+)$|)[0]);
                require File::Copy; File::Copy::copy('/*', q{/} . '/' . ('/*' =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy('/*', q{/});
            }
            if (-d q{/}) {
                require File::Path; File::Path::make_path(q{/} . '/' . ($dkms_dir_location =~ m|([^/]+)$|)[0]);
                require File::Copy; File::Copy::copy($dkms_dir_location, q{/} . '/' . ($dkms_dir_location =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy($dkms_dir_location, q{/});
            }
        }
    }
    if (!($loc ne dkms_binaries_only)) {
        (-d $source_tree/$module-$module_version)    }
    return;
}

sub run_match {
    set_kernel_source_dir_and_kconfig("$kernelver");
if ((!$template_kernel)) {
        die(q{1}, "$\"Invalid number of parameters passed.\"", "$\"Usage: match --templatekernel=<kernel-version> -k <kernel-version>\"", "$\"   or: match --templatekernel=<kernel-version> -k <kernel-version> <module>\"");
    }
if ($template_kernel eq $kernelver) {
        die(q{2}, "$\"The templatekernel and the specified kernel version are the same.\"");
    }
    my $template_kernel_status = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_132 = q{};
        my $output_printed_132;
        my $pipeline_success_132 = 1;

        my ($in_133, $out_133);
        my $pid_133 = open3($in_133, $out_133, '>&STDERR', 'do_status', q{}, q{});
        close $in_133 or croak 'Close failed: $OS_ERROR';
        $output_132 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_133> };
        close $out_133 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_133, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_132 = 0; }
        my $grep_result_132_1;
        my @grep_lines_132_1 = split /\n/msx, $output_132;
        my @grep_filtered_132_1 = grep { /:\ installed/msx } @grep_lines_132_1;
        $grep_result_132_1 = join "\n", @grep_filtered_132_1;
                if (!($grep_result_132_1 =~ m{\n\z}msx || $grep_result_132_1 eq q{})) {
                    $grep_result_132_1 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_132_1 > 0 ? 0 : 1;
        $output_132 = $grep_result_132_1;
        if ((scalar @grep_filtered_132_1) == 0) {
            $pipeline_success_132 = 0;
        }
        if ( !$pipeline_success_132 ) { $main_exit_code = 1; }
        $output_132 =~ s/\n+\z//msx;
        $output_132;
}; $_pipeline_result; };
if (($module ne q{})) {
if (!(!((-d $dkms_tree/$module/)))) {
            die(q{3}, "$\"The module: $module is not located in the DKMS tree.\"");
        }
        $template_kernel_status = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_134 = q{};
            my $output_printed_134;
            my $pipeline_success_134 = 1;
            $output_134 .= $template_kernel_status . "\n";
            if ( !($output_134 =~ m{\n\z}msx) ) { $output_134 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_134 = 0; }
            my $grep_result_134_1;
            my @grep_lines_134_1 = split /\n/msx, $output_134;
            my @grep_filtered_134_1 = grep { /^$module,/msx } @grep_lines_134_1;
            $grep_result_134_1 = join "\n", @grep_filtered_134_1;
                        if (!($grep_result_134_1 =~ m{\n\z}msx || $grep_result_134_1 eq q{})) {
                            $grep_result_134_1 .= "\n";
                        }
            $CHILD_ERROR = scalar @grep_filtered_134_1 > 0 ? 0 : 1;
            $output_134 = $grep_result_134_1;
            if ((scalar @grep_filtered_134_1) == 0) {
                $pipeline_success_134 = 0;
            }
            if ( !$pipeline_success_134 ) { $main_exit_code = 1; }
            $output_134 =~ s/\n+\z//msx;
            $output_134;
}; $_pipeline_result; };
    }
    do {
    my $__echo_line = "$\"\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "$\"Matching modules in kernel: $kernelver ($arch)\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "$\"to the configuration of kernel: $ENV{template_kernel} ($arch)\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
if ((!$template_kernel_status)) {
        do {
    my $__echo_line = "$\"\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        do {
    my $__echo_line = "$\"There is nothing to be done for this match.\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
return q{0};
    }
    prepare_kernel("$kernelver", "$arch");
    my $temp_file_ps_fh_6 = q{/tmp} . '/process_sub_fh_6.tmp';
    my $output_ps_fh_6;
    {
        local *STDOUT;
        open STDOUT, '>', \$output_ps_fh_6 or croak "Cannot redirect STDOUT";
        my $output_135 = q{};
        my $output_printed_135;
        print $template_kernel_status;
    if ( !( ($template_kernel_status) =~ m{\n\z}msx ) ) { print "\n"; }
    if ($output_135 ne q{} && !$output_printed_135) {
        print $output_135;
    }
    }
    use File::Path qw(make_path);
    my $temp_dir_fh_6 = dirname($temp_file_ps_fh_6);
    if (!-d $temp_dir_fh_6) { make_path($temp_dir_fh_6); }
    open my $fh_ps_fh_6, '>', $temp_file_ps_fh_6 or croak "Cannot create temp file: $ERRNO\n";
    print {$fh_ps_fh_6} $output_ps_fh_6;
    close $fh_ps_fh_6 or croak "Close failed: $ERRNO\n";
    open STDIN, '<', $temp_file_ps_fh_6 or croak "Cannot open process substitution: $ERRNO\n";
    my $template_line;
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $template_line = $_fields[0] // q{};
        my $template_module;
        my @template_module;
        my %template_module;
        $template_module = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_136 = q{};
            my $output_printed_136;
            my $pipeline_success_136 = 1;
            $output_136 .= $template_line . "\n";
            if ( !($output_136 =~ m{\n\z}msx) ) { $output_136 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_136 = 0; }
            my @lines = split /\n/msx, $output_136;
            my @result;
            foreach my $line (@lines) {
                chomp $line;
                if ($line =~ /^\s*$/msx) { next; }
                my @fields = split /\s+/msx, $line;
                push @result, ($line . "\n");
            }
            $output_136 = join "", @result;

            my @sed_lines_136 = split /\n/msx, $output_136;
            my @sed_result_136;
            foreach my $line (@sed_lines_136) {
            chomp $line;
            $line =~ s/,$//gmsx;
            push @sed_result_136, $line;
            }
            $output_136 = join "\n", @sed_result_136;

            if ( !$pipeline_success_136 ) { $main_exit_code = 1; }
            $output_136 =~ s/\n+\z//msx;
            $output_136;
}; $_pipeline_result; };
        my $template_version;
        my @template_version;
        my %template_version;
        $template_version = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_137 = q{};
            my $output_printed_137;
            my $pipeline_success_137 = 1;
            $output_137 .= $template_line . "\n";
            if ( !($output_137 =~ m{\n\z}msx) ) { $output_137 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_137 = 0; }
            my @lines = split /\n/msx, $output_137;
            my @result;
            foreach my $line (@lines) {
                chomp $line;
                if ($line =~ /^\s*$/msx) { next; }
                my @fields = split /\s+/msx, $line;
                push @result, ($line . "\n");
            }
            $output_137 = join "", @result;

            my @sed_lines_137 = split /\n/msx, $output_137;
            my @sed_result_137;
            foreach my $line (@sed_lines_137) {
            chomp $line;
            $line =~ s/,$//gmsx;
            push @sed_result_137, $line;
            }
            $output_137 = join "\n", @sed_result_137;

            if ( !$pipeline_success_137 ) { $main_exit_code = 1; }
            $output_137 =~ s/\n+\z//msx;
            $output_137;
}; $_pipeline_result; };
        do {
    my $__echo_line = "$\"Module:  $template_module\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        do {
    my $__echo_line = "$\"Version: $template_version\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        $main_exit_code = system('maybe_build_module', "$template_module", "$template_version", "$kernelver", "$arch") >> 8;
        $main_exit_code = system('maybe_install_module', "$template_module", "$template_version", "$kernelver", "$arch") >> 8;
    }
    return;
}

sub report_build_problem {
if (((-x '/usr/share/apport/apport') && !(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $_wa0 = 'python3';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    }))) {
        $main_exit_code = system('python3', '/usr/share/apport/package-hooks/dkms_packages.py', '-m', $module, '-v', $module_version, '-k', $kernelver[0]) >> 8;
    }
    die("@ARGV");
    return;
}

sub read_arg {
    my $rematch = "^[^=]*=(.*)$";
if ($ENV{2} =~ /$rematch/msx) {
my $L = <>;
chomp $L;
$CHILD_ERROR = defined($L) ? 0 : 1;
}
    else {
my $L = <>;
chomp $L;
$CHILD_ERROR = defined($L) ? 0 : 1;
return q{1};
    }
    return;
}

sub parse_kernelarch {
if ($ENV{1} =~ /$mv_re/msx) {
        $kernelver{"${#kernelver[@"} = $BASH_REMATCH[1];
        $arch{"${#arch[@"} = $BASH_REMATCH[2];
}
    else {
        $kernelver{"${#kernelver[@"} = "$_[0]";
    }
    return;
}

sub parse_moduleversion {
if ($ENV{1} =~ /$mv_re/msx) {
        $module = $BASH_REMATCH[1];
        my $module_version;
        my @module_version;
        my %module_version;
        $module_version = $BASH_REMATCH[2];
}
    else {
        $module = "$_[0]";
    }
    return;
}

sub check_root {
    if ($(id -u) eq 0) {
        return;        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    die(q{1}, "$\"You must be root to use this command.\"");
    return;
}

sub check_rw_dkms_tree {
    if ((-w "$dkms_tree")) {
        return;        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    die(q{1}, "$\"No write access to DKMS tree at " . ($ENV{dkms_tree} // q{}) . "\"");
    return;
}

sub add_source_tree {
    my $from = do {
    my ($in_141, $out_141);
    my $pid_141 = open3($in_141, $out_141, '>&STDERR', 'readlink', '-f', $1);
    close $in_141 or croak 'Close failed: $OS_ERROR';
    my $result_141 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_141> };
    close $out_141 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_141, 0;
    $result_141
};
if (!(!((($from ne q{}) && (-f $from/dkms.conf))))) {
        die(q{9}, "$\"$_[0] must contain a dkms.conf file!\"");
    }
    check_root();
    setup_kernels_arches();
if (!(!(get_pkginfo_from_conf("$from/dkms.conf");))) {
        die('10', "$\"Malformed dkms.conf file. Cannot load source tree.\"");
    }
    $module = "$ENV{PACKAGE_NAME}";
    my $module_version;
    my @module_version;
    my %module_version;
    $module_version = "$ENV{PACKAGE_VERSION}";
if ((($force ne q{}) && (-d $source_tree/$module-$module_version))) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "\n";
            $CHILD_ERROR = 0;
        };
        do {
    my $__echo_line = "$\"Forcing install of $module-$module_version\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
if ( -e "$ENV{source_tree}/$module-$module_version" ) {
            if ( -d "$ENV{source_tree}/$module-$module_version" ) {
                my $err;
                require File::Path;
                File::Path::remove_tree("$ENV{source_tree}/$module-$module_version", {error => \$err});
                if (@{$err}) {
                    carp "rm: carping: could not remove ", "$ENV{source_tree}/$module-$module_version", ": $err->[0]\n";
                }
                else {
                                    }
            }
            else {
                if ( unlink "$ENV{source_tree}/$module-$module_version" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$ENV{source_tree}/$module-$module_version",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
if ($from =~ /^$source_tree/$module-$module_version$/msx) {
        return;    } elsif ($from =~ /^$dkms_tree/$module/$version/source$/msx) {
        return;    } elsif ($from =~ /^$dkms_tree/$module/$version/build$/msx) {
        return;    }
    use File::Path qw(make_path);
    my $err;
    if ( !-d "$ENV{source_tree}/$module-$module_version" ) {
        make_path( "$ENV{source_tree}/$module-$module_version", { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . "$ENV{source_tree}/$module-$module_version" . ": $err->[0]\n";
        }
    }
    use File::Copy qw(copy);
    if ( -e q{r} ) {
        if ( -d "$ENV{source_tree}/$module-$module_version" ) {
            require File::Copy; File::Copy::copy(q{r}, "$ENV{source_tree}/$module-$module_version" . '/' . (q{r} =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy(q{r}, "$ENV{source_tree}/$module-$module_version");
        }
    } else {
        croak "cp: cannot stat '-f': No such file or directory\n";
    }
    if ( -e "$from" ) {
        if ( -d "$ENV{source_tree}/$module-$module_version" ) {
            require File::Copy; File::Copy::copy("$from", "$ENV{source_tree}/$module-$module_version" . '/' . ("$from" =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy("$from", "$ENV{source_tree}/$module-$module_version");
        }
    } else {
        croak "cp: cannot stat '-f': No such file or directory\n";
    }
    if ( -e '/*' ) {
        if ( -d "$ENV{source_tree}/$module-$module_version" ) {
            require File::Copy; File::Copy::copy('/*', "$ENV{source_tree}/$module-$module_version" . '/' . ('/*' =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy('/*', "$ENV{source_tree}/$module-$module_version");
        }
    } else {
        croak "cp: cannot stat '-f': No such file or directory\n";
    }
    return;
}

sub autoinstall {
    my $status;
    my $mv;
    my $mvka;
    my $m;
    my $v;
    my $k;
    my $a;
    my $progress;
    my $next_depends;
    my @to_install = ();
    my @next_install = ();
    my @known_modules = ();
    my @installed_modules = ();
    my @skipped_modules = ();
    my @failed_modules = ();
    my %build_depends = ();
    my %latest = ();
    my $temp_file_ps_fh_7 = q{/tmp} . '/process_sub_fh_7.tmp';
    my $output_ps_fh_7;
    {
    my ($in, $out);
    my $pid = open3($in, $out, '>&STDERR', 'bash', '-c', 'module_status');
    close $in or croak 'Close failed: $OS_ERROR';
    $output_ps_fh_7 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
$CHILD_ERROR = $? >> 8;
    }
    use File::Path qw(make_path);
    my $temp_dir_fh_7 = dirname($temp_file_ps_fh_7);
    if (!-d $temp_dir_fh_7) { make_path($temp_dir_fh_7); }
    open my $fh_ps_fh_7, '>', $temp_file_ps_fh_7 or croak "Cannot create temp file: $ERRNO\n";
    print {$fh_ps_fh_7} $output_ps_fh_7;
    close $fh_ps_fh_7 or croak "Close failed: $ERRNO\n";
    open STDIN, '<', $temp_file_ps_fh_7 or croak "Cannot open process substitution: $ERRNO\n";
while ( my $L = <> ) {
    chomp $L;
    my @_fields = split /\s+/msx, $L;
    $status = $_fields[0] // q{};
    $mvka = $_fields[1] // q{};
            my $IFS = q{/};
$m = <>;
chomp $m;
$CHILD_ERROR = defined($m) ? 0 : 1;
if ("${latest["$m"]}" eq q{}) {
            $known_modules{"${#known_modules[@"} = "$m";
            $latest{"$m"} = "$v";
}
        else {
            if ((("qx'VER "$v"'">"qx'VER "${latest["$m"]}"'") ne q{})) {
                $latest{"$m"} = "$v";
            }
        }
    }
    for my $m (@known_modules) {
        $v = $latest{'"$m"'};
if (!(        _is_module_installed("$m", "$v", "$kernelver", "$arch"))) {
            $installed_modules{"${#installed_modules[@"} = "$m";
next;
        }
if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            module_status_weak("$m", "$v", "$kernelver", "$arch");
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
            $installed_modules{"${#installed_modules[@"} = "$m";
next;
        }
        read_conf_or_die("$kernelver", "$arch", "$ENV{dkms_tree}/$m/$v/source/dkms.conf");
if ((!$AUTOINSTALL)) {
next;
        }
        $to_install{"${#to_install[@"} = "$m/$v";
        $build_depends{"$m"} = (join(" ", @BUILD_DEPENDS));
    }
    if (!(($to_install ne q{}))) {
        return q{0};    }
while ( 1 ) {
        $progress = q{0};
        @next_install = ();
        for my $m (keys %build_depends) {
            $next_depends = q{};
            my $d;
            for my $d ($build_depends{$m}) {
                my $i;
                for my $i ($installed_modules[eval { int(@) } // ""], $skipped_modules[eval { int(@) } // ""]) {
                    if ("$d" eq "$i") {
                        next LABEL2;                        $CHILD_ERROR = 0;
                    } else {
                        $CHILD_ERROR = 1;
                    }
                }
                $next_depends = "$d ";
            }
            $build_depends{"$m"} = (${next_depends} =~ s/ $//sr =~ s/ $//sr);
        }
        for my $mv (@to_install) {
                $IFS = q{/};
$m = <>;
chomp $m;
$CHILD_ERROR = defined($m) ? 0 : 1;
if ("${build_depends[$m]}" eq q{}) {
                do {
                    local %ENV = %ENV;
                    my $known_modules = $known_modules;
                    my $skipped_modules = $skipped_modules;
                    my $next_install = $next_install;
                    my $d = $d;
                    my $installed_modules = $installed_modules;
                    my $progress = $progress;
                    my $m = $m;
                    my $k = $k;
                    my $to_install = $to_install;
                    my $IFS = $IFS;
                    my $i = $i;
                    my $next_depends = $next_depends;
                    my $mvka = $mvka;
                    my $mv = $mv;
                    my %latest = %latest;
                    my $failed_modules = $failed_modules;
                    my $status = $status;
                    my $a = $a;
                    my %build_depends = %build_depends;
                    my $v = $v;
                    my $arch = "$arch";
                    my $kernelver = "$kernelver";
                    my $module = "$m";
                    my $module_version = "$v";
                    install_module();
                    q{};
                };
                $status = $?;
if ("$status" eq 0) {
                    $installed_modules{"${#installed_modules[@"} = "$m";
                    $progress = eval { int($progress +1) } // "";
}
                else {
                    if ("$status" eq 77) {
                        $skipped_modules{"${#skipped_modules[@"} = "$m";
                        $progress = eval { int($progress +1) } // "";
}
                    else {
                        $failed_modules{"${#failed_modules[@"} = "$m($status)";
                    }
                }
}
            else {
                $next_install{"${#next_install[@"} = "$mv";
            }
        }
1 while wait() > -1;
$CHILD_ERROR = $? == -1 ? 0 : $? >> 8;
        @to_install = (@next_install);
        if (!(($progress > 0))) {
            last;        }
    }
if ((${#installed_modules[@]} > 0)) {
        do {
    my $__echo_line = "dkms autoinstall on $kernelver/$arch succeeded for " . (join(" ", @installed_modules));
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
if ((${#skipped_modules[@]} > 0)) {
        do {
    my $__echo_line = "dkms autoinstall on $kernelver/$arch was skipped for " . (join(" ", @skipped_modules));
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
if ((${#failed_modules[@]} > 0)) {
        do {
    my $__echo_line = "dkms autoinstall on $kernelver/$arch failed for " . (join(" ", @failed_modules));
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
    for my $mv (@to_install) {
            $IFS = q{/};
$m = <>;
chomp $m;
$CHILD_ERROR = defined($m) ? 0 : 1;
        do {
    my $__echo_line = "$m/$v autoinstall failed due to missing dependencies: " . $build_depends{$m};
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
if (((${#failed_modules[@]} > 0) || (${#to_install[@]} > 0))) {
        die('11', "$\"One or more modules failed to install during autoinstall.\"", "$\"Refer to previous errors for more information.\"");
    }
    return;
}
my $PATH;
my @PATH;
my %PATH;
$PATH = "$PATH:/usr/lib/dkms";
$main_exit_code = system('umask', '022') >> 8;
delete $ENV{CC};
delete $ENV{CXX};
delete $ENV{CFLAGS};
delete $ENV{CXXFLAGS};
delete $ENV{LDFLAGS};
my $current_kernel;
my @current_kernel;
my %current_kernel;
$current_kernel = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__rel; join(" ", @__parts) . "\n"; };
my $current_os;
my @current_os;
my %current_os;
$current_os = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__sys; join(" ", @__parts) . "\n"; };
my $running_distribution;
my @running_distribution;
my %running_distribution;
$running_distribution = do {
    my ($in_148, $out_148);
    my $pid_148 = open3($in_148, $out_148, '>&STDERR', 'distro_version');
    close $in_148 or croak 'Close failed: $OS_ERROR';
    my $result_148 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_148> };
    close $out_148 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_148, 0;
    $result_148
};
my $dkms_tree;
my @dkms_tree;
my %dkms_tree;
$dkms_tree = "/var/lib/dkms";
my $source_tree;
my @source_tree;
my %source_tree;
$source_tree = "/usr/src";
my $install_tree;
my @install_tree;
my %install_tree;
$install_tree = "/lib/modules";
my $tmp_location;
my @tmp_location;
my %tmp_location;
$tmp_location = (defined ($ENV{TMPDIR} // q{}) && ($ENV{TMPDIR} // q{}) ne q{} ? ($ENV{TMPDIR} // q{}) : '/tmp');
my $verbose;
my @verbose;
my %verbose;
$verbose = "";
my $symlink_modules;
my @symlink_modules;
my %symlink_modules;
$symlink_modules = "";
$tmpfile = do {
    my ($in_149, $out_149);
    my $pid_149 = open3($in_149, $out_149, '>&STDERR', 'mktemp_or_die');
    close $in_149 or croak 'Close failed: $OS_ERROR';
    my $result_149 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_149> };
    close $out_149 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_149, 0;
    $result_149
};
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', "$tmpfile"
      or die "Cannot open file: $OS_ERROR\n";
    print "Hello, DKMS!\n";
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
if ("$(cat "$tmpfile")" ne "Hello, DKMS!") {
    $main_exit_code = system('warn', "$\"dkms will not function properly without some free space in $TMPDIR ($tmp_location).\"") >> 8;
}
if ( -e "$tmpfile" ) {
    if ( -d "$tmpfile" ) {
        carp "rm: carping: ", "$tmpfile",
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "$tmpfile" ) {
                    }
        else {
            carp "rm: carping: could not remove ", "$tmpfile",
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}
if (((!${ADDON_MODULES_DIR}) && (-e '/etc/sysconfig/module-init-tools'))) {
        $main_exit_code = system('.', '/etc/sysconfig/module-init-tools') >> 8;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
my $addon_modules_dir;
my @addon_modules_dir;
my %addon_modules_dir;
$addon_modules_dir = ${ADDON_MODULES_DIR};
$weak_modules = ($ENV{WEAK_MODULES_BIN} // q{});
read_framework_conf($dkms_framework_nonsigning_variables);
$module = "";
my $module_version;
my @module_version;
my %module_version;
$module_version = "";
my $template_kernel;
my @template_kernel;
my %template_kernel;
$template_kernel = "";
my $conf;
my @conf;
my %conf;
$conf = "";
my $kernel_config;
my @kernel_config;
my %kernel_config;
$kernel_config = "";
my $kconfig_fromcli;
my @kconfig_fromcli;
my %kconfig_fromcli;
$kconfig_fromcli = "";
my $archive_location;
my @archive_location;
my %archive_location;
$archive_location = "";
my $kernel_source_dir;
my @kernel_source_dir;
my %kernel_source_dir;
$kernel_source_dir = "";
my $ksourcedir_fromcli;
my @ksourcedir_fromcli;
my %ksourcedir_fromcli;
$ksourcedir_fromcli = "";
$action = "";
$force = "";
my $force_version_override;
my @force_version_override;
my %force_version_override;
$force_version_override = "";
$binaries_only = "";
$source_only = "";
$all = "";
my $module_suffix;
my @module_suffix;
my %module_suffix;
$module_suffix = "";
my $module_uncompressed_suffix;
my @module_uncompressed_suffix;
my %module_uncompressed_suffix;
$module_uncompressed_suffix = "";
my $module_compressed_suffix;
my @module_compressed_suffix;
my %module_compressed_suffix;
$module_compressed_suffix = "";
my $rpm_safe_upgrade;
my @rpm_safe_upgrade;
my %rpm_safe_upgrade;
$rpm_safe_upgrade = "";
my @directive_array = ();
my @kernelver = ();
my @arch = ();
$weak_modules = q{};
my $last_mvka;
my @last_mvka;
my %last_mvka;
$last_mvka = q{};
my $last_mvka_conf;
my @last_mvka_conf;
my %last_mvka_conf;
$last_mvka_conf = q{};
my $try_source_tree;
my @try_source_tree;
my %try_source_tree;
$try_source_tree = q{};
my $die_is_fatal;
my @die_is_fatal;
my %die_is_fatal;
$die_is_fatal = "yes";
if ((-x '/sbin/weak-modules')) {
        $weak_modules = '/sbin/weak-modules';
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
if ((-x '/usr/lib/module-init-tools/weak-modules')) {
        $weak_modules = '/usr/lib/module-init-tools/weak-modules';
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
my $no_depmod;
my @no_depmod;
my %no_depmod;
$no_depmod = "";
$action_re = '^(remove|(auto|un)?install|match|mktarball|(un)?build|add|status|ldtarball)$';
while ( !($CHILD_ERROR = ($main_exit_code = eval { int($# > 0) } // "") ? 0 : 1) ) {
if ($arg1 =~ /^--module.*$/msx or $arg1 =~ /^-m$/msx) {
                        read_arg('_mv', "$_[0]", "$_[1]");
        if ($CHILD_ERROR != 0) {
            # Builtin command 'shift' not implemented
        }
                parse_moduleversion("$ENV{_mv}");
    } elsif ($arg1 =~ /^-v$/msx) {
                        read_arg('module_version', "$_[0]", "$_[1]");
        if ($CHILD_ERROR != 0) {
            # Builtin command 'shift' not implemented
        }
    } elsif ($arg1 =~ /^--kernelver.*$/msx or $arg1 =~ /^-k$/msx) {
                        read_arg('_ka', "$_[0]", "$_[1]");
        if ($CHILD_ERROR != 0) {
            # Builtin command 'shift' not implemented
        }
                parse_kernelarch("$ENV{_ka}");
    } elsif ($arg1 =~ /^--templatekernel.*$/msx) {
                        read_arg('template_kernel', "$_[0]", "$_[1]");
        if ($CHILD_ERROR != 0) {
            # Builtin command 'shift' not implemented
        }
    } elsif ($arg1 =~ /^-c$/msx) {
                        read_arg('conf', "$_[0]", "$_[1]");
        if ($CHILD_ERROR != 0) {
            # Builtin command 'shift' not implemented
        }
    } elsif ($arg1 =~ /^--quiet$/msx or $arg1 =~ /^-q$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
# Builtin command 'exec' not implemented
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    } elsif ($arg1 =~ /^--version$/msx or $arg1 =~ /^-V$/msx) {
                do {
    my $__echo_line = "$\"dkms-3.0.11\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        exit 0;
    } elsif ($arg1 =~ /^--no-initrd$/msx) {
                $main_exit_code = system('deprecated', "$\"--no-initrd\"") >> 8;
    } elsif ($arg1 =~ /^--no-clean-kernel$/msx) {
                $main_exit_code = system('deprecated', "$\"--no-clean-kernel\"") >> 8;
    } elsif ($arg1 =~ /^--no-prepare-kernel$/msx) {
                $main_exit_code = system('deprecated', "$\"--no-prepare-kernel\"") >> 8;
    } elsif ($arg1 =~ /^--binaries-only$/msx) {
                $binaries_only = "binaries-only";
    } elsif ($arg1 =~ /^--source-only$/msx) {
                $source_only = "source-only";
    } elsif ($arg1 =~ /^--force$/msx) {
                $force = "true";
    } elsif ($arg1 =~ /^--force-version-override$/msx) {
                $force_version_override = "true";
    } elsif ($arg1 =~ /^--all$/msx) {
                $all = "true";
    } elsif ($arg1 =~ /^--verbose$/msx) {
                $verbose = "true";
    } elsif ($arg1 =~ /^--rpm_safe_upgrade$/msx) {
                $rpm_safe_upgrade = "true";
    } elsif ($arg1 =~ /^--dkmstree.*$/msx) {
                        read_arg('dkms_tree', "$_[0]", "$_[1]");
        if ($CHILD_ERROR != 0) {
            # Builtin command 'shift' not implemented
        }
    } elsif ($arg1 =~ /^--sourcetree.*$/msx) {
                        read_arg('source_tree', "$_[0]", "$_[1]");
        if ($CHILD_ERROR != 0) {
            # Builtin command 'shift' not implemented
        }
    } elsif ($arg1 =~ /^--installtree.*$/msx) {
                        read_arg('install_tree', "$_[0]", "$_[1]");
        if ($CHILD_ERROR != 0) {
            # Builtin command 'shift' not implemented
        }
    } elsif ($arg1 =~ /^--symlink-modules$/msx) {
                my $symlink_module;
        my @symlink_module;
        my %symlink_module;
        $symlink_module = "true";
    } elsif ($arg1 =~ /^--config.*$/msx) {
                        read_arg('kernel_config', "$_[0]", "$_[1]");
        if ($CHILD_ERROR != 0) {
            # Builtin command 'shift' not implemented
        }
                $kconfig_fromcli = "true";
    } elsif ($arg1 =~ /^--archive.*$/msx) {
                        read_arg('archive_location', "$_[0]", "$_[1]");
        if ($CHILD_ERROR != 0) {
            # Builtin command 'shift' not implemented
        }
    } elsif ($arg1 =~ /^--arch.*$/msx or $arg1 =~ /^-a$/msx) {
                        read_arg('_aa', "$_[0]", "$_[1]");
        if ($CHILD_ERROR != 0) {
            # Builtin command 'shift' not implemented
        }
                $arch{"${#arch[@"} = "$ENV{_aa}";
    } elsif ($arg1 =~ /^--kernelsourcedir.*$/msx) {
                        read_arg('kernel_source_dir', "$_[0]", "$_[1]");
        if ($CHILD_ERROR != 0) {
            # Builtin command 'shift' not implemented
        }
                $ksourcedir_fromcli = "true";
    } elsif ($arg1 =~ /^--directive.*$/msx) {
                        read_arg('_da', "$_[0]", "$_[1]");
        if ($CHILD_ERROR != 0) {
            # Builtin command 'shift' not implemented
        }
                $directive_array{"${#directive_array[@"} = "$ENV{_da}";
    } elsif ($arg1 =~ /^--no-depmod$/msx) {
                $no_depmod = "true";
    } elsif ($arg1 =~ /^--modprobe-on-install$/msx) {
                my $modprobe_on_install;
        my @modprobe_on_install;
        my %modprobe_on_install;
        $modprobe_on_install = "true";
    } elsif ($arg1 =~ /^--debug$/msx) {
        $ENV{PS4} = '${BASH_SOURCE}@${LINENO}(${FUNCNAME[0]}): ';
        # set -x not implemented
    } elsif ($arg1 =~ /^-j$/msx) {
                        read_arg('parallel_jobs', "$_[0]", "$_[1]");
        if ($CHILD_ERROR != 0) {
            # Builtin command 'shift' not implemented
        }
    } elsif ($arg1 =~ /^-.*$/msx) {
                $main_exit_code = system('error', "$\" Unknown option: $_[0]\"") >> 8;
                show_usage();
        exit 2;
    } elsif (1) {
        if ($ENV{1} =~ /$action_re/msx) {
            if (($action ne q{})) {
                                die(q{4}, "$\"Cannot specify more than one action.\"");
                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
            $action = "$_[0]";
}
        else {
            if (((-f $1) && $1 eq *dkms.conf)) {
                $try_source_tree = (scalar reverse( (scalar reverse $_[0]) =~ s/^fnoc\.smkd//r ) =~ s/dkms\.conf$//r) . "./";
}
            else {
                if (((-d $1) && (-f $1/dkms.conf))) {
                    $try_source_tree = "$_[0]";
}
                else {
                    if ((-f $1)) {
                        $archive_location = "$_[0]";
}
                    else {
                        if ((!$module)) {
                            parse_moduleversion("$_[0]");
}
                        else {
                            $main_exit_code = system('warn', "$\"I do not know how to handle $_[0].\"") >> 8;
                        }
                    }
                }
            }
        }
    }
# Builtin command 'shift' not implemented
}
my $temp_file_ps_fh_8 = q{/tmp} . '/process_sub_fh_8.tmp';
my $output_ps_fh_8;
{
    local *STDOUT;
    open STDOUT, '>', \$output_ps_fh_8 or croak "Cannot redirect STDOUT";
    my $output_150 = q{};
    my $output_printed_150;
    print "Hello, DKMS!\n";
if ($output_150 ne q{} && !$output_printed_150) {
    print $output_150;
}
}
use File::Path qw(make_path);
my $temp_dir_fh_8 = dirname($temp_file_ps_fh_8);
if (!-d $temp_dir_fh_8) { make_path($temp_dir_fh_8); }
open my $fh_ps_fh_8, '>', $temp_file_ps_fh_8 or croak "Cannot create temp file: $ERRNO\n";
print {$fh_ps_fh_8} $output_ps_fh_8;
close $fh_ps_fh_8 or croak "Close failed: $ERRNO\n";
open STDIN, '<', $temp_file_ps_fh_8 or croak "Cannot open process substitution: $ERRNO\n";
$line = <>;
chomp $line;
$CHILD_ERROR = defined($line) ? 0 : 1;
if ("$line" ne "Hello, DKMS!") {
    $main_exit_code = system('warn', "$\"dkms will not function properly if /proc is not mounted.\"") >> 8;
}
if ((($binaries_only ne q{}) && ($source_only ne q{}))) {
    die(q{8}, "$\" You have specified both --binaries-only and --source-only.\"", "$\"You cannot do this.\"");
}
if (eval { int(scalar(@kernelver) != scalar(@arch) &&     scalar(@arch) > 1) } // "") {
    die(q{1}, "$\" If more than one arch is specified on the command line, then there\"", "$\"must be an equal number of kernel versions also specified (1:1 relationship).\"");
}
if ((($kernelver ne q{}) && ($all ne q{}))) {
    die(q{2}, "$\" You cannot specify a kernel version and also specify\"", "$\"--all on the command line.\"");
}
if ((($arch ne q{}) && ($all ne q{}))) {
    die(q{3}, "$\" You cannot specify an arch and also specify\"", "$\"--all on the command line.\"");
}
if (($weak_modules ne q{})) {
    my $weak_modules_no_initrd;
    my @weak_modules_no_initrd;
    my %weak_modules_no_initrd;
    $weak_modules_no_initrd = "--no-initramfs";
}
$parallel_jobs = (defined ${parallel_jobs} && ${parallel_jobs} ne q{} ? ${parallel_jobs} : do { my $_result = do {
    my ($in_152, $out_152);
    my $pid_152 = open3($in_152, $out_152, '>&STDERR', 'get_num_cpus');
    close $in_152 or croak 'Close failed: $OS_ERROR';
    my $result_152 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_152> };
    close $out_152 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_152, 0;
    $result_152
}; $_result; });
if ("$parallel_jobs" eq 0) {
        $parallel_jobs = "";
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
setup_kernels_arches("$action");
if ("$action" =~ /^remove$/msx or "$action" =~ /^unbuild$/msx or "$action" =~ /^uninstall$/msx) {
        check_module_args($action);
        module_is_added_or_die();
            if ($action eq uninstall) {
                check_root();
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ($CHILD_ERROR != 0) {
                check_rw_dkms_tree();
    }
        $CHILD_ERROR = 0;
} elsif ("$action" =~ /^add$/msx or "$action" =~ /^build$/msx or "$action" =~ /^install$/msx) {
        check_all_is_banned($action);
            if ($action eq install) {
                check_root();
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ($CHILD_ERROR != 0) {
                check_rw_dkms_tree();
    }
        $CHILD_ERROR = 0;
} elsif ("$action" =~ /^autoinstall$/msx) {
        if (do {
check_root();
        $CHILD_ERROR == 0
    }) {
                autoinstall();
    }
} elsif ("$action" =~ /^match$/msx) {
        if (do {
if (do {
check_root();
    $CHILD_ERROR == 0
}) {
        have_one_kernel("match");
}
        $CHILD_ERROR == 0
    }) {
                run_match();
    }
} elsif ("$action" =~ /^mktarball$/msx) {
        check_module_args('mktarball');
        module_is_added_or_die();
        make_tarball();
} elsif ("$action" =~ /^status$/msx) {
        show_status();
} elsif ("$action" =~ /^ldtarball$/msx) {
    if (($(id -u) ne 0 && $force eq true)) {
        die(q{1}, "$\"You must be root to use this command with the --force option.\"");
    }
        if (do {
load_tarball();
        $CHILD_ERROR == 0
    }) {
                add_module();
    }
} elsif (1) {
        $main_exit_code = system('error', "$\"Unknown action specified: \"$action\"\"") >> 8;
        show_usage();
}

exit $main_exit_code;
