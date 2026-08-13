#!/usr/bin/env perl
# WorkerPool.pm — worker allocation + cgroup enforcement for the corpus gates.
#
# Sizes a gate run's parallel worker budget as
#     min( cpu_cap,              # int(nproc/2) — leave half the box for the
#                                #   pi agent windows ("native windows")
#          50%-of-RAM ceiling,   # 0.5 * MemTotal / est. worker RSS
#          loadavg room,         # 0.9*nproc − load1 → dynamic shrink while the
#                                #   box (agents + sibling gates) is busy
#          MemAvailable headroom,# keep ≥2GB free for the agents
#          global slot capacity )# .workers/ slot files: ALL gates on the box
#                                #   share ONE budget, so N agent loops running
#                                #   gates at once can't each spawn nproc/2
#                                #   workers (the observed oversubscription)
# ...floored at 1 so a gate always makes progress even when fully squeezed
# (the loadavg cap + cgroup weight make that one extra slot harmless).
#
# CGROUP ENFORCEMENT (on by default; best-effort — falls back to the
# cooperative accounting above when cgroups aren't writable, e.g. running
# unprivileged in WSL). TWO sibling cgroups under the controller root:
#   - sh2gates    — the corpus test workers: the gate process writes
#                   itself in BEFORE forking; children inherit membership.
#       memory:  limited to SH2_GATE_MEM_FRAC (default 0.5) of box RAM —
#                a runaway test can no longer OOM the box (it OOMs inside
#                the gates cgroup instead, sparing the agents);
#       pids:    SH2_GATE_PIDS_MAX (default 1024) — fork-bomb containment;
#       cpu:     cpu.shares SH2_GATE_CPU_SHARES (v1, default 512) /
#                cpu.weight SH2_GATE_CPU_WEIGHT (v2, default 50) — half
#                the default weight, so under contention the worker loops
#                (sh2workers) win CPU automatically;
#   - sh2workers — the long-running worker loops (estree / perl / backend /
#                frontend / triage + their pi sessions and builds): the
#                loop self-enrolls at startup (enter_worker_cgroup).
#       memory:  SH2_WORKER_MEM_FRAC (default 0.5) — a runaway worker or
#                pi session can't OOM the box either;
#       pids:    SH2_WORKER_PIDS_MAX (default 2048 — builds + node + pi
#                spawn more than a gate run);
#       cpu:     DEFAULT weight (1024/100) — the workers stay the priority
#                class; the gates yield to them under contention.
#
# CLI (so bash gates use the same logic as the perl gates):
#   perl WorkerPool.pm --status          print caps + cgroup status
#   perl WorkerPool.pm --max-jobs [want] print the current dynamic budget
#   perl WorkerPool.pm --enter [pid]     move pid (default $$) into sh2gates
#   perl WorkerPool.pm --enter-worker [pid]
#                                       move pid (default $$) into sh2workers
#   perl WorkerPool.pm --release         drop this process's worker slots
#
# Env: SH2_NO_CGROUPS=1 disables cgroup enforcement (cooperative only);
# SH2_WORKER_RAM_MB (128) est. RSS per test worker;
# SH2_WORKER_CAP (global pool cap override); SH2_TARGET_LOAD (0.9);
# SH2_GATE_MEM_FRAC (0.5); SH2_GATE_PIDS_MAX (1024);
# SH2_GATE_CPU_SHARES (512, v1); SH2_GATE_CPU_WEIGHT (50, v2);
# SH2_WORKER_MEM_FRAC (0.5); SH2_WORKER_PIDS_MAX (2048);
# SH2_WORKER_CPU_SHARES (1024, v1); SH2_WORKER_CPU_WEIGHT (100, v2).
package WorkerPool;
use strict;
use warnings;
use Fcntl qw(:flock);
use Cwd qw(abs_path);
use File::Basename qw(dirname);

my $STATE;

sub init {
    my (%o) = @_;
    return $STATE if $STATE;
    my $root = $o{root} || _default_root();
    my $S = {
        root          => $root,
        slots_dir     => "$root/.workers",
        nproc         => _nproc(),
        worker_ram_mb => $ENV{SH2_WORKER_RAM_MB} // 128,
        cgroup        => undef,
        acquired      => 0,
    };
    # cpu cap: keep half the box for the agents (same rule as before)
    $S->{cpu_cap} = int($S->{nproc} / 2);
    $S->{cpu_cap} = 1 if $S->{cpu_cap} < 1;
    # 50%-of-RAM ceiling
    my $mem_total_mb = _meminfo()->{MemTotal} // 0;
    $S->{ram_cap} = $mem_total_mb
        ? int(0.5 * $mem_total_mb / $S->{worker_ram_mb})
        : $S->{cpu_cap};
    $S->{ram_cap} = 1 if $S->{ram_cap} < 1;
    $S->{cap} = $S->{cpu_cap} < $S->{ram_cap} ? $S->{cpu_cap} : $S->{ram_cap};
    $S->{cap} = $ENV{SH2_WORKER_CAP} if defined $ENV{SH2_WORKER_CAP};
    $S->{cap} = 1 if $S->{cap} < 1;
    $S->{cgroup} = _cgroup_setup($S);
    mkdir $S->{slots_dir};   # ignore EEXIST; unwritable → accounting degrades
    $STATE = $S;
    return $S;
}

# ── cgroup setup (best-effort, fail-open) ───────────────────────────
sub _cgroup_setup {
    my ($S) = @_;
    return if $ENV{SH2_NO_CGROUPS};
    my $mem_frac      = $ENV{SH2_GATE_MEM_FRAC}     // 0.5;
    my $pids_max      = $ENV{SH2_GATE_PIDS_MAX}     // 1024;
    my $shares        = $ENV{SH2_GATE_CPU_SHARES}   // 512;
    my $wm_f          = $ENV{SH2_WORKER_MEM_FRAC}   // 0.5;
    my $wm_pids       = $ENV{SH2_WORKER_PIDS_MAX}   // 2048;
    my $wm_shares     = $ENV{SH2_WORKER_CPU_SHARES} // 1024;
    my $mem_total     = _meminfo()->{MemTotal} // 0;
    my $mem_limit     = int($mem_total * 1024 * $mem_frac);   # kB → bytes
    my $wm_mem_limit  = int($mem_total * 1024 * $wm_f);
    my $min_bytes = 256 * 1024 * 1024;
    $mem_limit    = $min_bytes if $mem_limit    < $min_bytes;
    $wm_mem_limit = $min_bytes if $wm_mem_limit < $min_bytes;

    # v1 first: per-controller trees /sys/fs/cgroup/{memory,cpu,pids}
    my (%gates, %workers);
    for my $ctrl (qw(memory cpu pids)) {
        my $base = "/sys/fs/cgroup/$ctrl";
        next unless -d $base;
        my $g = "$base/sh2gates";
        my $w = "$base/sh2workers";
        $gates{$ctrl}   = $g if mkdir $g;
        $workers{$ctrl} = $w if mkdir $w;
    }
    if (%gates || %workers) {
        _write("$gates{memory}/memory.limit_in_bytes", $mem_limit)     if $gates{memory};
        _write("$gates{cpu}/cpu.shares", $shares)                     if $gates{cpu};
        _write("$gates{pids}/pids.max", $pids_max)                    if $gates{pids};
        _write("$workers{memory}/memory.limit_in_bytes", $wm_mem_limit) if $workers{memory};
        _write("$workers{cpu}/cpu.shares", $wm_shares)                if $workers{cpu};
        _write("$workers{pids}/pids.max", $wm_pids)                   if $workers{pids};
        return { type => 'v1', gates => \%gates, workers => \%workers };
    }

    # v2 fallback: unified tree at /sys/fs/cgroup (pure v2) or
    # /sys/fs/cgroup/unified (hybrid WSL). Only usable if the controllers
    # are ALREADY enabled on the parent's subtree_control (we never try to
    # enable them — that needs root at boot; a fresh v2 box without them
    # falls back to cooperative mode).
    for my $root ('/sys/fs/cgroup', '/sys/fs/cgroup/unified') {
        next unless -f "$root/cgroup.controllers";
        my $sc = _read("$root/cgroup.subtree_control") // '';
        next unless $sc =~ /\bmemory\b/ && $sc =~ /\bcpu\b/ && $sc =~ /\bpids\b/;
        my $g = "$root/sh2gates";
        my $w = "$root/sh2workers";
        my ($g_ok, $w_ok) = (mkdir $g, mkdir $w);
        next unless $g_ok || $w_ok;
        my $weight   = $ENV{SH2_GATE_CPU_WEIGHT}   // 50;
        my $wm_weight = $ENV{SH2_WORKER_CPU_WEIGHT} // 100;
        _write("$g/memory.max", $mem_limit)    if $g_ok;
        _write("$g/cpu.weight", $weight)       if $g_ok;
        _write("$g/pids.max", $pids_max)       if $g_ok;
        _write("$w/memory.max", $wm_mem_limit) if $w_ok;
        _write("$w/cpu.weight", $wm_weight)    if $w_ok;
        _write("$w/pids.max", $wm_pids)        if $w_ok;
        return { type => 'v2', root => $root, gates => ($g_ok ? $g : undef),
                 workers => ($w_ok ? $w : undef) };
    }
    return;
}

sub enter_cgroup {
    my ($pid) = @_;
    $pid //= $$;
    my $S = $STATE or return 0;
    my $cg = $S->{cgroup} or return 0;
    return _enter_cg($cg, 'gates', $pid);
}

# Move into sh2workers — the long-running worker loops (estree/perl/
# backend/frontend/triage + their pi sessions). Children inherit.
sub enter_worker_cgroup {
    my ($pid) = @_;
    $pid //= $$;
    my $S = $STATE or return 0;
    my $cg = $S->{cgroup} or return 0;
    return _enter_cg($cg, 'workers', $pid);
}

sub _enter_cg {
    my ($cg, $which, $pid) = @_;
    my $moved = 0;
    if ($cg->{type} eq 'v1') {
        my $dirs = $cg->{$which} or return 0;
        for my $dir (values %$dirs) {
            $moved++ if _append("$dir/tasks", "$pid\n");
        }
    } elsif ($cg->{type} eq 'v2') {
        my $dir = $cg->{$which} or return 0;
        $moved++ if _append("$dir/cgroup.procs", "$pid\n");
    }
    return $moved ? 1 : 0;
}

# ── worker budget ───────────────────────────────────────────────────
sub max_jobs {
    my ($want) = @_;
    my $S = $STATE or return 1;
    $want //= $S->{cap};
    # global slots currently held by OTHER gate processes
    my $slot_cap = $S->{cap} - _slots_held();
    $slot_cap = 1 if $slot_cap < 1;
    # loadavg room — the dynamic shrink: yields to agents AND sibling gates
    my $load1  = _loadavg();
    my $target = $ENV{SH2_TARGET_LOAD} // 0.9;
    my $room   = int($target * $S->{nproc} - $load1);
    my $load_cap = $room >= 1 ? $room : 1;
    # MemAvailable headroom — keep ≥2GB for the agents (fail-open: no
    # MemAvailable on ancient kernels → don't constrain)
    my $avail_mb = _meminfo()->{MemAvailable};
    my $ram_cap  = $S->{cap};
    if (defined $avail_mb) {
        $ram_cap = $avail_mb > 2048
            ? int(($avail_mb - 2048) / $S->{worker_ram_mb})
            : 1;
        $ram_cap = 1 if $ram_cap < 1;
    }
    my $jobs = $want;
    $jobs = $slot_cap if $slot_cap < $jobs;
    $jobs = $load_cap if $load_cap < $jobs;
    $jobs = $ram_cap  if $ram_cap  < $jobs;
    $jobs = 1 if $jobs < 1;    # progress floor: a gate never stalls
    return $jobs;
}

# Acquire worker slots from the shared pool (flock'd). Returns how many
# workers this gate may spawn now. Slots are released on release()/exit.
sub acquire {
    my ($want) = @_;
    my $S = $STATE or return 1;
    my $n = max_jobs($want);
    my $lock = "$S->{slots_dir}/lock";
    return $n unless open my $lfh, '>', $lock;
    if (flock($lfh, LOCK_EX)) {
        _sweep_slots();                     # precise under the lock
        my $avail = $S->{cap} - _slots_held();
        $n = $avail if $avail < $n;
        $n = 1 if $n < 1;                   # progress floor (see header)
        for my $i (1 .. $n) {
            my $f = "$S->{slots_dir}/slot.$$.$i";
            if (open my $sfh, '>', $f) {
                print $sfh "$$\n";
                close $sfh;
            }
        }
        $S->{acquired} = $n;
    }
    close $lfh;
    return $n;
}

sub release {
    my $S = $STATE or return;
    return unless -d $S->{slots_dir};
    for my $f (glob "$S->{slots_dir}/slot.$$.*") {
        unlink $f;
    }
    $S->{acquired} = 0;
}

sub status {
    my $S = $STATE or return 'not initialized';
    my $cg = $S->{cgroup}
        ? ($S->{cgroup}{type} eq 'v1'
            ? 'v1(gates=' . join(',', sort keys %{ $S->{cgroup}{gates} // {} })
              . ' workers=' . join(',', sort keys %{ $S->{cgroup}{workers} // {} }) . ')'
            : 'v2')
        : 'none (cooperative fallback)';
    return "cap=$S->{cap} (cpu $S->{cpu_cap}, ram50%-cap $S->{ram_cap}) cgroup=$cg";
}

# ── slot accounting helpers ─────────────────────────────────────────
sub _slots_held {
    my $S = $STATE or return 0;
    return 0 unless -d $S->{slots_dir};
    my $n = 0;
    for my $f (glob "$S->{slots_dir}/slot.*") {
        next if $f =~ m{/lock$};
        my $pid = _slot_pid($f);
        next if $pid == $$;                 # my own slots don't count
        $n++ if _alive($pid);
    }
    return $n;
}

sub _sweep_slots {
    my $S = $STATE or return;
    return unless -d $S->{slots_dir};
    for my $f (glob "$S->{slots_dir}/slot.*") {
        next if $f =~ m{/lock$};
        my $pid = _slot_pid($f);
        unlink $f unless $pid && _alive($pid);   # crashed gate → its slots die
    }
}

sub _slot_pid {
    my ($f) = @_;
    open my $fh, '<', $f or return 0;
    my $l = <$fh>;
    close $fh;
    return $l =~ /^(\d+)/ ? $1 : 0;
}

sub _alive {
    my ($pid) = @_;
    return 0 unless $pid && $pid > 0;
    return kill(0, $pid) ? 1 : 0;
}

# ── system probes (all Linux/WSL; absent files → fail-open) ─────────
sub _nproc {
    my $n = 1;
    if (open my $fh, '<', '/proc/cpuinfo') {
        my @l = grep { /^processor\s*:/ } <$fh>;
        $n = scalar @l || 1;
        close $fh;
    }
    return $n;
}

sub _meminfo {
    my %mi;
    if (open my $fh, '<', '/proc/meminfo') {
        while (<$fh>) {
            if (/^(MemTotal|MemAvailable):\s+(\d+)/) { $mi{$1} = $2; }
        }
        close $fh;
    }
    return \%mi;
}

sub _loadavg {
    if (open my $fh, '<', '/proc/loadavg') {
        my $l = <$fh>;
        close $fh;
        return $l =~ /^(\d+\.\d+|\d+)/ ? $1 + 0 : 0;
    }
    return 0;
}

sub _read  { open my $fh, '<', $_[0] or return undef; local $/; my $v = <$fh>; close $fh; return $v; }
sub _write { open my $fh, '>', $_[0] or return 0; print $fh "$_[1]\n" or return 0; close $fh; return 1; }
sub _append{ open my $fh, '>>', $_[0] or return 0; print $fh "$_[1]" or return 0; close $fh; return 1; }

sub _default_root {
    return dirname(dirname(abs_path($0)));
}

# ── CLI ─────────────────────────────────────────────────────────────
unless (caller) {
    my $root = _default_root();
    my $cmd  = shift @ARGV // '--status';
    if ($cmd eq '--status') {
        init(root => $root);
        print WorkerPool::status(), "\n";
    } elsif ($cmd eq '--max-jobs') {
        init(root => $root);
        my $want = defined $ARGV[0] ? $ARGV[0] + 0 : undef;
        print WorkerPool::max_jobs($want), "\n";
    } elsif ($cmd eq '--enter') {
        init(root => $root);
        my $pid = defined $ARGV[0] ? $ARGV[0] + 0 : $$;
        my $ok = WorkerPool::enter_cgroup($pid);
        warn "WorkerPool: cgroup unavailable (cooperative mode)\n" unless $ok;
        print WorkerPool::status(), "\n";
    } elsif ($cmd eq '--enter-worker') {
        init(root => $root);
        my $pid = defined $ARGV[0] ? $ARGV[0] + 0 : $$;
        my $ok = WorkerPool::enter_worker_cgroup($pid);
        warn "WorkerPool: cgroup unavailable (cooperative mode)\n" unless $ok;
        print WorkerPool::status(), "\n";
    } elsif ($cmd eq '--release') {
        init(root => $root);
        WorkerPool::release();
    } else {
        die "usage: $0 {--status|--max-jobs [want]|--enter [pid]|--enter-worker [pid]|--release}\n";
    }
}
