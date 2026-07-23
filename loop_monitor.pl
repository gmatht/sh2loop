#!/usr/bin/env perl
use strict;
use warnings;

# First line: latest test summary from git log
my $summary = '(no results yet)';
my $git_dir = '/nvme/ai/sh2loop/sh2perl';
chomp(my $latest = `git -C $git_dir log --oneline -- failing_tests.txt -1 2>/dev/null`);
if ($latest) {
    chomp(my $msg = `git -C $git_dir log --format=%s -- failing_tests.txt -1 2>/dev/null`);
    $summary = $msg if $msg;
}
print "$summary\n";

# Next 20 lines: tail of loop log
my $log = '/nvme/ai/sh2loop/loop.log';
if (open my $fh, '<', $log) {
    my @lines = <$fh>;
    close $fh;
    # Only last 20 lines
    my $start = @lines > 20 ? $#lines - 19 : 0;
    print for @lines[$start .. $#lines];
} else {
    print "(no log yet)\n";
}
