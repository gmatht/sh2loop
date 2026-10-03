#!/usr/bin/env perl
# pg-classify.pl — split the Perl generator's ./fail failures into the two
# dispositions that decide who can fix them:
#
#   PARSER_FB — the generator emitted the bash-wrapper fallback
#               (`system('bash', '<file>')`). That is the PARSER failing, and
#               the parser is shared core. These are NOT generator bugs.
#   GEN       — real generator/codegen bug: the generator emitted Perl, it just
#               did not match bash byte-for-byte. These are in scope.
#
# Uses the EXACT regex ./fail uses, so the classification agrees with the
# gate rather than with a looser grep (a plain `grep -F "system('bash'"`
# also matches the __sh_uu_run fallback seam inside the preamble helper,
# which is a legitimate runtime fallback, not a parse failure).
#
#   harness/pg-classify.pl <example-basename> [more...]
use strict;
use warnings;

my $root = '/home/llm/sh2loop';
my $cli  = "$root/otranspilerl/target/debug/otranspilerl-cli";

my (@fb, @gen, @empty);
for my $ex (@ARGV) {
    my $path = -f "$root/sh2perl/examples/$ex" ? "$root/sh2perl/examples/$ex" : $ex;
    my $all = '';
    if (open my $fh, '-|', $cli, '--target', 'pl', $path) {
        local $/;
        $all = <$fh> // '';
        close $fh;
    }
    if (!length $all)          { push @empty, $ex; next }
    if ($all =~ /system\('bash',\s*'[^']*'\)/) { push @fb, $ex; next }
    push @gen, $ex;
}

printf "PARSER_FB (%d): %s\n", scalar @fb, join(' ', @fb);
print "\n";
printf "GEN (%d): %s\n", scalar @gen, join(' ', @gen);
print "\n";
printf "EMPTY (%d): %s\n", scalar @empty, join(' ', @empty) if @empty;
