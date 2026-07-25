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

my $INIT_D_SCRIPT_SOURCED;
my @INIT_D_SCRIPT_SOURCED;
my %INIT_D_SCRIPT_SOURCED;

if (true ne "$INIT_D_SCRIPT_SOURCED") {

    $INIT_D_SCRIPT_SOURCED = 'true';
    $main_exit_code = system('.', '/lib/init/init-d-script') >> 8;
}
my $DESC;
my @DESC;
my %DESC;
$DESC = "Setting kernel variables";
my $DAEMON;
my @DAEMON;
my %DAEMON;
$DAEMON = '/sbin/sysctl';
my $PIDFILE;
my @PIDFILE;
my %PIDFILE;
$PIDFILE = 'none';
my $QUIET_SYSCTL;
my @QUIET_SYSCTL;
my %QUIET_SYSCTL;
$QUIET_SYSCTL = "-q";

sub do_start_cmd {
    my $STATUS;
    my @STATUS;
    my %STATUS;
    $STATUS = q{0};
        $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) {
                $STATUS = $?;
    }
return $STATUS;
    return;
}

sub do_reload {
    $main_exit_code = system('call', 'do_start_cmd') >> 8;
    return;
}

sub do_stop {
return q{0};
    return;
}

sub do_status {
return q{0};
    return;
}

exit $main_exit_code;
