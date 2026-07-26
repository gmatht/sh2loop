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

my $PORT;
my @PORT;
my %PORT;
$PORT = '8000';
my $XNC;
my @XNC;
my %XNC;
$XNC = q{};
if ($_[0] . ($ENV{RDEST} // q{}) =~ /^$/msx) {
        print 'needs' . q{ } . 'hostname' . "\n";
    $CHILD_ERROR = 0;
    exit 1;
}
if ($_[0] =~ /^$/msx) {
        if (my $pid = fork()) {
        # Parent process continues
    } elsif (defined $pid) {
        # Child process executes the background command
open STDIN, '<', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('nc', '-w', '600', '-l', '-n', '-p', $PORT, '-e', "$PROGRAM_NAME", $XNC) >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit(0);
    } else {
        die "Cannot fork: $ERRNO\n";
    }
    # Builtin command 'exec' not implemented
}
my $RDEST;
my @RDEST;
my %RDEST;
$RDEST = "$_[0]";
my $RPORT;
my @RPORT;
my %RPORT;
$RPORT = "$_[1]";
$main_exit_code = system('test', "$RPORT") >> 8;
if ($CHILD_ERROR != 0) {
        $RPORT = '80';
}
$ENV{RDEST} = $RDEST;
$ENV{RPORT} = $RPORT;
if (my $pid = fork()) {
    # Parent process continues
} elsif (defined $pid) {
    # Child process executes the background command
open STDIN, '<', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('nc', '-v', '-w', '600', '-l', '-p', $PORT, '-e', "$PROGRAM_NAME", $XNC) >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    exit(0);
} else {
    die "Cannot fork: $ERRNO\n";
}
do {
    my $__echo_line = "Relay to " . ${RDEST} . ":" . ${RPORT} . " running -- point your browser here on port $PORT";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
exit 0;

exit $main_exit_code;
