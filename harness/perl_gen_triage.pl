#!/usr/bin/env perl
# perl_gen_triage.pl — perl-GENERATOR triage: run the same strict gate ./fail
# runs, but for one file, and dump bash-vs-perl stdout/stderr/exit plus a
# unified diff. Purpose: classify the generator's failures into root-cause
# buckets without re-reading the whole corpus by hand.
#
# Usage: perl harness/perl_gen_triage.pl <example.sh> [...]
#        (no args) => every file in the failure list handed to the worker

use strict;
use warnings;
use File::Basename qw(dirname);
use File::Temp qw(tempdir);
use Cwd qw(abs_path);

my $root = abs_path(dirname(abs_path($0)) . '/..');
my $CLI  = "$root/otranspilerl/target/debug/otranspilerl-cli";

# The failure list handed to the perl-generator worker (57 entries).
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

# Per-example shell scratch dir (pid-suffixed: no shared scratch state, so a
# killed run can never delete a sibling's files).
my $scratch = tempdir("perltri-$$-XXXXXX", TMPDIR => 1, CLEANUP => 1);

sub slurp {
    my ($p) = @_;
    open my $fh, '<', $p or return q{};
    local $/; my $c = <$fh>; close $fh;
    return defined $c ? $c : q{};
}

my (@classes, $n);
$n = 0;
for my $t (@tests) {
    my $src = "$root/sh2perl/examples/$t";
    unless (-f $src) { print "MISSING  $t\n"; next; }
    $n++;

    my $dir = "$scratch/$n";
    mkdir $dir;

    # Generate the Perl.
    my $gen = `$CLI --target pl '$src' 2>'$dir/gen.err'`;
    my $gen_rc = $? >> 8;
    my $gen_err = slurp("$dir/gen.err");
    if ($gen_rc != 0) {
        push @classes, { file => $t, class => 'GEN_FAILED',
                        detail => "otranspilerl rc=$gen_rc: " . substr($gen_err, 0, 300) };
        print "== $t  GEN_FAILED rc=$gen_rc\n";
        print "   ", join("\n   ", (split /\n/, $gen_err)[0..3]), "\n" if length $gen_err;
        next;
    }
    if ($gen =~ /system\('bash',\s*'[^']*'\)/) {
        push @classes, { file => $t, class => 'PARSER_FALLBACK', detail => 'bash wrapper' };
        print "== $t  PARSER_FALLBACK\n";
        next;
    }

    my $pl = "$dir/test.pl";
    open my $pf, '>', $pl or die $!; print $pf $gen; close $pf;

    # check_qx (same gate ./fail runs) — reject before executing.
    my $qx = `perl '$root/check_qx.pl' '$pl' 2>/dev/null`;
    if (($? >> 8) != 0) {
        my ($line) = grep { /FAIL/ } split /\n/, $qx;
        $line //= 'violation';
        push @classes, { file => $t, class => 'CHECK_QX', detail => $line };
        print "== $t  CHECK_QX  $line\n";
        next;
    }

    # Run both arms with the same argv0 the real gate uses.
    my $bash = `'$root/harness/kill-session.sh' timeout 20 bash '$src' 2>'$dir/bash.err'`;
    my $bash_rc = $? >> 8;
    my $perl = `'$root/harness/kill-session.sh' timeout 20 perl -M5.010 -e '\$0 = shift \@ARGV; my \$__f = shift \@ARGV; do \$__f' '$src' '$pl' 2>'$dir/perl.err'`;
    my $perl_rc = $? >> 8;

    my $reasons = q{};
    $reasons .= 'stdout '    if $perl ne $bash;
    $reasons .= 'exit '      if $perl_rc != $bash_rc;
    unless (length $reasons) {
        print "== $t  PASS\n";
        next;
    }

    # Classify: the cheapest signal first.
    my $class =
          $perl_rc == 124                          ? 'PERL_TIMEOUT'
        : $gen =~ /sub\s+sh2_/                    ? 'COMPILE/RUNTIME_ERR'
        : tilde_arm_missing($bash, $perl)          ? 'TILDE'
        : test_argv_mangled($src)                  ? 'TEST_ARGV'
        : array_ws_dropped($bash)                  ? 'ARRAY_WS'
        :                                           'OTHER';

    push @classes, { file => $t, class => $class,
                     detail => "bash_rc=$bash_rc perl_rc=$perl_rc; $reasons" };
    print "== $t  $class  (bash=$bash_rc perl=$perl_rc) $reasons\n";
    print "   perl stderr: ", join(' ', (split /\n/, slurp("$dir/perl.err"))[0..2]), "\n"
        if length slurp("$dir/perl.err");

    # Keep the artifacts for the ones that are NOT obviously known, so the
    # next iteration can diff them without regenerating.
    system('cp', '-a', $dir, "$scratch/keep-$n") if $class eq 'OTHER';
}

# `~` in a word position: bash expands it, so the bash arm mentions the home
# path while the perl arm does not.
sub tilde_arm_missing {
    my ($bash, $perl) = @_;
    my $h = $ENV{HOME} // q{};
    return 0 unless length $h;
    return 0 unless $bash =~ /\Q$h\E/;
    return 0 if    $perl =~ /\Q$h\E/;
    return 1;
}

# `test`/`[` whose first argument is mangled into a literal (e.g.
# `length('-n')`): `${VAR+word}` was dropped from the emitted test argv.
sub test_argv_mangled {
    my ($src) = @_;
    open my $fh, '<', $src or return 0;
    local $/; my $c = <$fh>; close $fh;
    return 0 unless $c =~ /^\s*(?:if\s+|while\s+|elif\s+)?(?:test|\[)\s/m;
    return $c =~ /\$\{[A-Za-z_][A-Za-z0-9_]*\+[^}]*\}/ ? 1 : 0;
}

# bash printed a line that is blank; perl printed nothing at all there (a
# list rendered as "" instead of "\n").
sub array_ws_dropped {
    my ($bash) = @_;
    return 0 unless $bash =~ /\n\n/;
    return 1;
}

print "\n\n===== CLASS SUMMARY =====\n";
my %by;
push @{ $by{ $_->{class} } }, $_->{file} for @classes;
for my $c (sort { $by{$b} <=> $by{$a} || $a cmp $b } keys %by) {
    printf "%3d  %-18s %s\n", scalar @{ $by{$c} }, $c, join(' ', sort @{ $by{$c} });
}
print "\ntotal examined: $n, failing: ", scalar @classes, "\n";
print "artifacts kept in: $scratch\n" if grep { $_->{class} eq 'OTHER' } @classes;
