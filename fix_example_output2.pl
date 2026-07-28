#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw(basename dirname);
use Cwd qw(abs_path);
$| = 1;

my $root = dirname(abs_path($0));
my $examples = "$root/sh2perl/examples";

# Find all .sh files
my @all = sort glob "$examples/*.sh";

my @need_fix;
for my $f (@all) {
    my $content = do { local $/; open my $fh, '<', $f or die $!; <$fh> };
    my $name = basename($f);

    # Find variables that capture command output: var=$(...)
    # These are the "result" variables whose value is the test output
    my @captured;
    while ($content =~ /^([a-zA-Z_][a-zA-Z0-9_]*)=\$\(/gm) {
        push @captured, $1;
    }
    # Also var="$(...)"
    while ($content =~ /^([a-zA-Z_][a-zA-Z0-9_]*)=\"\$\(/gm) {
        push @captured, $1;
    }

    next unless @captured;

    # Check if any captured variable is never displayed
    my @undisplayed;
    for my $v (@captured) {
        # Variable is referenced in echo/printf/cat after its definition
        my $rest = substr($content, pos($content) // 0);
        if ($content =~ /\$\{?\Q$v\E\}?/) {
            # Check if it's used in output context
            my $after_def = $';
            next if $after_def =~ /echo\s+.*\$\{?\Q$v\E\}?/s || $after_def =~ /printf\s+.*\$\{?\Q$v\E\}?/s;
        }
        push @undisplayed, $v;
    }

    next unless @undisplayed;

    # Find the insertion point: before the last echo/printf/exit, or at end
    my $insert_before = '';
    if ($content =~ /\n(echo\s|printf\s|exit\s|done|fi|esac)[^}]*\n?$/) {
        $insert_before = $1;
    }

    push @need_fix, {
        file => $f,
        name => $name,
        vars => \@undisplayed,
        content => $content,
    };
}

print "Found " . scalar(@need_fix) . " tests with undisplayed captured variables\n";

for my $t (@need_fix) {
    print "  $t->{name}: \$" . join(', $', @{$t->{vars}}) . "\n";
}

if (@need_fix == 0) {
    print "All tests display their captured variables. Nothing to fix.\n";
    exit 0;
}

# Build a prompt for pi
my $prompt = "Fix the following shell test scripts to print their captured variables to stdout.\n\n";
$prompt .= "For each script, find variables set via \$(...) command substitution and add a printf line\n";
$prompt .= "that outputs their value. Example:\n\n";
$prompt .= "  # Before:\n";
$prompt .= "  result=\$(echo \"hello\")\n";
$prompt .= "  echo done\n\n";
$prompt .= "  # After:\n";
$prompt .= "  result=\$(echo \"hello\")\n";
$prompt .= "  printf 'result=[%s]\\n' \"\$result\"\n\n";
$prompt .= "Add the printf before the final 'echo done' or at the end of the file.\n";
$prompt .= "Preserve the original test structure.\n\n";

for my $t (@need_fix) {
    $prompt .= "--- examples/$t->{name} ---\n";
    $prompt .= "Variables to display: " . join(', ', map { "\$$_" } @{$t->{vars}}) . "\n";
    $prompt .= "Current content:\n$t->{content}\n\n";
}

print "\nInvoking pi to fix ${\scalar(@need_fix)} tests...\n";

chdir "$root/sh2perl";

use JSON::PP;
my $pi_pid = open(my $pi_fh, '-|', 'pi', '--mode', 'json', '--provider', 'opencode-go', '--model', 'deepseek-v4-flash', '--thinking', 'high', $prompt);
if (defined $pi_fh) {
    my $buffer = '';
    while (<$pi_fh>) {
        $buffer .= $_;
        while ($buffer =~ s/^(.*)\n//) {
            my $line = $1;
            next if $line eq '';
            my $event = eval { JSON::PP::decode_json($line) };
            if ($@) { print STDERR "[JSON error]\n"; next; }
            next unless ref $event eq 'HASH';
            my $type = $event->{type} // '';
            if ($type eq 'message_update') {
                my $msg = $event->{assistantMessageEvent};
                next unless ref $msg eq 'HASH';
                my $dt = $msg->{delta} // '';
                my $et = $msg->{type} // '';
                if ($et eq 'text_delta' && length $dt) { print $dt; }
                elsif ($et eq 'tool_use_start') { print "\n[tool: $msg->{name}]\n"; }
            }
        }
    }
    close $pi_fh;
    print "\n";
} else {
    print STDERR "WARNING: Could not run pi: $!\n";
}
