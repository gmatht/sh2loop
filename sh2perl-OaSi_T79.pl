#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use IPC::Open3;
use File::Path qw(make_path remove_tree);

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

my $MAGIC_32 = 32;


sub help {
print "Usage: devinput.sh [-i]  [input.h path] > outfile

devinput.sh parses a linux input.h header file and produces a
lircd.conf file for the devinput driver tailored for the local
system. Using the -i option, it produces an internal format
used when building lirc.

input.h path defaults to /usr/include/linux/input.h, often in
the kernel-headers package.

Script uses the python interpreter defined by the PYTHON
environment variable, falling back to 'python'
";
    return;
}
my $here;
my @here;
my %here;
$here = do { use File::Basename qw(dirname); my $dirname_output = dirname(do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', (defined ($ENV{PYTHON} // q{}) && ($ENV{PYTHON} // q{}) ne q{} ? ($ENV{PYTHON} // q{}) : ''python''), '-c', "import os; print(os.path.realpath(\"$PROGRAM_NAME\"))");
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
}); $CHILD_ERROR = 0; $dirname_output; };
if (!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $_wa0 = 'gsed';
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
})) {
    my $SED;
    my @SED;
    my %SED;
    $SED = 'gsed';
}
else {
    $SED = 'sed';
}
my $lirc_map;
my @lirc_map;
my %lirc_map;
$lirc_map = q{};
if (("$1" eq '-h' || "$1" eq '--help')) {
    help();
exit 0;
}
else {
    if ("$1" eq -i) {
        $lirc_map = "true";
# Builtin command 'shift' not implemented
    }
}
# readonly TYPES not implemented in Perl
# readonly = not implemented in Perl
if ((-e 'StringInterpolation(StringInterpolation { parts: [Literal("/usr/include/linux/input-event-codes.h")] }, None)')) {
# readonly file not implemented in Perl
# readonly = not implemented in Perl
}
else {
    if ((-e 'StringInterpolation(StringInterpolation { parts: [Literal("/usr/include/linux/input.h")] }, None)')) {
# readonly file not implemented in Perl
# readonly = not implemented in Perl
}
    else {
        if ((-e 'StringInterpolation(StringInterpolation { parts: [Variable("here"), Literal("/../include/linux/input-event-codes.h")] }, None)')) {
# readonly file not implemented in Perl
# readonly = not implemented in Perl
        }
    }
}
my $tmpfile;
my @tmpfile;
my %tmpfile;
$tmpfile = do {
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'mktemp', (defined (defined ($ENV{TMPDIR} // q{}) && ($ENV{TMPDIR} // q{}) ne q{} ? ($ENV{TMPDIR} // q{}) : '/tmp') && (defined ($ENV{TMPDIR} // q{}) && ($ENV{TMPDIR} // q{}) ne q{} ? ($ENV{TMPDIR} // q{}) : '/tmp') ne q{} ? (defined ($ENV{TMPDIR} // q{}) && ($ENV{TMPDIR} // q{}) ne q{} ? ($ENV{TMPDIR} // q{}) : '/tmp') : '/tmp') . "/devinput.XXXXXXXXX");
    close $in_2 or croak 'Close failed: $OS_ERROR';
    my $result_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    $result_2
};
if (!(!($main_exit_code = system('test', '-f', $file) >> 8;))) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "Cannot access $ENV{file}. Giving up";
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
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', $tmpfile
      or die "Cannot open file: $OS_ERROR\n";
    my $type;
    for my $type ($TYPES) {
        # Original bash: grep "^#define ${type}_" < $file | \
{
            my $output_3 = q{};
            my $output_printed_3;
            my $pipeline_success_3 = 1;
                        $output = q{};
            open STDIN, '<', $file or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_4 = q{};
my $grep_result_5;
my @grep_lines_5 = split /\n/msx, $output_3;
my @grep_filtered_5 = grep { /^\#define\ "\ .\ ${type}\ .\ "_/msx } @grep_lines_5;
$grep_result_5 = join "\n", @grep_filtered_5;
            if (!($grep_result_5 =~ m{\n\z}msx || $grep_result_5 eq q{})) {
                $grep_result_5 .= "\n";
            }
$CHILD_ERROR = scalar @grep_filtered_5 > 0 ? 0 : 1;
$tmp_redirect_4 = $grep_result_5;
$tmp_redirect_4;
            $output_3 = $output;

                        my @sort_lines_3_1 = split /\n/msx, $output_3;
            my @sort_sorted_3_1 = sort @sort_lines_3_1;
            my $output_3_1 = join "\n", @sort_sorted_3_1;
            if ($output_3_1 ne q{} && !($output_3_1 =~ m{\n\z}msx)) {
            $output_3_1 .= "\n";
            }
            $output_3 = $output_3_1;
            $output_3 = $output_3_1;

                        my $cmd_7 = 'unknown_command';
            my ($in_6, $out_6);
            my $pid_6 = open3($in_6, $out_6, '>&STDERR', $cmd_7, '-ne');
            print {$in_6} $output_3;
            close $in_6 or croak 'Close failed: $OS_ERROR';
            $output_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> };
            close $out_6 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_6, 0;
            if ($output_3 ne q{} && !defined $output_printed_3) {
                print $output_3;
                if (!($output_3 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
            }
    }
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
if (StringInterpolation(StringInterpolation { parts: [Variable("lirc_map")] }, None) ne q{}) {
print do { my $cat_chunk = q{}; if ( open my $fh, '<', $tmpfile ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $tmpfile . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
if ( -e "$tmpfile" ) {
        if ( -d "$tmpfile" ) {
            carp "rm: carping: ", $tmpfile,
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$tmpfile" ) {
                            }
            else {
                carp "rm: carping: could not remove ", $tmpfile,
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
exit 0;
}
do {
    my $__echo_line = "# Generated by " . (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename($PROGRAM_NAME); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; });
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
print "
begin remote
        name            devinput-64
        bits            16
        eps             30
        aeps            100
        pre_data_bits   16
        pre_data        0x0001
        post_data_bits  32
        post_data       0x00000001
        gap             132799
        toggle_bit      0
\tdriver          devinput

        begin codes
";
open STDIN, '<', $tmpfile or croak "Cannot open file: $OS_ERROR\n";
my @sed_lines_9 = split /\n/msx, $;
my @sed_result_9;
foreach my $line (@sed_lines_9) {
chomp $line;
push @sed_result_9, $line;
}
$ = join "\n", @sed_result_9;

print "        end codes
end remote
";
print "\n";
$CHILD_ERROR = 0;
do {
    my $__echo_line = "# generated by " . (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename($PROGRAM_NAME); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; }) . " (obsolete 32 bit version)";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
print "
begin remote
        name            devinput-32
        bits            16
        eps             30
        aeps            100
        pre_data_bits   16
        pre_data        0x8001
        gap             132799
        toggle_bit      0
        driver          devinput

        begin codes
";
open STDIN, '<', $tmpfile or croak "Cannot open file: $OS_ERROR\n";
my @sed_lines_10 = split /\n/msx, $;
my @sed_result_10;
foreach my $line (@sed_lines_10) {
chomp $line;
push @sed_result_10, $line;
}
$ = join "\n", @sed_result_10;

print "        end codes
end remote
";
if ( -e "$tmpfile" ) {
    if ( -d "$tmpfile" ) {
        carp "rm: carping: ", $tmpfile,
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "$tmpfile" ) {
                    }
        else {
            carp "rm: carping: could not remove ", $tmpfile,
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}

exit $main_exit_code;
