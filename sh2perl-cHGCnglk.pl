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

my $dir_count;
my @dir_count;
my %dir_count;
my $value;
my @value;
my %value;
my $num;
my @num;
my %num;
my $file_count;
my @file_count;
my %file_count;
my $letter;
my @letter;
my %letter;

my $MAGIC_5  = 5;
my $MAGIC_3  = 3;
my $MAGIC_17 = 17;
my $MAGIC_42 = 42;

print "=== Advanced Bash Idioms Examples ===\n";
print "\n";
$CHILD_ERROR = 0;
print "1. Nested loops with conditional logic and array manipulation:\n";
my $numbers;
my @numbers = ('1', '2', '3', '4', '5');
my %numbers;
my $letters;
my @letters = ('a', 'b', 'c', 'd', 'e');
my %letters;
for my $num (@numbers) {
    for my $letter (@letters) {
if ((($num > $MAGIC_3) && $letter ne "c")) {
            do {
    my $__echo_line = "  Number $num with letter $letter (filtered)";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        }
    }
}
print "\n";
$CHILD_ERROR = 0;
print "2. Function with nested case statements and parameter expansion:\n";

sub process_data {
    my $data_type = "$_[0]";
    my $value = "$_[1]";
if ("$data_type" =~ /^string$/msx) {
        if (lc(lc(${value})) =~ /^hello$/msx or lc(lc(${value})) =~ /^hi$/msx) {
                        do {
    my $__echo_line = "  Greeting detected: $value";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        } elsif (lc(lc(${value})) =~ /^bye$/msx or lc(lc(${value})) =~ /^goodbye$/msx) {
                        do {
    my $__echo_line = "  Farewell detected: $value";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        } elsif (1) {
                        do {
    my $__echo_line = "  Unknown string: $value";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        }
    } elsif ("$data_type" =~ /^number$/msx) {
        if ("$value" =~ /^[0-9]+$/msx) {
if (eval { int($value % 2 == 0) } // "") {
                do {
    my $__echo_line = "  Even number: $value";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
}
            else {
                do {
    my $__echo_line = "  Odd number: $value";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
            }
}
        else {
            do {
    my $__echo_line = "  Invalid number: $value";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        }
    } elsif (1) {
                do {
    my $__echo_line = "  Unknown data type: $data_type";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
    return;
}
process_data("string", "Hello");
process_data("string", "Bye");
process_data("number", "42");
process_data("number", "17");
print "\n";
$CHILD_ERROR = 0;
print "3. Complex conditional with command substitution and arithmetic:\n";
$file_count = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;
    $output_0 = do {
        require File::Find;
        my @find_results;
        File::Find::find(sub { my $maxdepth = 1; my $depth = ($File::Find::dir =~ tr/\///) + 1; next if $depth > $maxdepth; if (-f $_) { push @find_results, $File::Find::name; } }, q{.});
        my $result = join "\n", @find_results;
        if ($result ne q{}) { $result .= "\n"; }
        $CHILD_ERROR = 0;
        $result;
    };
    if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
    $output_0 = do {
            my $_wc_data = $output_0;
            my $_wc_lines = () = $_wc_data =~ /\n/gsxm;
            my $_wc_result = q{};
            $_wc_result .= sprintf q{%d}, $_wc_lines;
            $_wc_result .= "\n";
            $_wc_result;
        };
    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    $output_0 =~ s/\n+\z//msx;
    $output_0;
}; $_pipeline_result; };
$dir_count = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_1 = q{};
    my $output_printed_1;
    my $pipeline_success_1 = 1;
    $output_1 = do {
        require File::Find;
        my @find_results;
        File::Find::find(sub { my $maxdepth = 1; my $depth = ($File::Find::dir =~ tr/\///) + 1; next if $depth > $maxdepth; if (-d $_) { push @find_results, $File::Find::name; } }, q{.});
        my $result = join "\n", @find_results;
        if ($result ne q{}) { $result .= "\n"; }
        $CHILD_ERROR = 0;
        $result;
    };
    if ($CHILD_ERROR != 0) { $pipeline_success_1 = 0; }
    $output_1 = do {
            my $_wc_data = $output_1;
            my $_wc_lines = () = $_wc_data =~ /\n/gsxm;
            my $_wc_result = q{};
            $_wc_result .= sprintf q{%d}, $_wc_lines;
            $_wc_result .= "\n";
            $_wc_result;
        };
    if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
    $output_1 =~ s/\n+\z//msx;
    $output_1;
}; $_pipeline_result; };
if ((($file_count > 0) && ($dir_count > 1))) {
if (eval { int($file_count > $dir_count) } // "") {
        do {
    my $__echo_line = "  More files ($file_count) than directories ($dir_count)";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
}
    else {
        if (eval { int($file_count == $dir_count) } // "") {
            do {
    my $__echo_line = "  Equal count: $file_count files and $dir_count directories";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
}
        else {
            do {
    my $__echo_line = "  More directories ($dir_count) than files ($file_count)";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        }
    }
}
else {
    print "  Insufficient items for comparison\n";
}
print "\n";
$CHILD_ERROR = 0;
print "4. Nested here-documents with parameter expansion:\n";
my $user;
my @user;
my %user;
$user = "admin";
my $host;
my @host;
my %host;
$host = "localhost";
my $port;
my @port;
my %port;
$port = "22";
print q{    SSH Configuration:
    $(cat <<'INNER'
        User: $user
        Host: $host
        Port: $port
        Status: $(ping -c 1 $host >/dev/null 2>&1 && echo "Online" || echo "Offline")
INNER
    )
};
print "\n";
$CHILD_ERROR = 0;
print "5. Array processing with nested loops and conditional logic:\n";
my %matrix = ();
$matrix{"0,0"} = q{1};
$matrix{"0,1"} = q{2};
$matrix{"0,2"} = q{3};
$matrix{"1,0"} = q{4};
$matrix{"1,1"} = q{5};
$matrix{"1,2"} = q{6};
$matrix{"2,0"} = q{7};
$matrix{"2,1"} = q{8};
$matrix{"2,2"} = q{9};
my $i;
for my $i ( 0 .. 2 ) {
    my $j;
    for my $j ( 0 .. 2 ) {
        $value = $matrix{"$i,$j"};
if (($value > $MAGIC_5)) {
            print "  [$value] ";
}
        else {
            print "  $value ";
        }
    }
    print "\n";
    $CHILD_ERROR = 0;
}
print "\n";
$CHILD_ERROR = 0;
print "6. Process substitution with nested commands and error handling:\n";
    do {
    my $__echo_line = "  First word: " . (($ENV{test_string} // q{}) =~ s/ .*$//sr =~ s/ .*$//sr);
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "  Last word: " . (($ENV{test_string} // q{}) =~ s/^.* //sr =~ s/^.* //sr);
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "  Middle: " . (($ENV{test_string} // q{}) =~ s/^.*? //r =~ s/^.*? //r);
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "  Middle: " . (scalar reverse( (scalar reverse ($ENV{test_string} // q{})) =~ s/^.*? //r ) =~ s/ .*?$//r);
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "  Uppercase: " . uc(uc(($ENV{test_string} // q{})));
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "  Lowercase: " . lc(lc(($ENV{test_string} // q{})));
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "  Capitalize: " . ucfirst(ucfirst(($ENV{test_string} // q{})));
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    print "\n";
    $CHILD_ERROR = 0;
    print "11. Complex arithmetic with nested expressions:\n";
    my $a;
    my @a;
    my %a;
    $a = '10';
    my $b;
    my @b;
    my %b;
    $b = q{5};
    my $c;
    my @c;
    my %c;
    $c = q{3};
    my $result;
    my @result;
    my %result;
    $result = eval { int( ($a + $b) * $c - ($a % $b) / $c ) } // "";
    print "  Expression: (a + b) * c - (a % b) / c\n";
    do {
    my $__echo_line = "  Values: a=$a, b=$b, c=$c";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "  Result: $result";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
if (eval { int(($a > $b) && ($b < $c) || ($a % 2 == 0)) } // "") {
        print "  Complex condition met: a > b AND (b < c OR a is even)\n";
    }
    print "\n";
    $CHILD_ERROR = 0;
    print "12. Nested command substitution with error handling:\n";
    do {
    my $__echo_line = "  Current directory: " . (do { my $_chomp_temp = do { use Cwd; getcwd(); }; chomp $_chomp_temp; $_chomp_temp; });
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "  Parent directory: " . (do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname((do { my $_chomp_temp = do { use Cwd; getcwd(); }; chomp $_chomp_temp; $_chomp_temp; })); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; });
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "  Home directory: " . (do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname((do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname((do { my $_chomp_temp = do { use Cwd; getcwd(); }; chomp $_chomp_temp; $_chomp_temp; })); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; })); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; });
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    my $file_info;
    my @file_info;
    my %file_info;
    $file_info = do {
    my $command = q{stat -c '%s %y' nonexistent_file 2> /dev/null || echo 'File not found'};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
};
    do {
    my $__echo_line = "  File info: $file_info";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    print "\n";
    $CHILD_ERROR = 0;
print "=== Advanced Bash Idioms Examples Complete ===\n";

exit $main_exit_code;
