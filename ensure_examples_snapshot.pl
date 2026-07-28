#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;

my $blessed_commit = '9c619e5c8fa113004795a60f6b5021ef2b1ce24c';
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
