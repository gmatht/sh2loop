#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use IPC::Open3;
use File::Path qw(make_path remove_tree);
use File::Copy qw(copy move);

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

my $EUID;
my @EUID;
my %EUID;

if (! $1 ne q{}) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
    };
    $CHILD_ERROR = 0;
exit -1;
}
if (($EUID != 0)) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
    };
    $main_exit_code = system('bash', 'This program must be run with superuser rights') >> 8;
exit -1;
}
if ((!-f $1)) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
    };
    $CHILD_ERROR = 0;
exit -1;
}
if ($1 =~ /^.*[.]dts$/msx) {
    my $fname;
    my @fname;
    my %fname;
    $fname = do { use File::Basename qw(basename); my $basename_output = basename($1); $CHILD_ERROR = 0; $basename_output; };
}
else {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
    };
    $main_exit_code = system('bash', 'Overlay source file name should have the .dts extension') >> 8;
exit -1;
}
if (((!-f /etc/orangepi-release) || (!-f /boot/orangepiEnv.txt))) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
    };
    $main_exit_code = system('bash', 'Orange Pi is not installed properly. Missing orangepi-release or orangepiEnv.txt') >> 8;
exit -1;
}
$main_exit_code = system('.', '/etc/orangepi-release') >> 8;
if (($ENV{LINUXFAMILY} // q{}) =~ /^sunxi$/msx or ($ENV{LINUXFAMILY} // q{}) =~ /^sunxi64$/msx or ($ENV{LINUXFAMILY} // q{}) =~ /^rockchip64$/msx or ($ENV{LINUXFAMILY} // q{}) =~ /^sun50iw9$/msx or ($ENV{LINUXFAMILY} // q{}) =~ /^sun50iw6$/msx or ($ENV{LINUXFAMILY} // q{}) =~ /^rk3399$/msx) {
        $main_exit_code = system('bash', ':') >> 8;
} elsif (1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
    };
        $CHILD_ERROR = 0;
    exit -1;
}
if ((-d '/lib/modules/$(uname -r)/build/scripts/dtc')) {
if ((!-x /lib/modules/qx'uname -r'/build/scripts/dtc/dtc ne q{})) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "\n";
            $CHILD_ERROR = 0;
        };
        $main_exit_code = system('bash', 'Error: kernel headers are not installed properly') >> 8;
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "\n";
            $CHILD_ERROR = 0;
        };
        $main_exit_code = system('bash', 'Can't find dtc that supports compiling overlays') >> 8;
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "\n";
            $CHILD_ERROR = 0;
        };
        $CHILD_ERROR = 0;
exit -1;
}
    else {
$ENV{PATH} = '/lib/modules/';
$ENV{/build/scripts/dtc/:} = $/build/scripts/dtc/:;
    }
}
if (!(!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('type', 'dtc') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};))) {
    print "Error: dtc not found in PATH\n";
    print "Please try to install matching kernel headers\n";
exit -1;
}
if (!(!(my $temp_file_ps_fh_1 = q{/tmp} . '/process_sub_fh_1.tmp';
my $output_ps_fh_1;
{
my ($in, $out);
my $pid = open3($in, $out, '>&STDERR', 'bash', '-c', 'dtc --help');
close $in or croak 'Close failed: $OS_ERROR';
$output_ps_fh_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
close $out or croak 'Close failed: $OS_ERROR';
waitpid $pid, 0;
$CHILD_ERROR = $? >> 8;
}
use File::Path qw(make_path);
my $temp_dir_fh_1 = dirname($temp_file_ps_fh_1);
if (!-d $temp_dir_fh_1) { make_path($temp_dir_fh_1); }
open my $fh_ps_fh_1, '>', $temp_file_ps_fh_1 or croak "Cannot create temp file: $ERRNO\n";
print {$fh_ps_fh_1} $output_ps_fh_1;
close $fh_ps_fh_1 or croak "Close failed: $ERRNO\n";
open STDIN, '<', $temp_file_ps_fh_1 or croak "Cannot open process substitution: $ERRNO\n";
my $grep_result_0;
my @grep_lines_0 = ();
my @grep_filtered_0 = grep { /symbols/msx } @grep_lines_0;
$grep_result_0 = join "\n", @grep_filtered_0;
if (!($grep_result_0 =~ m{\n\z}msx || $grep_result_0 eq q{})) {
    $grep_result_0 .= "\n";
}
$CHILD_ERROR = scalar @grep_filtered_0 > 0 ? 0 : 1;
$grep_result_0 = q{};))) {
    print "Error: dtc does not support compiling overlays\n";
exit -1;
}
if ((!-d /boot/overlay-user)) {
    use File::Path qw(make_path);
    my $err;
    if ( !-d '/boot/overlay-user' ) {
        make_path( '/boot/overlay-user', { error => \$err } );
        if ( @{$err} ) {
            croak "mkdir: cannot create directory " . '/boot/overlay-user' . ": $err->[0]\n";
        }
    }
}
my $temp_dir;
my @temp_dir;
my %temp_dir;
$temp_dir = do {
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'mktemp', '-d');
    close $in_2 or croak 'Close failed: $OS_ERROR';
    my $result_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    $result_2
};
print "Compiling the overlay\n";
$main_exit_code = system('dtc', q{-}, q{@}, '-q', '-I', 'dts', '-O', 'dtb', '-o', $temp_dir, q{/}, $fname, '.dtbo', $1) >> 8;
if (($? != 0)) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
    };
    $main_exit_code = system('bash', 'Error compiling the overlay') >> 8;
exit -1;
}
print "Copying the compiled overlay file to /boot/overlay-user/\n";
use File::Copy qw(copy);
if ( -e $temp_dir ) {
    if ( -d '.dtbo' ) {
        require File::Copy; File::Copy::copy($temp_dir, '.dtbo' . '/' . ($temp_dir =~ m|([^/]+)$|)[0]);
    } else {
        require File::Copy; File::Copy::copy($temp_dir, '.dtbo');
    }
} else {
    croak "cp: cannot stat '$temp_dir': No such file or directory\n";
}
if ( -e q{/} ) {
    if ( -d '.dtbo' ) {
        require File::Copy; File::Copy::copy(q{/}, '.dtbo' . '/' . (q{/} =~ m|([^/]+)$|)[0]);
    } else {
        require File::Copy; File::Copy::copy(q{/}, '.dtbo');
    }
} else {
    croak "cp: cannot stat '$temp_dir': No such file or directory\n";
}
if ( -e $fname ) {
    if ( -d '.dtbo' ) {
        require File::Copy; File::Copy::copy($fname, '.dtbo' . '/' . ($fname =~ m|([^/]+)$|)[0]);
    } else {
        require File::Copy; File::Copy::copy($fname, '.dtbo');
    }
} else {
    croak "cp: cannot stat '$temp_dir': No such file or directory\n";
}
if ( -e '.dtbo' ) {
    if ( -d '.dtbo' ) {
        require File::Copy; File::Copy::copy('.dtbo', '.dtbo' . '/' . ('.dtbo' =~ m|([^/]+)$|)[0]);
    } else {
        require File::Copy; File::Copy::copy('.dtbo', '.dtbo');
    }
} else {
    croak "cp: cannot stat '$temp_dir': No such file or directory\n";
}
if ( -e '/boot/overlay-user/' ) {
    if ( -d '.dtbo' ) {
        require File::Copy; File::Copy::copy('/boot/overlay-user/', '.dtbo' . '/' . ('/boot/overlay-user/' =~ m|([^/]+)$|)[0]);
    } else {
        require File::Copy; File::Copy::copy('/boot/overlay-user/', '.dtbo');
    }
} else {
    croak "cp: cannot stat '$temp_dir': No such file or directory\n";
}
if ( -e $fname ) {
    if ( -d '.dtbo' ) {
        require File::Copy; File::Copy::copy($fname, '.dtbo' . '/' . ($fname =~ m|([^/]+)$|)[0]);
    } else {
        require File::Copy; File::Copy::copy($fname, '.dtbo');
    }
} else {
    croak "cp: cannot stat '$temp_dir': No such file or directory\n";
}
if (!(my $grep_result_4;
my @grep_lines_4 = ();
my @grep_filenames_4 = ();
if (-e "/boot/orangepiEnv.txt") {
    open my $fh, '<', "/boot/orangepiEnv.txt" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_4, $line;
        push @grep_filenames_4, "/boot/orangepiEnv.txt";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /boot/orangepiEnv.txt: No such file or directory\n"; }
my @grep_filtered_4 = grep { /^user_overlays=/msx } @grep_lines_4;
$grep_result_4 = join "\n", @grep_filtered_4;
if (!($grep_result_4 =~ m{\n\z}msx || $grep_result_4 eq q{})) {
    $grep_result_4 .= "\n";
}
$CHILD_ERROR = scalar @grep_filtered_4 > 0 ? 0 : 1;
$grep_result_4 = q{})) {
    my $line;
    my @line;
    my %line;
    $line = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_5 = q{};
        my $output_printed_5;
        my $pipeline_success_5 = 1;
        my $grep_result_5_0;
        my @grep_lines_5_0 = ();
        my @grep_filenames_5_0 = ();
        if (-e "/boot/orangepiEnv.txt") {
            open my $fh, '<', "/boot/orangepiEnv.txt" or croak "Cannot open file: $ERRNO";
            while (my $line = <$fh>) {
                chomp $line;
                push @grep_lines_5_0, $line;
                push @grep_filenames_5_0, "/boot/orangepiEnv.txt";
            }
            close $fh
                or croak "Close failed: $OS_ERROR";
        }
        else { print {*STDERR} "grep: /boot/orangepiEnv.txt: No such file or directory\n"; }
        my @grep_filtered_5_0 = grep { /^user_overlays=/msx } @grep_lines_5_0;
        $grep_result_5_0 = join "\n", @grep_filtered_5_0;
                if (!($grep_result_5_0 =~ m{\n\z}msx || $grep_result_5_0 eq q{})) {
                    $grep_result_5_0 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_5_0 > 0 ? 0 : 1;
        $output_5 = $grep_result_5_0;
        if ($CHILD_ERROR != 0) { $pipeline_success_5 = 0; }
        my @lines_6 = split /\n/msx, $output_5;
        my @result_6;
        foreach my $line (@lines_6) {
        chomp $line;
        my @fields = split /=/msx, $line;
        if (@fields > 1) {
            push @result_6, $fields[1];
        }
        }
        $output_5 = join "\n", @result_6;
        if ($output_5 ne q{} && !($output_5  =~ m{\n\z}msx)) { $output_5 .= "\n"; }

        if ( !$pipeline_success_5 ) { $main_exit_code = 1; }
        $output_5 =~ s/\n+\z//msx;
        $output_5;
}; $_pipeline_result; };
if (!(    my $here_string_content_fh_2 = $line;
my $grep_result_0;
my @grep_lines_0 = split /\n/msx, $here_string_content_fh_2;
my @grep_filtered_0 = grep { /(^|[[:space:]])"\ .\ ${fname}\ .\ "([[:space:]]|$)/msx } @grep_lines_0;
$grep_result_0 = join "\n", @grep_filtered_0;
    if (!($grep_result_0 =~ m{\n\z}msx || $grep_result_0 eq q{})) {
        $grep_result_0 .= "\n";
    }
$CHILD_ERROR = scalar @grep_filtered_0 > 0 ? 0 : 1;
$grep_result_0 = q{})) {
        do {
    my $__echo_line = "Overlay " . ${fname} . " was already added to /boot/orangepiEnv.txt, skipping";
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
my @sed_lines_7 = split /\n/msx, $;
my @sed_result_7;
foreach my $line (@sed_lines_7) {
chomp $line;
push @sed_result_7, $line;
}
$ = join "\n", @sed_result_7;

    }
}
else {
my @sed_lines_8 = split /\n/msx, $;
my @sed_result_8;
foreach my $line (@sed_lines_8) {
chomp $line;
push @sed_result_8, $line;
}
$ = join "\n", @sed_result_8;

}
print "Reboot is required to apply the changes\n";

exit $main_exit_code;
