#!/usr/bin/env perl
use strict;
use warnings;
use File::Temp qw(tempfile);
use File::Basename qw(basename);
use Cwd qw(realpath);
use JSON::PP;

#==============================================================================
# analyze_pc.pl - Analyze Perl Critic violations across all generated Perl files
#
# Tests all sh/ files by:
#   1. Converting to Perl via otranspilerl
#   2. Running perlcritic with NO exemptions (--severity 1)
#   3. Categorizing all violations
#   4. Comparing with currently exempted policies
#==============================================================================

my $ROOT     = realpath("$FindBin::RealBin");
my $SH_DIR   = "$ROOT/sh";
my $OTRANSPILERL = "$ROOT/otranspilerl/target/release/otranspilerl-cli";

die "ERROR: $SH_DIR not found\n" unless -d $SH_DIR;
die "ERROR: $OTRANSPILERL not found\n" unless -x $OTRANSPILERL;

# Read the current perlcritic.conf to get exempted policies
my $CONF_FILE = "$ROOT/sh2perl/docs/perlcritic.conf";
my %exempted_policies;
if (-f $CONF_FILE) {
    open my $fh, '<', $CONF_FILE or die "Cannot read $CONF_FILE: $!";
    while (<$fh>) {
        chomp;
        if (/^\[-([^\]]+)\]/) {
            $exempted_policies{$1} = 1;
        }
    }
    close $fh;
}

print "=" x 80, "\n";
print "Perl::Critic Violation Analysis\n";
print "=" x 80, "\n";
print "Testing directory: $SH_DIR\n";
print "Currently exempted policies in perlcritic.conf: " . (scalar keys %exempted_policies) . "\n\n";

# Process files
my @sh_files = sort glob("$SH_DIR/*");
my $total = scalar @sh_files;
print "Processing $total files...\n\n";

# Collect all violations
my %violation_counts;   # policy_name => count
my %violation_files;    # policy_name => { file => [locations] }
my %violation_details;  # policy_name => { severity => N, description => "...", example => "..." }

my $processed = 0;
my $failed = 0;

foreach my $sh_file (@sh_files) {
    my $name = basename($sh_file);
    $processed++;
    printf "\r  [%d/%d] %-60s", $processed, $total, $name;
    
    # Create temp file for Perl output
    my ($tmp_fh, $tmp_path) = tempfile("pc_analyze-XXXXXXXX", SUFFIX => '.pl', UNLINK => 1);
    close $tmp_fh;
    
    # Convert to Perl
    my $gen_cmd = "$OTRANSPILERL '$sh_file' '$tmp_path' 2>/dev/null";
    my $gen_out = `$gen_cmd`;
    if ($? != 0 || !-s $tmp_path) {
        $failed++;
        unlink $tmp_path if -f $tmp_path;
        next;
    }
    
    # Run perlcritic with ALL severities, no exemptions
    my $critic_cmd = "perlcritic --severity 1 '$tmp_path' 2>/dev/null";
    my $critic_out = `$critic_cmd`;
    my $exit_code = $? >> 8;
    
    if ($exit_code != 0 && $critic_out ne '') {
        # Parse violations
        my @lines = split /\n/, $critic_out;
        foreach my $line (@lines) {
            next if $line =~ /^Source OK/;
            next if $line =~ /^\s*$/;
            
            # Parse: "PolicyName at line X, column Y. Description (Severity: N)"
            if ($line =~ /^(.+) at line (\d+), column (\d+)\.\s*(.*?)\s*\(Severity:\s*(\d+)\)\s*$/) {
                my ($policy_full, $line_num, $col_num, $desc, $sev) = ($1, $2, $3, $4, $5);
                # Extract short policy name
                my $policy = $policy_full;
                $policy =~ s/.*:://;  # Get last part after ::
                
                my $full_policy = $policy_full;
                $full_policy =~ s/^Perl::Critic::Policy:://;
                
                $violation_counts{$full_policy}++;
                $violation_files{$full_policy}{$name} = [] unless exists $violation_files{$full_policy}{$name};
                push @{$violation_files{$full_policy}{$name}}, "L$line_num:C$col_num";
                
                unless (exists $violation_details{$full_policy}) {
                    $violation_details{$full_policy} = {
                        severity => $sev,
                        description => $desc,
                        example_line => $line,
                    };
                }
            }
        }
    }
    
    unlink $tmp_path if -f $tmp_path;
}

print "\n\n";

# ===========================================================================
# REPORT
# ===========================================================================
print "=" x 80, "\n";
print "VIOLATION REPORT (sorted by frequency)\n";
print "=" x 80, "\n";
printf "%-70s %8s %10s  %s\n", "Policy", "Severity", "Count", "Exempted?";
print "-" x 80, "\n";

my @sorted_policies = sort { $violation_counts{$b} <=> $violation_counts{$a} } keys %violation_counts;
my $grand_total = 0;

foreach my $policy (@sorted_policies) {
    my $count = $violation_counts{$policy};
    my $sev = $violation_details{$policy}{severity};
    my $is_exempted = exists $exempted_policies{$policy} ? "YES (in conf)" : "no";
    my $desc = $violation_details{$policy}{description};
    $grand_total += $count;
    printf "%-70s %8s %10d  %s\n", $policy, $sev, $count, $is_exempted;
    # Show truncated description
    my $short_desc = substr($desc, 0, 120);
    print "  -> $short_desc\n" if length($short_desc) > 0;
    print "\n";
}

print "-" x 80, "\n";
printf "%-70s %8s %10d\n", "TOTAL", "", $grand_total;
print "-" x 80, "\n\n";

# ===========================================================================
# EXEMPTION ANALYSIS
# ===========================================================================
print "=" x 80, "\n";
print "EXEMPTION ANALYSIS\n";
print "=" x 80, "\n\n";

# Which exempted policies actually have violations?
print "--- Exempted policies that ARE needed (have violations) ---\n";
my $needed = 0;
foreach my $policy (sort keys %exempted_policies) {
    if (exists $violation_counts{$policy}) {
        printf "  %-70s %d violations\n", $policy, $violation_counts{$policy};
        $needed++;
    }
}
if ($needed == 0) { print "  (none)\n"; }

print "\n--- Exempted policies that are NOT needed (no violations) ---\n";
my $not_needed = 0;
foreach my $policy (sort keys %exempted_policies) {
    unless (exists $violation_counts{$policy}) {
        printf "  %-70s (0 violations in all $processed files)\n", $policy;
        $not_needed++;
    }
}
if ($not_needed == 0) { print "  (none)\n"; }

printf "\n  Summary: %d needed, %d potentially unnecessary out of %d exempted policies\n", 
    $needed, $not_needed, scalar(keys %exempted_policies);

print "\n--- Non-exempted policies that DO have violations ---\n";
my $non_exempted = 0;
foreach my $policy (@sorted_policies) {
    unless (exists $exempted_policies{$policy}) {
        printf "  %-70s %d violations (severity %s)\n", $policy, $violation_counts{$policy}, $violation_details{$policy}{severity};
        $non_exempted++;
    }
}
if ($non_exempted == 0) { print "  (none)\n"; }

# ===========================================================================
# EASY FIX ANALYSIS
# ===========================================================================
print "\n", "=" x 80, "\n";
print "EASY-TO-FIX CATEGORIES\n";
print "=" x 80, "\n\n";

# Group policies by ease of fixing in the generator
print "--- Policies that could be fixed in the Perl generator ---\n";
my %fix_categories = (
    'ValuesAndExpressions::ProhibitMagicNumbers' => 'Easy - Generate named constants instead of magic numbers like 3, -1, 5',
    'CodeLayout::RequireTidyCode' => 'Easy - Run perltidy on generated output',
    'Modules::RequireVersionVar' => 'Easy - Add $VERSION to generated scripts',
    'ValuesAndExpressions::ProhibitInterpolationOfLiterals' => 'Easy - Use single quotes instead of double quotes for literal strings',
    'ValuesAndExpressions::RequireInterpolationOfMetachars' => 'Easy - Add escape sequences to make interpolation explicit',
    'InputOutput::ProhibitTwoArgOpen' => 'Medium - Use three-arg open with explicit mode',
    'InputOutput::RequireCheckedSyscalls' => 'Hard - Add error checking after print/open/close',
    'Variables::RequireLocalizedPunctuationVars' => 'Easy - Use "local $CHILD_ERROR;" instead of just $CHILD_ERROR',
    'Subroutines::ProhibitSubroutinePrototypes' => 'Easy - Use function signatures instead of prototypes',
    'Modules::ProhibitExcessMainComplexity' => 'Hard - Refactor main code into smaller functions',
    'Modules::RequireEndWithOne' => 'Easy - Add "1;" at end of generated scripts',
    'Modules::RequireExplicitPackage' => 'Easy - Add package declaration',
    'BuiltinFunctions::RequireSimpleSortBlock' => 'Easy - Simplify sort blocks',
    'BuiltinFunctions::ProhibitReverseSortBlock' => 'Easy - Use "reverse sort" instead of sort { $b <=> $a }',
    'BuiltinFunctions::ProhibitComplexMappings' => 'Medium - Simplify map blocks or use foreach loops',
    'Variables::RequireInitializationForLocalVars' => 'Easy - Initialize local variables',
    'Variables::ProhibitUnusedVariables' => 'Medium - Track variable usage and eliminate unused ones',
    'Modules::ProhibitConditionalUseStatements' => 'Medium - Move use statements to top of file',
    'InputOutput::RequireBriefOpen' => 'Medium - Minimize open handle duration',
    'RegularExpressions::RequireDotMatchAnything' => 'Easy - Add /s flag to regexes',
    'RegularExpressions::RequireExtendedFormatting' => 'Easy - Add /x flag to regexes',
    'RegularExpressions::RequireLineBoundaryMatching' => 'Easy - Add /m flag to regexes',
    'CodeLayout::ProhibitParensWithBuiltins' => 'Easy - Remove parens from builtin functions',
    'ControlStructures::ProhibitPostfixControls' => 'Easy - Convert postfix controls to block form',
    'ControlStructures::ProhibitCascadingIfElse' => 'Hard - Use dispatch table or given/when',
    'ControlStructures::ProhibitUnreachableCode' => 'Medium - Remove unreachable code after return',
    'ValuesAndExpressions::ProhibitImplicitNewlines' => 'Easy - Use \n instead of literal newlines in strings',
    'ValuesAndExpressions::ProhibitEmptyQuotes' => 'Easy - Use q{} for empty strings',
    'ValuesAndExpressions::ProhibitNoisyQuotes' => 'Easy - Use q{} for single-char strings',
    'ValuesAndExpressions::ProhibitMismatchedOperators' => 'Medium - Ensure numeric vs string operator correctness',
    'BuiltinFunctions::ProhibitUselessTopic' => 'Medium - Avoid implicit $_ use',
    'BuiltinFunctions::ProhibitBooleanGrep' => 'Medium - Use "any" or "first" from List::Util',
    'InputOutput::ProhibitBacktickOperators' => 'Hard - Use IPC::Open3 instead of backticks',
    'InputOutput::RequireCheckedClose' => 'Easy - Check close() return value',
    'RegularExpressions::ProhibitEnumeratedClasses' => 'Easy - Use POSIX character classes',
    'RegularExpressions::ProhibitEscapedMetacharacters' => 'Easy - Use character classes instead of escapes',
    'RegularExpressions::ProhibitCaptureWithoutTest' => 'Easy - Test match before using captures',
    'References::ProhibitDoubleSigils' => 'Medium - Use -> instead of @{$ref}',
    'Variables::ProhibitReusedNames' => 'Medium - Use unique variable names across scopes',
    'Variables::ProhibitPunctuationVars' => 'Easy - Use English module names',
    'Variables::ProhibitConditionalDeclarations' => 'Medium - Restructure to avoid conditional my',
    'ErrorHandling::RequireCarping' => 'Easy - Use croak/carp instead of die/warn',
    'Subroutines::RequireArgUnpacking' => 'Easy - Use shift or @_ assignment',
    'Subroutines::ProhibitNestedSubs' => 'Medium - Move nested subs to outer scope',
    'InputOutput::RequireBracedFileHandleWithPrint' => 'Easy - Use braced filehandle with print',
    'ValuesAndExpressions::RequireNumberSeparators' => 'Easy - Add underscores to large numbers',
    'Subroutines::RequireFinalReturn' => 'Easy - Ensure explicit return at end of subs',
    'BuiltinFunctions::ProhibitSystem' => 'Hard - Use IPC::Open3 instead of system()',
    'BuiltinFunctions::ProhibitExec' => 'Hard - Avoid exec(), use system() or IPC::Open3',
    'InputOutput::ProhibitInteractiveTest' => 'Easy - Use IO::Interactive',
    'TestingAndDebugging::RequireUseStrict' => 'Easy - Already included (no issue)',
    'TestingAndDebugging::RequireUseWarnings' => 'Easy - Already included (no issue)',
    'Variables::ProhibitPackageVars' => 'Medium - Avoid package variables',
);

foreach my $policy (@sorted_policies) {
    next if exists $exempted_policies{$policy};
    my $count = $violation_counts{$policy};
    my $easiness = $fix_categories{$policy} || 'Unknown - needs investigation';
    printf "  %-70s %6d  [%s]\n", $policy, $count, $easiness;
}

print "\n", "=" x 80, "\n";
print "SUMMARY\n";
print "=" x 80, "\n";
printf "Total sh/ files analyzed:    %d\n", $processed;
printf "Failed to convert:           %d\n", $failed;
printf "Total distinct policy types: %d\n", scalar(keys %violation_counts);
printf "Total violations found:      %d\n", $grand_total;
printf "Exempted policies (total):   %d\n", scalar(keys %exempted_policies);
printf "  - Needed (have violations): %d\n", $needed;
printf "  - Unnecessary (no viol's):  %d\n", $not_needed;
printf "Non-exempted violations:      %d policies\n", $non_exempted;
print "=" x 80, "\n";
