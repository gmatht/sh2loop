#!/usr/bin/perl
# Regression guard: a gate verdict must not depend on the directory the gate
# was launched from.
#
# `000__04c_text_processing_commands.sh` greps its OWN filename
# (`grep -n "echo" 000__04c_text_processing_commands.sh`), so its stdout is
# 2155 bytes when that file is readable in the cwd and 501 bytes when it is
# not. fail-estree runs both arms of the comparison (the transpiler's output
# and the `bash` reference) in whatever cwd the caller happened to be in, so
# the SAME binary gave ESTREE 1/1 from the repo root and 0/1 from /tmp — a
# verdict flip caused by nothing but the invocation directory.
#
# The fix pins both arms to the per-test temp dir. This test runs the gate
# from two different cwds and asserts the verdicts AGREE, which is the
# property the fix restores. Run it from a third directory to be sure it is
# not itself cwd-sensitive.
#
# Usage: perl harness/check_gate_cwd.pl [path-to-fail-estree]
# Exits 0 on pass, 1 on FAIL, 2 on inconclusive (gate not runnable here).

use strict;
use warnings;
use Cwd qw(abs_path getcwd);
use File::Temp qw(tempdir);
use File::Path qw(make_path);
use FindBin qw($Bin);

my $root = abs_path("$Bin/..");
my $gate = $ARGV[0] // "$root/fail-estree";

my $EXAMPLE = '000__04c_text_processing_commands.sh';

# The gate builds the CLI before testing; a stale/missing binary makes the
# run meaningless rather than failing, so check it up front.
my $cli = "$root/otranspilerl/target/debug/otranspilerl-cli";
unless (-x $cli) {
    print "SKIP: $cli not built — nothing to compare\n";
    exit 2;
}

# Run the gate for one example from each of two unrelated cwds. The two
# temp dirs are empty and unrelated, so if the gate pins its own cwd the
# verdict can only be decided by the example's behaviour.
sub run_from {
    my ($label, $dir) = @_;
    make_path($dir);
    my $out = `cd '$dir' && timeout 600 '$gate' $EXAMPLE 2>&1`;
    # Match the summary line and its counts in ONE pass: a failed match must
    # not leave $1/$2 set from an earlier successful match, which would let
    # this test pass vacuously.
    my ($passed, $failed);
    if ($out =~ /^ESTREE:\s*(\d+) passed,\s*(\d+) failed/m) {
        ($passed, $failed) = ($1, $2);
    } else {
        return ($label, undef, $out);
    }
    return ($label, "$passed/$failed", $out);
}

my $base = tempdir('gatecwd-XXXXXXXX', CLEANUP => 1, DIR => '/tmp');
# The two cwds must be chosen so the pre-fix gate DISAGREES between them —
# otherwise this test passes vacuously. `$root` is one (generation succeeds
# there and the example's self-grep resolves); an unrelated dir under /tmp is
# the other (generation aborts with "cannot locate the workspace root"). Both
# are empty of anything the example reads, so once the gate pins its own cwd
# the two must agree.
my $d1 = $root;
my $d2 = "$base/beta";
make_path($d2);

my ($l1, $v1, $raw1) = run_from('workspace-root', $d1);
my ($l2, $v2, $raw2) = run_from('unrelated-tmp', $d2);

if (!defined $v1 || !defined $v2) {
    print "FAIL: gate did not report a verdict\n";
    print "  from $l1: $v1\n";
    print "  from $l2: $v2\n";
    print "  raw($l1): $raw1\n" if !defined $v1;
    print "  raw($l2): $raw2\n" if !defined $v2;
    exit 1;
}

printf "  from %s: %s\n", $l1, $v1;
printf "  from %s: %s\n", $l2, $v2;

# The property under test: the SAME binary, SAME example, SAME everything
# except the cwd, must reach the SAME verdict.
if ($v1 ne $v2) {
    print "FAIL: verdict depends on the invocation cwd ($v1 vs $v2)\n";
    print "      fail-estree must pin both comparison arms to the per-test\n";
    print "      temp dir so the example's own cwd-sensitive reads decide.\n";
    exit 1;
}

print "PASS: verdict is cwd-independent ($v1 from both directories)\n";
exit 0;
