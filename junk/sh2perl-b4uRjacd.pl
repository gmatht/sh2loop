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

$__set_e = 1;
if ("$_[0]" =~ /^install$/msx or "$_[0]" =~ /^upgrade$/msx or "$_[0]" =~ /^abort-upgrade$/msx) {
    if (("$1" eq "upgrade" && !(    $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt-nl', "2.12-4ubuntu2") >> 8))) {
my @files_to_remove = glob("/var/lib/apparmor/profiles/.*.md5sums");
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
    }
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "preinst called with unknown argument \\" . chr(96) . "$_[0]'";
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
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/abstractions/launchpad-integration', "2.13.1-2\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor/features', "2.11.1-4\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor/subdomain.conf', "2.13.2-2\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/init/apparmor.conf', "2.11.0-11\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.share.code.bin.code', "4.0.0\\~alpha2-0ubuntu7\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.lib.multiarch.opera.opera', "4.0.0\\~alpha2-0ubuntu7\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.ch-checkns', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.ch-run', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.crun', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.flatpak', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.libexec.multiarch.bazel.linux-sandbox', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.busybox', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.buildah', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.cam', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.ipa_verify', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.lc-compliance', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.libcamerify', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.qcam', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.podman', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.lxc-attach', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.lxc-create', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.lxc-destroy', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.lxc-execute', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.lxc-stop', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.lxc-unshare', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.lxc-usernsexec', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.mmdebstrap', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.vpnns', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.lib.qt6.libexec.QtWebEngineProcess', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.lib.multiarch.qt5.libexec.QtWebEngineProcess', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', "/etc/apparmor.d/usr.lib." . "sys" . "tem" . "d." . "sys" . "tem" . "d-coredump", "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.rootlesskit', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.rpm', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.sbin.runc', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.libexec.virtiofsd', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.sbuild', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.sbuild-abort', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.sbuild-apt', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.sbuild-checkpackages', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.sbuild-clean', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.sbuild-createchroot', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.sbuild-distupgrade', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.sbuild-hold', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.sbuild-shell', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.sbuild-unhold', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.sbuild-update', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.sbuild-upgrade', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.sbin.sbuild-adduser', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.sbin.sbuild-destroychroot', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.slirp4netns', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.stress-ng', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.thunderbird', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/bin.toybox', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.trinity', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.tup', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.userbindmount', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.uwsgi-core', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/usr.bin.vdens', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/opt.google.chrome.chrome', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/opt.microsoft.msedge.msedge', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/opt.brave.com.brave.brave', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/opt.vivaldi.vivaldi-bin', "4.0.0\\~alpha4-0ubuntu1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/abstractions/transmission-common', '4.0.1really4.0.0', '-b', "eta3-0ubuntu0.1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/balena-etcher', '4.0.1really4.0.0', '-b', "eta3-0ubuntu0.1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/bwrap-userns-restrict', '4.0.1really4.0.0', '-b', "eta3-0ubuntu0.1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/foliate', '4.0.1really4.0.0', '-b', "eta3-0ubuntu0.1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/transmission', '4.0.1really4.0.0', '-b', "eta3-0ubuntu0.1\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/apparmor.d/wike', '4.0.1really4.0.0', '-b', "eta3-0ubuntu0.1\\~", '--', "@ARGV") >> 8;
if ((("$1" eq "install" && "$2" ne q{}) && (-e "/etc/init.d/apparmor"))) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
chmod(oct('+x'), ("/etc/init.d/apparmor")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
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
exit 0;

exit $main_exit_code;
