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

my $RUNCMD;
my @RUNCMD;
my %RUNCMD;
my $RULESFILE;
my @RULESFILE;
my %RULESFILE;
my $ret;
my @ret;
my %ret;
my $SAVEFILE;
my @SAVEFILE;
my %SAVEFILE;
my $TIMEOUT;
my @TIMEOUT;
my %TIMEOUT;

$__set_e = 1;
# set u not implemented
my $PROGNAME;
my @PROGNAME;
my %PROGNAME;
$PROGNAME = ( ( basename($_[0]) ) =~ s|^.*/||sr );
my $VERSION;
my @VERSION;
my %VERSION;
$VERSION = '1.1';
my $DEF_TIMEOUT;
my @DEF_TIMEOUT;
my %DEF_TIMEOUT;
$DEF_TIMEOUT = '10';
my $MODE;
my @MODE;
my %MODE;
$MODE = q{0};
if ("$PROGNAME" =~ /^.*6.*$/msx) {
        my $SAVE;
    my @SAVE;
    my %SAVE;
    $SAVE = 'ip6tables-save';
        my $RESTORE;
    my @RESTORE;
    my %RESTORE;
    $RESTORE = 'ip6tables-restore';
        my $DEF_RULESFILE;
    my @DEF_RULESFILE;
    my %DEF_RULESFILE;
    $DEF_RULESFILE = "/etc/network/ip6tables.up.rules";
        my $DEF_SAVEFILE;
    my @DEF_SAVEFILE;
    my %DEF_SAVEFILE;
    $DEF_SAVEFILE = "$DEF_RULESFILE";
        my $DEF_RUNCMD;
    my @DEF_RUNCMD;
    my %DEF_RUNCMD;
    $DEF_RUNCMD = "/etc/network/ip6tables.up.run";
} elsif (1) {
        $SAVE = 'iptables-save';
        $RESTORE = 'iptables-restore';
        $DEF_RULESFILE = "/etc/network/iptables.up.rules";
        $DEF_SAVEFILE = "$DEF_RULESFILE";
        $DEF_RUNCMD = "/etc/network/iptables.up.run";
}

sub blurb {
print "\t$PROGNAME $VERSION -- a safer way to update iptables remotely
";
    return;
}

sub copyright {
print "\t$PROGNAME has been published under the terms of the Artistic Licence 2.0.

\tOriginal version - Copyright 2006 Martin F. Krafft <madduck@madduck.net>.
\tVersion 1.1 - Copyright 2010 GW <gw.2010@tnode.com or http://gw.tnode.com/>.
";
    return;
}

sub about {
    blurb();
    print "\n";
    $CHILD_ERROR = 0;
    copyright();
    return;
}

sub usage {
    blurb();
    print "\n";
    $CHILD_ERROR = 0;
print "\tUsage:
\t  $PROGNAME [-hV] [-t timeout] [-w savefile] {[rulesfile]|-c [runcmd]}

\tThe script will try to apply a new rulesfile (as output by iptables-save,
\tread by iptables-restore) or run a command to configure iptables and then
\tprompt the user whether the changes are okay. If the new iptables rules cut
\tthe existing connection, the user will not be able to answer affirmatively.
\tIn this case, the script rolls back to the previous working iptables rules
\tafter the timeout expires.

\tSuccessfully applied rules can also be written to savefile and later used
\tto roll back to this state. This can be used to implement a store last good
\tconfiguration mechanism when experimenting with an iptables setup script:
\t  $PROGNAME -w $DEF_SAVEFILE -c $DEF_RUNCMD

\tWhen called as ip6tables-apply, the script will use ip6tables-save/-restore
\tand IPv6 default values instead. Default value for rulesfile is
\t'$DEF_RULESFILE'.

\tOptions:

\t-t seconds, --timeout seconds
\t  Specify the timeout in seconds (default: $DEF_TIMEOUT).
\t-w savefile, --write savefile
\t  Specify the savefile where successfully applied rules will be written to
\t  (default if empty string is given: $DEF_SAVEFILE).
\t-c runcmd, --command runcmd
\t  Run command runcmd to configure iptables instead of applying a rulesfile
\t  (default: $DEF_RUNCMD).
\t-h, --help
\t  Display this help text.
\t-V, --version
\t  Display version information.

";
    return;
}

sub checkcommands {
    my $cmd;
    for my $cmd (@COMMANDS) {
if (!(!(do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('command', '-v', "$cmd") >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };))) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "Error: needed command not found: $cmd";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
            };
exit 127;
        }
    }
    return;
}

sub revertrules {
    print "Reverting to old iptables rules... ";
open STDIN, '<', "$ENV{TMPFILE}" or croak "Cannot open file: $OS_ERROR\n";
    $CHILD_ERROR = 0;
    print "done.\n";
    return;
}
$TIMEOUT = "$DEF_TIMEOUT";
$SAVEFILE = "";
my $SHORTOPTS;
my @SHORTOPTS;
my %SHORTOPTS;
$SHORTOPTS = "t:w:chV";
my $LONGOPTS;
my @LONGOPTS;
my %LONGOPTS;
$LONGOPTS = "timeout:,write:,command,help,version";
my $OPTS;
my @OPTS;
my %OPTS;
$OPTS = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'getopt', '-s', 'bash', '-o', "$SHORTOPTS", '-l', "$LONGOPTS", '-n', "$PROGNAME", '--', "@ARGV");
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
if ($CHILD_ERROR != 0) {
    }
my $opt;
for my $opt ($OPTS) {
if ("$opt" =~ /^-.*$/msx) {
        delete $ENV{OPT_STATE};
    } elsif (1) {
        if ((defined (defined ($ENV{OPT_STATE} // q{}) && ($ENV{OPT_STATE} // q{}) ne q{} ? ($ENV{OPT_STATE} // q{}) : '') && (defined ($ENV{OPT_STATE} // q{}) && ($ENV{OPT_STATE} // q{}) ne q{} ? ($ENV{OPT_STATE} // q{}) : '') ne q{} ? (defined ($ENV{OPT_STATE} // q{}) && ($ENV{OPT_STATE} // q{}) ne q{} ? ($ENV{OPT_STATE} // q{}) : '') : '') =~ /^SET_TIMEOUT$/msx) {
            do { my $eval_input = "TIMEOUT" . "=" . $opt; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
        } elsif ((defined (defined ($ENV{OPT_STATE} // q{}) && ($ENV{OPT_STATE} // q{}) ne q{} ? ($ENV{OPT_STATE} // q{}) : '') && (defined ($ENV{OPT_STATE} // q{}) && ($ENV{OPT_STATE} // q{}) ne q{} ? ($ENV{OPT_STATE} // q{}) : '') ne q{} ? (defined ($ENV{OPT_STATE} // q{}) && ($ENV{OPT_STATE} // q{}) ne q{} ? ($ENV{OPT_STATE} // q{}) : '') : '') =~ /^SET_SAVEFILE$/msx) {
            do { my $eval_input = "SAVEFILE" . "=" . $opt; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
                        if ("$SAVEFILE" eq q{}) {
                                $SAVEFILE = "$DEF_SAVEFILE";
                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
        }
    }
if ("$opt" =~ /^-t$/msx or "$opt" =~ /^--timeout$/msx) {
                my $OPT_STATE;
        my @OPT_STATE;
        my %OPT_STATE;
        $OPT_STATE = "SET_TIMEOUT";
    } elsif ("$opt" =~ /^-w$/msx or "$opt" =~ /^--write$/msx) {
                $OPT_STATE = "SET_SAVEFILE";
    } elsif ("$opt" =~ /^-c$/msx or "$opt" =~ /^--command$/msx) {
                $MODE = q{1};
    } elsif ("$opt" =~ /^-h$/msx or "$opt" =~ /^--help$/msx) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            usage();
        };
        exit 0;
    } elsif ("$opt" =~ /^-V$/msx or "$opt" =~ /^--version$/msx) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            about();
        };
        exit 0;
    } elsif ("$opt" =~ /^--$/msx) {
        last;    }
# Builtin command 'shift' not implemented
}
if (!(do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
($TIMEOUT >= 0)})) {
    $TIMEOUT = eval { int($TIMEOUT) } // "";
}
else {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "Error: timeout must be a positive number\n";
    };
exit 1;
}
if ((("$SAVEFILE" ne q{} && (-e "$SAVEFILE")) && (!-w "$SAVEFILE"))) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "Error: savefile not writable: $SAVEFILE";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
exit 8;
}
if ("$MODE" =~ /^1$/msx) {
        $RUNCMD = (defined (defined $_[0] && $_[0] ne q{} ? $_[0] : '$DEF_RUNCMD') && (defined $_[0] && $_[0] ne q{} ? $_[0] : '$DEF_RUNCMD') ne q{} ? (defined $_[0] && $_[0] ne q{} ? $_[0] : '$DEF_RUNCMD') : '$DEF_RUNCMD');
    if ((!-x "$RUNCMD")) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "Error: runcmd not executable: $RUNCMD";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
exit 6;
    }
        my $COMMANDS;
    my @COMMANDS = ('mktemp', $SAVE, $RESTORE, $RUNCMD);
    my %COMMANDS;
        checkcommands();
} elsif (1) {
        $RULESFILE = (defined (defined $_[0] && $_[0] ne q{} ? $_[0] : '$DEF_RULESFILE') && (defined $_[0] && $_[0] ne q{} ? $_[0] : '$DEF_RULESFILE') ne q{} ? (defined $_[0] && $_[0] ne q{} ? $_[0] : '$DEF_RULESFILE') : '$DEF_RULESFILE');
    if ((!-r "$RULESFILE")) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "Error: rulesfile not readable: $RULESFILE";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
exit 2;
    }
        @COMMANDS = ('mktemp', $SAVE, $RESTORE);
        checkcommands();
}
my $TMPFILE;
my @TMPFILE;
my %TMPFILE;
$TMPFILE = do {
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'mktemp', "/tmp/$PROGNAME-XXXXXXXX");
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    $result_1
};
END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx'rm -f $TMPFILE 2>&1'; print $end_out if $end_out ne q{}; }
if (!(!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', "$TMPFILE"
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    $CHILD_ERROR = 0;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};))) {
if (!(!(do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $grep_result_2;
my @grep_lines_2 = ();
my @grep_filenames_2 = ();
if (-e "/proc/modules") {
    open my $fh, '<', "/proc/modules" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_2, $line;
        push @grep_filenames_2, "/proc/modules";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /proc/modules: No such file or directory\n"; }
my @grep_filtered_2 = grep { /ipt/msx } @grep_lines_2;
$grep_result_2 = join "\n", @grep_filtered_2;
        if (!($grep_result_2 =~ m{\n\z}msx || $grep_result_2 eq q{})) {
            $grep_result_2 .= "\n";
        }
$CHILD_ERROR = scalar @grep_filtered_2 > 0 ? 0 : 1;
$grep_result_2 = q{};
    };))) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "Error: iptables support lacking from the kernel\n";
        };
exit 3;
}
    else {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "Error: unknown error saving old iptables rules: $TMPFILE";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
exit 4;
    }
}
if ((-x '/etc/init.d/fail2ban')) {
        $main_exit_code = system('/etc/init.d/fail2ban', 'stop') >> 8;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
if ("$MODE" =~ /^1$/msx) {
        print "Running command '$RUNCMD'... ";
        if (my $pid = fork()) {
        # Parent process continues
    } elsif (defined $pid) {
        # Child process executes the background command
        $CHILD_ERROR = 0;
        exit(0);
    } else {
        die "Cannot fork: $ERRNO\n";
    }
        my $CMD_PID;
    my @CMD_PID;
    my %CMD_PID;
    $CMD_PID = $!;
        if (my $pid = fork()) {
        # Parent process continues
    } elsif (defined $pid) {
        # Child process executes the background command
        exec 'bash', '-c', q{(sleep "$TIMEOUT"; kill "$CMD_PID" 2> /dev/null; : 'Complex command not supported in bash string generation')};
        croak "exec failed: $OS_ERROR\n";
    } else {
        die "Cannot fork: $ERRNO\n";
    }
    if (!(!(1 while wait() > -1;
$CHILD_ERROR = $? == -1 ? 0 : $? >> 8;))) {
        print "failed.\n";
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "Error: unknown error running command: $RUNCMD";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
        revertrules();
exit 7;
}
    else {
        print "done.\n";
    }
} elsif (1) {
        print "Applying new iptables rules from '$RULESFILE'... ";
    if (!(!(open STDIN, '<', "$RULESFILE" or croak "Cannot open file: $OS_ERROR\n";
    $CHILD_ERROR = 0;))) {
        print "failed.\n";
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "Error: unknown error applying new iptables rules: $RULESFILE";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
        revertrules();
exit 5;
}
    else {
        print "done.\n";
    }
}
print "Can you establish NEW connections to the machine? (y/N) ";
do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
$1 = <>;
chomp $1;
$CHILD_ERROR = defined($1) ? 0 : 1;
};
if ($CHILD_ERROR != 0) {
        $main_exit_code = system('bash', ':') >> 8;
}
if ((defined (defined ${ret} && ${ret} ne q{} ? ${ret} : '') && (defined ${ret} && ${ret} ne q{} ? ${ret} : '') ne q{} ? (defined ${ret} && ${ret} ne q{} ? ${ret} : '') : '') =~ /^y.*$/msx or (defined (defined ${ret} && ${ret} ne q{} ? ${ret} : '') && (defined ${ret} && ${ret} ne q{} ? ${ret} : '') ne q{} ? (defined ${ret} && ${ret} ne q{} ? ${ret} : '') : '') =~ /^Y.*$/msx) {
        print "\n";
    $CHILD_ERROR = 0;
    if ("$SAVEFILE" ne q{}) {
        do {
    my $__echo_line = "Writing successfully applied rules to '$SAVEFILE'...";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
if (!(!(do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$SAVEFILE"
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };))) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "Error: unknown error writing successfully applied rules: $SAVEFILE";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
            };
exit 9;
        }
    }
        print "... then my job is done. See you next time.\n";
} elsif (1) {
        print "\n";
    $CHILD_ERROR = 0;
    if ("${ret:-}" eq q{}) {
        print "Timeout! Something happened (or did not). Better play it safe...\n";
}
    else {
        print "No affirmative response! Better play it safe...\n";
    }
        revertrules();
    exit 255;
}
if ((-x '/etc/init.d/fail2ban')) {
        $main_exit_code = system('/etc/init.d/fail2ban', 'start') >> 8;
    $CHILD_ERROR = 0;
} else {
    $CHILD_ERROR = 1;
}
exit 0;

exit $main_exit_code;
