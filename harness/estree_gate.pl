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
    exec getVar setVar test pipeline capture captureWords redirect caseMatch param arith brace setArray setArrayAppend assign arrayItems arrayLen arrayIndex join setLastExit arithEval idiv imod guard not contains builtin grepText grepMatches cutText bcSqrt fileTest fnCall fnValue callDirect callUndefined
    define subshell background block whileLoop whileLoopSync whileLoopBatch cstyleFor cstyleForSync forLoop forLoopSync forLoopBatch listVar and or
    subshellSync blockSync captureSync captureWordsSync pipelineSync redirectSync
    shopt return break continue unsupported
    pipelineInputLines
    trimCapture dirname basename uname date readlink hostname whoami mktempValue split readFile writeFile appendFile lstat access unlink rm mkdir mkdtemp addrOf memLoad memStore
    memAlloc memFree ternary arrayStore memAdvance memTest line
    assocSet assocGet assocNames assocValues
);

my $file = shift @ARGV or die "usage: estree_gate.pl <program.estree.json>\n";
open my $fh, '<', $file or die "open $file: $!";
my $content = do { local $/; <$fh> };
close $fh;

# debashc --estree prints NOTHING on stdout when the parse fails (the CLI
# reports the error on stderr and exits 0), so the gate receives an empty
# artifact. Every corpus file that reaches this path is REJECTED by bash
# too (syntax error: bash exit 2, no stdout), so the faithful artifact is
# an exit-2 program — the runner then matches bash's verdict (before this,
# the empty Program exited 0: "exit code (bash=2 estree=0)" failures).
# The CLI now emits this fallback itself; this materialization covers
# other producers of empty artifacts (older binaries, --shir-in-estree
# ingest of an empty file).
if ($content =~ /^\s*$/) {
    $content = '{"type":"Program","sourceType":"module","body":[{"type":"ExpressionStatement","expression":{"type":"CallExpression","callee":{"type":"MemberExpression","object":{"type":"Identifier","name":"process"},"property":{"type":"Identifier","name":"exit"},"computed":false,"optional":false},"arguments":[{"type":"Literal","value":2,"raw":"2"}],"optional":false}}]}';
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

# Module-level `let f = ...` declarations whose init is an arrow — the
# native-direct function bindings. Identifier callees with one of these
# names are the direct calls (`sh2.callDirect(f, ...)`); collecting the
# declared names keeps the gate strict about everything else.
my %native_fn_bindings;
my %promise_params;
for my $s (@{ $data->{body} // [] }) {
    next unless ref $s eq 'HASH' && ($s->{type} // '') eq 'VariableDeclaration';
    for my $d (@{ $s->{declarations} // [] }) {
        next unless ref $d eq 'HASH';
        my $id = $d->{id} // {};
        my $init = $d->{init} // {};
        if ((($id->{type} // '') eq 'Identifier')
            && (($init->{type} // '') eq 'ArrowFunctionExpression')) {
            $native_fn_bindings{ $id->{name} // '' } = 1;
        }
        # the native-DIRECT bindings (`let __fn_f = null;` — reassigned to
        # the arrow at the define; called BARE from statement positions
        # with a dead status write, src/shir.rs BARE_FN_CALLS)
        if ((($id->{type} // '') eq 'Identifier')
            && (($id->{name} // '') =~ /^__fn_/)
            && (($init->{type} // '') eq 'Literal' && !defined $init->{value})) {
            $native_fn_bindings{ $id->{name} // '' } = 1;
        }
    }
}

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
            # sh2.fs.<name> — the runtime's node:fs/promises surface for
            # the pure-capture lowerings (`$(cat f)` → sh2.fs.readFile),
            # the native echo-to-file redirect lowering (`echo x > f` →
            # await sh2.fs.writeFile / appendFile). File TESTS
            # (`[ -f x ]`) now lower to the sync `sh2.fileTest(flag,
            # path)` runtime helper (the async lstat/access chains were
            # the last await in otherwise-sync loop bodies).
            # Async-only codegen.
            my $is_sh2_fs = ref $obj eq 'HASH'
                && ($obj->{type} // '') eq 'MemberExpression'
                && ref $obj->{object} eq 'HASH'
                && ($obj->{object}{type} // '') eq 'Identifier'
                && ($obj->{object}{name} // '') eq 'sh2'
                && ref $obj->{property} eq 'HASH'
                && ($obj->{property}{name} // '') eq 'fs'
                && ref $prop eq 'HASH'
                && ($prop->{type} // '') eq 'Identifier'
                && $prop->{name} =~ /^(readFile|writeFile|appendFile|lstat|access|unlink|rm|mkdir|mkdtemp)$/;
            my $is_native = ($callee->{type} // '') eq 'Identifier'
                && (($callee->{name} // '') eq 'Number' || ($callee->{name} // '') eq 'String'
                    || ($callee->{name} // '') eq 'parseInt' || ($callee->{name} // '') eq 'parseFloat'
                    || ($callee->{name} // '') eq 'Promise'
                    # the native sleep lowering (`sleep 1` →
                    # `await new Promise(r => setTimeout(() => r(true), 1000))`,
                    # src/shir.rs try_native_sleep): setTimeout is the timer
                    # builtin; the resolver param `r` (collected from the
                    # NewExpression executor below) is called with `true` so
                    # the awaited statement's value is truthy for the
                    # errexit guard.
                    || ($callee->{name} // '') eq 'setTimeout'
                    || $promise_params{ $callee->{name} // '' }
                    # the native-direct function bindings (src/shir.rs
                    # NATIVE_DIRECT_FNS): module-level `let f = (...args)
                    # => ...` declarations called directly from
                    # `sh2.callDirect(f, ...)` — the callee name must be one
                    # of those declared bindings (collected below)
                    || $native_fn_bindings{ $callee->{name} // '' });
            my $is_math = ref $obj eq 'HASH'
                && ($obj->{type} // '') eq 'Identifier'
                && ($obj->{name} // '') eq 'Math'
                && ref $prop eq 'HASH'
                # sqrt — the native bc capture lowering (`$(echo "sqrt($n)" |
                # bc)` → String(Math.floor(Math.sqrt(Number(n)))), Plan 8)
                # max — the native `${x##*[/\\]}` class-core strip (max of
                # per-char lastIndexOf, src/shir.rs glob_class_chars)
                && ($prop->{name} // '') =~ /^(trunc|floor|ceil|sqrt|max)$/;
            # Number.isNaN — the NaN-guarded numeric test lowering (bash's
            # "integer expression expected" error → the whole test is false)
            my $is_number_member = ref $obj eq 'HASH'
                && ($obj->{type} // '') eq 'Identifier'
                && ($obj->{name} // '') eq 'Number'
                && ref $prop eq 'HASH'
                && ($prop->{name} // '') eq 'isNaN';
            # Array.isArray — the native sh2.join lowering (the runtime
            # helper's exact `Array.isArray(v) ? v.join(" ") : String(v)`)
            my $is_array_member = ref $obj eq 'HASH'
                && ($obj->{type} // '') eq 'Identifier'
                && ($obj->{name} // '') eq 'Array'
                && ref $prop eq 'HASH'
                && ($prop->{name} // '') eq 'isArray';
            # Promise.all — the native rm/mkdir fs-command lift's status
            # aggregation (`Promise.all([per-path results]).then(...)`)
            my $is_promise_member = ref $obj eq 'HASH'
                && ($obj->{type} // '') eq 'Identifier'
                && ($obj->{name} // '') eq 'Promise'
                && ref $prop eq 'HASH'
                && ($prop->{name} // '') eq 'all';
            # String(x).includes(n) / startsWith / endsWith / toLowerCase / … —
            # the native glob-to-string-op and param lowerings (pure string ops).
            # The object may be a String(...) call, a chained string op
            # (CallExpression), an array literal (`[a, b].join(" ")` — the
            # echo-capture join; the elements are walked recursively), a
            # BinaryExpression (`[a, b].join(" ") + "\n"` — the echo|wc text),
            # a regex Literal (the wc -w split), a plain string Literal, or an
            # Identifier — the native fs-command lift's own arrow params
            # (`Promise.all([...]).then(s => s.includes(1) ? …)` — the status
            # aggregation over per-path results).
            my $is_string_method = ref $obj eq 'HASH'
                && (($obj->{type} // '') eq 'CallExpression' || ($obj->{type} // '') eq 'ArrayExpression'
                    || ($obj->{type} // '') eq 'AwaitExpression' || ($obj->{type} // '') eq 'ConditionalExpression'
                    || ($obj->{type} // '') eq 'BinaryExpression' || ($obj->{type} // '') eq 'Literal'
                    || ($obj->{type} // '') eq 'Identifier')
                && ref $prop eq 'HASH'
                && ($prop->{name} // '') =~ /^(includes|startsWith|endsWith|toLowerCase|toUpperCase|charAt|slice|split|join|flat|sort|then|catch|trim|replace|replaceAll|lastIndexOf|concat|filter|map|indexOf|test|exec|repeat)$/;
            # Buffer.byteLength(text, 'utf8') — the native wc -c byte-count
            # lowering (the runtime wc's exact formula; node global)
            my $is_buffer = ref $obj eq 'HASH'
                && ($obj->{type} // '') eq 'Identifier'
                && ($obj->{name} // '') eq 'Buffer'
                && ref $prop eq 'HASH'
                && ($prop->{name} // '') eq 'byteLength';
            # an IIFE callee — the state-free subshell fold (src/shir.rs
            # subshell_body_state_free): the sync arrow runs the body the
            # subshellSync twin would run, without the state copy/restore.
            # The arrow's body is part of the same tree, so every call
            # inside it is still checked below; the fold only fires for
            # await-free bodies, so the IIFE is pure-CPU (the *Sync rule).
            my $is_iife = ref $callee eq 'HASH'
                && ($callee->{type} // '') eq 'ArrowFunctionExpression';
            # direct calls on the sh2 runtime's own state fields — the
            # native special-var lowerings (`$@` → sh2.positional.join(' '),
            # `$#` → sh2.positional.length, `${@:1}` →
            # sh2.positional.slice(...)) read fields, never dispatched; the
            # native define/shopt lowerings call the state MAPS directly
            # (`sh2.functions.set(name, fn)`, `sh2.shoptState.set(opt, en)`)
            # — the runtime helpers' exact bodies, no dispatch
            my $is_sh2_state = ref $obj eq 'HASH'
                && ($obj->{type} // '') eq 'MemberExpression'
                && ref $obj->{object} eq 'HASH'
                && ($obj->{object}{type} // '') eq 'Identifier'
                && ($obj->{object}{name} // '') eq 'sh2'
                && ref $prop eq 'HASH'
                && (($prop->{name} // '') =~ /^(join|length|slice|concat)$/
                    # `sh2.functions.set(name, fn)` / `sh2.shoptState.set(opt, en)`
                    # — the state-MAP `.set` calls (the inner member is the
                    # map; the outer prop is `set`)
                    || (($prop->{name} // '') eq 'set'
                        && ref $obj->{property} eq 'HASH'
                        && ($obj->{property}{name} // '') =~ /^(functions|shoptState)$/)
                    # `sh2.exported.add(name)` — the native export lowering
                    # (the runtime builtin's exported-set write; the outer
                    # prop is `add`); `sh2.assocNames.add(name)` — the bare
                    # `declare -A map` lowering (the assoc-name registration)
                    || (($prop->{name} // '') eq 'add'
                        && ref $obj->{property} eq 'HASH'
                        && ($obj->{property}{name} // '') =~ /^(exported|assocNames)$/));
            # process.stdout.write — the native echo lowering (src/shir.rs
            # try_native_echo): a direct module-stdout write, no dispatch
            my $is_stdout_write = ref $obj eq 'HASH'
                && ($obj->{type} // '') eq 'MemberExpression'
                && ref $obj->{object} eq 'HASH'
                && ($obj->{object}{type} // '') eq 'Identifier'
                && ($obj->{object}{name} // '') eq 'process'
                && ref $obj->{property} eq 'HASH'
                && ($obj->{property}{name} // '') eq 'stdout'
                && ref $prop eq 'HASH'
                && ($prop->{name} // '') eq 'write';
            # process.stderr.write — the native ${x:?msg} param-error
            # lowering (mirrors the runtime's param `:?` direct stderr
            # write byte-for-byte)
            my $is_stderr_write = ref $obj eq 'HASH'
                && ($obj->{type} // '') eq 'MemberExpression'
                && ref $obj->{object} eq 'HASH'
                && ($obj->{object}{type} // '') eq 'Identifier'
                && ($obj->{object}{name} // '') eq 'process'
                && ref $obj->{property} eq 'HASH'
                && ($obj->{property}{name} // '') eq 'stderr'
                && ref $prop eq 'HASH'
                && ($prop->{name} // '') eq 'write';
            # process.getuid() / process.getgid() / process.chdir() /
            # process.exit() — the native -O/-G file-test lowering (the
            # runtime's evalUnary reads the same process ids), the native
            # `cd /` lowering, and the native `exit` lowering
            my $is_process_member = ref $obj eq 'HASH'
                && ($obj->{type} // '') eq 'Identifier'
                && ($obj->{name} // '') eq 'process'
                && ref $prop eq 'HASH'
                && ($prop->{name} // '') =~ /^(getuid|getgid|chdir|exit)$/;
            if (!$is_sh2 && !$is_sh2_fs && !$is_native && !$is_math && !$is_number_member && !$is_array_member && !$is_promise_member && !$is_string_method && !$is_sh2_state && !$is_stdout_write && !$is_stderr_write && !$is_buffer && !$is_process_member && !$is_iife) {
                push @problems, "non-sh2 callee: " . ($cname || $type);
            } elsif (($is_sh2 || $is_sh2_fs) && !$whitelist{$cname}) {
                push @problems, "callee not in sh2.* whitelist: $cname";
            } elsif ($is_sh2 && $cname eq 'unsupported') {
                push @problems, "sh2.unsupported call present";
            }
        }
        if ($type eq 'MemberExpression') {
            my $prop = $n->{property} // {};
            my $pname = ref $prop eq 'HASH' ? ($prop->{name} // '') : '';
            if ($pname =~ /Sync$/) {
                # The *Sync family: pure-CPU wrappers with no I/O — the
                # emitter only emits them when every lowered arg contains no
                # AwaitExpression (capture/pipeline/subshell/redirect/block
                # bodies, loop cond/body — see src/shir.rs SYNC_TWIN_CALLS),
                # so they can't block a browser event loop the way
                # fs.readFileSync & friends would. Same rule as the *Sync
                # loops (whileLoopSync / forLoopSync / cstyleForSync).
                push @problems, "*Sync callee: $pname"
                    unless $pname =~ /^(whileLoopSync|forLoopSync|cstyleForSync|captureSync|captureWordsSync|pipelineSync|subshellSync|redirectSync|blockSync)$/;
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
        if ($type eq 'NewExpression') {
            # `new Promise(r => …)` — the native sleep lowering: collect
            # the executor arrow's params into the promise-param set so
            # the resolver calls (`r(true)`) pass the callee check. The
            # set is program-global (a same-named stray call can only be
            # accepted in a program that already contains the executor).
            my $callee = $n->{callee} // {};
            if (($callee->{type} // '') eq 'Identifier' && ($callee->{name} // '') eq 'Promise') {
                my $exec = $n->{arguments}[0] // {};
                if (($exec->{type} // '') eq 'ArrowFunctionExpression') {
                    for my $p (@{ $exec->{params} // [] }) {
                        $promise_params{ $p->{name} // '' } = 1 if ref $p eq 'HASH';
                    }
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
