#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

my $output         = q{};
our $CHILD_ERROR;

if (my $pid = fork()) {
    # Parent process continues
} elsif (defined $pid) {
    # Child process executes the background command
require Time::HiRes; Time::HiRes::sleep('0.1');
    exit(0);
} else {
    die "Cannot fork: $ERRNO\n";
}
1 while wait() > -1;
$CHILD_ERROR = $? == -1 ? 0 : $? >> 8;
say "Background done";
