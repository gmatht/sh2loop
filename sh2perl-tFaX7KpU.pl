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

my $MAGIC_8000 = 8_000;

$main_exit_code = system('cargo', 'run', '--bin', 'convert_examples') >> 8;
print "Checking if WASM rebuild is needed...\n";
if (!(!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('command', '-v', 'wasm-pack') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};))) {
    print "Installing wasm-pack...\n";
    $main_exit_code = system('cargo', 'install', 'wasm-pack') >> 8;
}
my $WASM_DIR;
my @WASM_DIR;
my %WASM_DIR;
$WASM_DIR = "www/pkg";
my $WASM_FILES;
my @WASM_FILES = ($WASM_DIR/debashl_bg.wasm, $WASM_DIR/debashl.js, $WASM_DIR/debashl.d.ts);
my %WASM_FILES;

sub needs_rebuild {
if ((!-d "$WASM_DIR")) {
        print "WASM directory doesn't exist, rebuild needed\n";
return q{0};
    }
    my $file;
    for my $file (@WASM_FILES) {
if ((!-f "$file")) {
            do {
    my $__echo_line = "Missing WASM file: $file, rebuild needed";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
return q{0};
        }
    }
    my $NEWEST_WASM;
    my @NEWEST_WASM;
    my %NEWEST_WASM;
    $NEWEST_WASM = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
        $output_0 = do {
            require File::Find;
            my @find_results;
            File::Find::find(sub { if ($_ =~ /^.*\.d\.ts$/msx) { push @find_results, $File::Find::name; } }, 'rintf');
            my $result = join "\n", @find_results;
            if ($result ne q{}) { $result .= "\n"; }
            $CHILD_ERROR = 0;
            $result;
        };
        if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
        my @sort_lines_0_1 = split /\n/msx, $output_0;
        my @sort_sorted_0_1 = sort {
            my @a_fields = split /\s+/msx, $a;
            my @b_fields = split /\s+/msx, $b;
            my $a_num = 0;
            my $b_num = 0;
            my $a_key = ( scalar @a_fields > 0 ) ? $a_fields[0] : q{}; $a_key =~ s/^\s+|\s+$//g;
            my $b_key = ( scalar @b_fields > 0 ) ? $b_fields[0] : q{}; $b_key =~ s/^\s+|\s+$//g;
            if ( $a_key =~ /^\d+(?:[.]\d+)?$/msx ) { $a_num = $a_key; }
            if ( $b_key =~ /^\d+(?:[.]\d+)?$/msx ) { $b_num = $b_key; }
            $a_num <=> $b_num || $a cmp $b
        } @sort_lines_0_1;
        $output_0 = join "\n", @sort_sorted_0_1;
                if ($output_0 ne q{} && !($output_0 =~ m{\n\z}msx)) {
                    $output_0 .= "\n";
                }
        my @lines = split /\n/msx, $output_0;
        my $num_lines = 1;
        if ($num_lines > scalar @lines) {
        $num_lines = scalar @lines;
        }
        my $start_index = scalar @lines - $num_lines;
        if ($start_index < 0) { $start_index = 0; }
        my @result = @lines[$start_index..$#lines];
        $output_0 = join "\n", @result;
        if ($output_0 ne q{} && !($output_0  =~ m{\n\z}msx)) { $output_0 .= "\n"; }

        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        $output_0 =~ s/\n+\z//msx;
        $output_0;
}; $_pipeline_result; };
    my $NEWEST_SOURCE;
    my @NEWEST_SOURCE;
    my %NEWEST_SOURCE;
    $NEWEST_SOURCE = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_1 = q{};
        my $output_printed_1;
        my $pipeline_success_1 = 1;
        $output_1 = do {
            require File::Find;
            my @find_results;
            File::Find::find(sub { if ($_ =~ /^.*\.rs$/msx) { push @find_results, $File::Find::name; } }, 'src/');
            my $result = join "\n", @find_results;
            if ($result ne q{}) { $result .= "\n"; }
            $CHILD_ERROR = 0;
            $result;
        };
        if ($CHILD_ERROR != 0) { $pipeline_success_1 = 0; }
        my @sort_lines_1_1 = split /\n/msx, $output_1;
        my @sort_sorted_1_1 = sort {
            my @a_fields = split /\s+/msx, $a;
            my @b_fields = split /\s+/msx, $b;
            my $a_num = 0;
            my $b_num = 0;
            my $a_key = ( scalar @a_fields > 0 ) ? $a_fields[0] : q{}; $a_key =~ s/^\s+|\s+$//g;
            my $b_key = ( scalar @b_fields > 0 ) ? $b_fields[0] : q{}; $b_key =~ s/^\s+|\s+$//g;
            if ( $a_key =~ /^\d+(?:[.]\d+)?$/msx ) { $a_num = $a_key; }
            if ( $b_key =~ /^\d+(?:[.]\d+)?$/msx ) { $b_num = $b_key; }
            $a_num <=> $b_num || $a cmp $b
        } @sort_lines_1_1;
        $output_1 = join "\n", @sort_sorted_1_1;
                if ($output_1 ne q{} && !($output_1 =~ m{\n\z}msx)) {
                    $output_1 .= "\n";
                }
        my @lines = split /\n/msx, $output_1;
        my $num_lines = 1;
        if ($num_lines > scalar @lines) {
        $num_lines = scalar @lines;
        }
        my $start_index = scalar @lines - $num_lines;
        if ($start_index < 0) { $start_index = 0; }
        my @result = @lines[$start_index..$#lines];
        $output_1 = join "\n", @result;
        if ($output_1 ne q{} && !($output_1  =~ m{\n\z}msx)) { $output_1 .= "\n"; }

        if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
        $output_1 =~ s/\n+\z//msx;
        $output_1;
}; $_pipeline_result; };
if (("$NEWEST_SOURCE"\>"$NEWEST_WASM")) {
        print "Source files are newer than WASM files, rebuild needed\n";
return q{0};
    }
    print "WASM files are up to date, no rebuild needed\n";
return q{1};
    return;
}
if (!(needs_rebuild())) {
    print "Building WASM target for debashc...\n";
    print "Compiling to WASM...\n";
    $main_exit_code = system('wasm-pack', 'build', '--target', 'web', '--out-dir', 'www/pkg') >> 8;
    use File::Path qw(make_path);
    my $err;
    if ( !-d 'www' ) {
        make_path( 'www', { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . 'www' . ": $err->[0]\n";
        }
    }
    print "WASM build complete!\n";
}
else {
    print "WASM is up to date, skipping build\n";
}
print "To run the demo:\n";
print "1. cd www\n";
print "2. python3 -m http.server 8000\n";
print "3. Open http://localhost:8000 in your browser\n";

exit $main_exit_code;
