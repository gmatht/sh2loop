#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

my $OPTION = 'FRAMEBUFFER';
my $PREREQ = "udev";

sub prereqs {
    say $PREREQ;
    return;
}
if ($arg1 =~ /^prereqs$/msx) {
        prereqs();
    exit 0;
}
$main_exit_code = system('/usr/bin/plymouth', 'quit') >> 8;
