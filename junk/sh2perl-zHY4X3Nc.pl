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
my $SMARTCTL;
my @SMARTCTL;
my %SMARTCTL;
my $enable_smart;
my @enable_smart;
my %enable_smart;

my $MAGIC_30 = 30;

$SMARTCTL = '/usr/sbin/smartctl';
$DAEMON = '/usr/sbin/smartd';
my $PIDFILE;
my @PIDFILE;
my %PIDFILE;
$PIDFILE = '/var/run/smartd.pid';
if (!((-x $SMARTCTL))) {
    exit 0;
}
if (!((-x $DAEMON))) {
    exit 0;
}
$main_exit_code = system('.', '/lib/lsb/init-functions') >> 8;
my $RET;
my @RET;
my %RET;
$RET = q{0};
if ((-r '/etc/default/rcS')) {
        $main_exit_code = system('.', '/etc/default/rcS') >> 8;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
if ((-r '/etc/default/smartmontools')) {
        $main_exit_code = system('.', '/etc/default/smartmontools') >> 8;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
my $smartd_opts;
my @smartd_opts;
my %smartd_opts;
$smartd_opts = "--pidfile $PIDFILE $smartd_opts";

sub enable_smart {
    $main_exit_code = system('log_action_begin_msg', "Enabling S.M.A.R.T.") >> 8;
    my $device;
    for my $device ($enable_smart) {
        $main_exit_code = system('log_action_cont_msg', "$device") >> 8;
if (!(!($CHILD_ERROR = 0;))) {
            $main_exit_code = system('log_action_cont_msg', "(failed)") >> 8;
            $RET = q{2};
        }
    }
    $main_exit_code = system('log_action_end_msg', q{0}) >> 8;
    return;
}

sub running_pid {
    my $pid;
    my @pid;
    my %pid;
    $pid = $1;
    my $name;
    my @name;
    my %name;
    $name = $2;
    if ("$pid" eq q{}) {
        return q{1};        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    if ((!-d /proc/$pid)) {
        return q{1};        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    my $cmd;
    my @cmd;
    my %cmd;
    $cmd = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
        $output_0 = (do { my $cat_chunk = q{}; if ( open my $fh, '<', '/proc/' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/proc/' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', $pid ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $pid . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', '/cmdline' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/cmdline' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });
        if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
        my $set1_1 = "\000";
        my $set2_1 = "\n";
        my $input_1 = $output_0;
        # Expand character ranges for tr command
        my $expanded_set1_1 = $set1_1;
        my $expanded_set2_1 = $set2_1;
        # Handle a-z range in set1
        if ($expanded_set1_1 =~ /a-z/msx) {
            $expanded_set1_1 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set1
        if ($expanded_set1_1 =~ /A-Z/msx) {
            $expanded_set1_1 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set1
        if ($expanded_set1_1 =~ /\[:upper:\]/msx) {
            $expanded_set1_1 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set1
        if ($expanded_set1_1 =~ /\[:lower:\]/msx) {
            $expanded_set1_1 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle a-z range in set2
        if ($expanded_set2_1 =~ /a-z/msx) {
            $expanded_set2_1 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set2
        if ($expanded_set2_1 =~ /A-Z/msx) {
            $expanded_set2_1 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set2
        if ($expanded_set2_1 =~ /\[:upper:\]/msx) {
            $expanded_set2_1 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set2
        if ($expanded_set2_1 =~ /\[:lower:\]/msx) {
            $expanded_set2_1 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        my $tr_result_0_1 = q{};
        for my $char ( split //msx, $input_1 ) {
            my $pos_1 = index $expanded_set1_1, $char;
            if ( $pos_1 >= 0 && $pos_1 < length $expanded_set2_1 ) {
                $tr_result_0_1 .= substr $expanded_set2_1, $pos_1, 1;
            } else {
                $tr_result_0_1 .= $char;
            }
        }
                if (!($tr_result_0_1 =~ m{\n\z}msx || $tr_result_0_1 eq q{})) {
                    $tr_result_0_1 .= "\n";
                }
                $output_0 = $tr_result_0_1;
        my $num_lines       = 1;
        my $head_line_count = 0;
        my $result          = q{};
        my $input           = $output_0;
        my $pos             = 0;

        while ( $pos < length $input && $head_line_count < $num_lines ) {
            my $line_end = index $input, "\n", $pos;
            if ( $line_end == -1 ) {
                $line_end = length $input;
            }
            my $head_line = substr $input, $pos, $line_end - $pos;
            $result .= $head_line . "\n";
            $pos = $line_end + 1;
            ++$head_line_count;
        }
        $output_0 = $result;

        my @lines_2 = split /\n/msx, $output_0;
        my @result_2;
        foreach my $line (@lines_2) {
        chomp $line;
        my @fields = split /:/msx, $line;
        if (@fields > 0) {
            push @result_2, $fields[0];
        }
        }
        $output_0 = join "\n", @result_2;
        if ($output_0 ne q{} && !($output_0  =~ m{\n\z}msx)) { $output_0 .= "\n"; }

        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        $output_0 =~ s/\n+\z//msx;
        $output_0;
}; $_pipeline_result; };
    if ("$cmd" ne "$name") {
        return q{1};        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
return q{0};
    return;
}

sub running {
    if ((!-f "$PIDFILE")) {
        return q{1};        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    my $pid;
    my @pid;
    my %pid;
    $pid = do { my $cat_chunk = q{}; if ( open my $fh, '<', $PIDFILE ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $PIDFILE . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
        running_pid($pid, $DAEMON);
    if ($CHILD_ERROR != 0) {
        return q{1};    }
return q{0};
    return;
}
if ("$_[0]" =~ /^start$/msx) {
        if ("$enable_smart" ne q{}) {
                enable_smart();
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
        $main_exit_code = system('log_daemon_msg', "Starting S.M.A.R.T. daemon", "smartd") >> 8;
    if (!(    running())) {
        $main_exit_code = system('log_progress_msg', "already running") >> 8;
        $main_exit_code = system('log_end_msg', q{0}) >> 8;
exit 0;
    }
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
    if (!(    $main_exit_code = system('start-stop-daemon', '--start', '--quiet', '--pidfile', $PIDFILE, '--exec', $DAEMON, '--', $smartd_opts) >> 8)) {
        $main_exit_code = system('log_end_msg', q{0}) >> 8;
}
    else {
        $main_exit_code = system('log_end_msg', q{1}) >> 8;
        $RET = q{1};
    }
} elsif ("$_[0]" =~ /^stop$/msx) {
        $main_exit_code = system('log_daemon_msg', "Stopping S.M.A.R.T. daemon", "smartd") >> 8;
        $main_exit_code = system('start-stop-daemon', '--stop', '--quiet', '--oknodo', '--pidfile', $PIDFILE) >> 8;
        $main_exit_code = system('log_end_msg', q{0}) >> 8;
} elsif ("$_[0]" =~ /^reload$/msx or "$_[0]" =~ /^force-reload$/msx) {
        $main_exit_code = system('log_daemon_msg', "Reloading S.M.A.R.T. daemon", "smartd") >> 8;
    if (!(    $main_exit_code = system('start-stop-daemon', '--stop', '--quiet', '--signal', q{1}, '--pidfile', $PIDFILE) >> 8)) {
        $main_exit_code = system('log_end_msg', q{0}) >> 8;
}
    else {
        $main_exit_code = system('log_end_msg', q{1}) >> 8;
        $RET = q{1};
    }
} elsif ("$_[0]" =~ /^restart$/msx) {
        $main_exit_code = system('log_daemon_msg', "Restarting S.M.A.R.T. daemon", "smartd") >> 8;
        $main_exit_code = system('start-stop-daemon', '--stop', '--quiet', '--oknodo', '--retry', '30', '--pidfile', $PIDFILE) >> 8;
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
    if (!(    $main_exit_code = system('start-stop-daemon', '--start', '--quiet', '--pidfile', $PIDFILE, '--exec', $DAEMON, '--', $smartd_opts) >> 8)) {
        $main_exit_code = system('log_end_msg', q{0}) >> 8;
}
    else {
        $main_exit_code = system('log_end_msg', q{1}) >> 8;
        $RET = q{1};
    }
} elsif ("$_[0]" =~ /^status$/msx) {
            if (do {
$main_exit_code = system('status_of_proc', $DAEMON, 'smartd') >> 8;
        $CHILD_ERROR == 0
    }) {
        exit 0;
    }
    if ($CHILD_ERROR != 0) {
            }
} elsif (1) {
        print "Usage: /etc/init.d/smartmontools {start|stop|restart|reload|force-reload|status}\n";
    exit 1;
}


exit $main_exit_code;
