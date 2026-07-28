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

my $TMPFILE;
my @TMPFILE;
my %TMPFILE;
my $USERFILTER;
my @USERFILTER;
my %USERFILTER;
my $BASH;
my @BASH;
my %BASH;
my $BASENAME;
my @BASENAME;
my %BASENAME;
my $LESSFILE;
my @LESSFILE;
my %LESSFILE;
my $CONFIGDIR;
my @CONFIGDIR;
my %CONFIGDIR;

my $MAGIC_77 = 77;

my $TMPDIR;
my @TMPDIR;
my %TMPDIR;
$TMPDIR = (defined ${TMPDIR} && ${TMPDIR} ne q{} ? ${TMPDIR} : '/tmp');
$CONFIGDIR = (defined ($ENV{XDG_CONFIG_HOME} // q{}) && ($ENV{XDG_CONFIG_HOME} // q{}) ne q{} ? ($ENV{XDG_CONFIG_HOME} // q{}) : '~/.config');
$BASENAME = do { use File::Basename qw(basename); my $basename_output = basename($PROGRAM_NAME); $CHILD_ERROR = 0; $basename_output; };
$LESSFILE = 'lessfile';

sub iso_list {
    my ($file) = @_;
    $main_exit_code = system('isoinfo', '-d', '-i', "$_[0]") >> 8;
    if (do {
{
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;
        my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'isoinfo', '-d', '-i');
    close $in_1 or croak 'Close failed: $OS_ERROR';
    $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;

        my $grep_result_0_1;
    my @grep_lines_0_1 = split /\n/msx, $output_0;
    my @grep_filtered_0_1 = grep { /^Rock[.]Ridge/msx } @grep_lines_0_1;
    $grep_result_0_1 = join "\n", @grep_filtered_0_1;
    if (!($grep_result_0_1 =~ m{\n\z}msx || $grep_result_0_1 eq q{})) {
    $grep_result_0_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_0_1 > 0 ? 0 : 1;
    $grep_result_0_1 = q{};
    $output_0 = q{};
    if ((scalar @grep_filtered_0_1) == 0) {
        $pipeline_success_0 = 0;
    }
    if ($output_0 ne q{} && !defined $output_printed_0) {
        print $output_0;
        if (!($output_0 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    }
        $CHILD_ERROR == 0
    }) {
                my $iiopts;
        my @iiopts;
        my %iiopts;
        $iiopts = "$iiopts -R";
    }
    if (do {
{
    my $output_2 = q{};
    my $output_printed_2;
    my $pipeline_success_2 = 1;
        my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'isoinfo', '-d', '-i');
    close $in_3 or croak 'Close failed: $OS_ERROR';
    $output_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;

        my $grep_result_2_1;
    my @grep_lines_2_1 = split /\n/msx, $output_2;
    my @grep_filtered_2_1 = grep { /^Joliet/msx } @grep_lines_2_1;
    $grep_result_2_1 = join "\n", @grep_filtered_2_1;
    if (!($grep_result_2_1 =~ m{\n\z}msx || $grep_result_2_1 eq q{})) {
    $grep_result_2_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_2_1 > 0 ? 0 : 1;
    $grep_result_2_1 = q{};
    $output_2 = q{};
    if ((scalar @grep_filtered_2_1) == 0) {
        $pipeline_success_2 = 0;
    }
    if ($output_2 ne q{} && !defined $output_printed_2) {
        print $output_2;
        if (!($output_2 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
    }
        $CHILD_ERROR == 0
    }) {
                $iiopts = "$iiopts -J";
    }
    print "\n";
    $CHILD_ERROR = 0;
    $main_exit_code = system('isoinfo', '-f', $iiopts, '-i', "$_[0]") >> 8;
    return;
}
if ((scalar(@ARGV) == 1)) {
if ((!-r "$1")) {
exit 0;
    }
    $main_exit_code = system('umask', '077') >> 8;
if ($BASENAME eq $LESSFILE) {
        $TMPFILE = do {
    my ($in_4, $out_4);
    my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'mktemp', '-p', $TMPDIR, 'lessfXXXXXX');
    close $in_4 or croak 'Close failed: $OS_ERROR';
    my $result_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
    close $out_4 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_4, 0;
    $result_4
};
if ("$TMPFILE" eq q{}) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                print "\n";
                $CHILD_ERROR = 0;
            };
            $main_exit_code = system('bash', 'TMPFILE variable is empty. Exiting') >> 8;
exit 1;
        }
    }
    do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
        do {
            local %ENV = %ENV;
            my $TMPDIR = $TMPDIR;
                $USERFILTER = q{};
if ((-x "$CONFIGDIR/lessfilter")) {
                    $USERFILTER = "$CONFIGDIR/lessfilter";
}
                else {
                    if ((-x '~/.lessfilter')) {
                        $main_exit_code = system('USERFILTER', '=~', '/.lessfilter') >> 8;
                    }
                }
if ("$USERFILTER" ne q{}) {
if ($BASENAME eq $LESSFILE) {
                        do {
                            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                            open STDOUT, '>', $TMPFILE
      or die "Cannot open file: $OS_ERROR\n";
                            my $tmp = do {
                            $CHILD_ERROR = 0;
                            };
                            print $tmp;
                            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                        };
if (($? == 0)) {
if (((-s $TMPFILE) > 0)) {
                                print $TMPFILE;
if ( !( ($TMPFILE) =~ m{\n\z}msx ) ) { print "\n"; }
}
                            else {
if ( -e "$TMPFILE" ) {
                                    if ( -d "$TMPFILE" ) {
                                        carp "rm: carping: ", $TMPFILE,
          " is a directory (use -r to remove recursively)\n";
                                    }
                                    else {
                                        if ( unlink "$TMPFILE" ) {
                                                                                    }
                                        else {
                                            carp "rm: carping: could not remove ", $TMPFILE,
              ": $OS_ERROR\n";
                                        }
                                    }
                                }
                                else {
                                    local $CHILD_ERROR = 0;
                                }
                            }
exit 0;
}
                        else {
if ( -e "$TMPFILE" ) {
                                if ( -d "$TMPFILE" ) {
                                    carp "rm: carping: ", $TMPFILE,
          " is a directory (use -r to remove recursively)\n";
                                }
                                else {
                                    if ( unlink "$TMPFILE" ) {
                                                                            }
                                    else {
                                        carp "rm: carping: could not remove ", $TMPFILE,
              ": $OS_ERROR\n";
                                    }
                                }
                            }
                            else {
                                local $CHILD_ERROR = 0;
                            }
                        }
}
                    else {
                        if (do {
$CHILD_ERROR = 0;
                            $CHILD_ERROR == 0
                        }) {
                            exit 0;
                        }
                    }
                }
if ($BASENAME eq $LESSFILE) {
                    do {
                        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>', $TMPFILE
      or die "Cannot open file: $OS_ERROR\n";
# Builtin command 'exec' not implemented
                        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                    };
                }
if (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_6 = '[:upper:]';
my $set2_6 = '[:lower:]';
my $input_6 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_6 = $set1_6;
my $expanded_set2_6 = $set2_6;
# Handle a-z range in set1
if ($expanded_set1_6 =~ /a-z/msx) {
    $expanded_set1_6 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_6 =~ /A-Z/msx) {
    $expanded_set1_6 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_6 =~ /\[:upper:\]/msx) {
    $expanded_set1_6 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_6 =~ /\[:lower:\]/msx) {
    $expanded_set1_6 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_6 =~ /a-z/msx) {
    $expanded_set2_6 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_6 =~ /A-Z/msx) {
    $expanded_set2_6 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_6 =~ /\[:upper:\]/msx) {
    $expanded_set2_6 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_6 =~ /\[:lower:\]/msx) {
    $expanded_set2_6 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_5 = q{};
for my $char ( split //msx, $input_6 ) {
    my $pos_6 = index $expanded_set1_6, $char;
    if ( $pos_6 >= 0 && $pos_6 < length $expanded_set2_6 ) {
        $tr_result_5 .= substr $expanded_set2_6, $pos_6, 1;
    } else {
        $tr_result_5 .= $char;
    }
}
$tr_result_5
}; $_pipeline_result; } =~ /^.*.a$/msx) {
                    if ((-x "`which ar`")) {
                        $main_exit_code = system('ar', 'tv', "$_[0]") >> 8;
}
                    else {
                        print "No ar available\n";
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_8 = '[:upper:]';
my $set2_8 = '[:lower:]';
my $input_8 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_8 = $set1_8;
my $expanded_set2_8 = $set2_8;
# Handle a-z range in set1
if ($expanded_set1_8 =~ /a-z/msx) {
    $expanded_set1_8 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_8 =~ /A-Z/msx) {
    $expanded_set1_8 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_8 =~ /\[:upper:\]/msx) {
    $expanded_set1_8 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_8 =~ /\[:lower:\]/msx) {
    $expanded_set1_8 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_8 =~ /a-z/msx) {
    $expanded_set2_8 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_8 =~ /A-Z/msx) {
    $expanded_set2_8 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_8 =~ /\[:upper:\]/msx) {
    $expanded_set2_8 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_8 =~ /\[:lower:\]/msx) {
    $expanded_set2_8 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_7 = q{};
for my $char ( split //msx, $input_8 ) {
    my $pos_8 = index $expanded_set1_8, $char;
    if ( $pos_8 >= 0 && $pos_8 < length $expanded_set2_8 ) {
        $tr_result_7 .= substr $expanded_set2_8, $pos_8, 1;
    } else {
        $tr_result_7 .= $char;
    }
}
$tr_result_7
}; $_pipeline_result; } =~ /^.*.arj$/msx) {
                    if ((-x "`which unarj`")) {
                        $main_exit_code = system('unarj', q{l}, "$_[0]") >> 8;
}
                    else {
                        print "No unarj available\n";
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_10 = '[:upper:]';
my $set2_10 = '[:lower:]';
my $input_10 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_10 = $set1_10;
my $expanded_set2_10 = $set2_10;
# Handle a-z range in set1
if ($expanded_set1_10 =~ /a-z/msx) {
    $expanded_set1_10 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_10 =~ /A-Z/msx) {
    $expanded_set1_10 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_10 =~ /\[:upper:\]/msx) {
    $expanded_set1_10 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_10 =~ /\[:lower:\]/msx) {
    $expanded_set1_10 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_10 =~ /a-z/msx) {
    $expanded_set2_10 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_10 =~ /A-Z/msx) {
    $expanded_set2_10 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_10 =~ /\[:upper:\]/msx) {
    $expanded_set2_10 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_10 =~ /\[:lower:\]/msx) {
    $expanded_set2_10 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_9 = q{};
for my $char ( split //msx, $input_10 ) {
    my $pos_10 = index $expanded_set1_10, $char;
    if ( $pos_10 >= 0 && $pos_10 < length $expanded_set2_10 ) {
        $tr_result_9 .= substr $expanded_set2_10, $pos_10, 1;
    } else {
        $tr_result_9 .= $char;
    }
}
$tr_result_9
}; $_pipeline_result; } =~ /^.*.tar.bz2$/msx) {
                    if ((-x "`which bunzip2`")) {
                        # Original bash: bunzip2 -dc "$1" | tar tvvf -
{
                            my $output_11 = q{};
                            my $output_printed_11;
                            my $pipeline_success_11 = 1;
                                                        my ($in_12, $out_12);
                            my $pid_12 = open3($in_12, $out_12, '>&STDERR', 'bunzip2', '-d', q{c});
                            close $in_12 or croak 'Close failed: $OS_ERROR';
                            $output_11 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_12> };
                            close $out_12 or croak 'Close failed: $OS_ERROR';
                            waitpid $pid_12, 0;

                                                        my $cmd_14 = 'tar';
                            my ($in_13, $out_13);
                            my $pid_13 = open3($in_13, $out_13, '>&STDERR', $cmd_14, 'tvvf', q{-});
                            print {$in_13} $output_11;
                            close $in_13 or croak 'Close failed: $OS_ERROR';
                            $output_11 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_13> };
                            close $out_13 or croak 'Close failed: $OS_ERROR';
                            waitpid $pid_13, 0;
                            if ($output_11 ne q{} && !defined $output_printed_11) {
                                print $output_11;
                                if (!($output_11 =~ m{\n\z}msx)) {
                                    print "\n";
                                }
                            }
                            if ( !$pipeline_success_11 ) { $main_exit_code = 1; }
                            }
}
                    else {
                        print "No bunzip2 available\n";
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_16 = '[:upper:]';
my $set2_16 = '[:lower:]';
my $input_16 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_16 = $set1_16;
my $expanded_set2_16 = $set2_16;
# Handle a-z range in set1
if ($expanded_set1_16 =~ /a-z/msx) {
    $expanded_set1_16 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_16 =~ /A-Z/msx) {
    $expanded_set1_16 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_16 =~ /\[:upper:\]/msx) {
    $expanded_set1_16 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_16 =~ /\[:lower:\]/msx) {
    $expanded_set1_16 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_16 =~ /a-z/msx) {
    $expanded_set2_16 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_16 =~ /A-Z/msx) {
    $expanded_set2_16 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_16 =~ /\[:upper:\]/msx) {
    $expanded_set2_16 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_16 =~ /\[:lower:\]/msx) {
    $expanded_set2_16 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_15 = q{};
for my $char ( split //msx, $input_16 ) {
    my $pos_16 = index $expanded_set1_16, $char;
    if ( $pos_16 >= 0 && $pos_16 < length $expanded_set2_16 ) {
        $tr_result_15 .= substr $expanded_set2_16, $pos_16, 1;
    } else {
        $tr_result_15 .= $char;
    }
}
$tr_result_15
}; $_pipeline_result; } =~ /^.*.bz$/msx) {
                    if ((-x "`which bunzip`")) {
                        $main_exit_code = system('bunzip', '-c', "$_[0]") >> 8;
}
                    else {
                        print "No bunzip available\n";
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_18 = '[:upper:]';
my $set2_18 = '[:lower:]';
my $input_18 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_18 = $set1_18;
my $expanded_set2_18 = $set2_18;
# Handle a-z range in set1
if ($expanded_set1_18 =~ /a-z/msx) {
    $expanded_set1_18 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_18 =~ /A-Z/msx) {
    $expanded_set1_18 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_18 =~ /\[:upper:\]/msx) {
    $expanded_set1_18 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_18 =~ /\[:lower:\]/msx) {
    $expanded_set1_18 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_18 =~ /a-z/msx) {
    $expanded_set2_18 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_18 =~ /A-Z/msx) {
    $expanded_set2_18 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_18 =~ /\[:upper:\]/msx) {
    $expanded_set2_18 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_18 =~ /\[:lower:\]/msx) {
    $expanded_set2_18 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_17 = q{};
for my $char ( split //msx, $input_18 ) {
    my $pos_18 = index $expanded_set1_18, $char;
    if ( $pos_18 >= 0 && $pos_18 < length $expanded_set2_18 ) {
        $tr_result_17 .= substr $expanded_set2_18, $pos_18, 1;
    } else {
        $tr_result_17 .= $char;
    }
}
$tr_result_17
}; $_pipeline_result; } =~ /^.*.bz2$/msx) {
                    if ((-x "`which bunzip2`")) {
                        $main_exit_code = system('bunzip2', '-d', q{c}, "$_[0]") >> 8;
}
                    else {
                        print "No bunzip2 available\n";
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_20 = '[:upper:]';
my $set2_20 = '[:lower:]';
my $input_20 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_20 = $set1_20;
my $expanded_set2_20 = $set2_20;
# Handle a-z range in set1
if ($expanded_set1_20 =~ /a-z/msx) {
    $expanded_set1_20 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_20 =~ /A-Z/msx) {
    $expanded_set1_20 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_20 =~ /\[:upper:\]/msx) {
    $expanded_set1_20 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_20 =~ /\[:lower:\]/msx) {
    $expanded_set1_20 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_20 =~ /a-z/msx) {
    $expanded_set2_20 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_20 =~ /A-Z/msx) {
    $expanded_set2_20 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_20 =~ /\[:upper:\]/msx) {
    $expanded_set2_20 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_20 =~ /\[:lower:\]/msx) {
    $expanded_set2_20 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_19 = q{};
for my $char ( split //msx, $input_20 ) {
    my $pos_20 = index $expanded_set1_20, $char;
    if ( $pos_20 >= 0 && $pos_20 < length $expanded_set2_20 ) {
        $tr_result_19 .= substr $expanded_set2_20, $pos_20, 1;
    } else {
        $tr_result_19 .= $char;
    }
}
$tr_result_19
}; $_pipeline_result; } =~ /^.*.deb$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_22 = '[:upper:]';
my $set2_22 = '[:lower:]';
my $input_22 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_22 = $set1_22;
my $expanded_set2_22 = $set2_22;
# Handle a-z range in set1
if ($expanded_set1_22 =~ /a-z/msx) {
    $expanded_set1_22 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_22 =~ /A-Z/msx) {
    $expanded_set1_22 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_22 =~ /\[:upper:\]/msx) {
    $expanded_set1_22 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_22 =~ /\[:lower:\]/msx) {
    $expanded_set1_22 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_22 =~ /a-z/msx) {
    $expanded_set2_22 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_22 =~ /A-Z/msx) {
    $expanded_set2_22 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_22 =~ /\[:upper:\]/msx) {
    $expanded_set2_22 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_22 =~ /\[:lower:\]/msx) {
    $expanded_set2_22 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_21 = q{};
for my $char ( split //msx, $input_22 ) {
    my $pos_22 = index $expanded_set1_22, $char;
    if ( $pos_22 >= 0 && $pos_22 < length $expanded_set2_22 ) {
        $tr_result_21 .= substr $expanded_set2_22, $pos_22, 1;
    } else {
        $tr_result_21 .= $char;
    }
}
$tr_result_21
}; $_pipeline_result; } =~ /^.*.udeb$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_24 = '[:upper:]';
my $set2_24 = '[:lower:]';
my $input_24 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_24 = $set1_24;
my $expanded_set2_24 = $set2_24;
# Handle a-z range in set1
if ($expanded_set1_24 =~ /a-z/msx) {
    $expanded_set1_24 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_24 =~ /A-Z/msx) {
    $expanded_set1_24 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_24 =~ /\[:upper:\]/msx) {
    $expanded_set1_24 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_24 =~ /\[:lower:\]/msx) {
    $expanded_set1_24 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_24 =~ /a-z/msx) {
    $expanded_set2_24 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_24 =~ /A-Z/msx) {
    $expanded_set2_24 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_24 =~ /\[:upper:\]/msx) {
    $expanded_set2_24 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_24 =~ /\[:lower:\]/msx) {
    $expanded_set2_24 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_23 = q{};
for my $char ( split //msx, $input_24 ) {
    my $pos_24 = index $expanded_set1_24, $char;
    if ( $pos_24 >= 0 && $pos_24 < length $expanded_set2_24 ) {
        $tr_result_23 .= substr $expanded_set2_24, $pos_24, 1;
    } else {
        $tr_result_23 .= $char;
    }
}
$tr_result_23
}; $_pipeline_result; } =~ /^.*.ddeb$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_26 = '[:upper:]';
my $set2_26 = '[:lower:]';
my $input_26 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_26 = $set1_26;
my $expanded_set2_26 = $set2_26;
# Handle a-z range in set1
if ($expanded_set1_26 =~ /a-z/msx) {
    $expanded_set1_26 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_26 =~ /A-Z/msx) {
    $expanded_set1_26 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_26 =~ /\[:upper:\]/msx) {
    $expanded_set1_26 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_26 =~ /\[:lower:\]/msx) {
    $expanded_set1_26 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_26 =~ /a-z/msx) {
    $expanded_set2_26 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_26 =~ /A-Z/msx) {
    $expanded_set2_26 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_26 =~ /\[:upper:\]/msx) {
    $expanded_set2_26 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_26 =~ /\[:lower:\]/msx) {
    $expanded_set2_26 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_25 = q{};
for my $char ( split //msx, $input_26 ) {
    my $pos_26 = index $expanded_set1_26, $char;
    if ( $pos_26 >= 0 && $pos_26 < length $expanded_set2_26 ) {
        $tr_result_25 .= substr $expanded_set2_26, $pos_26, 1;
    } else {
        $tr_result_25 .= $char;
    }
}
$tr_result_25
}; $_pipeline_result; } =~ /^.*.ipk$/msx) {
                                        do {
    my $__echo_line = "$_[0]:";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                                        $main_exit_code = system('dpkg', '--info', "$_[0]") >> 8;
                                        print "\n";
                    $CHILD_ERROR = 0;
                                        print '*** Contents:' . "\n";
                    $CHILD_ERROR = 0;
                                        $main_exit_code = system('dpkg-deb', '--contents', "$_[0]") >> 8;
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_28 = '[:upper:]';
my $set2_28 = '[:lower:]';
my $input_28 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_28 = $set1_28;
my $expanded_set2_28 = $set2_28;
# Handle a-z range in set1
if ($expanded_set1_28 =~ /a-z/msx) {
    $expanded_set1_28 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_28 =~ /A-Z/msx) {
    $expanded_set1_28 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_28 =~ /\[:upper:\]/msx) {
    $expanded_set1_28 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_28 =~ /\[:lower:\]/msx) {
    $expanded_set1_28 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_28 =~ /a-z/msx) {
    $expanded_set2_28 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_28 =~ /A-Z/msx) {
    $expanded_set2_28 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_28 =~ /\[:upper:\]/msx) {
    $expanded_set2_28 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_28 =~ /\[:lower:\]/msx) {
    $expanded_set2_28 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_27 = q{};
for my $char ( split //msx, $input_28 ) {
    my $pos_28 = index $expanded_set1_28, $char;
    if ( $pos_28 >= 0 && $pos_28 < length $expanded_set2_28 ) {
        $tr_result_27 .= substr $expanded_set2_28, $pos_28, 1;
    } else {
        $tr_result_27 .= $char;
    }
}
$tr_result_27
}; $_pipeline_result; } =~ /^.*.doc$/msx) {
                    if ((-x "`which catdoc`")) {
                        $main_exit_code = system('catdoc', "$_[0]") >> 8;
}
                    else {
if (!(                        do {
                            local %ENV = %ENV;
                            my $TMPDIR = $TMPDIR;
                            # Original bash: file "$1" | grep ASCII 2>/dev/null >/dev/null)
{
                                my $output_29 = q{};
                                my $output_printed_29;
                                my $pipeline_success_29 = 1;
                                                                my ($in_30, $out_30);
                                my $pid_30 = open3($in_30, $out_30, '>&STDERR', 'file', );
                                close $in_30 or croak 'Close failed: $OS_ERROR';
                                $output_29 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_30> };
                                close $out_30 or croak 'Close failed: $OS_ERROR';
                                waitpid $pid_30, 0;

                                                                my $grep_result_29_1;
                                my @grep_lines_29_1 = split /\n/msx, $output_29;
                                my @grep_filtered_29_1 = grep { /ASCII/msx } @grep_lines_29_1;
                                $grep_result_29_1 = join "\n", @grep_filtered_29_1;
                                if (!($grep_result_29_1 =~ m{\n\z}msx || $grep_result_29_1 eq q{})) {
                                $grep_result_29_1 .= "\n";
                                }
                                $CHILD_ERROR = scalar @grep_filtered_29_1 > 0 ? 0 : 1;
                                $output_29 = $grep_result_29_1;
                                if ( !$pipeline_success_29 ) { $main_exit_code = 1; }
                                }
                            q{};
                        })) {
print do { my $cat_chunk = q{}; if ( open my $fh, '<', "$_[0]" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$_[0]" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
}
                        else {
                            print "No catdoc available\n";
                        }
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_33 = '[:upper:]';
my $set2_33 = '[:lower:]';
my $input_33 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_33 = $set1_33;
my $expanded_set2_33 = $set2_33;
# Handle a-z range in set1
if ($expanded_set1_33 =~ /a-z/msx) {
    $expanded_set1_33 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_33 =~ /A-Z/msx) {
    $expanded_set1_33 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_33 =~ /\[:upper:\]/msx) {
    $expanded_set1_33 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_33 =~ /\[:lower:\]/msx) {
    $expanded_set1_33 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_33 =~ /a-z/msx) {
    $expanded_set2_33 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_33 =~ /A-Z/msx) {
    $expanded_set2_33 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_33 =~ /\[:upper:\]/msx) {
    $expanded_set2_33 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_33 =~ /\[:lower:\]/msx) {
    $expanded_set2_33 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_32 = q{};
for my $char ( split //msx, $input_33 ) {
    my $pos_33 = index $expanded_set1_33, $char;
    if ( $pos_33 >= 0 && $pos_33 < length $expanded_set2_33 ) {
        $tr_result_32 .= substr $expanded_set2_33, $pos_33, 1;
    } else {
        $tr_result_32 .= $char;
    }
}
$tr_result_32
}; $_pipeline_result; } =~ /^.*.egg$/msx) {
                    if ((-x "`which unzip`")) {
                        # Original bash: unzip -p "$1" EGG-INFO/PKG-INFO | \
{
                            my $output_34 = q{};
                            my $output_printed_34;
                            my $pipeline_success_34 = 1;
                                                        my ($in_35, $out_35);
                            my $pid_35 = open3($in_35, $out_35, '>&STDERR', 'unzip', '-p', 'EGG-INFO/PKG-INFO');
                            close $in_35 or croak 'Close failed: $OS_ERROR';
                            $output_34 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_35> };
                            close $out_35 or croak 'Close failed: $OS_ERROR';
                            waitpid $pid_35, 0;

                                                        my @sed_lines_34 = split /\n/msx, $output_34;
                            my @sed_result_34;
                            foreach my $line (@sed_lines_34) {
                            chomp $line;
                            push @sed_result_34, $line;
                            }
                            $output_34 = join "\n", @sed_result_34;
                            if ($output_34 ne q{} && !defined $output_printed_34) {
                                print $output_34;
                                if (!($output_34 =~ m{\n\z}msx)) {
                                    print "\n";
                                }
                            }
                            if ( !$pipeline_success_34 ) { $main_exit_code = 1; }
                            }
                        print "\n";
                        $CHILD_ERROR = 0;
                        $main_exit_code = system('unzip', '-v', "$_[0]") >> 8;
}
                    else {
                        print "No unzip available\n";
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_37 = '[:upper:]';
my $set2_37 = '[:lower:]';
my $input_37 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_37 = $set1_37;
my $expanded_set2_37 = $set2_37;
# Handle a-z range in set1
if ($expanded_set1_37 =~ /a-z/msx) {
    $expanded_set1_37 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_37 =~ /A-Z/msx) {
    $expanded_set1_37 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_37 =~ /\[:upper:\]/msx) {
    $expanded_set1_37 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_37 =~ /\[:lower:\]/msx) {
    $expanded_set1_37 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_37 =~ /a-z/msx) {
    $expanded_set2_37 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_37 =~ /A-Z/msx) {
    $expanded_set2_37 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_37 =~ /\[:upper:\]/msx) {
    $expanded_set2_37 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_37 =~ /\[:lower:\]/msx) {
    $expanded_set2_37 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_36 = q{};
for my $char ( split //msx, $input_37 ) {
    my $pos_37 = index $expanded_set1_37, $char;
    if ( $pos_37 >= 0 && $pos_37 < length $expanded_set2_37 ) {
        $tr_result_36 .= substr $expanded_set2_37, $pos_37, 1;
    } else {
        $tr_result_36 .= $char;
    }
}
$tr_result_36
}; $_pipeline_result; } =~ /^.*.gif$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_39 = '[:upper:]';
my $set2_39 = '[:lower:]';
my $input_39 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_39 = $set1_39;
my $expanded_set2_39 = $set2_39;
# Handle a-z range in set1
if ($expanded_set1_39 =~ /a-z/msx) {
    $expanded_set1_39 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_39 =~ /A-Z/msx) {
    $expanded_set1_39 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_39 =~ /\[:upper:\]/msx) {
    $expanded_set1_39 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_39 =~ /\[:lower:\]/msx) {
    $expanded_set1_39 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_39 =~ /a-z/msx) {
    $expanded_set2_39 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_39 =~ /A-Z/msx) {
    $expanded_set2_39 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_39 =~ /\[:upper:\]/msx) {
    $expanded_set2_39 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_39 =~ /\[:lower:\]/msx) {
    $expanded_set2_39 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_38 = q{};
for my $char ( split //msx, $input_39 ) {
    my $pos_39 = index $expanded_set1_39, $char;
    if ( $pos_39 >= 0 && $pos_39 < length $expanded_set2_39 ) {
        $tr_result_38 .= substr $expanded_set2_39, $pos_39, 1;
    } else {
        $tr_result_38 .= $char;
    }
}
$tr_result_38
}; $_pipeline_result; } =~ /^.*.jpeg$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_41 = '[:upper:]';
my $set2_41 = '[:lower:]';
my $input_41 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_41 = $set1_41;
my $expanded_set2_41 = $set2_41;
# Handle a-z range in set1
if ($expanded_set1_41 =~ /a-z/msx) {
    $expanded_set1_41 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_41 =~ /A-Z/msx) {
    $expanded_set1_41 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_41 =~ /\[:upper:\]/msx) {
    $expanded_set1_41 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_41 =~ /\[:lower:\]/msx) {
    $expanded_set1_41 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_41 =~ /a-z/msx) {
    $expanded_set2_41 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_41 =~ /A-Z/msx) {
    $expanded_set2_41 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_41 =~ /\[:upper:\]/msx) {
    $expanded_set2_41 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_41 =~ /\[:lower:\]/msx) {
    $expanded_set2_41 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_40 = q{};
for my $char ( split //msx, $input_41 ) {
    my $pos_41 = index $expanded_set1_41, $char;
    if ( $pos_41 >= 0 && $pos_41 < length $expanded_set2_41 ) {
        $tr_result_40 .= substr $expanded_set2_41, $pos_41, 1;
    } else {
        $tr_result_40 .= $char;
    }
}
$tr_result_40
}; $_pipeline_result; } =~ /^.*.jpg$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_43 = '[:upper:]';
my $set2_43 = '[:lower:]';
my $input_43 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_43 = $set1_43;
my $expanded_set2_43 = $set2_43;
# Handle a-z range in set1
if ($expanded_set1_43 =~ /a-z/msx) {
    $expanded_set1_43 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_43 =~ /A-Z/msx) {
    $expanded_set1_43 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_43 =~ /\[:upper:\]/msx) {
    $expanded_set1_43 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_43 =~ /\[:lower:\]/msx) {
    $expanded_set1_43 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_43 =~ /a-z/msx) {
    $expanded_set2_43 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_43 =~ /A-Z/msx) {
    $expanded_set2_43 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_43 =~ /\[:upper:\]/msx) {
    $expanded_set2_43 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_43 =~ /\[:lower:\]/msx) {
    $expanded_set2_43 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_42 = q{};
for my $char ( split //msx, $input_43 ) {
    my $pos_43 = index $expanded_set1_43, $char;
    if ( $pos_43 >= 0 && $pos_43 < length $expanded_set2_43 ) {
        $tr_result_42 .= substr $expanded_set2_43, $pos_43, 1;
    } else {
        $tr_result_42 .= $char;
    }
}
$tr_result_42
}; $_pipeline_result; } =~ /^.*.pcd$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_45 = '[:upper:]';
my $set2_45 = '[:lower:]';
my $input_45 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_45 = $set1_45;
my $expanded_set2_45 = $set2_45;
# Handle a-z range in set1
if ($expanded_set1_45 =~ /a-z/msx) {
    $expanded_set1_45 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_45 =~ /A-Z/msx) {
    $expanded_set1_45 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_45 =~ /\[:upper:\]/msx) {
    $expanded_set1_45 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_45 =~ /\[:lower:\]/msx) {
    $expanded_set1_45 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_45 =~ /a-z/msx) {
    $expanded_set2_45 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_45 =~ /A-Z/msx) {
    $expanded_set2_45 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_45 =~ /\[:upper:\]/msx) {
    $expanded_set2_45 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_45 =~ /\[:lower:\]/msx) {
    $expanded_set2_45 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_44 = q{};
for my $char ( split //msx, $input_45 ) {
    my $pos_45 = index $expanded_set1_45, $char;
    if ( $pos_45 >= 0 && $pos_45 < length $expanded_set2_45 ) {
        $tr_result_44 .= substr $expanded_set2_45, $pos_45, 1;
    } else {
        $tr_result_44 .= $char;
    }
}
$tr_result_44
}; $_pipeline_result; } =~ /^.*.png$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_47 = '[:upper:]';
my $set2_47 = '[:lower:]';
my $input_47 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_47 = $set1_47;
my $expanded_set2_47 = $set2_47;
# Handle a-z range in set1
if ($expanded_set1_47 =~ /a-z/msx) {
    $expanded_set1_47 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_47 =~ /A-Z/msx) {
    $expanded_set1_47 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_47 =~ /\[:upper:\]/msx) {
    $expanded_set1_47 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_47 =~ /\[:lower:\]/msx) {
    $expanded_set1_47 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_47 =~ /a-z/msx) {
    $expanded_set2_47 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_47 =~ /A-Z/msx) {
    $expanded_set2_47 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_47 =~ /\[:upper:\]/msx) {
    $expanded_set2_47 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_47 =~ /\[:lower:\]/msx) {
    $expanded_set2_47 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_46 = q{};
for my $char ( split //msx, $input_47 ) {
    my $pos_47 = index $expanded_set1_47, $char;
    if ( $pos_47 >= 0 && $pos_47 < length $expanded_set2_47 ) {
        $tr_result_46 .= substr $expanded_set2_47, $pos_47, 1;
    } else {
        $tr_result_46 .= $char;
    }
}
$tr_result_46
}; $_pipeline_result; } =~ /^.*.tga$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_49 = '[:upper:]';
my $set2_49 = '[:lower:]';
my $input_49 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_49 = $set1_49;
my $expanded_set2_49 = $set2_49;
# Handle a-z range in set1
if ($expanded_set1_49 =~ /a-z/msx) {
    $expanded_set1_49 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_49 =~ /A-Z/msx) {
    $expanded_set1_49 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_49 =~ /\[:upper:\]/msx) {
    $expanded_set1_49 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_49 =~ /\[:lower:\]/msx) {
    $expanded_set1_49 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_49 =~ /a-z/msx) {
    $expanded_set2_49 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_49 =~ /A-Z/msx) {
    $expanded_set2_49 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_49 =~ /\[:upper:\]/msx) {
    $expanded_set2_49 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_49 =~ /\[:lower:\]/msx) {
    $expanded_set2_49 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_48 = q{};
for my $char ( split //msx, $input_49 ) {
    my $pos_49 = index $expanded_set1_49, $char;
    if ( $pos_49 >= 0 && $pos_49 < length $expanded_set2_49 ) {
        $tr_result_48 .= substr $expanded_set2_49, $pos_49, 1;
    } else {
        $tr_result_48 .= $char;
    }
}
$tr_result_48
}; $_pipeline_result; } =~ /^.*.tiff$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_51 = '[:upper:]';
my $set2_51 = '[:lower:]';
my $input_51 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_51 = $set1_51;
my $expanded_set2_51 = $set2_51;
# Handle a-z range in set1
if ($expanded_set1_51 =~ /a-z/msx) {
    $expanded_set1_51 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_51 =~ /A-Z/msx) {
    $expanded_set1_51 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_51 =~ /\[:upper:\]/msx) {
    $expanded_set1_51 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_51 =~ /\[:lower:\]/msx) {
    $expanded_set1_51 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_51 =~ /a-z/msx) {
    $expanded_set2_51 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_51 =~ /A-Z/msx) {
    $expanded_set2_51 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_51 =~ /\[:upper:\]/msx) {
    $expanded_set2_51 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_51 =~ /\[:lower:\]/msx) {
    $expanded_set2_51 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_50 = q{};
for my $char ( split //msx, $input_51 ) {
    my $pos_51 = index $expanded_set1_51, $char;
    if ( $pos_51 >= 0 && $pos_51 < length $expanded_set2_51 ) {
        $tr_result_50 .= substr $expanded_set2_51, $pos_51, 1;
    } else {
        $tr_result_50 .= $char;
    }
}
$tr_result_50
}; $_pipeline_result; } =~ /^.*.tif$/msx) {
                    if ((-x "`which identify`")) {
                        $main_exit_code = system('identify', "$_[0]") >> 8;
}
                    else {
                        print "No identify available\n";
                        print "Install ImageMagick to browse images\n";
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_53 = '[:upper:]';
my $set2_53 = '[:lower:]';
my $input_53 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_53 = $set1_53;
my $expanded_set2_53 = $set2_53;
# Handle a-z range in set1
if ($expanded_set1_53 =~ /a-z/msx) {
    $expanded_set1_53 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_53 =~ /A-Z/msx) {
    $expanded_set1_53 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_53 =~ /\[:upper:\]/msx) {
    $expanded_set1_53 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_53 =~ /\[:lower:\]/msx) {
    $expanded_set1_53 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_53 =~ /a-z/msx) {
    $expanded_set2_53 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_53 =~ /A-Z/msx) {
    $expanded_set2_53 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_53 =~ /\[:upper:\]/msx) {
    $expanded_set2_53 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_53 =~ /\[:lower:\]/msx) {
    $expanded_set2_53 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_52 = q{};
for my $char ( split //msx, $input_53 ) {
    my $pos_53 = index $expanded_set1_53, $char;
    if ( $pos_53 >= 0 && $pos_53 < length $expanded_set2_53 ) {
        $tr_result_52 .= substr $expanded_set2_53, $pos_53, 1;
    } else {
        $tr_result_52 .= $char;
    }
}
$tr_result_52
}; $_pipeline_result; } =~ /^.*.iso$/msx) {
                    if ((-x "`which isoinfo`")) {
                        iso_list("$_[0]");
}
                    else {
                        print "No isoinfo available\n";
                        print "Install mkisofs to view ISO images\n";
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_55 = '[:upper:]';
my $set2_55 = '[:lower:]';
my $input_55 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_55 = $set1_55;
my $expanded_set2_55 = $set2_55;
# Handle a-z range in set1
if ($expanded_set1_55 =~ /a-z/msx) {
    $expanded_set1_55 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_55 =~ /A-Z/msx) {
    $expanded_set1_55 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_55 =~ /\[:upper:\]/msx) {
    $expanded_set1_55 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_55 =~ /\[:lower:\]/msx) {
    $expanded_set1_55 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_55 =~ /a-z/msx) {
    $expanded_set2_55 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_55 =~ /A-Z/msx) {
    $expanded_set2_55 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_55 =~ /\[:upper:\]/msx) {
    $expanded_set2_55 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_55 =~ /\[:lower:\]/msx) {
    $expanded_set2_55 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_54 = q{};
for my $char ( split //msx, $input_55 ) {
    my $pos_55 = index $expanded_set1_55, $char;
    if ( $pos_55 >= 0 && $pos_55 < length $expanded_set2_55 ) {
        $tr_result_54 .= substr $expanded_set2_55, $pos_55, 1;
    } else {
        $tr_result_54 .= $char;
    }
}
$tr_result_54
}; $_pipeline_result; } =~ /^.*.bin$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_57 = '[:upper:]';
my $set2_57 = '[:lower:]';
my $input_57 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_57 = $set1_57;
my $expanded_set2_57 = $set2_57;
# Handle a-z range in set1
if ($expanded_set1_57 =~ /a-z/msx) {
    $expanded_set1_57 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_57 =~ /A-Z/msx) {
    $expanded_set1_57 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_57 =~ /\[:upper:\]/msx) {
    $expanded_set1_57 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_57 =~ /\[:lower:\]/msx) {
    $expanded_set1_57 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_57 =~ /a-z/msx) {
    $expanded_set2_57 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_57 =~ /A-Z/msx) {
    $expanded_set2_57 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_57 =~ /\[:upper:\]/msx) {
    $expanded_set2_57 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_57 =~ /\[:lower:\]/msx) {
    $expanded_set2_57 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_56 = q{};
for my $char ( split //msx, $input_57 ) {
    my $pos_57 = index $expanded_set1_57, $char;
    if ( $pos_57 >= 0 && $pos_57 < length $expanded_set2_57 ) {
        $tr_result_56 .= substr $expanded_set2_57, $pos_57, 1;
    } else {
        $tr_result_56 .= $char;
    }
}
$tr_result_56
}; $_pipeline_result; } =~ /^.*.raw$/msx) {
                    if ((-x "`which isoinfo`")) {
                        if (do {
{
    my $output_58 = q{};
    my $output_printed_58;
    my $pipeline_success_58 = 1;
        my ($in_59, $out_59);
    my $pid_59 = open3($in_59, $out_59, '>&STDERR', 'file', );
    close $in_59 or croak 'Close failed: $OS_ERROR';
    $output_58 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_59> };
    close $out_59 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_59, 0;

        my $grep_result_58_1;
    my @grep_lines_58_1 = split /\n/msx, $output_58;
    my @grep_filtered_58_1 = grep { /ISO[.]9660/msx } @grep_lines_58_1;
    $grep_result_58_1 = join "\n", @grep_filtered_58_1;
    if (!($grep_result_58_1 =~ m{\n\z}msx || $grep_result_58_1 eq q{})) {
    $grep_result_58_1 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_58_1 > 0 ? 0 : 1;
    $grep_result_58_1 = q{};
    $output_58 = q{};
    if ((scalar @grep_filtered_58_1) == 0) {
        $pipeline_success_58 = 0;
    }
    if ($output_58 ne q{} && !defined $output_printed_58) {
        print $output_58;
        if (!($output_58 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_58 ) { $main_exit_code = 1; }
    }
                            $CHILD_ERROR == 0
                        }) {
                                                        iso_list("$_[0]");
                        }
}
                    else {
                        print "No isoinfo available\n";
                        print "Install mkisofs to view ISO images\n";
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_61 = '[:upper:]';
my $set2_61 = '[:lower:]';
my $input_61 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_61 = $set1_61;
my $expanded_set2_61 = $set2_61;
# Handle a-z range in set1
if ($expanded_set1_61 =~ /a-z/msx) {
    $expanded_set1_61 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_61 =~ /A-Z/msx) {
    $expanded_set1_61 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_61 =~ /\[:upper:\]/msx) {
    $expanded_set1_61 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_61 =~ /\[:lower:\]/msx) {
    $expanded_set1_61 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_61 =~ /a-z/msx) {
    $expanded_set2_61 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_61 =~ /A-Z/msx) {
    $expanded_set2_61 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_61 =~ /\[:upper:\]/msx) {
    $expanded_set2_61 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_61 =~ /\[:lower:\]/msx) {
    $expanded_set2_61 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_60 = q{};
for my $char ( split //msx, $input_61 ) {
    my $pos_61 = index $expanded_set1_61, $char;
    if ( $pos_61 >= 0 && $pos_61 < length $expanded_set2_61 ) {
        $tr_result_60 .= substr $expanded_set2_61, $pos_61, 1;
    } else {
        $tr_result_60 .= $char;
    }
}
$tr_result_60
}; $_pipeline_result; } =~ /^.*.lha$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_63 = '[:upper:]';
my $set2_63 = '[:lower:]';
my $input_63 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_63 = $set1_63;
my $expanded_set2_63 = $set2_63;
# Handle a-z range in set1
if ($expanded_set1_63 =~ /a-z/msx) {
    $expanded_set1_63 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_63 =~ /A-Z/msx) {
    $expanded_set1_63 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_63 =~ /\[:upper:\]/msx) {
    $expanded_set1_63 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_63 =~ /\[:lower:\]/msx) {
    $expanded_set1_63 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_63 =~ /a-z/msx) {
    $expanded_set2_63 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_63 =~ /A-Z/msx) {
    $expanded_set2_63 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_63 =~ /\[:upper:\]/msx) {
    $expanded_set2_63 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_63 =~ /\[:lower:\]/msx) {
    $expanded_set2_63 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_62 = q{};
for my $char ( split //msx, $input_63 ) {
    my $pos_63 = index $expanded_set1_63, $char;
    if ( $pos_63 >= 0 && $pos_63 < length $expanded_set2_63 ) {
        $tr_result_62 .= substr $expanded_set2_63, $pos_63, 1;
    } else {
        $tr_result_62 .= $char;
    }
}
$tr_result_62
}; $_pipeline_result; } =~ /^.*.lzh$/msx) {
                    if ((-x "`which lha`")) {
                        $main_exit_code = system('lha', q{v}, "$_[0]") >> 8;
}
                    else {
                        print "No lha available\n";
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_65 = '[:upper:]';
my $set2_65 = '[:lower:]';
my $input_65 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_65 = $set1_65;
my $expanded_set2_65 = $set2_65;
# Handle a-z range in set1
if ($expanded_set1_65 =~ /a-z/msx) {
    $expanded_set1_65 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_65 =~ /A-Z/msx) {
    $expanded_set1_65 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_65 =~ /\[:upper:\]/msx) {
    $expanded_set1_65 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_65 =~ /\[:lower:\]/msx) {
    $expanded_set1_65 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_65 =~ /a-z/msx) {
    $expanded_set2_65 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_65 =~ /A-Z/msx) {
    $expanded_set2_65 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_65 =~ /\[:upper:\]/msx) {
    $expanded_set2_65 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_65 =~ /\[:lower:\]/msx) {
    $expanded_set2_65 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_64 = q{};
for my $char ( split //msx, $input_65 ) {
    my $pos_65 = index $expanded_set1_65, $char;
    if ( $pos_65 >= 0 && $pos_65 < length $expanded_set2_65 ) {
        $tr_result_64 .= substr $expanded_set2_65, $pos_65, 1;
    } else {
        $tr_result_64 .= $char;
    }
}
$tr_result_64
}; $_pipeline_result; } =~ /^.*.tar.lz$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_67 = '[:upper:]';
my $set2_67 = '[:lower:]';
my $input_67 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_67 = $set1_67;
my $expanded_set2_67 = $set2_67;
# Handle a-z range in set1
if ($expanded_set1_67 =~ /a-z/msx) {
    $expanded_set1_67 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_67 =~ /A-Z/msx) {
    $expanded_set1_67 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_67 =~ /\[:upper:\]/msx) {
    $expanded_set1_67 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_67 =~ /\[:lower:\]/msx) {
    $expanded_set1_67 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_67 =~ /a-z/msx) {
    $expanded_set2_67 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_67 =~ /A-Z/msx) {
    $expanded_set2_67 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_67 =~ /\[:upper:\]/msx) {
    $expanded_set2_67 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_67 =~ /\[:lower:\]/msx) {
    $expanded_set2_67 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_66 = q{};
for my $char ( split //msx, $input_67 ) {
    my $pos_67 = index $expanded_set1_67, $char;
    if ( $pos_67 >= 0 && $pos_67 < length $expanded_set2_67 ) {
        $tr_result_66 .= substr $expanded_set2_67, $pos_67, 1;
    } else {
        $tr_result_66 .= $char;
    }
}
$tr_result_66
}; $_pipeline_result; } =~ /^.*.tlz$/msx) {
                    if ((-x "`which lzip`")) {
                        # Original bash: lzip -dc "$1" | tar tvvf -
{
                            my $output_68 = q{};
                            my $output_printed_68;
                            my $pipeline_success_68 = 1;
                                                        my ($in_69, $out_69);
                            my $pid_69 = open3($in_69, $out_69, '>&STDERR', 'lzip', '-d', q{c});
                            close $in_69 or croak 'Close failed: $OS_ERROR';
                            $output_68 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_69> };
                            close $out_69 or croak 'Close failed: $OS_ERROR';
                            waitpid $pid_69, 0;

                                                        my $cmd_71 = 'tar';
                            my ($in_70, $out_70);
                            my $pid_70 = open3($in_70, $out_70, '>&STDERR', $cmd_71, 'tvvf', q{-});
                            print {$in_70} $output_68;
                            close $in_70 or croak 'Close failed: $OS_ERROR';
                            $output_68 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_70> };
                            close $out_70 or croak 'Close failed: $OS_ERROR';
                            waitpid $pid_70, 0;
                            if ($output_68 ne q{} && !defined $output_printed_68) {
                                print $output_68;
                                if (!($output_68 =~ m{\n\z}msx)) {
                                    print "\n";
                                }
                            }
                            if ( !$pipeline_success_68 ) { $main_exit_code = 1; }
                            }
}
                    else {
                        if ((-x "`which lunzip`")) {
                            # Original bash: lunzip -dc "$1" | tar tvvf -
{
                                my $output_72 = q{};
                                my $output_printed_72;
                                my $pipeline_success_72 = 1;
                                                                my ($in_73, $out_73);
                                my $pid_73 = open3($in_73, $out_73, '>&STDERR', 'lunzip', '-d', q{c});
                                close $in_73 or croak 'Close failed: $OS_ERROR';
                                $output_72 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_73> };
                                close $out_73 or croak 'Close failed: $OS_ERROR';
                                waitpid $pid_73, 0;

                                                                my $cmd_75 = 'tar';
                                my ($in_74, $out_74);
                                my $pid_74 = open3($in_74, $out_74, '>&STDERR', $cmd_75, 'tvvf', q{-});
                                print {$in_74} $output_72;
                                close $in_74 or croak 'Close failed: $OS_ERROR';
                                $output_72 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_74> };
                                close $out_74 or croak 'Close failed: $OS_ERROR';
                                waitpid $pid_74, 0;
                                if ($output_72 ne q{} && !defined $output_printed_72) {
                                    print $output_72;
                                    if (!($output_72 =~ m{\n\z}msx)) {
                                        print "\n";
                                    }
                                }
                                if ( !$pipeline_success_72 ) { $main_exit_code = 1; }
                                }
}
                        else {
                            print "No lzip or lunzip available\n";
                        }
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_77 = '[:upper:]';
my $set2_77 = '[:lower:]';
my $input_77 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_77 = $set1_77;
my $expanded_set2_77 = $set2_77;
# Handle a-z range in set1
if ($expanded_set1_77 =~ /a-z/msx) {
    $expanded_set1_77 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_77 =~ /A-Z/msx) {
    $expanded_set1_77 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_77 =~ /\[:upper:\]/msx) {
    $expanded_set1_77 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_77 =~ /\[:lower:\]/msx) {
    $expanded_set1_77 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_77 =~ /a-z/msx) {
    $expanded_set2_77 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_77 =~ /A-Z/msx) {
    $expanded_set2_77 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_77 =~ /\[:upper:\]/msx) {
    $expanded_set2_77 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_77 =~ /\[:lower:\]/msx) {
    $expanded_set2_77 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_76 = q{};
for my $char ( split //msx, $input_77 ) {
    my $pos_77 = index $expanded_set1_77, $char;
    if ( $pos_77 >= 0 && $pos_77 < length $expanded_set2_77 ) {
        $tr_result_76 .= substr $expanded_set2_77, $pos_77, 1;
    } else {
        $tr_result_76 .= $char;
    }
}
$tr_result_76
}; $_pipeline_result; } =~ /^.*.lz$/msx) {
                    if ((-x "`which lzip`")) {
                        $main_exit_code = system('lzip', '-d', q{c}, "$_[0]") >> 8;
}
                    else {
                        if ((-x "`which lunzip`")) {
                            $main_exit_code = system('lunzip', '-d', q{c}, "$_[0]") >> 8;
}
                        else {
                            print "No lzip or lunzip available\n";
                        }
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_79 = '[:upper:]';
my $set2_79 = '[:lower:]';
my $input_79 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_79 = $set1_79;
my $expanded_set2_79 = $set2_79;
# Handle a-z range in set1
if ($expanded_set1_79 =~ /a-z/msx) {
    $expanded_set1_79 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_79 =~ /A-Z/msx) {
    $expanded_set1_79 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_79 =~ /\[:upper:\]/msx) {
    $expanded_set1_79 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_79 =~ /\[:lower:\]/msx) {
    $expanded_set1_79 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_79 =~ /a-z/msx) {
    $expanded_set2_79 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_79 =~ /A-Z/msx) {
    $expanded_set2_79 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_79 =~ /\[:upper:\]/msx) {
    $expanded_set2_79 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_79 =~ /\[:lower:\]/msx) {
    $expanded_set2_79 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_78 = q{};
for my $char ( split //msx, $input_79 ) {
    my $pos_79 = index $expanded_set1_79, $char;
    if ( $pos_79 >= 0 && $pos_79 < length $expanded_set2_79 ) {
        $tr_result_78 .= substr $expanded_set2_79, $pos_79, 1;
    } else {
        $tr_result_78 .= $char;
    }
}
$tr_result_78
}; $_pipeline_result; } =~ /^.*.tar.lzma$/msx) {
                    if ((-x "`which lzma`")) {
                        # Original bash: lzma -dc "$1" | tar tfvv -
{
                            my $output_80 = q{};
                            my $output_printed_80;
                            my $pipeline_success_80 = 1;
                                                        my ($in_81, $out_81);
                            my $pid_81 = open3($in_81, $out_81, '>&STDERR', 'lzma', '-d', q{c});
                            close $in_81 or croak 'Close failed: $OS_ERROR';
                            $output_80 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_81> };
                            close $out_81 or croak 'Close failed: $OS_ERROR';
                            waitpid $pid_81, 0;

                                                        my $cmd_83 = 'tar';
                            my ($in_82, $out_82);
                            my $pid_82 = open3($in_82, $out_82, '>&STDERR', $cmd_83, 'tfvv', q{-});
                            print {$in_82} $output_80;
                            close $in_82 or croak 'Close failed: $OS_ERROR';
                            $output_80 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_82> };
                            close $out_82 or croak 'Close failed: $OS_ERROR';
                            waitpid $pid_82, 0;
                            if ($output_80 ne q{} && !defined $output_printed_80) {
                                print $output_80;
                                if (!($output_80 =~ m{\n\z}msx)) {
                                    print "\n";
                                }
                            }
                            if ( !$pipeline_success_80 ) { $main_exit_code = 1; }
                            }
}
                    else {
                        print "No lzma available\n";
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_85 = '[:upper:]';
my $set2_85 = '[:lower:]';
my $input_85 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_85 = $set1_85;
my $expanded_set2_85 = $set2_85;
# Handle a-z range in set1
if ($expanded_set1_85 =~ /a-z/msx) {
    $expanded_set1_85 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_85 =~ /A-Z/msx) {
    $expanded_set1_85 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_85 =~ /\[:upper:\]/msx) {
    $expanded_set1_85 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_85 =~ /\[:lower:\]/msx) {
    $expanded_set1_85 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_85 =~ /a-z/msx) {
    $expanded_set2_85 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_85 =~ /A-Z/msx) {
    $expanded_set2_85 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_85 =~ /\[:upper:\]/msx) {
    $expanded_set2_85 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_85 =~ /\[:lower:\]/msx) {
    $expanded_set2_85 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_84 = q{};
for my $char ( split //msx, $input_85 ) {
    my $pos_85 = index $expanded_set1_85, $char;
    if ( $pos_85 >= 0 && $pos_85 < length $expanded_set2_85 ) {
        $tr_result_84 .= substr $expanded_set2_85, $pos_85, 1;
    } else {
        $tr_result_84 .= $char;
    }
}
$tr_result_84
}; $_pipeline_result; } =~ /^.*.lzma$/msx) {
                    if ((-x "`which lzma`")) {
                        $main_exit_code = system('lzma', '-d', q{c}, "$_[0]") >> 8;
}
                    else {
                        print "No lzma available\n";
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_87 = '[:upper:]';
my $set2_87 = '[:lower:]';
my $input_87 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_87 = $set1_87;
my $expanded_set2_87 = $set2_87;
# Handle a-z range in set1
if ($expanded_set1_87 =~ /a-z/msx) {
    $expanded_set1_87 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_87 =~ /A-Z/msx) {
    $expanded_set1_87 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_87 =~ /\[:upper:\]/msx) {
    $expanded_set1_87 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_87 =~ /\[:lower:\]/msx) {
    $expanded_set1_87 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_87 =~ /a-z/msx) {
    $expanded_set2_87 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_87 =~ /A-Z/msx) {
    $expanded_set2_87 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_87 =~ /\[:upper:\]/msx) {
    $expanded_set2_87 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_87 =~ /\[:lower:\]/msx) {
    $expanded_set2_87 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_86 = q{};
for my $char ( split //msx, $input_87 ) {
    my $pos_87 = index $expanded_set1_87, $char;
    if ( $pos_87 >= 0 && $pos_87 < length $expanded_set2_87 ) {
        $tr_result_86 .= substr $expanded_set2_87, $pos_87, 1;
    } else {
        $tr_result_86 .= $char;
    }
}
$tr_result_86
}; $_pipeline_result; } =~ /^.*.pdf$/msx) {
                    if ((-x "`which pdftotext`")) {
                        $main_exit_code = system('pdftotext', '-layout', "$_[0]", q{-}) >> 8;
}
                    else {
                        print "No pdftotext available\n";
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_89 = '[:upper:]';
my $set2_89 = '[:lower:]';
my $input_89 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_89 = $set1_89;
my $expanded_set2_89 = $set2_89;
# Handle a-z range in set1
if ($expanded_set1_89 =~ /a-z/msx) {
    $expanded_set1_89 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_89 =~ /A-Z/msx) {
    $expanded_set1_89 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_89 =~ /\[:upper:\]/msx) {
    $expanded_set1_89 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_89 =~ /\[:lower:\]/msx) {
    $expanded_set1_89 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_89 =~ /a-z/msx) {
    $expanded_set2_89 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_89 =~ /A-Z/msx) {
    $expanded_set2_89 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_89 =~ /\[:upper:\]/msx) {
    $expanded_set2_89 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_89 =~ /\[:lower:\]/msx) {
    $expanded_set2_89 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_88 = q{};
for my $char ( split //msx, $input_89 ) {
    my $pos_89 = index $expanded_set1_89, $char;
    if ( $pos_89 >= 0 && $pos_89 < length $expanded_set2_89 ) {
        $tr_result_88 .= substr $expanded_set2_89, $pos_89, 1;
    } else {
        $tr_result_88 .= $char;
    }
}
$tr_result_88
}; $_pipeline_result; } =~ /^.*.rar$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_91 = '[:upper:]';
my $set2_91 = '[:lower:]';
my $input_91 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_91 = $set1_91;
my $expanded_set2_91 = $set2_91;
# Handle a-z range in set1
if ($expanded_set1_91 =~ /a-z/msx) {
    $expanded_set1_91 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_91 =~ /A-Z/msx) {
    $expanded_set1_91 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_91 =~ /\[:upper:\]/msx) {
    $expanded_set1_91 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_91 =~ /\[:lower:\]/msx) {
    $expanded_set1_91 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_91 =~ /a-z/msx) {
    $expanded_set2_91 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_91 =~ /A-Z/msx) {
    $expanded_set2_91 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_91 =~ /\[:upper:\]/msx) {
    $expanded_set2_91 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_91 =~ /\[:lower:\]/msx) {
    $expanded_set2_91 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_90 = q{};
for my $char ( split //msx, $input_91 ) {
    my $pos_91 = index $expanded_set1_91, $char;
    if ( $pos_91 >= 0 && $pos_91 < length $expanded_set2_91 ) {
        $tr_result_90 .= substr $expanded_set2_91, $pos_91, 1;
    } else {
        $tr_result_90 .= $char;
    }
}
$tr_result_90
}; $_pipeline_result; } =~ /^.*.r\[0-9\]\[0-9\]$/msx) {
                    if ((-x "`which rar`")) {
                        $main_exit_code = system('rar', q{v}, "$_[0]") >> 8;
}
                    else {
                        if ((-x "`which unrar`")) {
                            $main_exit_code = system('unrar', q{v}, "$_[0]") >> 8;
}
                        else {
                            print "No rar or unrar available\n";
                        }
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_93 = '[:upper:]';
my $set2_93 = '[:lower:]';
my $input_93 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_93 = $set1_93;
my $expanded_set2_93 = $set2_93;
# Handle a-z range in set1
if ($expanded_set1_93 =~ /a-z/msx) {
    $expanded_set1_93 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_93 =~ /A-Z/msx) {
    $expanded_set1_93 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_93 =~ /\[:upper:\]/msx) {
    $expanded_set1_93 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_93 =~ /\[:lower:\]/msx) {
    $expanded_set1_93 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_93 =~ /a-z/msx) {
    $expanded_set2_93 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_93 =~ /A-Z/msx) {
    $expanded_set2_93 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_93 =~ /\[:upper:\]/msx) {
    $expanded_set2_93 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_93 =~ /\[:lower:\]/msx) {
    $expanded_set2_93 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_92 = q{};
for my $char ( split //msx, $input_93 ) {
    my $pos_93 = index $expanded_set1_93, $char;
    if ( $pos_93 >= 0 && $pos_93 < length $expanded_set2_93 ) {
        $tr_result_92 .= substr $expanded_set2_93, $pos_93, 1;
    } else {
        $tr_result_92 .= $char;
    }
}
$tr_result_92
}; $_pipeline_result; } =~ /^.*.rpm$/msx) {
                    if ((-x "`which rpm`")) {
                        do {
    my $__echo_line = "$_[0]:";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                        $CHILD_ERROR = 0;
                        $main_exit_code = system('rpm', '-q', '-i', '-p', "$_[0]") >> 8;
                        print "\n";
                        $CHILD_ERROR = 0;
                        print '*** Contents:' . "\n";
                        $CHILD_ERROR = 0;
                        $main_exit_code = system('rpm', '-q', '-l', '-p', "$_[0]") >> 8;
}
                    else {
                        print "rpm isn't available, no query on rpm package possible\n";
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_95 = '[:upper:]';
my $set2_95 = '[:lower:]';
my $input_95 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_95 = $set1_95;
my $expanded_set2_95 = $set2_95;
# Handle a-z range in set1
if ($expanded_set1_95 =~ /a-z/msx) {
    $expanded_set1_95 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_95 =~ /A-Z/msx) {
    $expanded_set1_95 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_95 =~ /\[:upper:\]/msx) {
    $expanded_set1_95 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_95 =~ /\[:lower:\]/msx) {
    $expanded_set1_95 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_95 =~ /a-z/msx) {
    $expanded_set2_95 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_95 =~ /A-Z/msx) {
    $expanded_set2_95 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_95 =~ /\[:upper:\]/msx) {
    $expanded_set2_95 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_95 =~ /\[:lower:\]/msx) {
    $expanded_set2_95 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_94 = q{};
for my $char ( split //msx, $input_95 ) {
    my $pos_95 = index $expanded_set1_95, $char;
    if ( $pos_95 >= 0 && $pos_95 < length $expanded_set2_95 ) {
        $tr_result_94 .= substr $expanded_set2_95, $pos_95, 1;
    } else {
        $tr_result_94 .= $char;
    }
}
$tr_result_94
}; $_pipeline_result; } =~ /^.*.snap$/msx) {
                    if ((-x "`which snap`")) {
                        $main_exit_code = system('snap', 'info', "$_[0]") >> 8;
                    }
                    if ((-x "`which unsquashfs`")) {
                        print "\n";
                        $CHILD_ERROR = 0;
                        print '*** Contents:' . "\n";
                        $CHILD_ERROR = 0;
                        $main_exit_code = system('unsquashfs', '-ll', '-d', q{}, "$_[0]") >> 8;
}
                    else {
                        print "No unsquashfs available\n";
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_97 = '[:upper:]';
my $set2_97 = '[:lower:]';
my $input_97 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_97 = $set1_97;
my $expanded_set2_97 = $set2_97;
# Handle a-z range in set1
if ($expanded_set1_97 =~ /a-z/msx) {
    $expanded_set1_97 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_97 =~ /A-Z/msx) {
    $expanded_set1_97 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_97 =~ /\[:upper:\]/msx) {
    $expanded_set1_97 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_97 =~ /\[:lower:\]/msx) {
    $expanded_set1_97 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_97 =~ /a-z/msx) {
    $expanded_set2_97 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_97 =~ /A-Z/msx) {
    $expanded_set2_97 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_97 =~ /\[:upper:\]/msx) {
    $expanded_set2_97 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_97 =~ /\[:lower:\]/msx) {
    $expanded_set2_97 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_96 = q{};
for my $char ( split //msx, $input_97 ) {
    my $pos_97 = index $expanded_set1_97, $char;
    if ( $pos_97 >= 0 && $pos_97 < length $expanded_set2_97 ) {
        $tr_result_96 .= substr $expanded_set2_97, $pos_97, 1;
    } else {
        $tr_result_96 .= $char;
    }
}
$tr_result_96
}; $_pipeline_result; } =~ /^.*.tar.gz$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_99 = '[:upper:]';
my $set2_99 = '[:lower:]';
my $input_99 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_99 = $set1_99;
my $expanded_set2_99 = $set2_99;
# Handle a-z range in set1
if ($expanded_set1_99 =~ /a-z/msx) {
    $expanded_set1_99 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_99 =~ /A-Z/msx) {
    $expanded_set1_99 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_99 =~ /\[:upper:\]/msx) {
    $expanded_set1_99 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_99 =~ /\[:lower:\]/msx) {
    $expanded_set1_99 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_99 =~ /a-z/msx) {
    $expanded_set2_99 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_99 =~ /A-Z/msx) {
    $expanded_set2_99 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_99 =~ /\[:upper:\]/msx) {
    $expanded_set2_99 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_99 =~ /\[:lower:\]/msx) {
    $expanded_set2_99 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_98 = q{};
for my $char ( split //msx, $input_99 ) {
    my $pos_99 = index $expanded_set1_99, $char;
    if ( $pos_99 >= 0 && $pos_99 < length $expanded_set2_99 ) {
        $tr_result_98 .= substr $expanded_set2_99, $pos_99, 1;
    } else {
        $tr_result_98 .= $char;
    }
}
$tr_result_98
}; $_pipeline_result; } =~ /^.*.tgz$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_101 = '[:upper:]';
my $set2_101 = '[:lower:]';
my $input_101 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_101 = $set1_101;
my $expanded_set2_101 = $set2_101;
# Handle a-z range in set1
if ($expanded_set1_101 =~ /a-z/msx) {
    $expanded_set1_101 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_101 =~ /A-Z/msx) {
    $expanded_set1_101 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_101 =~ /\[:upper:\]/msx) {
    $expanded_set1_101 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_101 =~ /\[:lower:\]/msx) {
    $expanded_set1_101 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_101 =~ /a-z/msx) {
    $expanded_set2_101 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_101 =~ /A-Z/msx) {
    $expanded_set2_101 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_101 =~ /\[:upper:\]/msx) {
    $expanded_set2_101 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_101 =~ /\[:lower:\]/msx) {
    $expanded_set2_101 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_100 = q{};
for my $char ( split //msx, $input_101 ) {
    my $pos_101 = index $expanded_set1_101, $char;
    if ( $pos_101 >= 0 && $pos_101 < length $expanded_set2_101 ) {
        $tr_result_100 .= substr $expanded_set2_101, $pos_101, 1;
    } else {
        $tr_result_100 .= $char;
    }
}
$tr_result_100
}; $_pipeline_result; } =~ /^.*.tar.z$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_103 = '[:upper:]';
my $set2_103 = '[:lower:]';
my $input_103 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_103 = $set1_103;
my $expanded_set2_103 = $set2_103;
# Handle a-z range in set1
if ($expanded_set1_103 =~ /a-z/msx) {
    $expanded_set1_103 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_103 =~ /A-Z/msx) {
    $expanded_set1_103 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_103 =~ /\[:upper:\]/msx) {
    $expanded_set1_103 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_103 =~ /\[:lower:\]/msx) {
    $expanded_set1_103 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_103 =~ /a-z/msx) {
    $expanded_set2_103 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_103 =~ /A-Z/msx) {
    $expanded_set2_103 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_103 =~ /\[:upper:\]/msx) {
    $expanded_set2_103 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_103 =~ /\[:lower:\]/msx) {
    $expanded_set2_103 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_102 = q{};
for my $char ( split //msx, $input_103 ) {
    my $pos_103 = index $expanded_set1_103, $char;
    if ( $pos_103 >= 0 && $pos_103 < length $expanded_set2_103 ) {
        $tr_result_102 .= substr $expanded_set2_103, $pos_103, 1;
    } else {
        $tr_result_102 .= $char;
    }
}
$tr_result_102
}; $_pipeline_result; } =~ /^.*.tar.dz$/msx) {
                                        $main_exit_code = system('tar', 'tzvf', "$_[0]", '--force-local') >> 8;
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_105 = '[:upper:]';
my $set2_105 = '[:lower:]';
my $input_105 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_105 = $set1_105;
my $expanded_set2_105 = $set2_105;
# Handle a-z range in set1
if ($expanded_set1_105 =~ /a-z/msx) {
    $expanded_set1_105 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_105 =~ /A-Z/msx) {
    $expanded_set1_105 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_105 =~ /\[:upper:\]/msx) {
    $expanded_set1_105 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_105 =~ /\[:lower:\]/msx) {
    $expanded_set1_105 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_105 =~ /a-z/msx) {
    $expanded_set2_105 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_105 =~ /A-Z/msx) {
    $expanded_set2_105 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_105 =~ /\[:upper:\]/msx) {
    $expanded_set2_105 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_105 =~ /\[:lower:\]/msx) {
    $expanded_set2_105 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_104 = q{};
for my $char ( split //msx, $input_105 ) {
    my $pos_105 = index $expanded_set1_105, $char;
    if ( $pos_105 >= 0 && $pos_105 < length $expanded_set2_105 ) {
        $tr_result_104 .= substr $expanded_set2_105, $pos_105, 1;
    } else {
        $tr_result_104 .= $char;
    }
}
$tr_result_104
}; $_pipeline_result; } =~ /^.*.tar.xz$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_107 = '[:upper:]';
my $set2_107 = '[:lower:]';
my $input_107 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_107 = $set1_107;
my $expanded_set2_107 = $set2_107;
# Handle a-z range in set1
if ($expanded_set1_107 =~ /a-z/msx) {
    $expanded_set1_107 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_107 =~ /A-Z/msx) {
    $expanded_set1_107 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_107 =~ /\[:upper:\]/msx) {
    $expanded_set1_107 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_107 =~ /\[:lower:\]/msx) {
    $expanded_set1_107 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_107 =~ /a-z/msx) {
    $expanded_set2_107 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_107 =~ /A-Z/msx) {
    $expanded_set2_107 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_107 =~ /\[:upper:\]/msx) {
    $expanded_set2_107 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_107 =~ /\[:lower:\]/msx) {
    $expanded_set2_107 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_106 = q{};
for my $char ( split //msx, $input_107 ) {
    my $pos_107 = index $expanded_set1_107, $char;
    if ( $pos_107 >= 0 && $pos_107 < length $expanded_set2_107 ) {
        $tr_result_106 .= substr $expanded_set2_107, $pos_107, 1;
    } else {
        $tr_result_106 .= $char;
    }
}
$tr_result_106
}; $_pipeline_result; } =~ /^.*.txz$/msx) {
                    if ((-x "`which xz`")) {
                        # Original bash: xz -dc "$1" | tar tfvv -
{
                            my $output_108 = q{};
                            my $output_printed_108;
                            my $pipeline_success_108 = 1;
                                                        my ($in_109, $out_109);
                            my $pid_109 = open3($in_109, $out_109, '>&STDERR', 'xz', '-d', q{c});
                            close $in_109 or croak 'Close failed: $OS_ERROR';
                            $output_108 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_109> };
                            close $out_109 or croak 'Close failed: $OS_ERROR';
                            waitpid $pid_109, 0;

                                                        my $cmd_111 = 'tar';
                            my ($in_110, $out_110);
                            my $pid_110 = open3($in_110, $out_110, '>&STDERR', $cmd_111, 'tfvv', q{-});
                            print {$in_110} $output_108;
                            close $in_110 or croak 'Close failed: $OS_ERROR';
                            $output_108 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_110> };
                            close $out_110 or croak 'Close failed: $OS_ERROR';
                            waitpid $pid_110, 0;
                            if ($output_108 ne q{} && !defined $output_printed_108) {
                                print $output_108;
                                if (!($output_108 =~ m{\n\z}msx)) {
                                    print "\n";
                                }
                            }
                            if ( !$pipeline_success_108 ) { $main_exit_code = 1; }
                            }
}
                    else {
                        print "No xz available\n";
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_113 = '[:upper:]';
my $set2_113 = '[:lower:]';
my $input_113 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_113 = $set1_113;
my $expanded_set2_113 = $set2_113;
# Handle a-z range in set1
if ($expanded_set1_113 =~ /a-z/msx) {
    $expanded_set1_113 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_113 =~ /A-Z/msx) {
    $expanded_set1_113 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_113 =~ /\[:upper:\]/msx) {
    $expanded_set1_113 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_113 =~ /\[:lower:\]/msx) {
    $expanded_set1_113 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_113 =~ /a-z/msx) {
    $expanded_set2_113 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_113 =~ /A-Z/msx) {
    $expanded_set2_113 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_113 =~ /\[:upper:\]/msx) {
    $expanded_set2_113 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_113 =~ /\[:lower:\]/msx) {
    $expanded_set2_113 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_112 = q{};
for my $char ( split //msx, $input_113 ) {
    my $pos_113 = index $expanded_set1_113, $char;
    if ( $pos_113 >= 0 && $pos_113 < length $expanded_set2_113 ) {
        $tr_result_112 .= substr $expanded_set2_113, $pos_113, 1;
    } else {
        $tr_result_112 .= $char;
    }
}
$tr_result_112
}; $_pipeline_result; } =~ /^.*.tar.zst$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_115 = '[:upper:]';
my $set2_115 = '[:lower:]';
my $input_115 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_115 = $set1_115;
my $expanded_set2_115 = $set2_115;
# Handle a-z range in set1
if ($expanded_set1_115 =~ /a-z/msx) {
    $expanded_set1_115 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_115 =~ /A-Z/msx) {
    $expanded_set1_115 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_115 =~ /\[:upper:\]/msx) {
    $expanded_set1_115 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_115 =~ /\[:lower:\]/msx) {
    $expanded_set1_115 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_115 =~ /a-z/msx) {
    $expanded_set2_115 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_115 =~ /A-Z/msx) {
    $expanded_set2_115 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_115 =~ /\[:upper:\]/msx) {
    $expanded_set2_115 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_115 =~ /\[:lower:\]/msx) {
    $expanded_set2_115 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_114 = q{};
for my $char ( split //msx, $input_115 ) {
    my $pos_115 = index $expanded_set1_115, $char;
    if ( $pos_115 >= 0 && $pos_115 < length $expanded_set2_115 ) {
        $tr_result_114 .= substr $expanded_set2_115, $pos_115, 1;
    } else {
        $tr_result_114 .= $char;
    }
}
$tr_result_114
}; $_pipeline_result; } =~ /^.*.tzst$/msx) {
                    if ((-x "`which zstd`")) {
                        # Original bash: zstd -qdc "$1" | tar tfvv -
{
                            my $output_116 = q{};
                            my $output_printed_116;
                            my $pipeline_success_116 = 1;
                                                        my ($in_117, $out_117);
                            my $pid_117 = open3($in_117, $out_117, '>&STDERR', 'zstd', '-qdc');
                            close $in_117 or croak 'Close failed: $OS_ERROR';
                            $output_116 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_117> };
                            close $out_117 or croak 'Close failed: $OS_ERROR';
                            waitpid $pid_117, 0;

                                                        my $cmd_119 = 'tar';
                            my ($in_118, $out_118);
                            my $pid_118 = open3($in_118, $out_118, '>&STDERR', $cmd_119, 'tfvv', q{-});
                            print {$in_118} $output_116;
                            close $in_118 or croak 'Close failed: $OS_ERROR';
                            $output_116 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_118> };
                            close $out_118 or croak 'Close failed: $OS_ERROR';
                            waitpid $pid_118, 0;
                            if ($output_116 ne q{} && !defined $output_printed_116) {
                                print $output_116;
                                if (!($output_116 =~ m{\n\z}msx)) {
                                    print "\n";
                                }
                            }
                            if ( !$pipeline_success_116 ) { $main_exit_code = 1; }
                            }
}
                    else {
                        print "No zstd available\n";
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_121 = '[:upper:]';
my $set2_121 = '[:lower:]';
my $input_121 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_121 = $set1_121;
my $expanded_set2_121 = $set2_121;
# Handle a-z range in set1
if ($expanded_set1_121 =~ /a-z/msx) {
    $expanded_set1_121 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_121 =~ /A-Z/msx) {
    $expanded_set1_121 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_121 =~ /\[:upper:\]/msx) {
    $expanded_set1_121 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_121 =~ /\[:lower:\]/msx) {
    $expanded_set1_121 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_121 =~ /a-z/msx) {
    $expanded_set2_121 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_121 =~ /A-Z/msx) {
    $expanded_set2_121 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_121 =~ /\[:upper:\]/msx) {
    $expanded_set2_121 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_121 =~ /\[:lower:\]/msx) {
    $expanded_set2_121 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_120 = q{};
for my $char ( split //msx, $input_121 ) {
    my $pos_121 = index $expanded_set1_121, $char;
    if ( $pos_121 >= 0 && $pos_121 < length $expanded_set2_121 ) {
        $tr_result_120 .= substr $expanded_set2_121, $pos_121, 1;
    } else {
        $tr_result_120 .= $char;
    }
}
$tr_result_120
}; $_pipeline_result; } =~ /^.*.whl$/msx) {
                    if ((-x "`which unzip`")) {
                        # Original bash: unzip -p "$1" '*.dist-info/METADATA' | sed '/^$/q'
{
                            my $output_122 = q{};
                            my $output_printed_122;
                            my $pipeline_success_122 = 1;
                                                        my ($in_123, $out_123);
                            my $pid_123 = open3($in_123, $out_123, '>&STDERR', 'unzip', '-p', '*.dist-info/METADATA');
                            close $in_123 or croak 'Close failed: $OS_ERROR';
                            $output_122 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_123> };
                            close $out_123 or croak 'Close failed: $OS_ERROR';
                            waitpid $pid_123, 0;

                                                        my @sed_lines_122 = split /\n/msx, $output_122;
                            my @sed_result_122;
                            foreach my $line (@sed_lines_122) {
                            chomp $line;
                            push @sed_result_122, $line;
                            }
                            $output_122 = join "\n", @sed_result_122;
                            if ($output_122 ne q{} && !defined $output_printed_122) {
                                print $output_122;
                                if (!($output_122 =~ m{\n\z}msx)) {
                                    print "\n";
                                }
                            }
                            if ( !$pipeline_success_122 ) { $main_exit_code = 1; }
                            }
                        $main_exit_code = system('unzip', '-v', "$_[0]") >> 8;
}
                    else {
                        print "No unzip available\n";
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_125 = '[:upper:]';
my $set2_125 = '[:lower:]';
my $input_125 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_125 = $set1_125;
my $expanded_set2_125 = $set2_125;
# Handle a-z range in set1
if ($expanded_set1_125 =~ /a-z/msx) {
    $expanded_set1_125 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_125 =~ /A-Z/msx) {
    $expanded_set1_125 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_125 =~ /\[:upper:\]/msx) {
    $expanded_set1_125 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_125 =~ /\[:lower:\]/msx) {
    $expanded_set1_125 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_125 =~ /a-z/msx) {
    $expanded_set2_125 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_125 =~ /A-Z/msx) {
    $expanded_set2_125 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_125 =~ /\[:upper:\]/msx) {
    $expanded_set2_125 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_125 =~ /\[:lower:\]/msx) {
    $expanded_set2_125 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_124 = q{};
for my $char ( split //msx, $input_125 ) {
    my $pos_125 = index $expanded_set1_125, $char;
    if ( $pos_125 >= 0 && $pos_125 < length $expanded_set2_125 ) {
        $tr_result_124 .= substr $expanded_set2_125, $pos_125, 1;
    } else {
        $tr_result_124 .= $char;
    }
}
$tr_result_124
}; $_pipeline_result; } =~ /^.*.xz$/msx) {
                    if ((-x "`which xz`")) {
                        $main_exit_code = system('xz', '-d', q{c}, "$_[0]") >> 8;
}
                    else {
                        print "No xz available\n";
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_127 = '[:upper:]';
my $set2_127 = '[:lower:]';
my $input_127 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_127 = $set1_127;
my $expanded_set2_127 = $set2_127;
# Handle a-z range in set1
if ($expanded_set1_127 =~ /a-z/msx) {
    $expanded_set1_127 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_127 =~ /A-Z/msx) {
    $expanded_set1_127 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_127 =~ /\[:upper:\]/msx) {
    $expanded_set1_127 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_127 =~ /\[:lower:\]/msx) {
    $expanded_set1_127 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_127 =~ /a-z/msx) {
    $expanded_set2_127 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_127 =~ /A-Z/msx) {
    $expanded_set2_127 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_127 =~ /\[:upper:\]/msx) {
    $expanded_set2_127 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_127 =~ /\[:lower:\]/msx) {
    $expanded_set2_127 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_126 = q{};
for my $char ( split //msx, $input_127 ) {
    my $pos_127 = index $expanded_set1_127, $char;
    if ( $pos_127 >= 0 && $pos_127 < length $expanded_set2_127 ) {
        $tr_result_126 .= substr $expanded_set2_127, $pos_127, 1;
    } else {
        $tr_result_126 .= $char;
    }
}
$tr_result_126
}; $_pipeline_result; } =~ /^.*.zst$/msx) {
                    if ((-x "`which zstd`")) {
                        $main_exit_code = system('zstd', '-qdc', "$_[0]") >> 8;
}
                    else {
                        print "No zstd available\n";
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_129 = '[:upper:]';
my $set2_129 = '[:lower:]';
my $input_129 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_129 = $set1_129;
my $expanded_set2_129 = $set2_129;
# Handle a-z range in set1
if ($expanded_set1_129 =~ /a-z/msx) {
    $expanded_set1_129 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_129 =~ /A-Z/msx) {
    $expanded_set1_129 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_129 =~ /\[:upper:\]/msx) {
    $expanded_set1_129 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_129 =~ /\[:lower:\]/msx) {
    $expanded_set1_129 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_129 =~ /a-z/msx) {
    $expanded_set2_129 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_129 =~ /A-Z/msx) {
    $expanded_set2_129 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_129 =~ /\[:upper:\]/msx) {
    $expanded_set2_129 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_129 =~ /\[:lower:\]/msx) {
    $expanded_set2_129 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_128 = q{};
for my $char ( split //msx, $input_129 ) {
    my $pos_129 = index $expanded_set1_129, $char;
    if ( $pos_129 >= 0 && $pos_129 < length $expanded_set2_129 ) {
        $tr_result_128 .= substr $expanded_set2_129, $pos_129, 1;
    } else {
        $tr_result_128 .= $char;
    }
}
$tr_result_128
}; $_pipeline_result; } =~ /^.*.gz$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_131 = '[:upper:]';
my $set2_131 = '[:lower:]';
my $input_131 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_131 = $set1_131;
my $expanded_set2_131 = $set2_131;
# Handle a-z range in set1
if ($expanded_set1_131 =~ /a-z/msx) {
    $expanded_set1_131 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_131 =~ /A-Z/msx) {
    $expanded_set1_131 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_131 =~ /\[:upper:\]/msx) {
    $expanded_set1_131 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_131 =~ /\[:lower:\]/msx) {
    $expanded_set1_131 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_131 =~ /a-z/msx) {
    $expanded_set2_131 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_131 =~ /A-Z/msx) {
    $expanded_set2_131 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_131 =~ /\[:upper:\]/msx) {
    $expanded_set2_131 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_131 =~ /\[:lower:\]/msx) {
    $expanded_set2_131 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_130 = q{};
for my $char ( split //msx, $input_131 ) {
    my $pos_131 = index $expanded_set1_131, $char;
    if ( $pos_131 >= 0 && $pos_131 < length $expanded_set2_131 ) {
        $tr_result_130 .= substr $expanded_set2_131, $pos_131, 1;
    } else {
        $tr_result_130 .= $char;
    }
}
$tr_result_130
}; $_pipeline_result; } =~ /^.*.z$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_133 = '[:upper:]';
my $set2_133 = '[:lower:]';
my $input_133 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_133 = $set1_133;
my $expanded_set2_133 = $set2_133;
# Handle a-z range in set1
if ($expanded_set1_133 =~ /a-z/msx) {
    $expanded_set1_133 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_133 =~ /A-Z/msx) {
    $expanded_set1_133 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_133 =~ /\[:upper:\]/msx) {
    $expanded_set1_133 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_133 =~ /\[:lower:\]/msx) {
    $expanded_set1_133 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_133 =~ /a-z/msx) {
    $expanded_set2_133 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_133 =~ /A-Z/msx) {
    $expanded_set2_133 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_133 =~ /\[:upper:\]/msx) {
    $expanded_set2_133 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_133 =~ /\[:lower:\]/msx) {
    $expanded_set2_133 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_132 = q{};
for my $char ( split //msx, $input_133 ) {
    my $pos_133 = index $expanded_set1_133, $char;
    if ( $pos_133 >= 0 && $pos_133 < length $expanded_set2_133 ) {
        $tr_result_132 .= substr $expanded_set2_133, $pos_133, 1;
    } else {
        $tr_result_132 .= $char;
    }
}
$tr_result_132
}; $_pipeline_result; } =~ /^.*.dz$/msx) {
                    my @results;
if (-f q{c}) {
if (q{c}.gz =~ /[\[].]gz$/msx) {
my ($in_135);
my $pid_135 = open3($in_135, $out_135, $err_135, 'gunzip', '-c', 'q{c}.gz');
close $in_135 or croak 'Close failed: $OS_ERROR';
my $decompressed = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_135> };
close $out_135 or croak 'Close failed: $OS_ERROR';
waitpid $pid_135, 0;
if (defined $decompressed) {
push @results, "Decompressed: q{c}";
} else {
push @results, "Failed to decompress: q{c}";
}
} else {
push @results, "File not compressed: q{c}";
}
} else {
push @results, "File not found: q{c}";
}
if (-f "$_[0]") {
if ("$_[0]".gz =~ /[\[].]gz$/msx) {
my ($in_136);
my $pid_136 = open3($in_136, $out_136, $err_136, 'gunzip', '-c', '"$_[0]".gz');
close $in_136 or croak 'Close failed: $OS_ERROR';
my $decompressed = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_136> };
close $out_136 or croak 'Close failed: $OS_ERROR';
waitpid $pid_136, 0;
if (defined $decompressed) {
push @results, "Decompressed: "$_[0]"";
} else {
push @results, "Failed to decompress: "$_[0]"";
}
} else {
push @results, "File not compressed: "$_[0]"";
}
} else {
push @results, "File not found: "$_[0]"";
}
 = join "\n", @results;

                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_138 = '[:upper:]';
my $set2_138 = '[:lower:]';
my $input_138 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_138 = $set1_138;
my $expanded_set2_138 = $set2_138;
# Handle a-z range in set1
if ($expanded_set1_138 =~ /a-z/msx) {
    $expanded_set1_138 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_138 =~ /A-Z/msx) {
    $expanded_set1_138 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_138 =~ /\[:upper:\]/msx) {
    $expanded_set1_138 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_138 =~ /\[:lower:\]/msx) {
    $expanded_set1_138 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_138 =~ /a-z/msx) {
    $expanded_set2_138 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_138 =~ /A-Z/msx) {
    $expanded_set2_138 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_138 =~ /\[:upper:\]/msx) {
    $expanded_set2_138 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_138 =~ /\[:lower:\]/msx) {
    $expanded_set2_138 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_137 = q{};
for my $char ( split //msx, $input_138 ) {
    my $pos_138 = index $expanded_set1_138, $char;
    if ( $pos_138 >= 0 && $pos_138 < length $expanded_set2_138 ) {
        $tr_result_137 .= substr $expanded_set2_138, $pos_138, 1;
    } else {
        $tr_result_137 .= $char;
    }
}
$tr_result_137
}; $_pipeline_result; } =~ /^.*.tar$/msx) {
                                        $main_exit_code = system('tar', 'tvf', "$_[0]", '--force-local') >> 8;
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_140 = '[:upper:]';
my $set2_140 = '[:lower:]';
my $input_140 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_140 = $set1_140;
my $expanded_set2_140 = $set2_140;
# Handle a-z range in set1
if ($expanded_set1_140 =~ /a-z/msx) {
    $expanded_set1_140 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_140 =~ /A-Z/msx) {
    $expanded_set1_140 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_140 =~ /\[:upper:\]/msx) {
    $expanded_set1_140 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_140 =~ /\[:lower:\]/msx) {
    $expanded_set1_140 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_140 =~ /a-z/msx) {
    $expanded_set2_140 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_140 =~ /A-Z/msx) {
    $expanded_set2_140 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_140 =~ /\[:upper:\]/msx) {
    $expanded_set2_140 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_140 =~ /\[:lower:\]/msx) {
    $expanded_set2_140 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_139 = q{};
for my $char ( split //msx, $input_140 ) {
    my $pos_140 = index $expanded_set1_140, $char;
    if ( $pos_140 >= 0 && $pos_140 < length $expanded_set2_140 ) {
        $tr_result_139 .= substr $expanded_set2_140, $pos_140, 1;
    } else {
        $tr_result_139 .= $char;
    }
}
$tr_result_139
}; $_pipeline_result; } =~ /^.*.jar$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_142 = '[:upper:]';
my $set2_142 = '[:lower:]';
my $input_142 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_142 = $set1_142;
my $expanded_set2_142 = $set2_142;
# Handle a-z range in set1
if ($expanded_set1_142 =~ /a-z/msx) {
    $expanded_set1_142 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_142 =~ /A-Z/msx) {
    $expanded_set1_142 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_142 =~ /\[:upper:\]/msx) {
    $expanded_set1_142 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_142 =~ /\[:lower:\]/msx) {
    $expanded_set1_142 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_142 =~ /a-z/msx) {
    $expanded_set2_142 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_142 =~ /A-Z/msx) {
    $expanded_set2_142 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_142 =~ /\[:upper:\]/msx) {
    $expanded_set2_142 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_142 =~ /\[:lower:\]/msx) {
    $expanded_set2_142 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_141 = q{};
for my $char ( split //msx, $input_142 ) {
    my $pos_142 = index $expanded_set1_142, $char;
    if ( $pos_142 >= 0 && $pos_142 < length $expanded_set2_142 ) {
        $tr_result_141 .= substr $expanded_set2_142, $pos_142, 1;
    } else {
        $tr_result_141 .= $char;
    }
}
$tr_result_141
}; $_pipeline_result; } =~ /^.*.war$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_144 = '[:upper:]';
my $set2_144 = '[:lower:]';
my $input_144 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_144 = $set1_144;
my $expanded_set2_144 = $set2_144;
# Handle a-z range in set1
if ($expanded_set1_144 =~ /a-z/msx) {
    $expanded_set1_144 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_144 =~ /A-Z/msx) {
    $expanded_set1_144 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_144 =~ /\[:upper:\]/msx) {
    $expanded_set1_144 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_144 =~ /\[:lower:\]/msx) {
    $expanded_set1_144 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_144 =~ /a-z/msx) {
    $expanded_set2_144 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_144 =~ /A-Z/msx) {
    $expanded_set2_144 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_144 =~ /\[:upper:\]/msx) {
    $expanded_set2_144 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_144 =~ /\[:lower:\]/msx) {
    $expanded_set2_144 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_143 = q{};
for my $char ( split //msx, $input_144 ) {
    my $pos_144 = index $expanded_set1_144, $char;
    if ( $pos_144 >= 0 && $pos_144 < length $expanded_set2_144 ) {
        $tr_result_143 .= substr $expanded_set2_144, $pos_144, 1;
    } else {
        $tr_result_143 .= $char;
    }
}
$tr_result_143
}; $_pipeline_result; } =~ /^.*.ear$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_146 = '[:upper:]';
my $set2_146 = '[:lower:]';
my $input_146 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_146 = $set1_146;
my $expanded_set2_146 = $set2_146;
# Handle a-z range in set1
if ($expanded_set1_146 =~ /a-z/msx) {
    $expanded_set1_146 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_146 =~ /A-Z/msx) {
    $expanded_set1_146 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_146 =~ /\[:upper:\]/msx) {
    $expanded_set1_146 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_146 =~ /\[:lower:\]/msx) {
    $expanded_set1_146 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_146 =~ /a-z/msx) {
    $expanded_set2_146 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_146 =~ /A-Z/msx) {
    $expanded_set2_146 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_146 =~ /\[:upper:\]/msx) {
    $expanded_set2_146 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_146 =~ /\[:lower:\]/msx) {
    $expanded_set2_146 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_145 = q{};
for my $char ( split //msx, $input_146 ) {
    my $pos_146 = index $expanded_set1_146, $char;
    if ( $pos_146 >= 0 && $pos_146 < length $expanded_set2_146 ) {
        $tr_result_145 .= substr $expanded_set2_146, $pos_146, 1;
    } else {
        $tr_result_145 .= $char;
    }
}
$tr_result_145
}; $_pipeline_result; } =~ /^.*.xpi$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_148 = '[:upper:]';
my $set2_148 = '[:lower:]';
my $input_148 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_148 = $set1_148;
my $expanded_set2_148 = $set2_148;
# Handle a-z range in set1
if ($expanded_set1_148 =~ /a-z/msx) {
    $expanded_set1_148 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_148 =~ /A-Z/msx) {
    $expanded_set1_148 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_148 =~ /\[:upper:\]/msx) {
    $expanded_set1_148 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_148 =~ /\[:lower:\]/msx) {
    $expanded_set1_148 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_148 =~ /a-z/msx) {
    $expanded_set2_148 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_148 =~ /A-Z/msx) {
    $expanded_set2_148 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_148 =~ /\[:upper:\]/msx) {
    $expanded_set2_148 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_148 =~ /\[:lower:\]/msx) {
    $expanded_set2_148 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_147 = q{};
for my $char ( split //msx, $input_148 ) {
    my $pos_148 = index $expanded_set1_148, $char;
    if ( $pos_148 >= 0 && $pos_148 < length $expanded_set2_148 ) {
        $tr_result_147 .= substr $expanded_set2_148, $pos_148, 1;
    } else {
        $tr_result_147 .= $char;
    }
}
$tr_result_147
}; $_pipeline_result; } =~ /^.*.zip$/msx) {
                    if ((-x "`which unzip`")) {
                        $main_exit_code = system('unzip', '-v', "$_[0]") >> 8;
}
                    else {
                        if ((-x "`which miniunzip`")) {
                            $main_exit_code = system('miniunzip', '-l', "$_[0]") >> 8;
}
                        else {
                            if ((-x "`which miniunz`")) {
                                $main_exit_code = system('miniunz', '-l', "$_[0]") >> 8;
}
                            else {
                                print "No unzip, miniunzip or miniunz available\n";
                            }
                        }
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_150 = '[:upper:]';
my $set2_150 = '[:lower:]';
my $input_150 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_150 = $set1_150;
my $expanded_set2_150 = $set2_150;
# Handle a-z range in set1
if ($expanded_set1_150 =~ /a-z/msx) {
    $expanded_set1_150 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_150 =~ /A-Z/msx) {
    $expanded_set1_150 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_150 =~ /\[:upper:\]/msx) {
    $expanded_set1_150 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_150 =~ /\[:lower:\]/msx) {
    $expanded_set1_150 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_150 =~ /a-z/msx) {
    $expanded_set2_150 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_150 =~ /A-Z/msx) {
    $expanded_set2_150 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_150 =~ /\[:upper:\]/msx) {
    $expanded_set2_150 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_150 =~ /\[:lower:\]/msx) {
    $expanded_set2_150 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_149 = q{};
for my $char ( split //msx, $input_150 ) {
    my $pos_150 = index $expanded_set1_150, $char;
    if ( $pos_150 >= 0 && $pos_150 < length $expanded_set2_150 ) {
        $tr_result_149 .= substr $expanded_set2_150, $pos_150, 1;
    } else {
        $tr_result_149 .= $char;
    }
}
$tr_result_149
}; $_pipeline_result; } =~ /^.*.7z$/msx) {
                    if ((-x "`which 7za`")) {
                        $main_exit_code = system('7za', q{l}, "$_[0]") >> 8;
}
                    else {
                        if ((-x "`which 7zr`")) {
                            $main_exit_code = system('7zr', q{l}, "$_[0]") >> 8;
}
                        else {
                            print "No 7za or 7zr available\n";
                        }
                    }
                } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ("$_[0]") . "\n";
    my $set1_152 = '[:upper:]';
my $set2_152 = '[:lower:]';
my $input_152 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_152 = $set1_152;
my $expanded_set2_152 = $set2_152;
# Handle a-z range in set1
if ($expanded_set1_152 =~ /a-z/msx) {
    $expanded_set1_152 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_152 =~ /A-Z/msx) {
    $expanded_set1_152 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_152 =~ /\[:upper:\]/msx) {
    $expanded_set1_152 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_152 =~ /\[:lower:\]/msx) {
    $expanded_set1_152 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_152 =~ /a-z/msx) {
    $expanded_set2_152 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_152 =~ /A-Z/msx) {
    $expanded_set2_152 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_152 =~ /\[:upper:\]/msx) {
    $expanded_set2_152 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_152 =~ /\[:lower:\]/msx) {
    $expanded_set2_152 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_151 = q{};
for my $char ( split //msx, $input_152 ) {
    my $pos_152 = index $expanded_set1_152, $char;
    if ( $pos_152 >= 0 && $pos_152 < length $expanded_set2_152 ) {
        $tr_result_151 .= substr $expanded_set2_152, $pos_152, 1;
    } else {
        $tr_result_151 .= $char;
    }
}
$tr_result_151
}; $_pipeline_result; } =~ /^.*.zoo$/msx) {
                    if ((-x "`which zoo`")) {
                        $main_exit_code = system('zoo', q{v}, "$_[0]") >> 8;
}
                    else {
                        if ((-x "`which unzoo`")) {
                            $main_exit_code = system('unzoo', '-l', "$_[0]") >> 8;
}
                        else {
                            print "No unzoo or zoo available\n";
                        }
                    }
                }
            q{};
        };
    };
if ($BASENAME eq $LESSFILE) {
if (((-s $TMPFILE) > 0)) {
            print $TMPFILE;
if ( !( ($TMPFILE) =~ m{\n\z}msx ) ) { print "\n"; }
}
        else {
if ( -e "$TMPFILE" ) {
                if ( -d "$TMPFILE" ) {
                    carp "rm: carping: ", $TMPFILE,
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$TMPFILE" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", $TMPFILE,
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
        }
    }
}
else {
    if ((scalar(@ARGV) == 2)) {
if ($BASENAME eq $LESSFILE) {
if ("$BASH" ne q{}) {
if ((! -O "$2")) {
                    do {
                        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>', '/dev/tty'
      or die "Cannot open file: $OS_ERROR\n";
                        do {
    my $__echo_line = "Error in deleting $_[1]";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                        $CHILD_ERROR = 0;
                        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                    };
exit 1;
                }
            }
if ((-f "$2")) {
if ( -e "$_[1]" ) {
                    if ( -d "$_[1]" ) {
                        carp "rm: carping: ", "$_[1]",
          " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink "$_[1]" ) {
                                                    }
                        else {
                            carp "rm: carping: could not remove ", "$_[1]",
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 0;
                }
}
            else {
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', '/dev/tty'
      or die "Cannot open file: $OS_ERROR\n";
                    do {
    my $__echo_line = "Error in deleting $_[1]";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
            }
        }
}
    else {
        if ((scalar(@ARGV) == 0)) {
            my $FULLPATH;
            my @FULLPATH;
            my %FULLPATH;
            $FULLPATH = do { chdir("\\" . chr(96) . "dirname"); q{} };
;
            $main_exit_code = system('/', $BASENAME) >> 8;
if ("$ENV{SHELL}" =~ /^.*csh$/msx) {
                if ($BASENAME eq $LESSFILE) {
                    do {
    my $__echo_line = "setenv LESSOPEN \"$FULLPATH %s\";";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                    do {
    my $__echo_line = "setenv LESSCLOSE \"$FULLPATH %s %s\";";
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
    my $__echo_line = "setenv LESSOPEN \"| $FULLPATH %s\";";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                    do {
    my $__echo_line = "setenv LESSCLOSE \"$FULLPATH %s %s\";";
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
                if ($BASENAME eq $LESSFILE) {
                    do {
    my $__echo_line = "export LESSOPEN=\"$FULLPATH %s\";";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                    do {
    my $__echo_line = "export LESSCLOSE=\"$FULLPATH %s %s\";";
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
    my $__echo_line = "export LESSOPEN=\"| $FULLPATH %s\";";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                    do {
    my $__echo_line = "export LESSCLOSE=\"$FULLPATH %s %s\";";
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
            do {
    my $__echo_line = "Usage: eval " . (do { my $_chomp_temp = do {
    my ($in_153, $out_153);
    my $pid_153 = open3($in_153, $out_153, '>&STDERR', $BASENAME);
    close $in_153 or croak 'Close failed: $OS_ERROR';
    my $result_153 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_153> };
    close $out_153 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_153, 0;
    $result_153
}; chomp $_chomp_temp; $_chomp_temp; });
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
exit $main_exit_code;
        }
    }
}

exit $main_exit_code;
