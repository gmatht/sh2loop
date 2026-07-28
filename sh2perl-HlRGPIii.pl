#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;


sub terminateTree {
    my ($file) = @_;
    my $cpid;
    for my $cpid (do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', '/usr/bin/pgrep', '-P', $_[0]);
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
}) {
        $main_exit_code = system('terminateTree', $cpid) >> 8;
    }
;
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $signal = '9';
my @pids = ($_[0]);
foreach my $pid (@pids) {
if ($pid =~ /^\\d+$/msx) {
my $result = kill $signal, $pid;
if ($result) {
print "Sent signal $signal to process $pid\n";
} else {
print {*STDERR} "kill: ($pid) - No such process\n";
}
} else {
print {*STDERR} "kill: invalid process id: $pid\n";
}
}
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}
my $pid;
for my $pid (@ARGV) {
    terminateTree($pid);
}
