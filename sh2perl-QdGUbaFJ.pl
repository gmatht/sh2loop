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

my $MAGIC_755 = 755;

$main_exit_code = system('test', '-f', '/sbin/rpcbind') >> 8;
if ($CHILD_ERROR != 0) {
    exit 0;
}
$main_exit_code = system('.', '/lib/lsb/init-functions') >> 8;
my $OPTIONS;
my @OPTIONS;
my %OPTIONS;
$OPTIONS = "-w";
my $STATEDIR;
my @STATEDIR;
my %STATEDIR;
$STATEDIR = '/run/rpcbind';
my $PIDFILE;
my @PIDFILE;
my %PIDFILE;
$PIDFILE = '/run/rpcbind.pid';
if ((-f '/etc/default/rpcbind')) {
    $main_exit_code = system('.', '/etc/default/rpcbind') >> 8;
}
else {
    if ((-f '/etc/rpcbind.conf')) {
        $main_exit_code = system('.', '/etc/rpcbind.conf') >> 8;
    }
}

sub start {
if ((!-d $STATEDIR)) {
        use File::Path qw(make_path);
        my $err;
        if ( mkdir $STATEDIR ) {
            }
        else {
            croak "mkdir: cannot create directory " . $STATEDIR . ": File exists\n";
        }
do {
    my ($owner, $group) = split /:/, '_rpc:root', 2;
    my $uid = getpwnam($owner);
    my $gid = defined($group) ? getgrnam($group) : -1;
    chown $uid, $gid, ($STATEDIR) or warn "chown failed: $OS_ERROR\n";
    $CHILD_ERROR = 0;
};
chmod(oct('0755'), ($STATEDIR)) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    }
if ((`ls -dl "$STATEDIR" | grep -cE '^drwxr-xr-x [0-9]+ _rpc root '` < 1)) {
        $main_exit_code = system('log_begin_msg', "$STATEDIR not owned by root") >> 8;
        $main_exit_code = system('log_end_msg', q{1}) >> 8;
exit 1;
    }
    if ((-x '/sbin/restorecon')) {
                $main_exit_code = system('/sbin/restorecon', $STATEDIR) >> 8;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    my $pid;
    my @pid;
    my %pid;
    $pid = do {
    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'pidofproc', '/sbin/rpcbind');
    close $in_3 or croak 'Close failed: $OS_ERROR';
    my $result_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;
    $result_3
};
if ("$pid" ne q{}) {
        $main_exit_code = system('log_action_msg', "Already running: rpcbind") >> 8;
exit 0;
    }
    $main_exit_code = system('log_daemon_msg', "Starting RPC port mapper daemon", "rpcbind") >> 8;
    $main_exit_code = system('start-stop-daemon', '--start', '--quiet', '--oknodo', '--exec', '/sbin/rpcbind', '--', "@ARGV") >> 8;
    $pid = do {
    my ($in_4, $out_4);
    my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'pidofproc', '/sbin/rpcbind');
    close $in_4 or croak 'Close failed: $OS_ERROR';
    my $result_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
    close $out_4 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_4, 0;
    $result_4
};
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$PIDFILE"
      or die "Cannot open file: $OS_ERROR\n";
        print $pid;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
symlink q{f}, '/run/sendsigs.omit.d/rpcbind' or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
    $main_exit_code = system('log_end_msg', $?) >> 8;
    return;
}

sub stop {
    $main_exit_code = system('log_daemon_msg', "Stopping RPC port mapper daemon", "rpcbind") >> 8;
    $main_exit_code = system('start-stop-daemon', '--stop', '--quiet', '--retry=TERM/30/KILL/5', '--oknodo', '--exec', '/sbin/rpcbind') >> 8;
if ( -e "$PIDFILE" ) {
        if ( -d "$PIDFILE" ) {
            carp "rm: carping: ", "$PIDFILE",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$PIDFILE" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$PIDFILE",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    $main_exit_code = system('log_end_msg', $?) >> 8;
    return;
}
if ("$_[0]" =~ /^start$/msx) {
    if (!(    $main_exit_code = system('bash', 'init_is_upstart') >> 8)) {
exit 1;
    }
        start($OPTIONS);
} elsif ("$_[0]" =~ /^stop$/msx) {
    if (!(    $main_exit_code = system('bash', 'init_is_upstart') >> 8)) {
exit 0;
    }
        stop();
} elsif ("$_[0]" =~ /^restart$/msx or "$_[0]" =~ /^force-reload$/msx) {
    if (!(    $main_exit_code = system('bash', 'init_is_upstart') >> 8)) {
exit 1;
    }
        stop();
        start($OPTIONS);
} elsif ("$_[0]" =~ /^status$/msx) {
            if (do {
$main_exit_code = system('status_of_proc', '/sbin/rpcbind', 'rpcbind') >> 8;
        $CHILD_ERROR == 0
    }) {
        exit 0;
    }
    if ($CHILD_ERROR != 0) {
            }
} elsif (1) {
        $main_exit_code = system('log_success_msg', "Usage: /etc/init.d/rpcbind {start|stop|force-reload|restart|status}") >> 8;
    exit 1;
}
exit 0;

exit $main_exit_code;
