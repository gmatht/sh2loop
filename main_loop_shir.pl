#!/usr/bin/env perl
# main_loop_shir.pl — the shIR normalisation worker (transform PRODUCER).
#
# Job: write IR transforms that eliminate `system('bash', '-c', ...)` call
# sites, verify them locally, and submit them to the CORE worker via the
# established channel (core-requests/transforms/<name>.rs — the core worker
# compile-ins, gates, keeps/rejects; see main_loop_estree.pl
# process_core_transforms + src/transforms.rs DEBASHC_TRANSFORMS gating).
#
# This worker NEVER edits the core (no sh2perl/src changes, no gitlink
# bumps): it produces self-contained `pub fn transform(&mut Vec<IrStmt>) ->
# bool` passes. The core worker is the single owner of transforms.rs.
#
# Gate: ./fail-shir — the RENDERED-output dimension (system('bash'...)
# call sites in the generated perl). The core worker's check_qx_shir is the
# A1 dimension; fail-shir is the end-to-end "does the transpiled program
# still need bash" truth (the `echo ... | tr ...` shell-out class).
#
# Per iteration:
#   1. run ./fail-shir (metric + tally + .shir_failures.tsv)
#   2. poll core-requests/transforms/{done,rejected}/ for shir-* outcomes
#   3. pick the top actionable system()-call pattern (normalisable files,
#      or the top tally command)
#   4. invoke pi to WRITE one self-contained transform .rs
#   5. verify locally: temp compile-in + cargo build --bin debashc +
#      DEBASHC_TRANSFORMS=<name> ./fail-shir (must improve) +
#      ./fail-estree (must stay at the trusted estree count); then REVERT
#   6. verified -> submit to core-requests/transforms/shir-<ts>-<name>.rs
#      (the core worker picks it up); not verified -> log + discard
#
# Options:
#   --dry-run   one iteration: run the gate + build the prompt, print it,
#               exit WITHOUT invoking pi.
#   --prefix X  restrict this run's corpus to files containing X.
#   --seed      initialize the trusted baseline from the current run.
#
# Run: nohup perl main_loop_shir.pl >> loop-shir.log 2>&1 &
use strict;
use warnings;
use Time::HiRes qw(sleep);
use FindBin;
use POSIX qw(:sys_wait_h);
use JSON::PP;

$| = 1;
STDERR->autoflush(1);

my $project_root = $FindBin::RealBin;
my $sh2perl = "$project_root/sh2perl";
my $gate     = "$project_root/fail-shir";
my $fail_estree = "$project_root/fail-estree";
my $results_file = "$project_root/.shir_failures.tsv";
my $trusted_file = "$project_root/.shir_trusted_count";
my $history_log  = "$project_root/.shir_history.log";
my $lock_file    = "$project_root/.shir_loop.lock";
my $transforms_dir = "$project_root/core-requests/transforms";
my $submissions_file = "$project_root/.shir_submissions.tsv";
my $estree_trusted_file = "$project_root/.estree_trusted_count";

my $dry_run = 0;
my $prefix  = '';
my $seed    = 0;
for (my $i = 0; $i < @ARGV; $i++) {
    my $a = $ARGV[$i];
    $dry_run = 1 if $a eq '--dry-run';
    $seed    = 1 if $a eq '--seed';
    $prefix  = $ARGV[$i + 1] if $a eq '--prefix';
}

# ── lock ─────────────────────────────────────────────────────────────
sub acquire_lock {
    return if $dry_run;
    if (-e $lock_file) {
        open my $lf, '<', $lock_file or return 0;
        my $pid = <$lf>; chomp $pid if defined $pid; close $lf;
        if (defined $pid && $pid ne '' && kill(0, $pid + 0)) {
            print STDERR "Another shir loop is running (PID $pid). Exiting.\n";
            exit 1;
        }
        unlink $lock_file;
    }
    open my $lf, '>', $lock_file or die "write $lock_file: $!";
    print $lf $$, "\n"; close $lf;
    return 1;
}
sub release_lock { unlink $lock_file if -e $lock_file; }

sub log_decision {
    my ($decision, $before, $after, $extra) = @_;
    open my $fh, '>>', $history_log or warn "Cannot append $history_log: $!";
    print $fh join("\t", localtime(), $decision, $before, $after, $extra // ''), "\n";
    close $fh;
}

# ── run a command, capture stdout, tolerate quiet periods ────────────
sub run_capture {
    my ($cmd, $budget) = @_;
    $budget //= 3600;
    my $pid = open(my $fh, '-|', $cmd);
    return ('', 1) unless defined $pid;
    my $output = '';
    my $deadline = time() + $budget;
    while (time() < $deadline) {
        my $rin = ''; vec($rin, fileno($fh), 1) = 1;
        my $n = select($rin, undef, undef, 30);
        if ($n > 0) {
            my $buf;
            my $read = sysread($fh, $buf, 65536);
            last unless defined $read && $read > 0;
            $output .= $buf;
        }
    }
    if (time() >= $deadline) { print STDERR "[shir loop] timed out — reaping\n"; kill_tree($pid); }
    close $fh;
    my $exit_code = $? >> 8;
    return ($output, $exit_code);
}

sub run_gate {
    my $cmd = "$gate" . ($prefix ne '' ? " $prefix" : '');
    return run_capture($cmd, 3600);
}

sub parse_summary {
    my ($out) = @_;
    my $s = { bashfree => undef, total => undef, norm_sites => 0, norm_files => 0, tally => {} };
    if ($out =~ /SHIR: (\d+) files bash-free/) { $s->{bashfree} = $1; }
    if ($out =~ /SHIR: (\d+) shell-out call sites across (\d+) files/) { $s->{total} = $1; }
    if ($out =~ /SHIR: (\d+) normalisable call sites across (\d+) files/) { $s->{norm_sites} = $1; $s->{norm_files} = $2; }
    if ($out =~ /SHIR: top shell-out commands: (.+)/) {
        my $tally_s = $1;
        while ($tally_s =~ /(\S+)\s+(\d+)/g) { $s->{tally}{$1} = $2; }
    }
    return $s;
}

sub update_trusted {
    my ($s) = @_;
    open my $tf, '>', $trusted_file or warn "write: $!";
    print $tf "$s->{bashfree}\t$s->{total}\n";
    close $tf;
}

# the estree worker's trusted failure count (the behavioral no-regression bar)
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

# ── poll the core worker's transform outcomes ────────────────────────
# The core worker moves submissions to done/ (kept) or rejected/ (sent
# back). Track outcomes per submission name in .shir_submissions.tsv.
sub poll_outcomes {
    my %logged;
    if (open my $fh, '<', $submissions_file) {
        while (<$fh>) { chomp; my ($n) = split /\t/; $logged{$n} = 1; }
        close $fh;
    }
    my $new = 0;
    for my $dir (qw(done rejected)) {
        next unless -d "$transforms_dir/$dir";
        opendir my $dh, "$transforms_dir/$dir" or next;
        for my $f (sort readdir $dh) {
            next unless $f =~ /^shir-.*\.rs$/;
            next if $logged{$f};
            open my $afh, '>>', $submissions_file or last;
            print $afh "$f\t$dir\n"; close $afh;
            print "shir: submission OUTCOME — $f -> $dir/\n";
            log_decision('outcome', '', '', "$f $dir");
            $new++;
        }
        closedir $dh;
    }
    return $new;
}

# ── verify a transform locally (temp compile-in + gate + revert) ─────
# Returns 1 if the transform compiles AND reduces fail-shir shell-outs AND
# keeps fail-estree at the trusted count. The core tree is restored
# exactly (no git clean — a concurrent core worker may have its own files).
sub verify_transform {
    my ($src, $want_less) = @_;    # src = the transform .rs; want_less = current total
    my $ts = time();
    my $label = "shir-verify-$ts";
    (my $mod = $label) =~ s/-/_/g;
    my $reg = "$sh2perl/src/transforms.rs";
    my $target = "$sh2perl/src/transforms/$mod.rs";

    system('cp', $src, $target);
    my $t = '';
    { local $/; open my $fh, '<', $reg or return 0; $t = <$fh>; close $fh; }
    my $edited = 0;
    if ($t !~ /pub mod $mod;/) {
        $t =~ s/pub mod sub;/pub mod $mod;\npub mod sub;/;
        $edited = 1;
    }
    if ($t !~ /\(\s*"$label"/) {
        $t =~ s/\/\/ \(name, <name>::transform\)/("$label", ${mod}::transform),\n        \/\/ (name, <name>::transform)/;
        $edited = 1;
    }
    if (!$edited) { system('rm', '-f', $target); print "  verify: registration anchors not found in transforms.rs\n"; return 0; }
    { open my $fh, '>', $reg or return 0; print $fh $t; close $fh; }

    print "  verify: building debashc with $label (isolated target)...\n";
    # CARGO_TARGET_DIR: NEVER touch the shared main-tree binary — a temp
    # transform compiled into it would poison the estree worker's next gate
    # (the phantom-regression class this worker's isolation is about).
    my $vtarget = "$project_root/.shir-verify-target";
    my $vbin = "$vtarget/debug/debashc";
    my ($bout, $brc) = run_capture("CARGO_TARGET_DIR='$vtarget' cargo build --manifest-path '$sh2perl/Cargo.toml' --bin debashc 2>&1", 900);
    if ($brc != 0 || !-x $vbin) {
        print "  verify: COMPILE ERROR:\n", substr($bout, -400), "\n";
        system('git', '-C', $sh2perl, 'checkout', '--', 'src/transforms.rs');
        system('rm', '-f', $target);
        return 0;
    }

    # gate: shell-outs must go DOWN under this transform (against the
    # ISOLATED binary, never the shared one)
    my ($gout, $grc) = run_capture("DEBASHC='$vbin' DEBASHC_TRANSFORMS='$label' $gate" . ($prefix ne '' ? " $prefix" : ''), 3600);
    my $g = parse_summary($gout);
    my $ok = defined $g->{total} && $g->{total} < $want_less;
    print "  verify: fail-shir with transform: total=$g->{total} (was $want_less) bashfree=$g->{bashfree}\n";
    if (!$ok) {
        print "  verify: shell-outs did not decrease — rejecting transform\n";
    } else {
        # behavioral no-regression: estree corpus must stay at trusted. The
        # gate runs against the isolated binary via a symlinked SH2PERL_DIR
        # (examples + binary in one dir, like the main tree's layout).
        my $trusted = estree_trusted();
        my $edir = "$project_root/.shir-verify-estree";
        system('rm', '-rf', $edir);
        system('mkdir', '-p', "$edir/target/debug");
        system('ln', '-s', $sh2perl . '/examples', "$edir/examples");
        system('ln', '-s', $vbin, "$edir/target/debug/debashc");
        my ($eout, $erc) = run_capture("SH2PERL_DIR='$edir' $fail_estree 2>&1", 3600);
        system('rm', '-rf', $edir);
        my $efailed = 10_000;
        if ($eout =~ /ESTREE:\s+\d+ passed, (\d+) failed/) { $efailed = $1; }
        print "  verify: fail-estree with transform: estree_failed=$efailed (trusted=$trusted)\n";
        $ok = 0 if $efailed > $trusted + 3;
    }

    system('git', '-C', $sh2perl, 'checkout', '--', 'src/transforms.rs');
    system('rm', '-f', $target);
    return $ok;
}

# ── the pi prompt ────────────────────────────────────────────────────
sub build_prompt {
    my ($summary, $grep_examples) = @_;
    my @sorted = sort { ($summary->{tally}{$b} // 0) <=> ($summary->{tally}{$a} // 0) } keys %{$summary->{tally}};
    my $top = join(", ", map { "$_ $summary->{tally}{$_}" } @sorted[0 .. (@sorted < 12 ? $#sorted : 11)]);

    my $prompt = <<"PROMPT";
You are writing an IR TRANSFORM for the sh2perl transpiler. The job: a
self-contained pass that ELIMINATES \`system('bash', '-c', ...)\` call sites
in the rendered output — the transpiled program must stop needing bash at
runtime for commands that have native emulations.

CURRENT STATE (the gate ./fail-shir counts system('bash'...) call sites in
the rendered perl):
- bash-free files: $summary->{bashfree}/546
- total shell-out call sites: $summary->{total}
- normalisable call sites (all shell-outs are whitelisted commands): $summary->{norm_sites} across $summary->{norm_files} files
- top shell-out commands: $top

EXAMPLES of files shelling out (from .shir_failures.tsv — the patterns to
eliminate):
$grep_examples

DELIVERABLE — ONE self-contained transform at:
  core-requests/transforms/shir-<name>.rs

Contract (the core worker compile-ins this file; read
sh2perl/src/transforms/arith_forms.rs for the reference shape):
- \`pub fn transform(stmts: &mut Vec<IrStmt>) -> bool\` — returns true iff it
  changed anything; walks stmts recursively (Blocks/If/While/For bodies).
- Self-contained: imports from \`crate::ir\` / \`crate::shir\` only (the same
  imports arith_forms.rs uses). No new modules, no core edits.
- The core worker registers it as ("shir-<name>", shir_<name>::transform)
  and gates it via DEBASHC_TRANSFORMS — your file must compile when dropped
  into src/transforms/ with a \`pub mod shir_<name>;\` line added.

WHAT TO TARGET — the cheapest correct pattern that removes system() calls:
- The renderer shells out when the A1 shape it sees isn't one it renders
  natively. Rewrite the A1 shape into the canonical native shape the
  renderers already emulate (the emulable commands are in
  harness/shir-whitelist.txt; the renderers' emulation paths exist for
  whitelisted commands).
- Pattern families that pay: exec-of-builtin shapes (\`exec("echo", ...)\`,
  \`exec("tr", ...)\`) that the renderer shells out -> the canonical
  Emulable exec shape; test-position \`echo X | grep P\` -> contains;
  capture \$(echo X | tr ...) -> native transform; pipelines of emulable
  stages -> native stages.
- REFUSE > GUESS: if a shape cannot be proven bash-identical, leave it
  alone. A transform that removes a shell-out but changes behavior will be
  rejected by the gates (fail-estree must stay green).

VERIFY YOURSELF (the worker re-verifies with the full gates):
- cd sh2perl && cargo build --bin debashc && cargo test --lib
- You CANNOT run the corpus gates (the worker does: temp compile-in +
  DEBASHC_TRANSFORMS=<label> ./fail-shir must show FEWER shell-outs +
  ./fail-estree must stay at the trusted estree failure count). If your
  transform doesn't reduce shell-outs or regresses estree, it will be
  rejected — iterate on the shape, don't force it.

NEVER touch: sh2perl/src/** (the core worker owns it), harness/**, the
renderers, examples/, PLAN.md, main_loop*.pl, fail*. Your ONLY output is
the transform .rs file.
PROMPT
    return $prompt;
}

# ── pick grep-able examples of the top pattern for the prompt ────────
sub grep_examples {
    my ($summary) = @_;
    my @sorted = sort { ($summary->{tally}{$b} // 0) <=> ($summary->{tally}{$a} // 0) } keys %{$summary->{tally}};
    return "  (no shell-outs)" unless @sorted;
    my $top = $sorted[0];
    my @rows;
    if (open my $fh, '<', $results_file) {
        while (<$fh>) {
            chomp;
            my @f = split /\t/;
            next unless @f >= 6;
            push @rows, "$f[0]\tshellouts=$f[1]\tcommands=$f[5]" if $f[5] =~ /(^|,)$top(,|$)/;
            last if @rows >= 8;
        }
        close $fh;
    }
    return join("\n", @rows);
}

# ── RAM gate + pi invocation ─────────────────────────────────────────
sub wait_for_ram {
    my ($min_free, $max_swap_frac, $max_wait_s) = @_;
    $min_free = 2048 unless defined $min_free;
    $max_swap_frac = 0.5 unless defined $max_swap_frac;
    $max_wait_s = 600 unless defined $max_wait_s;
    my $waited = 0;
    while ($waited < $max_wait_s) {
        my %mi;
        if (open my $fh, '<', '/proc/meminfo') {
            while (<$fh>) { if (/^(MemAvailable|SwapTotal|SwapFree):\s+(\d+)/) { $mi{$1} = $2; } }
            close $fh;
        }
        my $avail_mb = ($mi{MemAvailable} // 0) / 1024;
        my $tight = 0;
        if ($avail_mb < $min_free) { $tight = 1; }
        elsif ($avail_mb < $min_free * 2) {
            if (($mi{SwapTotal} // 0) > 0) {
                my $swap_frac = (($mi{SwapTotal} - ($mi{SwapFree} // 0)) / $mi{SwapTotal});
                $tight = 1 if $swap_frac > $max_swap_frac;
            }
        }
        return 0 unless $tight;
        printf "  RAM tight (MemAvailable=%dMB) - waiting 30s\n", $avail_mb;
        sleep 30; $waited += 30;
    }
    print "  RAM still tight after ${max_wait_s}s; proceeding (fail-open)\n";
    return 1;
}

sub invoke_pi {
    my ($prompt, $outfile) = @_;
    wait_for_ram(1024, 0.8, 120);
    print "\nInvoking pi to write a shIR normalisation transform...\n";
    my $pi_pid = open(my $pi_fh, '-|', 'pi', '--mode', 'json', '--provider', 'opencode-go', '--model', 'deepseek-v4-flash', '--thinking', 'xhigh', $prompt);
    unless (defined $pi_pid) { print STDERR "WARNING: could not run pi: $!\n"; return 0; }
    my $deadline = time() + 3600;
    my $buffer = ''; my $full = '';
    while (1) {
        my $remaining = $deadline - time();
        last if $remaining <= 0;
        my $rin = ''; vec($rin, fileno($pi_fh), 1) = 1;
        last unless select($rin, undef, undef, 30) > 0;
        my $buf; my $read = sysread($pi_fh, $buf, 8192);
        last unless defined $read && $read > 0;
        $buffer .= $buf;
        while ($buffer =~ s/^(.*)\n//) {
            my $line = $1; next if $line eq '';
            my $event = eval { JSON::PP::decode_json($line) };
            next unless ref $event eq 'HASH';
            my $type = $event->{type} // '';
            if ($type eq 'message_update') {
                my $msg = $event->{assistantMessageEvent};
                next unless ref $msg eq 'HASH';
                my $et = $msg->{type} // '';
                my $delta = $msg->{delta} // '';
                if (($et eq 'thinking_delta' || $et eq 'text_delta') && length $delta) { print $delta; $full .= $delta; }
                elsif ($et eq 'tool_use_start') { print "\n\e[33m>>> tool: $msg->{name}\e[0m\n"; }
            } elsif ($type eq 'message_end') {
                my $msg = $event->{message} // {};
                if (($msg->{stopReason} // '') eq 'error') {
                    print STDERR "\n*** pi ERROR: " . ($msg->{errorMessage} // '') . "\n";
                }
            }
        }
    }
    if (time() >= $deadline) { print "\n\e[33m(pi exceeded its budget — reaping)\e[0m\n"; kill_tree($pi_pid); }
    close $pi_fh;
    print "\n(pi finished)\n";
    # save the full transcript so the worker can find the transform path
    open my $ofh, '>', $outfile or warn "write $outfile: $!";
    print $ofh $full;
    close $ofh;
    return $full;
}

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
            if (open my $fh, '<', "/proc/$e/stat") { $line = <$fh>; close $fh; }
            next if $line eq '';
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
    for (1 .. 40) {
        last if waitpid($root, 1) > 0;
        last unless kill(0, $root);
        select undef, undef, undef, 0.25;
    }
}

# ── main ─────────────────────────────────────────────────────────────
print "main_loop_shir.pl — shIR normalisation worker (transform producer)\n";
print "project_root: $project_root\n";
print "dry_run: $dry_run  prefix: $prefix  seed: $seed\n";

acquire_lock();

# seed (one-shot)
if ($seed || !-e $trusted_file) {
    my ($out, $code) = run_gate();
    my $summary = parse_summary($out);
    print $out;
    if (defined $summary->{bashfree}) {
        update_trusted($summary);
        print "Seeded trusted baseline: bashfree=$summary->{bashfree} shellouts=$summary->{total}\n";
    } else {
        print "WARNING: seed run produced no summary — is the corpus populated and debashc built?\n";
    }
    release_lock();
    exit 0;
}

# main loop
while (1) {
    my ($out, $code) = run_gate();
    my $summary = parse_summary($out);
    print $out;

    if (!defined $summary->{bashfree}) {
        print "WARNING: gate produced no summary\n";
        sleep 60;
        next;
    }
    update_trusted($summary);

    # per-iteration report for summarize-progress.sh (the fleet convention:
    # the newest line in gate-reports/<name>.report is the latest report)
    open my $rfh, '>>', "$project_root/gate-reports/shir.report" or warn "write gate-reports/shir.report: $!";
    print $rfh localtime(), " shir: $summary->{bashfree}/$summary->{total} bash-free, $summary->{norm_sites} normalisable call sites\n";
    close $rfh;

    poll_outcomes();

    if ($summary->{total} == 0) {
        print "Corpus is fully bash-free — no system() call sites to eliminate (idle).\n";
        log_decision('done', '0/0', '0/0', 'fully bash-free');
        sleep 300;
        next;
    }

    my $examples = grep_examples($summary);
    my $prompt = build_prompt($summary, $examples);

    if ($dry_run) {
        print "\n--- DRY RUN: the pi prompt would be ---\n$prompt\n";
        release_lock();
        exit 0;
    }

    # pi writes the transform; the transcript is saved so the worker can
    # find the .rs it produced
    my $scratch = "$project_root/.shir_pi_transcript.txt";
    invoke_pi($prompt, $scratch);

    # find a transform pi produced under core-requests/transforms/
    my $submitted = 0;
    opendir my $dh, $transforms_dir or print "no transforms dir ($transforms_dir)\n" and next;
    my @cands = sort grep { /^shir-.*\.rs$/ && !/^shir-\d{8}-\d{6}-/ } readdir $dh;
    closedir $dh;
    # also look in the pi scratch for a written path
    for my $f (@cands) {
        my $src = "$transforms_dir/$f";
        print "shir: pi produced $src — verifying...\n";
        my $ok = verify_transform($src, $summary->{total});
        if ($ok) {
            (my $ts = $src) =~ s/.*shir-/shir-/;
            my $stamp = time();
            my $dest = "$transforms_dir/shir-" . (localtime($stamp)) . "-$f";
            $dest =~ s/\s+/-/g;   # sanitise the localtime spaces
            system('mv', $src, $dest);
            print "shir: VERIFIED — submitted to core worker: $dest\n";
            log_decision('submit', "$summary->{bashfree}/$summary->{total}", '', $dest);
            $submitted++;
        } else {
            print "shir: NOT verified — $src discarded (kept for inspection)\n";
            system('mv', $src, "$transforms_dir/rejected/") if -d "$transforms_dir/rejected";
            log_decision('reject-local', "$summary->{bashfree}/$summary->{total}", '', $f);
        }
        last if $submitted >= 1;   # one transform per iteration
    }
    if (!$submitted && !@cands) {
        print "shir: pi produced no transform (transcript at $scratch)\n";
        log_decision('no-transform', "$summary->{bashfree}/$summary->{total}", '', '');
    }

    sleep 30;
}

# ── helpers used above ───────────────────────────────────────────────
# (defined before main for clarity; Perl resolves at runtime)
sub poll_outcomes;   # no-op forward decl (already defined above)
