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

my $RELEASE_UPGRADE_IN_PROGRESS;
my @RELEASE_UPGRADE_IN_PROGRESS;
my %RELEASE_UPGRADE_IN_PROGRESS;
my $res;
my @res;
my %res;
my $prog;
my @prog;
my %prog;

if ((-f '/lib/lsb/init-functions')) {
    $main_exit_code = system('.', '/lib/lsb/init-functions') >> 8;
}
else {
    if ((-f '/etc/rc.d/init.d/functions')) {
        $main_exit_code = system('.', '/etc/rc.d/init.d/functions') >> 8;
    }
}
if ((!-f /etc/debian_version)) {
    $main_exit_code = system('alias', 'log_daemon_msg', q{=}, '/bin/echo -n') >> 8;

sub log_end_msg {
if ("$1" eq "0") {
            print " Done. \n";
}
        else {
            print " Failed. \n";
        }
        return;
}
    $main_exit_code = system('alias', 'log_action_msg', q{=}, '/bin/echo') >> 8;
}
# Builtin command 'exec' not implemented
$prog = basename(($ENV{exec} // q{}));
$main_exit_code = system('test', '-f', $exec) >> 8;
if ($CHILD_ERROR != 0) {
    exit 0;
}
if ((-e '/etc/sysconfig/$prog')) {
        $main_exit_code = system('.', '/etc/sysconfig/', $prog) >> 8;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
my $uname_s;
my @uname_s;
my %uname_s;
$uname_s = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__sys; join(" ", @__parts) . "\n"; };

sub _get_kernel_dir {
    my $KVER;
    my @KVER;
    my %KVER;
    $KVER = $1;
if ($uname_s =~ /^Linux$/msx) {
                my $DIR;
        my @DIR;
        my %DIR;
        $DIR = "/lib/modules/$KVER/build";
    } elsif ($uname_s =~ /^GNU/kFreeBSD$/msx) {
                $DIR = "/usr/src/kfreebsd-headers-$KVER/sys";
    }
    print $DIR;
if ( !( ($DIR) =~ m{\n\z}msx ) ) { print "\n"; }
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
if ("$_[0]" =~ /^start$/msx) {
    if ("$2" ne q{}) {
        my $kernel;
        my @kernel;
        my %kernel;
        $kernel = "$_[1]";
}
    else {
        $kernel = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__rel; join(" ", @__parts) . "\n"; };
    }
    if ((-f '/etc/dkms/no-autoinstall')) {
        $main_exit_code = system('log_action_msg', "$prog: autoinstall for dkms modules has been disabled") >> 8;
}
    else {
        if (!(!(_check_kernel_dir($kernel);))) {
            $main_exit_code = system('log_action_msg', "$prog: autoinstall for kernel $kernel was skipped since the kernel headers for this kernel do not seem to be installed") >> 8;
}
        else {
            $main_exit_code = system('log_action_msg', "$prog: running auto installation service for kernel $kernel") >> 8;
            $main_exit_code = system('dkms', 'autoinstall', '--kernelver', $kernel) >> 8;
            $res = $?;
if (("$res" ne "0" && !(                if (!((-f '/etc/dkms/no-autoinstall-errors'))) {
                    "$RELEASE_UPGRADE_IN_PROGRESS" eq "1"                }))) {
                $main_exit_code = system('log_action_msg', "$prog: ignore autoinstall errors for dkms modules") >> 8;
                $res = q{0};
            }
            $main_exit_code = system('log_daemon_msg', "$prog: autoinstall for kernel", "$kernel") >> 8;
            log_end_msg($res);
        }
    }
} elsif ("$_[0]" =~ /^stop$/msx or "$_[0]" =~ /^restart$/msx or "$_[0]" =~ /^force-reload$/msx or "$_[0]" =~ /^status$/msx or "$_[0]" =~ /^reload$/msx) {
} elsif (1) {
        do {
    my $__echo_line = "Usage: $PROGRAM_NAME {start}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    exit 2;
}

exit $main_exit_code;
