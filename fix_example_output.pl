#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw(basename dirname);
use File::Path qw(make_path);
use Cwd qw(abs_path);
$| = 1;

my $root = dirname(abs_path($0));
my $examples = "$root/sh2perl/examples";

# Find tests that were added from examples.new/ (not the pre-existing ones).
# Pre-existing tests start with 000_, 001_, 002_, ..., test_ or are well-known.
my @all = sort glob "$examples/*.sh";
my @existing_basenames = map { basename($_) } glob "$examples/{0,1,2,3,4,5,6,7,8,9}*.sh";
my %existing;
for (@existing_basenames) { $existing{$_} = 1 }

# Also keep known test files that predate examples.new
for (qw(test_find.sh test_grep.sh test_perl_critic.sh test_simple_function.sh
        test_system_builtin.sh 900_if2echo.sh 999_pwd.sh)) {
    $existing{$_} = 1
}

my @new_tests;
for my $f (@all) {
    my $b = basename($f);
    push @new_tests, $f unless $existing{$b};
}

print "Found " . scalar(@new_tests) . " tests from examples.new/\n";

my $fixed = 0;
for my $test (@new_tests) {
    my $content = do { local $/; open my $fh, '<', $test or die $!; <$fh> };
    my $orig = $content;

    # Find all variable assignments: var=value, var=$(cmd), local var=value
    my @vars;
    while ($content =~ /(?:^|\n)\s*(?:local\s+)?([a-zA-Z_][a-zA-Z0-9_]*)=/g) {
        push @vars, $1;
    }

    # Also find variables from read, for loop variables, etc.
    while ($content =~ /\b(?:read|for)\s+(?:\S+\s+)?([a-zA-Z_][a-zA-Z0-9_]*)/g) {
        push @vars, $1 unless $1 eq 'in' || $1 eq 'do';
    }

    # Deduplicate
    my %seen;
    @vars = grep { !$seen{$_}++ } @vars;

    # Filter out variables that are already displayed
    my @undisplayed;
    for my $v (@vars) {
        # Check if variable is printed or used in an echo/printf argument
        next if $content =~ /\$\{?\Q$v\E\}?/ && ($content =~ /echo\s.*\$\{?\Q$v\E\}?/ || $content =~ /printf\s.*\$\{?\Q$v\E\}?/);
        # Also check if it's used in a comparison or test
        next if $content =~ /\[\s.*\$\{?\Q$v\E\}?/;
        # If the variable is never referenced after assignment, it needs display
        push @undisplayed, $v;
    }

    next unless @undisplayed;

    # Find the last line and insert printf before it
    $content =~ s/(\n)([^\n]*\w)\s*$/\nfor my \$__v (qw(${\join(' ', @undisplayed)})) { printf "%s=[%s]\\n", \$__v, \${__v} }\n$2/;

    if ($content ne $orig) {
        open my $fh, '>', $test or die $!;
        print $fh $content;
        close $fh;
        print "Fixed: $test (" . join(', ', @undisplayed) . ")\n";
        $fixed++;
    }
}

print "\nFixed $fixed tests\n";
