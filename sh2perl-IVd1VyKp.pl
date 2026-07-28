#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use locale;
use IPC::Open3;

my $main_exit_code = 0;
my $output         = q{};
our $CHILD_ERROR;

my $autoinstall_all_kernels;
my $NEWEST_KERNEL;
my $VERSION;
my $NAME;
my $RELEASE_UPGRADE_IN_PROGRESS;
my $ARCH;
my $TARBALL_ROOT;
my $CURRENT_KERNEL;
my $KERNEL;
my $UPGRADE;
my $dkms_status;

$__set_e = 1;
if ((-f '/usr/share/debconf/confmodule')) {
        $main_exit_code = system('.', '/usr/share/debconf/confmodule') >> 8;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
my $uname_s = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__sys; join(" ", @__parts) . "\n"; };

sub _get_kernel_dir {
    my ($KVER) = @_;
    my $DIR;
if ($uname_s =~ /^Linux$/msx) {
                $DIR = "/lib/modules/$KVER/build";
    } elsif ($uname_s =~ /^GNU/kFreeBSD$/msx) {
                $DIR = "/usr/src/kfreebsd-headers-$KVER/sys";
    }
;
    say $DIR;
    return;
}

sub _check_kernel_dir {
    my ($file) = @_;
    my $DIR = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', '_get_kernel_dir', $_[0]);
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
if ($uname_s =~ /^Linux$/msx) {
                $main_exit_code = system('test', '-e', $DIR, '/include') >> 8;
    } elsif ($uname_s =~ /^GNU/kFreeBSD$/msx) {
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

sub _is_kernel_name_correct {
if ((-e "/lib/modules/$1")) {
        say 'yes';
}
    else {
        say 'no';
    }
    return;
}

sub _get_newest_kernel_debian {
    my ($file) = @_;
    $NEWEST_KERNEL = q{};
    my $NEWEST_VERSION = q{};
    my $NEWEST_ABI = q{};
    my $KERNEL_VERSION;
    my $ABI;
    my $COMPARE_TO;
    my $kernel;
    for my $kernel ('/boot/config-*') {
        if (!((-f "$kernel"))) {
            next;        }
        $KERNEL = ${kernel} =~ s/^.*?-//r;
        $KERNEL_VERSION = ${KERNEL} =~ s/-.*$//sr;
        $ABI = ${KERNEL} =~ s/^.*?-//r;
        $ABI = ${ABI} =~ s/-.*$//sr;
if ("$NEWEST_KERNEL" eq q{}) {
            $COMPARE_TO = $_[0];
}
        else {
            $COMPARE_TO = "$NEWEST_VERSION-$NEWEST_ABI";
        }
if ($(dpkg --compare-versions "$KERNEL_VERSION-$ABI" ge "$COMPARE_TO" && echo "yes" ||               echo "no") eq "yes") {
            $NEWEST_KERNEL = $KERNEL;
            $NEWEST_VERSION = $KERNEL_VERSION;
            $NEWEST_ABI = $ABI;
        }
    }
;
    say $NEWEST_KERNEL;
    return;
}

sub _get_newest_kernel_rhel {
    # Original bash: rpm -q --qf="%{VERSION}-%{RELEASE}.%{ARCH}\n" --whatprovides kernel | tail -n 1
do {
        my $output_1 = q{};
        my $output_printed_1;
        my $pipeline_success_1 = 1;
        my @tail_lines = ();
                my ($in_2, $out_2);
        my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'rpm', '-q', "--qf=%{VERSION}-%{RELEASE}.%{ARCH}\\n", '--whatprovides', 'kernel');
        close $in_2 or croak 'Close failed: $OS_ERROR';
        $output_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
        close $out_2 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_2, 0;

                my @lines = split /\n/, $output_1;
        my $num_lines = 1;
        if ($num_lines > scalar @lines) {
        $num_lines = scalar @lines;
        }
        my $start_index = scalar @lines - $num_lines;
        if ($start_index < 0) { $start_index = 0; }
        my @result = @lines[$start_index..$#lines];
        $output_1 = join "\n", @result;
        if ($output_1 ne q{} && !($output_1  =~ m{\n\z})) { $output_1 .= "\n"; }
        if ($output_1 ne q{} && !defined $output_printed_1) {
            print $output_1;
            if (!($output_1 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        }
;
    return;
}

sub get_newest_kernel {
    $NEWEST_KERNEL = q{};
    my $CURRENT_VERSION;
    my $CURRENT_ABI;
    my $CURRENT_FLAVOUR;
if ((-e '/usr/bin/dpkg')) {
        $CURRENT_VERSION = ${CURRENT_KERNEL} =~ s/-.*$//sr;
        $CURRENT_ABI = ${CURRENT_KERNEL} =~ s/^.*?-//r;
        $CURRENT_FLAVOUR = ${CURRENT_ABI} =~ s/^.*?-//r;
        $CURRENT_ABI = ${CURRENT_ABI} =~ s/-.*$//sr;
        $NEWEST_KERNEL = do {
    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', '_get_newest_kernel_debian', "$CURRENT_VERSION-$CURRENT_ABI");
    close $in_3 or croak 'Close failed: $OS_ERROR';
    my $result_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;
    $result_3
};
}
    else {
        if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $_wa0 = 'rpm';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };)) {
            $NEWEST_KERNEL = do {
    my ($in_5, $out_5);
    my $pid_5 = open3($in_5, $out_5, '>&STDERR', '_get_newest_kernel_rhel');
    close $in_5 or croak 'Close failed: $OS_ERROR';
    my $result_5 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
    close $out_5 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_5, 0;
    $result_5
};
        }
    }
;
if (("$NEWEST_KERNEL" ne q{} && $(_is_kernel_name_correct $NEWEST_KERNEL) eq "no")) {
        $NEWEST_KERNEL = q{};
    }
    say $NEWEST_KERNEL;
    return;
}
$NAME = $1;
$VERSION = $2;
$TARBALL_ROOT = $3;
$ARCH = $4;
$UPGRADE = $5;
if (("$NAME" eq q{} || "$VERSION" eq q{})) {
    say "Need NAME, and VERSION defined";
    say "ARCH is optional";
exit 1;
}
if ((-f '/etc/dkms/no-autoinstall')) {
    say "autoinstall for dkms modules has been disabled.";
exit 0;
}
if ((-r '/etc/dkms/framework.conf')) {
    $main_exit_code = system('.', '/etc/dkms/framework.conf') >> 8;
}
my $KERNELS = do {
    my $command = 'ls -v /lib/modules/ 2> /dev/null || true';
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
};
$CURRENT_KERNEL = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__rel; join(" ", @__parts) . "\n"; };
if ((-e "/var/lib/dkms/$NAME/$VERSION")) {
    say "Removing old $NAME-$VERSION DKMS files...";
    $main_exit_code = system('dkms', 'remove', '-m', $NAME, '-v', $VERSION, '--all') >> 8;
}
if ((-f "$TARBALL_ROOT/$NAME-$VERSION.dkms.tar.gz")) {
if (system('dkms', 'ldtarball', '--archive', "$TARBALL_ROOT/$NAME-$VERSION.dkms.tar.gz") >> 8) {
        say "";
        say "";
        say "Unable to load DKMS tarball $TARBALL_ROOT/$NAME-$VERSION.dkms.tar.gz.";
        say "Common causes include: ";
        say " - You must be using DKMS 2.1.0.0 or later to support binaries only";
        say "   distribution specific archives.";
        say " - Corrupt distribution specific archive";
        say "";
        say "";
exit 2;
    }
}
else {
    if ((-d "/usr/src/$NAME-$VERSION")) {
        say "Loading new $NAME-$VERSION DKMS files...";
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('dkms', 'add', '-m', $NAME, '-v', $VERSION) >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
}
$NEWEST_KERNEL = do {
    my ($in_6, $out_6);
    my $pid_6 = open3($in_6, $out_6, '>&STDERR', 'get_newest_kernel');
    close $in_6 or croak 'Close failed: $OS_ERROR';
    my $result_6 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> };
    close $out_6 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_6, 0;
    $result_6
};
if ("$autoinstall_all_kernels" eq q{}) {
if ($(_is_kernel_name_correct $CURRENT_KERNEL) eq "yes") {
if (("$NEWEST_KERNEL" ne q{} && ${CURRENT_KERNEL} ne ${NEWEST_KERNEL})) {
            $KERNELS = "$CURRENT_KERNEL $NEWEST_KERNEL";
}
        else {
            $KERNELS = $CURRENT_KERNEL;
        }
}
    else {
        say "It is likely that $CURRENT_KERNEL belongs to a chroot's host";
if (("$NEWEST_KERNEL" ne q{} && "$UPGRADE" ne q{})) {
            $KERNELS = "$NEWEST_KERNEL";
        }
    }
}
# Original bash: echo "Building for $KERNELS" | tr '\n' ',' \
do {
    my $output_7 = q{};
    my $output_printed_7;
    my $pipeline_success_7 = 1;
    $output_7 .= "Building for $KERNELS\n";
if ( !($output_7 =~ m{\n\z}) ) { $output_7 .= "\n"; }

        my $set1_8 = "\\n";
    my $set2_8 = q{,};
    my $input_8 = $output_7;
    # Expand character ranges for tr command
    my $expanded_set1_8 = $set1_8;
    my $expanded_set2_8 = $set2_8;
    # Handle a-z range in set1
    if ($expanded_set1_8 =~ /a-z/msx) {
    $expanded_set1_8 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
    }
    # Handle A-Z range in set1
    if ($expanded_set1_8 =~ /A-Z/msx) {
    $expanded_set1_8 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
    }
    # Handle [:upper:] POSIX class in set1
    if ($expanded_set1_8 =~ /\[:upper:\]/msx) {
    $expanded_set1_8 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
    }
    # Handle [:lower:] POSIX class in set1
    if ($expanded_set1_8 =~ /\[:lower:\]/msx) {
    $expanded_set1_8 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
    }
    # Handle a-z range in set2
    if ($expanded_set2_8 =~ /a-z/msx) {
    $expanded_set2_8 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
    }
    # Handle A-Z range in set2
    if ($expanded_set2_8 =~ /A-Z/msx) {
    $expanded_set2_8 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
    }
    # Handle [:upper:] POSIX class in set2
    if ($expanded_set2_8 =~ /\[:upper:\]/msx) {
    $expanded_set2_8 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
    }
    # Handle [:lower:] POSIX class in set2
    if ($expanded_set2_8 =~ /\[:lower:\]/msx) {
    $expanded_set2_8 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
    }
    my $tr_result_7_1 = q{};
    for my $char ( split //msx, $input_8 ) {
    my $pos_8 = index $expanded_set1_8, $char;
    if ( $pos_8 >= 0 && $pos_8 < length $expanded_set2_8 ) {
    $tr_result_7_1 .= substr $expanded_set2_8, $pos_8, 1;
    } else {
    $tr_result_7_1 .= $char;
    }
    }
    if (!($tr_result_7_1 =~ m{\n\z} || $tr_result_7_1 eq q{})) {
    $tr_result_7_1 .= "\n";
    }
    $output_7 = $tr_result_7_1;
    $output_7 = $tr_result_7_1;

        my @sed_lines_7 = split /\n/, $output_7;
    my @sed_result_7;
    foreach my $line (@sed_lines_7) {
    chomp $line;
    push @sed_result_7, $line;
    }
    $output_7 = join "\n", @sed_result_7;
    if ($output_7 ne q{} && !defined $output_printed_7) {
        print $output_7;
        if (!($output_7 =~ m{\n\z})) {
            print "\n";
        }
    }
    if ( !$pipeline_success_7 ) { $main_exit_code = 1; }
    exit $main_exit_code if $__set_e && $main_exit_code != 0;
    }
if ("$ARCH" ne q{}) {
if ((!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
my $_wa0 = 'lsb_release';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    }) && $(lsb_release -s -i) eq "Ubuntu")) {
if ($ARCH =~ /^amd64$/msx) {
                        $ARCH = "x86_64";
        } elsif ($ARCH =~ /^lpia$/msx or $ARCH =~ /^i.86$/msx) {
                        $ARCH = "i686";
        }
    }
    say "Building for architecture $ARCH";
    $ARCH = "-a $ARCH";
}
my $res;
for my $KERNEL ($KERNELS) {
    $dkms_status = do {
    my ($in_10, $out_10);
    my $pid_10 = open3($in_10, $out_10, '>&STDERR', 'dkms', 'status', '-m', $NAME, '-v', $VERSION, '-k', $KERNEL, $ARCH);
    close $in_10 or croak 'Close failed: $OS_ERROR';
    my $result_10 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_10> };
    close $out_10 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_10, 0;
    $result_10
};
if ((qx'echo $KERNEL | grep -c "BOOT"' > 0)) {
        say "";
        say "Module build and install for $KERNEL was skipped as ";
        say "it is a BOOT variant";
next;
    }
if ((qx'echo $dkms_status | grep -c ": built"' == 0)) {
if ((!-L /var/lib/dkms/$NAME/$VERSION/source)) {
            say "This package appears to be a binaries-only package";
            say " you will not be able to build against kernel $KERNEL";
            say " since the package source was not provided";
next;
        }
if (!(        _check_kernel_dir($KERNEL))) {
            say "Building initial module for $KERNEL";
# set +e not implemented
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
                my $tmp = do {
                $main_exit_code = system('dkms', 'build', '-m', $NAME, '-v', $VERSION, '-k', $KERNEL, $ARCH) >> 8;
                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            $res = $?;
if ("$res" =~ /^77$/msx) {
                $__set_e = 1;
                                say "Skipped.";
                next;            } elsif ("$res" =~ /^0$/msx) {
                $__set_e = 1;
                                say "Done.";
            } elsif (1) {
                if (((-f '/etc/dkms/no-autoinstall-errors') || "$RELEASE_UPGRADE_IN_PROGRESS" eq "1")) {
$__set_e = 1;
                    say "Ignored.";
next;
}
                else {

                }
            }
            $dkms_status = do {
    my ($in_11, $out_11);
    my $pid_11 = open3($in_11, $out_11, '>&STDERR', 'dkms', 'status', '-m', $NAME, '-v', $VERSION, '-k', $KERNEL, $ARCH);
    close $in_11 or croak 'Close failed: $OS_ERROR';
    my $result_11 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_11> };
    close $out_11 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_11, 0;
    $result_11
};
}
        else {
            say "Module build for kernel $KERNEL was skipped since the";
            say "kernel headers for this kernel do not seem to be installed.";
        }
    }
if (((qx'echo $dkms_status | grep -c ": built"' == 1) && (qx'echo $dkms_status | grep -c ": installed"' == 0))) {
        $main_exit_code = system('dkms', 'install', '-m', $NAME, '-v', $VERSION, '-k', $KERNEL, $ARCH) >> 8;
    }
}

exit $main_exit_code;
