#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw(basename dirname);
use Cwd qw(abs_path);
$| = 1;

my $root = dirname(abs_path($0));
my $examples = "$root/sh2perl/examples";

# Load list of new examples
open my $lfh, '<', '/tmp/new_examples.txt' or die;
my @new = <$lfh>; chomp @new; close $lfh;
my %new; for (@new) { $new{$_} = 1 }

# Keywords that look like variable assignments but aren't
my %keywords = map { $_ => 1 } qw(for if while until case esac then else do done
    function local declare export readonly typeset unset shift eval exec trap);

my $fixed = 0;
for my $f (sort glob "$examples/*.sh") {
    my $name = basename($f);
    next unless $new{$name};

    my $content = do { local $/; open my $fh, '<', $f or die $!; <$fh> };
    my $orig = $content;

    # Find all variable assignments at line start: VAR=value or local VAR=value
    my @vars;
    while ($content =~ /(?:^|\n)\s*(?:local\s+|declare\s+)?([a-zA-Z_][a-zA-Z0-9_]*)=/g) {
        my $var = $1;
        next if $keywords{$var};
        next if $var eq 'LIBSSL' || $var eq 'VERSION' || $var eq 'LOG_FILE';  # already checked
        my $pos = pos($content) // length($content);
        my $rest = substr($content, $pos);
        # Check if variable appears in echo/printf after this point
        next if $rest =~ /echo\s+.*\$\{?\Q$var\E\}?/s || $rest =~ /printf\s+.*\$\{?\Q$var\E\}?/s || $rest =~ /\$\{?\Q$var\E\}?.*echo/s;
        push @vars, $var;
    }

    next unless @vars;

    # Build printf lines
    my $add = '';
    for my $v (@vars) {
        # Use ${var:-} to avoid warnings about unset vars
        $add .= "printf \"%s=[%s]\\n\" $v \"\${$v:-}\"\n";
    }

    # Insert before the last exit/echo/printf, or at end
    if ($content =~ /\n(\s*exit\s)/) {
        $content =~ s/\n(\s*exit\s)/\n${add}$1/;
    } elsif ($content =~ /\n(\s*(?:echo|printf)\s)/) {
        $content =~ s/\n(\s*(?:echo|printf)\s)/\n${add}$1/;
    } else {
        $content =~ s/(\n\s*)$/${add}${1}/;
        $content .= "\n$add" unless $content ne $orig;
    }

    if ($content ne $orig) {
        open my $fh, '>', $f or die $!;
        print $fh $content;
        close $fh;
        print "$name: " . join(', ', @vars) . "\n";
        $fixed++;
    }
}

print "\nFixed $fixed tests\n";
