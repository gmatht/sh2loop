#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw(basename dirname);
use Cwd qw(abs_path);
$| = 1;

my $root = dirname(abs_path($0));
my $examples = "$root/sh2perl/examples";

# Read list of new examples (from examples.new/)
open my $fh, '<', '/tmp/new_examples.txt' or die "Cannot read /tmp/new_examples.txt";
my @new = <$fh>; chomp @new; close $fh;
my %new; for (@new) { $new{$_} = 1 }

my $fixed = 0;
for my $f (sort glob "$examples/*.sh") {
    my $name = basename($f);
    next unless $new{$name};

    my $content = do { local $/; open my $fh2, '<', $f or die $!; <$fh2> };
    my $orig = $content;

    # Find variables set via $() that aren't displayed
    my @to_add;
    while ($content =~ /^([a-zA-Z_][a-zA-Z0-9_]*)=(\042|)\$\(/gm) {
        my $var = $1;
        next if $content =~ /echo\s+.*\$\{?\Q$var\E\}?/s || $content =~ /printf\s+.*\$\{?\Q$var\E\}?/s;
        push @to_add, $var;
    }

    next unless @to_add;

    # Build the printf lines
    my $printf_lines = '';
    for my $v (@to_add) {
        $printf_lines .= "printf '$v=[%s]\\n' \"\$$v\"\n";
    }

    # Insert before the last exit, or append at end
    if ($content =~ /(\n)(exit\s|echo\s)/) {
        my $pos = $-[0];
        substr($content, $pos+1, 0) = $printf_lines;
    } else {
        # Find a good insertion point: before the last non-comment line
        $content =~ s/\n(\s*exit\s.*)$/\n${printf_lines}$1/;
        unless ($content ne $orig) {
            $content =~ s/\n(\s*echo\s+)/\n${printf_lines}$1/;
        }
        unless ($content ne $orig) {
            $content =~ s/\n(\s*printf\s)/\n${printf_lines}$1/;
        }
    }

    if ($content ne $orig) {
        open my $fh3, '>', $f or die $!;
        print $fh3 $content;
        close $fh3;
        print "Fixed: $name (" . join(', ', @to_add) . ")\n";
        $fixed++;
    }
}

print "\nFixed $fixed tests\n";
