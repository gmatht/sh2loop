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
    exec getVar setVar test pipeline capture captureWords fieldSplit mktemp redirect caseMatch globMatch param arith brace setArray setArrayAppend assign arrayItems arrayValues arrayLen arrayIndex join setLastExit arithEval idiv imod guard not contains builtin builtinValue builtinText grepText grepMatches cutText bcSqrt fileTest fileTest2 fnCall fnValue callDirect callUndefined
    define subshell background block whileLoop whileLoopSync whileLoopBatch cstyleFor cstyleForSync forLoop forLoopSync forLoopBatch listVar and or
    subshellSync blockSync captureSync captureWordsSync pipelineSync redirectSync
    execRedirect pipelineCapture pipelineCaptureSync
    shopt return break continue unsupported
    isReturnSignal returnSignalValue
    typeOf isType toI64
    pipelineInputLines
    makeChan recv send select
    trimCapture dirname basename uname date readlink hostname whoami mktempValue split readFile writeFile appendFile lstat access unlink rm mkdir mkdtemp addrOf memLoad memStore walkLines readLine eachLine readText writeText
    memAlloc memFree ternary arrayStore memAdvance memTest line
    assocSet assocGet assocNames assocValues
    lit warn die
    int lc uc
    pyFloat
);

my $file = shift @ARGV or die "usage: estree_gate.pl <program.estree.json>\n";
open my $fh, '<', $file or die "open $file: $!";
my $content = do { local $/; <$fh> };
close $fh;

# otranspilerl-cli --target estree prints NOTHING on stdout when the parse fails (the CLI
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
my %null_fn_candidates;
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
        # a module-level `let <id> = null` binding that the program later
        # ASSIGNS a function to is the same direct binding under a
        # readable name (`let my_func = null; (my_func = () => …, …)`) —
        # src/shir.rs `direct_binding_name` keeps the plain name when it
        # collides with nothing. Record the null init here and confirm the
        # arrow assignment below, so `x()` on an ordinary null variable
        # still fails.
        if ((($id->{type} // '') eq 'Identifier')
            && (($init->{type} // '') eq 'Literal' && !defined $init->{value})) {
            $null_fn_candidates{ $id->{name} // '' } = 1;
        }
    }
}
# Confirm the candidates: an AssignmentExpression `<id> = <fn>` anywhere in
# the program promotes the binding to a callable (the define site).
sub confirm_fn_assignments {
    my ($n) = @_;
    return unless defined $n;
    if (ref $n eq 'HASH') {
        if (($n->{type} // '') eq 'AssignmentExpression'
            && ref $n->{left} eq 'HASH'
            && ($n->{left}{type} // '') eq 'Identifier'
            && $null_fn_candidates{ $n->{left}{name} // '' }
            && ref $n->{right} eq 'HASH'
            && (($n->{right}{type} // '') eq 'ArrowFunctionExpression'
                || ($n->{right}{type} // '') eq 'FunctionExpression')) {
            $native_fn_bindings{ $n->{left}{name} } = 1;
        }
        for my $k (keys %$n) {
            next if $k eq 'type';
            confirm_fn_assignments($n->{$k});
        }
    } elsif (ref $n eq 'ARRAY') {
        confirm_fn_assignments($_) for @$n;
    }
}
confirm_fn_assignments($data);

# Names bound to a native `Map` — the associative-array migration
# (src/shir.rs `assoc_migrate_program`, SH2_ASSUME_NATIVE_ASSOC, ON by
# default). A `declare -A M` that the pass proves script-local becomes a JS
# `Map`, so every later touch is `M.get(k)` / `M.set(k, v)` / `M.has(k)` /
# `M.keys()` — built-in Map.prototype methods, pure CPU, no dispatch, no
# store round-trip. The gate must accept exactly those methods on exactly
# those receivers; a bare `x.set(...)` on anything else still fails.
my %map_bindings;
sub collect_map_bindings {
    my ($n) = @_;
    return unless defined $n;
    if (ref $n eq 'HASH') {
        my $type = $n->{type} // '';
        my $is_new_map = $type eq 'NewExpression'
            && ref $n->{callee} eq 'HASH'
            && ($n->{callee}{type} // '') eq 'Identifier'
            && ($n->{callee}{name} // '') eq 'Map';
        # `let M = new Map()`, `M = new Map()` — the latter also covers the
        # `(M || (M = new Map()))` lazy-init fallback the emitter wraps
        # every access in, so a receiver seen only THERE is still known.
        if ($is_new_map) {
            # nothing to record from the constructor itself
        }
        if ($type eq 'VariableDeclarator'
            && ref $n->{id} eq 'HASH'
            && ($n->{id}{type} // '') eq 'Identifier'
            && ref $n->{init} eq 'HASH'
            && ($n->{init}{type} // '') eq 'NewExpression'
            && ref $n->{init}{callee} eq 'HASH'
            && ($n->{init}{callee}{name} // '') eq 'Map') {
            $map_bindings{ $n->{id}{name} // '' } = 1;
        }
        if ($type eq 'AssignmentExpression'
            && ref $n->{left} eq 'HASH'
            && ($n->{left}{type} // '') eq 'Identifier'
            && ref $n->{right} eq 'HASH'
            && ($n->{right}{type} // '') eq 'NewExpression'
            && ref $n->{right}{callee} eq 'HASH'
            && ($n->{right}{callee}{name} // '') eq 'Map') {
            $map_bindings{ $n->{left}{name} // '' } = 1;
        }
        for my $k (keys %$n) {
            next if $k eq 'type';
            collect_map_bindings($n->{$k});
        }
    } elsif (ref $n eq 'ARRAY') {
        collect_map_bindings($_) for @$n;
    }
}
collect_map_bindings($data);

# Script-defined native functions (the POSITIONAL_LOCAL / param lift,
# src/shir.rs): a lifted define is a HOISTED `function <name>(<params>)`
# declaration and its call sites are plain `<name>(<args>)` calls — no
# runtime dispatch, no subprocess, no store round-trip. The gate accepts a
# call exactly when the callee is a FunctionDeclaration id in this same
# program (the body is walked like any other node, so every call inside it
# is still checked).
my %defined_fns;
sub collect_defined_fns {
    my ($n) = @_;
    return unless defined $n;
    if (ref $n eq 'HASH') {
        if (($n->{type} // '') eq 'FunctionDeclaration'
            && ref $n->{id} eq 'HASH'
            && ($n->{id}{type} // '') eq 'Identifier'
            && ($n->{id}{name} // '') ne '') {
            $defined_fns{ $n->{id}{name} } = 1;
        }
        for my $k (keys %$n) {
            next if $k eq 'type';
            collect_defined_fns($n->{$k});
        }
    } elsif (ref $n eq 'ARRAY') {
        collect_defined_fns($_) for @$n;
    }
}
collect_defined_fns($data);

# Does this expression evaluate to a native Map? The receiver is a plain
# `Identifier` (a name recorded above), the constructor itself, or the
# lazy-init wrapper the emitter builds around each access.
sub resolves_to_map {
    my ($n) = @_;
    return 0 unless ref $n eq 'HASH';
    my $t = $n->{type} // '';
    if ($t eq 'Identifier') {
        return $map_bindings{ $n->{name} // '' } ? 1 : 0;
    }
    if ($t eq 'NewExpression') {
        my $c = $n->{callee} // {};
        return (($c->{type} // '') eq 'Identifier' && ($c->{name} // '') eq 'Map') ? 1 : 0;
    }
    # `M || (M = new Map())` — either side proves it
    if ($t eq 'LogicalExpression') {
        return resolves_to_map($n->{left}) || resolves_to_map($n->{right});
    }
    if ($t eq 'AssignmentExpression') {
        return resolves_to_map($n->{right});
    }
    if ($t eq 'SequenceExpression') {
        for my $e (@{ $n->{expressions} // [] }) {
            return 1 if resolves_to_map($e);
        }
        return 0;
    }
    # `sh2.arrays` / `sh2.assocStore` / … — the runtime's OWN Map fields
    # (sh2-namespace.mjs: `arrays: new Map()`, `assocStore: new Map()`, …).
    # The native lowerings reach into them directly instead of paying a
    # dispatch — `sh2.arrays.get("primes")` is the indexed-array store
    # lookup (src/shir.rs `arrays_get`, whose doc calls it "the same class
    # of direct store access `sh2.vars.<n>` already is"). The receiver is
    # the same Map, just spelled as a member chain rather than a binding,
    # so it belongs here; without this arm every `.get` on the store fell
    # through to `non-sh2 callee: get` and 14 corpus examples failed the
    # structural gate. The field list is the runtime's literal `new Map()`
    # fields — a field that is not a Map stays refused, which is what keeps
    # `anythingElse.get(...)` a failure.
    if ($t eq 'MemberExpression') {
        my $o = $n->{object} // {};
        my $p = $n->{property} // {};
        return 0 unless ref $o eq 'HASH' && ref $p eq 'HASH';
        return 0
            unless ($o->{type} // '') eq 'Identifier'
                && ($o->{name} // '') eq 'sh2'
                && ($p->{type} // '') eq 'Identifier';
        return (($p->{name} // '') =~ /^(arrays|assocStore|functions|chans|shoptState|traps|refVars|readBufs|_objStore|_wasm)$/) ? 1 : 0;
    }
    return 0;
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
                && $prop->{name} =~ /^(readFile|writeFile|appendFile|lstat|access|unlink|rm|mkdir|mkdtemp|readText|writeText)$/;
            my $is_native = ($callee->{type} // '') eq 'Identifier'
                && (($callee->{name} // '') eq 'Number' || ($callee->{name} // '') eq 'String'
                    || ($callee->{name} // '') eq 'parseInt' || ($callee->{name} // '') eq 'parseFloat'
                    || ($callee->{name} // '') eq 'Promise'
                    # the i53 escalation / `--true64` BigInt home
                    # (src/shir.rs): `BigInt("9007199254740993")` exact
                    # literals — a Number literal would round past 2^53
                    || ($callee->{name} // '') eq 'BigInt'
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
                # max/min — the native `${x##*[/\\]}` class-core strip (max of
                # per-char lastIndexOf, src/shir.rs glob_class_chars) and the
                # `head -n N` / `tail -n N` clamp (`Math.min(n-1, L.length)`),
                # both pure numeric bounds
                && ($prop->{name} // '') =~ /^(trunc|floor|ceil|sqrt|max|min)$/;
            # BigInt.asIntN(64, x) / BigInt.asUintN(64, x) — the i53
            # escalation / `--true64` 64-bit wrap (bash int64 semantics)
            my $is_bigint_member = ref $obj eq 'HASH'
                && ($obj->{type} // '') eq 'Identifier'
                && ($obj->{name} // '') eq 'BigInt'
                && ref $prop eq 'HASH'
                && ($prop->{name} // '') =~ /^(asIntN|asUintN)$/;
            # Number.isNaN — the NaN-guarded numeric test lowering (bash's
            # "integer expression expected" error → the whole test is false)
            # `isSafeInteger` — the i53 bound check of the same escalation
            # family (src/shir.rs): a value that has left the ±2^53
            # safe-integer domain switches representation rather than
            # silently rounding. Same `Number.<static>` shape as isNaN.
            my $is_number_member = ref $obj eq 'HASH'
                && ($obj->{type} // '') eq 'Identifier'
                && ($obj->{name} // '') eq 'Number'
                && ref $prop eq 'HASH'
                && ($prop->{name} // '') =~ /^(isNaN|isSafeInteger)$/;
            # Array.isArray — the native sh2.join lowering (the runtime
            # helper's exact `Array.isArray(v) ? v.join(" ") : String(v)`)
            my $is_array_member = ref $obj eq 'HASH'
                && ($obj->{type} // '') eq 'Identifier'
                && ($obj->{name} // '') eq 'Array'
                && ref $prop eq 'HASH'
                && ($prop->{name} // '') eq 'isArray';
            # M.get / M.set / M.has / M.keys / … on a receiver that
            # RESOLVES TO A NATIVE MAP — the associative-array migration's
            # whole point (no store round-trip, no sh2.assocGet dispatch).
            # Restricting by receiver, not by method name alone, keeps
            # `anythingElse.set(...)` a failure.
            my $is_map_member = ref $prop eq 'HASH'
                && ($prop->{name} // '') =~ /^(get|set|has|delete|keys|values|entries|clear|forEach|size)$/
                && resolves_to_map($obj);
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
            # text-ops primitive lowerings widen this twice:
            #   - LogicalExpression objects: `(sh2.getVar(x) ?? "")`
            #     unset-default coalescing feeding a pure string op;
            #   - substring/pop names: SubStrExtract's `.substring(off,
            #     off+len)` and PathName(basename)'s `split('/').pop()` —
            #     the same pure-CPU class as slice/includes.
            my $is_string_method = ref $obj eq 'HASH'
                && (($obj->{type} // '') eq 'CallExpression' || ($obj->{type} // '') eq 'ArrayExpression'
                    || ($obj->{type} // '') eq 'AwaitExpression' || ($obj->{type} // '') eq 'ConditionalExpression'
                    || ($obj->{type} // '') eq 'BinaryExpression' || ($obj->{type} // '') eq 'Literal'
                    || ($obj->{type} // '') eq 'LogicalExpression' || ($obj->{type} // '') eq 'Identifier')
                && ref $prop eq 'HASH'
                # charCodeAt / forEach — the native tr stage's contiguous
                # code-point shift (`c.charCodeAt(0) + 32`) and the native sed
                # stage's per-line loop (`L.forEach((line, li) => …)`), both
                # src/shir.rs (tr_stage / sed_stage). Pure CPU, no I/O.
                # reduce — the array-sum/concat lowering over a store read:
                # `sh2.arrays.get("primes").reduce((a, b) => a + b, 0)`
                # (051_primes, 063_09, 063_20). The receiver is a
                # CallExpression — already in the allowed object types — and
                # the fold is a native Array method on the plain string[] the
                # store hands back: pure CPU, no dispatch, no I/O, exactly
                # the class of `map`/`filter` two names earlier.
                && ($prop->{name} // '') =~ /^(includes|startsWith|endsWith|toLowerCase|toUpperCase|charAt|slice|substring|split|join|flat|sort|then|catch|trim|replace|replaceAll|lastIndexOf|concat|filter|map|indexOf|test|exec|repeat|push|pop|charCodeAt|forEach|reduce)$/;
            # String.fromCharCode(n) — the native tr stage's contiguous
            # code-point shift (`A-Z` -> `a-z` is exactly `fromCharCode(+32)`,
            # src/shir.rs tr_stage). Pure-CPU, no I/O.
            my $is_string_static = ref $obj eq 'HASH'
                && ($obj->{type} // '') eq 'Identifier'
                && ($obj->{name} // '') eq 'String'
                && ref $prop eq 'HASH'
                && ($prop->{name} // '') eq 'fromCharCode';
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
            # a direct call to a script-defined native function (the
            # POSITIONAL_LOCAL / param lift): the callee is a hoisted
            # FunctionDeclaration in this same program — no dispatch, no
            # subprocess. Its body is walked by this same gate.
            my $is_direct_fn = ref $callee eq 'HASH'
                && ($callee->{type} // '') eq 'Identifier'
                && $defined_fns{ $callee->{name} // '' };
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
            # sh2._r.<string method> — the sync-read scratch (src/shir.rs
            # read_text_map / native_exec_grep_q): the file text bound by
            # `sh2.fs.readText` and transformed by the capture lift's native
            # string ops. It is the exact chain the old `.then(t => …)` arrow
            # ran over its parameter — a plain JS string, no dispatch, no I/O.
            my $is_read_scratch = ref $obj eq 'HASH'
                && ($obj->{type} // '') eq 'MemberExpression'
                && ref $obj->{object} eq 'HASH'
                && ($obj->{object}{type} // '') eq 'Identifier'
                && ($obj->{object}{name} // '') eq 'sh2'
                && ref $obj->{property} eq 'HASH'
                && ($obj->{property}{name} // '') eq '_r'
                && ref $prop eq 'HASH'
                && ($prop->{name} // '') =~ /^(includes|startsWith|endsWith|toLowerCase|toUpperCase|charAt|slice|substring|split|join|trim|replace|replaceAll|lastIndexOf|concat|filter|map|indexOf|test|repeat)$/;
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
            if (!$is_sh2 && !$is_sh2_fs && !$is_native && !$is_math && !$is_number_member && !$is_array_member && !$is_map_member && !$is_promise_member && !$is_bigint_member && !$is_string_method && !$is_sh2_state && !$is_read_scratch && !$is_stdout_write && !$is_stderr_write && !$is_buffer && !$is_process_member && !$is_iife && !$is_direct_fn && !$is_string_static) {
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
                    unless $pname =~ /^(whileLoopSync|forLoopSync|cstyleForSync|captureSync|captureWordsSync|pipelineSync|subshellSync|redirectSync|blockSync|pipelineCaptureSync)$/;
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
