#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw(basename dirname);
use Cwd qw(abs_path);
$| = 1;

my $root = dirname(abs_path($0));
my $examples = "$root/sh2perl/examples";

# Load new examples list
open my $lfh, '<', '/tmp/new_examples.txt' or die;
my @new = <$lfh>; chomp @new; close $lfh;
my %new; for (@new) { $new{$_} = 1 }

my %keywords = map { $_ => 1 } qw(for if while until case esac then else do done
    function local declare export readonly typeset unset shift eval exec trap);

my $fixed = 0;
for my $f (sort glob "$examples/*.sh") {
    my $name = basename($f);
    next unless $new{$name};

    my $content = do { local $/; open my $fh, '<', $f or die $!; <$fh> };
    my $orig = $content;

    # Find variable assignments, skip keywords
    my %vars;
    while ($content =~ /(?:^|\n)\s*(?:local\s+|declare\s+)?([a-zA-Z_][a-zA-Z0-9_]*)=/g) {
        my $var = $1;
        next if $keywords{$var};
        $vars{$var} = 1;
    }

    next unless keys %vars;

    # Check which are never displayed
    my @undisplayed;
    for my $v (keys %vars) {
        next if $content =~ /echo\s+.*\$\{?\Q$v\E\}?/s || $content =~ /printf\s+.*\$\{?\Q$v\E\}?/s;
        push @undisplayed, $v;
    }

    next unless @undisplayed;

    # Build printf lines with proper newline before
    my $add = "\n";
    for my $v (@undisplayed) {
        $add .= "printf \"%s=[%s]\\n\" $v \"\${$v:-}\"\n";
    }
    $add .= "\n";

    # Insert at file end (safe, works with all shell constructs)
    $content =~ s/\n?\z/$add/;

    if ($content ne $orig) {
        open my $fh, '>', $f or die $!;
        print $fh $content;
        close $fh;
        print "$name: " . join(', ', @undisplayed) . "\n";
        $fixed++;
    }
}

print "\nFixed $fixed tests\n";
