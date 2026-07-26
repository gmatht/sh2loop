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

my $PERCENT_MEMORY;
my @PERCENT_MEMORY;
my %PERCENT_MEMORY;
my $pid;
my @pid;
my %pid;

my $PAGESIZE;
my @PAGESIZE;
my %PAGESIZE;
$PAGESIZE = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'getconf', 'PAGESIZE');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
my $TOTAL_MEMORY;
my @TOTAL_MEMORY;
my %TOTAL_MEMORY;
$TOTAL_MEMORY = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_1 = q{};
    my $output_printed_1;
    my $pipeline_success_1 = 1;
    $output_1 = do { my $cat_chunk = q{}; if ( open my $fh, '<', '/proc/meminfo' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/proc/meminfo' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
    if ($CHILD_ERROR != 0) { $pipeline_success_1 = 0; }
    my $num_lines       = 1;
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

    my @lines = split /\n/msx, $output_1;
    my @result;
    foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /^\s*$/msx) { next; }
        my @fields = split /\s+/msx, $line;
        push @result, ($fields[1] . "\n");
    }
    $output_1 = join "", @result;

    if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
    $output_1 =~ s/\n+\z//msx;
    $output_1;
}; $_pipeline_result; };
for my $pid (do {
    my $left_result_2 = do { chdir('/proc'); q{} };
;
    if ( $CHILD_ERROR == 0 ) {
        my $right_result_2 = do {
    my @ls_files_3 = ();
    my $ls_all_found_4 = 1;
    my @ls_inputs_5 = ();
    push @ls_inputs_5, '[0-9]';
    my @ls_glob_ls_inputs_5_1 = glob('*');
    if ( !@ls_glob_ls_inputs_5_1 ) {
        push @ls_inputs_5, '*';
        $ls_all_found_4 = 0;
    } else {
        push @ls_inputs_5, @ls_glob_ls_inputs_5_1;
    }
    my @ls_files_6 = ();
    my @ls_dirs_7 = ();
    my $ls_show_headers_8 = scalar(@ls_inputs_5) > 1;
    for my $ls_item_9 (@ls_inputs_5) {
        if ( -f $ls_item_9 ) {
            push @ls_files_6, $ls_item_9;
        }
        elsif ( -d $ls_item_9 ) {
            push @ls_dirs_7, $ls_item_9;
        }
        else {
            $ls_all_found_4 = 0;
        }
    }
    @ls_files_6 = sort { $a cmp $b } @ls_files_6;
    @ls_dirs_7 = sort { $a cmp $b } @ls_dirs_7;
    if (@ls_files_6) {
        push @ls_files_3, join("\n", @ls_files_6);
    }
    for my $ls_dir_10 (@ls_dirs_7) {
        my @ls_dir_entries_11 = ();
        if ( opendir my $dh, $ls_dir_10 ) {
            while ( my $file = readdir $dh ) {
                next if $file eq q{.} || $file eq q{..} || $file =~ /^[.]/msx;
                push @ls_dir_entries_11, $file;
            }
            closedir $dh;
            @ls_dir_entries_11 = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, do { (my $s = $_) =~ s{/$}{}msx; $s } ] } @ls_dir_entries_11;
            if ( $ls_show_headers_8 ) {
                if ( @ls_dir_entries_11 ) {
                    push @ls_files_3, $ls_dir_10 . ":\n" . join("\n", @ls_dir_entries_11);
                } else {
                    push @ls_files_3, $ls_dir_10 . ':';
                }
            }
            elsif ( @ls_dir_entries_11 ) {
                push @ls_files_3, join("\n", @ls_dir_entries_11);
            }
        }
        else {
            $ls_all_found_4 = 0;
        }
    }
    (@ls_files_3 ? join("\n\n", @ls_files_3) . "\n" : q{});
};
;
        $left_result_2 . $right_result_2;
    } else {
        q{};
    }
}) {
    # Original bash: #!/bin/sh
{
        my $output_12 = q{};
        my $output_printed_12;
        my $pipeline_success_12 = 1;
                my @_pcmd_14 = ('bash', '-c', ": \"Complex command cannot be converted to shell command\"");
        my ($in_13);
        my $pid_13 = open3($in_13, $out_13, '>&STDERR', @_pcmd_14);
        close $in_13 or croak 'Close failed: $OS_ERROR';
        my $temp_result;
        $temp_result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_13> };
        $output_12 = $temp_result;
        close $out_13 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_13, 0;

                my $set1_15 = "\n";
        my $set2_15 = "\t";
        my $input_15 = $output_12;
        # Expand character ranges for tr command
        my $expanded_set1_15 = $set1_15;
        my $expanded_set2_15 = $set2_15;
        # Handle a-z range in set1
        if ($expanded_set1_15 =~ /a-z/msx) {
        $expanded_set1_15 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set1
        if ($expanded_set1_15 =~ /A-Z/msx) {
        $expanded_set1_15 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set1
        if ($expanded_set1_15 =~ /\[:upper:\]/msx) {
        $expanded_set1_15 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set1
        if ($expanded_set1_15 =~ /\[:lower:\]/msx) {
        $expanded_set1_15 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle a-z range in set2
        if ($expanded_set2_15 =~ /a-z/msx) {
        $expanded_set2_15 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set2
        if ($expanded_set2_15 =~ /A-Z/msx) {
        $expanded_set2_15 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set2
        if ($expanded_set2_15 =~ /\[:upper:\]/msx) {
        $expanded_set2_15 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set2
        if ($expanded_set2_15 =~ /\[:lower:\]/msx) {
        $expanded_set2_15 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        my $tr_result_12_1 = q{};
        for my $char ( split //msx, $input_15 ) {
        my $pos_15 = index $expanded_set1_15, $char;
        if ( $pos_15 >= 0 && $pos_15 < length $expanded_set2_15 ) {
        $tr_result_12_1 .= substr $expanded_set2_15, $pos_15, 1;
        } else {
        $tr_result_12_1 .= $char;
        }
        }
        if (!($tr_result_12_1 =~ m{\n\z}msx || $tr_result_12_1 eq q{})) {
        $tr_result_12_1 .= "\n";
        }
        $output_12 = $tr_result_12_1;
        $output_12 = $tr_result_12_1;
        if ($output_12 ne q{} && !defined $output_printed_12) {
            print $output_12;
            if (!($output_12 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_12 ) { $main_exit_code = 1; }
        }
    print "\n";
    $CHILD_ERROR = 0;
}
$pid = } || $file =~ /^[.]/msx;
                push @ls_dir_entries_11, $file;
            }
            closedir $dh;
            @ls_dir_entries_11 = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, do { (my $s = $_) =~ s{/$}{}msx; $s } ] } @ls_dir_entries_11;
            if ( $ls_show_headers_8 ) {
                if ( @ls_dir_entries_11 ) {
                    push @ls_files_3, $ls_dir_10 . ":\n" . join("\n", @ls_dir_entries_11);
                } else {
                    push @ls_files_3, $ls_dir_10 . ':';
                }
            }
            elsif ( @ls_dir_entries_11 ) {
                push @ls_files_3, join("\n", @ls_dir_entries_11);
            }
        }
        else {
            $ls_all_found_4 = 0;
        }
    }
    (@ls_files_3 ? join("\n\n", @ls_files_3) . "\n" : q{});
};
;
        $left_result_2 . $right_result_2;
    } else {
        q{};
    }
};

exit $main_exit_code;
