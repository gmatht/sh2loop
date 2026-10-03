#!/usr/bin/env perl
# For every failing example, generate the Perl and report the SEAM calls whose
# command is a bash builtin that `ir.rs::is_shell_builtin` does NOT list. Those
# are exec'd by literal name (no such program), so the line silently produces
# nothing. Cheap: no execution, just a grep over the generated text.
use strict;
use warnings;

my $root = '/home/llm/sh2loop';
my $cli  = "$root/otranspilerl/target/debug/otranspilerl-cli";

my %missing = map { $_ => 1 } qw(
    builtin caller command compgen complete dirs disown enable fc help
    history kill logout mapfile popd pushd readarray suspend type ulimit
    hash jobs fg bg
);

my @names = @ARGV;
if (!@names) {
    open my $fh, '<', "$root/.pg-triage-fails.txt" or die $!;
    @names = <$fh>; close $fh; chomp @names;
}

my $hit = 0;
for my $n (grep { length } @names) {
    my $ex = "$root/sh2perl/examples/$n";
    next unless -f $ex;
    my $pl = "/tmp/pgseam.$$.$n.pl";
    open my $w, '>', $pl or next;
    print $w `timeout 60 sh -c '"$cli" --target pl "$ex" 2>/dev/null'`;
    close $w;
    my %seen;
    if (open my $r, '<', $pl) {
        while (my $l = <$r>) {
            while ($l =~ /__sh_uu_(?:capture|run)\('([^']+)'/g) {
                $seen{$1}++;
            }
        }
        close $r;
    }
    unlink $pl;
    my @bad = grep { $missing{$_} } sort keys %seen;
    if (@bad) {
        $hit++;
        printf "%-46s %s\n", $n, join(', ', map { "$_ x$seen{$_}" } @bad);
    }
}
print "\n=== $hit / ".scalar(grep { length } @names)." examples exec an unlisted builtin ===\n";
