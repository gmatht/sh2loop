#!/usr/bin/env perl
# sh2stat.pl — count sh2.* calls (total, in-loop, *Sync) in a generated
# program JSON. Loop bodies = the arrow arguments of *Loop calls.
use strict; use warnings; use JSON::PP;
my $f = shift or die "usage: sh2stat.pl program.json\n";
open my $fh, '<', $f or die "open $f: $!";
local $/; my $json = <$fh>; close $fh;
my $data = eval { JSON::PP::decode_json($json) };
if (!$data) { print "0\t0\t0\n"; exit; }
my ($tot, $iloop, $sync) = (0, 0, 0);
my $walk;
$walk = sub {
    my ($node, $in_loop) = @_;
    if (ref $node eq 'ARRAY') { $walk->($_, $in_loop) for @$node; return; }
    return unless ref $node eq 'HASH';
    if (($node->{type} // '') eq 'CallExpression') {
        my $c = $node->{callee};
        if (ref $c eq 'HASH' && ($c->{object}{name} // '') eq 'sh2') {
            my $n = $c->{property}{name} // '';
            $tot++; $iloop++ if $in_loop; $sync++ if $n =~ /Sync$/;
            if ($n =~ /Loop$/) {
                for my $a (@{$node->{arguments} // []}) {
                    my $inb = (ref $a eq 'HASH' && ($a->{type} // '') eq 'ArrowFunctionExpression') ? 1 : $in_loop;
                    $walk->($a, $inb);
                }
                return;
            }
        }
    }
    $walk->($_, $in_loop) for values %$node;
};
$walk->($data, 0);
print "$tot\t$iloop\t$sync\n";
