#!/usr/bin/env perl
use strict;
use warnings;
use Time::HiRes qw(sleep);
use FindBin;
use POSIX qw(:sys_wait_h);

$| = 1;
STDERR->autoflush(1);

my $snapshot_script = "$FindBin::RealBin/ensure_examples_snapshot.pl";

sub read_pipe_with_timeout {
    my ($timeout, $fh, $pid) = @_;
    my $output = '';
    my $start = time();
    while (1) {
        my $remaining = $timeout - (time() - $start);
        last if $remaining <= 0;
        my $rin = '';
        vec($rin, fileno($fh), 1) = 1;
        my $nfound = select($rin, undef, undef, $remaining);
        last if $nfound <= 0;
        my $buf;
        my $read = sysread($fh, $buf, 8192);
        last unless defined $read && $read > 0;
        print $buf;
        $output .= $buf;
    }
    my $timed_out = (time() - $start) >= $timeout;
    if ($timed_out && defined $pid) {
        print STDERR "WARNING: read_pipe_with_timeout timed out after ${timeout}s, killing PID $pid\n";
        kill('TERM', $pid);
        sleep(0.2);
        kill('KILL', $pid) if kill(0, $pid);
    }
    return ($output, $timed_out);
}

sub run_system_with_timeout {
    my ($timeout, @cmd) = @_;
    my $pid = fork();
    return -1 unless defined $pid;
    if ($pid == 0) {
        exec @cmd;
        exit(1);
    }
    my $deadline = time() + $timeout;
    my $got_exit = 0;
    while (1) {
        my $remaining = $deadline - time();
        last if $remaining <= 0;
        my $kid = waitpid($pid, WNOHANG);
        if ($kid == $pid) {
            $got_exit = 1;
            last;
        }
        Time::HiRes::sleep(0.1);
    }
    if ($got_exit) {
        return $? >> 8;
    }
    print STDERR "WARNING: run_system_with_timeout timed out after ${timeout}s, killing PID $pid (@cmd)\n";
    kill('TERM', $pid);
    Time::HiRes::sleep(0.2);
    kill('KILL', $pid) if kill(0, $pid);
    waitpid($pid, 0);
    return -1;
}

sub snapshot_capture {
    run_system_with_timeout(30, 'perl', $snapshot_script, 'capture');
}

sub snapshot_restore {
    run_system_with_timeout(30, 'perl', $snapshot_script, 'restore');
}

my $cached_summary_file = "$FindBin::RealBin/.cached_test_summary";

sub print_cached_summary {
    if (open my $cfh, '<', $cached_summary_file) {
        my $cached = <$cfh>;
        close $cfh;
        chomp $cached if defined $cached;
        print "cached: $cached\n" if defined $cached && $cached ne '';
    }
}

my $test_cmd = './fail';

while (1) {
    my $output = '';
    chdir 'sh2perl';
    my $pipe_pid = open(my $pipe, '-|', "$test_cmd 2>&1");
    die "Cannot run $test_cmd: $!" unless defined $pipe_pid;
    ($output, my $timed_out) = read_pipe_with_timeout(120, $pipe, $pipe_pid);
    close($pipe);

    if ($output =~ /(TESTS COMPLETED: (\d+) passed, (\d+) failed out of \d+)/) {
        my $summary_line = $1;
        my $passed_count = $2 + 0;
        my $failed_count = $3 + 0;
        if ($passed_count > 1 || $failed_count > 1) {
            open my $cfh, '>', $cached_summary_file or warn "Cannot write cached summary: $!";
            print $cfh $summary_line;
            close $cfh;
        }
    }
    
    my $exit_code = $? >> 8;
    my $has_failures = ($output =~ /FAILED:|FAILURE|ERROR|mismatch/i);

    if ($exit_code == 0 && !$timed_out && !$has_failures) {
        print "\nAll errors are fixed.\n";
        last;
    }

    print "\nInvoking opencode to fix the failure (Timed Out: $timed_out, Exit: $exit_code)...\n";
    print_cached_summary();

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
    my $rc = run_system_with_timeout(300, 'opencode', 'run', '-m', 'opencode-go/deepseek-v4-flash', '--variant', 'xhigh', $prompt);
    if ($rc == -1) {
        print STDERR "WARNING: opencode fix command timed out\n";
    }
    snapshot_restore();

    sleep 1;
}
