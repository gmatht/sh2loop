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

my $dirs;
my @dirs;
my %dirs;
my $RET;
my @RET;
my %RET;
my $APP_PROFILE;
my @APP_PROFILE;
my %APP_PROFILE;

my $MAGIC_644 = 644;

$__set_e = 1;
$main_exit_code = system('.', '/usr/share/debconf/confmodule') >> 8;
$main_exit_code = system('.', '/lib/apparmor/rc.apparmor.functions') >> 8;
if ("$_[0]" =~ /^configure$/msx or "$_[0]" =~ /^abort-remove$/msx or "$_[0]" =~ /^abort-deconfigure$/msx) {
    if (!(    $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt-nl', "2.13-7") >> 8)) {
if ( -e "/etc/apparmor.d/cache" ) {
            if ( -d "/etc/apparmor.d/cache" ) {
                my $err;
                require File::Path;
                File::Path::remove_tree("/etc/apparmor.d/cache", {error => \$err});
                if (@{$err}) {
                    carp "rm: carping: could not remove ", "/etc/apparmor.d/cache", ": $err->[0]\n";
                }
                else {
                                    }
            }
            else {
                if ( unlink "/etc/apparmor.d/cache" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "/etc/apparmor.d/cache",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
if ( -e "/etc/apparmor.d/cache.d" ) {
            if ( -d "/etc/apparmor.d/cache.d" ) {
                my $err;
                require File::Path;
                File::Path::remove_tree("/etc/apparmor.d/cache.d", {error => \$err});
                if (@{$err}) {
                    carp "rm: carping: could not remove ", "/etc/apparmor.d/cache.d", ": $err->[0]\n";
                }
                else {
                                    }
            }
            else {
                if ( unlink "/etc/apparmor.d/cache.d" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "/etc/apparmor.d/cache.d",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
    if (!(    $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt-nl', "2.13-7") >> 8)) {
        require File::Find;
        File::Find::find(sub {     next unless -f $_;     next unless $_ =~ /^CACHEDIR\.TAG$/msx;     my $depth = ($File::Find::dir =~ tr/\///) + 1; next if $depth > 1;     print "$File::Find::name\n"; }, '/var/cache/apparmor');
    }
    if (!(    $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt-nl', "2.5~pre+bzr1362-0ubuntu2") >> 8)) {
        $main_exit_code = system('db_get', 'apparmor/homedirs') >> 8;
if ("$RET" eq q{}) {
            $dirs = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $result_2 = qx{bash -c q[awk -F: "\$3 >= 1000 && \$3 < 30000 {printf \"%s\\n\", \$6}" /etc/passwd | xargs -d "\\n" -n 1 dirname | grep -v ^/home$ | sed -e "s#\\(.*\\)#\\\\1/#g" | sed -e "/ / { s#\\(.*\\)#\"\\\\1\"#g }" | sort -u | tr "\\n" ' '] };
    chomp $result_2;
    $result_2;
}; $_pipeline_result; };
if ("$dirs" ne q{}) {
                $main_exit_code = system('db_set', 'apparmor/homedirs', "$dirs") >> 8;
            }
        }
    }
        $main_exit_code = system('db_get', 'apparmor/homedirs') >> 8;
        my $tmp;
    my @tmp;
    my %tmp;
    $tmp = do {
    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'mktemp');
    close $in_3 or croak 'Close failed: $OS_ERROR';
    my $result_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;
    $result_3
};
    open my $fh_cat, '>', "\"$tmp\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "# This file is auto-generated. It is recommended you update it using:
# $ sudo dpkg-reconfigure apparmor
#
# The following is a space-separated list of where additional user home
# directories are stored, each must have a trailing '/'. Directories added
# here are appended to @{HOMEDIRS}.  See tunables/home for details.
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    if ("$RET" ne q{}) {
open my $fh_cat, '>', "\"$tmp\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "@{HOMEDIRS}+=$RET
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
}
    else {
open my $fh_cat, '>', "\"$tmp\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "#@{HOMEDIRS}+=
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
    }
            do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
        use File::Path qw(make_path);
        my $err;
        if ( !-d '/etc/apparmor.d/tunables/home.d' ) {
            make_path( '/etc/apparmor.d/tunables/home.d', { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . '/etc/apparmor.d/tunables/home.d' . ": $err->[0]\n";
            }
        }
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
    do {
    my $mv_cmd_str = 'mv -Z -f "$tmp" /etc/apparmor.d/tunables/home.d/ubuntu';
    system $mv_cmd_str;
};
    chmod(oct('644'), ('/etc/apparmor.d/tunables/home.d/ubuntu')) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    if ((!-e /etc/apparmor.d/tunables/xdg-user-dirs.d/site.local)) {
        $tmp = do {
    my ($in_8, $out_8);
    my $pid_8 = open3($in_8, $out_8, '>&STDERR', 'mktemp');
    close $in_8 or croak 'Close failed: $OS_ERROR';
    my $result_8 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_8> };
    close $out_8 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_8, 0;
    $result_8
};
open my $fh_cat, '>', "\"$tmp\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "# ------------------------------------------------------------------
#
#    Copyright (C) 2014 Canonical Ltd.
#    This program is free software; you can redistribute it and/or
#    modify it under the terms of version 2 of the GNU General Public
#    License published by the Free Software Foundation.
#
# ------------------------------------------------------------------

# The following may be used to add additional entries such as for
# translations. See tunables/xdg-user-dirs for details. Eg:
#@{XDG_MUSIC_DIR}+=\"Musique\"

#@{XDG_DESKTOP_DIR}+=\"\"
#@{XDG_DOWNLOAD_DIR}+=\"\"
#@{XDG_TEMPLATES_DIR}+=\"\"
#@{XDG_PUBLICSHARE_DIR}+=\"\"
#@{XDG_DOCUMENTS_DIR}+=\"\"
#@{XDG_MUSIC_DIR}+=\"\"
#@{XDG_PICTURES_DIR}+=\"\"
#@{XDG_VIDEOS_DIR}+=\"\"
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
            use File::Path qw(make_path);
            if ( !-d '/etc/apparmor.d/tunables/xdg-user-dirs.d' ) {
                make_path( '/etc/apparmor.d/tunables/xdg-user-dirs.d', { error => \$err } );
                if ( @{$err} ) {
                    croak "mkdir: cannot create directory " . '/etc/apparmor.d/tunables/xdg-user-dirs.d' . ": $err->[0]\n";
                }
            }
        };
        if ($CHILD_ERROR != 0) {
            1;
        }
do {
    my $mv_cmd_str = 'mv -Z -n "$tmp" /etc/apparmor.d/tunables/xdg-user-dirs.d/site.local';
    system $mv_cmd_str;
};
chmod(oct('644'), ('/etc/apparmor.d/tunables/xdg-user-dirs.d/site.local')) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    }
    if (!(    $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt-nl', "2.12-4ubuntu4") >> 8)) {
        my $i;
        for my $i ('usr.bin.media-hub-server', 'usr.bin.mediascanner-service-2.0', 'usr.lib.mediascanner-2.0.mediascanner-extractor', 'usr.bin.messaging-app', 'usr.bin.webbrowser-app') {
if ( -e "/etc/apparmor.d/$i" ) {
                if ( -d "/etc/apparmor.d/$i" ) {
                    carp "rm: carping: ", "/etc/apparmor.d/$i",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "/etc/apparmor.d/$i" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "/etc/apparmor.d/$i",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
if ( -e "/etc/apparmor.d/local/$i" ) {
                if ( -d "/etc/apparmor.d/local/$i" ) {
                    carp "rm: carping: ", "/etc/apparmor.d/local/$i",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "/etc/apparmor.d/local/$i" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "/etc/apparmor.d/local/$i",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
        }
    }
} elsif ("$_[0]" =~ /^abort-upgrade$/msx) {
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "postinst called with unknown argument \\" . chr(96) . "$_[0]'";
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
if ("$1" eq "configure") {
    $APP_PROFILE = "/etc/apparmor.d/lsb_release";
if ((-f "$APP_PROFILE")) {
        my $LOCAL_APP_PROFILE;
        my @LOCAL_APP_PROFILE;
        my %LOCAL_APP_PROFILE;
        $LOCAL_APP_PROFILE = "/etc/apparmor.d/local/lsb_release";
                $main_exit_code = system('test', '-e', "$LOCAL_APP_PROFILE") >> 8;
        if ($CHILD_ERROR != 0) {
                            use File::Path qw(make_path);
                if ( !-d do { use File::Basename qw(dirname); my $dirname_output = dirname("$LOCAL_APP_PROFILE"); $CHILD_ERROR = 0; $dirname_output; } ) {
                    make_path( do { use File::Basename qw(dirname); my $dirname_output = dirname("$LOCAL_APP_PROFILE"); $CHILD_ERROR = 0; $dirname_output; }, { error => \$err } );
                    if ( @{$err} ) {
                        croak "mkdir: cannot create directory " . do { use File::Basename qw(dirname); my $dirname_output = dirname("$LOCAL_APP_PROFILE"); $CHILD_ERROR = 0; $dirname_output; } . ": $err->[0]\n";
                    }
                }
                $main_exit_code = system('install', '--mode', '644', '/dev/null', "$LOCAL_APP_PROFILE") >> 8;
        }
if (!(        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
            $main_exit_code = system('aa-enabled', '--quiet') >> 8;
        })) {
                        $main_exit_code = system('apparmor_parser', '-r', '-T', '-W', "$APP_PROFILE") >> 8;
            if ($CHILD_ERROR != 0) {
                1;
            }
        }
    }
}
if ("$1" eq "configure") {
    $APP_PROFILE = "/etc/apparmor.d/nvidia_modprobe";
if ((-f "$APP_PROFILE")) {
        $LOCAL_APP_PROFILE = "/etc/apparmor.d/local/nvidia_modprobe";
                $main_exit_code = system('test', '-e', "$LOCAL_APP_PROFILE") >> 8;
        if ($CHILD_ERROR != 0) {
                            use File::Path qw(make_path);
                if ( !-d do { use File::Basename qw(dirname); my $dirname_output = dirname("$LOCAL_APP_PROFILE"); $CHILD_ERROR = 0; $dirname_output; } ) {
                    make_path( do { use File::Basename qw(dirname); my $dirname_output = dirname("$LOCAL_APP_PROFILE"); $CHILD_ERROR = 0; $dirname_output; }, { error => \$err } );
                    if ( @{$err} ) {
                        croak "mkdir: cannot create directory " . do { use File::Basename qw(dirname); my $dirname_output = dirname("$LOCAL_APP_PROFILE"); $CHILD_ERROR = 0; $dirname_output; } . ": $err->[0]\n";
                    }
                }
                $main_exit_code = system('install', '--mode', '644', '/dev/null', "$LOCAL_APP_PROFILE") >> 8;
        }
if (!(        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
            $main_exit_code = system('aa-enabled', '--quiet') >> 8;
        })) {
                        $main_exit_code = system('apparmor_parser', '-r', '-T', '-W', "$APP_PROFILE") >> 8;
            if ($CHILD_ERROR != 0) {
                1;
            }
        }
    }
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
if (((("$1" eq "configure" || "$1" eq "abort-upgrade") || "$1" eq "abort-deconfigure") || "$1" eq "abort-remove")) {
if ((-x "/etc/init.d/apparmor")) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('update-rc.d', 'apparmor', 'defaults') >> 8;
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
}
if (((("$1" eq "configure" || "$1" eq "abort-upgrade") || "$1" eq "abort-deconfigure") || "$1" eq "abort-remove")) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('deb-systemd-helper', 'unmask', 'apparmor.service') >> 8;
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
if (!(    $main_exit_code = system('deb-systemd-helper', '--quiet', 'was-enabled', 'apparmor.service') >> 8)) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('deb-systemd-helper', 'enable', 'apparmor.service') >> 8;
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
    else {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('deb-systemd-helper', 'update-state', 'apparmor.service') >> 8;
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
}

sub aa_log_action_start {
    do {
    my $__echo_line = @ARGV;
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

sub aa_log_action_end {
    $CHILD_ERROR = 0;
    return;
}

sub aa_log_daemon_msg {
    do {
    my $__echo_line = @ARGV;
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

sub aa_log_end_msg {
    $CHILD_ERROR = 0;
    return;
}

sub aa_log_failure_msg {
    print "Error: @ARGV\n";
    return;
}

sub aa_log_skipped_msg {
    print "Skipped: @ARGV\n";
    return;
}

sub aa_log_warning_msg {
    print "Warning: @ARGV\n";
    return;
}
if ("$_[0]" =~ /^configure$/msx) {
    if (!(    do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
        $main_exit_code = system('aa-status', '--enabled') >> 8;
    })) {
                $main_exit_code = system('parse_profiles', 'reload') >> 8;
        if ($CHILD_ERROR != 0) {
            1;
        }
    }
}
exit 0;

exit $main_exit_code;
