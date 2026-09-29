#!/usr/bin/env perl
# perl_gen_diffs.pl — dump bash-vs-perl stdout diffs for the perl-GENERATOR
# failure list into $outdir, and summarise the most common diff shapes.
# Companion to harness/perl_gen_triage.pl: the triage script CLASSIFIES, this
# one shows the actual bytes so the root cause is read, not guessed.
#
# Usage: perl harness/perl_gen_diffs.pl <outdir> [example.sh ...]

use strict;
use warnings;
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use Cwd qw(abs_path);

my $root = abs_path(dirname(abs_path($0)) . '/..');
my $CLI  = "$root/otranspilerl/target/debug/otranspilerl-cli";

my $outdir = shift @ARGV // "$root/tmp_run/perl-gen-diffs";
make_path($outdir);

my @ALL = qw(
  000__04h_complex_examples.sh 008_simple_backup.sh 045_shell_calling_perl.sh
  043_home.sh 051_primes.sh 062_09_complex_function.sh 062_hard_to_lex.sh
  058_advanced_bash_idioms.sh 063_01_deeply_nested_arithmetic.sh
  063_04_complex_parameter_expansion.sh 063_05_heredoc_with_complex_content.sh
  063_11_complex_while_loop.sh 063_09_complex_function_parameter_handling.sh
  063_12_complex_eval.sh 063_18_complex_here_string.sh
  064_01_complex_nested_subshells.sh 063_hard_to_parse.sh
  064_07_complex_array_operations.sh 064_19_complex_pattern_matching_extended_globs.sh
  064_20_nested_subshells_environment_variables.sh 064_hard_to_generate.sh
  070_cmp_basic.sh 065_yes_head_while.sh 070_gnuisms_thorough.sh
  091_while_pipe_var.sh 103_pipeline_failure_multi.sh
  arithmetic-vs-command-subshell.sh bc-native-capture.sh bench-strsubst.sh
  dot-source-lib.sh 096_head_procsub.sh dq-hashbang-multiline-assign.sh
  grep_p.sh heredoc-binary-data.sh heredoc-unclosed.sh
  parse-arithmetic-extra-paren.sh parse-at-slice-param.sh
  parse-bracket-subshell-pipe.sh parse-dollar-paren-pipe.sh
  parse-dollar-in-arithmetic.sh parse-dollar-single-quote.sh
  parse-eval-multiline.sh parse-heredoc-tab.sh
  parse-multi-command-while-condition.sh parse-param-pattern-match.sh
  parse-redirect-in-case-pattern.sh process-substitution.sh
  printf-format-and-v.sh qx-var-builtin-cd.sh realpath-cmdsub.sh
  parse-error-block-in-pipeline.sh sync-direct-call-await.sh
  sqs-overlap-multiline-awk.sh tty-cmdsub.sh typeset-cmdsub.sh
  utf8-non-utf8-content.sh variable-plus-operator.sh
);

my @tests = @ARGV ? @ARGV : @ALL;
my $scratch = tempdir("perldiff-$$-XXXXXX", TMPDIR => 1, CLEANUP => 1);

# ── Per-example output byte cap ───────────────────────────────────────────
# WHY. This script persisted FOUR copies of every example's stdout: the
# .bash capture, the .perl capture, the generated .pl, and a `diff -u` of the
# first two. parse-error-block-in-pipeline.sh mis-lowers a `while ! { :; }`
# condition, so its program never terminates: measured 2026-09-29, this
# script produced a 1.0 GB .pl and a 940 MB .diff, both full of the literal
# line "waiting". Four unbounded copies of an unbounded stream is the shape
# that fills page cache and wedges the box.
#
# `timeout 20` bounds WALL TIME and did not stop it: the file was still 1 GB
# when found, and every intermediate copy was already flushed. The bound has
# to be in BYTES.
#
# WHY cap-capture.pl AND NOT RLIMIT_FSIZE. RLIMIT_FSIZE bounds file writes,
# not pipe writes, and these captures are pipes — measured: 4 MB passed
# straight through a 512 KB `ulimit -f`. It is applied to the generated-code
# capture below via `ulimit -f` inside a subshell, where it does work, and to
# the runtime captures via the streaming cap.
#
# WHY NOT `head -c`. Truncating a pipe closes its read end early. Under this
# fleet SIGPIPE is IGNORED (systemd IgnoreSIGPIPE=yes; workers inherit it —
# SigIgn=0x1000 = bit 12), so the writer gets EPIPE instead of a signal and
# keeps looping: the 096_head_procsub.sh orphan class that filled sh2gates'
# pids.max. cap-capture.pl DRAINS to EOF, so it never manufactures an EPIPE.
my $CAP = int($ENV{SH2_CAPTURE_CAP} // (1024 * 1024));
my $CAP_BLOCKS = int($CAP / 512) || 1;   # `ulimit -f` counts 512-byte blocks
# Stream every capture through cap-capture.pl: it caps the bytes AND keeps
# the unbounded stream out of this process's memory. A `local $/` backtick
# over a runaway producer allocates the whole gigabyte in Perl before any
# limit can apply.
my $CAP_CMD = qq(perl '$root/harness/cap-capture.pl' $CAP);

sub slurp { open my $fh, '<', $_[0] or return q{}; local $/; my $c = <$fh>; close $fh; return $c // q{} }

my ($n, @bad) = (0);
for my $t (@tests) {
    my $src = "$root/sh2perl/examples/$t";
    -f $src or next;
    $n++;
    my $dir = "$scratch/$n"; mkdir $dir;
    my $gen = `ulimit -f $CAP_BLOCKS 2>/dev/null; $CLI --target pl '$src' 2>/dev/null`;
    next if ($? >> 8) != 0;
    my $pl = "$dir/test.pl";
    open my $pf, '>', $pl or die $!; print $pf $gen; close $pf;

    my $bash = `'$root/harness/kill-session.sh' timeout 20 bash '$src' 2>/dev/null | $CAP_CMD bash`;
    my $bash_rc = $? >> 8;
    my $perl = `'$root/harness/kill-session.sh' timeout 20 perl -M5.010 -e '\$0 = shift \@ARGV; my \$__f = shift \@ARGV; do \$__f' '$src' '$pl' 2>'$dir/perl.err' | $CAP_CMD perl`;
    my $perl_rc = $? >> 8;

    my $base = $t; $base =~ s/\.sh$//;
    open my $bf, '>', "$outdir/$base.bash" or die $!; print $bf $bash; close $bf;
    open my $xf, '>', "$outdir/$base.perl" or die $!; print $xf $perl; close $xf;
    system('cp', $pl, "$outdir/$base.pl");
    system('cp', $src, "$outdir/$base.src");
    system('cp', "$dir/perl.err", "$outdir/$base.err") if -s "$dir/perl.err";

    system('diff', '-u', "$outdir/$base.bash", "$outdir/$base.perl",
           map { $_ . " > $outdir/$base.diff" } ()) if 0;
    # The diff is bounded by construction (both inputs are capped above), so
    # this backtick is safe to slurp. It MUST be a real pipeline:
    # `cap-capture.pl diff -u a b` would pass those as ARGUMENTS to the cap
    # (which reads stdin and has no command to run), producing an empty diff
    # and no error — measured, that silently wrote a 0-byte .diff.
    my $d = `diff -u '$outdir/$base.bash' '$outdir/$base.perl' 2>/dev/null | $CAP_CMD diff`;
    $d = '' unless defined $d;
    open my $df, '>', "$outdir/$base.diff" or die $!; print $df $d; close $df;

    # Decide the verdict from the CAPTURED STREAMS, not from whether the diff
    # file came out non-empty. The old check was `next if $d eq '' &&
    # $bash_rc == $perl_rc`, and `open '-|', 'diff', ...` exits 0 whenever the
    # exec merely fails to produce output — so a broken diff looked like a
    # clean match. Measured 2026-09-29 on parse-error-block-in-pipeline.sh:
    # the perl side printed "waiting" until the cap and the bash side printed
    # "exit: 0", yet the report said "failing: 0 / 1" with a 0-byte .diff.
    # A triage tool that reports 0 failures for a visibly broken translation
    # is worse than one that crashes, so the streams themselves are now the
    # oracle and the diff is only ever the human-readable artifact.
    next if $d eq '' && $bash eq $perl && $bash_rc == $perl_rc;
    push @bad, $t;
    printf "%-52s bash=%-3d perl=%-3d diff=%d lines\n", $t, $bash_rc, $perl_rc,
        scalar(grep { /^[+-][^+-]/ } split /\n/, $d);
}

print "\nfailing: ", scalar @bad, " / $n\n";
print "\n=== first diff hunk line of each (the shape of the break) ===\n";
for my $t (@bad) {
    my $base = $t; $base =~ s/\.sh$//;
    my $d = slurp("$outdir/$base.diff");
    my ($first) = grep { /^[+-][^+-]/ } split /\n/, $d;
    my $e = slurp("$outdir/$base.err");
    $e = (split /\n/, $e)[0] // q{};
    printf "%-46s | %-58s | %s\n", $t, substr($first // q{}, 0, 58), substr($e, 0, 60);
}
print "\ndiffs in: $outdir\n";
