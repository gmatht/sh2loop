#!/usr/bin/env perl
use strict;
use warnings;
use File::Basename qw(basename);
use Cwd qw(abs_path);
use File::Basename qw(dirname);
use JSON::PP;

$| = 1;

my $root = dirname(abs_path($0));
my $examples = "$root/sh2perl/examples";
my @all_tests = sort glob "$examples/*.sh";
my $total = scalar @all_tests;

# Patterns that indicate insufficient output (just a status marker)
my @weak_patterns = (
    qr/^echo "?done"?$/im,
    qr/^echo "?ok"?$/im,
    qr/^echo "?test"?$/im,
    qr/^echo "?PASS"?$/im,
    qr/^printf '.*parsed OK/im,
    qr/^echo "?after heredoc"?$/im,
    qr/^echo "?heredoc done"?$/im,
);

print "Checking $total examples for sufficient stdout output...\n\n";

my @weak_tests;
for my $test (@all_tests) {
    my $name = basename($test);
    my $content = do { local $/; open my $fh, '<', $test or die $!; <$fh> };

    # Skip tests that already display actual variable values
    next if $content =~ /\$\{?[a-zA-Z_][a-zA-Z0-9_]*\}?/ && $content =~ /printf.*\$|echo.*\$/;

    # Check the last few lines for weak patterns
    my @lines = split "\n", $content;
    my $tail = @lines >= 3 ? join("\n", @lines[-3..-1]) : join("\n", @lines);

    for my $pat (@weak_patterns) {
        if ($tail =~ $pat) {
            push @weak_tests, {
                file => $name,
                tail => $tail,
                content => $content,
            };
            last;
        }
    }
}

my $weak_count = scalar @weak_tests;
print "Found $weak_count tests with insufficient output (only status markers, no actual values).\n\n";

if ($weak_count == 0) {
    print "All tests have sufficient output. Nothing to fix.\n";
    exit 0;
}

# Build a prompt for pi
my $prompt = "Fix the following $weak_count shell test scripts to output actual variable/file values instead of just status markers like 'done' or 'parsed OK'.\n\n";
$prompt .= "Guidelines:\n";
$prompt .= "- Replace echo \"done\" / echo \"ok\" / printf '...parsed OK\\n' with output that shows the actual computed value.\n";
$prompt .= "- If the script captures output to a variable (e.g. result=\$(...)), print that variable: printf 'result=[%s]\\n' \"\$result\"\n";
$prompt .= "- If the script writes to a file, read the file back and show its content or size.\n";
$prompt .= "- Preserve the original shell construct being tested — don't simplify the pattern.\n";
$prompt .= "- Keep each script minimal and focused on its original test case.\n";
$prompt .= "- Do NOT change anything outside examples/ directory.\n\n";
$prompt .= "Files to fix:\n";

for my $t (@weak_tests) {
    $prompt .= "\n--- examples/$t->{file} ---\n";
    $prompt .= "Current last lines:\n";
    $prompt .= "$t->{tail}\n";
    $prompt .= "Full content:\n";
    $prompt .= "$t->{content}\n";
}

print "Invoking pi to fix $weak_count tests...\n";

chdir "$root/sh2perl";

my $pi_pid = open(my $pi_fh, '-|', 'pi', '--mode', 'json', '--provider', 'opencode-go', '--model', 'deepseek-v4-flash', '--thinking', 'high', $prompt);
if (defined $pi_pid) {
    my $buffer = '';
    while (<$pi_fh>) {
        $buffer .= $_;
        while ($buffer =~ s/^(.*)\n//) {
            my $line = $1;
            next if $line eq '';
            my $event = eval { JSON::PP::decode_json($line) };
            if ($@) { print STDERR "[JSON parse error: $@]\n"; next; }
            next unless ref $event eq 'HASH';
            my $type = $event->{type} // '';
            if ($type eq 'message_update') {
                my $msg = $event->{assistantMessageEvent};
                next unless ref $msg eq 'HASH';
                my $event_type = $msg->{type} // '';
                my $delta = $msg->{delta} // '';
                if ($event_type eq 'text_delta' && length $delta) {
                    print $delta;
                } elsif ($event_type eq 'tool_use_start') {
                    my $name = $msg->{name} // '?';
                    print "\n[using tool: $name]\n";
                }
            }
        }
    }
    close $pi_fh;
    print "\n";
} else {
    print STDERR "WARNING: Could not run pi: $!\n";
}

print "\nDone. Now run update_blessed.sh to commit and bless.\n";
