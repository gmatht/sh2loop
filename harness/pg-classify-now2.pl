#!/usr/bin/env perl
# Classify the 57 perl-generator corpus failures by their FIRST diff hunk, so
# the work can be prioritised by cluster size instead of by list order.
#
# Reads example names on argv (or the ones in .pg-triage-fails.txt), and for
# each prints:  <name>\t<CLASS>\t<bash_bytes>\t<perl_bytes>\t<first diff line>
use strict;
use warnings;

my $root = $ENV{SH2_ROOT} // do { require Cwd; my $s = $0; $s =~ s{/[^/]+$}{}; Cwd::abs_path("$s/..") };
my $cli  = "$root/otranspilerl/target/debug/otranspilerl-cli";
my $cap  = "$root/harness/cap-capture.pl";

$ENV{SH2_UU_LIB}         = "$root/sh2perl/runtime/lib/libcoreutils_ffi.so";
$ENV{SH2_UU_PIPELINE_LIB} = "$root/sh2perl/runtime/lib/libcoreutils_ffi_pipeline.so";
$ENV{UU_FFI_MULTICALL}   = "$root/sh2perl/runtime/lib/coreutils-ffi-multicall";

my @names = @ARGV;
if (!@names) {
    open my $fh, '<', "$root/.pg-triage-fails.txt" or die $!;
    @names = <$fh>; close $fh; chomp @names;
}
@names = grep { length } @names;

my %class;
my $pass = 0;
for my $n (@names) {
    my $ex = "$root/sh2perl/examples/$n";
    if (!-f $ex) { print "$n\tMISSING\n"; next; }
    my $d = "/tmp/pgcls.$$.$n";
    system("rm -rf $d; mkdir -p $d");
    my $pl = "$d/test.pl";
    system("timeout 60 sh -c '\"$cli\" --target pl \"$ex\" 2>/dev/null' > $pl");
    if (!-s $pl) { print "$n\tNO-GENERATED\n"; system("rm -rf $d"); next; }

    system("bash $ex > $d/bash.out 2>/dev/null");
    system("timeout 60 perl -M5.010 -e '\$0 = shift \@ARGV; my \$__f = shift \@ARGV; do \$__f' "
         . "$ex $pl > $d/perl.out 2>$d/perl.err");

    my $bo = slurp("$d/bash.out");
    my $po = slurp("$d/perl.out");
    if ($bo eq $po) { $pass++; print "$n\tPASS-NOW\n"; system("rm -rf $d"); next; }

    # The error the Perl run died with is a far better class label than the
    # first diff line when the program never produced anything.
    my ($first, $cls);
    if (length($po) == 0) {
        my $err = slurp("$d/perl.err");
        ($err) = $err =~ /(Can't exec "[^"]+"|syntax error.*|Global symbol.*|Bareword.*|uninitialized.*|Odd number.*|not allowed.*)/s;
        $cls = 'EMPTY:' . ($err // 'no-stderr');
        $first = '(no perl output)';
    } else {
        my @b = split /\n/, $bo;
        my @p = split /\n/, $po;
        for my $i (0 .. $#b) {
            my $bb = defined $b[$i] ? $b[$i] : '';
            my $pp = defined $p[$i] ? $p[$i] : '<MISSING>';
            if ($bb ne $pp) { $first = "bash: $bb || perl: $pp"; last; }
        }
        $first //= '(length-only difference)';
        $cls = $b[0] && $p[0] ? 'DIFF' : 'SHAPE';
    }
    $class{$cls}++;
    printf "%s\t%s\t%d\t%d\t%s\n", $n, $cls, length($bo), length($po), $first;
    system("rm -rf $d");
}
print STDERR "\n=== passing: $pass / ".scalar(@names)." ===\n";
print STDERR "=== classes ===\n";
printf STDERR "%4d  %s\n", $class{$_}, $_ for sort { $class{$b} <=> $class{$a} || $a cmp $b } keys %class;

sub slurp { my $f = shift; open my $h, '<', $f or return ''; local $/; my $c = <$h>; close $h; $c // '' }
