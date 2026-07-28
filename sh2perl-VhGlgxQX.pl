#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

my $INITRD_SRC;
my $KERNEL_INSTALL_VERBOSE;
my $COMMAND;

my $MAGIC_5 = 5;

$__set_e = 1;
# set u not implemented
$COMMAND = "$_[0]";
my $KERNEL_VERSION = "$_[1]";
my $BOOT_DIR_ABS = "$_[2]";
$INITRD_SRC = "/boot/initrd.img-$KERNEL_VERSION";
my $INITRD_DEST = "$BOOT_DIR_ABS/initrd";
if ("$COMMAND" eq remove) {
# Builtin command 'exec' not implemented
}
if ("$COMMAND" ne add) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        say "Invalid command $COMMAND";
    };
exit 1;
}
if ((scalar(@ARGV) >= $MAGIC_5)) {
exit 0;
}
if ((-e "$INITRD_SRC")) {
    if (($KERNEL_INSTALL_VERBOSE > 0)) {
                say "Installing '$INITRD_SRC' as '$INITRD_DEST'";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
        $main_exit_code = system('install', '-m', q{0644}, '-o', 'root', '-g', 'root', "$INITRD_SRC", "$INITRD_DEST") >> 8;
    if ($CHILD_ERROR != 0) {
                    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                say "Could not copy '$INITRD_SRC' to '$INITRD_DEST'.";
            };
exit 1;
    }
;
}
else {
    say "$INITRD_SRC does not exist, not installing an initrd";
}
exit 0;
