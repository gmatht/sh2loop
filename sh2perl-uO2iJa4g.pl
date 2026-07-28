#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

$__set_e = 1;
if ("$1" eq "remove") {
    if ((-f '/etc/logrotate.d/rsyslog')) {
                my $err;
        my $force = 1;
        if ( -e '/etc/logrotate.d/rsyslog' ) {
            my $dest = '/etc/logrotate.d/rsyslog.disabled';
            if ( -e $dest && -d $dest ) {
                my $source_name = '/etc/logrotate.d/rsyslog';
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
            if ( File::Copy::move( '/etc/logrotate.d/rsyslog', $dest ) ) {
            } else {
                croak
  "mv: cannot move '/etc/logrotate.d/rsyslog' to $dest: $ERRNO\n";
            }
        } else {
            croak "mv: '/etc/logrotate.d/rsyslog': No such file or directory\n";
        }
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
}
if ("$1" eq "purge") {
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
my $_wa0 = 'ucfr';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };)) {
        $main_exit_code = system('ucfr', '--purge', 'rsyslog', '/etc/rsyslog.d/50', '-d', 'efault.conf') >> 8;
    }
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
my $_wa0 = 'ucf';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };)) {
        $main_exit_code = system('ucf', '--purge', '/etc/rsyslog.d/50', '-d', 'efault.conf') >> 8;
    }
if ((-d '/etc/rsyslog.d')) {
do { my $rm_cmd_str = 'rm -f /etc/rsyslog.d/50 -d efault.conf'; system $rm_cmd_str; };
rmdir ('/etc/rsyslog.d') or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    }
}
if (("$1" eq "purge" || "$1" eq "disappear")) {
    if ((-f '/etc/logrotate.d/rsyslog.disabled')) {
        if ( -e "/etc/logrotate.d/rsyslog.disabled" ) {
            if ( -d "/etc/logrotate.d/rsyslog.disabled" ) {
                carp "rm: carping: ", "/etc/logrotate.d/rsyslog.disabled",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "/etc/logrotate.d/rsyslog.disabled" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "/etc/logrotate.d/rsyslog.disabled",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
}
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/default/rsyslog', "8.1905.0-4\\~", '--', "\@ARGV") >> 8;
$main_exit_code = system('dpkg-maintscript-helper', 'rm_conffile', '/etc/init.d/rsyslog', "8.2110.0-2\\~", '--', "\@ARGV") >> 8;
if (("$1" eq remove && (-d '/run/systemd/system'))) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
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
;
}
if ("$1" eq "purge") {
if ((-x "/usr/bin/deb-systemd-helper")) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('deb-systemd-helper', 'purge', 'dmesg.service', 'rsyslog.service') >> 8;
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
;
    }
}
if (("$1" eq "purge" && !(!((-e "/etc/apparmor.d/usr.sbin.rsyslogd"))))) {
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
    if ($CHILD_ERROR != 0) {
        1;
    }
    if ( -e "/etc/apparmor.d/force-complain/usr.sbin.rsyslogd" ) {
        if ( -d "/etc/apparmor.d/force-complain/usr.sbin.rsyslogd" ) {
            carp "rm: carping: ", "/etc/apparmor.d/force-complain/usr.sbin.rsyslogd",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/etc/apparmor.d/force-complain/usr.sbin.rsyslogd" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/etc/apparmor.d/force-complain/usr.sbin.rsyslogd",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    if ($CHILD_ERROR != 0) {
        1;
    }
    if ( -e "/etc/apparmor.d/local/usr.sbin.rsyslogd" ) {
        if ( -d "/etc/apparmor.d/local/usr.sbin.rsyslogd" ) {
            carp "rm: carping: ", "/etc/apparmor.d/local/usr.sbin.rsyslogd",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/etc/apparmor.d/local/usr.sbin.rsyslogd" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/etc/apparmor.d/local/usr.sbin.rsyslogd",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    if ($CHILD_ERROR != 0) {
        1;
    }
    my @files_to_remove = glob("/var/cache/apparmor/*/");
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
if ( -e "usr.sbin.rsyslogd" ) {
        if ( -d "usr.sbin.rsyslogd" ) {
            carp "rm: carping: ", "usr.sbin.rsyslogd",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "usr.sbin.rsyslogd" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "usr.sbin.rsyslogd",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    if ($CHILD_ERROR != 0) {
        1;
    }
;
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
rmdir ('/etc/apparmor.d/disable') or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
;
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
rmdir ('/etc/apparmor.d/local') or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
;
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
rmdir ('/etc/apparmor.d') or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
;
}
