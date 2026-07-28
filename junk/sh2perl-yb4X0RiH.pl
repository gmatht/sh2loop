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


sub get_mysql_option {
    my $result;
    my @result;
    my %result;
    $result = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;

        my ($in_1, $out_1);
        my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'my_print_defaults', );
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
if ("$result" eq q{}) {
        $result = "$_[2]";
    }
    print $result;
if ( !( ($result) =~ m{\n\z}msx ) ) { print "\n"; }
    return;
}

sub sanity {
if (((-e '/etc/mysql/FROZEN') || (-h /etc/mysql/FROZEN))) {
        print "MySQL has been frozen to prevent damage to your " . "sys" . "tem" . ". Please see /etc/mysql/FROZEN for help.\n";
exit 1;
    }
if ((!-r /etc/mysql/my.cnf)) {
        print "MySQL configuration not found at /etc/mysql/my.cnf. Please create one.\n";
exit 1;
    }
    my $datadir;
    my @datadir;
    my %datadir;
    $datadir = do {
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'get_mysql_option', 'mysqld', 'datadir', "/var/lib/mysql");
    close $in_2 or croak 'Close failed: $OS_ERROR';
    my $result_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    $result_2
};
if (((!-d "${datadir}") && (!-L "${datadir}"))) {
        do {
    my $__echo_line = "MySQL data dir not found at " . ${datadir} . ". Please create one.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
exit 1;
    }
if (((!-d "${datadir}/mysql") && (!-L "${datadir}/mysql"))) {
        do {
    my $__echo_line = "MySQL " . "sys" . "tem" . " database not found in " . ${datadir} . ". Please run mysqld --initialize.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
exit 1;
    }
    my $result;
    my @result;
    my %result;
    $result = q{0};
        my $output;
    my @output;
    my %output;
    $output = do { my @_qx_cmd = ("mysqld --verbose --help --innodb-read-only 2>&1 > /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
    if ($CHILD_ERROR != 0) {
                $result = $?;
    }
if (!"$result" eq "0") {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "ERROR: Unable to start MySQL server:\n";
        };
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print $output;
if ( !( ($output) =~ m{\n\z}msx ) ) { print "\n"; }
        };
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "Please take a look at https://wiki.debian.org/Teams/MySQL/FAQ for tips on fixing common upgrade issues.\n";
        };
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "Once the problem is resolved, restart the service.\n";
        };
exit 1;
    }
    return;
}
if ($arg1 =~ /^pre$/msx) {
        sanity();
}

exit $main_exit_code;
