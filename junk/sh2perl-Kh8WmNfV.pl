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

my $APP_PROFILE;
my @APP_PROFILE;
my %APP_PROFILE;

my $MAGIC_700 = 700;

$__set_e = 1;
if ("$_[0]" =~ /^configure$/msx) {
            $main_exit_code = system('adduser', "--" . "sys" . "tem", '--group', '--no-create-home', '--quiet', 'syslog') >> 8;
    if ($CHILD_ERROR != 0) {
        1;
    }
            $main_exit_code = system('adduser', 'syslog', 'adm') >> 8;
    if ($CHILD_ERROR != 0) {
        1;
    }
    chmod(oct('700'), ('/var/spool/rsyslog')) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    do {
    my ($owner, $group) = split /:/, 'syslog:adm', 2;
    my $uid = getpwnam($owner);
    my $gid = defined($group) ? getgrnam($group) : -1;
    chown $uid, $gid, ('/var/spool/rsyslog') or warn "chown failed: $OS_ERROR\n";
    $CHILD_ERROR = 0;
};
        $main_exit_code = system('chgrp', 'syslog', '/var/log') >> 8;
    chmod(oct('g+w'), ('/var/log')) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
        my $user_conf;
    my @user_conf;
    my %user_conf;
    $user_conf = '/etc/rsyslog.d/50';
        $main_exit_code = system('-d', 'efault.conf') >> 8;
        my $default_conf;
    my @default_conf;
    my %default_conf;
    $default_conf = '/usr/share/rsyslog/50';
        $main_exit_code = system('-d', 'efault.conf') >> 8;
        $main_exit_code = system('ucf', '--three-way', '--debconf-ok', $default_conf, $user_conf) >> 8;
        $main_exit_code = system('ucfr', 'rsyslog', $user_conf) >> 8;
    if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $_wa0 = "sys" . "tem" . "d-tmpfiles";
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
                $main_exit_code = system('systemd-tmpfiles', '--create', '/usr/lib/tmpfiles.d/00rsyslog.conf') >> 8;
        if ($CHILD_ERROR != 0) {
            1;
        }
    }
    if (!(    $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt-nl', "8.2110.0-2") >> 8)) {
                $main_exit_code = system('update-rc.d', '-f', 'rsyslog', 'remove') >> 8;
        if ($CHILD_ERROR != 0) {
            1;
        }
    }
    if (!(    $main_exit_code = system('dpkg', '--compare-versions', "$_[1]", 'lt-nl', "8.2210.0-3ubuntu2~") >> 8)) {
if ( -e "/etc/apparmor.d/disable/usr.sbin.rsyslogd" ) {
            if ( -d "/etc/apparmor.d/disable/usr.sbin.rsyslogd" ) {
                carp "rm: carping: ", "/etc/apparmor.d/disable/usr.sbin.rsyslogd",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "/etc/apparmor.d/disable/usr.sbin.rsyslogd" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "/etc/apparmor.d/disable/usr.sbin.rsyslogd",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
} elsif ("$_[0]" =~ /^triggered$/msx) {
            $main_exit_code = system('invoke-rc.d', 'rsyslog', 'try-restart') >> 8;
    if ($CHILD_ERROR != 0) {
        1;
    }
    exit 0;
} elsif ("$_[0]" =~ /^abort-upgrade$/msx or "$_[0]" =~ /^abort-remove$/msx or "$_[0]" =~ /^abort-deconfigure$/msx) {
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
    $APP_PROFILE = "/etc/apparmor.d/usr.sbin.rsyslogd";
if ((-f "$APP_PROFILE")) {
        my $LOCAL_APP_PROFILE;
        my @LOCAL_APP_PROFILE;
        my %LOCAL_APP_PROFILE;
        $LOCAL_APP_PROFILE = "/etc/apparmor.d/local/usr.sbin.rsyslogd";
                $main_exit_code = system('test', '-e', "$LOCAL_APP_PROFILE") >> 8;
        if ($CHILD_ERROR != 0) {
                            use File::Path qw(make_path);
                my $err;
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
if (((("$1" eq "configure" || "$1" eq "abort-upgrade") || "$1" eq "abort-deconfigure") || "$1" eq "abort-remove")) {
if ((-x "$(command -v systemd-tmpfiles)")) {
                $main_exit_code = system('systemd-tmpfiles', (defined ($ENV{DPKG_ROOT} // q{}) && ($ENV{DPKG_ROOT} // q{}) ne q{} ? ($ENV{DPKG_ROOT} // q{}) : '--root="$DPKG_ROOT"'), '--create', '00rsyslog.conf') >> 8;
        if ($CHILD_ERROR != 0) {
            1;
        }
    }
}
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/default/rsyslog', "8.1905.0-4\\~", '--', "@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/init.d/rsyslog', "8.2110.0-2\\~", '--', "@ARGV") >> 8;
if (((("$1" eq "configure" || "$1" eq "abort-upgrade") || "$1" eq "abort-deconfigure") || "$1" eq "abort-remove")) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('deb-systemd-helper', 'unmask', 'dmesg.service') >> 8;
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
if (!(    $main_exit_code = system('deb-systemd-helper', '--quiet', 'was-enabled', 'dmesg.service') >> 8)) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('deb-systemd-helper', 'enable', 'dmesg.service') >> 8;
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
            $main_exit_code = system('deb-systemd-helper', 'update-state', 'dmesg.service') >> 8;
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
        $main_exit_code = system('deb-systemd-helper', 'unmask', 'rsyslog.service') >> 8;
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
if (!(    $main_exit_code = system('deb-systemd-helper', '--quiet', 'was-enabled', 'rsyslog.service') >> 8)) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('deb-systemd-helper', 'enable', 'rsyslog.service') >> 8;
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
            $main_exit_code = system('deb-systemd-helper', 'update-state', 'rsyslog.service') >> 8;
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
if ((-d '/run/systemd/system')) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('systemctl', "--" . "sys" . "tem", 'daemon-reload') >> 8;
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
if ("$2" ne q{}) {
            my $_dh_action;
            my @_dh_action;
            my %_dh_action;
            $_dh_action = 'restart';
}
        else {
            $_dh_action = 'start';
        }
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('deb-systemd-invoke', $_dh_action, 'dmesg.service', 'rsyslog.service') >> 8;
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

exit $main_exit_code;
