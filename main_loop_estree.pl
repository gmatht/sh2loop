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
my $metric_prev  = "$project_root/.estree_metric_prev.tsv";  # committed-state metric baseline
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
- PERL (baseline, do not regress): $summary->{perl_passed}/$summary->{total}
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
- NEVER reduce the PERL pass count.
- If you cannot fix something, move on — do not regress what works.
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

# ── improvement-mode prompt (M8 / PLAN.md §9) ───────────────────────
sub build_improvement_prompt {
    my ($metric, $summary, $fails) = @_;
    my $total = (defined $metric ? ($metric->{total} // 0) : 0);
    my $table = defined $metric ? ($metric->{table} // {}) : {};
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

CURRENT METRIC — remaining sh2.* call sites across the corpus (fail-estree --metric):
PROMPT
    $prompt .= "  total: $total call sites\n";
    for my $k (sort { ($table->{$b} // 0) <=> ($table->{$a} // 0) } keys %$table) {
        $prompt .= sprintf("  %-16s %d\n", $k, $table->{$k});
    }
    $prompt .= <<"PROMPT";
The highest-count runtime constructs (getVar/setVar/param/test/caseMatch/brace/
arith/forLoop/whileLoop/join/...) are where native lowering pays most. Pick the
construct with the CLEAREST best lowering, implement it, and verify below.

PROMPT
    $prompt .= fix_surface_text();
    $prompt .= <<"PROMPT";

VERIFY (mandatory, exactly like fix mode):
- Rust: cd sh2perl && cargo build --bin debashc && cargo test --lib  (determinism asserted)
- Full corpus: ./fail-estree  — must stay 100% (the correctness oracle; a test
  that previously passed now failing means your lowering is wrong — fix or revert)
- Structural gate stays green; NEW sh2.* names need estree_gate.pl whitelist
  entries; *Sync only for the pure-CPU loop exception (whileLoopSync precedent).
- NEVER reduce the PERL pass count; no blocking I/O (async-only codegen).
- Smallest change that wins the most. If a lowering cannot be proven correct on
  the corpus, keep the existing runtime call — do not regress what works.
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
    my ($total, %table);
    while (my $line = <$fh>) {
        chomp $line;
        my ($k, $v) = split /\t/, $line;
        next unless defined $v && $v =~ /^\d+$/;
        if ($k eq 'total') { $total = $v + 0; }
        else { $table{$k} = $v + 0; }
    }
    close $fh;
    return { total => ($total // 0), table => \%table };
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
sub invoke_pi {
    my ($prompt) = @_;
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
                }
            }
        }
    }
    close $pi_fh;
    print "\n(pi finished)\n";
    return 1;
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

sub scoped_commit {
    my ($msg, $summary) = @_;
    my @sub = submodule_changed_paths();
    my @root = root_changed_paths();
    if (@sub) {
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
    my @sub = submodule_changed_paths();
    my @root = root_changed_paths();
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

my $iteration = 0;
while (1) {
    $iteration++;
    print "\n" . "=" x 70, "\n";
    print "iteration $iteration — running fail-estree", ($prefix ne '' ? " (prefix $prefix)" : ''), "\n";
    my ($out, $code) = run_fail_estree();
    my $summary = parse_summary($out);
    unless (defined $summary->{estree_failed}) {
        print STDERR "No summary in fail-estree output; sleeping and retrying.\n";
        sleep 30;
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

    my $estree_trusted = 10_000;
    if (open my $tf, '<', $estree_trusted_file) { my $v = <$tf>; chomp $v if defined $v; $estree_trusted = $v + 0 if defined $v && $v ne ''; close $tf; }
    my $perl_trusted = 10_000;
    if (open my $pf, '<', $perl_trusted_file) { my $v = <$pf>; chomp $v if defined $v; $perl_trusted = $v + 0 if defined $v && $v ne ''; close $pf; }

    # reseed trusted/baseline when the corpus size changes (examples churn)
    my $estree_total = 0;
    if (open my $tf, '<', $estree_trusted_file) {
        my $v = <$tf>; chomp $v if defined $v;
        my ($f, $t) = split /\t/, ($v // '');
        $estree_trusted = ($f // '') + 0; $estree_total = ($t // '') + 0;
        close $tf;
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
        invoke_pi($prompt);
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
    invoke_pi($prompt);

    # update the baseline so the diff next iteration reflects pi's changes
    write_list($prev_file, $fails);
    sleep 3;
}

release_lock();
