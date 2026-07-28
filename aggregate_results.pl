#!/usr/bin/env perl
use strict;
use warnings;
use JSON::PP;

my %violation_counts;
my %violation_severity;
my %violation_example;
my $total_processed = 0;
my $total_violations = 0;

# Read exempted policies
my $CONF_FILE = "sh2perl/docs/perlcritic.conf";
my %exempted;
if (-f $CONF_FILE) {
    open my $fh, "<", $CONF_FILE or die;
    while (<$fh>) {
        chomp;
        if (/^\[-([^\]]+)\]/) {
            my $p = $1;
            $p =~ s/^Perl::Critic::Policy:://;
            $exempted{$p} = 1;
        }
    }
    close $fh;
}

for my $w (0..7) {
    my $f = ".pc_analysis_work/worker_${w}.jsonl";
    next unless -f $f && -s $f;
    open my $fh, "<", $f or next;
    while (<$fh>) {
        chomp;
        my ($status, $name, $data) = split /\t/, $_, 3;
        $total_processed++;
        next unless $status eq "OK" && $data;
        my $violations = decode_json($data);
        next unless ref $violations eq "ARRAY";
        for my $v (@$violations) {
            my $policy = $v->{policy};
            $violation_counts{$policy}++;
            $total_violations++;
            $violation_severity{$policy} = $v->{severity} unless exists $violation_severity{$policy};
            $violation_example{$policy} = $v->{desc} unless exists $violation_example{$policy};
        }
    }
    close $fh;
}

print "=" x 95, "\n";
print "PERL::CRITIC ANALYSIS OF sh/ FILES (no exemptions, severity 1)\n";
print "=" x 95, "\n\n";
print "Files processed: $total_processed / 1584 total\n";
print "Total violations: $total_violations\n";
print "Distinct policy types: " . (scalar keys %violation_counts) . "\n\n";

# Top violations
print "--- TOP VIOLATIONS BY POLICY (count >= 100) ---\n";
printf "%-65s %4s %8s  %s\n", "Policy", "Sev", "Count", "Exempted?";
print "-" x 95, "\n";
my @sorted = sort { $violation_counts{$b} <=> $violation_counts{$a} } keys %violation_counts;
for my $p (@sorted) {
    last if $violation_counts{$p} < 100;
    printf "%-65s %4s %8d  %s\n", $p, $violation_severity{$p}, $violation_counts{$p}, exists $exempted{$p} ? "YES" : "no";
}
print "\n";

# Exempted policy analysis
print "--- EXEMPTION ANALYSIS ---\n";
print "Currently exempted policies in perlcritic.conf:\n";
my $needed = 0; my $not_needed = 0;
for my $policy (sort keys %exempted) {
    my $count = $violation_counts{$policy} // 0;
    if ($count > 0) {
        printf "  [NEEDED]   %-55s %d violations\n", $policy, $count;
        $needed++;
    } else {
        printf "  [UNNEEDED] %-55s (0 violations in %d files)\n", $policy, $total_processed;
        $not_needed++;
    }
}
print "\nSummary: $needed genuinely needed, $not_needed may be removable\n\n";

# Fix suggestions
print "--- NON-EXEMPTED VIOLATIONS WITH FIX SUGGESTIONS ---\n";
print "These violations are currently visible even with the perlcritic.conf exemptions.\n";
print "They represent real issues that should be addressed in the generator.\n\n";

printf "%-65s %4s %8s  %s\n", "Policy", "Sev", "Count", "Fix Difficulty";
print "-" x 95, "\n";

for my $p (@sorted) {
    next if exists $exempted{$p};
    my $severity = $violation_severity{$p};
    my $count = $violation_counts{$p};
    my $fix = fix_difficulty($p);
    printf "%-65s %4s %8d  %s\n", $p, $severity, $count, $fix;
}

print "\n--- EXEMPTED POLICIES: EASE OF FIX IN GENERATOR ---\n";
print "If we removed these exemptions, could the generator be fixed?:\n\n";
for my $policy (sort keys %exempted) {
    my $count = $violation_counts{$policy} // 0;
    my $fix = fix_difficulty($policy);
    my $status = $count > 0 ? "$count violations" : "0 violations";
    printf "  %-55s %s  (%s)\n", $policy, $fix, $status;
}

sub fix_difficulty {
    my ($policy) = @_;
    
    # Direct policy matching
    return "EASY (add /x flag to regexes)" if $policy eq 'RegularExpressions::RequireExtendedFormatting';
    return "EASY (add /s flag to regexes)" if $policy eq 'RegularExpressions::RequireDotMatchAnything';
    return "EASY (add /m flag to regexes)" if $policy eq 'RegularExpressions::RequireLineBoundaryMatching';
    return "EASY (single-quote literal strings)" if $policy eq 'ValuesAndExpressions::ProhibitInterpolationOfLiterals';
    return "EASY (local \$CHILD_ERROR)" if $policy eq 'Variables::RequireLocalizedPunctuationVars';
    return "EASY (named constants)" if $policy eq 'ValuesAndExpressions::ProhibitMagicNumbers';
    return "EASY (add \$VERSION)" if $policy eq 'Modules::RequireVersionVar';
    return "EASY (run perltidy)" if $policy eq 'CodeLayout::RequireTidyCode';
    return "EASY (add \"or die\" after print)" if $policy eq 'InputOutput::RequireCheckedSyscalls';
    return "EASY (unused var analysis)" if $policy eq 'Variables::ProhibitUnusedVariables';
    return "EASY (pack @_ into vars)" if $policy eq 'Subroutines::RequireArgUnpacking';
    return "EASY (add \"1;\" at end)" if $policy eq 'Modules::RequireEndWithOne';
    return "EASY (add package decl)" if $policy eq 'Modules::RequireExplicitPackage';
    return "EASY (use croak/carp)" if $policy eq 'ErrorHandling::RequireCarping';
    return "EASY (init local vars)" if $policy eq 'Variables::RequireInitializationForLocalVars';
    return "EASY (use English names)" if $policy eq 'Variables::ProhibitPunctuationVars';
    return "EASY (q{} for single chars)" if $policy eq 'ValuesAndExpressions::ProhibitNoisyQuotes';
    return "EASY (q{} for empty strings)" if $policy eq 'ValuesAndExpressions::ProhibitEmptyQuotes';
    return "EASY (use \\n not literal newlines)" if $policy eq 'ValuesAndExpressions::ProhibitImplicitNewlines';
    return "EASY (braced filehandle)" if $policy eq 'InputOutput::RequireBracedFileHandleWithPrint';
    return "EASY (remove parens on builtins)" if $policy eq 'CodeLayout::ProhibitParensWithBuiltins';
    return "EASY (number underscores)" if $policy eq 'ValuesAndExpressions::RequireNumberSeparators';
    return "EASY (explicit return at end)" if $policy eq 'Subroutines::RequireFinalReturn';
    return "EASY (remove prototypes)" if $policy eq 'Subroutines::ProhibitSubroutinePrototypes';
    return "EASY (check close retval)" if $policy eq 'InputOutput::RequireCheckedClose';
    return "EASY (POSIX char classes)" if $policy eq 'RegularExpressions::ProhibitEnumeratedClasses';
    return "EASY (char class for escapes)" if $policy eq 'RegularExpressions::ProhibitEscapedMetacharacters';
    return "EASY (check match before captures)" if $policy eq 'RegularExpressions::ProhibitCaptureWithoutTest';
    return "EASY (reverse sort)" if $policy eq 'BuiltinFunctions::ProhibitReverseSortBlock';
    return "EASY (simplify sort block)" if $policy eq 'BuiltinFunctions::RequireSimpleSortBlock';
    return "EASY (remove unused topic)" if $policy eq 'BuiltinFunctions::ProhibitUselessTopic';
    return "EASY (rename vars)" if $policy eq 'NamingConventions::Capitalization';
    return "EASY (use strict/warnings already done)" if $policy eq 'TestingAndDebugging::RequireUseStrict';
    return "EASY (use strict/warnings already done)" if $policy eq 'TestingAndDebugging::RequireUseWarnings';
    
    return "MEDIUM (simplify map blocks)" if $policy eq 'BuiltinFunctions::ProhibitComplexMappings';
    return "MEDIUM (use List::Util::any)" if $policy eq 'BuiltinFunctions::ProhibitBooleanGrep';
    return "MEDIUM (unique var names)" if $policy eq 'Variables::ProhibitReusedNames';
    return "MEDIUM (remove dead code)" if $policy eq 'ControlStructures::ProhibitUnreachableCode';
    return "MEDIUM (three-arg open)" if $policy eq 'InputOutput::ProhibitTwoArgOpen';
    return "MEDIUM (move use to top)" if $policy eq 'Modules::ProhibitConditionalUseStatements';
    return "MEDIUM (conditionals outside declarations)" if $policy eq 'Variables::ProhibitConditionalDeclarations';
    return "MEDIUM (flat subs)" if $policy eq 'Subroutines::ProhibitNestedSubs';
    return "MEDIUM (double-sigil deref)" if $policy eq 'References::ProhibitDoubleSigils';
    return "MEDIUM (mismatched operators)" if $policy eq 'ValuesAndExpressions::ProhibitMismatchedOperators';
    return "MEDIUM (explicit interpolation)" if $policy eq 'ValuesAndExpressions::RequireInterpolationOfMetachars';
    return "MEDIUM (brief open handles)" if $policy eq 'InputOutput::RequireBriefOpen';
    return "MEDIUM (avoid package vars)" if $policy eq 'Variables::ProhibitPackageVars';
    
    return "HARD (refactor into functions)" if $policy eq 'Modules::ProhibitExcessMainComplexity';
    return "HARD (cascading if/elsif from bash elif)" if $policy eq 'ControlStructures::ProhibitCascadingIfElse';
    return "HARD (replace system()/exec())" if $policy eq 'BuiltinFunctions::ProhibitSystem';
    return "HARD (replace system()/exec())" if $policy eq 'BuiltinFunctions::ProhibitExec';
    return "HARD (IPC::Open3 instead of backticks)" if $policy eq 'InputOutput::ProhibitBacktickOperators';
    return "HARD (IO::Interactive)" if $policy eq 'InputOutput::ProhibitInteractiveTest';
    return "HARD (postfix controls natural for bash)" if $policy eq 'ControlStructures::ProhibitPostfixControls';
    
    return "ALREADY SATISFIED by generator boilerplate" if $policy =~ /RequireUseStrict|RequireUseWarnings/;
    
    return "N/A - not seen in violations";
}
