#!/usr/bin/env perl
use strict;
use warnings;
use Carp;
use English qw(-no_match_vars $ERRNO $EVAL_ERROR $INPUT_RECORD_SEPARATOR $OS_ERROR $PROGRAM_NAME);
use locale;
use IPC::Open3;
use File::Path qw(make_path remove_tree);

my $main_exit_code = 0;
my $ls_success     = 0;
my $__set_e        = 0;
my $output         = q{};
our $CHILD_ERROR;

my $SYSSESSIONDIR;
my @SYSSESSIONDIR;
my %SYSSESSIONDIR;
my $ERRFILE;
my @ERRFILE;
my %ERRFILE;
my $SESSIONFILES;
my @SESSIONFILES;
my %SESSIONFILES;

my $MAGIC_600    = 600;
my $MAGIC_500000 = 500_000;

$__set_e = 1;
my $PROGNAME;
my @PROGNAME;
my %PROGNAME;
$PROGNAME = 'Xsession';

sub message {
    my $MESSAGE;
    my @MESSAGE;
    my %MESSAGE;
    $MESSAGE = "$PROGNAME: @ARGV";
    # Original bash: echo "$MESSAGE" | fold -s -w ${COLUMNS:-80} >&2
{
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;
        $output_0 .= $MESSAGE . "\n";
if ( !($output_0 =~ m{\n\z}msx) ) { $output_0 .= "\n"; }
$CHILD_ERROR = 0;

                my $cmd_2 = 'fold';
        my ($in_1, $out_1);
        my $pid_1 = open3($in_1, $out_1, '>&STDERR', $cmd_2, '-s', '-w');
        print {$in_1} $output_0;
        close $in_1 or croak 'Close failed: $OS_ERROR';
        $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
        close $out_1 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_1, 0;
        if ($output_0 ne q{} && !defined $output_printed_0) {
            print $output_0;
            if (!($output_0 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        }
if (("$DISPLAY" ne q{} && !(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('command', '-v', 'xmessage') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    }))) {
        # Original bash: echo "$MESSAGE" | fold -s -w ${COLUMNS:-80} | xmessage -center -file -
{
            my $output_3 = q{};
            my $output_printed_3;
            my $pipeline_success_3 = 1;
            $output_3 .= $MESSAGE . "\n";
if ( !($output_3 =~ m{\n\z}msx) ) { $output_3 .= "\n"; }
$CHILD_ERROR = 0;

                        my $cmd_5 = 'fold';
            my ($in_4, $out_4);
            my $pid_4 = open3($in_4, $out_4, '>&STDERR', $cmd_5, '-s', '-w');
            print {$in_4} $output_3;
            close $in_4 or croak 'Close failed: $OS_ERROR';
            $output_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
            close $out_4 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_4, 0;

                        my $cmd_7 = 'xmessage';
            my ($in_6, $out_6);
            my $pid_6 = open3($in_6, $out_6, '>&STDERR', $cmd_7, '-c', 'enter', '-f', 'ile', q{-});
            print {$in_6} $output_3;
            close $in_6 or croak 'Close failed: $OS_ERROR';
            $output_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> };
            close $out_6 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_6, 0;
            if ($output_3 ne q{} && !defined $output_printed_3) {
                print $output_3;
                if (!($output_3 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_3 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            }
    }
    return;
}

sub message_nonl {
    my $MESSAGE;
    my @MESSAGE;
    my %MESSAGE;
    $MESSAGE = "$PROGNAME: @ARGV";
    # Original bash: echo -n "$MESSAGE" | fold -s -w ${COLUMNS:-80} >&2;
{
        my $output_8 = q{};
        my $output_printed_8;
        my $pipeline_success_8 = 1;
        $output_8 .= $MESSAGE . "\n";
$CHILD_ERROR = 0;

                my $cmd_10 = 'fold';
        my ($in_9, $out_9);
        my $pid_9 = open3($in_9, $out_9, '>&STDERR', $cmd_10, '-s', '-w');
        print {$in_9} $output_8;
        close $in_9 or croak 'Close failed: $OS_ERROR';
        $output_8 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_9> };
        close $out_9 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_9, 0;
        if ($output_8 ne q{} && !defined $output_printed_8) {
            print $output_8;
            if (!($output_8 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_8 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        }
if (("$DISPLAY" ne q{} && !(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('command', '-v', 'xmessage') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    }))) {
        # Original bash: echo -n "$MESSAGE" | fold -s -w ${COLUMNS:-80} | xmessage -center -file -
{
            my $output_11 = q{};
            my $output_printed_11;
            my $pipeline_success_11 = 1;
            $output_11 .= $MESSAGE . "\n";
$CHILD_ERROR = 0;

                        my $cmd_13 = 'fold';
            my ($in_12, $out_12);
            my $pid_12 = open3($in_12, $out_12, '>&STDERR', $cmd_13, '-s', '-w');
            print {$in_12} $output_11;
            close $in_12 or croak 'Close failed: $OS_ERROR';
            $output_11 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_12> };
            close $out_12 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_12, 0;

                        my $cmd_15 = 'xmessage';
            my ($in_14, $out_14);
            my $pid_14 = open3($in_14, $out_14, '>&STDERR', $cmd_15, '-c', 'enter', '-f', 'ile', q{-});
            print {$in_14} $output_11;
            close $in_14 or croak 'Close failed: $OS_ERROR';
            $output_11 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_14> };
            close $out_14 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_14, 0;
            if ($output_11 ne q{} && !defined $output_printed_11) {
                print $output_11;
                if (!($output_11 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_11 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            }
    }
    return;
}

sub errormsg {
    message("@ARGV");
exit 1;
    return;
}

sub internal_errormsg {
    errormsg("@ARGV", "Please report the installed version of the \"x11-common\"", "package and the complete text of this error message to", "<debian-x@lists.debian.org>.");
    return;
}
my $OPTIONFILE;
my @OPTIONFILE;
my %OPTIONFILE;
$OPTIONFILE = '/etc/X11/Xsession.options';
my $SYSRESOURCES;
my @SYSRESOURCES;
my %SYSRESOURCES;
$SYSRESOURCES = '/etc/X11/Xresources';
my $USRRESOURCES;
my @USRRESOURCES;
my %USRRESOURCES;
$USRRESOURCES = $HOME;
$main_exit_code = system('bash', '/.Xresources') >> 8;
$SYSSESSIONDIR = '/etc/X11/Xsession.d';
my $USERXSESSION;
my @USERXSESSION;
my %USERXSESSION;
$USERXSESSION = $HOME;
$main_exit_code = system('bash', '/.xsession') >> 8;
my $USERXSESSIONRC;
my @USERXSESSIONRC;
my %USERXSESSIONRC;
$USERXSESSIONRC = $HOME;
$main_exit_code = system('bash', '/.xsessionrc') >> 8;
my $ALTUSERXSESSION;
my @ALTUSERXSESSION;
my %ALTUSERXSESSION;
$ALTUSERXSESSION = $HOME;
$main_exit_code = system('bash', '/.Xsession') >> 8;
$ERRFILE = $HOME;
$main_exit_code = system('bash', '/.xsession-errors') >> 8;
my $OPTIONS;
my @OPTIONS;
my %OPTIONS;
$OPTIONS = (do { my $_chomp_temp = do {
    my ($in_16, $out_16);
    my $pid_16 = open3($in_16, $out_16, '>&STDERR', 'if', q{[}, '-r', "$OPTIONFILE", q{]});
    close $in_16 or croak 'Close failed: $OS_ERROR';
    my $result_16 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_16> };
    close $out_16 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_16, 0;
    $result_16
}; chomp $_chomp_temp; $_chomp_temp; });

sub has_option {
if ("$(echo "$OPTIONS" | grep -Eo "^(no-)?$1\>" | tail -n 1)" eq "$1") {
return q{0};
}
    else {
return q{1};
    }
    return;
}
if (((!(do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
    do {
        local %ENV = %ENV;
        my $OPTIONFILE = $OPTIONFILE;
        my $PROGNAME = $PROGNAME;
        my $USRRESOURCES = $USRRESOURCES;
        my $USERXSESSION = $USERXSESSION;
        my $ALTUSERXSESSION = $ALTUSERXSESSION;
        my $USERXSESSIONRC = $USERXSESSIONRC;
        my $SYSRESOURCES = $SYSRESOURCES;
        my $OPTIONS = $OPTIONS;
        if (do {
$main_exit_code = system('umask', '077') >> 8;
            $CHILD_ERROR == 0
        }) {
                        if ( -e "$ERRFILE" ) {
                my $current_time = time;
                utime $current_time, $current_time, "$ERRFILE";
            }
            else {
                if ( open my $fh, '>', "$ERRFILE" ) {
                    close $fh or croak "Close failed: $ERRNO";
                }
                else {
                    croak "touch: cannot create ", "$ERRFILE",
                      ": $ERRNO\n";
                }
            }
        }
        q{};
    };
}) && (-w "$ERRFILE")) && (!-L "$ERRFILE"))) {
chmod(oct('600'), ("$ERRFILE")) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
else {
    if (!(    $ERRFILE = do { my @_qx_cmd = ("mktemp 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; })) {
if (!(!(symlink q{f}, (defined ($ENV{TMPDIR} // q{}) && ($ENV{TMPDIR} // q{}) ne q{} ? ($ENV{TMPDIR} // q{}) : do { $ENV{TMPDIR} = '/tmp'; ($ENV{TMPDIR} // q{}) }) . "/xsession-$ENV{USER}" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;))) {
            message("warning: unable to symlink \"$ENV{TMPDIR}/xsession-$ENV{USER}\" to", "\"$ERRFILE\"; look for session log/errors in", "\"$ENV{TMPDIR}/xsession-$ENV{USER}\".");
        }
}
    else {
        errormsg("unable to create X session log/error file; aborting.");
    }
}
if ((`stat -c%s \"$ERRFILE\"` > $MAGIC_500000)) {
    my $T;
    my @T;
    my %T;
    $T = do {
    my ($in_20, $out_20);
    my $pid_20 = open3($in_20, $out_20, '>&STDERR', 'mktemp', '-p', "$ENV{HOME}");
    close $in_20 or croak 'Close failed: $OS_ERROR';
    my $result_20 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> };
    close $out_20 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_20, 0;
    $result_20
};
        if (do {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$T"
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
do { my @_qx_cmd = ('tail -c 500000 "$ERRFILE"'); qx{$_qx_cmd[0]}; };
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    } == 0) {
                my $err;
        my $force = 1;
        if ( -e "$T" ) {
            my $dest = "$ERRFILE";
            if ( -e $dest && -d $dest ) {
                my $source_name = "$T";
                $source_name =~ s{^.*[\/]}{};
                $dest = "$dest/$source_name";
            }
            if ( -e $dest && !$force ) {
                croak "mv: $dest: File exists (use -f to force overwrite)\n";
            }
            my $dest_dir = $dest;
            $dest_dir =~ s/\/[^\/]*$//msx;
            if ( $dest_dir eq $dest ) {
                $dest_dir = q{};
            }
            if ( $dest_dir ne q{} && !-d $dest_dir ) {
                my $err;
                make_path( $dest_dir, { error => \$err } );
                if ( @{$err} ) {
                    croak "mv: cannot create directory $dest_dir: $err->[0]\n";
                }
            }
            require File::Copy;
            if ( File::Copy::move( "$T", $dest ) ) {
            } else {
                croak
  "mv: cannot move "$T" to $dest: $ERRNO\n";
            }
        } else {
            croak "mv: "$T": No such file or directory\n";
        }
    }
    if ($CHILD_ERROR != 0) {
        if ( -e "$T" ) {
            if ( -d "$T" ) {
                carp "rm: carping: ", "$T",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$T" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$T",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
}
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>>', "$ERRFILE"
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
# Builtin command 'exec' not implemented
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
do {
    my $__echo_line = "$PROGNAME: X session started for $ENV{LOGNAME} at " . (do { my $_chomp_temp = do {
require POSIX; POSIX::strftime('%a %b %e %H:%M:%S %Z %Y', localtime(time())) . "\n"
}; chomp $_chomp_temp; $_chomp_temp; });
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
if ((!-d "$SYSSESSIONDIR")) {
    errormsg("no \"$SYSSESSIONDIR\" directory found; aborting.");
}
my $WRITE_TEST;
my @WRITE_TEST;
my %WRITE_TEST;
$WRITE_TEST = do {
    my ($in_23, $out_23);
    my $pid_23 = open3($in_23, $out_23, '>&STDERR', 'mktemp');
    close $in_23 or croak 'Close failed: $OS_ERROR';
    my $result_23 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_23> };
    close $out_23 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_23, 0;
    $result_23
};
if (!(!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>>', "$WRITE_TEST"
      or die "Cannot open file: $OS_ERROR\n";
    print "*\n";
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};))) {
    message("warning: unable to write to " . ( ( dirname(${WRITE_TEST}) ) =~ s|/[^/]*$||sr ) . "; X session may exit", "with an error");
}
if ( -e "$WRITE_TEST" ) {
    if ( -d "$WRITE_TEST" ) {
        carp "rm: carping: ", "$WRITE_TEST",
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "$WRITE_TEST" ) {
                    }
        else {
            carp "rm: carping: could not remove ", "$WRITE_TEST",
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 0;
}
$SESSIONFILES = do {
    my ($in_24, $out_24);
    my $pid_24 = open3($in_24, $out_24, '>&STDERR', 'run-parts', '--list', $SYSSESSIONDIR);
    close $in_24 or croak 'Close failed: $OS_ERROR';
    my $result_24 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_24> };
    close $out_24 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_24, 0;
    $result_24
};
if ("$SESSIONFILES" ne q{}) {
# set +e not implemented
    my $SESSIONFILE;
    for my $SESSIONFILE ($SESSIONFILES) {
        $main_exit_code = system('.', $SESSIONFILE) >> 8;
    }
$__set_e = 1;
}
exit 0;

exit $main_exit_code;
