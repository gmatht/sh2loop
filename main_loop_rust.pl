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

# Separate tracking for check_sh_files.pl failures
my $csf_results_file = "$project_root/check_sh_files_failing.txt";
my $csf_trusted_count_file = "$project_root/.csf_last_trusted_count";

# Stash history log — each entry: timestamp\twhat-it-tried\tregression\n
my $stash_log_file = "$project_root/.stash_history.log";

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

# Parse summary line (from ./fail)
sub parse_summary {
    my ($output) = @_;
    if ($output =~ /TESTS COMPLETED: (\d+) passed, (\d+) failed out of (\d+)/) {
        return { passed => $1 + 0, failed => $2 + 0, total => $3 + 0 };
    }
    return undef;
}

# Parse check_sh_files.pl summary line
sub parse_csf_summary {
    my ($output) = @_;
    if ($output =~ /SUMMARY:\s+(\d+)\s+tested,\s+(\d+)\s+passed,\s+(\d+)\s+failed/) {
        return { passed => $2 + 0, failed => $3 + 0, total => $1 + 0 };
    }
    return undef;
}

# Parse failed test names+reasons from check_sh_files.pl output.
# Lines like:  [N] file.sh ... FAIL (reason)
# Followed by indented detail lines.
sub parse_csf_failures {
    my ($output) = @_;
    my @failed;
    my @lines = split "\n", $output;
    for (my $i = 0; $i < @lines; $i++) {
        my $line = $lines[$i];
        # Match the FAIL line (two formats):
        #   Old: [N] file.sh ... FAIL (reason)
        #   New: [N] file.sh ... FAIL    (reason on next indented line)
        if ($line =~ /^\[\d+\]\s+(\S+)\s+\.\.\.\s+FAIL(?:\s+\(([^)]+)\))?$/) {
            my $name   = $1;
            my $reason = $2 // '';
            # Collect detail lines (indented) that follow
            my @details;
            $i++;
            while ($i < @lines && $lines[$i] =~ /^\s{7,}/) {
                my $detail = $lines[$i];
                $detail =~ s/^\s+//;
                push @details, $detail;
                $i++;
            }
            $i--;  # step back for outer loop increment
            # If no parenthesised reason on the FAIL line, use the first detail line
            if ($reason eq '' && @details) {
                $reason = $details[0];
            }
            push @failed, { name => $name, reason => $reason, details => \@details };
        }
    }
    return \@failed;
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
    my $out_file = "$project_root/sh2perl/last_test_run.log";
    # Run ./fail with a generous total timeout (30 minutes for all 169 tests)
    my ($output, $timed_out, $exit_code) = run_with_timeout(1800, "bash -c '../fail 2>&1 | tee " . $out_file . "'");
    if ($timed_out) {
        # Log partial output and return failure
        if (open my $fh, '>', $out_file) {
            print $fh $output;
            close $fh;
        }
        print STDERR "WARNING: ./fail timed out after 1200s\n";
    }
    chdir $project_root;
    return ($output, $timed_out, $exit_code);
}

sub run_with_timeout {
    my ($timeout, $cmd) = @_;
    my $pid = open(my $fh, '-|', $cmd);
    return ('', 1, -1) unless defined $pid;
    my ($output, $timed_out) = read_pipe_with_timeout($timeout, $fh, $pid);
    close $fh;
    my $exit_code = $? >> 8;
    if ($timed_out) {
        waitpid($pid, 0);
        print STDERR "run_with_timeout: command timed out after ${timeout}s, killed PID $pid\n";
    }
    return ($output, $timed_out, $exit_code);
}

sub run_check_sh_files {
    chdir $project_root;
    my $out_file = "$project_root/.check_sh_files_run.log";
    # Total timeout for the full check_sh_files.pl run (30 minutes)
    my ($output, $timed_out, $exit_code) = run_with_timeout(1800, "perl check_sh_files.pl 2>&1 | tee '$out_file'");
    if ($timed_out) {
        if (open my $fh, '>', $out_file) {
            print $fh $output;
            close $fh;
        }
        print STDERR "WARNING: check_sh_files.pl timed out after 1800s\n";
    }
    return ($output, $timed_out, $exit_code);
}

while (1) {
    my ($output, $timed_out, $test_exit) = run_tests();

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

    # Check for complete success (no Rust failures AND no check_qx.pl violations)
    if ($summary && $summary->{failed} == 0 && !$timed_out && @{$failed_tests} == 0) {
        print "\nAll ./fail tests pass! Now checking sh/ files with check_sh_files.pl...\n";
        write_results_file($results_file, []);
        if ($summary) {
            open my $tcfh, '>', $trusted_count_file or warn "Cannot write $trusted_count_file: $!";
            print $tcfh $summary->{failed}, "\n";
            close $tcfh;
        }
        system('git', '-C', "$project_root/sh2perl", 'add', '-A');
        system('git', '-C', "$project_root/sh2perl", 'commit', '-m', "All tests passing");

        # Run check_sh_files.pl
        my ($csf_output, $csf_timed, $csf_exit) = run_check_sh_files();
        my $csf_summary = parse_csf_summary($csf_output);
        my $csf_failed_tests = parse_csf_failures($csf_output);
        my $csf_old_results = read_results_file($csf_results_file);

        if ($csf_summary && $csf_summary->{failed} == 0 && @{$csf_failed_tests} == 0) {
            print "\nAll check_sh_files.pl tests also pass!\n";
            write_results_file($csf_results_file, []);
            system('git', '-C', $project_root, 'add', 'check_sh_files.pl');
            system('git', '-C', "$project_root/sh2perl", 'commit', '-m', "All tests passing (including sh/ checks)", '--allow-empty');

            # All tests pass — move to idiom-fixing mode
            print "\n" . "=" x 72 . "\n";
            print "All tests pass. Running idiom review to find IR-fixable patterns...\n";
            print "=" x 72 . "\n\n";

            chdir "$project_root/sh2perl";
            my $ir_prompt = `./next-ideom-review 2>&1`;
            my $ir_exit = $? >> 8;
            chdir $project_root;

            if ($ir_exit == 0 && $ir_prompt =~ /Review saved to/) {
                # A review was generated — extract the filename
                my ($review_file) = $ir_prompt =~ /Review saved to (.+)/;
                print "\nIdiom review generated: $review_file\n";
                print "Invoking pi to fix IR-fixable patterns...\n";

                # Read the review to build a focused prompt
                my $review_content = '';
                if (open my $rfh, '<', $review_file) {
                    local $/; $review_content = <$rfh>; close $rfh;
                }

                my $ir_fix_prompt = join("\n",
                    "The idiom review below identifies patterns in the generated Perl that",
                    "an IR-based optimizing backend could fix automatically.",
                    "",
                    "For each pattern marked 'IR-fixable: Yes', migrate the relevant",
                    "generator function in src/generator/ to emit IR nodes from src/ir.rs",
                    "instead of raw format!() strings. Then update ir_to_perl() in src/ir.rs",
                    "to produce cleaner, more idiomatic Perl from those nodes.",
                    "",
                    "The goal is to make the generated Perl look like native Perl, not a",
                    "line-by-line transliteration from bash.",
                    "",
                    "See docs/ir-design.md for the IR architecture and migration strategy.",
                    "Do NOT modify main_loop_rust.pl or next-ideom-review.",
                    "",
                    "--- Idiom review ---",
                    $review_content,
                );

                # Run pi with the IR-fix prompt
                my $pi_pid = open(my $pi_fh, '-|', 'pi', '--mode', 'json',
                    '--provider', 'opencode-go', '--model', 'deepseek-v4-flash',
                    '--thinking', 'xhigh', $ir_fix_prompt);
                if (defined $pi_pid) {
                    my $buffer = '';
                    while (<$pi_fh>) {
                        $buffer .= $_;
                        while ($buffer =~ s/^(.*)\n//) {
                            my $line = $1;
                            next if $line eq '';
                            my $event = eval { JSON::PP::decode_json($line) };
                            if ($@) { print STDERR "."; next; }
                            next unless ref $event eq 'HASH';
                            my $type = $event->{type} // '';
                            if ($type eq 'message_update') {
                                my $msg = $event->{assistantMessageEvent};
                                next unless ref $msg eq 'HASH';
                                my $dt = $msg->{delta} // '';
                                my $et = $msg->{type} // '';
                                if ($et eq 'text_delta' && length $dt) { print $dt; }
                            }
                        }
                    }
                    close $pi_fh;
                    print "\n";
                }

                # Commit the IR migration changes
                system('git', '-C', "$project_root/sh2perl", 'add', '-A');
                system('git', '-C', "$project_root/sh2perl", 'commit', '-m',
                    "IR: migrate patterns from idiom review", '--allow-empty');
            } else {
                # No more reviews available, or review generation failed
                print "No more idiom reviews available. Done.\n";
                last;
            }

            # Restore examples snapshot and re-run tests to verify IR changes
            system('perl', $snapshot_script, 'restore');
            next;
        }

        # check_sh_files has failures — enter a fix sub-loop
        print "\n" . "=" x 72, "\n";
        printf "check_sh_files.pl: %d tested, %d passed, %d failed\n",
            $csf_summary->{total}, $csf_summary->{passed}, $csf_summary->{failed};
        print "=" x 72, "\n\n";

        if ($csf_summary->{failed} > 0) {
            write_results_file($csf_results_file, $csf_failed_tests);

            # Build a concise test report for pi
            my $csf_report = '';
            for my $f (@{$csf_failed_tests}) {
                $csf_report .= "  FAIL: $f->{name} ($f->{reason})\n";
                for my $d (@{$f->{details}}) {
                    $csf_report .= "    $d\n";
                }
            }

            # Truncate the raw output for the prompt
            my $csf_short = $csf_output;
            my @csf_lines = split "\n", $csf_short;
            if (@csf_lines > 80) {
                # Keep first 20 and last 60 lines
                $csf_short = join("\n", @csf_lines[0..19]) . "\n...\n" . join("\n", @csf_lines[-60..-1]);
            }

            my $prompt = join("\n",
                "Fix the failures reported by check_sh_files.pl.",
                "The test iterates over all .sh files in the sh/ directory,",
                "converts each to Perl with sh2perl, then checks that the",
                "generated code passes check_qx.pl and Perl::Critic.",
                "",
                "Common failure types:",
                "  - sh2perl generation (parse error): sh2perl can't parse the .sh file",
                "  - check_qx: generated Perl uses qx{}/system()/open3() with shell builtins",
                "  - perlcritic: generated Perl fails Perl::Critic style checks",
                "",
                "Make the smallest correct code change, typically in the Rust source.",
                "IMPORTANT: Prefer changes at the Abstract Syntax Tree (AST) level",
                "in the Rust parser/generator.  Avoid string-level hacks on generated",
                "Perl output (e.g. replace() calls on code strings).",
                "When you encounter an existing string-level hack that is causing",
                "problems or blocking progress, refactor it into proper AST-level",
                "code instead of piling on more string patching.",
                "",
                "IMPORTANT: The IR infrastructure in src/ir.rs is being built to fix",
                "non-idiomatic output.  PRESERVE it — do not revert, remove, or comment",
                "out src/ir.rs or docs/ir-design.md.  When fixing code generation,",
                "prefer emitting IR nodes and updating ir_to_perl() over direct",
                "format!() string emission.",
                "",
                "You are in the sh2perl/ directory and the project root.",
                "Do NOT modify main_loop_rust.pl or ensure_examples_snapshot.pl.",
                "",
                "Also, for EACH distinct failure pattern among the failing .sh files,",
                "create a safe, minimal sample shell file in examples.new/ that",
                "demonstrates the problem.  This ensures the scenario is covered by",
                "the test suite going forward.",
                "  - examples.new/ is at the project root (../examples.new).",
                "  - Name the file something descriptive, e.g. 'parse-heredoc-tab.sh'.",
                "  - Keep it short — just the few lines needed to trigger the issue.",
                "  - Make it safe to run (no rm -rf, no destructive commands).",
                "  - Create examples.new/ if it doesn't exist.",
                "  - When testing each sample file, prepend 'timeout 10' so that",
                "    a stuck debashc process is killed after 10 seconds.",
                "",
                (get_stash_summaries($stash_log_file) ne '' ? ("--- Previous failed attempts (learn from these) ---", get_stash_summaries($stash_log_file), "") : ()),
                "--- Failing tests ---",
                $csf_report,
                "",
                "--- Test output (truncated) ---",
                $csf_short,
                "",
                "After fixing the issue and creating sample files, stop.",
            );

            print "\nInvoking pi to fix check_sh_files.pl failures...\n";

            chdir "$project_root/sh2perl";
            # Write prompt to a temp file to avoid E2BIG (Argument list too long).
            # The @file syntax reads the prompt from the file and interpolates it.
            my $prompt_file = '/tmp/pi_prompt.txt';
            open my $pfh, '>', $prompt_file or die "Cannot write '$prompt_file': $!";
            print $pfh $prompt;
            close $pfh;

            my $full_output = q{};
            my $pi_pid = open(my $pi_fh, '-|', 'pi', '--mode', 'json', '--provider', 'opencode-go', '--model', 'deepseek-v4-flash', '--thinking', 'xhigh', '@' . $prompt_file);
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

            chdir $project_root;

            # Re-run check_sh_files.pl to see if pi actually fixed anything
            print "\nRe-running check_sh_files.pl to verify fixes...\n";
            my ($csf_new_output, $csf_timed_out, $csf_exit_code) = run_with_timeout(1800, "perl check_sh_files.pl 2>&1 | tee '$project_root/.check_sh_files_run.log'");
            if ($csf_timed_out) {
                print STDERR "WARNING: check_sh_files.pl timed out after 1800s while verifying fixes\n";
            }
            my $csf_new_summary  = parse_csf_summary($csf_new_output);
            my $csf_new_failures = parse_csf_failures($csf_new_output);
            my $csf_old_count    = scalar @{$csf_failed_tests};
            my $csf_new_count;
            if ($csf_timed_out) {
                # Timeout — treat as same count (we don't know), don't discard fixes
                $csf_new_count = $csf_old_count;
                print STDERR "check_sh_files.pl timed out, assuming same failure count ($csf_old_count)\n";
            } else {
                $csf_new_count = $csf_new_summary ? $csf_new_summary->{failed} : scalar @{$csf_new_failures};
            }

            print "check_sh_files.pl before: $csf_old_count failed, after: $csf_new_count failed\n";

            if ($csf_new_count < $csf_old_count) {
                # pi actually fixed something — commit before returning to outer loop
                print "\nImprovement detected! Committing check_sh_files fixes...\n";
                write_results_file($csf_results_file, $csf_new_failures);
                system('git', '-C', $project_root, 'add', '-A');
                system('git', '-C', $project_root, 'commit', '-m',
                    "check_sh_files: $csf_old_count -> $csf_new_count failures");
                open my $tcfh, '>', $csf_trusted_count_file or warn "Cannot write $csf_trusted_count_file: $!";
                print $tcfh $csf_new_count, "\n";
                close $tcfh;
            } elsif ($csf_new_count > $csf_old_count) {
                # pi made things worse — discard
                print "\nWARNING: check_sh_files regressed ($csf_old_count -> $csf_new_count). Stashing...\n";
                system('git', '-C', $project_root, 'stash', 'push', '--include-untracked', '-m',
                    "auto-stash: check_sh_files $csf_old_count->$csf_new_count");
                # Log to stash history
                open my $slfh, '>>', $stash_log_file or warn "Cannot append $stash_log_file: $!";
                print $slfh scalar(localtime), "\tcheck_sh_files fix regressed ($csf_old_count->$csf_new_count)\n";
                close $slfh;
            } else {
                # Same count — keep changes (might be same failures but different tests)
                print "\nSame failure count ($csf_old_count). Committing changes anyway.\n";
                system('git', '-C', $project_root, 'add', '-A');
                system('git', '-C', $project_root, 'commit', '-m',
                    "check_sh_files: same count ($csf_old_count failures), code changes");
            }

            print "\nRestoring examples snapshot and re-running ./fail...\n";
            system('perl', $snapshot_script, 'restore');
            next;  # Go back to the top of the outer loop (re-run ./fail)
        }
    }

    # Collect summaries of recent stashes so pi can learn from past attempts
    sub get_stash_summaries {
        my $log_file = shift;
        return '' unless -e $log_file;
        open my $lfh, '<', $log_file or return '';
        my @entries = <$lfh>;
        close $lfh;
        # Keep only the last 6 entries
        @entries = @entries[-6 .. -1] if @entries > 6;
        my $out = '';
        for my $e (@entries) {
            chomp $e;
            $out .= "  $e\n";
        }
        return $out;
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

    my $stash_summaries = get_stash_summaries($stash_log_file);

    my $prompt = join("\n",
        "Fix the failures reported by './fail'.",
        "Make the smallest correct code change.",
        "IMPORTANT: Prefer changes at the Abstract Syntax Tree (AST) level",
        "in the Rust parser/generator.  Avoid string-level hacks on generated",
        "Perl output (e.g. replace() calls on code strings).",
        "When you encounter an existing string-level hack that is causing",
        "problems or blocking progress, refactor it into proper AST-level",
        "code instead of piling on more string patching.",
        "",
        "IMPORTANT: The IR infrastructure in src/ir.rs is being built to fix",
        "non-idiomatic output.  PRESERVE it — do not revert, remove, or comment",
        "out src/ir.rs or docs/ir-design.md.  When fixing code generation,",
        "prefer emitting IR nodes and updating ir_to_perl() over direct",
        "format!() string emission.",
        "",
        "You are in the sh2perl/ directory. Only modify files here.",
        "Do NOT modify files outside this directory — especially not main_loop_rust.pl or ensure_examples_snapshot.pl.",
        "",
        $test_report,
        ($stash_summaries ne '' ? ("", "--- Previous failed attempts (learn from these) ---", $stash_summaries, "") : ()),
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
    my $full_output = q{};
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
    my $before_count = scalar(@{$failed_tests}) || $new_diff->{old_count};

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
        my $decision_prompt = join("\n",
            "Failing tests went from $new_diff->{old_count} to $new_diff->{new_count}.",
            "Should these changes be kept or stashed?",
            "",
            "NOTE: The IR infrastructure in src/ir.rs and docs/ir-design.md is",
            "being built to fix non-idiomatic output.  Changes to these files",
            "should be KEPT even if they cause temporary regressions, because",
            "the IR migration is an ongoing effort that may break tests before",
            "it fixes them.  Only STASH if the changes are clearly wrong or",
            "there is a better approach.",
            "",
            "If the answer is STASH, also write a SHORT summary explaining:",
            "  - What the code was trying to achieve",
            "  - How it attempted to do it",
            "  - Why it caused regressions",
            "Use this format on the last two lines:",
            "DECISION: STASH",
            "SUMMARY: <one-line summary>",
        );
        my $oc_out = '';
        my $pid = open(my $oc, '-|', 'pi', '-p', '--provider', 'opencode-go', '--model', 'deepseek-v4-flash', '--thinking', 'high', $decision_prompt);
        if (defined $pid) {
            ($oc_out, my $timed_out2) = read_pipe_with_timeout(600, $oc, $pid);
            close $oc;
        }
        my $decision = ($oc_out =~ /STASH/i) ? 'STASH' : 'KEEP';
        # Extract the summary line if provided
        my $stash_summary = '';
        if ($oc_out =~ /^SUMMARY:\s*(.+)$/im) {
            $stash_summary = $1;
        }
        if ($decision eq 'STASH') {
            write_results_file($results_file, $failed_tests);
            if ($summary) {
                open my $tcfh, '>', $trusted_count_file or warn "Cannot write $trusted_count_file: $!";
                print $tcfh $summary->{failed}, "\n";
                close $tcfh;
            }
            system('git', '-C', "$project_root/sh2perl", 'stash', 'push', '--include-untracked', '-m', "auto-stash: tests $new_diff->{old_count}->$new_diff->{new_count}");
            log_decision('stash', $on_disk_count, $before_count, $new_diff->{new_count});
            # Log the stash summary
            if ($stash_summary ne '') {
                open my $slfh, '>>', $stash_log_file or warn "Cannot append $stash_log_file: $!";
                print $slfh scalar(localtime), "\t$stash_summary (regression: $new_diff->{old_count}->$new_diff->{new_count})\n";
                close $slfh;
            }
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
