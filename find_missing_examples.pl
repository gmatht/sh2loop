#!/usr/bin/env perl
use strict;
use warnings;
use FindBin qw($RealBin);

# Read builtins from check_qx.pl
my $check_qx = "$RealBin/check_qx.pl";
open my $fh, '<', $check_qx or die "Cannot read $check_qx: $!\n";
my $code = do { local $/; <$fh> };
close $fh;

# Extract the qw() list of builtins
my @builtins;
if ($code =~ /my \@builtins = qw\((.*?)\);/s) {
    my $list = $1;
    @builtins = split /\s+/, $list;
}

@builtins = grep { !/^#/ && $_ ne '' } @builtins;

print "Found " . scalar(@builtins) . " builtins in check_qx.pl\n";

my $examples_dir = "$RealBin/sh2perl/examples";
opendir my $dh, $examples_dir or die "Cannot read $examples_dir: $!\n";
my @existing = grep { /\.sh$/ } readdir $dh;
closedir $dh;

print "Existing examples: " . scalar(@existing) . "\n\n";

# Check which builtins are covered
my %covered;
for my $ex (@existing) {
    open my $efh, '<', "$examples_dir/$ex" or next;
    my $ecode = do { local $/; <$efh> };
    close $efh;
    for my $b (@builtins) {
        if ($ecode =~ /\b\Q$b\E\b/) {
            $covered{$b} //= [];
            push @{$covered{$b}}, $ex;
        }
    }
}

my @missing;
for my $b (@builtins) {
    if (!$covered{$b}) {
        push @missing, $b;
    }
}

print "=== Fully covered builtins ===\n";
for my $b (sort keys %covered) {
    my @files = @{$covered{$b}};
    print "  $b: " . join(", ", @files) . "\n";
}

print "\n=== Missing builtins (no example at all) ===\n";
for my $b (@missing) {
    print "  $b\n";
}

print "\n--- Generating examples for missing builtins via pi ---\n";

my $examples_new_dir = "$RealBin/examples.new";
mkdir $examples_new_dir unless -d $examples_new_dir;

for my $b (@missing) {
    my $safe_name = $b =~ s/[^a-zA-Z0-9_-]/_/gr;
    my $out_file = "$examples_new_dir/${safe_name}-cmdsub.sh";

    if (-f $out_file) {
        print "  $b -> $out_file (already exists, skipping)\n";
        next;
    }

    # Collect documentation for this builtin
    my $help_text = '';
    # Try bash builtin 'help' first
    $help_text = `bash -c 'help $b' 2>/dev/null`;
    # Try 'man' for external commands if bash help didn't return anything useful
    if ($help_text eq '' || $help_text =~ /^$b: not found/) {
        $help_text = `man $b 2>/dev/null | col -b | head -80`;
    }
    # Try '$b --help' as last resort
    if ($help_text eq '') {
        $help_text = `$b --help 2>/dev/null | head -40`;
    }
    # Fallback to 'type' description
    if ($help_text eq '') {
        $help_text = `type $b 2>/dev/null`;
    }

    my $prompt = <<"END_PROMPT";
Create a minimal self-contained shell script example that demonstrates the '$b' command.

Requirements:
- The script should take NO arguments (self-contained, uses hardcoded paths).
- It should call '$b' with its most common flags/options and demonstrate correctness.
- Use actual files/symlinks that exist on this system (it's Debian Bookworm on aarch64).
- Each invocation should print debug-like output showing what the command returns.
- The script must be safe to run (no rm -rf, no destructive operations).
- Save it to $out_file.
- The script will be used as a test case for the shell-to-Perl translator.
- Ignore options like --version, --help and anything that goes to stderr.

Documentation for '$b':
$help_text
Create the file now.
END_PROMPT

    print "  Generating example for '$b'...\n";
    my $prompt_file = '/tmp/pi_prompt_missing.txt';
    open my $pfh, '>', $prompt_file or warn "Cannot write $prompt_file: $!" and next;
    print $pfh $prompt;
    close $pfh;
    system('pi', '--print', '--provider', 'opencode-go', '--model', 'deepseek-v4-flash', '--thinking', 'xhigh', '@' . $prompt_file);
    print "\n";
}

print "\nDone.\n";
