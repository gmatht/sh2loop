#!/usr/bin/env perl
use strict;
use warnings;
use Time::HiRes qw(sleep);
use FindBin;

my $snapshot_script = "$FindBin::RealBin/ensure_examples_snapshot.pl";

sub snapshot_capture {
    system('perl', $snapshot_script, 'capture');
}

sub snapshot_restore {
    system('perl', $snapshot_script, 'restore');
}

my $test_cmd = './fail';

while (1) {
    my $output = '';
    chdir 'sh2perl';
    open(my $pipe, '-|', "$test_cmd 2>&1") or die "Cannot run $test_cmd: $!";
    while (my $line = <$pipe>) {
        print $line;
        $output .= $line;
    }
    close($pipe);
    my $exit_code = $? >> 8;
    chdir $FindBin::RealBin;

    if ($exit_code == 0) {
	if ($output=~/FAILED:|FAILURE/) {
		print ('BUG: Failed did not raise exit code');
	} else {
        	print "\nAll errors are fixed.\n";
	        last;
	}
    }

    print "\nInvoking opencode to fix the failure...\n";

    my @lines = split("\n", $output);
    if (@lines > 50) {
        $output = join("\n", @lines[0..24]) . "\n...\n" . join("\n", @lines[-25..-1]);
    }

    my $prompt = join("\n",
        "Fix the failure reported by fail.",
        "Use the output below as the task description and make the smallest correct code change.",
        "",
        $output,
        "",
        "After fixing the issue, stop.",
    );

    snapshot_capture();
    system('opencode', 'run', '-m', 'opencode-go/deepseek-v4-flash', '--variant', 'xhigh', $prompt);
    snapshot_restore();

    sleep 1;
}
