#!/usr/bin/perl
# core-requests-queue.pl — the escalations queue, with an age/priority view
# and a WIP cap.
#
# WHY (measured 2026-11-11): 2,178 unprocessed requests, 872 more in
# stalled/, 4,077 done, 0 rejected. Nothing reads the backlog, so workers
# file and nobody implements: PLAN §11's offers/accepts marketplace is
# one-directional. A queue you cannot see is a sink.
#
#   ./core-requests-queue.pl            report: totals, age buckets, per-lang,
#                                       repeat classes, highest-priority rows
#   ./core-requests-queue.pl --top 20   more rows
#   ./core-requests-queue.pl --admit    exit 4 when open > cap — filing paths
#                                       call this BEFORE writing a request
#   SH2_CORE_WIP_CAP (default 8)        the cap --admit enforces
#
# Age comes from the `YYYYMMDD-HHMMSS` stamp in the filename, never the mtime:
# a copy or a checkout rewrites mtimes and would make the whole queue look
# new. mtime is only a fallback for a name with no stamp.
#
# Priority = age_days x class_size, where a class is the request topic with
# the language and timestamp stripped. That ranks "the same ask, re-filed
# five times, oldest three weeks ago" above a fresh one-off, which is the
# signal that the queue is being used as a dumping ground.
use strict;
use warnings;
use Time::Local qw(timelocal);

my $root = $ENV{SH2_ROOT};
if (!defined $root) {
    require Cwd;
    $root = Cwd::abs_path($0) // $0;
    $root =~ s{/harness/[^/]+$}{};
}
my $cap   = $ENV{SH2_CORE_WIP_CAP} // 8;
my $top   = 10;
my $admit = 0;
while (@ARGV) {
    my $a = shift @ARGV;
    if    ($a eq '--admit') { $admit = 1 }
    elsif ($a eq '--top')   { $top = shift(@ARGV) // 10 }
    elsif ($a eq '--cap')   { $cap = shift(@ARGV) // 8 }
    elsif ($a eq '-h' || $a eq '--help') {
        print "usage: $0 [--admit] [--top N] [--cap N]\n";
        exit 0;
    }
    else { die "core-requests-queue.pl: unknown argument '$a'\n" }
}

my $dir = "$root/core-requests";
-d $dir or die "core-requests-queue.pl: no $dir\n";

my $now = time;

sub basename { my $p = shift; $p =~ s{.*/}{}; return $p }

my @paths = (glob("$dir/*.md"), glob("$dir/*.md.stall"), glob("$dir/stalled/*"));
@paths = grep { !m{/(README\.md|stalled-needs\.tsv|janitor-verdicts\.tsv)$} } @paths;

# A top-level .stall and its copy under stalled/ are ONE request.
my %seen;
@paths = grep { my $k = basename($_); $k =~ s/\.stall$//; !$seen{$k}++ } @paths;

my $done     =()= glob("$dir/done/*");
my $rejected =()= glob("$dir/rejected/*");
my $open     = scalar @paths;

if ($admit) {
    if ($open > $cap) {
        print STDERR "core-requests: $open open > cap $cap — do NOT file another.\n";
        print STDERR "  Triage the oldest first: $0 --top 5\n";
        print STDERR "  Raise the cap deliberately with SH2_CORE_WIP_CAP=N if this\n";
        print STDERR "  request is genuinely more urgent than the backlog.\n";
        exit 4;
    }
    print "core-requests: $open open (cap $cap) — admitted\n";
    exit 0;
}

sub age_days {
    my $path = shift;
    my $name = basename($path);
    if ($name =~ /(20\d\d)(\d\d)(\d\d)-(\d\d)(\d\d)(\d\d)/) {
        my ($Y, $M, $D, $h, $m, $s) = ($1, $2, $3, $4, $5, $6);
        my $t = eval { timelocal($s, $m, $h, $D, $M - 1, $Y) };
        return (($now - $t) / 86400) if defined $t && $t > 0;
    }
    my $age = -M $path;
    return defined $age ? $age : 0;
}

sub lang_of {
    my $name = basename(shift);
    return 'other' unless $name =~ /^(?:triage-)?([a-z]+)/;
    my $l = $1;
    return 'rust' if $l eq 'rust';
    return 'py'   if $l eq 'python';
    return $l;
}

sub topic_of {
    my $name = basename(shift);
    my $lang = lang_of($name);
    $name =~ s/\.md(\.stall)?$//;
    $name =~ s/^(?:triage-)?[a-z]+-//;   # language prefix, if any
    $name =~ s/-?\d{8}-\d{6}//g;        # timestamp
    $name =~ s/^-+//;
    return '(untitled)' if $name eq '' || $name eq $lang;
    return $name;
}

my (@rows, %class, %lang);
for my $p (@paths) {
    my $d = age_days($p);
    my $t = topic_of($p);
    my $l = lang_of($p);
    push @rows, { path => $p, days => $d, topic => $t, lang => $l };
    $class{$t}++;
    $lang{$l}++;
}

my %bucket = ('<1d' => 0, '1-7d' => 0, '7-30d' => 0, '>30d' => 0);
for my $r (@rows) {
    my $d = $r->{days};
    my $cz = ($r->{topic} eq '(untitled)') ? 1 : $class{ $r->{topic} };
    $r->{priority} = int($d * $cz);
    if    ($d < 1)   { $bucket{'<1d'}++ }
    elsif ($d < 7)   { $bucket{'1-7d'}++ }
    elsif ($d < 30)  { $bucket{'7-30d'}++ }
    else             { $bucket{'>30d'}++ }
}

printf "core-requests: %d open, %d done, %d rejected\n", $open, $done, $rejected;
printf "age: <1d %d | 1-7d %d | 7-30d %d | >30d %d\n",
    @bucket{'<1d', '1-7d', '7-30d', '>30d'};

print "per-lang: ";
print join(' ', map { "$_=$lang{$_}" } sort { $lang{$b} <=> $lang{$a} } keys %lang);
print "\n";

my @repeat = sort { $class{$b} <=> $class{$a} }
             grep { $class{$_} >= 3 && $_ ne '(untitled)' } keys %class;
if (@repeat) {
    print "repeat classes (the same ask, filed N times):\n";
    for my $t (@repeat[0 .. ($#repeat > 5 ? 5 : $#repeat)]) {
        printf "  %3d x %s\n", $class{$t}, substr($t, 0, 72);
    }
}

print "highest priority (age_days x class_size), top $top:\n";
my @ranked = sort { $b->{priority} <=> $a->{priority} || $b->{days} <=> $a->{days} } @rows;
for my $r (@ranked[0 .. ($#ranked > $top - 1 ? $top - 1 : $#ranked)]) {
    printf "  %6.1fd  p%-5d %-7s %s\n",
        $r->{days}, $r->{priority}, $r->{lang}, substr(basename($r->{path}), 0, 78);
}

my $cap_hit = $open > $cap ? "OVER CAP ($cap)" : "within cap ($cap)";
print "WIP: $cap_hit — a filing path must call --admit before writing.\n";
exit 0;
