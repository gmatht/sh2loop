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

my $NAME;
my @NAME;
my %NAME;
$NAME = 'nmbd';
my $DAEMON;
my @DAEMON;
my %DAEMON;
$DAEMON = '/usr/sbin/';
my $PIDFILE;
my @PIDFILE;
my %PIDFILE;
$PIDFILE = '/run/samba/';
$CHILD_ERROR = 0;
my $DESC;
my @DESC;
my %DESC;
$DESC = "NetBIOS name server";
my $SCRIPT;
my @SCRIPT;
my %SCRIPT;
$SCRIPT = 'nmbd';
delete $ENV{TMPDIR};
$main_exit_code = system('test', '-x', $DAEMON) >> 8;
if ($CHILD_ERROR != 0) {
    exit 0;
}
$main_exit_code = system('/usr/share/samba/is-configured', $NAME) >> 8;
if ($CHILD_ERROR != 0) {
    exit 0;
}
if ((-f '/etc/default/samba')) {
        $main_exit_code = system('.', '/etc/default/samba') >> 8;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
$main_exit_code = system('.', '/lib/lsb/init-functions') >> 8;
if ("$_[0]" =~ /^start$/msx) {
        $main_exit_code = system('log_daemon_msg', "Starting $DESC", $NAME) >> 8;
        $main_exit_code = system('start-stop-daemon', '--start', '--quiet', '--oknodo', '--exec', $DAEMON, '--pidfile', $PIDFILE, '--', '-D', $NMBDOPTIONS) >> 8;
        $main_exit_code = system('log_end_msg', $?) >> 8;
} elsif ("$_[0]" =~ /^stop$/msx) {
        $main_exit_code = system('log_daemon_msg', "Stopping $DESC", $NAME) >> 8;
        $main_exit_code = system('start-stop-daemon', '--stop', '--quiet', '--oknodo', '--exec', $DAEMON, '--pidfile', $PIDFILE) >> 8;
        $main_exit_code = system('log_end_msg', $?) >> 8;
} elsif ("$_[0]" =~ /^restart$/msx or "$_[0]" =~ /^force-reload$/msx) {
        if (do {
if (do {
$CHILD_ERROR = 0;
    $CHILD_ERROR == 0
}) {
    require Time::HiRes; Time::HiRes::sleep(q{1});
}
        $CHILD_ERROR == 0
    }) {
                $CHILD_ERROR = 0;
    }
} elsif ("$_[0]" =~ /^status$/msx) {
        $main_exit_code = system('status_of_proc', '-p', $PIDFILE, $DAEMON, $NAME) >> 8;
} elsif (1) {
        do {
    my $__echo_line = "Usage: /etc/init.d/$SCRIPT {start|stop|restart|force-reload|status}";
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

exit $main_exit_code;
