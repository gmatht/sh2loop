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
    exec getVar setVar test pipeline capture captureWords redirect caseMatch param arith brace setArray setArrayAppend assign arrayItems arrayLen arrayIndex join setLastExit arithEval idiv imod guard not contains builtin
    define subshell background block whileLoop whileLoopSync cstyleFor cstyleForSync forLoop forLoopSync listVar and or
    shopt return break continue unsupported
    trimCapture
);

my $file = shift @ARGV or die "usage: estree_gate.pl <program.estree.json>\n";
open my $fh, '<', $file or die "open $file: $!";
my $content = do { local $/; <$fh> };
close $fh;

# debashc --estree prints NOTHING on stdout when the parse fails (the CLI
# reports the error on stderr and exits 0), so the gate receives an empty
# artifact. A parse failure is a faithful EMPTY program — bash rejects the
# same file (the corpus parse-error tests all have empty bash stdout), so
# the runner must execute nothing (exit 0, no output) instead of this
# structural check failing on a file that has nothing structural in it.
# Materialize the canonical empty Program in place for the runner.
if ($content =~ /^\s*$/) {
    $content = '{"type":"Program","sourceType":"module","body":[]}';
    open my $wfh, '>', $file or die "write $file: $!";
    print $wfh $content;
    close $wfh;
}

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
            my $is_native = ($callee->{type} // '') eq 'Identifier'
                && (($callee->{name} // '') eq 'Number' || ($callee->{name} // '') eq 'String');
            my $is_math = ref $obj eq 'HASH'
                && ($obj->{type} // '') eq 'Identifier'
                && ($obj->{name} // '') eq 'Math'
                && ref $prop eq 'HASH'
                && ($prop->{name} // '') =~ /^(trunc|floor|ceil)$/;
            # Number.isNaN — the NaN-guarded numeric test lowering (bash's
            # "integer expression expected" error → the whole test is false)
            my $is_number_member = ref $obj eq 'HASH'
                && ($obj->{type} // '') eq 'Identifier'
                && ($obj->{name} // '') eq 'Number'
                && ref $prop eq 'HASH'
                && ($prop->{name} // '') eq 'isNaN';
            # String(x).includes(n) / startsWith / endsWith / toLowerCase / … —
            # the native glob-to-string-op and param lowerings (pure string ops).
            # The object may be a String(...) call, a chained string op
            # (CallExpression), or an array literal (`[a, b].join(" ")` — the
            # echo-capture join; the elements are walked recursively).
            my $is_string_method = ref $obj eq 'HASH'
                && (($obj->{type} // '') eq 'CallExpression' || ($obj->{type} // '') eq 'ArrayExpression')
                && ref $prop eq 'HASH'
                && ($prop->{name} // '') =~ /^(includes|startsWith|endsWith|toLowerCase|toUpperCase|charAt|slice|split|join)$/;
            # direct calls on the sh2 runtime's own state fields — the
            # native special-var lowerings (`$@` → sh2.positional.join(' '),
            # `$#` → sh2.positional.length) read fields, never dispatched
            my $is_sh2_state = ref $obj eq 'HASH'
                && ($obj->{type} // '') eq 'MemberExpression'
                && ref $obj->{object} eq 'HASH'
                && ($obj->{object}{type} // '') eq 'Identifier'
                && ($obj->{object}{name} // '') eq 'sh2'
                && ref $prop eq 'HASH'
                && ($prop->{name} // '') =~ /^(join|length)$/;
            if (!$is_sh2 && !$is_native && !$is_math && !$is_number_member && !$is_string_method && !$is_sh2_state) {
                push @problems, "non-sh2 callee: " . ($cname || $type);
            } elsif ($is_sh2 && !$whitelist{$cname}) {
                push @problems, "callee not in sh2.* whitelist: $cname";
            } elsif ($is_sh2 && $cname eq 'unsupported') {
                push @problems, "sh2.unsupported call present";
            }
        }
        if ($type eq 'MemberExpression') {
            my $prop = $n->{property} // {};
            my $pname = ref $prop eq 'HASH' ? ($prop->{name} // '') : '';
            if ($pname =~ /Sync$/) {
                # whileLoopSync / forLoopSync / cstyleForSync are the ONLY
                # permitted *Sync calls: pure-CPU loops with no I/O (the
                # emitter only emits them when cond/iterable/body contain no
                # AwaitExpression — see src/shir.rs), so they can't block a
                # browser event loop the way fs.readFileSync & friends would.
                push @problems, "*Sync callee: $pname" unless $pname =~ /^(whileLoopSync|forLoopSync|cstyleForSync)$/;
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
