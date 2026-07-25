#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use IPC::Open3;
use File::Path qw(make_path remove_tree);
use File::Copy qw(copy move);
use POSIX qw(time);

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

$__set_e = 1;
$ENV{DEB_MAINT_PARAMS} = '';
$ENV{INITRD} = 'Yes';
if (do {
$main_exit_code = system('test', '-d', '/etc/kernel/postinst.d') >> 8;
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('run-parts', '--arg=6.1.31-sun50iw9', '--arg=/boot/vmlinuz-6.1.31-sun50iw9', '/etc/kernel/postinst.d') >> 8;
}
do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
symlink q{f}, '/boot/Image' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
};
if ($CHILD_ERROR != 0) {
        use File::Copy qw(copy);
    if ( -e '/boot/vmlinuz-6.1.31' ) {
        if ( -d '/boot/Image' ) {
            require File::Copy; File::Copy::copy('/boot/vmlinuz-6.1.31', '/boot/Image' . '/' . ('/boot/vmlinuz-6.1.31' =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy('/boot/vmlinuz-6.1.31', '/boot/Image');
        }
    } else {
        croak "cp: cannot stat '/boot/vmlinuz-6.1.31': No such file or directory\n";
    }
    if ( -e 'un50iw9' ) {
        if ( -d '/boot/Image' ) {
            require File::Copy; File::Copy::copy('un50iw9', '/boot/Image' . '/' . ('un50iw9' =~ m|([^/]+)$|)[0]);
        } else {
            require File::Copy; File::Copy::copy('un50iw9', '/boot/Image');
        }
    } else {
        croak "cp: cannot stat '/boot/vmlinuz-6.1.31': No such file or directory\n";
    }
}
if ( -e "/boot/.next" ) {
    my $current_time = time;
    utime $current_time, $current_time, "/boot/.next";
}
else {
    if ( open my $fh, '>', "/boot/.next" ) {
        close $fh or croak "Close failed: $ERRNO";
    }
    else {
        croak "touch: cannot create ", "/boot/.next",
          ": $ERRNO\n";
    }
}
exit 0;

exit $main_exit_code;
