#!/usr/bin/env perl
# bisect-transforms.pl — blame the worker-submitted IR transforms that
# regress a backend gate.
#
# Standalone counterpart to the estree worker's embedded transform bisect
# (main_loop_estree.pl `process_core_transforms`): given an ORDERED list of
# transform names, binary-search which one(s) push a backend gate's failure
# count above the trusted baseline. It never rebuilds — every candidate is
# already compiled into the crate and gated at RUNTIME by the
# `DEBASHC_TRANSFORMS` env var (empty/unset = ALL registered), so each step
# is just a gate run with `DEBASHC_TRANSFORMS=<subset>`.
#
# Unlike the worker's single-pass blame, this script iterates: it removes
# each blamed transform from the candidate set and re-bisects the remainder,
# so ALL offending transforms are reported, not just the first.
#
# Usage:
#   perl bisect-transforms.pl [options] -- TRANSFORM1 TRANSFORM2 ...
#   perl bisect-transforms.pl [options] --list FILE            # names from a file
#   perl bisect-transforms.pl --all [options]                  # every registered transform
#
# Options:
#   --gate CMD      gate to run for each subset
#                   (default: ./fail-estree --metric)
#   --prefix P      corpus prefix passed after the gate's flags
#                   (fail-estree style positional filter; also overridable
#                   by just including it inside --gate)
#   --field F       which failure count the gate reports:
#                   estree|perl|shir|gated|raw   (default: estree)
#   --metric RE     exact regex whose $1 is the failure count (overrides --field)
#   --baseline N    trusted failure count (gate passes when failures <= N+tol)
#   --baseline-file F   read baseline from a file (first whitespace/tab field)
#                   (default auto-chosen by --field: estree->.estree_trusted_count,
#                    shir->.shir_trusted_count, perl->.perl_gen_trusted_count)
#   --measure       instead, run the gate ONCE with DEBASHC_TRANSFORMS empty
#                   and use that count as the baseline (the right choice when
#                   the candidates are NOT yet staged/registered: empty=ALL
#                   already excludes them, equal to the pre-addition state)
#   --tol N         tolerance above baseline counted as a regression
#                   (default 3, matching the estree worker)
#   --timeout S     per-gate timeout in seconds (default 1800)
#   --dry-run       print the bisect plan + all gate invocations, run nothing
#   --all           candidate set = every name currently in `all()` registry
#
# Exit status: 0 if no offending transform found; 1 if at least one was blamed.
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use Cwd qw(abs_path getcwd);
use File::Basename qw(dirname basename);

my $root = dirname(abs_path($0));
my $fail_estree = "$root/fail-estree";

my ($gate, $prefix, $field, $metric_re, $baseline, $baseline_file,
    $measure, $tol, $timeout, $dry_run, $all, $list_file, $always_on, $invert);
our $base = 0;   # resolved trusted baseline; visible to run_gate's flake fallback
my @always_on;   # transforms kept enabled in every subset (the trusted core)
my @transforms;
GetOptions(
    'gate=s'        => \$gate,
    'prefix=s'      => \$prefix,
    'field=s'       => \$field,
    'metric=s'      => \$metric_re,
    'invert'        => \$invert,
    'baseline=i'    => \$baseline,
    'baseline-file=s' => \$baseline_file,
    'measure'       => \$measure,
    'tol=i'         => \$tol,
    'timeout=i'     => \$timeout,
    'dry-run'       => \$dry_run,
    'all'           => \$all,
    'list=s'        => \$list_file,
    'always-on=s'   => \$always_on,
    'help'          => sub { print usage(); exit 0 },
) or die usage();

@always_on = split /,/, $always_on if defined $always_on;

$gate   //= "$fail_estree --metric";
$field  //= 'estree';
$tol    //= 3;
$timeout //= 1800;

# after GetOptions, the non-option args are the positional transform names
@transforms = @ARGV if @ARGV;

# ── candidate set ────────────────────────────────────────────────────
my @registry = registered_names("$root/sh2perl/src/transforms.rs");
if ($all) {
    @transforms = @registry;
} elsif ($list_file) {
    push @transforms, read_name_list($list_file);
}
die "no transforms given (use positional, --list, or --all)\n" unless @transforms;
# dedup, preserve order
my %seen; @transforms = grep { !$seen{$_}++ } @transforms;
my %reg = map { $_ => 1 } @registry;
for my $t (@transforms) {
    warn "  [warn] '$t' is not in the all() registry — a no-op unless staged\n"
        unless $reg{$t};
}

# ── baseline ─────────────────────────────────────────────────────────
$baseline_file //= trusted_file($field);
if ($measure) {
    $base = run_gate('');                      # empty = ALL registered
    print "baseline (all registered, DEBASHC_TRANSFORMS=empty): failures=$base\n";
} elsif (defined $baseline) {
    $base = $baseline;
} elsif ($baseline_file && -e $baseline_file) {
    open my $fh, '<', $baseline_file or die "read $baseline_file: $!";
    my $line = <$fh>; chomp $line; close $fh;
    ($base) = split /[\t\s]+/, $line;
    $base //= 0;
    print "baseline: failures=$base (from $baseline_file)\n";
} else {
    die "--baseline, --measure, or a readable --baseline-file is required\n";
}

print "gate:      $gate\n";
print "candidates (" . scalar(@transforms) . "): @transforms\n";
print "tolerance: $tol (regression = failures > ", ($base + $tol), ")\n\n";
exit 0 if $dry_run;

# ── iterate: blame + remove, re-bisect the remainder until green ─────
my @cand   = @transforms;
my @blamed = ();
my $round  = 0;
while (@cand) {
    $round++;
    my $all_fail = run_gate(join(',', @cand));
    print "round $round: all-in ($all_fail failures) vs baseline+$tol\n";
    last unless $all_fail > $base + $tol;       # remainder is green

    # binary search the first index whose inclusion regresses
    my ($lo, $hi) = (1, scalar @cand);
    while ($lo < $hi) {
        my $mid = int(($lo + $hi) / 2);
        my $subset = join(',', @cand[0 .. $mid - 1]);
        my $fails  = run_gate($subset);
        printf "  bisect n=%d/%d (%s): failures=%d\n", $mid, scalar(@cand),
            display_names($subset), $fails;
        if ($fails > $base + $tol) { $hi = $mid } else { $lo = $mid + 1 }
    }
    my $offender = $cand[$lo - 1];
    push @blamed, $offender;
    print "  >>> BLAMED: $offender\n\n";
    splice @cand, $lo - 1, 1;                   # remove it, continue
}

# ── report ───────────────────────────────────────────────────────────
if (@blamed) {
    print "\n" . ("=" x 60) . "\n";
    print "RESULT: @{[scalar @blamed]} offending transform(s) found\n";
    print "  @blamed\n";
    print "  (check for interactions first — re-bisect with each blamed\n";
    print "   transform excluded to confirm it alone, not a pair, regresses)\n";
    exit 1;
}
print "\nNo offending transform — the candidate set is green within tolerance.\n";
exit 0;

# ── helpers ──────────────────────────────────────────────────────────
# Run the gate with a DEBASHC_TRANSFORMS subset; return the failure count.
sub run_gate {
    my ($subset) = @_;
    my $full = (@always_on ? join(',', @always_on) . ($subset ne '' ? ",$subset" : '') : $subset);
    my $cmd = resolve_gate($gate);
    $cmd .= " $prefix" if defined $prefix && length $prefix;
    print "  [run] DEBASHC_TRANSFORMS=", (length $full ? $full : '(empty/all)'),
        " $cmd\n" unless $dry_run;
    return 0 if $dry_run;                       # dry-run: report only

    my $env = { %ENV, DEBASHC_TRANSFORMS => $full };
    # A first-run gate may spend its whole budget compiling the toolchain
    # (otranspilerl-cli) and return truncated output; that is NOT a
    # regression. Retry unparseable runs before falling back to the
    # catastrophic-regression sentinel, so a one-time build blip can't
    # fabricate a false blame.
    my $retries = 2;
    my ($out, $fails, $aborted) = ('', undef, 0);
    for my $attempt (0 .. $retries) {
        $aborted = 0;
        my $pid = open(my $fh, '-|');
        die "fork: $!" unless defined $pid;
        if ($pid == 0) {
            local %ENV = %$env;
            exec '/bin/sh', '-c', $cmd;         # keep $cmd's quoting intact
            exit 127;
        }
        ($out, my $timed_out) = ('', 0);
        my $deadline = time() + $timeout;
        # IMPORTANT: only stop on TRUE EOF (sysread == 0) or the deadline.
        # A gate can be quiet for many seconds while it builds/fans out
        # tests; treat selectivity as "no new line yet", never as EOD.
        while (1) {
            my $remaining = $deadline - time();
            if ($remaining <= 0) { $timed_out = 1; last; }
            my $rin = ''; vec($rin, fileno($fh), 1) = 1;
            my $wait = $remaining < 1 ? $remaining : 1;
            my $nfound = select($rin, undef, undef, $wait);
            if ($nfound < 0) { last; }          # select error
            if ($nfound == 0) { next; }         # quiet period — keep waiting
            my $buf; my $n = sysread($fh, $buf, 65536);
            if (!defined $n || $n == 0) { last; }  # EOF / read error
            $out .= $buf;
        }
        if (close $fh) { }                      # child exit status (best-effort)
        else { waitpid($pid, 0); }
        $aborted = $timed_out;
        $fails = extract_fail_count($out);
        last if defined $fails;
        print STDERR "  !! gate output unparseable"
            . ($aborted ? " (hit ${timeout}s timeout)" : '') . " — retry "
            . ($attempt < $retries ? ($attempt + 1) : 'exhausted') . "/$retries\n";
        print STDERR substr($out, 0, 600) . "\n" if length $out;
    }
    if (!defined $fails) {
        # Last resort: a crash/flake is NOT a blame-worthy regression.
        print STDERR "  !! treating unparseable gate run as a FLAKE (count=$base) — verify manually\n";
        return $base;
    }
    return $fails;
}

# Extract the failure count from gate stdout: --metric RE wins, else --field.
sub extract_fail_count {
    my ($out) = @_;
    if (defined $metric_re) {
        if ($invert) {
            # --metric must capture (pass, total); failures = total - pass
            return ($2 - $1) if $out =~ /$metric_re/;
            return undef;
        }
        return $1 if $out =~ /$metric_re/;
        return undef;
    }
    my %pat = (
        estree => '\bESTREE:\s+\d+ passed, (\d+) failed',
        perl   => '\bPERL:\s+\d+ passed, (\d+) failed',
        shir   => '\bSHIR:\s+\d+ passed, (\d+) failed',
        gated  => '\bGATED:\s+\d+ passed, (\d+) failed',
    );
    my $pat = $pat{$field};
    return $1 if $pat && $out =~ /$pat/;
    # generic last resort: any "N failed out of M"
    return $1 if $out =~ /(\d+) failed out of \d+/;
    return undef;
}

# A gate string may be an absolute path, "./rake-script", or a bare name.
sub resolve_gate {
    my ($g) = @_;
    return "$root/$g" if $g !~ m{/} && -e "$root/$g";
    return $g;
}

sub trusted_file {
    my ($f) = @_;
    return "$root/.estree_trusted_count"    if $f eq 'estree';
    return "$root/.shir_trusted_count"      if $f eq 'shir';
    return "$root/.perl_gen_trusted_count"  if $f eq 'perl';
    return undef;
}

# Parse the ordered (name, …) registry out of src/transforms.rs `all()`.
sub registered_names {
    my ($file) = @_;
    return () unless -e $file;
    open my $fh, '<', $file or die "read $file: $!";
    local $/; my $t = <$fh>; close $fh;
    # only the `all()` body, so a registry-looking name like ("DEBASHC_TRANSFORMS")
    # from an env-var doc elsewhere in the file can't leak into the candidate set.
    $t =~ /pub fn all\(\)[\s\S]*?vec!\[(.*?)\n\s*\]/s;
    return () unless defined $1;
    return ($1 =~ /\(\s*"([A-Za-z0-9._-]+)"/g);
}

sub read_name_list {
    my ($file) = @_;
    open my $fh, '<', $file or die "read $file: $!";
    my @n;
    while (<$fh>) {
        chomp; s/#.*//; s/^\s+|\s+$//g; next unless length;
        push @n, split /[,\s]+/, $_;
    }
    close $fh;
    return @n;
}

# Truncate a long comma-joined subset for the log line.
sub display_names {
    my ($s) = @_;
    return length($s) <= 80 ? $s : substr($s, 0, 80) . '…';
}

sub usage {
    return <<'USAGE';
Usage: perl bisect-transforms.pl [options] -- TRANSFORM1 TRANSFORM2 ...
       perl bisect-transforms.pl [options] --list FILE
       perl bisect-transforms.pl --all [options]

Options:
  --gate CMD        gate to run per subset (default: ./fail-estree --metric)
  --prefix P        corpus prefix appended after the gate's flags
  --field F         estree|perl|shir|gated|raw  (default: estree)
  --metric RE       exact regex; $1 = failure count (overrides --field)
  --baseline N      trusted failure count
  --baseline-file F file whose first field is the baseline
                    (default auto: .estree/.shir/.perl_gen_trusted_count)
  --measure         baseline = one gate run with DEBASHC_TRANSFORMS empty
  --tol N           regression tolerance above baseline (default: 3)
  --timeout S       per-gate timeout, seconds (default: 1800)
  --dry-run         print the plan, run nothing
  --all             candidate set = every registered transform
  --list FILE       read candidate names from FILE
  --always-on NAMES  comma-separated transforms kept enabled in EVERY subset
                    (the trusted core; keeps the baseline valid when the
                    candidates are new additions to an existing registry)
  --help            this message
USAGE
}
