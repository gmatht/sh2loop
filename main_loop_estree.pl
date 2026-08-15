#!/usr/bin/env perl
# main_loop_estree.pl — autonomous repair loop for the ESTree backend.
#
# Analogous to main_loop_rust.pl (which drives the Perl backend), this loop:
#   1. runs ./fail-estree (perl + estree verdicts per corpus example)
#   2. parses the summary + .estree_failures.tsv, diffs against the baseline
#   3. if failures remain, invokes pi to fix the EMITTER (sh2perl/src) and/or
#      the REFERENCE EXECUTOR (harness/), restricted to that surface
#   4. re-runs, and keeps/commits improvements or stashes regressions
#
# Wide-character output (UTF-8) WITHOUT the use open ':std' pragma: that
# layers STDIN/STDOUT/STDERR globally and makes sysread() on '-|' child
# pipes fatal ("isn't allowed on :utf8 handles"). binmode the print handles
# only — pipes stay raw.
binmode(STDOUT, ':encoding(UTF-8)');
binmode(STDERR, ':encoding(UTF-8)');

# FIX SURFACE is conditional on the Perl worker (main_loop_rust.pl):
#   - rust loop RUNNING     : pi may touch ONLY src/estree.rs in the submodule
#     + harness/* in the workspace root (the Perl backend is owned by the
#     rust loop while it runs — keep it stable).
#   - rust loop NOT running : pi may touch ALL of sh2perl/src + harness/*
#     (the estree loop is the only worker; the emitter lives in src/shir.rs
#     since M3, so a narrow estree.rs-only scope would be ineffective). The
#     Perl-corpus regression tripwire still applies, and the widened
#     pathspec makes the auto-stash revert the culprit instead of stashing
#     estree.rs as collateral.
#
# CRITICAL DIFFERENCES from main_loop_rust.pl:
#   - NEVER `git add -A`: stage only what submodule_changed_paths() returns
#     (src/* when solo, src/estree.rs when the rust loop is live) plus the
#     harness whitelist. examples/, PLAN.md, main_loop*.pl, fail stay off
#     the fix surface either way (user WIP / scratch).
#   - NEVER runs ensure_examples_snapshot.pl restore (would clobber user WIP).
#   - The fix surface spans TWO repos: sh2perl (src) and the workspace
#     (harness/). The prompt restricts pi to exactly those paths.
#   - Regressions are AUTO-STASHED (scoped pathspec stash) instead of asking
#     pi, so a bad change can never become a blessed regression.
#
# Run it like the perl loop:
#   nohup perl main_loop_estree.pl > loop-estree.log 2>&1 &
#   ./tmux_mon --session sh2estree -- perl main_loop_estree.pl     (auto-restart)
#   sudo systemctl enable --now sh2estree                         (unit provided)
#
# Options:
#   --dry-run   one iteration: run fail-estree, build the prompt, print it,
#               and exit WITHOUT invoking pi or committing.
#   --prefix X  restrict this run's corpus to files containing X.
#   --seed      initialize trusted counts / baseline from the current
#               .estree_failures.tsv (run once after a manual fail-estree).
use strict;
use warnings;
use Time::HiRes qw(sleep);
use FindBin;
use POSIX qw(:sys_wait_h);
use JSON::PP;

$| = 1;
STDERR->autoflush(1);

my $project_root = $FindBin::RealBin;

# Worker cgroup enrollment (harness/WorkerPool.pm): this loop's whole
# process tree (pi sessions, cargo builds, gates) runs inside the
# sh2workers cgroup — pids/memory bounded so a runaway can't OOM the box.
# Best-effort: unprivileged WSL falls back to cooperative mode. The gates
# this loop runs (fail-estree) re-enroll themselves into sh2gates.
my $pool_ok = eval { require "$project_root/harness/WorkerPool.pm"; 1 };
if ($pool_ok) {
    WorkerPool::init(root => $project_root);
    WorkerPool::enter_worker_cgroup();
}
my $sh2perl      = "$project_root/sh2perl";
my $fail_estree  = "$project_root/fail-estree";
my $results_file = "$project_root/.estree_failures.tsv";    # fail-estree writes this
my $prev_file    = "$project_root/.estree_prev_failures.tsv"; # committed-state baseline
my $estree_trusted_file = "$project_root/.estree_trusted_count";
my $perl_trusted_file   = "$project_root/.estree_perl_trusted_count";
my $history_log  = "$project_root/.estree_history.log";
my $lock_file    = "$project_root/.estree_loop.lock";
# improvement-mode (M8 / PLAN.md §9) state
my $metric_file  = "$project_root/.estree_metric.tsv";       # fail-estree --metric writes (current run)
my $metric_prev  = "$project_root/.estree_metric_prev.tsv";
my $bench_file    = "$project_root/.estree_bench.tsv";   # persisted benchmark trend (js/bash per bench)  # committed-state metric baseline
my $improvement_idle_count = 0;

my $dry_run = 0;
my $prefix  = '';
my $seed    = 0;
for (my $i = 0; $i < @ARGV; $i++) {
    my $a = $ARGV[$i];
    $dry_run = 1 if $a eq '--dry-run';
    $seed    = 1 if $a eq '--seed';
    $prefix  = $ARGV[$i + 1] if $a eq '--prefix';
}

# ── lock (prevent two loops fighting over the same repos) ────────────
sub acquire_lock {
    return if $dry_run;
    if (-e $lock_file) {
        open my $lf, '<', $lock_file or return 0;
        my $pid = <$lf>; chomp $pid if defined $pid; close $lf;
        if (defined $pid && $pid ne '' && kill(0, $pid + 0)) {
            print STDERR "Another estree loop is running (PID $pid). Exiting.\n";
            exit 1;
        }
        unlink $lock_file; # stale
    }
    open my $lf, '>', $lock_file or die "write $lock_file: $!";
    print $lf $$, "\n";
    close $lf;
    return 1;
}
sub release_lock { unlink $lock_file if -e $lock_file; }

# ── history ──────────────────────────────────────────────────────────
sub log_decision {
    my ($decision, $before, $after, $extra) = @_;
    open my $fh, '>>', $history_log or warn "Cannot append $history_log: $!";
    print $fh join("\t", localtime(), $decision, $before, $after, $extra // ''), "\n";
    close $fh;
}

# ── run fail-estree ──────────────────────────────────────────────────
sub run_fail_estree {
    my $cmd = "$fail_estree --metric" . ($prefix ne '' ? " $prefix" : '');
    my $pid = open(my $fh, '-|', $cmd);
    return ('', 1, -1) unless defined $pid;
    my ($output, $timed_out) = ('', 0);
    my $deadline = time() + 1800;
    while (1) {
        my $remaining = $deadline - time();
        last if $remaining <= 0;
        my $rin = '';
        vec($rin, fileno($fh), 1) = 1;
        my $nfound = select($rin, undef, undef, 1);
        if ($nfound > 0) {
            my $buf;
            my $read = sysread($fh, $buf, 65536);
            last unless defined $read && $read > 0;
            $output .= $buf;
        }
    }
    # a hung metric child would block `close` below (Perl's close on a
    # pipe waits for the child — do_wait forever); reap the tree first
    if (time() >= $deadline) {
        print STDERR "[estree loop] fail-estree --metric exceeded 1800s — reaping\n";
        kill_tree($pid);
        $timed_out = 1;
    }
    close $fh;
    my $exit_code = $? >> 8;
    if ($timed_out) { waitpid($pid, 0); }
    return ($output, $exit_code);
}

sub parse_summary {
    my ($out) = @_;
    my $s = { estree_passed => undef, estree_failed => undef, perl_passed => undef, perl_failed => undef, total => undef };
    if ($out =~ /ESTREE:\s+(\d+) passed, (\d+) failed out of (\d+)/) {
        $s->{estree_passed} = $1; $s->{estree_failed} = $2; $s->{total} = $3;
    }
    if ($out =~ /PERL:\s+(\d+) passed, (\d+) failed out of \d+/) {
        $s->{perl_passed} = $1; $s->{perl_failed} = $2;
    }
    return $s;
}

# ── .estree_failures.tsv (all tests) → estree FAIL entries ──────────
sub read_fails {
    my ($file) = @_;
    my @fails;
    return \@fails unless -e $file;
    open my $fh, '<', $file or return \@fails;
    while (<$fh>) {
        chomp;
        next unless /\S/;   # tolerate partial/corrupt lines
        my @f = split /\t/, $_, -1;   # keep trailing empty fields (PASS entries have an empty reason)
        next unless @f >= 2;
        my ($verdict, $reason);
        if (@f >= 3 && ($f[1] eq 'FAIL' || $f[1] eq 'PASS')) {
            $verdict = $f[1]; $reason = $f[2];          # fail-estree results format
        } else {
            $verdict = 'FAIL'; $reason = $f[1];          # baseline (name\treason) format
        }
        next unless $verdict eq 'FAIL';
        push @fails, "$f[0]\t$reason";
    }
    close $fh;
    return \@fails;
}

sub write_list {
    my ($file, $list) = @_;
    open my $fh, '>', $file or warn "write $file: $!" and return;
    print $fh join("\n", @$list), "\n";
    close $fh;
}

sub diff_lists {
    my ($old, $new) = @_;
    my %old;  my %new;
    for my $e (@$old) { my ($n) = split /\t/, $e; $old{$n} = $e; }
    for my $e (@$new) { my ($n) = split /\t/, $e; $new{$n} = $e; }
    my ($fixed, $regressed, $stayed) = ([], [], []);
    for my $name (keys %old) {
        push @{$new{$name} ? $stayed : $fixed}, $name;
    }
    for my $name (keys %new) {
        push @$regressed, $name unless exists $old{$name};
    }
    return { fixed => $fixed, regressed => $regressed, stayed => $stayed, old_count => scalar(@$old), new_count => scalar(@$new) };
}

# ── tally of unsupported constructs across gate-failing files ────────
sub unsupported_tally {
    my ($fails) = @_;
    my %tally;
    my @samples;
    for my $entry (@$fails) {
        next unless $entry =~ /gate/;
        my ($file) = split /\t/, $entry;
        next unless -e "$sh2perl/examples/$file";
        my $json = `timeout 20 sh -c 'cd "$sh2perl" && ./target/debug/debashc file --estree "$sh2perl/examples/$file" 2>/dev/null'`;
        while ($json =~ /"value":"([^"]*?): not yet lowered to ESTree"/g) {
            my $v = $1;
            $v =~ s/\(.*//; # ParameterExpansion(ParameterExpansion { ... }) → ParameterExpansion
            $tally{$v}++;
        }
        push @samples, $file if @samples < 10;
    }
    my @sorted = sort { $tally{$b} <=> $tally{$a} } keys %tally;
    return (\@sorted, \%tally, \@samples);
}

# ── focus list for this iteration ────────────────────────────────────
sub focus_list {
    my ($fails, $cat) = @_;
    my @chosen;
    for my $e (@$fails) { last if @chosen >= 25; push @chosen, $e if $e =~ /$cat/; }
    return @chosen;
}

# ── build the pi prompt ──────────────────────────────────────────────
sub build_prompt {
    my ($summary, $fails, $diff, $sorted, $tally, $samples) = @_;

    my @gate  = focus_list($fails, 'gate');
    my @std   = focus_list($fails, 'stdout mismatch');
    my @rt    = focus_list($fails, 'runtime error');

    my $prompt = <<"PROMPT";
You are fixing the ESTree backend of the sh2perl transpiler (see PLAN.md §1–§2).

ARCHITECTURE
- \`debashc file --estree <file.sh>\` emits standard ESTree JSON that lowers
  shell semantics to calls into a documented \`sh2.*\` runtime namespace.
- The reference executor (harness/sh2-namespace.mjs) implements \`sh2.*\` in
  node (real child_process + fs). harness/estree-gen.mjs prints ESTree JSON to
  JS. harness/estree_gate.pl is the structural gate (callee whitelist, no
  \`sh2.unsupported\`, no *Sync).
- \`./fail-estree\` runs every example through BOTH backends and compares each
  against bash (normalized stdout). It writes .estree_failures.tsv.

CURRENT STATE
- ESTREE: $summary->{estree_passed}/$summary->{total} examples match bash
- PERL: $summary->{perl_passed}/$summary->{total} (INFORMATIONAL ONLY — 100% the perl workers' problem; ignore entirely)
- estree failures: $summary->{estree_failed} total

FAILURE CATEGORIES (current run)
- gate: failures contain \`sh2.unsupported\` (word-level lowering missing).
  Tally of unsupported constructs across gate-failing files:
PROMPT
    for my $k (@$sorted) {
        $prompt .= "    $tally->{$k}  $k\n";
    }
    $prompt .= <<"PROMPT";
  Sample gate-failing files: @$samples
- stdout mismatch (${\scalar @{$diff->{stayed}}} stayed / ${\scalar @{$diff->{regressed}}} regressed):
PROMPT
    $prompt .= join("\n", map { "    $_" } @std) . "\n" if @std;
    $prompt .= "- runtime error:\n" . join("\n", map { "    $_" } @rt) . "\n" if @rt;

    $prompt .= fix_surface_text();

    $prompt .= <<"PROMPT";
VERIFY
- Rust changes: cd sh2perl && cargo build --bin debashc && cargo test --lib
  (the estree unit tests assert no sh2.unsupported leaks and determinism)
- Subset: ./fail-estree <prefix>   (e.g. ./fail-estree 010_pattern)
- Full:  ./fail-estree
- Keep the structural gate green and the emitted JSON deterministic.

STRATEGY
- Prefer the smallest fix that moves the most examples. Word-level lowering
  (parameter expansion, arithmetic, brace expansion, arrays) clears the gate
  bucket (~${\scalar @$sorted} distinct constructs).
- If a fix belongs in the runtime instead of the emitter, fix the runtime.
- The PERL backend is 100% the perl workers' problem (rust loop / backends/perl). IGNORE perl verdicts entirely: never touch perl code, never act on perl failures. Your scope: the ESTree backend + the shared core's estree-facing parts + pending core-requests.
- If you cannot fix something, move on — do not regress what works.
- When REPRODUCING any failing test or RUNNING the transpiled output,
  ALWAYS wrap the command in 'timeout 15' (e.g.
  'timeout 15 node harness/estree-runner.mjs <estree.json> --source <f>').
  Some transpiled programs (double-paren-subshell.sh) never terminate —
  the harness's 20s timeout protects the corpus, but a direct pi
  reproduction bypasses it and wedges this loop on the unclosed pipe.
PROMPT
    return $prompt;
}

# ── fix surface text (shared by fix + improvement prompts) ──────────
sub fix_surface_text {
    my $t = "\nFIX SURFACE — modify ONLY these files:\n";
    if (fix_surface_wide()) {
        $t .= <<'WIDE';
- sh2perl/src/**  (ALL Rust sources — the estree loop is the only worker
  right now: the emitter is src/shir.rs (ast_to_ir/shir_to_estree), the
  node model + sh2.* helpers are src/estree.rs, and the shared IR + Perl
  generator also live under src/. Modify as needed, but NEVER reduce the
  PERL pass count.)
WIDE
    } else {
        $t .= <<'NARROW';
- sh2perl/src/estree.rs  (the Rust emitter; word-level lowering is the big
  bucket: parameter expansion, arithmetic words, brace expansion, arrays)
NARROW
    }
    $t .= <<"PROMPT";
- harness/sh2-namespace.mjs  (the sh2.* runtime / builtins / test parser)
- harness/estree-gen.mjs     (ESTree→JS printer)
- harness/estree_gate.pl     (structural gate — if you add sh2.* functions,
  add them to the whitelist here)

NEVER touch: examples/ (user WIP), PLAN.md, main_loop*.pl, fail,
no failing-test allowlist exists (it was removed — a failing test is a bug). If
main_loop_rust.pl (the Perl worker) starts running, the src surface
narrows to src/estree.rs only — the FIX SURFACE above reflects the
current mode.
PROMPT
    return $t;
}

# ── the durable plan backlog (.estree_plans.md) ──────────────────────
# The improvement loop executes the FIRST entry with "Status: planned":
# the entry's precise steps go into the pi prompt, and the pi updates the
# entry (status / benchmark results / issues) after verification. This
# stops every pi session from re-deriving the whole analysis.
sub build_plan_prompt {
    my $plans = "$project_root/.estree_plans.md";
    return '' unless -e $plans;
    open my $fh, '<', $plans or return '';
    local $/; my $content = <$fh>; close $fh;
    my ($entry) = $content =~ /(## .*?)(?=\n## |\z)/s;
    return '' unless defined $entry && $entry =~ /Status: planned/;
    return "CURRENT PLAN — implement THIS entry exactly (its steps, files, and\nbenchmark expectations):\n$entry\n";
}

# ── benchmark fruit (JS vs bash ops/sec) for the improvement prompt ──
# Runs bench.sh on a fast subset and returns the rows sorted by worst
# js:bash ratio — the per-iteration overhead and spawns that remain.
# Persist a benchmark run to .estree_bench.tsv (appending a timestamped
# block per run, so the trend accumulates: js/bash ratios improving =
# the sh2.* sync/async removal paying off). Also logs a bench decision.
sub write_bench_file {
    my ($rows) = @_;
    return unless @$rows;
    open my $fh, '>>', $bench_file or return;
    my $ts = localtime();
    print $fh "# run $ts\n";
    for my $r (@$rows) {
        print $fh join("\t", $r->[0], $r->[1], ($r->[2] =~ /^\d+$/ ? $r->[2] : 'ERR'), $r->[3], $r->[4]), "\n";
    }
    close $fh;
    # log the trend signal: rows[0] = worst ratio (sorted ascending),
    # rows[-1] = best. Improving worst = sync-removal progress.
    log_decision('bench', scalar(@$rows), $rows->[0][4] // '?', $rows->[-1][4] // '?');
}

sub build_bench_prompt {
    my $sb = $ENV{SHELLBENCH_DIR} // '/tmp/shellbench';
    my @samples = map { "$sb/sample/$_" }
        qw(count.sh func.sh eval.sh output.sh stringop1.sh stringop2.sh);
    my $out = `CAL_MS=100 timeout 300 bash "$project_root/bench.sh" @samples 2>/dev/null`;
    my @rows;
    for my $line (split /\n/, $out) {
        # "sample:name    bash/s    dash/s    js/s"
        my ($name, $b, $d, $j) = split /\s+/, $line;
        next unless defined $j && $j =~ /^\d+$/ && defined $b && $b =~ /^\d+$/ && $b > 0;
        push @rows, [ $name, $b, $d, $j, sprintf('%.2f', $j / $b) ];
    }
    @rows = sort { $a->[4] <=> $b->[4] } @rows;
    return '' unless @rows;
    # PERSIST the benchmark trend (the user asked the worker to keep +
    # log bench results): append a timestamped block to .estree_bench.tsv
    # and log a bench decision so the sync-removal progress (js/bash
    # ratios improving over time) is visible, not just in the pi prompt.
    write_bench_file(\@rows);
    my $t = "BENCHMARK FRUIT (JS vs bash, ops/sec — LOW ratio = per-iteration overhead / spawns left):\n";
    $t .= sprintf("  %-30s %8s %8s %8s %6s\n", "bench", "bash", "dash", "js", "js/bash");
    for my $r (@rows) {
        $t .= sprintf("  %-30s %8d %8s %8d %6s\n", $r->[0], $r->[1],
            ($r->[2] =~ /^\d+$/ ? $r->[2] : 'ERR'), $r->[3], $r->[4]);
    }
    $t .= "TARGET the worst ratios FIRST (low-hanging fruit): a native cut/sed/expr\n";
    $t .= "builtin flips the spawn-parity echo|cut benches (~100x); ((i++)) arith, the\n";
    $t .= "function-call dispatch, and eval/assign are per-iteration runtime paths.\n";
    $t .= "After a lowering, re-run:  CAL_MS=100 bash $project_root/bench.sh <sample>\n";
    return $t;
}

# ── improvement-mode prompt (M8 / PLAN.md §9) ───────────────────────
sub build_improvement_prompt {
    my ($metric, $summary, $fails) = @_;
    my $total = (defined $metric ? ($metric->{total} // 0) : 0);
    my $in_loop_total = (defined $metric ? ($metric->{in_loop_total} // 0) : 0);
    my $table = defined $metric ? ($metric->{table} // {}) : {};
    my $in_loop = defined $metric ? ($metric->{in_loop} // {}) : {};
    my $prompt = <<"PROMPT";
The ESTree backend passes the FULL corpus ($summary->{estree_passed}/$summary->{total}) —
no bugs to fix. Your job now: make the generated JS FASTER and more NATIVE by
finding the CHEAPEST CORRECT LOWERING for everything that still goes through the
sh2.* runtime or spawns a subprocess.

LOWERING LADDER (cheapest wins; the corpus is the correctness oracle):
  native JS expression          <  sync sh2.* runtime call   <  async sh2.* call   <  subprocess spawn
  String(x).includes(p)            sh2.test                     sh2.exec              echo | grep
  i < 100000, i = i + 1            (fallback)                   sh2.pipeline          ...
  String.slice/replace/...

Think in PATTERN FAMILIES, not instances: \`grep 1337\` is a substring test
(String(x).includes("1337")) — NEVER a regex, NEVER a generic grep translation.
Generalize the same way: grep -q P file -> read + includes; case \$x in *P*) ->
includes; seq 1 N -> native range; [ \"\$x\" = *P* ] -> native glob-to-includes;
\${x//p/r} -> replaceAll; head/tail/wc on a known producer -> native counts;
for/cstyle-for loops with no awaits -> sync runtime loops (forLoopSync /
cstyleForSync, mirroring whileLoopSync); remaining async while loops -> sync.

EXEMPLARS ALREADY LANDED (the bar to match or beat):
  - numeric lift:  [ \$i -lt 100000 ] -> i < 100000 ;  i=\$((i+1)) -> i = i + 1
  - whileLoopSync: sync runtime loop, no per-iteration promises
    (10M-iter arithmetic loop: 2.64s -> 0.23s loop-only)
  - echo X | grep P >/dev/null 2>/dev/null (test position) -> String(X).includes(P)
    via the ShIR grep-test lift (~180x on a 10k-iter loop)

AGGRESSIVENESS — 'provable' can be broadened with DOCUMENTED, OPTION-GATED
ASSUMPTIONS about the execution environment the corpus cannot observe. For
each assumption: implement the aggressive lowering it unlocks, run the FULL
suite, and if it stays 100% KEEP it — behind an option that DEFAULTS ON
(mirror SH2_BC_NATIVE=1 but inverted: ON by default; an env flag like
SH2_ASSUME_X=0 turns it off for maximal fidelity). Document the assumption
next to its option. The metric has been FLAT — the conservative reads are
stalling progress; the keep/stash loop is the safety net, so TRY and let the
suite judge.

Candidate assumptions (state which you use, or find better ones):
- SELF_CONTAINED: no code outside this script reads its variables or calls
  its functions (no parent-shell/source/`declare -p` observation) -> the
  variable store and function map only need to serve the script itself;
  drop store syncs / dispatch where the script provably cannot observe it.
- NO_RUNTIME_REFLECTION: no `declare -p`, `\${!x}`, `set` dumps, or `eval`
  that reads variables -> the store need not be queryable.
- NO_OVERFLOW / C_LOCALE: arithmetic uses JS machine numbers; sort/glob
  ordering assumes the C locale -> native comparison/ordering everywhere.
- POSITIONAL_LOCAL: \$1..\$N / \$@ are only consumed inside the script
  (no caller fetches them mid-run) -> positionals need no live backing.

CURRENT METRIC — remaining sh2.* call sites across the corpus (fail-estree --metric):
PROMPT
    $prompt .= "  total: $total call sites  (in-loop: $in_loop_total — per-iteration cost)\n";
    for my $k (sort { ($table->{$b} // 0) <=> ($table->{$a} // 0) } keys %$table) {
        my $il = $in_loop->{$k} // 0;
        my $mark = ($il > 0) ? "  [in-loop $il]" : "";
        $prompt .= sprintf("  %-16s %d%s\n", $k, $table->{$k}, $mark);
    }
    # curated improvement backlog (harness/improvement-backlog.md) — candidate
    # tasks appended verbatim so the worker sees them without extra tooling.
    my $backlog = "$project_root/harness/improvement-backlog.md";
    if (-e $backlog) {
        open my $bfh, '<', $backlog or die "read $backlog: $!";
        local $/;
        my $content = <$bfh>;
        close $bfh;
        $prompt .= "\nCANDIDATE TASKS (improvement backlog — pick one or find your own):\n$content\n";
    }
    $prompt .= <<"PROMPT";
The highest-count runtime constructs (getVar/setVar/param/test/caseMatch/brace/
arith/forLoop/whileLoop/join/...) are where native lowering pays most. Pick the
construct with the CLEAREST best lowering, implement it, and verify below.

HOISTING — an in-loop sh2.* call runs PER ITERATION, so it is worth more than
a top-level one (the metric now tags them). Prefer lowerings that remove or
HOIST calls OUT of loop bodies: loop-invariant guards/setLastExit, invariant
getVar/setVar (values computed before the loop), and loop-invariant test
conditions. A call eliminated from a 10k-iteration loop is worth 10k call
sites in runtime terms even if the metric counts it once.

PROMPT
    $prompt .= build_plan_prompt();
    $prompt .= build_bench_prompt();
    $prompt .= fix_surface_text();
    $prompt .= <<"PROMPT";

VERIFY (mandatory, exactly like fix mode):
- Rust: cd sh2perl && cargo build --bin debashc && cargo test --lib  (determinism asserted)
- Full corpus: ./fail-estree  — must stay 100% (the correctness oracle; a test
  that previously passed now failing means your lowering is wrong — fix or revert)
- Structural gate stays green; NEW sh2.* names need estree_gate.pl whitelist
  entries; *Sync only for the pure-CPU loop exception (whileLoopSync precedent).
- The PERL backend is 100% the perl workers' problem — IGNORE perl entirely (never touch perl code, never act on perl verdicts). Your scope: the ESTree emitter/runtime. No blocking I/O (async-only codegen).
- Smallest change that wins the most. TRY the aggressive lowering and let the
  full suite judge (the loop stashes on regression) — only give up on an
  approach after it actually regresses a test, not on speculation. Every
  kept assumption must be documented + option-gated with the aggressive
  default.
- UPDATE THE PLAN FILE (.estree_plans.md): when you implement the CURRENT PLAN
  entry, set its Status to implemented (or blocked with the reason), fill in
  the benchmark after numbers, and note issues. If you find NEW fruit not in
  the plans, append a new entry.
- Prefer src/shir.rs (shared ShIR) for pattern lifts so other backends can
  reuse them; harness/sh2-namespace.mjs for runtime changes; estree_gate.pl
  for whitelist entries.
PROMPT
    return $prompt;
}

# ── metric helpers (M8 / PLAN.md §9) ────────────────────────────────
sub read_metric {
    my ($file) = @_;
    return undef unless -e $file;
    open my $fh, '<', $file or return undef;
    my ($total, $in_loop_total, %table, %in_loop);
    while (my $line = <$fh>) {
        chomp $line;
        my ($k, $v, $il) = split /\t/, $line;
        next unless defined $v && $v =~ /^\d+$/;
        if ($k eq 'total') { $total = $v + 0; }
        elsif ($k eq 'in_loop') { $in_loop_total = $v + 0; }
        else {
            $table{$k} = $v + 0;
            $in_loop{$k} = (defined $il && $il =~ /^\d+$/) ? $il + 0 : 0;
        }
    }
    close $fh;
    return {
        total => ($total // 0),
        in_loop_total => ($in_loop_total // 0),
        table => \%table,
        in_loop => \%in_loop,
    };
}

sub read_metric_total {
    my ($file) = @_;
    my $m = read_metric($file);
    return defined $m ? $m->{total} : undef;
}

sub write_metric_file {
    my ($file, $metric) = @_;
    return unless defined $metric;
    open my $fh, '>', $file or warn "write $file: $!";
    print $fh "total\t$metric->{total}\n";
    print $fh "$_\t$metric->{table}{$_}\n" for sort keys %{$metric->{table} // {}};
    close $fh;
}

# ── invoke pi (streaming, mirrors main_loop_rust.pl) ─────────────────
# Wait (fail-open) until MemAvailable > min_free MB and swap usage <
# max_swap_frac, polling every 30s up to max_wait_s. Returns when free,
# or after max_wait_s regardless (so pi isn't starved indefinitely).
sub wait_for_ram_perl {
    my ($min_free, $max_swap_frac, $max_wait_s) = @_;
    $min_free = 2048 unless defined $min_free;
    $max_swap_frac = 0.5 unless defined $max_swap_frac;
    $max_wait_s = 600 unless defined $max_wait_s;
    my $waited = 0;
    while ($waited < $max_wait_s) {
        my %mi;
        if (open my $fh, '<', '/proc/meminfo') {
            while (<$fh>) {
                if (/^(MemAvailable|SwapTotal|SwapFree):\s+(\d+)/) { $mi{$1} = $2; }
            }
            close $fh;
        }
        my $avail_mb = ($mi{MemAvailable} // 0) / 1024;
        my $tight = 0;
        if ($avail_mb < $min_free) {
            $tight = 1;  # low RAM = OOM risk, regardless of swap
        } elsif ($avail_mb < $min_free * 2) {
            # moderate RAM: high swap is the secondary pressure signal
            if (($mi{SwapTotal} // 0) > 0) {
                my $swap_frac = (($mi{SwapTotal} - ($mi{SwapFree} // 0)) / $mi{SwapTotal});
                $tight = 1 if $swap_frac > $max_swap_frac;
            }
            # else (plenty of RAM) high swap is ignored
        }
        if (!$tight) {
            return 0;
        }
        printf "  RAM tight (MemAvailable=%dMB%s) - waiting 30s (waited %ds)\n",
            $avail_mb,
            ($avail_mb < $min_free ? " < ${min_free}MB" : " + high swap"),
            $waited;
        sleep 30;
        $waited += 30;
    }
    print "  RAM still tight after ${max_wait_s}s; proceeding (fail-open)\n";
    return 1;
}

sub invoke_pi {
    my ($prompt) = @_;
    # RAM gate (fail-open, RELAXED — this is the LEAD worker, not a
    # secondary): the secondary workers yield at 2GB/50% swap; the lead
    # worker proceeds unless RAM is CRITICALLY low (<1GB) or moderately
    # low (<2GB) with very high swap (>80%), and waits at most 120s. It
    # must not be starved by the gates meant to throttle its followers.
    wait_for_ram_perl(1024, 0.8, 120);
    print "\nInvoking pi to fix ESTree failures...\n";
    my $pi_pid = open(my $pi_fh, '-|', 'pi', '--mode', 'json', '--provider', 'opencode-go', '--model', 'deepseek-v4-flash', '--thinking', 'xhigh', $prompt);
    unless (defined $pi_pid) {
        print STDERR "WARNING: could not run pi: $!\n";
        return 0;
    }
    my $deadline = time() + 3600;
    my $buffer = '';
    my $full = '';
    while (1) {
        my $remaining = $deadline - time();
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
                next unless ref $event eq 'HASH';
                my $type = $event->{type} // '';
                if ($type eq 'message_update') {
                    my $msg = $event->{assistantMessageEvent};
                    next unless ref $msg eq 'HASH';
                    my $et = $msg->{type} // '';
                    my $delta = $msg->{delta} // '';
                    if (($et eq 'thinking_delta' || $et eq 'text_delta') && length $delta) {
                        print $delta;
                        $full .= $delta;
                    } elsif ($et eq 'tool_use_start') {
                        my $name = $msg->{name} // '?';
                        print "\n\e[33m>>> tool: $name\e[0m\n";
                    }
                } elsif ($type eq 'message_end') {
                # SURFACE FAILURES (2026-08-15: the opencode-go provider
                # hit its monthly quota — every pi call died with a 429
                # GoUsageLimitError and the worker logged NOTHING between
                # 'Invoking pi' and '(pi finished)'. The stalled queue was
                # silently untouched for 187 rounds. Print the stopReason
                # + errorMessage so a dead provider is visible in one line
                # instead of looking like 'pi said nothing'.)
                my $msg = $event->{message} // {};
                my $err = $msg->{errorMessage} // '';
                if (($msg->{stopReason} // '') eq 'error') {
                    print STDERR "\n*** pi ERROR (stopReason=error): " . $err . "\n";
                    $full .= "[pi error] $err\n";
                }
            }
        }
    }
    }
    # the select loop exits on EOF (pi finished) or the 3600s budget.
    # On a BUDGET hit, kill the pi process TREE before `close` — Perl's
    # close on the pipe waits for the child, so a wedged pi (or its own
    # unbounded child probe — the 2026-08-14 incident: a
    # SIZE=100000000000000000 loop froze the whole estree loop 4.5h,
    # log stale from 19:17 until a manual kill) would block the worker
    # in do_wait forever.
    if (time() >= $deadline) {
        print "\n\e[33m(pi exceeded its 3600s budget — reaping the pi process tree)\e[0m\n";
        kill_tree($pi_pid);
    }
    close $pi_fh;
    print "\n(pi finished)\n";
    # Bounded final-reply echo: the deltas above streamed live, but a clean
    # bounded block makes the round's conclusion greppable (the DECISION
    # lines live here — or the reason they are absent, e.g. the provider
    # error surfaced above). Never echo unbounded: the transcripts ate GBs
    # of log + cgroup page cache (2026-08-14/15).
    my @reply_lines = split /\n/, $full;
    if (@reply_lines > 80) {
        print "--- pi final reply (first 20 / last 60 of " . scalar(@reply_lines) . " lines) ---\n";
        print "  $_\n" for @reply_lines[0 .. 19];
        print "  ... elided " . (scalar(@reply_lines) - 80) . " lines ...\n";
        print "  $_\n" for @reply_lines[-60 .. -1];
        print "--- end pi final reply ---\n";
    } elsif (@reply_lines) {
        print "--- pi final reply ---\n";
        print "  $_\n" for @reply_lines;
        print "--- end pi final reply ---\n";
    }
    # Return the accumulated full text so callers (the dedicated
    # core-request round) can parse per-request DECISION lines. Truthy
    # for the existing boolean callers (non-empty on success).
    return $full;
}

# ── process-tree reaper (watchdog) ──────────────────────────────────
# kill_tree(ROOT): TERM then KILL the root process AND every descendant
# (BFS over /proc ppid links). Used on a budget hit so the worker's
# `close $fh` cannot freeze the loop on a wedged child, and so a pi
# agent's runaway GRANDCHILDREN (an unbounded `while` probe, a stuck
# node runner) are not left reparented and burning CPU after pi itself
# dies.
sub kill_tree {
    my ($root) = @_;
    return unless defined $root && $root > 0;
    my %alive = ($root => 1);
    for (1 .. 3) {
        my %next = %alive;
        opendir my $dh, '/proc' or last;
        while (my $e = readdir $dh) {
            next unless $e =~ /^\d+$/;
            next if $alive{$e};
            my $line = '';
            if (open my $fh, '<', "/proc/$e/stat") {
                $line = <$fh>;
                close $fh;
            }
            next if $line eq '';
            # /proc/PID/stat: "pid (comm) state ppid ..." — comm may
            # contain spaces/parens, so split after the LAST ')'
            my $i = rindex($line, ')');
            next if $i < 0;
            my $rest = substr($line, $i + 1);
            next unless $rest =~ /^\s*\S\s+(\d+)/;
            $next{$e} = 1 if $alive{$1};
        }
        closedir $dh;
        last if scalar(keys %next) == scalar(keys %alive);
        %alive = %next;
    }
    kill 'TERM', keys %alive;
    sleep 2;
    my @stubborn = grep { kill(0, $_) } keys %alive;
    kill 'KILL', @stubborn if @stubborn;
    # reap the root (WNOHANG poll) so a subsequent `close` returns at once
    for (1 .. 40) {
        last if waitpid($root, 1) > 0;
        last unless kill(0, $root);
        select undef, undef, undef, 0.25;
    }
}

# ── scoped git operations (never add -A) ─────────────────────────────
# Whether the Perl worker (main_loop_rust.pl) is alive decides the fix
# surface: solo → all of sh2perl/src; rust loop live → src/estree.rs only.
sub perl_worker_running {
    my @ps = `ps -eo args 2>/dev/null`;
    for my $l (@ps) {
        return 1 if $l =~ /main_loop_rust\.pl\b/;
    }
    return 0;
}

sub fix_surface_wide { return !perl_worker_running(); }

sub submodule_changed_paths {
    my @out = `git -C "$sh2perl" status --porcelain`;
    my @allowed;
    my $wide = fix_surface_wide();
    for my $line (@out) {
        # porcelain format: "XY path" (X=index, Y=worktree; either may be a space)
        # UNTRACKED ("??") entries ARE included: scoped_commit stages them
        # (git add handles new files — pi's new modules must land, or the
        # build references files that never get committed). scoped_stash
        # filters them out (git stash cannot take untracked pathspecs).
        my ($path) = $line =~ /^..\s+(.+)$/;
        next unless defined $path;
        $path =~ s/\s+$//;
        if ($wide) {
            push @allowed, $path if $path =~ m{^src/};
        } else {
            push @allowed, $path if $path eq 'src/estree.rs';
        }
    }
    return @allowed;
}

sub root_changed_paths {
    my @out = `git status --porcelain harness/`;
    my @allowed;
    for my $line (@out) {
        my ($path) = $line =~ /^..\s+(.+)$/;
        next unless defined $path;
        $path =~ s/\s+$//;
        push @allowed, $path if $path =~ m{^harness/(estree-gen\.mjs|sh2-namespace\.mjs|estree-runner\.mjs|estree_gate\.pl|package\.json)$};
    }
    return @allowed;
}

# stash pathspecs must reference files git knows — untracked new files
# (pi's new modules) cannot be stashed by pathspec and would fail the push.
sub tracked_only {
    my ($repo, @paths) = @_;
    return grep { system('git', '-C', $repo, 'ls-files', '--error-unmatch', '--', $_) == 0 } @paths;
}

sub scoped_commit {
    my ($msg, $summary) = @_;
    my @sub = submodule_changed_paths();
    my @root = root_changed_paths();
    if (@sub) {
        # FULL-WORKSPACE BUILD GATE: the corpus gate (fail-estree) only
        # builds --bin debashc, but the backend workers build the WHOLE
        # workspace (debashl + its bins: glsl_dump, dump_*, ...). Commit
        # core changes only when the full build passes, so committed HEAD
        # is healthy for every consumer (2026-08-14: HEAD was committed
        # with a broken glsl_dump E0063 and the backend gates ground on
        # it for hours). On failure the WIP stays uncommitted in the tree.
        my $build_out = `cd '$sh2perl' && cargo build --manifest-path Cargo.toml 2>&1`;
        if ($? != 0) {
            print "\nFULL-WORKSPACE BUILD FAILED — NOT committing (fail-estree only builds debashc; the backend gates need the whole workspace). WIP left in the tree:\n";
            print substr($build_out, -500);
            print "\n";
            return;
        }
        system('git', '-C', $sh2perl, 'add', @sub);
        system('git', '-C', $sh2perl, 'commit', '-m', $msg);
        system('git', '-C', $project_root, 'add', 'sh2perl'); # bump gitlink
    }
    if (@root) {
        system('git', '-C', $project_root, 'add', @root);
        system('git', '-C', $project_root, 'commit', '-m', $msg);
    }
    log_decision('keep', @sub ? "sub: @sub" : '', @root ? "root: @root" : '', $msg);
}

sub scoped_stash {
    # stash ONLY tracked files (untracked new modules can't be a stash
    # pathspec); the stash reverts the modified references, and the
    # orphaned untracked files stop breaking the build once nothing
    # references them.
    my @sub = tracked_only($sh2perl, submodule_changed_paths());
    my @root = tracked_only($project_root, root_changed_paths());
    my $stashed = 0;
    if (@sub) {
        system('git', '-C', $sh2perl, 'stash', 'push', '-m', 'estree-loop regression', @sub);
        $stashed = 1;
    }
    if (@root) {
        system('git', '-C', $project_root, 'stash', 'push', '-m', 'estree-loop regression', @root);
        $stashed = 1;
    }
    return $stashed;
}

# ── main ─────────────────────────────────────────────────────────────
print "main_loop_estree.pl — ESTree backend repair loop\n";
print "project_root: $project_root\n";
print "dry_run: $dry_run  prefix: $prefix  seed: $seed\n";

my $wide = fix_surface_wide();
print "perl worker (main_loop_rust.pl): ", $wide ? "NOT running" : "RUNNING",
      "  -> fix surface: ", $wide ? "ALL of sh2perl/src + harness/*" : "src/estree.rs + harness/* (narrow)", "\n";
if ($wide) {
    my @dirty = `git -C "$sh2perl" status --porcelain src/`;
    chomp @dirty;
    if (@dirty) {
        print "WARNING: sh2perl/src not clean; wide-mode commit/stash will include:\n";
        print "  $_\n" for @dirty;
    }
}

acquire_lock();

# seed: initialize trusted counts + baseline from current state
if ($seed || !-e $estree_trusted_file) {
    my ($out, $code) = run_fail_estree();
    my $s = parse_summary($out);
    if (defined $s->{estree_failed}) {
        open my $tf, '>', $estree_trusted_file or warn "write: $!"; print $tf $s->{estree_failed}, "\t", $s->{total}, "\n"; close $tf;
        open my $pf, '>', $perl_trusted_file or warn "write: $!"; print $pf $s->{perl_failed}, "\t", $s->{total}, "\n"; close $pf;
        if (-e $results_file) {
            my $fails = read_fails($results_file);
            write_list($prev_file, $fails);
        }
        print "Seeded trusted counts: estree fails=$s->{estree_failed} perl fails=$s->{perl_failed}\n";
    } else {
        print "WARNING: seed run produced no summary. Is the corpus dir populated?\n";
    }
    release_lock();
    exit 0;
}


# ── core-requests: mediate + implement worker escalations ────────────
# The estree worker is the single owner of the shared core. Per-worktree
# backend workers and per-frontend workers escalate core needs via
# core-requests/<lang>-<ts>.md (see core-requests/README.md), and when
# TRAPPED they sleep on core-requests/sleeping-<lang> until we wake them.
# Each iteration: collect pending requests, pass ALL to one pi invocation
# that MEDIATES between conflicting requests and implements each WITHOUT
# regressing the ESTree corpus, then verify with fail-estree ourselves.
# Green: commit (scoped) + move requests to done/ + WAKE the sleeping
# workers (remove core-requests/sleeping-<lang>). Regressed: scoped_stash
# (revert pi's changes), leave requests + markers (workers stay asleep).
#
# STALLED != DONE: a request that survives 3 cycles without implementation
# is NOT retired — it moves to core-requests/stalled/ (never done/) and is
# re-fed to pi every iteration, STALLED FIRST (before pending requests and
# before any general estree/benchmark improvement). core-requests/
# stalled-needs.tsv is regenerated each iteration so the backlog stays
# visible to humans/agents. Only implemented/rejected requests reach done/.

my $core_requests_dir = "$project_root/core-requests";
my $stalled_dir       = "$core_requests_dir/stalled";    # 3-cycle-cap requests — REVISITED, not retired
my $stalled_report    = "$core_requests_dir/stalled-needs.tsv";  # human/agent-visible backlog report
my $stalled_max       = $ENV{SH2_STALLED_MAX} // 15;      # stalled reqs folded per iteration (prompt hygiene)
my @core_pending = ();    # pending request files this iteration (stalled first, then pending)
my $core_block = '';      # mediation block appended to the iteration's pi prompt

# Collect pending core-change requests (no pi invocation — the mediation is
# FOLDED into the estree worker's single pi prompt for this iteration, so
# there is exactly ONE pi agent per iteration touching the core). Returns
# the mediation block appended at the invoke_pi sites; the green-outcome
# path finalizes (commits + wakes sleeping workers).
sub collect_core_requests {
    @core_pending = ();
    $core_block = '';
    return '' unless -d $core_requests_dir;
    # NEWEST first (reverse filename order — the filename embeds the filing
    # timestamp). Rationale: the freshest escalations are the LIVE blockers
    # (the workers sleeping on core-requests/sleeping-<lang> wait for
    # today's requests, not August's); the shared core has evolved massively
    # since the Aug 6-7 filings (A1 contract, shir_passes, the frontend
    # fleet), so old requests are often superseded. Oldest-first starved
    # the newest under the stalled cap: the 15 oldest stalled (Aug 6-13)
    # consumed the whole budget every iteration while 388/411 stalled
    # (Aug 13-14) never reached the prompt. Within a class: newest first.
    # Stalled still precedes pending (stalled = 3+ cycles unaddressed —
    # revisit before fresh work), but the NEWEST stalled, not the oldest.
    my @reqs;
    if (-d $stalled_dir) {
        opendir(my $sdh, $stalled_dir) or return '';
        for my $f (reverse sort readdir $sdh) {
            next unless $f =~ /\.md$/;
            push @reqs, "$stalled_dir/$f";
            last if @reqs >= $stalled_max;
        }
        closedir $sdh;
    }
    my $n_stalled = scalar @reqs;
    opendir(my $dh, $core_requests_dir) or return '';
    for my $f (reverse sort readdir $dh) {
        next unless $f =~ /\.md$/;
        next if $f eq 'README.md';
        next if $f =~ /^sleeping-/;
        push @reqs, "$core_requests_dir/$f";
    }
    closedir $dh;
    return '' unless @reqs;
    @core_pending = @reqs;
    write_stalled_report();
    print "\ncore-requests: " . scalar(@reqs) . " folded into the pi prompt — $n_stalled stalled (revisit FIRST), "
        . (scalar(@reqs) - $n_stalled) . " pending (one pi per iteration).\n";
    print "  $_\n" for @reqs;
    my $b = "\n\n--- CORE-CHANGE REQUESTS (mediate + implement; no corpus regression) ---\n";
    $b .= "You are the SINGLE OWNER of the shared core (src/shir.rs, src/ir.rs, src/estree.rs,\n";
    $b .= "src/parser/, harness/*).\n";
    if ($n_stalled) {
        $b .= "PRIORITY 1 — STALLED REQUESTS (the first $n_stalled files below): these waited >=3 cycles\n";
        $b .= "  without implementation. REVISIT AND IMPLEMENT THEM BEFORE ANY OTHER WORK in this\n";
        $b .= "  prompt — before the pending requests and before any general estree/benchmark\n";
        $b .= "  improvement. A stalled request is NOT abandoned: it stays in core-requests/stalled/\n";
        $b .= "  and is re-fed here every iteration until you implement or explicitly reject it.\n";
    }
    $b .= "MEDIATE between the requests:\n";
    $b .= "  - priority within a class: NEWEST first (by filename timestamp) — the freshest\n";
    $b .= "    escalations are the live blockers; old requests may be superseded by the\n";
    $b .= "    shared core's evolution. Stalled (PRIORITY 1) still precedes pending.\n";
    $b .= "  - if two conflict, implement the one maximizing corpus coverage, note the rejection;\n";
    $b .= "  - implement each WITHOUT regressing the ESTree corpus (run ./fail-estree;\n";
    $b .= "    estree_failed must stay 0 / at the trusted baseline). If a request would regress,\n";
    $b .= "    leave it pending with a note.\n";
    $b .= "  - FOR EVERY request: either implement it, or APPEND a line to the\n";
    $b .= "    file of the form '## OUTCOME: rejected: <one-line reason>' (only that\n";
    $b .= "    exact marker counts — a bare mention is ignored). A request WITHOUT an\n";
    $b .= "    outcome marker is treated as UNTOUCHED: pending requests stay pending (they\n";
    $b .= "    accumulate a stall counter and move to core-requests/stalled/ after 3 cycles);\n";
    $b .= "    stalled requests stay in core-requests/stalled/ and are re-fed next iteration.\n";
    $b .= "    Only requests you actually addressed (implemented, or explicitly rejected with\n";
    $b .= "    a reason in the file) are finalized.\n\n";
    for my $r (@reqs) {
        my $txt = eval { local $/; open my $fh, '<', $r; <$fh> };
        $txt = "(unreadable request)" unless defined $txt;
        $b .= "--- $r ---\n$txt\n";
    }
    $core_block = $b;
    return $b;
}

# Regenerate core-requests/stalled-needs.tsv — the human/agent-visible
# backlog report. The loop itself never forgets stalled requests (it re-feds
# them every iteration); this file exists so whoever else is watching can see
# what is waiting and for how long.
sub write_stalled_report {
    my @rows;
    if (-d $stalled_dir && opendir(my $sdh, $stalled_dir)) {
        for my $f (sort readdir $sdh) {
            next unless $f =~ /^(.+)-\d{8}(?:-\d{6})?(?:-.*)?\.md$/;
            my $title = '';
            if (open my $fh, '<', "$stalled_dir/$f") {
                my $l = <$fh>; chomp $l;
                ($title = $l) =~ s/^#\s*//;
                close $fh;
            }
            push @rows, "$1\t$f\t$title";
        }
        closedir $sdh;
    }
    if (open my $fh, '>', $stalled_report) {
        print $fh "# stalled core-requests — revisited (stalled-first) before general estree work\n";
        print $fh "# lang\tfilename\ttitle\n";
        print $fh "$_\n" for @rows;
        close $fh;
    }
}

# Finalize implemented core requests once the corpus is green: commit the
# core changes pi made, move requests to core-requests/done/, and WAKE the
# sleeping workers (remove core-requests/sleeping-<lang>).
# Read the trusted ESTree failure count (from .estree_trusted_count).
sub estree_trusted {
    my $trusted = 10_000;
    if (open my $tf, '<', $estree_trusted_file) {
        my $f = <$tf>; chomp $f;
        my ($failed) = split /\t/, $f;
        $trusted = ($failed // '') + 0 if defined $failed && $failed ne '';
        close $tf;
    }
    return $trusted;
}

# ── core-requests/transforms: compile-in + bisect worker-submitted IR passes ──
# Secondary workers escalate the strongest form of a core need as a
# CONCRETE IR transform (.rs file, core-requests/transforms/<lang>-<name>.rs
# with `pub fn transform(&mut Vec<IrStmt>) -> bool`). The estree worker:
#   1. compile-in: copy to src/transforms/<sanitized>.rs + register in
#      all(). cargo build ONCE (all transforms registered).
#      Compile error -> the compiler names the file -> send back (rejected/).
#   2. gate: run fail-estree with all enabled (DEBASHC_TRANSFORMS empty).
#      Green -> keep (commit the compile-in) + move to done/.
#      Regressed -> bisect: binary search on DEBASHC_TRANSFORMS=first-n
#      (NO rebuild per step — the transforms are env-gated), blame the
#      first transform whose inclusion regresses, send it back (rejected/),
#      re-test the remainder.
my $transforms_dir = "$core_requests_dir/transforms";
my $src_transforms = "$sh2perl/src/transforms.rs";

sub process_core_transforms {
    return 0 if $dry_run;
    return 0 unless -d $transforms_dir;
    opendir(my $dh, $transforms_dir) or return 0;
    my @files = sort grep { /\.rs$/ } grep { !/^rejected\// } readdir $dh;
    closedir $dh;
    return 0 unless @files;
    print "\n" . "=" x 70, "\n";
    print "transforms: " . scalar(@files) . " worker-submitted IR passes — compile-in + gate\n";

    # 1. compile-in (copy + register + cargo build once)
    my @names = ();
    for my $f (@files) {
        (my $n = $f) =~ s/\.rs$//;
        (my $m = $n) =~ s/-/_/g;   # valid Rust ident
        push @names, $n;
        system('cp', "$transforms_dir/$f", "$sh2perl/src/transforms/$m.rs");
        if (open my $rfh, '<', $src_transforms) {
            local $/; my $t = <$rfh>; close $rfh;
            if ($t !~ /pub mod $m;/) {
                $t =~ s/pub mod sub;/pub mod $m;\npub mod sub;/;
                open my $wfh, '>', $src_transforms; print $wfh $t; close $wfh;
            }
            if ($t !~ /\(\s*"$n"/) {
                # ${m}::transform — the braces delimit the Perl var so the
                # Rust `::transform` stays literal text in the emitted line.
                $t =~ s/\/\/ \(name, <name>::transform\)/("$n", ${m}::transform),\n        \/\/ (name, <name>::transform)/;
                open my $wfh, '>', $src_transforms; print $wfh $t; close $wfh;
            }
        }
        print "  compile-in: $f -> src/transforms/$m.rs\n";
    }
    print "transforms: cargo build (once, all registered)...\n";
    if (system('cargo', 'build', '--manifest-path', "$sh2perl/Cargo.toml") != 0) {
        print "transforms: COMPILE ERROR — sending all back (the compiler names the file)\n";
        system('git', '-C', $sh2perl, 'checkout', '--', 'src/transforms.rs');
        system('git', '-C', $sh2perl, 'clean', '-f', 'src/transforms/');
        for my $f (@files) { system('mkdir', '-p', "$transforms_dir/rejected"); system('mv', "$transforms_dir/$f", "$transforms_dir/rejected/$f"); }
        log_decision('transform-compile', scalar(@files), 0, 'all-sent-back');
        return 1;
    }

    # 2. gate: all enabled
    my $trusted = estree_trusted();
    my $all_green = 0;
    {
        local $ENV{DEBASHC_TRANSFORMS} = '';
        my ($out, $code) = run_fail_estree();
        my $s = parse_summary($out);
        my $failed = defined $s->{estree_failed} ? $s->{estree_failed} : 10_000;
        if ($failed <= $trusted + 3) {
            $all_green = 1;
            print "transforms: all " . scalar(@names) . " GREEN (estree_failed=$failed) — keeping\n";
            my @sub = submodule_changed_paths();
            if (@sub) {
                system('git', '-C', $sh2perl, 'add', @sub);
                system('git', '-C', $sh2perl, 'commit', '-m', "transforms: worker-submitted IR passes (${\scalar @names})");
                system('git', '-C', $project_root, 'add', 'sh2perl');
            }
            for my $f (@files) { system('mv', "$transforms_dir/$f", "$transforms_dir/done/$f"); }
            log_decision('transform-gate', scalar(@names), $failed, 'keep-all');
        }
    }
    return 1 if $all_green;

    # 3. bisect: binary search for the first n that regresses
    print "transforms: REGRESSION with all on — bisecting (env-gated, no rebuild)\n";
    my ($lo, $hi) = (1, scalar @names);
    while ($lo < $hi) {
        my $mid = int(($lo + $hi) / 2);
        my $subset = join(',', @names[0 .. $mid-1]);
        local $ENV{DEBASHC_TRANSFORMS} = $subset;
        my ($out, $code) = run_fail_estree();
        my $s = parse_summary($out);
        my $failed = defined $s->{estree_failed} ? $s->{estree_failed} : 10_000;
        print "  bisect n=$mid ($subset): estree_failed=$failed\n";
        if ($failed > $trusted + 3) { $hi = $mid; } else { $lo = $mid + 1; }
    }
    my $blamed = $names[$lo-1];
    print "transforms: BLAMED transform $blamed (first to regress) — sending back\n";
    (my $bm = $blamed) =~ s/-/_/g;
    system('rm', '-f', "$sh2perl/src/transforms/$bm.rs");
    if (open my $rfh, '<', $src_transforms) {
        local $/; my $t = <$rfh>; close $rfh;
        $t =~ s/pub mod $bm;\n//;
        $t =~ s/\(\s*"$blamed", $bm::transform\),\n\s*//;
        open my $wfh, '>', $src_transforms; print $wfh $t; close $wfh;
    }
    system('mkdir', '-p', "$transforms_dir/rejected");
    system('mv', "$transforms_dir/$blamed.rs", "$transforms_dir/rejected/$blamed.rs");
    # the blamed transform is reverted; rebuild so the crate is green, then
    # re-test the remainder (repeat bisect if still regressed)
    system('cargo', 'build', '--manifest-path', "$sh2perl/Cargo.toml");
    log_decision('transform-blame', scalar(@names), 1, $blamed);
    return 1;
}

sub finalize_core_requests {
    return unless @core_pending;
    mkdir "$core_requests_dir/done";   # finalize targets — survive a wiped done/ or stalled/
    mkdir $stalled_dir;
    my @sub = submodule_changed_paths();
    my @root = root_changed_paths();
    if (@sub || @root) {
        my $s = { estree_passed => 'core-request', total => scalar(@core_pending),
                  estree_failed => 0, perl_passed => '?', perl_failed => '?' };
        scoped_commit("core-request: mediate + implement worker escalations", $s);
        print "\ncore-requests: core changes present; committing.\n";
    }
    # implemented -> done/ + WAKE the trapped worker (the fix landed);
    # rejected -> done/ with the reason RECORDED but NO wake (a rejected
    # request re-files uselessly — the -b loop; the rejection is the record);
    # untouched pending -> STAYS PENDING with a stall counter: after 3
    # consecutive cycles it moves to core-requests/stalled/ (NOT done/ — a
    # stalled request is debt the loop revisits, not a finished job) and is
    # re-fed to pi (stalled first) every iteration from then on;
    # untouched stalled -> STAYS in stalled/ (no counter — already there).
    my @impl      = grep { request_outcome($_) eq 'implemented' } @core_pending;
    my @rejected  = grep { request_outcome($_) eq 'rejected' } @core_pending;
    my @progress  = grep { request_outcome($_) eq 'progress' } @core_pending;
    my @untouched = grep { request_outcome($_) eq '' } @core_pending;
    for my $r (@impl) {
        my $bn = (split /\//, $r)[-1];
        system('mv', $r, "$core_requests_dir/done/$bn");
        if (my ($lang) = $bn =~ /^(.+)-\d{8}-\d{6}(?:-.*)?\.md$/) {
            my $marker = "$core_requests_dir/sleeping-$lang";
            if (-f $marker) {
                unlink $marker;
                print "  woke $lang (removed sleeping-$lang)\n";
            }
        }
    }
    for my $r (@rejected) {
        my $bn = (split /\//, $r)[-1];
        system('mv', $r, "$core_requests_dir/done/$bn");
        print "  rejected (worker stays asleep): $bn\n";
    }
    for my $r (@progress) {
        my $bn = (split /\//, $r)[-1];
        # partial work with a ## PROGRESS: handoff note (written by the loop
        # from the pi's DECISION line): stays out of done/ — another round
        # (or a human) continues from the note. A pending request that made
        # progress keeps its place: reset the 3-cycle stall counter so it
        # does not move to stalled/ while actively worked.
        if ($r =~ m{^\Q$stalled_dir\E/}) {
            print "  progress noted, stays stalled/ (next round continues from the note): $bn\n";
        } else {
            unlink "$r.stall" if -f "$r.stall";
            print "  progress noted, stays pending (stall counter reset): $bn\n";
        }
    }
    for my $r (@untouched) {
        my $bn = (split /\//, $r)[-1];
        if ($r =~ m{^\Q$stalled_dir\E/}) {
            # already stalled: stays put, revisited (stalled-first) next iteration
            print "  kept in stalled/ (revisit next iteration): $bn\n";
            next;
        }
        my $n = 0;
        if (open my $cf, '<', "$r.stall") { $n = <$cf>; close $cf; }
        $n++;
        if ($n >= 3) {
            system('mv', "$r.stall", "$stalled_dir/$bn.stall") if -f "$r.stall";
            system('mv', $r, "$stalled_dir/$bn");
            print "  STALLED (pending 3 cycles, no implementation) -> stalled/ (will revisit): $bn\n";
        } else {
            open my $cf, '>', "$r.stall"; print $cf $n; close $cf;
            print "  kept pending (cycle $n/3): $bn\n";
        }
    }
    write_stalled_report();
    log_decision('core-request', scalar(@impl), scalar(@rejected) + scalar(@untouched) + scalar(@progress), 'impl/rejected/pending/progress');
    @core_pending = ();
}

# A request's verdict: 'implemented' | 'rejected' | '' (untouched/pending).
sub request_outcome {
    my ($r) = @_;
    return '' unless -f $r;
    open my $fh, '<', $r or return '';
    local $/; my $txt = <$fh>; close $fh;
    if ($txt =~ /^## OUTCOME:\s*implemented/m) { return 'implemented'; }
    if ($txt =~ /^## OUTCOME:\s*rejected/m)    { return 'rejected'; }
    if ($txt =~ /^## PROGRESS:/m)                { return 'progress'; }
    return '';
}

# ── dedicated core-request mediation prompt ─────────────────────────
# Anti-starvation: when sibling workers have pending core-requests, a full
# pi round is given to the requests ALONE — the estree worker's own tiny
# improvement work (the sh2.* call-site grind) waits until the queue is
# empty. The corpus gate (green this iteration) still governs commits.
sub build_core_request_prompt {
    my ($summary) = @_;
    my $p = "You are the SINGLE OWNER of the shared sh2perl core.\n";
    $p .= "THIS ROUND IS PURELY THE CORE-REQUESTS BELOW — nothing else exists to do\n";
    $p .= "this round. Your ENTIRE deliverable is one line per request below:\n";
    $p .= "implement it, make PROGRESS on it, or reject it — nothing more, nothing\n";
    $p .= "else. Do not start any other work.\n\n";
    $p .= "Current corpus verdict (informational): estree " . ($summary->{estree_passed} // '?') . "/" . ($summary->{total} // '?') . " pass.\n\n";
    $p .= "MANDATORY PER-REQUEST ACCOUNTABILITY (the queue is no longer silently stalling):\n";
    $p .= "For EVERY request below you MUST emit, in your final reply to this prompt, a single line of the form:\n";
    $p .= "  [core-request <filename.md>] DECISION: implemented | rejected | progress | untouched — <one-line reason>\n";
    $p .= "The DECISION line is REQUIRED for every request — an in-file '## OUTCOME:' marker alone is NOT sufficient and is treated as a contract violation.\n";
    $p .= "- implemented: the fix landed and the corpus is green.\n";
    $p .= "- rejected: won't implement — one-line reason (superseded, conflicts, out of scope...).\n";
    $p .= "- progress: TOO LARGE FOR ONE ROUND — you did the tractable part and another session should continue. The loop appends your reason to the\n";
    $p .= "  request file as a '## PROGRESS:' handoff note; the NEXT round's pi continues from it. Say exactly what you did and what remains. Do NOT\n";
    $p .= "  write OUTCOME markers for progress — the loop records the note from your DECISION line.\n";
    $p .= "- untouched: no work this round — reason MANDATORY (state what you need to make progress — e.g. 'waiting on an upstream core change',\n";
    $p .= "  'conflicts with <other-request>, proposing reject').\n";
    $p .= "The loop scans your reply for these lines and prints a per-request table; missing lines surface as warnings so the situation is visible (and the stall cap is still the safety net).\n\n";
    $p .= "In-file outcomes (the existing contract) still apply where you DO land full work: APPEND '## OUTCOME: implemented' to the request file on implementation, or '## OUTCOME: rejected: <reason>' on rejection. The DECISION line is the per-round log signal; the in-file marker is the finalize signal.\n";
    $p .= "Regression rules (unchanged): ./fail-estree must stay green at the trusted baseline; determinism (cargo test --lib) and the structural gate must stay green; PERL pass count must not drop. If implementing would regress, the right call is 'untouched' WITH a reason (e.g. 'would regress tXX; needs a shir_passes fix first'), not a silent leave.\n";
    $p .= "If two requests conflict, implement the one maximizing corpus coverage and reject the other — the DECISION line carries the reason.\n";
    $p .= "Scope: shared core (src/shir.rs, src/ir.rs, src/estree.rs, src/parser/, shir_json.rs, shir_json_in.rs), src/transforms/ compile-ins (core-requests/transforms/), harness/*. Commit scoped changes when green.\n";
    return $p;
}

# ── parse per-request DECISION lines from pi's reply ─────────────────
# The dedicated mediation round requires pi to emit, for every request,
# `[core-request <name>] DECISION: implemented|rejected|untouched — <reason>`.
# Scan the pi transcript and build a { name => { state, reason } } map;
# report requests with no DECISION line as contract violations (so the
# situation is visible — "Deepseek trouble" / silent stall — without
# waiting for the cycle-3 auto-stall cap).
sub parse_pi_decisions {
    my ($text) = @_;
    my %d;
    return \%d unless defined $text && length $text;
    # Match the line; tolerate leading/trailing whitespace, em- or
    # en-dash separators (pi occasionally emits those), and the
    # <filename>.md may include hyphens.
    while ($text =~ m{
        \[\s*core-request\s+([\w.-]+\.md)\s*\]\s*
        DECISION\s*:\s*
        (implemented|rejected|untouched|progress)\s*
        [-–—]\s*
        ( [^\n\r]* )
    }gix) {
        $d{$1} = { state => lc($2), reason => $3 };
    }
    return \%d;
}

# ── print the per-request mediation table for a round ─────────────────
# For each request in @names, report the DECISION pi emitted (or flag
# a contract violation if none). This is the per-round accountability
# the dedicated prompt demands.
sub print_mediation_table {
    # Note: avoid `my (..., \@name) = @_` — that's the experimental
    # `declared_refs` feature in Perl 5.36+ and fatally aborts the
    # loop on startup. Take the array ref plainly.
    my ($decisions, $names) = @_;
    my $v = 0;  # violations
    for my $name (sort @$names) {
        my $bn = $name; $bn =~ s{.*/}{};
        my $d = $decisions->{$bn} || $decisions->{$name};
        if ($d) {
            my $r = $d->{reason}; $r //= ''; $r =~ s/^\s+|\s+$//g;
            print "    [core-request $bn] DECISION=" . $d->{state}
                . ($r ne '' ? "  — $r" : '') . "\n";
        } else {
            print STDERR "    [core-request $bn] *** CONTRACT VIOLATION: no per-round DECISION line emitted (in-file OUTCOME marker alone is insufficient; the situation is now visible — stall cap is the safety net)\n";
            $v++;
        }
    }
    if ($v) {
        print STDERR "  core-request mediation: $v contract violation(s) this round (missing DECISION lines).\n";
    }
    return $v;
}

my $iteration = 0;
while (1) {
    $iteration++;
    collect_core_requests();   # fold pending core escalations into this iteration's pi prompt
    process_core_transforms();  # compile-in + bisect worker-submitted IR passes
    print "\n" . "=" x 70, "\n";
    print "iteration $iteration — running fail-estree", ($prefix ne '' ? " (prefix $prefix)" : ''), "\n";
    my ($out, $code) = run_fail_estree();
    my $summary = parse_summary($out);
    unless (defined $summary->{estree_failed}) {
        # a missing summary usually means fail-estree's cargo build FAILED —
        # if the tree carries uncommitted changes they are a broken WIP:
        # stash them and retry (previously this slept+retried forever with
        # the broken tree, never stashing).
        my @ch = (submodule_changed_paths(), root_changed_paths());
        if (@ch) {
            my $stashed = scoped_stash();
            print STDERR "No summary (build failure?) with uncommitted changes — stashed broken WIP ($stashed).\n";
            log_decision('stash-build', '?', '?', $stashed ? 'stashed-broken-wip' : 'nothing');
        } else {
            print STDERR "No summary in fail-estree output (tree clean); sleeping and retrying.\n";
            sleep 30;
        }
        next;
    }
    my $fails = read_fails($results_file);
    my $baseline = (-e $prev_file) ? read_fails($prev_file) : [];
    my $diff = diff_lists($baseline, $fails);

    printf "ESTREE: %s/%s passed, %d failed (%d baseline) | PERL: %d/%s passed, %d failed\n",
        $summary->{estree_passed}, $summary->{total}, $summary->{estree_failed},
        $diff->{old_count}, $summary->{perl_passed}, $summary->{total}, $summary->{perl_failed};

    my $report_only = $prefix ne '';   # prefix runs are partial views: never
    # mutate baseline/trusted/commits — a full run verifies and commits.

    # ── flaky re-check (M8): a small failing set that PASSES SOLO is full-run
    # noise (/tmp races, load), not a regression — treat the corpus as green
    # so improvement mode can fire. A real regression fails solo too. Only
    # full runs (prefix runs are partial views and would false-positive).
    if (!$report_only && $summary->{estree_failed} > 0 && $summary->{estree_failed} <= 3) {
        my @still_failing;
        for my $f (@{$fails}) {
            my $solo = `timeout 120 "$fail_estree" "$f" 2>&1`;
            if ($solo =~ /ESTREE:\s*\d+ passed, 0 failed/) {
                print "flaky (passes solo): $f\n";
            } else {
                push @still_failing, $f;
            }
        }
        if (!@still_failing) {
            print "\nAll $summary->{estree_failed} failing test(s) pass solo — flaky full-run noise, treating corpus as green.\n";
            $summary->{estree_failed} = 0;
            $fails = [];
            $diff = diff_lists($baseline, $fails);
        }
    }

    # trusted-count files hold "failcount\ttotal" — split (never add the raw
    # line: "88\t528" isn't numeric and warned on every iteration)
    my $estree_trusted = 10_000;
    my $estree_total = 0;
    if (open my $tf, '<', $estree_trusted_file) {
        my $v = <$tf>; chomp $v if defined $v;
        my ($f, $t) = split /\t/, ($v // '');
        $estree_trusted = ($f // '') + 0 if defined $f && $f ne '';
        $estree_total = ($t // '') + 0;
        close $tf;
    }
    my $perl_trusted = 10_000;
    if (open my $pf, '<', $perl_trusted_file) {
        my $v = <$pf>; chomp $v if defined $v;
        my ($f) = split /\t/, ($v // '');
        $perl_trusted = ($f // '') + 0 if defined $f && $f ne '';
        close $pf;
    }
    if ($summary->{total} && $estree_total && $estree_total != $summary->{total}) {
        print "\nCorpus size changed ($estree_total -> $summary->{total}). Reseeding baseline + trusted counts.\n";
        open my $tf2, '>', $estree_trusted_file or warn "write: $!"; print $tf2 $summary->{estree_failed}, "\t", $summary->{total}, "\n"; close $tf2;
        open my $pf2, '>', $perl_trusted_file or warn "write: $!"; print $pf2 $summary->{perl_failed}, "\t", $summary->{total}, "\n"; close $pf2;
        write_list($prev_file, $fails);
        log_decision('reseed', $estree_total, $summary->{total}, 'corpus size change');
        sleep 3;
        next;
    }

    # ── regression guard (only stash when pi actually changed something) ──
    # (perl verdicts are COMPLETELY ignored: 100% the perl workers' problem)
    if (!$report_only && defined $summary->{estree_failed} && $summary->{estree_failed} > $estree_trusted + 3) {
        my @ch = (submodule_changed_paths(), root_changed_paths());
        print "\nREGRESSION: estree failures $summary->{estree_failed} > trusted $estree_trusted. Stashing scoped changes.\n";
        my $stashed = @ch ? scoped_stash() : 0;
        log_decision('stash', $estree_trusted, $summary->{estree_failed}, $stashed ? 'stashed' : 'nothing to stash');
        write_list($prev_file, $fails);
        sleep 5;
        next;
    }
    if (!$report_only && defined $summary->{perl_failed} && $summary->{perl_failed} > $perl_trusted + 3) {
        my @ch = (submodule_changed_paths(), root_changed_paths());
        print "\nREGRESSION: perl failures $summary->{perl_failed} > trusted $perl_trusted. Stashing scoped changes.\n";
        my $stashed = @ch ? scoped_stash() : 0;
        log_decision('stash-perl', $perl_trusted, $summary->{perl_failed}, $stashed ? 'stashed' : 'nothing to stash');
        write_list($prev_file, $fails);
        sleep 5;
        next;
    }

    # ── improvement → commit + update trusted ──
    if (!$report_only && $diff->{new_count} < $diff->{old_count}) {
        my @sub = submodule_changed_paths();
        my @root = root_changed_paths();
        if (@sub || @root) {
            print "\nImproved: $diff->{old_count} -> $diff->{new_count} estree failures. Committing.\n";
            scoped_commit("estree loop: $diff->{old_count} -> $diff->{new_count} failures (fixed " . scalar(@{$diff->{fixed}}) . ")", $summary);
        } else {
            print "\nImproved count but no file changes (flaky variance?). Updating baseline only.\n";
        }
        open my $tf, '>', $estree_trusted_file or warn "write: $!"; print $tf $summary->{estree_failed}, "\t", $summary->{total}, "\n"; close $tf;
        open my $pf, '>', $perl_trusted_file or warn "write: $!"; print $pf $summary->{perl_failed}, "\t", $summary->{total}, "\n"; close $pf;
        write_list($prev_file, $fails);
        log_decision('keep', $diff->{old_count}, $diff->{new_count}, 'improved');
        next;
    }

    # ── same count → update baseline (keep file changes if any) ──
    # Guarded with estree_failed > 0: at 0 failures the tree holds improvement
    # work (M8), which is committed/stashed on the METRIC, not a fix message.
    if (!$report_only && $diff->{new_count} == $diff->{old_count} && $summary->{estree_failed} > 0) {
        my @sub = submodule_changed_paths();
        my @root = root_changed_paths();
        if (@sub || @root) {
            print "\nSame failure count; committing file changes.\n";
            scoped_commit("estree loop: same count ($diff->{new_count} failures), code changes", $summary);
        }
        write_list($prev_file, $fails);
        log_decision('same', $diff->{old_count}, $diff->{new_count}, '');
        # fall through to possibly invoke pi on remaining failures
    } else {
        # regressed vs baseline but within trusted tolerance → update baseline,
        # then let pi look at the regressed set
        print "\nFailure count grew ($diff->{old_count} -> $diff->{new_count}) but within trusted tolerance. Updating baseline.\n";
        write_list($prev_file, $fails);
        log_decision('tolerance', $diff->{old_count}, $diff->{new_count}, join(',', @{$diff->{regressed}}));
    }

    # ── nothing left to fix → improvement mode (M8 / PLAN.md §9) ──
    if ($summary->{estree_failed} == 0) {
        # core-requests: once green, commit + wake any sleeping workers whose
        # requests the (single) pi call implemented.
        finalize_core_requests();
        # Anti-starvation policy: requests STILL pending after the previous
        # round's outcomes are finalized get a DEDICATED mediation round —
        # sibling workers (sh/c/go/python frontends + backends, trapped
        # sleepers) are blocked on them, so the estree worker's own tiny
        # improvements (the sh2.* call-site grind) wait until the queue is
        # empty. Regression protection is unchanged: the corpus gate (green
        # above) governs commits; a red corpus next iteration goes to fix
        # mode. report_only (prefix runs) never mutates: no invocation.
        collect_core_requests();
        if (!$report_only && @core_pending) {
            print "\nImprovement mode deferred: " . scalar(@core_pending) . " pending core-requests — dedicated mediation round (tiny estree improvements wait for the queue).\n";
            my $req_prompt = build_core_request_prompt($summary);
            if ($dry_run) {
                print "\n----- DRY RUN: core-request mediation prompt below, no pi invocation -----\n";
                print $req_prompt . $core_block;
                print "\n----- end dry run -----\n";
                release_lock();
                exit 0;
            }
            my $pi_text = invoke_pi($req_prompt . $core_block);
            # Per-round accountability: scan pi's reply for the
            # mandatory per-request DECISION lines and print a table.
            # Without this the "silently leave pending" failure mode (pi
            # in trouble) was invisible until the cycle-3 stall cap
            # kicked in. Now the situation surfaces immediately.
            my $decisions = parse_pi_decisions($pi_text);
            my $violations = print_mediation_table($decisions, [map { my $p=$_; $p =~ s{.*/}{}; $p } @core_pending]);
            if ($violations) {
                log_decision('core-request-violation', $violations, scalar(@core_pending), 'missing-decision');
            }
            # progress handoff: the pi emitted 'DECISION: progress — <what's
            # done / what remains>' for some requests — write the note into
            # the request file NOW so the NEXT round's pi (or a human)
            # continues from it. The note is the loop's pen, not pi's: pi
            # does not write OUTCOME markers for progress (per the prompt).
            for my $r (@core_pending) {
                my $bn = (split /\//, $r)[-1];
                my $d = $decisions->{$bn} // $decisions->{$r};
                next unless $d && $d->{state} eq 'progress';
                my $reason = $d->{reason} // 'partial work done';
                $reason =~ s/^\s+|\s+$//g;
                next if $reason eq '';
                open my $pf, '>>', $r or next;
                print $pf "\n## PROGRESS: $reason\n";
                close $pf;
                print "  [core-request $bn] progress handoff note appended (next round continues from it)\n";
            }
            sleep 3;
            next;
        }
        my $metric = read_metric($metric_file);
        if (!$report_only && defined $metric) {
            my $prev_total = read_metric_total($metric_prev);
            if (!defined $prev_total) {
                # seed the committed-state metric baseline, then idle a while
                write_metric_file($metric_prev, $metric);
                print "\nImprovement mode: metric baseline seeded ($metric->{total} sh2.* call sites). Idling.\n";
                log_decision('metric-seed', '?', $metric->{total}, '');
                if ($dry_run) { release_lock(); exit 0; }
                sleep 300;
                next;
            }
            my $cur = $metric->{total};
            if ($cur < $prev_total) {
                # pi's last round lowered call sites → commit (corpus is green
                # by construction here; determinism/gate verified by the worker)
                my @sub = submodule_changed_paths();
                my @root = root_changed_paths();
                if (@sub || @root) {
                    scoped_commit("estree improvement: sh2.* call sites $prev_total -> $cur", $summary);
                    print "\nImprovement: $prev_total -> $cur sh2.* call sites. Committed.\n";
                } else {
                    print "\nImprovement: $prev_total -> $cur sh2.* call sites (no file changes).\n";
                }
                write_metric_file($metric_prev, $metric);
                $improvement_idle_count = 0;
                log_decision('metric-improve', $prev_total, $cur, 'commit');
                next;
            }
            if ($cur > $prev_total + 1) {
                # pi's last round made things worse (more runtime calls)
                my @sub = submodule_changed_paths();
                my @root = root_changed_paths();
                my $stashed = (@sub || @root) ? scoped_stash() : 0;
                print "\nMETRIC REGRESSION: $prev_total -> $cur sh2.* call sites. Stashed scoped changes.\n";
                write_metric_file($metric_prev, $metric);
                $improvement_idle_count = 0;
                log_decision('metric-regress', $prev_total, $cur, $stashed ? 'stashed' : 'nothing');
                next;
            }
        }
        # flat (or first round after seed/commit): prompt the worker to find
        # cheaper lowerings; idle after 3 consecutive flat rounds.
        $improvement_idle_count++;
        if (!$report_only && $improvement_idle_count >= 3) {
            print "\nMetric flat after 3 improvement rounds. Idling.\n";
            log_decision('metric-idle', 'flat', 'flat', '');
            $improvement_idle_count = 0;
            if ($dry_run) { release_lock(); exit 0; }
            sleep 300;
            next;
        }
        my $prompt = build_improvement_prompt($metric, $summary, $fails);
        if ($dry_run) {
            print "\n----- DRY RUN: improvement prompt below, no pi invocation -----\n";
            print $prompt;
            print "\n----- end dry run -----\n";
            release_lock();
            exit 0;
        }
        invoke_pi($prompt . $core_block);
        sleep 3;
        next;
    }

    # ── build prompt + invoke pi ──
    my $prompt = build_prompt($summary, $fails, $diff, unsupported_tally($fails));
    if ($dry_run) {
        print "\n----- DRY RUN: prompt below, no pi invocation -----\n";
        print $prompt;
        print "\n----- end dry run -----\n";
        release_lock();
        exit 0;
    }
    invoke_pi($prompt . $core_block);

    # update the baseline so the diff next iteration reflects pi's changes
    write_list($prev_file, $fails);
    sleep 3;
}

release_lock();
