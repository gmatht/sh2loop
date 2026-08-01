#!/usr/bin/env perl
# check_ast.pl — AST-structure regression tests for the sh2perl parser.
#
# The estree repair worker has fixed several corpus tests by patching
# ARTIFACTS of the lexer/parser in the transform stage (transform_cmd in
# shir.rs / estree.rs). Some of those patches paper over structural gaps
# that the RAW parser AST cannot express. This script pins those properties
# so the gaps are visible in the workspace and stay tracked:
#
#   * `echo x $$` (a separate PID argument) must be distinguishable from
#     `echo x$$` (PID glued inside the word). Today the parser cuts `$$` off
#     the end of a word, so both arrive as [Literal, Variable("$")] — the
#     transform then rejoins both, miscompiling `echo x $$` to `echo x$$`.
#   * `echo 'a'\''b'` (bash joins to `a'b`) and `echo x \''y'` (bash keeps
#     two words `x 'y`) arrive with the SAME AST shape; the transform merges
#     both, miscompiling the second.
#
# KNOWN LIMITATIONS ARE FAILURES. The guardrail is "never bless a transpiler
# bug": these are real parser gaps producing wrong output (or an AST that
# cannot express the construct), so the script exits non-zero while any is
# present — the count decreases only when a parser/transform fix lands (the
# case then prints RESOLVED and moves out of @known_limitations).
#
# Usage: harness/check_ast.pl     (builds debashc + dump_ast if missing)

use strict;
use warnings;
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use File::Temp qw(tempdir);

$| = 1;

my $root = dirname(dirname(abs_path($0)));   # workspace root (this script lives in harness/)
my $sh2perl = "$root/sh2perl";
my $debashc = "$sh2perl/target/debug/debashc";
my $dump_ast = "$sh2perl/target/debug/dump_ast";

# ---- build the tools if missing -------------------------------------
if (!-x $debashc || !-x $dump_ast) {
    system("cargo", "build", "--manifest-path", "$sh2perl/Cargo.toml",
           "--bin", "debashc", "--bin", "dump_ast") == 0
        or die "cargo build failed\n";
}

# ---- helpers ---------------------------------------------------------
sub run_bash {
    my ($src) = @_;
    my $dir = tempdir(CLEANUP => 1);
    my $f = "$dir/in.sh";
    open my $fh, '>', $f or die "write $f: $!";
    print $fh "$src\n";
    close $fh;
    my $out = `timeout 15 bash $f 2>/dev/null`;
    return ($out, $dir);
}

sub run_estree {
    my ($src) = @_;
    my $dir = tempdir(CLEANUP => 1);
    my $f = "$dir/in.sh";
    open my $fh, '>', $f or die "write $f: $!";
    print $fh "$src\n";
    close $fh;
    my $json = `$debashc file --estree $f 2>/dev/null`;
    open my $of, '>', "$dir/out.json" or die "write: $!";
    print $of $json;
    close $of;
    my $out = `node $root/harness/estree-runner.mjs $dir/out.json --source $f 2>/dev/null`;
    return ($out, $dir);
}

# PID values differ between the bash and node processes: normalize.
sub norm {
    my ($s) = @_;
    $s =~ s/\d+/PID/g;
    return $s;
}

sub dump_ast_for {
    my ($src) = @_;
    my $dir = tempdir(CLEANUP => 1);
    my $f = "$dir/in.sh";
    open my $fh, '>', $f or die "write $f: $!";
    print $fh "$src\n";
    close $fh;
    return `$dump_ast $f 2>/dev/null`;
}

# ---- case table ------------------------------------------------------
# kind: 'ast' -> inspect the RAW parser AST via dump_ast
#       'beh' -> run bash and the estree pipeline, compare normalized stdout
# A case failing today that documents a real parser gap belongs in
# @known_limitations — it still counts as a FAILURE and trips the exit code,
# but is reported with the KNOWN AST GAP marker so it is distinguishable
# from an unexpected regression.

# Tracked parser gaps — ALL count as failures (exit 1). A fix flips a case
# to RESOLVED; remove it from this list when that happens.
my @known_limitations = qw();

my @cases = (
    # --- `$$` must stay inside the word it was written in -------------
    {
        name => 'ast_dollardollar_arg_boundary',
        kind => 'ast',
        src  => 'echo x $$',
        check => sub {
            my $d = shift;
            # two separate args: Literal("x"), Variable("$")
            return scalar(() = $d =~ /^WORD:/mg) == 2
                && $d =~ /Literal\("x"/ && $d =~ /Variable\("\$"/;
        },
    },
    {
        name => 'ast_dollardollar_word_internal',
        kind => 'ast',
        src  => 'echo x$$',
        check => sub {
            my $d = shift;
            # DESIRED: ONE arg — an interpolation ("x" + $$ inside the word).
            # Today the parser cuts `$$` off the end: TWO args
            # [Literal("x"), Variable("$")] — indistinguishable from the
            # spaced form above. Known limitation.
            return scalar(() = $d =~ /^WORD:/mg) == 1
                && $d =~ /StringInterpolation/;
        },
    },
    {
        name => 'ast_redirect_dollardollar_stays_in_target',
        kind => 'ast',
        src  => 'echo hi > /tmp/t.$$',
        check => sub {
            my $d = shift;
            # DESIRED: `$$` stays part of the redirect TARGET (as an
            # interpolation part); the command's args list must contain NO
            # Variable("$").
            my ($args) = $d =~ /args: \[([^\]]*)\]/;
            return defined $args && $args !~ /Variable\("\$"/;
        },
    },
    # --- escaped-quote join artifacts --------------------------------
    {
        name => 'ast_escaped_quote_fused_word',
        kind => 'ast',
        src  => "echo 'a'\\''b'",
        check => sub {
            my $d = shift;
            # DESIRED: ONE word `a\'b` — the parser fuses the adjacent
            # single-quote + escaped-quote + single-quote fragments (bash:
            # `'a'\''b'` is the single word `a'b`). The renderers unescape
            # the `\'` to `'`.
            return scalar(() = $d =~ /^WORD:/mg) == 1
                && $d =~ /Literal\("a\\\\'b"/;
        },
    },
    {
        name => 'ast_escaped_quote_word_start',
        kind => 'ast',
        src  => "echo \\''a'",
        check => sub {
            my $d = shift;
            # ONE arg, a literal STARTING with the escaped-quote artifact
            # (no predecessor to merge into — must survive as-is).
            return scalar(() = $d =~ /^WORD:/mg) == 1
                && $d =~ /Literal\("\\\\'a"/;
        },
    },
    # --- LongOption `${...}` artifact ---------------------------------
    {
        name => 'ast_longoption_dollar_brace_artifact',
        kind => 'ast',
        src  => 'echo --x="${X}"',
        check => sub {
            my $d = shift;
            # ONE arg, the raw merged literal (the transform re-splits it so
            # the expansion runs; pin the raw artifact shape here).
            return scalar(() = $d =~ /^WORD:/mg) == 1
                && $d =~ /Literal\("--x=\$\{X\}"/
                && $d !~ /ParameterExpansion/;
        },
    },
    # --- general mid-word `$`-fusion (fixed with the `$$` bug) ---------
    {
        name => 'ast_dollar_var_word_internal',
        kind => 'ast',
        src  => 'echo pre$var',
        check => sub {
            my $d = shift;
            # `pre$var` is ONE word (interpolation) — the old parser split
            # mid-word `$`-expansions into separate args (same bug as `$$`).
            return scalar(() = $d =~ /^WORD:/mg) == 1
                && $d =~ /StringInterpolation/;
        },
    },
    {
        name => 'beh_dollar_var_glued',
        kind => 'beh',
        src  => 'X=z; echo a$X b',
        check => sub {
            my ($b, $e) = @_;
            return $b eq $e;
        },
    },
    {
        name => 'beh_dollar_brace_glued',
        kind => 'beh',
        src  => 'X=z; echo a${X}b',
        check => sub {
            my ($b, $e) = @_;
            return $b eq $e;
        },
    },
    {
        name => 'beh_dollar_default_operator_glued',
        kind => 'beh',
        src  => 'v=z; echo a${v:-d}b',
        check => sub {
            my ($b, $e) = @_;
            # guard: the fusion must never DISCARD the ${...} expansion
            # (a missed merge previously dropped it, printing `a b`).
            return $b eq $e;
        },
    },
    {
        name => 'beh_cmdsub_glued',
        kind => 'beh',
        src  => 'echo a$(true)b',
        check => sub {
            my ($b, $e) = @_;
            return $b eq $e;
        },
    },
    {
        name => 'beh_dollardollar_slash_suffix',
        kind => 'beh',
        src  => 'echo x$$/suf',
        check => sub {
            my ($b, $e) = @_;
            return norm($b) eq norm($e);
        },
    },
    # --- behavioral (bash vs estree, PID-normalized) -----------------
    {
        name => 'beh_dollardollar_spaced_pid',
        kind => 'beh',
        src  => 'echo x $$',
        check => sub {
            my ($b, $e) = @_;
            # bash: `x PID` (two words). DESIRED estree identical — today
            # the transform rejoins to `xPID`. Known limitation.
            return norm($b) eq norm($e);
        },
    },
    {
        name => 'beh_dollardollar_internal',
        kind => 'beh',
        src  => 'echo x$$',
        check => sub {
            my ($b, $e) = @_;
            return norm($b) eq norm($e);
        },
    },
    {
        name => 'beh_escaped_quote_merge',
        kind => 'beh',
        src  => "echo 'a'\\''b'",
        check => sub {
            my ($b, $e) = @_;
            return $b eq $e;
        },
    },
    {
        name => 'beh_escaped_quote_midword',
        kind => 'beh',
        src  => "echo x \\''y'",
        check => sub {
            my ($b, $e) = @_;
            # bash: `x 'y` (two words). Today the merge glues them: `x'y`.
            # Known limitation — the AST shape is identical to the legit
            # `'a'\''b'` merge above.
            return $b eq $e;
        },
    },
    {
        name => 'beh_longoption_expansion',
        kind => 'beh',
        src  => 'X=test; echo --x="${X}"',
        check => sub {
            my ($b, $e) = @_;
            return $b eq $e;
        },
    },
    {
        name => 'beh_singlequote_literal_brace',
        kind => 'beh',
        src  => "echo '\${x}'",
        check => sub {
            my ($b, $e) = @_;
            return $b eq $e;
        },
    },
    {
        name => 'beh_unterminated_param_parse_error',
        kind => 'beh',
        src  => 'echo "${var:?unset"',
        check => sub {
            my ($b, $e) = @_;
            # bash parse error: empty stdout; the emitted program must not
            # print the lexer artifact text — also empty.
            return $b eq '' && $e eq '';
        },
    },
    {
        name => 'beh_redirect_pid_target',
        kind => 'beh',
        src  => 'echo hi > /tmp/check_ast_t.$$',
        check => sub {
            my ($b, $e) = @_;
            # both must create /tmp/check_ast_t.<pid> ($$ inside the target)
            return $b eq '' && $e eq ''
                && scalar(grep { /check_ast_t\.\d+$/ } glob('/tmp/check_ast_t.*')) == 2;
        },
    },
);

# ---- run -------------------------------------------------------------
my (%known, %ok);
@known{@known_limitations} = (1) x @known_limitations;

my ($pass, $fail, $limit, $resolved) = (0, 0, 0, 0);
for my $c (@cases) {
    my $res;
    if ($c->{kind} eq 'ast') {
        my $d = dump_ast_for($c->{src});
        $res = $c->{check}->($d) ? 1 : 0;
    } else {
        my ($b, $bd) = run_bash($c->{src});
        my ($e, $ed) = run_estree($c->{src});
        $res = $c->{check}->($b, $e) ? 1 : 0;
    }

    if ($res) {
        if ($known{$c->{name}}) {
            printf "RESOLVED (remove from \@known_limitations): %s\n", $c->{name};
            $resolved++;
        } else {
            printf "PASS: %s\n", $c->{name};
            $pass++;
        }
    } else {
        if ($known{$c->{name}}) {
            printf "** KNOWN AST GAP (counts as FAILURE): %s\n", $c->{name};
            $limit++;
        } else {
            printf "FAIL: %s\n", $c->{name};
            $fail++;
        }
    }
}

unlink glob('/tmp/check_ast_t.*');

my $total_fail = $fail + $limit;
print "\n--- summary: $pass passed, $total_fail FAILED ($fail unexpected, $limit known AST gaps), $resolved resolved\n";
if ($total_fail > 0) {
    print "check_ast: FAIL — AST-structure gate red ($total_fail failures)\n";
    exit 1;
}
print "check_ast: OK\n";
exit 0;
