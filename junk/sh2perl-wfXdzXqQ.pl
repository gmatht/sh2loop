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

my $DPKG_ROOT;
my @DPKG_ROOT;
my %DPKG_ROOT;

$__set_e = 1;
if (("$1" eq "remove" && (-x "/etc/init.d/haveged"))) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
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
if (("${DPKG_ROOT:-}" eq q{} && "$1" eq "purge")) {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('update-rc.d', 'haveged', 'remove') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
}
if (("$1" eq remove && (-d '/run/systemd/system'))) {
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
}
if ("$1" eq "purge") {
if ((-x "/usr/bin/deb-systemd-helper")) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('deb-systemd-helper', 'purge', 'haveged.service') >> 8;
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
if (("$1" eq "purge" && !(!((-e "/etc/apparmor.d/usr.sbin.haveged"))))) {
    if ( -e "/etc/apparmor.d/disable/usr.sbin.haveged" ) {
        if ( -d "/etc/apparmor.d/disable/usr.sbin.haveged" ) {
            carp "rm: carping: ", "/etc/apparmor.d/disable/usr.sbin.haveged",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/etc/apparmor.d/disable/usr.sbin.haveged" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/etc/apparmor.d/disable/usr.sbin.haveged",
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
    if ( -e "/etc/apparmor.d/force-complain/usr.sbin.haveged" ) {
        if ( -d "/etc/apparmor.d/force-complain/usr.sbin.haveged" ) {
            carp "rm: carping: ", "/etc/apparmor.d/force-complain/usr.sbin.haveged",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/etc/apparmor.d/force-complain/usr.sbin.haveged" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/etc/apparmor.d/force-complain/usr.sbin.haveged",
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
    if ( -e "/etc/apparmor.d/local/usr.sbin.haveged" ) {
        if ( -d "/etc/apparmor.d/local/usr.sbin.haveged" ) {
            carp "rm: carping: ", "/etc/apparmor.d/local/usr.sbin.haveged",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/etc/apparmor.d/local/usr.sbin.haveged" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/etc/apparmor.d/local/usr.sbin.haveged",
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
if ( -e "usr.sbin.haveged" ) {
        if ( -d "usr.sbin.haveged" ) {
            carp "rm: carping: ", "usr.sbin.haveged",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "usr.sbin.haveged" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "usr.sbin.haveged",
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
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
rmdir ('/etc/apparmor.d/disable') or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
rmdir ('/etc/apparmor.d/local') or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
rmdir ('/etc/apparmor.d') or warn "rmdir failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    };
    if ($CHILD_ERROR != 0) {
        1;
    }
}

exit $main_exit_code;
