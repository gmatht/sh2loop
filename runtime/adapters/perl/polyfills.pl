#!/usr/bin/perl
# adapters/perl/polyfills.pl — the Perl backend's thin adapter for the
# C polyfills. Loads libsh2poly.so via FFI::Platypus and maps the sh2.*
# call-site convention to sh2poly_dispatch.
#
# Run:   perl polyfills.pl   (reads adapters/battery.txt)
#
# The battery runner: reads battery.txt (TAB-separated fields, `\\` →
# backslash, `\n` → newline), sets up the deterministic stdin,
# dispatches every call, prints `== name` / `status=N`.
use strict;
use warnings;
use FFI::Platypus;
use FindBin;

$| = 1;  # unbuffered stdout: the C polyfills write to fd 1 directly

my $ffi = FFI::Platypus->new;
$ffi->lib("$FindBin::Bin/../../libsh2poly.so");
$ffi->attach(sh2poly_init => [] => 'void');
$ffi->attach(sh2poly_dispatch => ['int', 'string[]'] => 'int');
$ffi->attach(dup2 => ['int', 'int'] => 'int');

sh2poly_init();

# deterministic stdin for the read/readarray calls
open(my $in, '>', '/tmp/sh2poly_selftest_in.txt') or die $!;
print {$in} "alpha beta gamma\none\ntwo\nthree\n";
close $in;
open(my $inr, '<', '/tmp/sh2poly_selftest_in.txt') or die $!;
dup2(fileno($inr), 0);

my $bat;
open($bat, '<', 'adapters/battery.txt') or open($bat, '<', 'battery.txt') or die $!;
while (my $line = <$bat>) {
    chomp $line;
    $line =~ s/^\s+|\s+$//g;
    next if $line eq '' || $line =~ /^#/;
    my @fields = split /\t/, $line;
    my $name = shift @fields;
    my @args = map { unescape($_) } @fields;
    print "== $name\n";
    my $st = sh2poly_dispatch(scalar(@args) + 1, [$name, @args]);
    print "status=$st\n";
}

sub unescape {
    my ($s) = @_;
    $s =~ s/\\\\/\\/g;   # \\ -> backslash
    $s =~ s/\\n/\n/g;    # \n -> newline
    $s =~ s/\\t/\t/g;    # \t -> tab
    return $s;
}
