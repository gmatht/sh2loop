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

my $RUST_LLDB;
my @RUST_LLDB;
my %RUST_LLDB;
my $LLDB_VERSION;
my @LLDB_VERSION;
my %LLDB_VERSION;

$__set_e = 1;
my $host;
my @host;
my %host;
$host = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;

    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'rustc', '-vV');
    close $in_1 or croak 'Close failed: $OS_ERROR';
    $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
    my @sed_lines_0 = split /\n/msx, $output_0;
    my @sed_result_0;
    foreach my $line (@sed_lines_0) {
    chomp $line;
    push @sed_result_0, $line;
    }
    $output_0 = join "\n", @sed_result_0;

    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    exit $main_exit_code if $__set_e && $main_exit_code != 0;
    $output_0 =~ s/\n+\z//msx;
    $output_0;
}; $_pipeline_result; };
my $RUSTC_SYSROOT;
my @RUSTC_SYSROOT;
my %RUSTC_SYSROOT;
$RUSTC_SYSROOT = do {
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'rustc', '--print', 'sysroot');
    close $in_2 or croak 'Close failed: $OS_ERROR';
    my $result_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    $result_2
};
$RUST_LLDB = "$RUSTC_SYSROOT/lib/rustlib/$host/bin/lldb";
my $lldb;
my @lldb;
my %lldb;
$lldb = 'lldb';
if ((-f "$RUST_LLDB")) {
    $lldb = "$RUST_LLDB";
}
else {
if (!(!(do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('command', '-v', "$lldb") >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };))) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "$lldb not found! Please install it.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
exit 1;
}
    else {
        $LLDB_VERSION = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_3 = q{};
            my $output_printed_3;
            my $pipeline_success_3 = 1;

            my ($in_4, $out_4);
            my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'unknown_command', '--version');
            close $in_4 or croak 'Close failed: $OS_ERROR';
            $output_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
            close $out_4 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_4, 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_3 = 0; }
            my @lines_5 = split /\n/msx, $output_3;
            my @result_5;
            foreach my $line (@lines_5) {
            chomp $line;
            my @fields = split /\ /msx, $line;
            if (@fields > 2) {
                push @result_5, $fields[2];
            }
            }
            $output_3 = join "\n", @result_5;
            if ($output_3 ne q{} && !($output_3  =~ m{\n\z}msx)) { $output_3 .= "\n"; }

            if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            $output_3 =~ s/\n+\z//msx;
            $output_3;
}; $_pipeline_result; };
if ("$LLDB_VERSION" eq "3.5.0") {
print "***
WARNING: This version of LLDB has known issues with Rust and cannot display the contents of local variables!
***
";
        }
    }
}
my $script_import;
my @script_import;
my %script_import;
$script_import = "command script import \"$RUSTC_SYSROOT/lib/rustlib/etc/lldb_lookup.py\"";
my $commands_file;
my @commands_file;
my %commands_file;
$commands_file = "$RUSTC_SYSROOT/lib/rustlib/etc/lldb_commands";
# Builtin command 'exec' not implemented

exit $main_exit_code;
