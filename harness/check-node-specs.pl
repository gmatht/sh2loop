#!/usr/bin/perl
# harness/check-node-specs.pl — every `spec:` a node declares must name a
# THEOREM that exists in the theory its prefix claims, under sh2perl/docs/fm.
#
# The node files are the repository's cross-reference surface: a `spec:` line
# is a promise that the named obligation is proved somewhere under docs/fm.
# Three of them were dangling (newline_strip_sound, uniq_lines_sound,
# substitute_sound existed in no theory) and nothing noticed, because the only
# way to check was to grep by hand. This turns "no dangling spec" into a
# machine check, and distinguishes a proved obligation from a placeholder:
#
#   spec: TextOps#name        — `name` must be a theorem/lemma/corollary in a
#                               theory that belongs to session `TextOps`
#                               (read from docs/fm/*/ROOT). A `definition` or
#                               `fun` of that name is NOT accepted: a definition
#                               cannot be an obligation.
#   spec: TextOps#a, TextOps#b — several obligations, comma separated
#   spec: pending TextOps#name — an obligation that is still open. It must NOT
#                               resolve yet; if it starts resolving, the check
#                               fails and tells you to promote the line, so a
#                               pending name can never masquerade as proved.
#   spec: none (<reason>)     — deliberately no obligation recorded. Counted
#                               and reported, never an error.
#
# Exit 0 when nothing is dangling, not-a-theorem or stale-pending; 1 otherwise
# (so it can gate).
#
#   harness/check-node-specs.pl            # the default tree
#   harness/check-node-specs.pl --verbose  # list every resolved spec too
#   harness/check-node-specs.pl --map      # node -> theorem table (README node map)
#   harness/check-node-specs.pl --selftest # negative controls: dangling names,
#                                          # definition-as-spec, stale pending
use strict;
use warnings;
use File::Find;
use File::Basename qw(dirname basename);

my $root    = dirname(dirname(__FILE__));    # harness/ -> workspace root
my $nodes   = "$root/sh2perl/src/shir_nodes";
my $fm      = "$root/sh2perl/docs/fm";
my $verbose = grep { $_ eq '--verbose' } @ARGV;
my $map     = grep { $_ eq '--map' } @ARGV;
my $selftest = grep { $_ eq '--selftest' } @ARGV;

die "no node directory at $nodes\n" unless -d $nodes;
die "no theory tree at $fm\n"       unless -d $fm;

# ---------------------------------------------------------------- theory index
# Every declared name: kind, file, and the session its theory belongs to.
my (%kind, %file_of, %sessions_of);

find(
    { no_chdir => 1,
      wanted => sub {
        return unless /\.thy$/;
        return if $File::Find::dir =~ m{/\.};
        open my $fh, '<', $File::Find::name or die "$File::Find::name: $!\n";
        my $theory = basename($File::Find::name, '.thy');
        while (my $line = <$fh>) {
            next unless $line =~ /^\s*(theorem|lemma|corollary|definition|fun|primrec|datatype|abbreviation)\s+([A-Za-z0-9_']+)/;
            my ($k, $name) = ($1, $2);
            $kind{$name}      = $k unless exists $kind{$name} && $kind{$name} =~ /theorem|lemma|corollary/;
            $file_of{$name}   = $theory;
            $sessions_of{$name}{$theory} = 1;
        }
        close $fh;
      },
    },
    $fm
);

# session -> theory, from every ROOT under docs/fm
my (%session_theory, %built);
for my $r (glob("$fm/*/ROOT")) {
    open my $rf, '<', $r or die "$r: $!\n";
    my $cur = '';
    while (my $l = <$rf>) {
        if ($l =~ /^\s*session\s+([A-Za-z0-9_]+)/) { $cur = $1; next; }
        next unless $cur;
        if ($l =~ /^\s*([A-Za-z0-9_]+)\s*$/) {
            $session_theory{$cur}{$1} = 1;
            $built{$1} = 1;
        }
    }
    close $rf;
}

sub is_proved_in {
    my ($theory, $name) = @_;
    return 0 unless exists $kind{$name};
    return 0 unless $kind{$name} =~ /^(theorem|lemma|corollary)$/;
    # A theorem in a theory that no ROOT lists is NOT proved by this build:
    # an untracked WIP file must not satisfy a node's spec.
    return 0 unless $built{ $file_of{$name} };
    # The prefix is the session. A theory name is accepted too, for nodes that
    # cite one directly.
    if (exists $session_theory{$theory}) {
        return scalar grep { $sessions_of{$name}{$_} } keys %{ $session_theory{$theory} };
    }
    return exists $sessions_of{$name}{$theory};
}

sub verdict {
    my ($theory, $name) = @_;
    return 'proved'  if is_proved_in($theory, $name);
    return 'defined' if exists $kind{$name} && $kind{$name} !~ /^(theorem|lemma|corollary)$/;
    return 'unbuilt' if exists $kind{$name} && !$built{ $file_of{$name} };
    return 'absent';
}

# --------------------------------------------------------------------- selftest
if ($selftest) {
    my @cases = (
        # [theory, name, expected verdict, why]
        [ 'TextOps', 'newline_strip_sound', 'proved',  'a real theorem in the session' ],
        [ 'TextOps', 'trim_by',             'defined', 'a definition is not an obligation' ],
        [ 'TextOps', 'no_such_obligation',  'absent',  'a dangling name must be caught' ],
        [ 'NoSuchSession', 'newline_strip_sound', 'absent',
          'a real theorem under the wrong session prefix must be caught' ],
        [ 'TextOps', 'str_splice_fold_sound', 'unbuilt',
          'a theorem in a theory no ROOT lists is not proved by the build' ],
    );
    my $fail = 0;
    for my $c (@cases) {
        my ($t, $n, $want, $why) = @$c;
        my $got = verdict($t, $n);
        my $ok = $got eq $want;
        $fail++ unless $ok;
        printf "%s %-16s %-28s want=%-8s got=%-8s  %s\n",
            ($ok ? 'ok  ' : 'FAIL'), $t, $n, $want, $got, $why;
    }
    print $fail ? "selftest: $fail case(s) failed\n" : "selftest: all cases behave\n";
    exit($fail ? 1 : 0);
}

# ------------------------------------------------------------------------ nodes
my ($ok, $unstated, $pending, $bad) = (0, 0, 0, 0);
my @errors;
my @map_rows;

for my $node (sort glob("$nodes/*.node")) {
    my $file = basename($node);
    open my $fh, '<', $node or die "$node: $!\n";
    my $lineno = 0;
    while (my $line = <$fh>) {
        $lineno++;
        next unless $line =~ /^\s*spec:\s*(.*?)\s*$/;
        my $spec = $1;
        if ($spec =~ /^none\b/) {
            $unstated++;
            next;
        }
        my $is_pending = $spec =~ s/^pending\s+//;
        for my $one (split /\s*,\s*/, $spec) {
            unless ($one =~ /^([A-Za-z0-9_]+)#([A-Za-z0-9_']+)$/) {
                push @errors, "$file:$lineno: malformed spec '$one' (want Theory#name)";
                $bad++;
                next;
            }
            my ($theory, $name) = ($1, $2);
            my $v = verdict($theory, $name);
            if ($is_pending) {
                if ($v eq 'proved') {
                    push @errors,
                      "$file:$lineno: STALE PENDING $theory#$name — it now resolves, drop 'pending'";
                    $bad++;
                }
                else {
                    $pending++;
                    print "  pending  $file:$lineno  $theory#$name\n" if $verbose;
                }
                next;
            }
            if ($v eq 'proved') {
                $ok++;
                push @map_rows, [ $file, $theory, $name ];
                print "  ok       $file:$lineno  $theory#$name  ($file_of{$name}.thy)\n"
                    if $verbose;
            }
            elsif ($v eq 'unbuilt') {
                push @errors,
                  "$file:$lineno: OUTSIDE THE BUILD $theory#$name (declared in $file_of{$name}.thy, which no ROOT lists)";
                $bad++;
            }
            elsif ($v eq 'defined') {
                push @errors,
                  "$file:$lineno: NOT A THEOREM $theory#$name (declared as $kind{$name}, which cannot be an obligation)";
                $bad++;
            }
            else {
                push @errors,
                  "$file:$lineno: DANGLING $theory#$name (no theorem/lemma/corollary '$name' in session $theory)";
                $bad++;
            }
        }
    }
    close $fh;
}

if ($map) {
    printf "%-28s %-10s %s\n", 'node', 'theory', 'theorem';
    printf "%-28s %-10s %s\n", '-' x 28, '-' x 10, '-' x 40 for 1 .. 0;
    printf "%-28s %-10s %s\n", $_->[0], $_->[1], $_->[2] for @map_rows;
    print "\n";
}

print "$_\n" for @errors;
print "node specs: $ok resolved, $unstated unstated, $pending pending, $bad error(s)\n";
exit($bad ? 1 : 0);
