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

my $rv;
my @rv;
my %rv;
my $CRYPTTAB_EXTRA_OPTIONS;
my @CRYPTTAB_EXTRA_OPTIONS;
my %CRYPTTAB_EXTRA_OPTIONS;

$__set_e = 1;
$main_exit_code = system('.', '/lib/cryptsetup/cryptdisks-functions') >> 8;
my $INITSTATE;
my @INITSTATE;
my %INITSTATE;
$INITSTATE = "manual";
my $DEFAULT_LOUD;
my @DEFAULT_LOUD;
my %DEFAULT_LOUD;
$DEFAULT_LOUD = "yes";
my $FORCE_START;
my @FORCE_START;
my %FORCE_START;
$FORCE_START = "yes";

sub usage {
    my $rv = (defined (defined $_[0] && $_[0] ne q{} ? $_[0] : '1') && (defined $_[0] && $_[0] ne q{} ? $_[0] : '1') ne q{} ? (defined $_[0] && $_[0] ne q{} ? $_[0] : '1') : '1');
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "Usage: $PROGRAM_NAME [-r|--readonly] <name> [.. <name>]";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "\n";
        $CHILD_ERROR = 0;
    };
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "reads $ENV{TABFILE} and starts the mapping corresponding to <name>";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
    return;
}
$CRYPTTAB_EXTRA_OPTIONS = q{};
while ( scalar(@ARGV) > 0 ) {
if ("$_[0]" =~ /^-r$/msx or "$_[0]" =~ /^--readonly$/msx) {
                $CRYPTTAB_EXTRA_OPTIONS = (defined (defined ${CRYPTTAB_EXTRA_OPTIONS} && ${CRYPTTAB_EXTRA_OPTIONS} ne q{} ? ${CRYPTTAB_EXTRA_OPTIONS} : '$CRYPTTAB_EXTRA_OPTIONS,') && (defined ${CRYPTTAB_EXTRA_OPTIONS} && ${CRYPTTAB_EXTRA_OPTIONS} ne q{} ? ${CRYPTTAB_EXTRA_OPTIONS} : '$CRYPTTAB_EXTRA_OPTIONS,') ne q{} ? (defined ${CRYPTTAB_EXTRA_OPTIONS} && ${CRYPTTAB_EXTRA_OPTIONS} ne q{} ? ${CRYPTTAB_EXTRA_OPTIONS} : '$CRYPTTAB_EXTRA_OPTIONS,') : '$CRYPTTAB_EXTRA_OPTIONS,') . "readonly";
    } elsif ("$_[0]" =~ /^-h$/msx or "$_[0]" =~ /^--help$/msx or "$_[0]" =~ /^-\.$/msx) {
                usage(q{0});
    } elsif ("$_[0]" =~ /^--$/msx) {
        # Builtin command 'shift' not implemented
        last;    } elsif ("$_[0]" =~ /^-.*$/msx) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "Error: unknown option '$_[0]'";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
                usage(q{1});
    } elsif (1) {
        last;    }
# Builtin command 'shift' not implemented
}
if (!((scalar(@ARGV) > 0))) {
        usage(q{1});
}
if ((qx'id -u' != 0)) {
    $main_exit_code = system('log_warning_msg', "$PROGRAM_NAME needs root privileges") >> 8;
exit 1;
}
$main_exit_code = system('log_action_begin_msg', "Starting crypto disk") >> 8;
$main_exit_code = system('bash', 'mount_fs') >> 8;
$rv = q{0};
my $name;
for my $name (@ARGV) {
if (!(!($main_exit_code = system('crypttab_find_entry', '--quiet', "$name") >> 8;))) {
        $main_exit_code = system('device_msg', "$name", "failed, not found in crypttab") >> 8;
        $rv = q{1};
}
    else {
if ("$CRYPTTAB_EXTRA_OPTIONS" ne q{}) {
            my $CRYPTTAB_OPTIONS;
            my @CRYPTTAB_OPTIONS;
            my %CRYPTTAB_OPTIONS;
            $CRYPTTAB_OPTIONS = "$CRYPTTAB_OPTIONS,$CRYPTTAB_EXTRA_OPTIONS";
            my $_CRYPTTAB_OPTIONS;
            my @_CRYPTTAB_OPTIONS;
            my %_CRYPTTAB_OPTIONS;
            $_CRYPTTAB_OPTIONS = "$_CRYPTTAB_OPTIONS,$CRYPTTAB_EXTRA_OPTIONS";
        }
                $main_exit_code = system('bash', 'setup_mapping') >> 8;
        if ($CHILD_ERROR != 0) {
                        $rv = $?;
        }
    }
}
$main_exit_code = system('bash', 'umount_fs') >> 8;
$main_exit_code = system('log_action_end_msg', $rv) >> 8;


exit $main_exit_code;
