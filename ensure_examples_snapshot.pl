#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;

my $blessed_commit = 'd25c3e089a98880aa03cae907d63bd7260992821';
my $cmd = shift @ARGV // '';

if ($cmd eq 'capture') {
    # no-op: restore will use the blessed commit directly
    exit 0;
} elsif ($cmd eq 'restore') {
    my $dir = "$FindBin::RealBin/sh2perl";
    print "Restoring examples from blessed commit $blessed_commit...\n";
    system('git', '-C', $dir, 'checkout', $blessed_commit, '--', 'examples/');
    exit $? >> 8;
} elsif ($cmd eq 'cleanup') {
    # no-op
    exit 0;
} else {
    print "Usage: $0 {capture|restore|cleanup}\n";
    exit 1;
}
