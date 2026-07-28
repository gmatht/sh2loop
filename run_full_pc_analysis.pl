#!/usr/bin/env perl
use strict;
use warnings;
use File::Temp qw(tempfile);
use File::Basename qw(basename);
use Cwd qw(realpath);
use JSON::PP;
use POSIX qw(:sys_wait_h);

#==============================================================================
# run_full_pc_analysis.pl
#
# Full Perl::Critic analysis of all sh/ files WITHOUT exemptions.
# Uses parallel workers for speed.
#==============================================================================

my $ROOT     = realpath("$FindBin::RealBin");
my $SH_DIR   = "$ROOT/sh";
my $DEBASHC  = "$ROOT/sh2perl/target/release/debashc";

die "ERROR: $SH_DIR not found\n" unless -d $SH_DIR;
die "ERROR: $DEBASHC not found\n" unless -x $DEBASHC;

# Read the current perlcritic.conf to get exempted policies
my $CONF_FILE = "$ROOT/sh2perl/docs/perlcritic.conf";
my %exempted_policies;
if (-f $CONF_FILE) {
    open my $fh, '<', $CONF_FILE or die "Cannot read $CONF_FILE: $!";
    while (<$fh>) {
        chomp;
        if (/^\[-([^\]]+)\]/) {
            $exempted_policies{$1} = 1;
        }
    }
    close $fh;
}

my @sh_files = sort glob("$SH_DIR/*");
my $total = scalar @sh_files;

# Also check for the full-path policy names that perlcritic actually reports
# Map long names to short names
my %long_to_short = (
    'Perl::Critic::Policy::InputOutput::RequireCheckedSyscalls' => 'InputOutput::RequireCheckedSyscalls',
    'Perl::Critic::Policy::Modules::ProhibitExcessMainComplexity' => 'Modules::ProhibitExcessMainComplexity',
    'Perl::Critic::Policy::Modules::RequireVersionVar' => 'Modules::RequireVersionVar',
);

print "=" x 80, "\n";
print "Full Perl::Critic Analysis (no exemptions)\n";
print "=" x 80, "\n";
print "Files to process: $total\n";
print "Exempted policies: " . (scalar keys %exempted_policies) . "\n\n";

my $MAX_WORKERS = 8;
my $TIMEOUT = 30;  # seconds per file

# Divide files into chunks for parallel processing
my @chunks;
my $base = int($total / $MAX_WORKERS);
my $rem  = $total % $MAX_WORKERS;
my $pos  = 0;
for my $w (0 .. $MAX_WORKERS - 1) {
    my $n = $base + ($w < $rem ? 1 : 0);
    push @chunks, [ @sh_files[$pos .. $pos + $n - 1] ];
    $pos += $n;
}

my $work_dir = "$ROOT/.pc_analysis_work";
mkdir $work_dir unless -d $work_dir;

# Fork workers
my @worker_pids;
for my $w (0 .. $MAX_WORKERS - 1) {
    my $pid = fork;
    die "fork: $!" unless defined $pid;
    if ($pid == 0) {
        # Worker process
        open my $log, '>', "$work_dir/worker_${w}.jsonl" or die "Cannot write $work_dir/worker_${w}.jsonl: $!";
        for my $sh_file (@{$chunks[$w]}) {
            my $name = basename($sh_file);
            my ($fh, $tmp_path) = tempfile("pc-XXXXXXXX", SUFFIX => '.pl', UNLINK => 1);
            close $fh;
            
            # Convert to Perl
            my $gen_out = qx($DEBASHC -i '$sh_file' -o '$tmp_path' 2>/dev/null);
            my $gen_exit = $? >> 8;
            
            unless (-s $tmp_path && $gen_exit == 0) {
                unlink $tmp_path if -f $tmp_path;
                print $log "ERROR\t$name\tgeneration_failed\n";
                next;
            }
            
            # Run perlcritic with all severities, no exemptions
            my $critic_out = qx(perlcritic --severity 1 '$tmp_path' 2>/dev/null);
            my $critic_exit = $? >> 8;
            
            my @violations;
            if ($critic_exit != 0 && $critic_out ne '') {
                for my $line (split /\n/, $critic_out) {
                    next if $line =~ /^Source OK/;
                    next if $line =~ /^\s*$/;
                    
                    if ($line =~ /^(.+) at line (\d+), column (\d+)\.\s*(.*?)\s*\(Severity:\s*(\d+)\)\s*$/) {
                        my ($policy, $line_num, $col_num, $desc, $sev) = ($1, $2, $3, $4, $5);
                        # Normalize policy name
                        $policy =~ s/^Perl::Critic::Policy:://;
                        my $violation = {
                            policy => $policy,
                            line => $line_num,
                            col => $col_num,
                            desc => $desc,
                            severity => $sev,
                        };
                        push @violations, $violation;
                    }
                }
            }
            
            print $log "OK\t$name\t" . (encode_json(\@violations) // '[]') . "\n";
            unlink $tmp_path if -f $tmp_path;
        }
        close $log;
        exit 0;
    }
    push @worker_pids, $pid;
}

# Wait for all workers
my $done = 0;
while ($done < $MAX_WORKERS) {
    $done = 0;
    for my $pid (@worker_pids) {
        my $kid = waitpid($pid, WNOHANG);
        $done++ if $kid == $pid || $kid == -1;
    }
    my $progress = 0;
    for my $w (0 .. $MAX_WORKERS - 1) {
        my $f = "$work_dir/worker_${w}.jsonl";
        next unless -f $f && -s $f;
        open my $cf, '<', $f or next;
        while (<$cf>) { $progress++; }
        close $cf;
    }
    printf "\r  Progress: %d/%d files processed", $progress, $total;
    sleep 1 if $done < $MAX_WORKERS;
}
print "\n\n";

# Collect and aggregate results
my %violation_counts;
my %violation_severity;
my %violation_example;

for my $w (0 .. $MAX_WORKERS - 1) {
    my $f = "$work_dir/worker_${w}.jsonl";
    next unless -f $f && -s $f;
    open my $wf, '<', $f or next;
    while (<$wf>) {
        chomp;
        my ($status, $name, $data) = split /\t/, $_, 3;
        next unless $status eq 'OK' && $data;
        my $violations = decode_json($data);
        next unless ref $violations eq 'ARRAY';
        for my $v (@$violations) {
            my $policy = $v->{policy};
            $violation_counts{$policy}++;
            # Track severity
            $violation_severity{$policy} = $v->{severity} unless exists $violation_severity{$policy};
            # Save first example
            $violation_example{$policy} = $v->{desc} unless exists $violation_example{$policy};
        }
    }
    close $wf;
}

# Clean up worker files
for my $w (0 .. $MAX_WORKERS - 1) {
    unlink "$work_dir/worker_${w}.jsonl";
}
rmdir $work_dir;

my $grand_total = 0;
$grand_total += $_ for values %violation_counts;

# ===========================================================================
# REPORT
# ===========================================================================
print "=" x 80, "\n";
print "VIOLATION REPORT (sorted by frequency)\n";
print "=" x 80, "\n";
printf "%-75s %6s %8s  %s\n", "Policy", "Sev", "Count", "Exempted?";
print "-" x 80, "\n";

my @sorted_policies = sort { $violation_counts{$b} <=> $violation_counts{$a} } keys %violation_counts;

foreach my $policy (@sorted_policies) {
    my $count = $violation_counts{$policy};
    my $sev = $violation_severity{$policy};
    my $is_exempted = exists $exempted_policies{$policy} ? "YES" : "no";
    # Also check if the short form of a long policy is exempted
    if (!$is_exempted) {
        # Check if policy without Perl::Critic::Policy:: prefix is exempted
        my $short = $policy;
        $short =~ s/^Perl::Critic::Policy:://;
        $is_exempted = exists $exempted_policies{$short} ? "YES (short)" : $is_exempted;
        # Check reverse
        my $long = "Perl::Critic::Policy::$policy";
        $is_exempted = exists $exempted_policies{$long} ? "YES (long)" : $is_exempted;
    }
    my $desc = $violation_example{$policy} // '';
    printf "%-75s %6s %8d  %s\n", $policy, $sev, $count, $is_exempted;
}

print "-" x 80, "\n";
printf "%-75s %6s %8d\n", "TOTAL", "", $grand_total;
print "-" x 80, "\n\n";

# ===========================================================================
# EXEMPTION ANALYSIS
# ===========================================================================
print "=" x 80, "\n";
print "EXEMPTION ANALYSIS\n";
print "=" x 80, "\n\n";

# Build a map that includes both short and long forms
my %all_violation_policies;
for my $p (keys %violation_counts) {
    $all_violation_policies{$p} = $violation_counts{$p};
    # Also map short form
    my $short = $p;
    $short =~ s/^Perl::Critic::Policy:://;
    $all_violation_policies{$short} = $violation_counts{$p} unless exists $all_violation_policies{$short};
}

print "--- Exempted policies that ARE needed (would fire without exemption) ---\n";
my $needed = 0;
foreach my $policy (sort keys %exempted_policies) {
    my $count = $all_violation_policies{$policy} || 0;
    if ($count > 0) {
        printf "  %-70s %d violations\n", $policy, $count;
        $needed++;
    }
}
if ($needed == 0) { print "  (none)\n"; }

print "\n--- Exempted policies that are NOT needed (no violations even without exemption) ---\n";
my $not_needed = 0;
foreach my $policy (sort keys %exempted_policies) {
    my $count = $all_violation_policies{$policy} || 0;
    if ($count == 0) {
        printf "  %-70s (0 violations across all files)\n", $policy;
        $not_needed++;
    }
}
if ($not_needed == 0) { print "  (none)\n"; }

printf "\n  Summary: %d needed, %d potentially unnecessary out of %d exempted policies\n", 
    $needed, $not_needed, scalar(keys %exempted_policies);

print "\n--- Non-exempted policies that DO have violations ---\n";
my $non_exempted = 0;
foreach my $policy (@sorted_policies) {
    my $is_exempted = 0;
    $is_exempted ||= exists $exempted_policies{$policy};
    my $short = $policy;
    $short =~ s/^Perl::Critic::Policy:://;
    $is_exempted ||= exists $exempted_policies{$short};
    my $long = "Perl::Critic::Policy::$policy";
    $is_exempted ||= exists $exempted_policies{$long};
    
    unless ($is_exempted) {
        printf "  %-70s %d violations (severity %s)\n", $policy, $violation_counts{$policy}, $violation_severity{$policy};
        $non_exempted++;
    }
}
if ($non_exempted == 0) { print "  (none)\n"; }

print "\n", "=" x 80, "\n";
print "SUMMARY\n";
print "=" x 80, "\n";
printf "Total sh/ files analyzed:    %d\n", $total;
printf "Total distinct policy types: %d\n", scalar(keys %violation_counts);
printf "Total violations found:      %d\n", $grand_total;
printf "Exempted policies (total):   %d\n", scalar(keys %exempted_policies);
printf "  - Needed (have violations): %d\n", $needed;
printf "  - Unnecessary (no viol's):  %d\n", $not_needed;
printf "Non-exempted violations:      %d policies\n", $non_exempted;
print "=" x 80, "\n";
