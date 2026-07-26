#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use IPC::Open3;

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

print "Testing ambiguous operators...\n";
my $result;
my @result;
my %result;
$result = eval { int(2**3**2) } // "";
do {
    my $__echo_line = "2**3**2 = $result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
print "Testing complex parameter expansions...\n";
my $complex_var;
my @complex_var;
my %complex_var;
$complex_var = "hello world";
print ${complex_var} =~ s/^.*?o//r;
if ( !( (${complex_var} =~ s/^.*?o//r) =~ m{\n\z}msx ) ) { print "\n"; }
print ${complex_var} =~ s/^.*o//sr;
if ( !( (${complex_var} =~ s/^.*o//sr) =~ m{\n\z}msx ) ) { print "\n"; }
do {
    my $__echo_line = scalar reverse( (scalar reverse ${complex_var}) =~ s/^.*?o//r );
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
print ${complex_var} =~ s/o.*$//sr;
if ( !( (${complex_var} =~ s/o.*$//sr) =~ m{\n\z}msx ) ) { print "\n"; }
print "Testing complex here-documents...\n";
print q{This is a test line
This is not a test line
This is another test line
};
print "Testing nested arithmetic...\n";
$result = eval { int( (2 + 3) * (4 - 1) + (5 ** 2) ) } // "";
do {
    my $__echo_line = "Complex arithmetic: $result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
print "Testing nested command substitution...\n";
do {
    my $__echo_line = "Current dir: " . (defined (defined ($ENV{PWD} // q{}) && ($ENV{PWD} // q{}) ne q{} ? ($ENV{PWD} // q{}) : do { my $_result = do { use Cwd; getcwd(); }; $_result; }) && (defined ($ENV{PWD} // q{}) && ($ENV{PWD} // q{}) ne q{} ? ($ENV{PWD} // q{}) : do { my $_result = do { use Cwd; getcwd(); }; $_result; }) ne q{} ? (defined ($ENV{PWD} // q{}) && ($ENV{PWD} // q{}) ne q{} ? ($ENV{PWD} // q{}) : do { my $_result = do { use Cwd; getcwd(); }; $_result; }) : do { my $_result = do { use Cwd; getcwd(); }; $_result; });
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
do {
    my $__echo_line = "User: " . (defined (defined ($ENV{USER} // q{}) && ($ENV{USER} // q{}) ne q{} ? ($ENV{USER} // q{}) : do { my $_result = do { my $whoami_user = (getpwuid($<))[0]; $whoami_user . "\n"; }; $_result; }) && (defined ($ENV{USER} // q{}) && ($ENV{USER} // q{}) ne q{} ? ($ENV{USER} // q{}) : do { my $_result = do { my $whoami_user = (getpwuid($<))[0]; $whoami_user . "\n"; }; $_result; }) ne q{} ? (defined ($ENV{USER} // q{}) && ($ENV{USER} // q{}) ne q{} ? ($ENV{USER} // q{}) : do { my $_result = do { my $whoami_user = (getpwuid($<))[0]; $whoami_user . "\n"; }; $_result; }) : do { my $_result = do { my $whoami_user = (getpwuid($<))[0]; $whoami_user . "\n"; }; $_result; });
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
print "Testing process substitution...\n";
print "Testing complex brace expansion...\n";
print join(q[ ], ('a' . '1' . 'x', 'a' . '1' . 'y', 'a' . '1' . 'z', 'a' . '2' . 'x', 'a' . '2' . 'y', 'a' . '2' . 'z', 'a' . '3' . 'x', 'a' . '3' . 'y', 'a' . '3' . 'z', 'b' . '1' . 'x', 'b' . '1' . 'y', 'b' . '1' . 'z', 'b' . '2' . 'x', 'b' . '2' . 'y', 'b' . '2' . 'z', 'b' . '3' . 'x', 'b' . '3' . 'y', 'b' . '3' . 'z', 'c' . '1' . 'x', 'c' . '1' . 'y', 'c' . '1' . 'z', 'c' . '2' . 'x', 'c' . '2' . 'y', 'c' . '2' . 'z', 'c' . '3' . 'x', 'c' . '3' . 'y', 'c' . '3' . 'z')) . "\n";
$CHILD_ERROR = 0;
print "Testing simple case patterns...\n";
if ("$_[0]" =~ /^test$/msx) {
        print "Matched test\n";
} elsif (1) {
        print "Default case\n";
}

sub complex_function {
    my $param1 = "$_[0]";
    my $param2 = (defined (defined $_[1] && $_[1] ne q{} ? $_[1] : 'default') && (defined $_[1] && $_[1] ne q{} ? $_[1] : 'default') ne q{} ? (defined $_[1] && $_[1] ne q{} ? $_[1] : 'default') : 'default');
    my $param3 = $_[2] =~ s/"/\\"/grs;
    do {
    my $__echo_line = "Param1: $param1";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "Param2: $param2";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "Param3: $param3";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    my $result = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
        $output_0 .= $param1 . "\n";
        if ( !($output_0 =~ m{\n\z}msx) ) { $output_0 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
        my @sed_lines_0 = split /\n/msx, $output_0;
        my @sed_result_0;
        foreach my $line (@sed_lines_0) {
        chomp $line;
        push @sed_result_0, $line;
        }
        $output_0 = join "\n", @sed_result_0;

        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        $output_0 =~ s/\n+\z//msx;
        $output_0;
}; $_pipeline_result; };
    do {
    my $__echo_line = "Result: $result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    return;
}
print "Testing simple pipeline...\n";
# Original bash: ls -la | grep "^d" | head -5
{
    my $output_1 = q{};
    my $output_printed_1;
    my $pipeline_success_1 = 1;
        $output_1 = do { my @_qx_cmd = ('ls -la'); my $result = qx{$_qx_cmd[0]}; $CHILD_ERROR = $? >> 8; $result; };

        my $grep_result_1_1;
    my @grep_lines_1_1 = split /\n/msx, $output_1;
    my @grep_filtered_1_1 = grep { /^d/msx } @grep_lines_1_1;
    $grep_result_1_1 = join "\n", @grep_filtered_1_1;
    if (!($grep_result_1_1 =~ m{\n\z}msx || $grep_result_1_1 eq q{})) {
    $grep_result_1_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_1_1 > 0 ? 0 : 1;
    $output_1 = $grep_result_1_1;
    $output_1 = $grep_result_1_1;

        my $num_lines       = 5;
    my $head_line_count = 0;
    my $result          = q{};
    my $input           = $output_1;
    my $pos             = 0;
    while ( $pos < length $input && $head_line_count < $num_lines ) {
    my $line_end = index $input, "\n", $pos;
    if ( $line_end == -1 ) {
    $line_end = length $input;
    }
    my $head_line = substr $input, $pos, $line_end - $pos;
    $result .= $head_line . "\n";
    $pos = $line_end + 1;
    ++$head_line_count;
    }
    $output_1 = $result;
    if ($output_1 ne q{} && !defined $output_printed_1) {
        print $output_1;
        if (!($output_1 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
    }
print "Testing mixed arithmetic...\n";
my $hex;
my @hex;
my %hex;
$hex = '255';
my $octal;
my @octal;
my %octal;
$octal = '511';
my $binary;
my @binary;
my %binary;
$binary = '10';
$result = eval { int( $hex + $octal + $binary ) } // "";
do {
    my $__echo_line = "Mixed base result: $result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
print "Testing complex string interpolation...\n";
my $message;
my @message;
my %message;
$message = "Hello, " . (defined (defined ($ENV{USER} // q{}) && ($ENV{USER} // q{}) ne q{} ? ($ENV{USER} // q{}) : do { my $_result = do { my $whoami_user = (getpwuid($<))[0]; $whoami_user . "\n"; }; $_result; }) && (defined ($ENV{USER} // q{}) && ($ENV{USER} // q{}) ne q{} ? ($ENV{USER} // q{}) : do { my $_result = do { my $whoami_user = (getpwuid($<))[0]; $whoami_user . "\n"; }; $_result; }) ne q{} ? (defined ($ENV{USER} // q{}) && ($ENV{USER} // q{}) ne q{} ? ($ENV{USER} // q{}) : do { my $_result = do { my $whoami_user = (getpwuid($<))[0]; $whoami_user . "\n"; }; $_result; }) : do { my $_result = do { my $whoami_user = (getpwuid($<))[0]; $whoami_user . "\n"; }; $_result; }) . "! Your home is " . (defined (defined ($ENV{HOME} // q{}) && ($ENV{HOME} // q{}) ne q{} ? ($ENV{HOME} // q{}) : do { my $_result = (q{~}); $_result; }) && (defined ($ENV{HOME} // q{}) && ($ENV{HOME} // q{}) ne q{} ? ($ENV{HOME} // q{}) : do { my $_result = (q{~}); $_result; }) ne q{} ? (defined ($ENV{HOME} // q{}) && ($ENV{HOME} // q{}) ne q{} ? ($ENV{HOME} // q{}) : do { my $_result = (q{~}); $_result; }) : do { my $_result = (q{~}); $_result; });
print $message;
if ( !( ($message) =~ m{\n\z}msx ) ) { print "\n"; }
print "Testing simple test expressions...\n";
if ((-f "file.txt")) {
    print "File exists\n";
}
else {
    print "File does not exist\n";
}
print "Testing complex array operations...\n";
my @array = ('item1', 'item2', 'item3');
push @array, 'item4';
print "Array: " . (join(" ", @array)) . "\n";
$CHILD_ERROR = 0;
print "Length: " . scalar(@array) . "\n";
$CHILD_ERROR = 0;
do {
    my $__echo_line = "First item: " . $array[0];
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;

sub test_locals {
    my $var1 = "$_[0]";
    my $var2 = (defined (defined $_[1] && $_[1] ne q{} ? $_[1] : 'default_value') && (defined $_[1] && $_[1] ne q{} ? $_[1] : 'default_value') ne q{} ? (defined $_[1] && $_[1] ne q{} ? $_[1] : 'default_value') : 'default_value');
    my $var3 = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$var1") . "\n";
    my $set1_3 = '[:lower:]';
my $set2_3 = '[:upper:]';
my $input_3 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_3 = $set1_3;
my $expanded_set2_3 = $set2_3;
# Handle a-z range in set1
if ($expanded_set1_3 =~ /a-z/msx) {
    $expanded_set1_3 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_3 =~ /A-Z/msx) {
    $expanded_set1_3 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_3 =~ /\[:upper:\]/msx) {
    $expanded_set1_3 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_3 =~ /\[:lower:\]/msx) {
    $expanded_set1_3 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_3 =~ /a-z/msx) {
    $expanded_set2_3 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_3 =~ /A-Z/msx) {
    $expanded_set2_3 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_3 =~ /\[:upper:\]/msx) {
    $expanded_set2_3 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_3 =~ /\[:lower:\]/msx) {
    $expanded_set2_3 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_2 = q{};
for my $char ( split //msx, $input_3 ) {
    my $pos_3 = index $expanded_set1_3, $char;
    if ( $pos_3 >= 0 && $pos_3 < length $expanded_set2_3 ) {
        $tr_result_2 .= substr $expanded_set2_3, $pos_3, 1;
    } else {
        $tr_result_2 .= $char;
    }
}
$tr_result_2
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
    do {
    my $__echo_line = "Var1: $var1";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "Var2: $var2";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "Var3: $var3";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    return;
}
complex_function("test\"quote", "second_param", "third\"param");
test_locals("hello", "world");

exit $main_exit_code;
