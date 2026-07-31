#!/usr/bin/env perl
# estree_gate.pl — structural gate for emitted ESTree (PLAN.md §2.2).
#
# Usage: perl estree_gate.pl <program.estree.json>
#
# Checks (deterministic, no execution):
#   (a) valid JSON, top-level Program
#   (b) every CallExpression callee is sh2.<name> with <name> in the whitelist
#   (c) no sh2.unsupported calls
#   (d) no redirect spec with mode "unsupported"
#   (e) no *Sync callees / eval / Function / dynamic import (covered by (b)
#       plus an explicit scan of member names)
#
# Exit 0 = PASS, 1 = FAIL. Prints PASS/FAIL + reason to stdout.
use strict;
use warnings;
use JSON::PP;

my %whitelist = map { $_ => 1 } qw(
    exec getVar setVar test pipeline capture captureWords redirect caseMatch param arith brace setArray setArrayAppend assign arrayItems arrayLen arrayIndex join setLastExit
    define subshell background block whileLoop cstyleFor forLoop listVar
    shopt return break continue unsupported
);

my $file = shift @ARGV or die "usage: estree_gate.pl <program.estree.json>\n";
open my $fh, '<', $file or die "open $file: $!";
my $content = do { local $/; <$fh> };
close $fh;

my $data = eval { JSON::PP::decode_json($content) };
if (!$data) {
    print "FAIL: invalid JSON: $@\n";
    exit 1;
}
if (ref $data ne 'HASH' || ($data->{type} // '') ne 'Program') {
    print "FAIL: not an ESTree Program\n";
    exit 1;
}

my @problems;

sub walk {
    my ($n) = @_;
    return unless defined $n;
    if (ref $n eq 'HASH') {
        my $type = $n->{type} // '';
        if ($type eq 'CallExpression') {
            my $callee = $n->{callee} // {};
            my $obj = $callee->{object} // {};
            my $prop = $callee->{property} // {};
            my $is_sh2 = ref $obj eq 'HASH'
                && ($obj->{type} // '') eq 'Identifier'
                && ($obj->{name} // '') eq 'sh2'
                && ref $prop eq 'HASH'
                && ($prop->{type} // '') eq 'Identifier';
            my $cname = ref $prop eq 'HASH' ? ($prop->{name} // '') : '';
            if (!$is_sh2) {
                push @problems, "non-sh2 callee: " . ($cname || $type);
            } elsif (!$whitelist{$cname}) {
                push @problems, "callee not in sh2.* whitelist: $cname";
            } elsif ($cname eq 'unsupported') {
                push @problems, "sh2.unsupported call present";
            }
        }
        if ($type eq 'MemberExpression') {
            my $prop = $n->{property} // {};
            my $pname = ref $prop eq 'HASH' ? ($prop->{name} // '') : '';
            if ($pname =~ /Sync$/) {
                push @problems, "*Sync callee: $pname";
            }
        }
        if ($type eq 'ObjectExpression') {
            for my $p (@{ $n->{properties} // [] }) {
                next unless ref $p eq 'HASH';
                my $key = $p->{key} // {};
                my $val = $p->{value} // {};
                if (($key->{name} // '') eq 'mode'
                    && ref $val eq 'HASH'
                    && ($val->{value} // '') eq 'unsupported') {
                    push @problems, "redirect spec mode=unsupported";
                }
            }
        }
        for my $v (values %$n) { walk($v); }
    } elsif (ref $n eq 'ARRAY') {
        walk($_) for @$n;
    }
}

walk($data);

if (@problems) {
    my %seen;
    my @uniq = grep { !$seen{$_}++ } @problems;
    print "FAIL: ", join('; ', @uniq), "\n";
    exit 1;
}
print "PASS\n";
exit 0;
