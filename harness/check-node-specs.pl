#!/usr/bin/perl
# harness/check-node-specs.pl — every `spec:` a node declares must name a
# theorem that actually exists in sh2perl/docs/fm.
#
# The node files are the repository's cross-reference surface: a `spec:` line
# is a promise that the named obligation is proved somewhere under docs/fm.
# Three of them were dangling (newline_strip_sound, uniq_lines_sound,
# substitute_sound existed in no theory) and nothing noticed, because the only
# way to check was to grep by hand. This turns "no dangling spec" into a
# machine check.
#
# Accepted forms:
#   spec: TextOps#<name>     — <name> must be declared (theorem/lemma/
#                              definition/fun) in some .thy under docs/fm
#   spec: none (unstated)    — counted, reported, not an error
#
# Exit 0 when nothing dangles, 1 otherwise (so it can gate).
#
#   harness/check-node-specs.pl            # the default tree
#   harness/check-node-specs.pl --verbose  # list every resolved spec too
use strict;
use warnings;
use File::Find;
use File::Basename qw(dirname basename);

my $root = dirname(dirname(__FILE__));    # harness/ -> workspace root
my $nodes = "$root/sh2perl/src/shir_nodes";
my $fm    = "$root/sh2perl/docs/fm";
my $verbose = grep { $_ eq '--verbose' } @ARGV;

die "no node directory at $nodes\n" unless -d $nodes;
die "no theory tree at $fm\n"       unless -d $fm;

# Every declared name, and the file it lives in.
my (%declared, %where);
find(
    { no_chdir => 1,
      wanted => sub {
        return unless /\.thy$/;
        return if $File::Find::dir =~ m{/\.};
        open my $fh, '<', $File::Find::name or die "$File::Find::name: $!\n";
        while (my $line = <$fh>) {
            next unless $line =~ /^\s*(theorem|lemma|definition|fun)\s+([A-Za-z0-9_']+)/;
            my $name = $2;
            $declared{$name} = 1;
            $where{$name}    = $File::Find::name;
        }
        close $fh;
      },
    },
    $fm
);

my ($ok, $unstated, $bad) = (0, 0, 0);
my @dangling;

for my $node (sort glob("$nodes/*.node")) {
    my $file = basename($node);
    open my $fh, '<', $node or die "$node: $!\n";
    my $lineno = 0;
    while (my $line = <$fh>) {
        $lineno++;
        next unless $line =~ /^\s*spec:\s*(.*?)\s*$/;
        my $spec = $1;
        # `none (...)` is a deliberate "no obligation recorded" note — often with
        # a reason (an effect, a frontend shape). It is counted, not an error.
        if ($spec =~ /^none\b/) {
            $unstated++;
            next;
        }
        # A node may cite several obligations, comma separated.
        for my $one (split /\s*,\s*/, $spec) {
            unless ($one =~ /^([A-Za-z0-9_]+)#([A-Za-z0-9_']+)$/) {
                push @dangling, "$file:$lineno: malformed spec '$one' (want Theory#name)";
                $bad++;
                next;
            }
            my ($theory, $name) = ($1, $2);
            if ($declared{$name}) {
                $ok++;
                print "  ok       $file:$lineno  $theory#$name  ($where{$name})\n"
                    if $verbose;
            }
            else {
                push @dangling,
                  "$file:$lineno: DANGLING $theory#$name (no theorem/lemma/definition '$name' in docs/fm)";
                $bad++;
            }
        }
    }
    close $fh;
}

print "$_\n" for @dangling;
print "node specs: $ok resolved, $unstated unstated, $bad dangling\n";
exit($bad ? 1 : 0);
