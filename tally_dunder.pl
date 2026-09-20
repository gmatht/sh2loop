#!/usr/bin/env perl
# tally_dunder.pl — corpus-wide `__` tally over the Rust backend output.
# Renders every sh2perl/examples/*.sh through otranspilerl-cli --target rust
# and counts `__` occurrences per file. Usage:
#   perl tally_dunder.pl [--top N] [--out tally.tsv]
# Output: total files, total __, mean, and the top-N ranking.
use strict;
use warnings;
use File::Basename qw(dirname);
use Cwd qw(abs_path);

my $root = dirname(abs_path($0));
my $cli  = "$root/otranspilerl/target/debug/otranspilerl-cli";
my $dir  = "$root/sh2perl/examples";
my ($top, $out) = (20, undef);
for (my $i = 0; $i < @ARGV; $i++) {
    $top = $ARGV[$i+1] if $ARGV[$i] eq '--top';
    $out = $ARGV[$i+1] if $ARGV[$i] eq '--out';
}
die "no CLI at $cli (build it first)\n" unless -x $cli;
my @files = sort glob "$dir/*.sh";
my (@rows, $total, $ok);
$total = 0; $ok = 0;
for my $f (@files) {
    my $name = (split '/', $f)[-1];
    my $rs = `"$cli" --target rust "$f" 2>/dev/null`;
    unless ($rs ne '') { push @rows, [$name, 'RENDER-FAIL', 0]; next; }
    my $n = () = $rs =~ /__/g;
    $total += $n; $ok++;
    push @rows, [$name, $n, length($rs)];
}
@rows = sort { ($b->[1] =~ /^\d+$/ ? $b->[1] : -1) <=> ($a->[1] =~ /^\d+$/ ? $a->[1] : -1) } @rows;
printf "files=%d rendered=%d total__=%d mean=%.1f\n", scalar(@files), $ok, $total, $ok ? $total/$ok : 0;
printf "%-55s %8s %8s\n", "FILE", "__", "BYTES";
for my $i (0 .. $top-1) {
    last if $i > $#rows;
    printf "%-55s %8s %8s\n", $rows[$i][0], $rows[$i][1], $rows[$i][2];
}
if (defined $out) {
    open my $fh, '>', $out or die $!;
    print $fh join("\t", @$_) . "\n" for @rows;
    close $fh;
    print "wrote $out\n";
}
