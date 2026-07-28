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

my $current;
my @current;
my %current;
my $looking_for;
my @looking_for;
my %looking_for;
my $SYSTEMD_PROC_CMDLINE;
my @SYSTEMD_PROC_CMDLINE;
my %SYSTEMD_PROC_CMDLINE;
my $param;
my @param;
my %param;
my $name;
my @name;
my %name;
my $in_quote;
my @in_quote;
my %in_quote;

$__set_e = 1;
# set u not implemented
if ((scalar(@ARGV) != 1)) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "Expected kernel parameter name as argument\n";
    };
exit 1;
}
$looking_for = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;
    $output_0 .= $_[0] . "\n";
    if ( !($output_0 =~ m{\n\z}msx) ) { $output_0 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
    my @sed_lines_0 = split /\n/msx, $output_0;
    my @sed_result_0;
    foreach my $line (@sed_lines_0) {
    chomp $line;
    $line =~ s/_/-/gmsx;
    push @sed_result_0, $line;
    }
    $output_0 = join "\n", @sed_result_0;

    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    exit $main_exit_code if $__set_e && $main_exit_code != 0;
    $output_0 =~ s/\n+\z//msx;
    $output_0;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
if ("${SYSTEMD_PROC_CMDLINE:+set}" eq set) {
    my $cmdline;
    my @cmdline;
    my %cmdline;
    $cmdline = ${SYSTEMD_PROC_CMDLINE};
}
else {
    $cmdline = do { my $cat_chunk = q{}; if ( open my $fh, '<', '/proc/cmdline' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/proc/cmdline' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
}
# set -- not implemented
my $whitespaces;
my @whitespaces;
my %whitespaces;
$whitespaces = (do { my $_chomp_temp = sprintf("\t\nvf\r 240");
; chomp $_chomp_temp; $_chomp_temp; });
$in_quote = 'no';
$param = q{};
$current = ${cmdline};
while ( "${current}" ne q{} ) {
    my $suffix;
    my @suffix;
    my %suffix;
    $suffix = (${current} =~ s/^.//r =~ s/^.//r);
    my $char;
    my @char;
    my %char;
    $char = (scalar reverse( (scalar reverse ${current}) =~ s/^\}xiffus\{\$//r ) =~ s/\$\{suffix\}$//r);
    $current = ${suffix};
if (${char} =~ /^\["${whitespaces}"\]$/msx) {
        if ("${in_quote}" eq no) {
if ("${param}" ne q{}) {
# set -- not implemented
            }
            $param = q{};
}
        else {
            $param = ${param} . ${char};
        }
    } elsif (${char} =~ /^$/msx) {
        if ("${in_quote}" eq yes) {
            $in_quote = 'no';
}
        else {
            $in_quote = 'yes';
        }
    } elsif (1) {
                $param = ${param} . ${char};
    }
}
if ("${param}" ne q{}) {
# set -- not implemented
}
for my $param (@ARGV) {
    $name = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_1 = q{};
        my $output_printed_1;
        my $pipeline_success_1 = 1;
        $output_1 .= ${param} =~ s/=.*$//sr . "\n";
        if ( !($output_1 =~ m{\n\z}msx) ) { $output_1 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_1 = 0; }
        my @sed_lines_1 = split /\n/msx, $output_1;
        my @sed_result_1;
        foreach my $line (@sed_lines_1) {
        chomp $line;
        $line =~ s/_/-/gmsx;
        push @sed_result_1, $line;
        }
        $output_1 = join "\n", @sed_result_1;

        if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        $output_1 =~ s/\n+\z//msx;
        $output_1;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
if ("${name}" eq "${looking_for}") {
if (${param} =~ /^.*=.*$/msx) {
                        print ${param} =~ s/^.*?=//r;
if ( !( (${param} =~ s/^.*?=//r) =~ m{\n\z}msx ) ) { print "\n"; }
        }
exit 0;
    }
}
exit 1;

exit $main_exit_code;
