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

my $DAEMON;
my @DAEMON;
my %DAEMON;
my $status;
my @status;
my %status;

my $PATH;
my @PATH;
my %PATH;
$PATH = '/usr/sbin:/usr/bin:/sbin:/bin';
my $DESC;
my @DESC;
my %DESC;
$DESC = "vnStat daemon";
my $NAME;
my @NAME;
my %NAME;
$NAME = 'vnstatd';
my $PIDFILE;
my @PIDFILE;
my %PIDFILE;
$PIDFILE = '/run/vnstat/vnstat.pid';
$DAEMON = '/usr/sbin/';
my $DAEMON_ARGS;
my @DAEMON_ARGS;
my %DAEMON_ARGS;
$DAEMON_ARGS = "-d --pidfile $PIDFILE";
my $SCRIPTNAME;
my @SCRIPTNAME;
my %SCRIPTNAME;
$SCRIPTNAME = '/etc/init.d/vnstat';
my $USER;
my @USER;
my %USER;
$USER = 'vnstat';
$main_exit_code = system('.', '/lib/lsb/init-functions') >> 8;
if (!((-x "$DAEMON"))) {
    exit 0;
}
if ("$_[0]" =~ /^start$/msx) {
        $main_exit_code = system('log_daemon_msg', "Starting $DESC", "$NAME") >> 8;
    if ((!-d /run/vnstat)) {
        use File::Path qw(make_path);
        my $err;
        if ( mkdir '/run/vnstat' ) {
            }
        else {
            croak "mkdir: cannot create directory " . '/run/vnstat' . ": File exists\n";
        }
    }
    do {
    my ($owner, $group) = split /:/, $USER, 2;
    my $uid = getpwnam($owner);
    my $gid = defined($group) ? getgrnam($group) : -1;
    chown $uid, $gid, (q{:}, $USER, '/run/vnstat') or warn "chown failed: $OS_ERROR\n";
    $CHILD_ERROR = 0;
};
        $main_exit_code = system('start-stop-daemon', '--start', '--quiet', '--oknodo', '--chuid', $USER, '--exec', $DAEMON, '--', $DAEMON_ARGS) >> 8;
        $main_exit_code = system('log_end_msg', $?) >> 8;
} elsif ("$_[0]" =~ /^stop$/msx) {
        $main_exit_code = system('log_daemon_msg', "Stopping $DESC", "$NAME") >> 8;
        $main_exit_code = system('start-stop-daemon', '--stop', '--quiet', '--oknodo', '--retry=TERM/15/KILL/5', '--pidfile', $PIDFILE, '--name', $NAME) >> 8;
        $status = $?;
    if ( -e "$PIDFILE" ) {
        if ( -d "$PIDFILE" ) {
            carp "rm: carping: ", $PIDFILE,
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$PIDFILE" ) {
                            }
            else {
                carp "rm: carping: could not remove ", $PIDFILE,
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
        $main_exit_code = system('log_end_msg', $?) >> 8;
} elsif ("$_[0]" =~ /^status$/msx) {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('pidofproc', '-p', $PIDFILE, $DAEMON) >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
        $status = $?;
    if (($status == 0)) {
        $main_exit_code = system('log_success_msg', "$DESC is running") >> 8;
}
    else {
        $main_exit_code = system('log_failure_msg', "$DESC is not running") >> 8;
    }
    } elsif ("$_[0]" =~ /^reload$/msx or "$_[0]" =~ /^force-reload$/msx) {
        $main_exit_code = system('log_daemon_msg', "Reloading $DESC configuration...") >> 8;
        $main_exit_code = system('start-stop-daemon', '--stop', '--signal', q{1}, '--quiet', '--pidfile', $PIDFILE, '--name', $NAME) >> 8;
        $main_exit_code = system('log_end_msg', $?) >> 8;
} elsif ("$_[0]" =~ /^restart$/msx) {
        $CHILD_ERROR = 0;
    require Time::HiRes; Time::HiRes::sleep(q{1});
        $CHILD_ERROR = 0;
} elsif (1) {
        do {
    my $__echo_line = "Usage: $SCRIPTNAME {start|stop|restart|reload|force-reload|status}";
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
