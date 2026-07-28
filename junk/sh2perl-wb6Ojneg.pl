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

$main_exit_code = system('.', '/lib/lsb/init-functions') >> 8;
$main_exit_code = system('test', '-x', '/usr/sbin/lircd') >> 8;
if ($CHILD_ERROR != 0) {
    exit 0;
}
if (((!-f /etc/lirc/lircd.conf) || (qx'grep -v -e ^[\ \t]*\# -e ^$ /etc/lirc/lircd.conf | wc -l' == 0))) {
exit 0;
}
if ("$_[0]" =~ /^start$/msx) {
        if (!((-d "/run/lirc"))) {
                use File::Path qw(make_path);
        my $err;
        if ( !-d "/run/lirc" ) {
            make_path( "/run/lirc", { error => \$err } );
            if ( @{$err} ) {
                croak "mkdir: cannot create directory " . "/run/lirc" . ": $err->[0]\n";
            }
        }
    }
        $main_exit_code = system('log_daemon_msg', "Starting remote control daemon", "LIRCD") >> 8;
    open STDIN, '<', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
    $main_exit_code = system('start-stop-daemon', '--start', '--quiet', '--oknodo', '--exec', '/usr/sbin/lircd', '--') >> 8;
        $main_exit_code = system('log_end_msg', $?) >> 8;
    unlink '/dev/lircd';
link q{s}, '/dev/lircd' or warn "link failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
} elsif ("$_[0]" =~ /^stop$/msx) {
        $main_exit_code = system('log_daemon_msg', "Stopping remote control daemon", "LIRCD") >> 8;
        $main_exit_code = system('start-stop-daemon', '--stop', '--quiet', '--exec', '/usr/sbin/lircd') >> 8;
        $main_exit_code = system('log_end_msg', $?) >> 8;
} elsif ("$_[0]" =~ /^reload$/msx or "$_[0]" =~ /^force-reload$/msx) {
        $main_exit_code = system('log_daemon_msg', "Reload configuration for remote control daemon", "LIRCD") >> 8;
        $main_exit_code = system('start-stop-daemon', '--stop', '--quiet', '--signal', q{1}, '--exec', '/usr/sbin/lircd') >> 8;
        $main_exit_code = system('log_end_msg', $?) >> 8;
} elsif ("$_[0]" =~ /^restart$/msx) {
        $CHILD_ERROR = 0;
        $CHILD_ERROR = 0;
} elsif ("$_[0]" =~ /^status$/msx) {
            $main_exit_code = system('status_of_proc', '/usr/sbin/lircd', 'lircd') >> 8;
    if ($CHILD_ERROR != 0) {
            }
} elsif (1) {
        print "Usage: /etc/init.d/lircd {start|stop|reload|restart|force-reload|status}\n";
    exit 1;
}
exit 0;

exit $main_exit_code;
