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

my $XDG_RUNTIME_DIR;
my @XDG_RUNTIME_DIR;
my %XDG_RUNTIME_DIR;
my $net;
my @net;
my %net;
my $_DOCKERD_ROOTLESS_SELINUX;
my @_DOCKERD_ROOTLESS_SELINUX;
my %_DOCKERD_ROOTLESS_SELINUX;
my $rootlesskit;
my @rootlesskit;
my %rootlesskit;
my $mtu;
my @mtu;
my %mtu;
my $DOCKERD_ROOTLESS_ROOTLESSKIT_DISABLE_HOST_LOOPBACK;
my @DOCKERD_ROOTLESS_ROOTLESSKIT_DISABLE_HOST_LOOPBACK;
my %DOCKERD_ROOTLESS_ROOTLESSKIT_DISABLE_HOST_LOOPBACK;
my $_DOCKERD_ROOTLESS_CHILD;
my @_DOCKERD_ROOTLESS_CHILD;
my %_DOCKERD_ROOTLESS_CHILD;
my $HOME;
my @HOME;
my %HOME;

$__set_e = 1;
# set -x not implemented
if ("$_[0]" =~ /^check$/msx or "$_[0]" =~ /^install$/msx or "$_[0]" =~ /^uninstall$/msx) {
        print "Did you mean 'dockerd-rootless-setuptool.sh \@ARGV' ?\n";
    exit 1;
}
if (!(!((-w "$XDG_RUNTIME_DIR")))) {
    print "XDG_RUNTIME_DIR needs to be set and writable\n";
exit 1;
}
if (!(!((-d "$HOME")))) {
    print "HOME needs to be set and exist.\n";
exit 1;
}
$rootlesskit = "";
my $f;
for my $f ('docker-rootlesskit', 'rootlesskit') {
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('command', '-v', $f) >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
        $rootlesskit = $f;
last;
    }
}
if ("$rootlesskit" eq q{}) {
    print "rootlesskit needs to be installed\n";
exit 1;
}
$main_exit_code = system(':', (defined ($ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_STATE_DIR} // q{}) && ($ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_STATE_DIR} // q{}) ne q{} ? ($ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_STATE_DIR} // q{}) : do { $ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_STATE_DIR} = '$XDG_RUNTIME_DIR/dockerd-rootless'; ($ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_STATE_DIR} // q{}) })) >> 8;
$main_exit_code = system(':', (defined ($ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_NET} // q{}) && ($ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_NET} // q{}) ne q{} ? ($ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_NET} // q{}) : do { $ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_NET} = ''; ($ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_NET} // q{}) })) >> 8;
$main_exit_code = system(':', (defined ($ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_MTU} // q{}) && ($ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_MTU} // q{}) ne q{} ? ($ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_MTU} // q{}) : do { $ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_MTU} = ''; ($ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_MTU} // q{}) })) >> 8;
$main_exit_code = system(':', (defined ($ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_PORT_DRIVER} // q{}) && ($ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_PORT_DRIVER} // q{}) ne q{} ? ($ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_PORT_DRIVER} // q{}) : do { $ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_PORT_DRIVER} = 'builtin'; ($ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_PORT_DRIVER} // q{}) })) >> 8;
$main_exit_code = system(':', (defined ($ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_SLIRP4NETNS_SANDBOX} // q{}) && ($ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_SLIRP4NETNS_SANDBOX} // q{}) ne q{} ? ($ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_SLIRP4NETNS_SANDBOX} // q{}) : do { $ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_SLIRP4NETNS_SANDBOX} = 'auto'; ($ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_SLIRP4NETNS_SANDBOX} // q{}) })) >> 8;
$main_exit_code = system(':', (defined ($ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_SLIRP4NETNS_SECCOMP} // q{}) && ($ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_SLIRP4NETNS_SECCOMP} // q{}) ne q{} ? ($ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_SLIRP4NETNS_SECCOMP} // q{}) : do { $ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_SLIRP4NETNS_SECCOMP} = 'auto'; ($ENV{DOCKERD_ROOTLESS_ROOTLESSKIT_SLIRP4NETNS_SECCOMP} // q{}) })) >> 8;
$main_exit_code = system(':', (defined ${DOCKERD_ROOTLESS_ROOTLESSKIT_DISABLE_HOST_LOOPBACK} && ${DOCKERD_ROOTLESS_ROOTLESSKIT_DISABLE_HOST_LOOPBACK} ne q{} ? ${DOCKERD_ROOTLESS_ROOTLESSKIT_DISABLE_HOST_LOOPBACK} : do { $DOCKERD_ROOTLESS_ROOTLESSKIT_DISABLE_HOST_LOOPBACK = ''; ${DOCKERD_ROOTLESS_ROOTLESSKIT_DISABLE_HOST_LOOPBACK} })) >> 8;
$net = $DOCKERD_ROOTLESS_ROOTLESSKIT_NET;
$mtu = $DOCKERD_ROOTLESS_ROOTLESSKIT_MTU;
if ("$net" eq q{}) {
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('command', '-v', 'slirp4netns') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
if (!(        # Original bash: slirp4netns --help | grep -qw -- --netns-type;
{
            my $output_0 = q{};
            my $output_printed_0;
            my $pipeline_success_0 = 1;
                        my ($in_1, $out_1);
            my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'slirp4netns', '--help');
            close $in_1 or croak 'Close failed: $OS_ERROR';
            $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
            close $out_1 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_1, 0;

                        carp "grep: no pattern specified";
            exit 1;
            $output_0 = q{};
            if ((scalar @grep_filtered_0_1) == 0) {
                $pipeline_success_0 = 0;
            }
            if ($output_0 ne q{} && !defined $output_printed_0) {
                print $output_0;
                if (!($output_0 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
            })) {
            $net = 'slirp4netns';
if ("$mtu" eq q{}) {
                $mtu = '65520';
            }
}
        else {
            print "slirp4netns found but seems older than v0.4.0. Falling back to VPNKit.\n";
        }
    }
if ("$net" eq q{}) {
if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('command', '-v', 'vpnkit') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
            $net = 'vpnkit';
}
        else {
            print "Either slirp4netns (>= v0.4.0) or vpnkit needs to be installed\n";
exit 1;
        }
    }
}
if ("$mtu" eq q{}) {
    $mtu = '1500';
}
my $host_loopback;
my @host_loopback;
my %host_loopback;
$host_loopback = "--disable-host-loopback";
if ("$DOCKERD_ROOTLESS_ROOTLESSKIT_DISABLE_HOST_LOOPBACK" eq "false") {
    $host_loopback = "";
}
my $dockerd;
my @dockerd;
my %dockerd;
$dockerd = (defined (defined ($ENV{DOCKERD} // q{}) && ($ENV{DOCKERD} // q{}) ne q{} ? ($ENV{DOCKERD} // q{}) : 'dockerd') && (defined ($ENV{DOCKERD} // q{}) && ($ENV{DOCKERD} // q{}) ne q{} ? ($ENV{DOCKERD} // q{}) : 'dockerd') ne q{} ? (defined ($ENV{DOCKERD} // q{}) && ($ENV{DOCKERD} // q{}) ne q{} ? ($ENV{DOCKERD} // q{}) : 'dockerd') : 'dockerd');
if ("$_DOCKERD_ROOTLESS_CHILD" eq q{}) {
    $_DOCKERD_ROOTLESS_CHILD = q{1};
$ENV{_DOCKERD_ROOTLESS_CHILD} = $_DOCKERD_ROOTLESS_CHILD;
if ("$(id -u)" eq "0") {
        print "This script must be executed as a non-privileged user\n";
exit 1;
    }
if ((!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('command', '-v', 'selinuxenabled') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    }) && !(    $main_exit_code = system('bash', 'selinuxenabled') >> 8))) {
        $_DOCKERD_ROOTLESS_SELINUX = q{1};
$ENV{_DOCKERD_ROOTLESS_SELINUX} = $_DOCKERD_ROOTLESS_SELINUX;
    }
# Builtin command 'exec' not implemented
}
else {
"$_DOCKERD_ROOTLESS_CHILD" eq 1
if ( -e "/run/docker" ) {
        if ( -d "/run/docker" ) {
            carp "rm: carping: ", "/run/docker",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/run/docker" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/run/docker",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "/run/containerd" ) {
        if ( -d "/run/containerd" ) {
            carp "rm: carping: ", "/run/containerd",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/run/containerd" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/run/containerd",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "/run/xtables.lock" ) {
        if ( -d "/run/xtables.lock" ) {
            carp "rm: carping: ", "/run/xtables.lock",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/run/xtables.lock" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/run/xtables.lock",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ("$_DOCKERD_ROOTLESS_SELINUX" ne q{}) {
        $main_exit_code = system('chcon', "sys" . "tem" . "_u:object_r:iptables_var_run_t:s0", '/run') >> 8;
    }
if (("$(stat -c %T -f /etc)" eq "tmpfs" && (-l "/etc/ssl"))) {
        my $realpath_etc_ssl;
        my @realpath_etc_ssl;
        my %realpath_etc_ssl;
        $realpath_etc_ssl = do {
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'realpath', '/etc/ssl');
    close $in_2 or croak 'Close failed: $OS_ERROR';
    my $result_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    $result_2
};
if ( -e "/etc/ssl" ) {
            if ( -d "/etc/ssl" ) {
                carp "rm: carping: ", "/etc/ssl",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "/etc/ssl" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "/etc/ssl",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
        use File::Path qw(make_path);
        my $err;
        if ( mkdir '/etc/ssl' ) {
            }
        else {
            croak "mkdir: cannot create directory " . '/etc/ssl' . ": File exists\n";
        }
        $main_exit_code = system('mount', '--rbind', $realpath_etc_ssl, '/etc/ssl') >> 8;
    }
# Builtin command 'exec' not implemented
}

exit $main_exit_code;
