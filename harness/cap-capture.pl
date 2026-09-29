#!/usr/bin/env perl
# harness/cap-capture.pl — stream stdin to stdout, capped at N bytes, with a
# deterministic truncation marker. Used to bound corpus example output.
#
# WHY THIS EXISTS. A corpus example whose translation loops forever (observed
# 2026-09-29: parse-error-block-in-pipeline.sh mis-lowers a `while ! { :; }`
# condition, so the generated program prints "waiting" without end) produced
# 1.0 GB of stdout. The gates captured it with `local $/` backticks and then
# wrote it out FOUR times (.bash, .perl, .pl, and a `diff -u` of the first
# two) — a 1 GB file plus a 940 MB diff. That unbounded byte volume is what
# fills page cache and wedges the box; io.max/memory.high treat the symptom.
#
# WHY NOT `head -c N`. Truncating a pipe with head closes the read end early.
# Under this fleet SIGPIPE is IGNORED (systemd IgnoreSIGPIPE=yes; workers
# inherit it — measured SigIgn=0x0000000000001000 = bit 12 = SIGPIPE), so a
# writer on the far side gets EPIPE instead of a signal and keeps looping —
# exactly the 096_head_procsub.sh orphan class that once filled sh2gates'
# pids.max. So this cap DRAINS the stream to EOF instead of abandoning it:
# it never closes early, never manufactures an EPIPE, and the producer is
# still bounded by the caller's `timeout` + kill-session.sh session sweep.
#
# WHY A MARKER, AND WHY IT IS SAFE FOR A VERDICT ORACLE. The gates compare
# the translation's stdout to bash's byte-for-byte. If a cap truncated only
# one side it would invent mismatches. Truncating BOTH sides at the same N
# and appending the SAME marker keeps equal outputs equal (two identical
# >N-byte streams both become prefix+marker) and leaves genuinely different
# outputs different. The 7,470-byte max legitimate corpus output measured
# 2026-09-29 sits ~140x under the default 1 MiB, so real corpus output is
# never truncated at all; the cap only engages on a runaway.
#
# Usage:  <cmd> | perl harness/cap-capture.pl <cap-bytes> [marker-label]
# Reads stdin, writes capped stdout, exits 0. The marker's presence makes
# truncation VISIBLE to any consumer that cares; for a verdict comparison it
# is simply part of the compared bytes.
use strict;
use warnings;

my $cap = shift @ARGV;
$cap = 1024 * 1024 unless defined $cap && $cap =~ /^\d+$/ && $cap > 0;
my $label = shift @ARGV // 'output';

binmode(STDIN);
binmode(STDOUT);

my ($n, $truncated, $total) = (0, 0, 0);
my $buf;
while (1) {
    my $got = read(STDIN, $buf, 262144);
    last if !$got;
    $total += $got;
    my $room = $cap - $n;
    if ($room > 0) {
        print STDOUT substr($buf, 0, $room);
        $n += $room;
        $truncated = 1 if $got > $room;
    } else {
        $truncated = 1;
    }
}
if ($truncated) {
    # A single deterministic trailer. CRITICAL: it must NOT include the total
    # stream size. An unbounded producer reads a different number of bytes on
    # every run (it is stopped by the caller's `timeout`, not by EOF), so a
    # size-bearing marker differs between two runs of the SAME output and
    # manufactures a false stdout mismatch. Only the cap and label appear here
    # — both constant. The observed total goes to STDERR, which no verdict
    # comparison reads, so the number is still available for triage.
    printf STDOUT "\n[sh2-cap: %s truncated at %d bytes]\n", $label, $cap;
    printf STDERR "sh2-cap: %s truncated at %d bytes (stream was %d)\n",
        $label, $cap, $total;
}
exit 0;
