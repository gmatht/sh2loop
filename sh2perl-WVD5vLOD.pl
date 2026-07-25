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

my $READ_ENV;
my @READ_ENV;
my %READ_ENV;
my $PIDFILE;
my @PIDFILE;
my %PIDFILE;
my $RETVAL;
my @RETVAL;
my %RETVAL;

my $PATH;
my @PATH;
my %PATH;
$PATH = '/bin:/usr/bin:/sbin:/usr/sbin';
my $DESC;
my @DESC;
my %DESC;
$DESC = "cron daemon";
my $NAME;
my @NAME;
my %NAME;
$NAME = 'cron';
my $DAEMON;
my @DAEMON;
my %DAEMON;
$DAEMON = '/usr/sbin/cron';
$PIDFILE = '/var/run/crond.pid';
my $SCRIPTNAME;
my @SCRIPTNAME;
my %SCRIPTNAME;
$SCRIPTNAME = '/etc/init.d/';
$main_exit_code = system('test', '-f', $DAEMON) >> 8;
if ($CHILD_ERROR != 0) {
    exit 0;
}
$main_exit_code = system('.', '/lib/lsb/init-functions') >> 8;
if ((-r '/etc/default/cron')) {
        $main_exit_code = system('.', '/etc/default/cron') >> 8;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}

sub parse_environment {
    my $ENV_FILE;
    for my $ENV_FILE ('/etc/environment', '/etc/default/locale') {
        if (!((-r "$ENV_FILE"))) {
            next;        }
        if (!(((-s "$ENV_FILE") > 0))) {
            next;        }
        my $var;
        for my $var ('LANG', 'LANGUAGE', 'LC_ALL', 'LC_CTYPE') {
            my $value;
            my @value;
            my %value;
            $value = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_0 = q{};
                my $output_printed_0;
                my $pipeline_success_0 = 1;

                my ($in_1, $out_1);
                my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'egrep', );
                close $in_1 or croak 'Close failed: $OS_ERROR';
                $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
                close $out_1 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_1, 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
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

                my @lines_2 = split /\n/msx, $output_0;
                my @result_2;
                foreach my $line (@lines_2) {
                chomp $line;
                my @fields = split /=/msx, $line;
                if (@fields > 1) {
                    push @result_2, $fields[1];
                }
                }
                $output_0 = join "\n", @result_2;
                if ($output_0 ne q{} && !($output_0  =~ m{\n\z}msx)) { $output_0 .= "\n"; }

                if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
                $output_0 =~ s/\n+\z//msx;
                $output_0;
}; $_pipeline_result; };
            if ("$value" ne q{}) {
                do { my $eval_input = "export" . $var . "=" . $value; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
if (("$value" ne q{} && "$ENV_FILE" eq /etc/environment)) {
                $main_exit_code = system('log_warning_msg', "/etc/environment has been deprecated for locale information; use /etc/default/locale for $var=$value instead") >> 8;
            }
        }
    }
if (("$TZ" eq q{} && (-e '/etc/localtime'))) {
        my $TZ;
        my @TZ;
        my %TZ;
        $TZ = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_3 = q{};
            my $output_printed_3;
            my $pipeline_success_3 = 1;

            my ($in_4, $out_4);
            my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'readlink', '/etc/localtime');
            close $in_4 or croak 'Close failed: $OS_ERROR';
            $output_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
            close $out_4 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_4, 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_3 = 0; }
            my @sed_lines_3 = split /\n/msx, $output_3;
            my @sed_result_3;
            foreach my $line (@sed_lines_3) {
            chomp $line;
            push @sed_result_3, $line;
            }
            $output_3 = join "\n", @sed_result_3;

            if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
            $output_3 =~ s/\n+\z//msx;
            $output_3;
}; $_pipeline_result; };
    }
    return;
}
if ("$READ_ENV" eq "yes") {
    parse_environment();
}
if ("$_[0]" =~ /^start$/msx) {
        $main_exit_code = system('log_daemon_msg', "Starting periodic command scheduler", "cron") >> 8;
        $main_exit_code = system('start_daemon', '-p', $PIDFILE, $DAEMON, '-P', $EXTRA_OPTS) >> 8;
        $main_exit_code = system('log_end_msg', $?) >> 8;
} elsif ("$_[0]" =~ /^stop$/msx) {
        $main_exit_code = system('log_daemon_msg', "Stopping periodic command scheduler", "cron") >> 8;
        $main_exit_code = system('killproc', '-p', $PIDFILE, $DAEMON) >> 8;
        $RETVAL = $?;
        if (do {
if (($RETVAL == 0)) {
    (-e "$PIDFILE")    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
        $CHILD_ERROR == 0
    }) {
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
    }
        $main_exit_code = system('log_end_msg', $RETVAL) >> 8;
} elsif ("$_[0]" =~ /^restart$/msx) {
        $main_exit_code = system('log_daemon_msg', "Restarting periodic command scheduler", "cron") >> 8;
        $CHILD_ERROR = 0;
        $CHILD_ERROR = 0;
} elsif ("$_[0]" =~ /^reload$/msx or "$_[0]" =~ /^force-reload$/msx) {
        $main_exit_code = system('log_daemon_msg', "Reloading configuration files for periodic command scheduler", "cron") >> 8;
        $main_exit_code = system('log_end_msg', q{0}) >> 8;
} elsif ("$_[0]" =~ /^status$/msx) {
            if (do {
$main_exit_code = system('status_of_proc', '-p', $PIDFILE, $DAEMON, $NAME) >> 8;
        $CHILD_ERROR == 0
    }) {
        exit 0;
    }
    if ($CHILD_ERROR != 0) {
            }
} elsif (1) {
        $main_exit_code = system('log_action_msg', "Usage: /etc/init.d/cron {start|stop|status|restart|reload|force-reload}") >> 8;
    exit 2;
}
exit 0;

exit $main_exit_code;
