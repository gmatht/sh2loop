#!/usr/bin/env perl
use strict;
use warnings;
use Time::HiRes qw(sleep);
use FindBin;
use POSIX qw(:sys_wait_h);
use JSON::PP;

$| = 1;
STDERR->autoflush(1);

my $snapshot_script = "$FindBin::RealBin/ensure_examples_snapshot.pl";
my $project_root = $FindBin::RealBin;
my $results_file = "$project_root/sh2perl/failing_tests.txt";
my $history_log = "$project_root/sh2perl/fix_history.log";
my $trusted_count_file = "$project_root/sh2perl/.last_trusted_count";

sub log_decision {
    my ($decision, $on_disk, $before, $after) = @_;
    $decision //= '?';
    $on_disk  //= '?';
    $before   //= '?';
    $after    //= '?';
    open my $fh, '>>', $history_log or warn "Cannot append to $history_log: $!";
    print $fh join("\t", $decision, $on_disk, $before, $after), "\n";
    close $fh;
}

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



sub print_cached_summary {
    my $file = "$project_root/.cached_test_summary";
    if (open my $cfh, '<', $file) {
        my $cached = <$cfh>;
        close $cfh;
        chomp $cached if defined $cached;
        print "cached: $cached\n" if defined $cached && $cached ne '';
    }
}

# Parse failed test names+reasons from FAILED TESTS: section
sub parse_failed_tests {
    my ($output) = @_;
    my @failed;
    while ($output =~ /^  FAIL: ([^\[\s]+(?:\.[^\s]+)?) \[perl\] — (.+)$/gm) {
        push @failed, { name => $1, reason => $2 };
    }
    return \@failed;
}

# Parse summary line
sub parse_summary {
    my ($output) = @_;
    if ($output =~ /TESTS COMPLETED: (\d+) passed, (\d+) failed out of (\d+)/) {
        return { passed => $1 + 0, failed => $2 + 0, total => $3 + 0 };
    }
    return undef;
}

# Read a results file (one failing test per line, tab-separated name and reason)
sub read_results_file {
    my $file = shift;
    return [] unless -e $file;
    open my $fh, '<', $file or return [];
    my @lines;
    while (<$fh>) {
        chomp;
        next if /^\s*$/;
        my ($name, $reason) = split(/\t/, $_, 2);
        $reason //= '';
        push @lines, { name => $name, reason => $reason };
    }
    close $fh;
    return \@lines;
}

# Write results file (one failing test per line)
sub write_results_file {
    my ($file, $failed) = @_;
    open my $fh, '>', $file or warn "Cannot write $file: $!";
    for my $f (@$failed) {
        print $fh $f->{name}, "\t", $f->{reason}, "\n";
    }
    close $fh;
}

# Build a compact diff-style summary of changes
sub diff_results {
    my ($new, $old) = @_;
    my %old_named = map { $_->{name} => 1 } @$old;
    my %new_named = map { $_->{name} => 1 } @$new;

    my @fixed   = grep { !$new_named{$_} } keys %old_named;
    my @regressed = grep { !$old_named{$_} } keys %new_named;
    my @stayed  = grep { $old_named{$_} } keys %new_named;

    my $report = '';
    if (@fixed) {
        $report .= "FIXED (${\scalar @fixed}):\n";
        $report .= "  $_\n" for @fixed;
    }
    if (@regressed) {
        $report .= "REGRESSED (${\scalar @regressed}):\n";
        $report .= "  $_\n" for @regressed;
    }
    if (@stayed) {
        $report .= "STILL FAILING (${\scalar @stayed}):\n";
        $report .= "  $_\n" for @stayed;
    }
    return {
        fixed      => \@fixed,
        regressed  => \@regressed,
        stayed     => \@stayed,
        old_count  => scalar @$old,
        new_count  => scalar @$new,
        text       => $report,
    };
}

sub run_tests {
    chdir "$project_root/sh2perl";
    my $pipe_pid = open(my $pipe, '-|', '../fail 2>&1');
    die "Cannot run ../fail: $!" unless defined $pipe_pid;
    my ($output, $timed_out) = read_pipe_with_timeout(600, $pipe, $pipe_pid);
    close($pipe);
    chdir $project_root;
    return ($output, $timed_out);
}

while (1) {
    my ($output, $timed_out) = run_tests();

    my $summary = parse_summary($output);
    my $failed_tests = parse_failed_tests($output);
    my $old_results = read_results_file($results_file);
    my $diff = diff_results($failed_tests, $old_results);

    # Print summary
    if ($summary) {
        print "\n$summary->{passed} passed, $summary->{failed} failed out of $summary->{total}\n";
    } else {
        # Test harness crashed or produced unparseable output.
        # Log the raw output and skip this iteration instead of treating it as "0 failures".
        my $crash_log = "$project_root/sh2perl/crash_output.log";
        open my $clog, '>>', $crash_log or warn "Cannot append to $crash_log: $!";
        print $clog "=== " . localtime() . " ===\n";
        print $clog $output;
        print $clog "\n=== (timed_out=$timed_out) ===\n\n";
        close $clog;
        print STDERR "\nWARNING: Test output had no summary line. Logged to $crash_log. Skipping iteration.\n";
        log_decision('crash', scalar(@{$old_results}), '?', '?');
        sleep 5;
        next;
    }
    if ($diff->{text}) {
        print $diff->{text};
    }

    # Check for complete success
    if ($summary && $summary->{failed} == 0 && !$timed_out) {
        print "\nAll tests pass!\n";
        write_results_file($results_file, []);
        if ($summary) {
            open my $tcfh, '>', $trusted_count_file or warn "Cannot write $trusted_count_file: $!";
            print $tcfh $summary->{failed}, "\n";
            close $tcfh;
        }
        system('git', '-C', "$project_root/sh2perl", 'add', '-A');
        system('git', '-C', "$project_root/sh2perl", 'commit', '-m', "All tests passing");
        last;
    }

    # Build prompt for pi
    my $test_report = '';
    if ($diff->{fixed} && @{$diff->{fixed}}) {
        $test_report .= "Since last run, these tests were FIXED:\n";
        $test_report .= "  $_\n" for @{$diff->{fixed}};
    }
    if ($diff->{regressed} && @{$diff->{regressed}}) {
        $test_report .= "Since last run, these tests REGRESSED (newly failing):\n";
        $test_report .= "  $_\n" for @{$diff->{regressed}};
    }
    if ($diff->{stayed} && @{$diff->{stayed}}) {
        $test_report .= "These tests are STILL FAILING:\n";
        $test_report .= "  $_\n" for @{$diff->{stayed}};
    }

    my @lines = split("\n", $output);
    if (@lines > 50) {
        $output = join("\n", @lines[0..24]) . "\n...\n" . join("\n", @lines[-25..-1]);
    }

    my $prompt = join("\n",
        "Fix the failures reported by './fail'.",
        "Make the smallest correct code change.",
        "You are in the sh2perl/ directory. Only modify files here.",
        "Do NOT modify files outside this directory — especially not main_loop_rust.pl or ensure_examples_snapshot.pl.",
        "",
        $test_report,
        "",
        "--- Test output (truncated) ---",
        $output,
        "",
        "After fixing the issue, stop.",
        "",
        "Also maintain failing_notes.md — for each failing test that",
        "remains after your changes, write a brief line on why it's challenging",
        "to fix (e.g. 'eval inside function definition is hard to translate').",
        "If you fixed a test, remove its entry from that file.",
    );

    print "\nInvoking pi to fix failures...\n";
    print_cached_summary();

    # Restrict pi to sh2perl/ directory so it can't modify parent files
    chdir "$project_root/sh2perl";

    # Run pi with streaming JSON output
    my $full_output = '';
    my $pi_pid = open(my $pi_fh, '-|', 'pi', '--mode', 'json', '--provider', 'opencode-go', '--model', 'deepseek-v4-flash', '--thinking', 'xhigh', $prompt);
    if (defined $pi_pid) {
        my $pi_timeout = 3600;
        my $pi_deadline = time() + $pi_timeout;
        my $last_dot = time();
        my $buffer = '';
        while (1) {
            my $remaining = $pi_deadline - time();
            last if $remaining <= 0;
            my $rin = '';
            vec($rin, fileno($pi_fh), 1) = 1;
            my $nfound = select($rin, undef, undef, 1);
            if ($nfound > 0) {
                my $buf;
                my $read = sysread($pi_fh, $buf, 8192);
                last unless defined $read && $read > 0;
                $buffer .= $buf;
                while ($buffer =~ s/^(.*)\n//) {
                    my $line = $1;
                    next if $line eq '';
                    my $event = eval { JSON::PP::decode_json($line) };
                    if ($@) { print STDERR "[JSON parse error: $@]\n"; next; }
                    next unless ref $event eq 'HASH';
                    my $type = $event->{type} // '';
                    if ($type eq 'message_update') {
                        my $msg = $event->{assistantMessageEvent};
                        next unless ref $msg eq 'HASH';
                        my $event_type = $msg->{type} // '';
                        my $delta = $msg->{delta} // '';
                        if ($event_type eq 'thinking_delta' && length $delta) {
                            print "\e[2m$delta\e[0m";
                            $full_output .= $delta;
                        } elsif ($event_type eq 'text_delta' && length $delta) {
                            print $delta;
                            $full_output .= $delta;
                        } elsif ($event_type eq 'tool_use_start') {
                            my $name = $msg->{name} // '?';
                            my $args = $msg->{arguments} // {};
                            my $arg_str = (ref $args eq 'HASH') ? join(', ', map { "$_=$args->{$_}" } keys %$args) : '';
                            print "\n\e[33m>>> tool: $name($arg_str)\e[0m\n";
                        } elsif ($event_type eq 'tool_result') {
                            print "\e[33m<<< tool result\e[0m\n";
                        }
                    }
                    $last_dot = time();
                }
            }
            if (time() - $last_dot >= 30) {
                print STDERR ".";
                $last_dot = time();
            }
        }
        close($pi_fh);
        print "\n" if $full_output ne '';
    } else {
        print STDERR "WARNING: Could not run pi: $!\n";
    }

    # Restore working directory
    chdir "$project_root";

    my $new_diff = diff_results($failed_tests, $old_results);

    # Number of failing tests stored on disk before this loop
    my $on_disk_count = scalar(@{$old_results});
    # Number of failures seen at start of loop (from test summary, or fallback to disk count)
    my $before_count = $summary ? $summary->{failed} : $new_diff->{old_count};

    # Track the last "trusted" failure count to guard against false-positive fixes
    # where pi claims "0 failures" because test output was garbled.
    my $last_trusted = $on_disk_count;
    if (open my $tcfh, '<', $trusted_count_file) {
        my $val = <$tcfh>;
        chomp $val if defined $val;
        $last_trusted = $val + 0 if defined $val && $val ne '';
        close $tcfh;
    }

    # First run — no previous results file, just create it and commit baseline
    if (! -e $results_file) {
        write_results_file($results_file, $failed_tests);
        print "\nFirst run: committing baseline results...\n";
        open my $tcfh, '>', $trusted_count_file or warn "Cannot write $trusted_count_file: $!";
        print $tcfh ($summary ? $summary->{failed} : $new_diff->{new_count}), "\n";
        close $tcfh;
        system('git', '-C', "$project_root/sh2perl", 'add', '-A');
        my $msg = "Baseline test results: $summary->{passed} passed, $summary->{failed} failed";
        system('git', '-C', "$project_root/sh2perl", 'commit', '-m', $msg);
        log_decision('first', $on_disk_count, $before_count, $new_diff->{new_count});
    } elsif ($new_diff->{new_count} < $new_diff->{old_count}) {
        # Sanity check: if failures drop suspiciously (e.g. to 0 or by >50% of last trusted),
        # and the test output actually contains failure lines, the "fix" is probably false
        # (garbled output or harness crash). Reject it and keep the last trusted count.
        if ($new_diff->{new_count} == 0 && @{$failed_tests} > 0) {
            print "\nWARNING: pi claims 0 failures but test output shows ", scalar(@{$failed_tests}), " failures. Resetting to last trusted count ($last_trusted).\n";
            write_results_file($results_file, read_results_file($trusted_count_file));
            system('git', '-C', "$project_root/sh2perl", 'add', $results_file);
            system('git', '-C', "$project_root/sh2perl", 'checkout', '--', $results_file);
            log_decision('reject', $on_disk_count, $before_count, $new_diff->{new_count});
            next;
        }
        # Update trusted count only if we have a valid test summary (not a crash).
        # Never trust 0 unless the summary explicitly reports 0 failures.
        if ($summary) {
            my $trusted_val = $summary->{failed};  # use summary count, not parsed
            open my $tcfh, '>', $trusted_count_file or warn "Cannot write $trusted_count_file: $!";
            print $tcfh $trusted_val, "\n";
            close $tcfh;
        }

        write_results_file($results_file, $failed_tests);
        print "\nTests improved ($new_diff->{old_count} -> $new_diff->{new_count} failures). Committing...\n";
        system('git', '-C', "$project_root/sh2perl", 'add', '-A');
        my $msg = "Test results: $summary->{passed} passed, $summary->{failed} failed";
        $msg .= " (fixed " . scalar(@{$new_diff->{fixed}}) . ")" if @{$new_diff->{fixed}};
        system('git', '-C', "$project_root/sh2perl", 'commit', '-m', $msg);
        log_decision('keep', $on_disk_count, $before_count, $new_diff->{new_count});
    } elsif ($new_diff->{new_count} > $new_diff->{old_count}) {
        print "\nTests regressed ($new_diff->{old_count} -> $new_diff->{new_count} failures). Asking pi whether to keep or stash...\n";
        my $decision_prompt = "Failing tests went from $new_diff->{old_count} to $new_diff->{new_count}. Should these changes be kept or stashed? Answer KEEP or STASH on the final line.";
        my $oc_out = '';
        my $pid = open(my $oc, '-|', 'pi', '-p', '--provider', 'opencode-go', '--model', 'deepseek-v4-flash', '--thinking', 'high', $decision_prompt);
        if (defined $pid) {
            ($oc_out, my $timed_out2) = read_pipe_with_timeout(600, $oc, $pid);
            close $oc;
        }
        my $decision = ($oc_out =~ /STASH/i) ? 'STASH' : 'KEEP';
        if ($decision eq 'STASH') {
            write_results_file($results_file, $failed_tests);
            if ($summary) {
                open my $tcfh, '>', $trusted_count_file or warn "Cannot write $trusted_count_file: $!";
                print $tcfh $summary->{failed}, "\n";
                close $tcfh;
            }
            system('git', '-C', "$project_root/sh2perl", 'stash', 'push', '--include-untracked', '-m', "auto-stash: tests $new_diff->{old_count}->$new_diff->{new_count}");
            log_decision('stash', $on_disk_count, $before_count, $new_diff->{new_count});
        } else {
            write_results_file($results_file, $failed_tests);
            system('git', '-C', "$project_root/sh2perl", 'add', '-A');
            system('git', '-C', "$project_root/sh2perl", 'commit', '-m', "Test results: $summary->{passed} passed, $summary->{failed} failed (kept despite regression)");
            log_decision('keep', $on_disk_count, $before_count, $new_diff->{new_count});
        }
    } else {
        write_results_file($results_file, $failed_tests);
        if (@{$new_diff->{fixed}} || @{$new_diff->{regressed}}) {
            print "\nSame failure count but tests changed. Committing...\n";
        } else {
            print "\nNo change in test results. Committing...\n";
        }
        system('git', '-C', "$project_root/sh2perl", 'add', '-A');
        my $msg = "Test results: $summary->{passed} passed, $summary->{failed} failed";
        system('git', '-C', "$project_root/sh2perl", 'commit', '-m', $msg);
        log_decision('same', $on_disk_count, $before_count, $new_diff->{new_count});
    }

    # Update trusted count on any non-stash outcome (confirms the current count is valid)
    if ($summary) {
        open my $tcfh, '>', $trusted_count_file or warn "Cannot write $trusted_count_file: $!";
        print $tcfh $summary->{failed}, "\n";
        close $tcfh;
    }

    # Restore examples to blessed commit (canonical test data)
    system('perl', $snapshot_script, 'restore');
    sleep 1;
}
