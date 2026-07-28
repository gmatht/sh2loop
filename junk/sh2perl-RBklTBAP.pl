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

my $mysql_unix_port_dir;
my @mysql_unix_port_dir;
my %mysql_unix_port_dir;
my $err_log;
my @err_log;
my %err_log;
my $logging;
my @logging;
my %logging;
my $user;
my @user;
my %user;
my $log_dir_name;
my @log_dir_name;
my %log_dir_name;
my $safe_mysql_unix_port;
my @safe_mysql_unix_port;
my %safe_mysql_unix_port;
my $want_syslog;
my @want_syslog;
my %want_syslog;
my $fmlen;
my @fmlen;
my %fmlen;
my $MY_BASEDIR_VERSION;
my @MY_BASEDIR_VERSION;
my %MY_BASEDIR_VERSION;
my $dir;
my @dir;
my %dir;
my $plugin_dir;
my @plugin_dir;
my %plugin_dir;
my $safe_pid;
my @safe_pid;
my %safe_pid;
my $fmode;
my @fmode;
my %fmode;
my $syslog_tag;
my @syslog_tag;
my %syslog_tag;
my $PLUGIN_DIR;
my @PLUGIN_DIR;
my %PLUGIN_DIR;
my $octalp;
my @octalp;
my %octalp;
my $pid_file;
my @pid_file;
my %pid_file;
my $UMASK;
my @UMASK;
my %UMASK;

my $MAGIC_16 = 16;
my $MAGIC_7  = 7;

my $KILL_MYSQLD;
my @KILL_MYSQLD;
my %KILL_MYSQLD;
$KILL_MYSQLD = q{1};
my $MYSQLD;
my @MYSQLD;
my %MYSQLD;
$MYSQLD = q{};
my $niceness;
my @niceness;
my %niceness;
$niceness = q{0};
my $mysqld_ld_preload;
my @mysqld_ld_preload;
my %mysqld_ld_preload;
$mysqld_ld_preload = q{};
my $mysqld_ld_library_path;
my @mysqld_ld_library_path;
my %mysqld_ld_library_path;
$mysqld_ld_library_path = q{};
$logging = 'init';
$want_syslog = q{0};
$syslog_tag = q{};
$user = 'mysql';
$pid_file = q{};
my $pid_file_append;
my @pid_file_append;
my %pid_file_append;
$pid_file_append = q{};
$err_log = q{};
my $err_log_append;
my @err_log_append;
my %err_log_append;
$err_log_append = q{};
my $timestamp_format;
my @timestamp_format;
my %timestamp_format;
$timestamp_format = 'UTC';
my $syslog_tag_mysqld;
my @syslog_tag_mysqld;
my %syslog_tag_mysqld;
$syslog_tag_mysqld = 'mysqld';
my $syslog_tag_mysqld_safe;
my @syslog_tag_mysqld_safe;
my %syslog_tag_mysqld_safe;
$syslog_tag_mysqld_safe = 'mysqld_safe';
my $syslog_facility;
my @syslog_facility;
my %syslog_facility;
$syslog_facility = 'daemon';
$SIG{1} = sub { qx''; };
$SIG{13} = sub { qx''; };
$main_exit_code = system('umask', '007') >> 8;
$UMASK = (defined (defined ${UMASK} && ${UMASK} ne q{} ? ${UMASK} : '0640') && (defined ${UMASK} && ${UMASK} ne q{} ? ${UMASK} : '0640') ne q{} ? (defined ${UMASK} && ${UMASK} ne q{} ? ${UMASK} : '0640') : '0640');
$fmode = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;
    $output_0 .= $UMASK . "\n";
    if ( !($output_0 =~ m{\n\z}msx) ) { $output_0 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
    my @sed_lines_0 = split /\n/msx, $output_0;
    my @sed_result_0;
    foreach my $line (@sed_lines_0) {
    chomp $line;
    push @sed_result_0, $line;
    }
    $output_0 = join "\n", @sed_result_0;

    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    $output_0 =~ s/\n+\z//msx;
    $output_0;
}; $_pipeline_result; };
$octalp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_1 = q{};
    my $output_printed_1;
    my $pipeline_success_1 = 1;
    $output_1 .= $fmode . "\n";
    if ( !($output_1 =~ m{\n\z}msx) ) { $output_1 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_1 = 0; }
    my @lines_2 = split /\n/msx, $output_1;
    my @result_2;
    foreach my $line (@lines_2) {
    chomp $line;
    my @fields = split /\t/msx, $line;
    if (@fields > 0) {
        push @result_2, $fields[0];
    }
    }
    $output_1 = join "\n", @result_2;
    if ($output_1 ne q{} && !($output_1  =~ m{\n\z}msx)) { $output_1 .= "\n"; }

    if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
    $output_1 =~ s/\n+\z//msx;
    $output_1;
}; $_pipeline_result; };
$fmlen = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_3 = q{};
    my $output_printed_3;
    my $pipeline_success_3 = 1;
    $output_3 .= $fmode . "\n";
    if ( !($output_3 =~ m{\n\z}msx) ) { $output_3 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_3 = 0; }
    $output_3 = do {
            my $_wc_data = $output_3;
            my $_wc_bytes = length($_wc_data);
            my $_wc_result = q{};
            $_wc_result .= sprintf q{%d}, $_wc_bytes;
            $_wc_result .= "\n";
            $_wc_result;
        };
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
if (0) {
    $fmode = '0640';
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "UMASK must be a 3-digit mode with an additional leading 0 to indicate octal.\n";
    };
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "The first digit will be corrected to 6, the others may be 0, 2, 4, or 6.\n";
    };
}
$fmode = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_4 = q{};
    my $output_printed_4;
    my $pipeline_success_4 = 1;
    $output_4 .= $fmode . "\n";
    if ( !($output_4 =~ m{\n\z}msx) ) { $output_4 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_4 = 0; }
    my @lines_5 = split /\n/msx, $output_4;
    my @result_5;
    foreach my $line (@lines_5) {
    chomp $line;
    my @fields = split /\t/msx, $line;
    if (@fields > 0) {
        push @result_5, $fields[0];
    }
    }
    $output_4 = join "\n", @result_5;
    if ($output_4 ne q{} && !($output_4  =~ m{\n\z}msx)) { $output_4 .= "\n"; }

    if ( !$pipeline_success_4 ) { $main_exit_code = 1; }
    $output_4 =~ s/\n+\z//msx;
    $output_4;
}; $_pipeline_result; };
$fmode = "6$fmode";
if ("x$UMASK" ne "x0$fmode") {
    do {
    my $__echo_line = "UMASK corrected from $UMASK to 0$fmode ...";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
}
my $defaults;
my @defaults;
my %defaults;
$defaults = q{};
if ("$_[0]" =~ /^--no-defaults$/msx or "$_[0]" =~ /^--defaults-file=.*$/msx or "$_[0]" =~ /^--defaults-extra-file=.*$/msx) {
        $defaults = "$_[0]";
    # Builtin command 'shift' not implemented
}

sub usage {
print "Usage: $0 [OPTIONS]
 The following options may be given as the first argument:
  --no-defaults              Don't read the system defaults file
  --defaults-file=FILE       Use the specified defaults file
  --defaults-extra-file=FILE Also use defaults from the specified file

 Other options:
  --ledir=DIRECTORY          Look for mysqld in the specified directory
  --open-files-limit=LIMIT   Limit the number of open files
  --core-file-size=LIMIT     Limit core files to the specified size
  --timezone=TZ              Set the system timezone
  --malloc-lib=LIB           Preload shared library LIB if available
  --mysqld=FILE              Use the specified file as mysqld
  --mysqld-version=VERSION   Use \"mysqld-VERSION\" as mysqld
  --nice=NICE                Set the scheduling priority of mysqld
  --plugin-dir=DIR           Plugins are under DIR or DIR/VERSION, if
                             VERSION is given
  --skip-kill-mysqld         Don't try to kill stray mysqld processes
  --syslog                   Log messages to syslog with 'logger'
  --skip-syslog              Log messages to error log (default)
  --syslog-tag=TAG           Pass -t \"mysqld-TAG\" to 'logger'
  --mysqld-safe-log-         TYPE must be one of UTC (ISO 8601 UTC),
    timestamps=TYPE          system (ISO 8601 local time), hyphen
                             (hyphenated date a la mysqld 5.6), legacy
                             (legacy non-ISO 8601 mysqld_safe timestamps)

All other options are passed to the mysqld program.

";
exit 1;
    return;
}

sub my_which {
    my $save_ifs;
    my @save_ifs;
    my %save_ifs;
    $save_ifs = (defined (defined ($ENV{IFS} // q{}) && ($ENV{IFS} // q{}) ne q{} ? ($ENV{IFS} // q{}) : 'UNSET') && (defined ($ENV{IFS} // q{}) && ($ENV{IFS} // q{}) ne q{} ? ($ENV{IFS} // q{}) : 'UNSET') ne q{} ? (defined ($ENV{IFS} // q{}) && ($ENV{IFS} // q{}) ne q{} ? ($ENV{IFS} // q{}) : 'UNSET') : 'UNSET');
    my $IFS;
    my @IFS;
    my %IFS;
    $IFS = q{:};
    my $ret;
    my @ret;
    my %ret;
    $ret = q{0};
    my $file;
    for my $file () {
        for my $dir ($PATH) {
if ((-f "$dir/$file")) {
                do {
    my $__echo_line = "$dir/$file";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
next LABEL2;
            }
        }
        $ret = q{1};
last;
    }
if ("$save_ifs" eq UNSET) {
undef $IFS;
delete $ENV{IFS};
}
    else {
        $IFS = "$save_ifs";
    }
return $ret;
    return;
}

sub log_generic {
    my $priority;
    my @priority;
    my %priority;
    $priority = "$_[0]";
# Builtin command 'shift' not implemented
    my $msg;
    my @msg;
    my %msg;
    $msg = (do { my $_chomp_temp = do {
    local $ENV{DATE} = $DATE;
    my $command = q{: 'Complex command not supported in bash string generation'};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; }) . " mysqld_safe @ARGV";
    print $msg;
if ( !( ($msg) =~ m{\n\z}msx ) ) { print "\n"; }
if ($logging =~ /^init$/msx) {
    } elsif ($logging =~ /^file$/msx) {
        if (((-w '/') || "$USER" eq "root")) {
1;
}
        else {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "$err_log"
      or die "Cannot open file: $OS_ERROR\n";
                print $msg;
if ( !( ($msg) =~ m{\n\z}msx ) ) { print "\n"; }
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
    } elsif ($logging =~ /^syslog$/msx) {
                $main_exit_code = system('logger', '-t', "$syslog_tag_mysqld_safe", '-p', "$priority", "@ARGV") >> 8;
    } elsif ($logging =~ /^both$/msx) {
        if (((-w '/') || "$USER" eq "root")) {
1;
}
        else {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "$err_log"
      or die "Cannot open file: $OS_ERROR\n";
                print $msg;
if ( !( ($msg) =~ m{\n\z}msx ) ) { print "\n"; }
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
                $main_exit_code = system('logger', '-t', "$syslog_tag_mysqld_safe", '-p', "$priority", "@ARGV") >> 8;
    } elsif (1) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "Internal program error (non-fatal):" . q{ } . " unknown logging method '$logging'";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
    }
    return;
}

sub log_error {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        log_generic($syslog_facility, '.error', "@ARGV");
    };
    return;
}

sub log_notice {
    log_generic($syslog_facility, '.notice', "@ARGV");
    return;
}

sub eval_log_error {
    my $cmd;
    my @cmd;
    my %cmd;
    $cmd = "$_[0]";
if ($logging =~ /^file$/msx) {
        if (((-w '/') || "$USER" eq "root")) {
            $cmd = "$cmd > /dev/null 2>&1";
}
        else {
            $cmd = "$cmd >> ";
            $CHILD_ERROR = 0;
        }
    } elsif ($logging =~ /^syslog$/msx) {
                $cmd = "$cmd --log-syslog=1 --log-syslog-facility=$syslog_facility '--log-syslog-tag=$syslog_tag' > /dev/null 2>&1";
    } elsif ($logging =~ /^both$/msx) {
        if (((-w '/') || "$USER" eq "root")) {
            $cmd = "$cmd --log-syslog=1 --log-syslog-facility=$syslog_facility '--log-syslog-tag=$syslog_tag' > /dev/null 2>&1";
}
        else {
            $cmd = "$cmd --log-syslog=1 --log-syslog-facility=$syslog_facility '--log-syslog-tag=$syslog_tag' >> ";
            $CHILD_ERROR = 0;
        }
    } elsif (1) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "Internal program error (non-fatal):" . q{ } . " unknown logging method '$logging'";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
    }
    $cmd = "env MYSQLD_PARENT_PID=$ENV{$} $cmd";
do { my $eval_input = $cmd; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
    return;
}

sub shell_quote_string {
    my ($file) = @_;
    # Original bash: echo "$1" | sed -e 's,\([^a-zA-Z0-9/_.=-]\),\\\1,g'
{
        my $output_8 = q{};
        my $output_printed_8;
        my $pipeline_success_8 = 1;
        $output_8 .= $1 . "\n";
if ( !($output_8 =~ m{\n\z}msx) ) { $output_8 .= "\n"; }
$CHILD_ERROR = 0;

                my @sed_lines_8 = split /\n/msx, $output_8;
        my @sed_result_8;
        foreach my $line (@sed_lines_8) {
        chomp $line;
        push @sed_result_8, $line;
        }
        $output_8 = join "\n", @sed_result_8;
        if ($output_8 ne q{} && !defined $output_printed_8) {
            print $output_8;
            if (!($output_8 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_8 ) { $main_exit_code = 1; }
        }
    return;
}

sub parse_arguments {
    my $pick_args;
    my @pick_args;
    my %pick_args;
    $pick_args = q{};
if (StringInterpolation(StringInterpolation { parts: [Variable("1")] }, None) eq PICK-ARGS-FROM-ARGV) {
        $pick_args = q{1};
# Builtin command 'shift' not implemented
    }
    my $arg;
    for my $arg () {
        my $val;
        my @val;
        my %val;
        $val = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_9 = q{};
            my $output_printed_9;
            my $pipeline_success_9 = 1;
            $output_9 .= $arg . "\n";
            if ( !($output_9 =~ m{\n\z}msx) ) { $output_9 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_9 = 0; }
            my @sed_lines_9 = split /\n/msx, $output_9;
            my @sed_result_9;
            foreach my $line (@sed_lines_9) {
            chomp $line;
            push @sed_result_9, $line;
            }
            $output_9 = join "\n", @sed_result_9;

            if ( !$pipeline_success_9 ) { $main_exit_code = 1; }
            $output_9 =~ s/\n+\z//msx;
            $output_9;
}; $_pipeline_result; };
        my $optname;
        my @optname;
        my %optname;
        $optname = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_10 = q{};
            my $output_printed_10;
            my $pipeline_success_10 = 1;
            $output_10 .= $arg . "\n";
            if ( !($output_10 =~ m{\n\z}msx) ) { $output_10 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_10 = 0; }
            my @sed_lines_10 = split /\n/msx, $output_10;
            my @sed_result_10;
            foreach my $line (@sed_lines_10) {
            chomp $line;
            push @sed_result_10, $line;
            }
            $output_10 = join "\n", @sed_result_10;

            if ( !$pipeline_success_10 ) { $main_exit_code = 1; }
            $output_10 =~ s/\n+\z//msx;
            $output_10;
}; $_pipeline_result; };
        my $optname_subst;
        my @optname_subst;
        my %optname_subst;
        $optname_subst = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_11 = q{};
            my $output_printed_11;
            my $pipeline_success_11 = 1;
            $output_11 .= $optname . "\n";
            if ( !($output_11 =~ m{\n\z}msx) ) { $output_11 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_11 = 0; }
            my @sed_lines_11 = split /\n/msx, $output_11;
            my @sed_result_11;
            foreach my $line (@sed_lines_11) {
            chomp $line;
            $line =~ s/_/-/gmsx;
            push @sed_result_11, $line;
            }
            $output_11 = join "\n", @sed_result_11;

            if ( !$pipeline_success_11 ) { $main_exit_code = 1; }
            $output_11 =~ s/\n+\z//msx;
            $output_11;
}; $_pipeline_result; };
        $arg = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_12 = q{};
            my $output_printed_12;
            my $pipeline_success_12 = 1;
            $output_12 .= $arg . "\n";
            if ( !($output_12 =~ m{\n\z}msx) ) { $output_12 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_12 = 0; }
            my @sed_lines_12 = split /\n/msx, $output_12;
            my @sed_result_12;
            foreach my $line (@sed_lines_12) {
            chomp $line;
            push @sed_result_12, $line;
            }
            $output_12 = join "\n", @sed_result_12;

            if ( !$pipeline_success_12 ) { $main_exit_code = 1; }
            $output_12 =~ s/\n+\z//msx;
            $output_12;
}; $_pipeline_result; };
if ("$arg" =~ /^--basedir=.*$/msx) {
                        $MY_BASEDIR_VERSION = "$val";
        } elsif ("$arg" =~ /^--datadir=.*$/msx) {
            if ($val =~ /^/$/msx) {
                                my $DATADIR;
                my @DATADIR;
                my %DATADIR;
                $DATADIR = $val;
            } elsif (1) {
                                $DATADIR = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                    my $output_13 = q{};
                    my $output_printed_13;
                    my $pipeline_success_13 = 1;
                    $output_13 .= $val . "\n";
                    if ( !($output_13 =~ m{\n\z}msx) ) { $output_13 .= "\n"; }
                    $CHILD_ERROR = 0;
                    if ($CHILD_ERROR != 0) { $pipeline_success_13 = 0; }
                    my @sed_lines_13 = split /\n/msx, $output_13;
                    my @sed_result_13;
                    foreach my $line (@sed_lines_13) {
                    chomp $line;
                    push @sed_result_13, $line;
                    }
                    $output_13 = join "\n", @sed_result_13;

                    if ( !$pipeline_success_13 ) { $main_exit_code = 1; }
                    $output_13 =~ s/\n+\z//msx;
                    $output_13;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
            }
        } elsif ("$arg" =~ /^--pid-file=.*$/msx) {
                        $pid_file = "$val";
        } elsif ("$arg" =~ /^--plugin-dir=.*$/msx) {
                        $PLUGIN_DIR = "$val";
        } elsif ("$arg" =~ /^--user=.*$/msx) {
                        $user = "$val";
                        my $SET_USER;
            my @SET_USER;
            my %SET_USER;
            $SET_USER = q{1};
        } elsif ("$arg" =~ /^--log-error=.*$/msx) {
                        $err_log = "$val";
        } elsif ("$arg" =~ /^--port=.*$/msx) {
                        my $mysql_tcp_port;
            my @mysql_tcp_port;
            my %mysql_tcp_port;
            $mysql_tcp_port = "$val";
        } elsif ("$arg" =~ /^--socket=.*$/msx) {
                        my $mysql_unix_port;
            my @mysql_unix_port;
            my %mysql_unix_port;
            $mysql_unix_port = "$val";
        } elsif ("$arg" =~ /^--core-file-size=.*$/msx) {
                        my $core_file_size;
            my @core_file_size;
            my %core_file_size;
            $core_file_size = "$val";
        } elsif ("$arg" =~ /^--ledir=.*$/msx) {
            if ("$pick_args" eq q{}) {
                log_error("--ledir option can only be used as command line option, found in config file");
exit 1;
            }
                        my $ledir;
            my @ledir;
            my %ledir;
            $ledir = "$val";
        } elsif ("$arg" =~ /^--malloc-lib=.*$/msx) {
                        $main_exit_code = system('set_malloc_lib', "$val") >> 8;
        } elsif ("$arg" =~ /^--mysqld=.*$/msx) {
            if ("$pick_args" eq q{}) {
                log_error("--mysqld option can only be used as command line option, found in config file");
exit 1;
            }
                        $MYSQLD = "$val";
        } elsif ("$arg" =~ /^--mysqld-version=.*$/msx) {
            if ("$pick_args" eq q{}) {
                log_error("--mysqld-version option can only be used as command line option, found in config file");
exit 1;
            }
            if (StringInterpolation(StringInterpolation { parts: [Variable("val")] }, None) ne q{}) {
                $MYSQLD = "mysqld-$val";
                my $PLUGIN_VARIANT;
                my @PLUGIN_VARIANT;
                my %PLUGIN_VARIANT;
                $PLUGIN_VARIANT = "/$val";
}
            else {
                $MYSQLD = "mysqld";
            }
        } elsif ("$arg" =~ /^--nice=.*$/msx) {
                        $niceness = "$val";
        } elsif ("$arg" =~ /^--open-files-limit=.*$/msx) {
                        my $open_files;
            my @open_files;
            my %open_files;
            $open_files = "$val";
        } elsif ("$arg" =~ /^--open_files_limit=.*$/msx) {
                        $open_files = "$val";
        } elsif ("$arg" =~ /^--skip-kill-mysqld.*$/msx) {
                        $KILL_MYSQLD = q{0};
        } elsif ("$arg" =~ /^--mysqld-safe-log-timestamps=.*$/msx) {
                        $timestamp_format = "$val";
        } elsif ("$arg" =~ /^--syslog$/msx) {
                        $want_syslog = q{1};
        } elsif ("$arg" =~ /^--skip-syslog$/msx) {
                        $want_syslog = q{0};
        } elsif ("$arg" =~ /^--syslog-tag=.*$/msx) {
                        $syslog_tag = "$val";
        } elsif ("$arg" =~ /^--timezone=.*$/msx) {
                        my $TZ;
            my @TZ;
            my %TZ;
            $TZ = "$val";
            $ENV{TZ} = $TZ;
        } elsif ("$arg" =~ /^--help$/msx) {
                        usage();
        } elsif (1) {
            if (StringInterpolation(StringInterpolation { parts: [Variable("pick_args")] }, None) ne q{}) {
                $main_exit_code = system('append_arg_to_args', "$arg") >> 8;
            }
        }
    }
    return;
}

sub add_mysqld_ld_preload {
    my $lib_to_add;
    my @lib_to_add;
    my %lib_to_add;
    $lib_to_add = "$_[0]";
    log_notice("Adding '$lib_to_add' to LD_PRELOAD for mysqld");
if ("$lib_to_add" =~ /^.*' '.*$/msx) {
                my $lib_file;
        my @lib_file;
        my %lib_file;
        $lib_file = do { use File::Basename qw(basename); my $basename_output = basename("$lib_to_add"); $CHILD_ERROR = 0; $basename_output; };
        if ("$lib_file" =~ /^.*' '.*$/msx) {
                        log_error("library name '$lib_to_add' contains spaces and can not be used with LD_PRELOAD");
            exit 1;
        }
                my $lib_path;
        my @lib_path;
        my %lib_path;
        $lib_path = do { use File::Basename qw(dirname); my $dirname_output = dirname("$lib_to_add"); $CHILD_ERROR = 0; $dirname_output; };
                $lib_to_add = "$lib_file";
                if ("$mysqld_ld_library_path" ne q{}) {
                        $mysqld_ld_library_path = "$mysqld_ld_library_path:";
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
                $mysqld_ld_library_path = "$mysqld_ld_library_path$lib_path";
    }
    if ("$mysqld_ld_preload" ne q{}) {
                $mysqld_ld_preload = "$mysqld_ld_preload ";
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    $mysqld_ld_preload = ${mysqld_ld_preload} . "$lib_to_add";
    return;
}

sub mysqld_ld_preload_text {
    my $text;
    my @text;
    my %text;
    $text = q{};
if ("$mysqld_ld_preload" ne q{}) {
        my $new_text;
        my @new_text;
        my %new_text;
        $new_text = "$mysqld_ld_preload";
        if ("$LD_PRELOAD" ne q{}) {
                        $new_text = "$new_text $ENV{LD_PRELOAD}";
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        $text = ${text} . "LD_PRELOAD=";
        $CHILD_ERROR = 0;
    }
if ("$mysqld_ld_library_path" ne q{}) {
        $new_text = "$mysqld_ld_library_path";
        if ("$LD_LIBRARY_PATH" ne q{}) {
                        $new_text = "$new_text:$ENV{LD_LIBRARY_PATH}";
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
        $text = ${text} . "LD_LIBRARY_PATH=";
        $CHILD_ERROR = 0;
    }
    print $text;
if ( !( ($text) =~ m{\n\z}msx ) ) { print "\n"; }
    return;
}

sub set_malloc_lib {
    my $malloc_dirs;
    my @malloc_dirs;
    my %malloc_dirs;
    $malloc_dirs = "/usr/lib /usr/lib64 /usr/lib/i386-linux-gnu /usr/lib/x86_64-linux-gnu";
    my $malloc_lib;
    my @malloc_lib;
    my %malloc_lib;
    $malloc_lib = "$_[0]";
    if ("$malloc_lib" eq q{}) {
        return;        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
if ("$malloc_lib" =~ /^/.*$/msx) {
        if ((!-r "$malloc_lib")) {
            log_error("--malloc-lib can not be read and will not be used");
exit 1;
        }
        if ((do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname("$malloc_lib"); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }) =~ /^/usr/lib$/msx) {
        } elsif ((do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname("$malloc_lib"); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }) =~ /^/usr/lib64$/msx) {
        } elsif ((do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname("$malloc_lib"); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }) =~ /^/usr/lib/i386-linux-gnu$/msx) {
        } elsif ((do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname("$malloc_lib"); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }) =~ /^/usr/lib/x86_64-linux-gnu$/msx) {
        } elsif (1) {
                        log_error("--malloc-lib must be located in one of the directories: $malloc_dirs");
            exit 1;
        }
    } elsif (1) {
                log_error("--malloc-lib must be an absolute path ignoring value '$malloc_lib'");
        exit 1;
    }
    add_mysqld_ld_preload("$malloc_lib");
    return;
}

sub find_basedir_from_cmdline {
    my $arg;
    for my $arg (@ARGV) {
if ($arg =~ /^--basedir=.*$/msx) {
                        $MY_BASEDIR_VERSION = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_14 = q{};
                my $output_printed_14;
                my $pipeline_success_14 = 1;
                $output_14 .= $arg . "\n";
                if ( !($output_14 =~ m{\n\z}msx) ) { $output_14 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_14 = 0; }
                my @sed_lines_14 = split /\n/msx, $output_14;
                my @sed_result_14;
                foreach my $line (@sed_lines_14) {
                chomp $line;
                push @sed_result_14, $line;
                }
                $output_14 = join "\n", @sed_result_14;

                if ( !$pipeline_success_14 ) { $main_exit_code = 1; }
                $output_14 =~ s/\n+\z//msx;
                $output_14;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
                        chdir("$MY_BASEDIR_VERSION");
            $CHILD_ERROR = 0;
            if (($? != 0)) {
                log_error("--basedir set to '$MY_BASEDIR_VERSION', however could not access directory");
exit 1;
            }
                        $MY_BASEDIR_VERSION = (do { my $_chomp_temp = do { use Cwd; getcwd(); }; chomp $_chomp_temp; $_chomp_temp; });
        }
    }
    return;
}
my $oldpwd;
my @oldpwd;
my %oldpwd;
$oldpwd = (do { my $_chomp_temp = do { use Cwd; getcwd(); }; chomp $_chomp_temp; $_chomp_temp; });
find_basedir_from_cmdline("@ARGV");
if ((StringInterpolation(StringInterpolation { parts: [Variable("MY_BASEDIR_VERSION")] }, None) ne q{} && (-d 'StringInterpolation(StringInterpolation { parts: [Variable("MY_BASEDIR_VERSION")] }, None)'))) {
    for my $dir ('sbin', 'libexec', 'sbin', 'bin') {
if ((-x 'StringInterpolation(StringInterpolation { parts: [Variable("MY_BASEDIR_VERSION"), Literal("/"), Variable("dir"), Literal("/mysqld")] }, None)')) {
            my $ledir;
            my @ledir;
            my %ledir;
            $ledir = "$MY_BASEDIR_VERSION/$dir";
last;
        }
    }
    $dir = 'bin';
}
else {
    chdir((do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname($PROGRAM_NAME); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }));
    $CHILD_ERROR = 0;
if (( -h "$0")) {
        my $realpath;
        my @realpath;
        my %realpath;
        $realpath = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_15 = q{};
            my $output_printed_15;
            my $pipeline_success_15 = 1;
            $output_15 = do { my @_qx_cmd = ('ls -l "$0"'); my $result = qx{$_qx_cmd[0]}; $CHILD_ERROR = $? >> 8; $result; };
            if ($CHILD_ERROR != 0) { $pipeline_success_15 = 0; }
            my @lines = split /\n/msx, $output_15;
            my @result;
            foreach my $line (@lines) {
                chomp $line;
                if ($line =~ /^\s*$/msx) { next; }
                my @fields = split /\s+/msx, $line;
                push @result, ($scalar(@fields) . "\n");
            }
            $output_15 = join "", @result;

            if ( !$pipeline_success_15 ) { $main_exit_code = 1; }
            $output_15 =~ s/\n+\z//msx;
            $output_15;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
        chdir((do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname("$realpath"); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }));
        $CHILD_ERROR = 0;
    }
    chdir('..');
    $CHILD_ERROR = 0;
    my $MY_PWD;
    my @MY_PWD;
    my %MY_PWD;
    $MY_PWD = (do { my $_chomp_temp = do { use Cwd; getcwd(); }; chomp $_chomp_temp; $_chomp_temp; });
    for my $dir ('sbin', 'libexec', 'sbin', 'bin') {
if ((-x 'StringInterpolation(StringInterpolation { parts: [Variable("MY_PWD"), Literal("/"), Variable("dir"), Literal("/mysqld")] }, None)')) {
            $MY_BASEDIR_VERSION = "$MY_PWD";
            $ledir = "$MY_BASEDIR_VERSION/$dir";
last;
        }
    }
    $dir = 'bin';
if (StringInterpolation(StringInterpolation { parts: [Variable("MY_BASEDIR_VERSION")] }, None) eq q{}) {
        $MY_BASEDIR_VERSION = '/usr';
        $ledir = '/usr/sbin';
    }
}
if ((-d 'Variable("MY_BASEDIR_VERSION", false, None) /data/mysql')) {
    my $DATADIR;
    my @DATADIR;
    my %DATADIR;
    $DATADIR = $MY_BASEDIR_VERSION;
    $main_exit_code = system('bash', '/data') >> 8;
}
else {
    $DATADIR = '/var/lib/mysql';
}
if (StringInterpolation(StringInterpolation { parts: [Variable("MYSQL_HOME")] }, None) eq q{}) {
    my $MYSQL_HOME;
    my @MYSQL_HOME;
    my %MYSQL_HOME;
    $MYSQL_HOME = $MY_BASEDIR_VERSION;
}
$ENV{MYSQL_HOME} = $MYSQL_HOME;
if ((-x 'StringInterpolation(StringInterpolation { parts: [Variable("MY_BASEDIR_VERSION"), Literal("/bin/my_print_defaults")] }, None)')) {
    my $print_defaults;
    my @print_defaults;
    my %print_defaults;
    $print_defaults = "$MY_BASEDIR_VERSION/bin/my_print_defaults";
}
else {
    if ((-x 'StringInterpolation(StringInterpolation { parts: [Literal("/usr/bin/my_print_defaults")] }, None)')) {
        $print_defaults = "/usr/bin/my_print_defaults";
}
    else {
        $print_defaults = "my_print_defaults";
    }
}

sub append_arg_to_args {
    my ($file) = @_;
    my $args;
    my @args;
    my %args;
    $args = "$args ";
    $CHILD_ERROR = 0;
    return;
}
my $args;
my @args;
my %args;
$args = q{};
chdir("$oldpwd");
$CHILD_ERROR = 0;
my $SET_USER;
my @SET_USER;
my %SET_USER;
$SET_USER = q{2};
parse_arguments(do { my ($in_16, $out_16); my $pid_16 = open3($in_16, $out_16, '>&STDERR', $print_defaults, '$defaults', ''--loose-verbose'', ''mysqld'', ''server''); close $in_16 or croak 'Close failed: $OS_ERROR'; my $result_16 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_16> }; close $out_16 or croak 'Close failed: $OS_ERROR'; waitpid $pid_16, 0; $result_16 });
if ((Variable("SET_USER", false, None) == 2)) {
    $SET_USER = q{0};
}
parse_arguments(do { my ($in_17, $out_17); my $pid_17 = open3($in_17, $out_17, '>&STDERR', $print_defaults, '$defaults', ''--loose-verbose'', ''mysqld_safe'', ''safe_mysqld''); close $in_17 or croak 'Close failed: $OS_ERROR'; my $result_17 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_17> }; close $out_17 or croak 'Close failed: $OS_ERROR'; waitpid $pid_17, 0; $result_17 });
parse_arguments('PICK-ARGS-FROM-ARGV', "@ARGV");
if ("$timestamp_format" =~ /^UTC$/msx or "$timestamp_format" =~ /^utc$/msx) {
        my $DATE;
    my @DATE;
    my %DATE;
    $DATE = "date -u +%Y-%m-%dT%H:%M:%S.%06NZ";
} elsif ("$timestamp_format" =~ /^SYSTEM$/msx or "$timestamp_format" =~ /^system$/msx) {
        $DATE = "date +%Y-%m-%dT%H:%M:%S.%06N%:z";
} elsif ("$timestamp_format" =~ /^HYPHEN$/msx or "$timestamp_format" =~ /^hyphen$/msx) {
        $DATE = "date +'%Y-%m-%d %H:%M:%S'";
} elsif ("$timestamp_format" =~ /^LEGACY$/msx or "$timestamp_format" =~ /^legacy$/msx) {
        $DATE = "date +'%y%m%d %H:%M:%S'";
} elsif (1) {
        $DATE = "date -u +%Y-%m-%dT%H:%M:%S.%06NZ";
        log_error("unknown data format $timestamp_format, using UTC");
}
if ("${PLUGIN_DIR}" ne q{}) {
    $plugin_dir = ${PLUGIN_DIR};
}
else {
    for my $dir ('lib64/mysql/plugin', 'lib64/plugin', 'lib/mysql/plugin', 'lib/plugin') {
if ((-d "${MY_BASEDIR_VERSION}/${dir}")) {
            $plugin_dir = ${MY_BASEDIR_VERSION} . "/" . ${dir};
last;
        }
    }
    $dir = 'lib/plugin';
if ("${plugin_dir}" eq q{}) {
        $plugin_dir = '/usr/lib/mysql/plugin';
    }
}
$plugin_dir = ${plugin_dir} . ($ENV{PLUGIN_VARIANT} // q{});
if (($want_syslog == 1)) {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        my_which('logger');
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
if (($? != 0)) {
        log_error("--syslog requested, but no 'logger' program found.  Please ensure that 'logger' is in your PATH, or do not specify the --syslog option to mysqld_safe.");
exit 1;
    }
}
if (($want_syslog == 1)) {
if ("$syslog_tag" ne q{}) {
        $syslog_tag = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_18 = q{};
            my $output_printed_18;
            my $pipeline_success_18 = 1;
            $output_18 .= $syslog_tag . "\n";
            if ( !($output_18 =~ m{\n\z}msx) ) { $output_18 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_18 = 0; }
            my @sed_lines_18 = split /\n/msx, $output_18;
            my @sed_result_18;
            foreach my $line (@sed_lines_18) {
            chomp $line;
            push @sed_result_18, $line;
            }
            $output_18 = join "\n", @sed_result_18;

            if ( !$pipeline_success_18 ) { $main_exit_code = 1; }
            $output_18 =~ s/\n+\z//msx;
            $output_18;
}; $_pipeline_result; };
        $syslog_tag_mysqld_safe = ${syslog_tag_mysqld_safe} . "-$syslog_tag";
        $syslog_tag_mysqld = ${syslog_tag_mysqld} . "-$syslog_tag";
    }
    log_notice("Logging to syslog.");
    $logging = 'syslog';
}
if (("$err_log" ne q{} || ($want_syslog == 0))) {
if ("$err_log" ne q{}) {
if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('expr', "$err_log", q{:}, ".*\\.[^/]*$") >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
            $main_exit_code = system('bash', ':') >> 8;
}
        else {
            $err_log = "$err_log";
            $main_exit_code = system('bash', '.err') >> 8;
        }
        $err_log_append = "$err_log";
if ("$err_log" =~ /^/.*$/msx) {
        } elsif ("$err_log" =~ /^./.*$/msx or "$err_log" =~ /^../.*$/msx) {
                        $log_dir_name = (do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname("$err_log"); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; });
            if ((!-d "$log_dir_name")) {
                log_notice("Directory ", $log_dir_name, " does not exists.");
                $err_log = $DATADIR;
                $main_exit_code = system('/', do { my ($in_19, $out_19); my $pid_19 = open3($in_19, $out_19, '>&STDERR', 'hostname'); close $in_19 or croak 'Close failed: $OS_ERROR'; my $result_19 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_19> }; close $out_19 or croak 'Close failed: $OS_ERROR'; waitpid $pid_19, 0; $result_19 }, '.err') >> 8;
}
            else {
                if (((!-x "$log_dir_name") || (!-w "$log_dir_name"))) {
                    log_notice("Do not have Execute or Write permissions on directory ", $log_dir_name, ".");
                    $err_log = $DATADIR;
                    $main_exit_code = system('/', do { my ($in_20, $out_20); my $pid_20 = open3($in_20, $out_20, '>&STDERR', 'hostname'); close $in_20 or croak 'Close failed: $OS_ERROR'; my $result_20 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> }; close $out_20 or croak 'Close failed: $OS_ERROR'; waitpid $pid_20, 0; $result_20 }, '.err') >> 8;
}
                else {
                    $err_log = do {
    my $left_result_21 = do { chdir($log_dir_name); q{} };
;
    if ( $CHILD_ERROR == 0 ) {
        my $right_result_21 = do { use Cwd; getcwd(); };
        $left_result_21 . $right_result_21;
    } else {
        q{};
    }
};
                    $main_exit_code = system('/', do { use File::Basename qw(basename); my $basename_output = basename("$err_log"); $CHILD_ERROR = 0; $basename_output; }) >> 8;
                }
            }
        } elsif (1) {
                        $err_log = "$DATADIR/$err_log";
        }
}
    else {
        $err_log = $DATADIR;
        $main_exit_code = system('/', do { my ($in_22, $out_22); my $pid_22 = open3($in_22, $out_22, '>&STDERR', 'hostname'); close $in_22 or croak 'Close failed: $OS_ERROR'; my $result_22 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_22> }; close $out_22 or croak 'Close failed: $OS_ERROR'; waitpid $pid_22, 0; $result_22 }, '.err') >> 8;
        $err_log_append = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); $__node . "\n"; };
        $main_exit_code = system('bash', '.err') >> 8;
    }
    append_arg_to_args("--log-error=$err_log_append");
if (($want_syslog == 1)) {
        $logging = 'both';
}
    else {
        $logging = 'file';
    }
}
my $logdir;
my @logdir;
my %logdir;
$logdir = do { use File::Basename qw(dirname); my $dirname_output = dirname("$err_log"); $CHILD_ERROR = 0; $dirname_output; };
if (($logging eq "file" || $logging eq "both")) {
if (((!-e "$err_log") && (! -h "$err_log"))) {
if (((-w '/') || StringInterpolation(StringInterpolation { parts: [Variable("USER")] }, None) eq StringInterpolation(StringInterpolation { parts: [Literal("root")] }, None))) {
if ($logdir =~ /^/var/log$/msx) {
                                do {
                    local %ENV = %ENV;
                    my $KILL_MYSQLD = $KILL_MYSQLD;
                    my $err_log_append = $err_log_append;
                    my $syslog_facility = $syslog_facility;
                    my $niceness = $niceness;
                    my $MY_PWD = $MY_PWD;
                    my $mysqld_ld_preload = $mysqld_ld_preload;
                    my $args = $args;
                    my $defaults = $defaults;
                    my $syslog_tag_mysqld_safe = $syslog_tag_mysqld_safe;
                    my $MYSQL_HOME = $MYSQL_HOME;
                    my $SET_USER = $SET_USER;
                    my $print_defaults = $print_defaults;
                    my $DATADIR = $DATADIR;
                    my $timestamp_format = $timestamp_format;
                    my $oldpwd = $oldpwd;
                    my $ledir = $ledir;
                    my $pid_file_append = $pid_file_append;
                    my $MYSQLD = $MYSQLD;
                    my $mysqld_ld_library_path = $mysqld_ld_library_path;
                    my $logdir = $logdir;
                    my $syslog_tag_mysqld = $syslog_tag_mysqld;
                    my $realpath = $realpath;
                    my $DATE = $DATE;
                        $main_exit_code = system('umask', '0137') >> 8;
                        if (do {
                                                        do {
                                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                                open STDOUT, '>', "$err_log"
      or die "Cannot open file: $OS_ERROR\n";
# set -o noclobber not implemented
# set noclobber not implemented
                                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                            };
                        } == 0) {
                            do {
    my ($owner, $group) = split /:/, $user, 2;
    my $uid = getpwnam($owner);
    my $gid = defined($group) ? getgrnam($group) : -1;
    chown $uid, $gid, ("$err_log") or warn "chown failed: $OS_ERROR\n";
    $CHILD_ERROR = 0;
};
                        }
                    q{};
                };
            } elsif (1) {
            }
}
        else {
            do {
                local %ENV = %ENV;
                my $KILL_MYSQLD = $KILL_MYSQLD;
                my $err_log_append = $err_log_append;
                my $syslog_facility = $syslog_facility;
                my $niceness = $niceness;
                my $MY_PWD = $MY_PWD;
                my $mysqld_ld_preload = $mysqld_ld_preload;
                my $args = $args;
                my $defaults = $defaults;
                my $syslog_tag_mysqld_safe = $syslog_tag_mysqld_safe;
                my $MYSQL_HOME = $MYSQL_HOME;
                my $SET_USER = $SET_USER;
                my $print_defaults = $print_defaults;
                my $DATADIR = $DATADIR;
                my $timestamp_format = $timestamp_format;
                my $oldpwd = $oldpwd;
                my $ledir = $ledir;
                my $pid_file_append = $pid_file_append;
                my $MYSQLD = $MYSQLD;
                my $mysqld_ld_library_path = $mysqld_ld_library_path;
                my $logdir = $logdir;
                my $syslog_tag_mysqld = $syslog_tag_mysqld;
                my $realpath = $realpath;
                my $DATE = $DATE;
                    $main_exit_code = system('umask', '0137') >> 8;
                    do {
                        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>', "$err_log"
      or die "Cannot open file: $OS_ERROR\n";
# set -o noclobber not implemented
# set noclobber not implemented
                        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                    };
                q{};
            };
        }
    }
if (((-f "$err_log") || (-p "$err_log"))) {
        log_notice("Logging to '$err_log'.");
}
    else {
        if ("x$user" eq "xroot") {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "Logging to '$err_log'.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
            };
}
        else {
if ($logdir =~ /^/tmp$/msx or $logdir =~ /^/var/tmp$/msx or $logdir =~ /^/var/log/mysql$/msx or $logdir =~ /^$DATADIR$/msx) {
                                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    do {
    my $__echo_line = "Logging to '$err_log'.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                };
            } elsif (1) {
                                log_error("error: log-error set to '$err_log', however file don't exists. Create writable for user '$user'.");
                exit 1;
            }
        }
    }
}
my $USER_OPTION;
my @USER_OPTION;
my %USER_OPTION;
$USER_OPTION = "";
if (((-w '/') || StringInterpolation(StringInterpolation { parts: [Variable("USER")] }, None) eq StringInterpolation(StringInterpolation { parts: [Literal("root")] }, None))) {
if (((!StringInterpolation(StringInterpolation { parts: [Variable("user")] }, None) eq StringInterpolation(StringInterpolation { parts: [Literal("root")] }, None)) || Variable("SET_USER", false, None) eq 1)) {
        $USER_OPTION = "--user=$user";
    }
if (StringInterpolation(StringInterpolation { parts: [Variable("open_files")] }, None) ne q{}) {
        $main_exit_code = system('ulimit', '-n', $open_files) >> 8;
    }
}
if (StringInterpolation(StringInterpolation { parts: [Variable("open_files")] }, None) ne q{}) {
    append_arg_to_args("--open-files-limit=$ENV{open_files}");
}
$safe_mysql_unix_port = (defined ($ENV{mysql_unix_port} // q{}) && ($ENV{mysql_unix_port} // q{}) ne q{} ? ($ENV{mysql_unix_port} // q{}) : (defined ($ENV{MYSQL_UNIX_PORT} // q{}) && ($ENV{MYSQL_UNIX_PORT} // q{}) ne q{} ? ($ENV{MYSQL_UNIX_PORT} // q{}) : '/var/run/mysqld/mysqld.sock'));
$mysql_unix_port_dir = do { use File::Basename qw(dirname); my $dirname_output = dirname($safe_mysql_unix_port); $CHILD_ERROR = 0; $dirname_output; };
if ((!-d $mysql_unix_port_dir)) {
    log_error("Directory '$mysql_unix_port_dir' for UNIX socket file don't exists.");
exit 1;
}
if (StringInterpolation(StringInterpolation { parts: [Variable("MYSQLD")] }, None) eq q{}) {
    $MYSQLD = 'mysqld';
}
if ((-x '! StringInterpolation(StringInterpolation { parts: [Variable("ledir"), Literal("/"), Variable("MYSQLD")] }, None)')) {
    log_error("The file $ledir/$MYSQLD
does not exist or is not executable. Please cd to the mysql installation
directory and restart this script from there as follows:
./bin/mysqld_safe&
See http://dev.mysql.com/doc/mysql/en/mysqld-safe.html for more information");
exit 1;
}
if (StringInterpolation(StringInterpolation { parts: [Variable("pid_file")] }, None) eq q{}) {
    $pid_file = "$DATADIR/" . (do { my $_chomp_temp = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); $__node . "\n"; }; chomp $_chomp_temp; $_chomp_temp; }) . ".pid";
    $pid_file_append = (do { my $_chomp_temp = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); $__node . "\n"; }; chomp $_chomp_temp; $_chomp_temp; }) . ".pid";
}
else {
    $pid_file_append = "$pid_file";
if ("$pid_file" =~ /^/.*$/msx) {
    } elsif (1) {
                $pid_file = "$DATADIR/$pid_file";
    }
}
append_arg_to_args("--pid-file=$pid_file_append");
if (StringInterpolation(StringInterpolation { parts: [Variable("mysql_unix_port")] }, None) ne q{}) {
    append_arg_to_args("--socket=$ENV{mysql_unix_port}");
}
if (StringInterpolation(StringInterpolation { parts: [Variable("mysql_tcp_port")] }, None) ne q{}) {
    append_arg_to_args("--port=$ENV{mysql_tcp_port}");
}
if ((Variable("niceness", false, None) == 0)) {
    my $NOHUP_NICENESS;
    my @NOHUP_NICENESS;
    my %NOHUP_NICENESS;
    $NOHUP_NICENESS = "nohup";
}
else {
    $NOHUP_NICENESS = "nohup nice -$niceness";
}
if (!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
use POSIX qw(setsid);
use POSIX qw(dup2);
use POSIX qw(open);
my $nohup_out = 'nohup.out';
if (!defined $ENV{NOHUP_OUT}) {
$ENV{NOHUP_OUT} = $nohup_out;
}
my $pid = fork();
if ($pid == 0) {
setsid();
if (open my $fh, '>', $ENV{NOHUP_OUT}) {
dup2(fileno($fh), STDOUT->fileno());
dup2(fileno($fh), STDERR->fileno());
close $fh or croak "Close failed: $ERRNO";
}
exec('nice');
exit 1;
} elsif ($pid > 0) {
print "nohup: ignoring input and appending output to '$ENV{NOHUP_OUT}'\n";
print "nohup: process $pid started\n";
} else {
die "nohup: fork failed\n";
}
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
})) {
    my $normal_niceness;
    my @normal_niceness;
    my %normal_niceness;
    $normal_niceness = do { my @_qx_cmd = ('nice'); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
    my $nohup_niceness;
    my @nohup_niceness;
    my %nohup_niceness;
    $nohup_niceness = do { my @_qx_cmd = ("nohup nice 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
    my $numeric_nice_values;
    my @numeric_nice_values;
    my %numeric_nice_values;
    $numeric_nice_values = q{1};
    my $val;
    for my $val ($normal_niceness, $nohup_niceness) {
if ("$val" =~ /^-\[0-9\]$/msx or "$val" =~ /^-\[0-9\]\[0-9\]$/msx or "$val" =~ /^-\[0-9\]\[0-9\]\[0-9\]$/msx or "$val" =~ /^\[0-9\]$/msx or "$val" =~ /^\[0-9\]\[0-9\]$/msx or "$val" =~ /^\[0-9\]\[0-9\]\[0-9\]$/msx) {
        } elsif (1) {
                        $numeric_nice_values = q{0};
        }
    }
if ((Variable("numeric_nice_values", false, None) == 1)) {
        my $nice_value_diff;
        my @nice_value_diff;
        my %nice_value_diff;
        $nice_value_diff = do {
    my ($in_25, $out_25);
    my $pid_25 = open3($in_25, $out_25, '>&STDERR', 'expr', $nohup_niceness, q{-}, $normal_niceness);
    close $in_25 or croak 'Close failed: $OS_ERROR';
    my $result_25 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_25> };
    close $out_25 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_25, 0;
    $result_25
};
if (((!(        $main_exit_code = system('test', $?, '-eq', q{0}) >> 8) && !(        $main_exit_code = system('test', $nice_value_diff, '-gt', q{0}) >> 8)) && !(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
use POSIX qw(setpriority PRIO_PROCESS);
my $nice_value = 10;
my $pid = getpid();
my $old_priority = getpriority(PRIO_PROCESS, $pid);
setpriority(PRIO_PROCESS, $pid, $old_priority + $nice_value);
print "Running command with nice value: $nice_value\n";
system $nice_value_diff, @args;
setpriority(PRIO_PROCESS, $pid, $old_priority);
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        }))) {
            $niceness = do {
    my ($in_27, $out_27);
    my $pid_27 = open3($in_27, $out_27, '>&STDERR', 'expr', $niceness, q{-}, $nice_value_diff);
    close $in_27 or croak 'Close failed: $OS_ERROR';
    my $result_27 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_27> };
    close $out_27 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_27, 0;
    $result_27
};
            $NOHUP_NICENESS = "nice -$niceness nohup";
        }
    }
}
else {
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
use POSIX qw(setsid);
use POSIX qw(dup2);
use POSIX qw(open);
my $nohup_out = 'nohup.out';
if (!defined $ENV{NOHUP_OUT}) {
$ENV{NOHUP_OUT} = $nohup_out;
}
my $pid = fork();
if ($pid == 0) {
setsid();
if (open my $fh, '>', $ENV{NOHUP_OUT}) {
dup2(fileno($fh), STDOUT->fileno());
dup2(fileno($fh), STDERR->fileno());
close $fh or croak "Close failed: $ERRNO";
}
exec('echo', @args);
exit 1;
} elsif ($pid > 0) {
print "nohup: ignoring input and appending output to '$ENV{NOHUP_OUT}'\n";
print "nohup: process $pid started\n";
} else {
die "nohup: fork failed\n";
}
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
        $main_exit_code = system('bash', ':') >> 8;
}
    else {
        $NOHUP_NICENESS = "";
    }
}
if (StringInterpolation(StringInterpolation { parts: [Variable("core_file_size")] }, None) ne q{}) {
    $main_exit_code = system('ulimit', '-c', $core_file_size) >> 8;
}
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("pid_file")] }, None)')) {
    my $PID;
    my @PID;
    my %PID;
    $PID = do { my $cat_chunk = q{}; if ( open my $fh, '<', "$pid_file" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$pid_file" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $signal = '0';
my @pids = ($PID);
foreach my $pid (@pids) {
if ($pid =~ /^\\d+$/msx) {
my $result = kill $signal, $pid;
if ($result) {
print "Sent signal $signal to process $pid\n";
} else {
print {*STDERR} "kill: ($pid) - No such process\n";
}
} else {
print {*STDERR} "kill: invalid process id: $pid\n";
}
}
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
if (!(        # Original bash: ps wwwp $PID | grep -v mysqld_safe | grep -- $MYSQLD > /dev/null
{
            my $output_30 = q{};
            my $output_printed_30;
            my $pipeline_success_30 = 1;
                        my ($in_31, $out_31);
            my $pid_31 = open3($in_31, $out_31, '>&STDERR', 'ps', 'wwwp');
            close $in_31 or croak 'Close failed: $OS_ERROR';
            $output_30 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_31> };
            close $out_31 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_31, 0;

                        my $grep_result_30_1;
            my @grep_lines_30_1 = split /\n/msx, $output_30;
            my @grep_filtered_30_1 = grep { !/mysqld_safe/msx } @grep_lines_30_1;
            $grep_result_30_1 = join "\n", @grep_filtered_30_1;
            if (!($grep_result_30_1 =~ m{\n\z}msx || $grep_result_30_1 eq q{})) {
            $grep_result_30_1 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_30_1 > 0 ? 0 : 1;
            $output_30 = $grep_result_30_1;
            $output_30 = $grep_result_30_1;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_32 = q{};
            my $grep_result_33;
            my @grep_lines_33 = split /\n/msx, $output_30;
            my @grep_filtered_33 = grep { /$MYSQLD/msx } @grep_lines_33;
            $grep_result_33 = join "\n", @grep_filtered_33;
            if (!($grep_result_33 =~ m{\n\z}msx || $grep_result_33 eq q{})) {
            $grep_result_33 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_33 > 0 ? 0 : 1;
            $tmp_redirect_32 = $grep_result_33;
            $tmp_redirect_32;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_30; }
            $output_printed_30 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_30 ) { $main_exit_code = 1; }
            })) {
            log_error("A mysqld process already exists");
exit 1;
        }
    }
if ((! -h "$pid_file")) {
if ( -e "$pid_file" ) {
            if ( -d "$pid_file" ) {
                carp "rm: carping: ", "$pid_file",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$pid_file" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$pid_file",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("pid_file")] }, None)')) {
            log_error("Fatal error: Can't remove the pid file:
$pid_file.
Please remove the file manually and start $PROGRAM_NAME again;
mysqld daemon not started");
exit 1;
        }
    }
if ((! -h "$safe_mysql_unix_port")) {
if ( -e "$safe_mysql_unix_port" ) {
            if ( -d "$safe_mysql_unix_port" ) {
                carp "rm: carping: ", "$safe_mysql_unix_port",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$safe_mysql_unix_port" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$safe_mysql_unix_port",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("safe_mysql_unix_port")] }, None)')) {
            log_error("Fatal error: Can't remove the socket file:
$safe_mysql_unix_port.
Please remove the file manually and start $PROGRAM_NAME again;
mysqld daemon not started");
exit 1;
        }
    }
if ((! -h "$pid_file.shutdown")) {
if ( -e "$pid_file.shutdown" ) {
            if ( -d "$pid_file.shutdown" ) {
                carp "rm: carping: ", "$pid_file.shutdown",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$pid_file.shutdown" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$pid_file.shutdown",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("pid_file"), Literal(".shutdown")] }, None)')) {
            log_error("Fatal error: Can't remove the shutdown file:
$pid_file.shutdown.
Please remove the file manually and start $PROGRAM_NAME again;
mysqld daemon not started");
exit 1;
        }
    }
}
my $cmd;
my @cmd;
my %cmd;
$cmd = (do { my $_chomp_temp = do {
    my ($in_34, $out_34);
    my $pid_34 = open3($in_34, $out_34, '>&STDERR', 'mysqld_ld_preload_text');
    close $in_34 or croak 'Close failed: $OS_ERROR';
    my $result_34 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_34> };
    close $out_34 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_34, 0;
    $result_34
}; chomp $_chomp_temp; $_chomp_temp; }) . "$NOHUP_NICENESS";
my $i;
for my $i ("$ledir/$MYSQLD", "$defaults", "--basedir=$MY_BASEDIR_VERSION", "--datadir=$DATADIR", "--plugin-dir=$plugin_dir", "$USER_OPTION") {
    $cmd = "$cmd ";
    $CHILD_ERROR = 0;
}
$cmd = "$cmd $args";
if (do {
$main_exit_code = system('test', '-n', "$NOHUP_NICENESS") >> 8;
    $CHILD_ERROR == 0
}) {
        $cmd = "$cmd < /dev/null";
}
log_notice("Starting $MYSQLD daemon with databases from $DATADIR");
my $fast_restart;
my @fast_restart;
my %fast_restart;
$fast_restart = q{0};
my $max_fast_restarts;
my @max_fast_restarts;
my %max_fast_restarts;
$max_fast_restarts = q{5};
my $have_sleep;
my @have_sleep;
my %have_sleep;
$have_sleep = q{1};
while ( 1 ) {
    my $start_time;
    my @start_time;
    my %start_time;
    $start_time = do {
require POSIX; POSIX::strftime('%M%S', localtime(time())) . "\n"
};
    eval_log_error("$cmd");
if (($? == $MAGIC_16)) {
        my $dont_restart_mysqld;
        my @dont_restart_mysqld;
        my %dont_restart_mysqld;
        $dont_restart_mysqld = 'false';
        print "Restarting mysqld...\n";
}
    else {
        $dont_restart_mysqld = 'true';
    }
if (0) {
if (((-w '/') || StringInterpolation(StringInterpolation { parts: [Variable("USER")] }, None) eq StringInterpolation(StringInterpolation { parts: [Literal("root")] }, None))) {
            $logdir = do { use File::Basename qw(dirname); my $dirname_output = dirname("$err_log"); $CHILD_ERROR = 0; $dirname_output; };
if ($logdir =~ /^/var/log$/msx) {
                                do {
                    local %ENV = %ENV;
                    my $KILL_MYSQLD = $KILL_MYSQLD;
                    my $err_log_append = $err_log_append;
                    my $syslog_facility = $syslog_facility;
                    my $niceness = $niceness;
                    my $MY_PWD = $MY_PWD;
                    my $nohup_niceness = $nohup_niceness;
                    my $mysqld_ld_preload = $mysqld_ld_preload;
                    my $args = $args;
                    my $defaults = $defaults;
                    my $val = $val;
                    my $syslog_tag_mysqld_safe = $syslog_tag_mysqld_safe;
                    my $MYSQL_HOME = $MYSQL_HOME;
                    my $SET_USER = $SET_USER;
                    my $fast_restart = $fast_restart;
                    my $print_defaults = $print_defaults;
                    my $nice_value_diff = $nice_value_diff;
                    my $PID = $PID;
                    my $DATADIR = $DATADIR;
                    my $USER_OPTION = $USER_OPTION;
                    my $timestamp_format = $timestamp_format;
                    my $oldpwd = $oldpwd;
                    my $ledir = $ledir;
                    my $pid_file_append = $pid_file_append;
                    my $normal_niceness = $normal_niceness;
                    my $cmd = $cmd;
                    my $i = $i;
                    my $numeric_nice_values = $numeric_nice_values;
                    my $MYSQLD = $MYSQLD;
                    my $mysqld_ld_library_path = $mysqld_ld_library_path;
                    my $start_time = $start_time;
                    my $dont_restart_mysqld = $dont_restart_mysqld;
                    my $logdir = $logdir;
                    my $syslog_tag_mysqld = $syslog_tag_mysqld;
                    my $realpath = $realpath;
                    my $DATE = $DATE;
                    my $NOHUP_NICENESS = $NOHUP_NICENESS;
                    my $have_sleep = $have_sleep;
                    my $max_fast_restarts = $max_fast_restarts;
                        $main_exit_code = system('umask', '0137') >> 8;
                        if (do {
                                                        do {
                                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                                open STDOUT, '>', "$err_log"
      or die "Cannot open file: $OS_ERROR\n";
# set -o noclobber not implemented
# set noclobber not implemented
                                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                            };
                        } == 0) {
                            do {
    my ($owner, $group) = split /:/, $user, 2;
    my $uid = getpwnam($owner);
    my $gid = defined($group) ? getgrnam($group) : -1;
    chown $uid, $gid, ("$err_log") or warn "chown failed: $OS_ERROR\n";
    $CHILD_ERROR = 0;
};
                        }
                    q{};
                };
            } elsif (1) {
            }
}
        else {
            do {
                local %ENV = %ENV;
                my $KILL_MYSQLD = $KILL_MYSQLD;
                my $err_log_append = $err_log_append;
                my $syslog_facility = $syslog_facility;
                my $niceness = $niceness;
                my $MY_PWD = $MY_PWD;
                my $nohup_niceness = $nohup_niceness;
                my $mysqld_ld_preload = $mysqld_ld_preload;
                my $args = $args;
                my $defaults = $defaults;
                my $val = $val;
                my $syslog_tag_mysqld_safe = $syslog_tag_mysqld_safe;
                my $MYSQL_HOME = $MYSQL_HOME;
                my $SET_USER = $SET_USER;
                my $fast_restart = $fast_restart;
                my $print_defaults = $print_defaults;
                my $nice_value_diff = $nice_value_diff;
                my $PID = $PID;
                my $DATADIR = $DATADIR;
                my $USER_OPTION = $USER_OPTION;
                my $timestamp_format = $timestamp_format;
                my $oldpwd = $oldpwd;
                my $ledir = $ledir;
                my $pid_file_append = $pid_file_append;
                my $normal_niceness = $normal_niceness;
                my $cmd = $cmd;
                my $i = $i;
                my $numeric_nice_values = $numeric_nice_values;
                my $MYSQLD = $MYSQLD;
                my $mysqld_ld_library_path = $mysqld_ld_library_path;
                my $start_time = $start_time;
                my $dont_restart_mysqld = $dont_restart_mysqld;
                my $logdir = $logdir;
                my $syslog_tag_mysqld = $syslog_tag_mysqld;
                my $realpath = $realpath;
                my $DATE = $DATE;
                my $NOHUP_NICENESS = $NOHUP_NICENESS;
                my $have_sleep = $have_sleep;
                my $max_fast_restarts = $max_fast_restarts;
                    $main_exit_code = system('umask', '0137') >> 8;
                    do {
                        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>', "$err_log"
      or die "Cannot open file: $OS_ERROR\n";
# set -o noclobber not implemented
# set noclobber not implemented
                        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                    };
                q{};
            };
        }
    }
    my $end_time;
    my @end_time;
    my %end_time;
    $end_time = do {
require POSIX; POSIX::strftime('%M%S', localtime(time())) . "\n"
};
if (!(    $CHILD_ERROR = 0)) {
if ((-f '! StringInterpolation(StringInterpolation { parts: [Variable("pid_file")] }, None)')) {
last;
}
        else {
            $PID = do { my $cat_chunk = q{}; if ( open my $fh, '<', "$pid_file" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$pid_file" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
if (!(            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $signal = '0';
my @pids = ($PID);
foreach my $pid (@pids) {
if ($pid =~ /^\\d+$/msx) {
my $result = kill $signal, $pid;
if ($result) {
print "Sent signal $signal to process $pid\n";
} else {
print {*STDERR} "kill: ($pid) - No such process\n";
}
} else {
print {*STDERR} "kill: invalid process id: $pid\n";
}
}
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            })) {
                log_error("A mysqld process with pid=$PID is already running. Aborting!!");
exit 1;
            }
        }
    }
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("pid_file"), Literal(".shutdown")] }, None)')) {
        log_notice("$pid_file.shutdown present. The server will not restart.");
last;
    }
if (((Variable("end_time", false, None) > 0) && (Variable("have_sleep", false, None) > 0))) {
if ((Variable("end_time", false, None) == Variable("start_time", false, None))) {
            $fast_restart = do {
    my ($in_38, $out_38);
    my $pid_38 = open3($in_38, $out_38, '>&STDERR', 'expr', $fast_restart, q{+}, q{1});
    close $in_38 or croak 'Close failed: $OS_ERROR';
    my $result_38 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_38> };
    close $out_38 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_38, 0;
    $result_38
};
if ((Variable("fast_restart", false, None) >= Variable("max_fast_restarts", false, None))) {
                log_notice("The server is respawning too fast. Sleeping for 1 second.");
require Time::HiRes; Time::HiRes::sleep(q{1});
                my $sleep_state;
                my @sleep_state;
                my %sleep_state;
                $sleep_state = $?;
if ((Variable("sleep_state", false, None) > 0)) {
                    log_notice("The server is respawning too fast and in addition no working 'sleep' command was found. Turning off throttling.");
                    $have_sleep = q{0};
                }
                $fast_restart = q{0};
            }
}
        else {
            $fast_restart = q{0};
        }
    }
if ((!(1) && !(    $main_exit_code = system('test', $KILL_MYSQLD, '-eq', q{1}) >> 8))) {
        my $numofproces;
        my @numofproces;
        my %numofproces;
        $numofproces = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_41 = q{};
            my $output_printed_41;
            my $pipeline_success_41 = 1;

            my ($in_42, $out_42);
            my $pid_42 = open3($in_42, $out_42, '>&STDERR', 'ps', 'xaww');
            close $in_42 or croak 'Close failed: $OS_ERROR';
            $output_41 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_42> };
            close $out_42 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_42, 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_41 = 0; }
            my $grep_result_41_1;
            my @grep_lines_41_1 = split /\n/msx, $output_41;
            my @grep_filtered_41_1 = grep { !/grep/msx } @grep_lines_41_1;
            $grep_result_41_1 = join "\n", @grep_filtered_41_1;
                        if (!($grep_result_41_1 =~ m{\n\z}msx || $grep_result_41_1 eq q{})) {
                            $grep_result_41_1 .= "\n";
                        }
            $CHILD_ERROR = scalar @grep_filtered_41_1 > 0 ? 0 : 1;
            $output_41 = $grep_result_41_1;
            my $grep_result_41_2;
            my @grep_lines_41_2 = split /\n/msx, $output_41;
            my @grep_filtered_41_2 = grep { /$ledir\/$MYSQLD\>/msx } @grep_lines_41_2;
            $grep_result_41_2 = join "\n", @grep_filtered_41_2;
                        if (!($grep_result_41_2 =~ m{\n\z}msx || $grep_result_41_2 eq q{})) {
                            $grep_result_41_2 .= "\n";
                        }
            $CHILD_ERROR = scalar @grep_filtered_41_2 > 0 ? 0 : 1;
            $output_41 = $grep_result_41_2;
            my $grep_result_41_3;
            my @grep_lines_41_3 = split /\n/msx, $output_41;
            my @grep_filtered_41_3 = grep { /pid-file=$pid_file/msx } @grep_lines_41_3;
            $grep_result_41_3 = scalar @grep_filtered_41_3 . "\n";
            $CHILD_ERROR = scalar @grep_filtered_41_3 > 0 ? 0 : 1;
            $output_41 = $grep_result_41_3;
            if ((scalar @grep_filtered_41_3) == 0) {
                $pipeline_success_41 = 0;
            }
            if ( !$pipeline_success_41 ) { $main_exit_code = 1; }
            $output_41 =~ s/\n+\z//msx;
            $output_41;
}; $_pipeline_result; };
        log_notice("Number of processes running now: $numofproces");
        my $I;
        my @I;
        my %I;
        $I = q{1};
while ( (StringInterpolation(StringInterpolation { parts: [Variable("I")] }, None) <= StringInterpolation(StringInterpolation { parts: [Variable("numofproces")] }, None)) ) {
            my $PROC;
            my @PROC;
            my %PROC;
            $PROC = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_43 = q{};
                my $output_printed_43;
                my $pipeline_success_43 = 1;

                my ($in_44, $out_44);
                my $pid_44 = open3($in_44, $out_44, '>&STDERR', 'ps', 'xaww');
                close $in_44 or croak 'Close failed: $OS_ERROR';
                $output_43 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_44> };
                close $out_44 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_44, 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_43 = 0; }
                my $grep_result_43_1;
                my @grep_lines_43_1 = split /\n/msx, $output_43;
                my @grep_filtered_43_1 = grep { /$ledir\/$MYSQLD\>/msx } @grep_lines_43_1;
                $grep_result_43_1 = join "\n", @grep_filtered_43_1;
                                if (!($grep_result_43_1 =~ m{\n\z}msx || $grep_result_43_1 eq q{})) {
                                    $grep_result_43_1 .= "\n";
                                }
                $CHILD_ERROR = scalar @grep_filtered_43_1 > 0 ? 0 : 1;
                $output_43 = $grep_result_43_1;
                my $grep_result_43_2;
                my @grep_lines_43_2 = split /\n/msx, $output_43;
                my @grep_filtered_43_2 = grep { !/grep/msx } @grep_lines_43_2;
                $grep_result_43_2 = join "\n", @grep_filtered_43_2;
                                if (!($grep_result_43_2 =~ m{\n\z}msx || $grep_result_43_2 eq q{})) {
                                    $grep_result_43_2 .= "\n";
                                }
                $CHILD_ERROR = scalar @grep_filtered_43_2 > 0 ? 0 : 1;
                $output_43 = $grep_result_43_2;
                my $grep_result_43_3;
                my @grep_lines_43_3 = split /\n/msx, $output_43;
                my @grep_filtered_43_3 = grep { /pid-file=$pid_file/msx } @grep_lines_43_3;
                $grep_result_43_3 = join "\n", @grep_filtered_43_3;
                                if (!($grep_result_43_3 =~ m{\n\z}msx || $grep_result_43_3 eq q{})) {
                                    $grep_result_43_3 .= "\n";
                                }
                $CHILD_ERROR = scalar @grep_filtered_43_3 > 0 ? 0 : 1;
                $output_43 = $grep_result_43_3;
                my @sed_lines_43 = split /\n/msx, $output_43;
                my @sed_result_43;
                foreach my $line (@sed_lines_43) {
                chomp $line;
                push @sed_result_43, $line;
                }
                $output_43 = join "\n", @sed_result_43;

                if ( !$pipeline_success_43 ) { $main_exit_code = 1; }
                $output_43 =~ s/\n+\z//msx;
                $output_43;
}; $_pipeline_result; };
            my $T;
            for my $T ($PROC) {
last;
            }
if (!(my $signal = '9';
my @pids = ($T);
foreach my $pid (@pids) {
if ($pid =~ /^\\d+$/msx) {
my $result = kill $signal, $pid;
if ($result) {
print "Sent signal $signal to process $pid\n";
} else {
print {*STDERR} "kill: ($pid) - No such process\n";
}
} else {
print {*STDERR} "kill: invalid process id: $pid\n";
}
})) {
                log_error("$MYSQLD process hanging, pid $T - killed");
}
            else {
last;
            }
            $I = do {
    my ($in_46, $out_46);
    my $pid_46 = open3($in_46, $out_46, '>&STDERR', 'expr', $I, q{+}, q{1});
    close $in_46 or croak 'Close failed: $OS_ERROR';
    my $result_46 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_46> };
    close $out_46 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_46, 0;
    $result_46
};
        }
    }
if ((! -h "$pid_file")) {
if ( -e "$pid_file" ) {
            if ( -d "$pid_file" ) {
                carp "rm: carping: ", "$pid_file",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$pid_file" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$pid_file",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
if ((! -h "$safe_mysql_unix_port")) {
if ( -e "$safe_mysql_unix_port" ) {
            if ( -d "$safe_mysql_unix_port" ) {
                carp "rm: carping: ", "$safe_mysql_unix_port",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$safe_mysql_unix_port" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$safe_mysql_unix_port",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
if ((! -h "$pid_file.shutdown")) {
if ( -e "$pid_file.shutdown" ) {
            if ( -d "$pid_file.shutdown" ) {
                carp "rm: carping: ", "$pid_file.shutdown",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$pid_file.shutdown" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$pid_file.shutdown",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
    log_notice("mysqld restarted");
}
if ((! -h "$pid_file.shutdown")) {
if ( -e "$pid_file.shutdown" ) {
        if ( -d "$pid_file.shutdown" ) {
            carp "rm: carping: ", "$pid_file.shutdown",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$pid_file.shutdown" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$pid_file.shutdown",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
}
log_notice("mysqld from pid file $pid_file ended");
if ((! -h "$safe_pid")) {
if ( -e "$safe_pid" ) {
        if ( -d "$safe_pid" ) {
            carp "rm: carping: ", "$safe_pid",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$safe_pid" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$safe_pid",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
}

exit $main_exit_code;
