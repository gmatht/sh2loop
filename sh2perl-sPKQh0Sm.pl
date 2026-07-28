#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

my $DPKG_ROOT;

$__set_e = 1;
# set u not implemented
if ("$_[0]" =~ /^remove$/msx or "$_[0]" =~ /^upgrade$/msx or "$_[0]" =~ /^failed-upgrade$/msx or "$_[0]" =~ /^abort-install$/msx or "$_[0]" =~ /^abort-upgrade$/msx or "$_[0]" =~ /^disappear$/msx) {
} elsif ("$_[0]" =~ /^purge$/msx) {
            $main_exit_code = system('userdel', 'vnstat') >> 8;
    if ($CHILD_ERROR != 0) {
        1;
    }
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        say "postrm called with unknown argument \\" . chr(96) . "$_[0]'";
    };
    exit 1;
}
if (("$1" eq "remove" && (-x "/etc/init.d/vnstat"))) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
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
;
}
if (("${DPKG_ROOT:-}" eq q{} && "$1" eq "purge")) {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('update-rc.d', 'vnstat', 'remove') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
}
if ("$1" eq "purge") {
if ( -e "/var/lib/vnstat/" ) {
        if ( -d "/var/lib/vnstat/" ) {
            my $err;
            require File::Path;
            File::Path::remove_tree("/var/lib/vnstat/", {error => \$err});
            if (@{$err}) {
                carp "rm: carping: could not remove ", "/var/lib/vnstat/", ": $err->[0]\n";
            }
            else {
                            }
        }
        else {
            if ( unlink "/var/lib/vnstat/" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/var/lib/vnstat/",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
}
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
            $main_exit_code = system('deb-systemd-helper', 'purge', 'vnstat.service') >> 8;
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
