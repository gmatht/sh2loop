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

my $opt_force_conffold;
my @opt_force_conffold;
my %opt_force_conffold;
my $conf_force_conffold;
my @conf_force_conffold;
my %conf_force_conffold;
my $old_mdsum_dir;
my @old_mdsum_dir;
my %old_mdsum_dir;
my $override_template;
my @override_template;
my %override_template;
my $choices2;
my @choices2;
my %choices2;
my $DISPLAY;
my @DISPLAY;
my %DISPLAY;
my $PURGE;
my @PURGE;
my %PURGE;
my $destsum;
my @destsum;
my %destsum;
my $force_conffmiss;
my @force_conffmiss;
my %force_conffmiss;
my $oldsum;
my @oldsum;
my %oldsum;
my $conf_force_conffmiss;
my @conf_force_conffmiss;
my %conf_force_conffmiss;
my $DEBCONF_OK;
my @DEBCONF_OK;
my %DEBCONF_OK;
my $choices;
my @choices;
my %choices;
my $UCF_FORCE_CONFFOLD;
my @UCF_FORCE_CONFFOLD;
my %UCF_FORCE_CONFFOLD;
my $opt_source_dir;
my @opt_source_dir;
my %opt_source_dir;
my $UCF_SOURCE_DIR;
my @UCF_SOURCE_DIR;
my %UCF_SOURCE_DIR;
my $force_conffold;
my @force_conffold;
my %force_conffold;
my $new_file;
my @new_file;
my %new_file;
my $VERBOSE;
my @VERBOSE;
my %VERBOSE;
my $conf_state_dir;
my @conf_state_dir;
my %conf_state_dir;
my $docmd;
my @docmd;
my %docmd;
my $DEBIAN_HAS_FRONTEND;
my @DEBIAN_HAS_FRONTEND;
my %DEBIAN_HAS_FRONTEND;
my $UCF_FORCE_CONFFMISS;
my @UCF_FORCE_CONFFMISS;
my %UCF_FORCE_CONFFMISS;
my $do_replace_md5sum;
my @do_replace_md5sum;
my %do_replace_md5sum;
my $THREEWAY;
my @THREEWAY;
my %THREEWAY;
my $cached_file;
my @cached_file;
my %cached_file;
my $dest_file;
my @dest_file;
my %dest_file;
my $UCF_FORCE_CONFFNEW;
my @UCF_FORCE_CONFFNEW;
my %UCF_FORCE_CONFFNEW;
my $divert_line;
my @divert_line;
my %divert_line;
my $done;
my @done;
my %done;
my $temp_new_file;
my @temp_new_file;
my %temp_new_file;
my $conf_force_conffnew;
my @conf_force_conffnew;
my %conf_force_conffnew;
my $opt_force_conffnew;
my @opt_force_conffnew;
my %opt_force_conffnew;
my $opt_old_mdsum_file;
my @opt_old_mdsum_file;
my %opt_old_mdsum_file;
my $UCF_OLD_MDSUM_FILE;
my @UCF_OLD_MDSUM_FILE;
my %UCF_OLD_MDSUM_FILE;
my $opt_package;
my @opt_package;
my %opt_package;
my $temp_dest_file;
my @temp_dest_file;
my %temp_dest_file;
my $DEBUG;
my @DEBUG;
my %DEBUG;
my $PAGER;
my @PAGER;
my %PAGER;
my $lastsum;
my @lastsum;
my %lastsum;
my $old_mdsum_file;
my @old_mdsum_file;
my %old_mdsum_file;
my $opt_force_conffmiss;
my @opt_force_conffmiss;
my %opt_force_conffmiss;
my $conf_old_mdsum_file;
my @conf_old_mdsum_file;
my %conf_old_mdsum_file;
my $conf_source_dir;
my @conf_source_dir;
my %conf_source_dir;
my $divert_package;
my @divert_package;
my %divert_package;
my $DEBCONF_ALREADY_RUNNING;
my @DEBCONF_ALREADY_RUNNING;
my %DEBCONF_ALREADY_RUNNING;
my $opt_state_dir;
my @opt_state_dir;
my %opt_state_dir;
my $statedir;
my @statedir;
my %statedir;
my $newsum;
my @newsum;
my %newsum;
my $force_conffnew;
my @force_conffnew;
my %force_conffnew;
my $UCF_STATE_DIR;
my @UCF_STATE_DIR;
my %UCF_STATE_DIR;

my $MAGIC_99999 = 99_999;
my $MAGIC_3     = 3;

$__set_e = 1;
my $progname;
my @progname;
my %progname;
$progname = (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename($PROGRAM_NAME); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; });
my $pversion;
my @pversion;
my %pversion;
$pversion = 'Revision: 3.00 ';
delete $ENV{GREP_OPTIONS};

sub setq {
    my ($file) = @_;
if ("x$2" eq "x") {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "$progname: Unable to determine $_[2]";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
exit 1;
}
    else {
if ("x$VERBOSE" ne "x") {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "$progname: $_[2] is $_[1]";
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
do { my $eval_input = $1 . "=\"$2\""; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
    }
    return;
}

sub get_file_metadata {
    my ($file) = @_;
if ((-e "$1")) {
        my $moddate = (do { my $_chomp_temp = do {
require POSIX; POSIX::strftime('', localtime(time())) . "\n"
}; chomp $_chomp_temp; $_chomp_temp; });
        $main_exit_code = system('stat', '--format', "%n %U.%G 0%a $moddate", "$_[0]") >> 8;
}
    else {
        print "/dev/null\n";
    }
    return;
}

sub run_diff {
    my $diff_cmd = "$_[0]";
    my $diff_opt = "$_[1]";
    my $old_file = "$_[2]";
    my $new_file = "$_[3]";
    my $old_file_label = (do { my $_chomp_temp = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'get_file_metadata', "$old_file");
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
}; chomp $_chomp_temp; $_chomp_temp; });
    my $new_file_label = (do { my $_chomp_temp = do {
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'get_file_metadata', "$new_file");
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    $result_1
}; chomp $_chomp_temp; $_chomp_temp; });
    if (!((-e "$old_file"))) {
                $old_file = '/dev/null';
    }
    if (!((-e "$new_file"))) {
                $new_file = '/dev/null';
    }
if ("$diff_cmd" eq "diff") {
                my $diff_output = q{};
        {
            my $diff_cmd = 'diff';
            my @diff_args = ("$diff_opt", '--label', "$old_file_label", "$old_file", '--label', "$new_file_label", "$new_file");
            my $diff_pid = open my $diff_fh, q{-|}, $diff_cmd, @diff_args;
            if ($diff_pid) {
                local $INPUT_RECORD_SEPARATOR = undef;
                $diff_output = <$diff_fh>;
                close $diff_fh;
                $CHILD_ERROR = $? >> 8;
            } else {
                carp "Cannot execute diff command: $OS_ERROR";
                $diff_output = q{};
                $CHILD_ERROR = 1;
            }
        }
        $diff_output;
        if ($CHILD_ERROR != 0) {
            1;
        }
}
    else {
        if ("$diff_cmd" eq "sdiff") {
                        my $out = (do { my $_chomp_temp = do {
    my ($in_4, $out_4);
    my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'sdiff', "$diff_opt", "$old_file", "$new_file");
    close $in_4 or croak 'Close failed: $OS_ERROR';
    my $result_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
    close $out_4 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_4, 0;
    $result_4
}; chomp $_chomp_temp; $_chomp_temp; });
            if ($CHILD_ERROR != 0) {
                1;
            }
            if (!("$out" eq q{})) {
                printf("Old file: %s\nNew file: %s\n\n%s", "$old_file_label", "$new_file_label", "$out");
            }
}
        else {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "Unknown diff command: $diff_cmd";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
            };
exit 1;
        }
    }
    return;
}

sub show_diff {
if ("$1" eq q{}) {
        my $DIFF;
        my @DIFF;
        my %DIFF;
        $DIFF = "There are no non-white space differences in the files.";
}
    else {
if ((99999 < qx'echo $1 | wc -c | awk '{print $1; }'')) {
            $DIFF = "The differences between the files are too large to display.";
}
        else {
            $DIFF = "$_[0]";
        }
    }
if (("$DEBCONF_OK" eq "YES" && ("$DEBIAN_HAS_FRONTEND"))) {
        my $templ;
        my @templ;
        my %templ;
        $templ = 'ucf/show_diff';
        $main_exit_code = system('db_capb', 'escape') >> 8;
        $main_exit_code = system('db_subst', $templ, 'DIFF', (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_7 = q{};
            my $output_printed_7;
            my $pipeline_success_7 = 1;
            my $output_7;
            {
                local *STDOUT;
                open STDOUT, '>', \$output_7 or die "Cannot redirect STDOUT";
                printf('%s', "$DIFF");
            }
            if ($CHILD_ERROR != 0) { $pipeline_success_7 = 0; }

            my $cmd_9 = 'debconf-escape';
            my ($in_8, $out_8);
            my $pid_8 = open3($in_8, $out_8, '>&STDERR', $cmd_9, '-e');
            print {$in_8} $output_7;
            close $in_8 or croak 'Close failed: $OS_ERROR';
            $output_7 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_8> };
            close $out_8 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_8, 0;
            if ( !$pipeline_success_7 ) { $main_exit_code = 1; }
            exit $main_exit_code if $__set_e && $main_exit_code != 0;
            $output_7 =~ s/\n+\z//msx;
            $output_7;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; })) >> 8;
        $main_exit_code = system('db_fset', $templ, 'seen', 'false') >> 8;
                $main_exit_code = system('db_input', 'critical', $templ) >> 8;
        if ($CHILD_ERROR != 0) {
            1;
        }
                $main_exit_code = system('bash', 'db_go') >> 8;
        if ($CHILD_ERROR != 0) {
            1;
        }
        $main_exit_code = system('db_get', $templ) >> 8;
        $main_exit_code = system('db_subst', $templ, 'DIFF', "") >> 8;
        $main_exit_code = system('db_reset', $templ) >> 8;
        $main_exit_code = system('bash', 'db_capb') >> 8;
}
    else {
if ("$my_pager" eq q{}) {
            # Original bash: echo "$DIFF" | sensible-pager
{
                my $output_12 = q{};
                my $output_printed_12;
                my $pipeline_success_12 = 1;
                $output_12 .= $DIFF . "\n";
if ( !($output_12 =~ m{\n\z}msx) ) { $output_12 .= "\n"; }
$CHILD_ERROR = 0;

                                my $cmd_14 = 'sensible-pager';
                my ($in_13, $out_13);
                my $pid_13 = open3($in_13, $out_13, '>&STDERR', $cmd_14, );
                print {$in_13} $output_12;
                close $in_13 or croak 'Close failed: $OS_ERROR';
                $output_12 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_13> };
                close $out_13 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_13, 0;
                if ($output_12 ne q{} && !defined $output_printed_12) {
                    print $output_12;
                    if (!($output_12 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_12 ) { $main_exit_code = 1; }
                exit $main_exit_code if $__set_e && $main_exit_code != 0;
                }
}
        else {
            # Original bash: echo "$DIFF" | $my_pager
{
                my $output_15 = q{};
                my $output_printed_15;
                my $pipeline_success_15 = 1;
                $output_15 .= $DIFF . "\n";
if ( !($output_15 =~ m{\n\z}msx) ) { $output_15 .= "\n"; }
$CHILD_ERROR = 0;

                                my $cmd_17 = 'unknown_command';
                my ($in_16, $out_16);
                my $pid_16 = open3($in_16, $out_16, '>&STDERR', $cmd_17, );
                print {$in_16} $output_15;
                close $in_16 or croak 'Close failed: $OS_ERROR';
                $output_15 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_16> };
                close $out_16 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_16, 0;
                if ($output_15 ne q{} && !defined $output_printed_15) {
                    print $output_15;
                    if (!($output_15 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_15 ) { $main_exit_code = 1; }
                exit $main_exit_code if $__set_e && $main_exit_code != 0;
                }
        }
    }
    return;
}

sub withecho {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = @ARGV;
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    };
    $CHILD_ERROR = 0;
    return;
}

sub usageversion {
print "Debian GNU/Linux $progname $pversion.
           Copyright (C) 2002-2005 Manoj Srivastava.
This is free software; see the GNU General Public Licence for copying
conditions.  There is NO warranty.

Usage: $progname  [options] new_file  destination
Options:
     -h,     --help          print this message
     -s foo, --src-dir  foo  Set the src dir (historical md5sums live here)
             --sum-file bar  Force the historical md5sums to be read from
                             this file.  Overrides any setting of --src-dir.
     -d[n], --debug=[n]      Set the Debug level to N. Please note there must
                             be no spaces before the debug level
     -n,     --no-action     Dry run. No action is actually taken.
     -P foo, --package foo   Don't follow dpkg-divert diversions by package foo.
     -v,     --verbose       Make the script verbose
             --three-way     Register this file in the cache, and turn on the
                             diff3 option allowing the merging of maintainer
                             changes into a (potentially modified) local
                             configuration file. )
             --state-dir bar Set the state directory to bar instead of the
                             default '/var/lib/ucf'. Used mostly for testing.
             --debconf-ok    Indicate that it is ok for ucf to use an already
                             running debconf instance for prompting.
             --debconf-template bar
                             Specify an alternate, caller-provided debconf
                             template to use for prompting.
Usage: $progname  -p  destination
     -p,     --purge         Remove any reference to destination from records

By default, the directory the new_file lives in is assumed to be the src-dir,
which is where we look for any historical md5sums.

";
    return;
}

sub purge_md5sum {
    my $i;
    for my $i (do {
    my ($in_18, $out_18);
    my $pid_18 = open3($in_18, $out_18, '>&STDERR', '/usr/bin/seq', q{6}, '-1', q{0});
    close $in_18 or croak 'Close failed: $OS_ERROR';
    my $result_18 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_18> };
    close $out_18 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_18, 0;
    $result_18
}) {
if ((-e "${statedir}/hashfile.${i}")) {
if ("X$docmd" eq "XYES") {
                use File::Copy qw(copy);
                if ( -e q{f} ) {
                    if ( -d ${statedir} . "/hashfile." . (do { my $_chomp_temp = do {
    my ($in_20, $out_20);
    my $pid_20 = open3($in_20, $out_20, '>&STDERR', '$i+1');
    close $in_20 or croak 'Close failed: $OS_ERROR';
    my $result_20 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> };
    close $out_20 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_20, 0;
    $result_20
}; chomp $_chomp_temp; $_chomp_temp; }) ) {
                        require File::Copy; File::Copy::copy(q{f}, ${statedir} . "/hashfile." . (do { my $_chomp_temp = do {
    my ($in_20, $out_20);
    my $pid_20 = open3($in_20, $out_20, '>&STDERR', '$i+1');
    close $in_20 or croak 'Close failed: $OS_ERROR';
    my $result_20 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> };
    close $out_20 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_20, 0;
    $result_20
}; chomp $_chomp_temp; $_chomp_temp; }) . '/' . (q{f} =~ m|([^/]+)$|)[0]);
                    } else {
                        require File::Copy; File::Copy::copy(q{f}, ${statedir} . "/hashfile." . (do { my $_chomp_temp = do {
    my ($in_20, $out_20);
    my $pid_20 = open3($in_20, $out_20, '>&STDERR', '$i+1');
    close $in_20 or croak 'Close failed: $OS_ERROR';
    my $result_20 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> };
    close $out_20 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_20, 0;
    $result_20
}; chomp $_chomp_temp; $_chomp_temp; }));
                    }
                } else {
                    croak "cp: cannot stat '-p': No such file or directory\n";
                }
                if ( -e ${statedir} . "/hashfile." . ${i} ) {
                    if ( -d ${statedir} . "/hashfile." . (do { my $_chomp_temp = do {
    my ($in_20, $out_20);
    my $pid_20 = open3($in_20, $out_20, '>&STDERR', '$i+1');
    close $in_20 or croak 'Close failed: $OS_ERROR';
    my $result_20 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> };
    close $out_20 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_20, 0;
    $result_20
}; chomp $_chomp_temp; $_chomp_temp; }) ) {
                        require File::Copy; File::Copy::copy(${statedir} . "/hashfile." . ${i}, ${statedir} . "/hashfile." . (do { my $_chomp_temp = do {
    my ($in_20, $out_20);
    my $pid_20 = open3($in_20, $out_20, '>&STDERR', '$i+1');
    close $in_20 or croak 'Close failed: $OS_ERROR';
    my $result_20 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> };
    close $out_20 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_20, 0;
    $result_20
}; chomp $_chomp_temp; $_chomp_temp; }) . '/' . (${statedir} . "/hashfile." . ${i} =~ m|([^/]+)$|)[0]);
                    } else {
                        require File::Copy; File::Copy::copy(${statedir} . "/hashfile." . ${i}, ${statedir} . "/hashfile." . (do { my $_chomp_temp = do {
    my ($in_20, $out_20);
    my $pid_20 = open3($in_20, $out_20, '>&STDERR', '$i+1');
    close $in_20 or croak 'Close failed: $OS_ERROR';
    my $result_20 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> };
    close $out_20 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_20, 0;
    $result_20
}; chomp $_chomp_temp; $_chomp_temp; }));
                    }
                } else {
                    croak "cp: cannot stat '-p': No such file or directory\n";
                }
                if ( -e "\\\n" ) {
                    if ( -d ${statedir} . "/hashfile." . (do { my $_chomp_temp = do {
    my ($in_20, $out_20);
    my $pid_20 = open3($in_20, $out_20, '>&STDERR', '$i+1');
    close $in_20 or croak 'Close failed: $OS_ERROR';
    my $result_20 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> };
    close $out_20 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_20, 0;
    $result_20
}; chomp $_chomp_temp; $_chomp_temp; }) ) {
                        require File::Copy; File::Copy::copy("\\\n", ${statedir} . "/hashfile." . (do { my $_chomp_temp = do {
    my ($in_20, $out_20);
    my $pid_20 = open3($in_20, $out_20, '>&STDERR', '$i+1');
    close $in_20 or croak 'Close failed: $OS_ERROR';
    my $result_20 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> };
    close $out_20 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_20, 0;
    $result_20
}; chomp $_chomp_temp; $_chomp_temp; }) . '/' . ("\\\n" =~ m|([^/]+)$|)[0]);
                    } else {
                        require File::Copy; File::Copy::copy("\\\n", ${statedir} . "/hashfile." . (do { my $_chomp_temp = do {
    my ($in_20, $out_20);
    my $pid_20 = open3($in_20, $out_20, '>&STDERR', '$i+1');
    close $in_20 or croak 'Close failed: $OS_ERROR';
    my $result_20 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> };
    close $out_20 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_20, 0;
    $result_20
}; chomp $_chomp_temp; $_chomp_temp; }));
                    }
                } else {
                    croak "cp: cannot stat '-p': No such file or directory\n";
                }
}
            else {
                print 'cp' . q{ } . '-p' . q{ } . q{f} . q{ } . ${statedir} . "/hashfile." . ${i} . q{ } . "\\\n" . q{ } . ${statedir} . "/hashfile." . (do { my $_chomp_temp = do {
    my ($in_21, $out_21);
    my $pid_21 = open3($in_21, $out_21, '>&STDERR', '$i+1');
    close $in_21 or croak 'Close failed: $OS_ERROR';
    my $result_21 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_21> };
    close $out_21 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_21, 0;
    $result_21
}; chomp $_chomp_temp; $_chomp_temp; }) . "\n";
                $CHILD_ERROR = 0;
            }
        }
    }
if ((-e "$statedir/hashfile")) {
if ("X$docmd" eq "XYES") {
            use File::Copy qw(copy);
            if ( -e q{f} ) {
                if ( -d "$statedir/hashfile.0" ) {
                    require File::Copy; File::Copy::copy(q{f}, "$statedir/hashfile.0" . '/' . (q{f} =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy(q{f}, "$statedir/hashfile.0");
                }
            } else {
                croak "cp: cannot stat '-p': No such file or directory\n";
            }
            if ( -e "$statedir/hashfile" ) {
                if ( -d "$statedir/hashfile.0" ) {
                    require File::Copy; File::Copy::copy("$statedir/hashfile", "$statedir/hashfile.0" . '/' . ("$statedir/hashfile" =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy("$statedir/hashfile", "$statedir/hashfile.0");
                }
            } else {
                croak "cp: cannot stat '-p': No such file or directory\n";
            }
}
        else {
            do {
    my $__echo_line = 'cp' . q{ } . '-p' . q{ } . q{f} . q{ } . "$statedir/hashfile" . q{ } . "$statedir/hashfile.0";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        }
if ("X$docmd" eq "XYES") {
# set +e not implemented
if ("X$VERBOSE" ne "X") {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    do {
    my $__echo_line = "grep -Ev [[:space:]]" . ($ENV{safe_dest_file} // q{}) . "$ $statedir/hashfile";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                };
                                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
my $grep_result_23;
my @grep_lines_23 = ();
my @grep_filenames_23 = ();
if (-e "\
") {
    open my $fh, '<', "\
" or croak "Cannot access file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_23, $line;
        push @grep_filenames_23, "\
";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: \
: No such file or directory\n"; }
my @grep_filtered_23 = grep { !/[[:space:]]"\ .\ ($ENV{safe_dest_file}\ \/\/\ q{})\ .\ "$/msx } @grep_lines_23;
$grep_result_23 = join "\n", @grep_filtered_23;
                    if (!($grep_result_23 =~ m{\n\z}msx || $grep_result_23 eq q{})) {
                        $grep_result_23 .= "\n";
                    }
print $grep_result_23;
$CHILD_ERROR = scalar @grep_filtered_23 > 0 ? 0 : 1;
                };
                if ($CHILD_ERROR != 0) {
                    1;
                }
            }
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', "\\\n"
      or die "Cannot access file: $OS_ERROR\n";
my $grep_result_25;
my @grep_lines_25 = ();
my @grep_filtered_25 = grep { !/[[:space:]]"\ .\ ($ENV{safe_dest_file}\ \/\/\ q{})\ .\ "$/msx } @grep_lines_25;
$grep_result_25 = join "\n", @grep_filtered_25;
                if (!($grep_result_25 =~ m{\n\z}msx || $grep_result_25 eq q{})) {
                    $grep_result_25 .= "\n";
                }
print $grep_result_25;
$CHILD_ERROR = scalar @grep_filtered_25 > 0 ? 0 : 1;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            if ($CHILD_ERROR != 0) {
                1;
            }
if ("X$docmd" eq "XYES") {
                my $err;
                my $force = 1;
                if ( -e "$statedir/hashfile.tmp" ) {
                    my $dest = "$statedir/hashfile";
                    if ( -e $dest && -d $dest ) {
                        my $source_name = "$statedir/hashfile.tmp";
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
                    if ( File::Copy::move( "$statedir/hashfile.tmp", $dest ) ) {
                    } else {
                        croak
  "mv: cannot move "$statedir/hashfile.tmp" to $dest: $ERRNO\n";
                    }
                } else {
                    croak "mv: "$statedir/hashfile.tmp": No such file or directory\n";
                }
}
            else {
                do {
    my $__echo_line = 'mv' . q{ } . '-f' . q{ } . "$statedir/hashfile.tmp" . q{ } . "$statedir/hashfile";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
            }
$__set_e = 1;
        }
    }
    if (do {
$main_exit_code = system('test', '-n', "$VERBOSE") >> 8;
        $CHILD_ERROR == 0
    }) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "The cache file is $cached_file";
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
if ((! "$cached_file" eq q{} && (-f "$statedir/cache/$cached_file"))) {
        $CHILD_ERROR = 0;
    }
    return;
}

sub replace_md5sum {
    my $i;
    for my $i (do {
    my ($in_28, $out_28);
    my $pid_28 = open3($in_28, $out_28, '>&STDERR', '/usr/bin/seq', q{6}, '-1', q{0});
    close $in_28 or croak 'Close failed: $OS_ERROR';
    my $result_28 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_28> };
    close $out_28 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_28, 0;
    $result_28
}) {
if ((-e "${statedir}/hashfile.${i}")) {
if ("X$docmd" eq "XYES") {
                use File::Copy qw(copy);
                if ( -e q{f} ) {
                    if ( -d ${statedir} . "/hashfile." . (do { my $_chomp_temp = do {
    my ($in_30, $out_30);
    my $pid_30 = open3($in_30, $out_30, '>&STDERR', '$i+1');
    close $in_30 or croak 'Close failed: $OS_ERROR';
    my $result_30 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_30> };
    close $out_30 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_30, 0;
    $result_30
}; chomp $_chomp_temp; $_chomp_temp; }) ) {
                        require File::Copy; File::Copy::copy(q{f}, ${statedir} . "/hashfile." . (do { my $_chomp_temp = do {
    my ($in_30, $out_30);
    my $pid_30 = open3($in_30, $out_30, '>&STDERR', '$i+1');
    close $in_30 or croak 'Close failed: $OS_ERROR';
    my $result_30 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_30> };
    close $out_30 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_30, 0;
    $result_30
}; chomp $_chomp_temp; $_chomp_temp; }) . '/' . (q{f} =~ m|([^/]+)$|)[0]);
                    } else {
                        require File::Copy; File::Copy::copy(q{f}, ${statedir} . "/hashfile." . (do { my $_chomp_temp = do {
    my ($in_30, $out_30);
    my $pid_30 = open3($in_30, $out_30, '>&STDERR', '$i+1');
    close $in_30 or croak 'Close failed: $OS_ERROR';
    my $result_30 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_30> };
    close $out_30 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_30, 0;
    $result_30
}; chomp $_chomp_temp; $_chomp_temp; }));
                    }
                } else {
                    croak "cp: cannot stat '-p': No such file or directory\n";
                }
                if ( -e ${statedir} . "/hashfile." . ${i} ) {
                    if ( -d ${statedir} . "/hashfile." . (do { my $_chomp_temp = do {
    my ($in_30, $out_30);
    my $pid_30 = open3($in_30, $out_30, '>&STDERR', '$i+1');
    close $in_30 or croak 'Close failed: $OS_ERROR';
    my $result_30 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_30> };
    close $out_30 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_30, 0;
    $result_30
}; chomp $_chomp_temp; $_chomp_temp; }) ) {
                        require File::Copy; File::Copy::copy(${statedir} . "/hashfile." . ${i}, ${statedir} . "/hashfile." . (do { my $_chomp_temp = do {
    my ($in_30, $out_30);
    my $pid_30 = open3($in_30, $out_30, '>&STDERR', '$i+1');
    close $in_30 or croak 'Close failed: $OS_ERROR';
    my $result_30 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_30> };
    close $out_30 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_30, 0;
    $result_30
}; chomp $_chomp_temp; $_chomp_temp; }) . '/' . (${statedir} . "/hashfile." . ${i} =~ m|([^/]+)$|)[0]);
                    } else {
                        require File::Copy; File::Copy::copy(${statedir} . "/hashfile." . ${i}, ${statedir} . "/hashfile." . (do { my $_chomp_temp = do {
    my ($in_30, $out_30);
    my $pid_30 = open3($in_30, $out_30, '>&STDERR', '$i+1');
    close $in_30 or croak 'Close failed: $OS_ERROR';
    my $result_30 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_30> };
    close $out_30 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_30, 0;
    $result_30
}; chomp $_chomp_temp; $_chomp_temp; }));
                    }
                } else {
                    croak "cp: cannot stat '-p': No such file or directory\n";
                }
                if ( -e "\\\n" ) {
                    if ( -d ${statedir} . "/hashfile." . (do { my $_chomp_temp = do {
    my ($in_30, $out_30);
    my $pid_30 = open3($in_30, $out_30, '>&STDERR', '$i+1');
    close $in_30 or croak 'Close failed: $OS_ERROR';
    my $result_30 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_30> };
    close $out_30 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_30, 0;
    $result_30
}; chomp $_chomp_temp; $_chomp_temp; }) ) {
                        require File::Copy; File::Copy::copy("\\\n", ${statedir} . "/hashfile." . (do { my $_chomp_temp = do {
    my ($in_30, $out_30);
    my $pid_30 = open3($in_30, $out_30, '>&STDERR', '$i+1');
    close $in_30 or croak 'Close failed: $OS_ERROR';
    my $result_30 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_30> };
    close $out_30 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_30, 0;
    $result_30
}; chomp $_chomp_temp; $_chomp_temp; }) . '/' . ("\\\n" =~ m|([^/]+)$|)[0]);
                    } else {
                        require File::Copy; File::Copy::copy("\\\n", ${statedir} . "/hashfile." . (do { my $_chomp_temp = do {
    my ($in_30, $out_30);
    my $pid_30 = open3($in_30, $out_30, '>&STDERR', '$i+1');
    close $in_30 or croak 'Close failed: $OS_ERROR';
    my $result_30 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_30> };
    close $out_30 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_30, 0;
    $result_30
}; chomp $_chomp_temp; $_chomp_temp; }));
                    }
                } else {
                    croak "cp: cannot stat '-p': No such file or directory\n";
                }
}
            else {
                print 'cp' . q{ } . '-p' . q{ } . q{f} . q{ } . ${statedir} . "/hashfile." . ${i} . q{ } . "\\\n" . q{ } . ${statedir} . "/hashfile." . (do { my $_chomp_temp = do {
    my ($in_31, $out_31);
    my $pid_31 = open3($in_31, $out_31, '>&STDERR', '$i+1');
    close $in_31 or croak 'Close failed: $OS_ERROR';
    my $result_31 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_31> };
    close $out_31 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_31, 0;
    $result_31
}; chomp $_chomp_temp; $_chomp_temp; }) . "\n";
                $CHILD_ERROR = 0;
            }
        }
    }
if ((-e "$statedir/hashfile")) {
if ("X$docmd" eq "XYES") {
            use File::Copy qw(copy);
            if ( -e q{f} ) {
                if ( -d "$statedir/hashfile.0" ) {
                    require File::Copy; File::Copy::copy(q{f}, "$statedir/hashfile.0" . '/' . (q{f} =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy(q{f}, "$statedir/hashfile.0");
                }
            } else {
                croak "cp: cannot stat '-p': No such file or directory\n";
            }
            if ( -e "$statedir/hashfile" ) {
                if ( -d "$statedir/hashfile.0" ) {
                    require File::Copy; File::Copy::copy("$statedir/hashfile", "$statedir/hashfile.0" . '/' . ("$statedir/hashfile" =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy("$statedir/hashfile", "$statedir/hashfile.0");
                }
            } else {
                croak "cp: cannot stat '-p': No such file or directory\n";
            }
}
        else {
            do {
    my $__echo_line = 'cp' . q{ } . '-p' . q{ } . q{f} . q{ } . "$statedir/hashfile" . q{ } . "$statedir/hashfile.0";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        }
if ("X$docmd" eq "XYES") {
# set +e not implemented
if ("X$VERBOSE" ne "X") {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    do {
    my $__echo_line = "(grep -Ev \"[[:space:]]" . ($ENV{safe_dest_file} // q{}) . "$\" \"$statedir/hashfile\";";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                };
                                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
my $grep_result_33;
my @grep_lines_33 = ();
my @grep_filtered_33 = grep { !/[[:space:]]"\ .\ ($ENV{safe_dest_file}\ \/\/\ q{})\ .\ "$/msx } @grep_lines_33;
$grep_result_33 = join "\n", @grep_filtered_33;
                    if (!($grep_result_33 =~ m{\n\z}msx || $grep_result_33 eq q{})) {
                        $grep_result_33 .= "\n";
                    }
print $grep_result_33;
$CHILD_ERROR = scalar @grep_filtered_33 > 0 ? 0 : 1;
                };
                if ($CHILD_ERROR != 0) {
                    1;
                }
                # Original bash: md5sum "$orig_new_file" | sed "s|$orig_new_file|$dest_file|" >&2;
{
                    my $output_35 = q{};
                    my $output_printed_35;
                    my $pipeline_success_35 = 1;
                                        my ($in_36, $out_36);
                    my $pid_36 = open3($in_36, $out_36, '>&STDERR', 'md5sum', );
                    close $in_36 or croak 'Close failed: $OS_ERROR';
                    $output_35 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_36> };
                    close $out_36 or croak 'Close failed: $OS_ERROR';
                    waitpid $pid_36, 0;

                                        my @sed_lines_35 = split /\n/msx, $output_35;
                    my @sed_result_35;
                    foreach my $line (@sed_lines_35) {
                    chomp $line;
                    push @sed_result_35, $line;
                    }
                    $output_35 = join "\n", @sed_result_35;
                    if ($output_35 ne q{} && !defined $output_printed_35) {
                        print $output_35;
                        if (!($output_35 =~ m{\n\z}msx)) {
                            print "\n";
                        }
                    }
                    if ( !$pipeline_success_35 ) { $main_exit_code = 1; }
                    exit $main_exit_code if $__set_e && $main_exit_code != 0;
                    }
            }
                        do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', "\\\n"
      or die "Cannot access file: $OS_ERROR\n";
my $grep_result_37;
my @grep_lines_37 = ();
my @grep_filtered_37 = grep { !/[[:space:]]"\ .\ ($ENV{safe_dest_file}\ \/\/\ q{})\ .\ "$/msx } @grep_lines_37;
$grep_result_37 = join "\n", @grep_filtered_37;
                if (!($grep_result_37 =~ m{\n\z}msx || $grep_result_37 eq q{})) {
                    $grep_result_37 .= "\n";
                }
print $grep_result_37;
$CHILD_ERROR = scalar @grep_filtered_37 > 0 ? 0 : 1;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            if ($CHILD_ERROR != 0) {
                1;
            }
            # Original bash: md5sum "$orig_new_file" | sed "s|$orig_new_file|$dest_file|" >> \
{
                my $output_39 = q{};
                my $output_printed_39;
                my $pipeline_success_39 = 1;
                                my ($in_40, $out_40);
                my $pid_40 = open3($in_40, $out_40, '>&STDERR', 'md5sum', );
                close $in_40 or croak 'Close failed: $OS_ERROR';
                $output_39 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_40> };
                close $out_40 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_40, 0;

                                do {
                open my $original_stdout, '>&', STDOUT
                or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "\\\n"
                or die "Cannot access file: $OS_ERROR\n";
                my $tmp = do {
                my $tmp_redirect_41 = q{};
                my @sed_lines_42 = split /\n/msx, $output_39;
                my @sed_result_42;
                foreach my $line (@sed_lines_42) {
                chomp $line;
                push @sed_result_42, $line;
                }
                $output_39 = join "\n", @sed_result_42;
                $tmp_redirect_41;
                };
                print $tmp;
                if ($tmp eq q{}) { print $output_39; }
                $output_printed_39 = 1;
                open STDOUT, '>&', $original_stdout
                or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
                or die "Close failed: $OS_ERROR\n";
                };
                if ( !$pipeline_success_39 ) { $main_exit_code = 1; }
                exit $main_exit_code if $__set_e && $main_exit_code != 0;
                }
            my $err;
            my $force = 1;
            if ( -e "$statedir/hashfile.tmp" ) {
                my $dest = "$statedir/hashfile";
                if ( -e $dest && -d $dest ) {
                    my $source_name = "$statedir/hashfile.tmp";
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
                if ( File::Copy::move( "$statedir/hashfile.tmp", $dest ) ) {
                } else {
                    croak
  "mv: cannot move "$statedir/hashfile.tmp" to $dest: $ERRNO\n";
                }
            } else {
                croak "mv: "$statedir/hashfile.tmp": No such file or directory\n";
            }
$__set_e = 1;
}
        else {
            do {
    my $__echo_line = "(grep -Ev \"[[:space:]]" . ($ENV{safe_dest_file} // q{}) . "$\" \"$statedir/hashfile\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            do {
    my $__echo_line = " md5sum \"$ENV{orig_new_file}\" | sed \"s|$ENV{orig_new_file}|$dest_file|\"; ";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            do {
    my $__echo_line = ") | sort > \"$statedir/hashfile\"";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        }
}
    else {
if ("X$docmd" eq "XYES") {
            # Original bash: md5sum "$orig_new_file" | sed "s|$orig_new_file|$dest_file|"  > \
{
                my $output_44 = q{};
                my $output_printed_44;
                my $pipeline_success_44 = 1;
                                my ($in_45, $out_45);
                my $pid_45 = open3($in_45, $out_45, '>&STDERR', 'md5sum', );
                close $in_45 or croak 'Close failed: $OS_ERROR';
                $output_44 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_45> };
                close $out_45 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_45, 0;

                                do {
                open my $original_stdout, '>&', STDOUT
                or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', "\\\n"
                or die "Cannot access file: $OS_ERROR\n";
                my $tmp = do {
                my $tmp_redirect_46 = q{};
                my @sed_lines_47 = split /\n/msx, $output_44;
                my @sed_result_47;
                foreach my $line (@sed_lines_47) {
                chomp $line;
                push @sed_result_47, $line;
                }
                $output_44 = join "\n", @sed_result_47;
                $tmp_redirect_46;
                };
                print $tmp;
                if ($tmp eq q{}) { print $output_44; }
                $output_printed_44 = 1;
                open STDOUT, '>&', $original_stdout
                or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
                or die "Close failed: $OS_ERROR\n";
                };
                if ( !$pipeline_success_44 ) { $main_exit_code = 1; }
                exit $main_exit_code if $__set_e && $main_exit_code != 0;
                }
}
        else {
            do {
    my $__echo_line = " md5sum \"$ENV{orig_new_file}\" | sed \"s|$ENV{orig_new_file}|$dest_file|\" >" . q{ } . "\\\n" . q{ } . "\"$statedir/hashfile\"";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        }
    }
    my $file_size;
    my @file_size;
    my %file_size;
    $file_size = do {
    my ($in_48, $out_48);
    my $pid_48 = open3($in_48, $out_48, '>&STDERR', 'stat', '-c', '%s', "$ENV{orig_new_file}");
    close $in_48 or croak 'Close failed: $OS_ERROR';
    my $result_48 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_48> };
    close $out_48 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_48, 0;
    $result_48
};
if (("X$THREEWAY" ne "X" || ($file_size < 25600))) {
        $CHILD_ERROR = 0;
    }
    return;
}

sub replace_conf_file {
    my $real_file;
    my @real_file;
    my %real_file;
    $real_file = "$dest_file";
if ((-l "$dest_file")) {
        $real_file = (do { my $_chomp_temp = do {
    local $ENV{dest_file} = $dest_file;
    my $command = 'readlink -nf Variable("dest_file", false, None) || :';
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
}; chomp $_chomp_temp; $_chomp_temp; });
if ("x$real_file" eq "x") {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "$dest_file is a broken symlink!";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
            };
            $CHILD_ERROR = 0;
            $real_file = "$dest_file";
        }
    }
if ((-e "$real_file")) {
if ("$RETAIN_OLD" eq q{}) {
if ("x$VERBOSE" ne "x") {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    do {
    my $__echo_line = "Not saving " . ${real_file} . ", since it was unmodified";
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
}
        else {
            $CHILD_ERROR = 0;
        }
    }
if ((-e "${real_file}")) {
        $CHILD_ERROR = 0;
}
    else {
        $CHILD_ERROR = 0;
    }
    replace_md5sum();
    return;
}

sub quote_single {
    my ($file) = @_;
    # Original bash: printf "%s\n" "$1" | sed -e "s,','\\\\'',g"
    my $output_49 = q{};
    my $output_printed_49;
    my $output_50 = q{};
    while (my $line = <>) {
        chomp $line;
        # printf doesn't support line-by-line processing
                print $line . "\n";
    }
    $output_50;
    return;
}
$docmd = 'YES';
my $action;
my @action;
my %action;
$action = 'withecho';
$action = q{};
my $selinux;
my @selinux;
my %selinux;
$selinux = q{};
$DEBUG = q{0};
$VERBOSE = q{};
$statedir = '/var/lib/ucf';
$THREEWAY = q{};
my $DIST_SUFFIX;
my @DIST_SUFFIX;
my %DIST_SUFFIX;
$DIST_SUFFIX = "ucf-dist";
my $NEW_SUFFIX;
my @NEW_SUFFIX;
my %NEW_SUFFIX;
$NEW_SUFFIX = "ucf-new";
my $OLD_SUFFIX;
my @OLD_SUFFIX;
my %OLD_SUFFIX;
$OLD_SUFFIX = "ucf-old";
my $ERR_SUFFIX;
my @ERR_SUFFIX;
my %ERR_SUFFIX;
$ERR_SUFFIX = "merge-error";
my $arg;
for my $arg (@ARGV) {
    my $saved;
    my @saved;
    my %saved;
    $saved = (defined (defined ${saved} && ${saved} ne q{} ? ${saved} : '$saved ') && (defined ${saved} && ${saved} ne q{} ? ${saved} : '$saved ') ne q{} ? (defined ${saved} && ${saved} ne q{} ? ${saved} : '$saved ') : '$saved ') . "'" . (do { my $_chomp_temp = do {
    my ($in_51, $out_51);
    my $pid_51 = open3($in_51, $out_51, '>&STDERR', 'quote_single', "$arg");
    close $in_51 or croak 'Close failed: $OS_ERROR';
    my $result_51 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_51> };
    close $out_51 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_51, 0;
    $result_51
}; chomp $_chomp_temp; $_chomp_temp; }) . "'";
}
my $TEMP;
my @TEMP;
my %TEMP;
$TEMP = do {
    my ($in_52, $out_52);
    my $pid_52 = open3($in_52, $out_52, '>&STDERR', 'getopt', '-a', '-o', 'hs:d::D::npP:Zv', '-n', "$progname", '--long', 'help,src-dir:,sum-file:,dest-dir:,debug::,DEBUG::,no-action,package:,purge,verbose,three-way,debconf-ok,debconf-template:,state-dir:', '--', "\@ARGV");
    close $in_52 or croak 'Close failed: $OS_ERROR';
    my $result_52 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_52> };
    close $out_52 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_52, 0;
    $result_52
};
do { my $eval_input = "set" . "--" . $TEMP; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
while ( 1 ) {
if ("$_[0]" =~ /^-h$/msx or "$_[0]" =~ /^--help$/msx) {
                usageversion();
        exit 0;
    } elsif ("$_[0]" =~ /^-n$/msx or "$_[0]" =~ /^--no-action$/msx) {
                $action = 'echo';
                $docmd = 'NO';
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-v$/msx or "$_[0]" =~ /^--verbose$/msx) {
                $VERBOSE = q{1};
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-P$/msx or "$_[0]" =~ /^--package$/msx) {
                $opt_package = "$_[1]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-s$/msx or "$_[0]" =~ /^--src-dir$/msx) {
                $opt_source_dir = "$_[1]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--sum-file$/msx) {
                $opt_old_mdsum_file = "$_[1]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--state-dir$/msx) {
                $opt_state_dir = "$_[1]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--debconf-template$/msx) {
                $override_template = "$_[1]";
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-D$/msx or "$_[0]" =~ /^-d$/msx or "$_[0]" =~ /^--debug$/msx or "$_[0]" =~ /^--DEBUG$/msx) {
        if ("$_[1]" =~ /^$/msx) {
                        setq('DEBUG', q{1}, "The Debug value");
            # Builtin command 'shift' not implemented
        } elsif (1) {
                        setq('DEBUG', "$_[1]", "The Debug value");
            # Builtin command 'shift' not implemented
        }
    } elsif ("$_[0]" =~ /^-p$/msx or "$_[0]" =~ /^--purge$/msx) {
                $PURGE = 'YES';
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--three-way$/msx) {
                $THREEWAY = 'YES';
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--debconf-ok$/msx) {
                $DEBCONF_OK = 'YES';
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^-Z$/msx) {
                $selinux = '-Z';
        # Builtin command 'shift' not implemented
    } elsif ("$_[0]" =~ /^--$/msx) {
        # Builtin command 'shift' not implemented
        last;    } elsif (1) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "Internal error!\n";
        };
        exit 1;
    }
}
if ((!StringInterpolation(StringInterpolation { parts: [CommandSubstitution(Simple(SimpleCommand { name: Literal("id", None), args: [Literal("-u", None)], redirects: [], env_vars: {}, stdout_used: true, stderr_used: true }))] }, None) eq 0)) {
if ("$docmd" eq "YES") {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "$progname: Need to be run as root.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "$progname: Setting up no action mode.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
        $action = 'echo';
        $docmd = 'NO';
    }
}
if ("X$PURGE" eq "XYES") {
if ($# ne 1) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "*** ERROR: Need exactly one argument when purging, got ${scalar(\@ARGV)}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "\n";
        };
        usageversion();
exit 2;
    }
    $temp_dest_file = "$_[0]";
if ((-e "$temp_dest_file")) {
        setq('dest_file', (do { my $_chomp_temp = do {
    my ($in_54, $out_54);
    my $pid_54 = open3($in_54, $out_54, '>&STDERR', 'readlink', '-q', '-m', $temp_dest_file);
    close $in_54 or croak 'Close failed: $OS_ERROR';
    my $result_54 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_54> };
    close $out_54 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_54, 0;
    $result_54
}; chomp $_chomp_temp; $_chomp_temp; }), "The Destination file");
}
    else {
        setq('dest_file', "$temp_dest_file", "The Destination file");
    }
}
else {
if ($# ne 2) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "*** ERROR: Need exactly two arguments, got ${scalar(\@ARGV)}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "\n";
        };
        usageversion();
exit 2;
    }
    $temp_new_file = "$_[0]";
    $temp_dest_file = "$_[1]";
if ((!-e "${temp_new_file}")) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "Error: The new file " . ${temp_new_file} . " does not exist!";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
exit 1;
    }
    setq('new_file', (do { my $_chomp_temp = do {
    my ($in_55, $out_55);
    my $pid_55 = open3($in_55, $out_55, '>&STDERR', 'readlink', '-q', '-m', $temp_new_file);
    close $in_55 or croak 'Close failed: $OS_ERROR';
    my $result_55 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_55> };
    close $out_55 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_55, 0;
    $result_55
}; chomp $_chomp_temp; $_chomp_temp; }), "The new file");
if ((-e "$temp_dest_file")) {
        setq('dest_file', (do { my $_chomp_temp = do {
    my ($in_56, $out_56);
    my $pid_56 = open3($in_56, $out_56, '>&STDERR', 'readlink', '-q', '-m', $temp_dest_file);
    close $in_56 or croak 'Close failed: $OS_ERROR';
    my $result_56 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_56> };
    close $out_56 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_56, 0;
    $result_56
}; chomp $_chomp_temp; $_chomp_temp; }), "The Destination file");
}
    else {
        setq('dest_file', "$temp_dest_file", "The Destination file");
    }
}
$divert_line = do {
    my ($in_57, $out_57);
    my $pid_57 = open3($in_57, $out_57, '>&STDERR', 'dpkg-divert', '--listpackage', "$dest_file");
    close $in_57 or croak 'Close failed: $OS_ERROR';
    my $result_57 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_57> };
    close $out_57 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_57, 0;
    $result_57
};
if ("$divert_line" ne q{}) {
    $divert_package = "$divert_line";
if ("$divert_package" ne "$opt_package") {
        $dest_file = do {
    my ($in_58, $out_58);
    my $pid_58 = open3($in_58, $out_58, '>&STDERR', 'dpkg-divert', '--truename', "$dest_file");
    close $in_58 or croak 'Close failed: $OS_ERROR';
    my $result_58 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_58> };
    close $out_58 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_58, 0;
    $result_58
};
    }
}
my $safe_dest_file;
my @safe_dest_file;
my %safe_dest_file;
$safe_dest_file = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_59 = q{};
    my $output_printed_59;
    my $pipeline_success_59 = 1;
    $output_59 .= $dest_file . "\n";
    if ( !($output_59 =~ m{\n\z}msx) ) { $output_59 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_59 = 0; }
    my $perl_output_60 = do {
                    my $result = qx{perl '-n' 'le' "\"print \\\"\\\\Q\\$_\\\\E\\\\n\\\"\""};
                    chomp $result;
                    $result;
                };
    print $perl_output_60;
    if ( !$pipeline_success_59 ) { $main_exit_code = 1; }
    exit $main_exit_code if $__set_e && $main_exit_code != 0;
    $output_59 =~ s/\n+\z//msx;
    $output_59;
}; $_pipeline_result; };
if ((-f '/etc/ucf.conf')) {
    $main_exit_code = system('.', '/etc/ucf.conf') >> 8;
}
if (!"x$opt_source_dir" eq "x") {
    setq('source_dir', "$opt_source_dir", "The Source directory");
}
else {
    if (!"x$UCF_SOURCE_DIR" eq "x") {
        setq('source_dir', "$UCF_SOURCE_DIR", "The Source directory");
}
    else {
        if (!"x$conf_source_dir" eq "x") {
            setq('source_dir', "$conf_source_dir", "The Source directory");
}
        else {
if ("X$new_file" ne "X") {
                setq('source_dir', (do { my $_chomp_temp = do { use File::Basename qw(dirname); my $dirname_output = dirname($new_file); $CHILD_ERROR = 0; $dirname_output; }; chomp $_chomp_temp; $_chomp_temp; }), "The Source directory");
}
            else {
                setq('source_dir', "/tmp", "The Source directory");
            }
        }
    }
}
if (("X$PAGER" ne "X" && !(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $_wa0 = "$PAGER";
my $which_prog = q{which};
my $_which_out = qx{$which_prog $_wa0};
print $_which_out;
$CHILD_ERROR = $? >> 8;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
}))) {
    my $my_pager;
    my @my_pager;
    my %my_pager;
    $my_pager = (do { my $_chomp_temp = do { my $which_cmd = 'which $PAGER'; my $which_output = qx{$which_cmd}; $CHILD_ERROR = $? >> 8; $which_output; }; chomp $_chomp_temp; $_chomp_temp; });
}
else {
    if ((((-s '/usr/bin/pager') > 0) && "X$(readlink -e /usr/bin/pager || :)" ne "X")) {
        $my_pager = '/usr/bin/pager';
}
    else {
        if ((-x '/usr/bin/sensible-pager')) {
            $my_pager = '/usr/bin/sensible-pager';
}
        else {
            if ((-x '/bin/more')) {
                $my_pager = '/bin/more';
}
            else {
                $my_pager = q{};
            }
        }
    }
}
if (!"x$opt_state_dir" eq "x") {
    setq('statedir', "$opt_state_dir", "The State directory");
}
else {
    if (!"x$UCF_STATE_DIR" eq "x") {
        setq('statedir', "$UCF_STATE_DIR", "The State directory");
}
    else {
        if (!"x$conf_state_dir" eq "x") {
            setq('statedir', "$conf_state_dir", "The State directory");
}
        else {
            setq('statedir', '/var/lib/ucf', "The State directory");
        }
    }
}
if (!"x$opt_force_conffold" eq "x") {
    setq('force_conffold', "$opt_force_conffold", "Keep the old file");
}
else {
    if (!"x$UCF_FORCE_CONFFOLD" eq "x") {
        setq('force_conffold', "$UCF_FORCE_CONFFOLD", "Keep the old file");
}
    else {
        if (!"x$conf_force_conffold" eq "x") {
            setq('force_conffold', "$conf_force_conffold", "Keep the old file");
}
        else {
            $force_conffold = q{};
        }
    }
}
if (!"x$opt_force_conffnew" eq "x") {
    setq('force_conffnew', "$opt_force_conffnew", "Replace the old file");
}
else {
    if (!"x$UCF_FORCE_CONFFNEW" eq "x") {
        setq('force_conffnew', "$UCF_FORCE_CONFFNEW", "Replace the old file");
}
    else {
        if (!"x$conf_force_conffnew" eq "x") {
            setq('force_conffnew', "$conf_force_conffnew", "Replace the old file");
}
        else {
            $force_conffnew = q{};
        }
    }
}
if (!"x$opt_force_conffmiss" eq "x") {
    setq('force_conffmiss', "$opt_force_conffmiss", "Replace any missing files");
}
else {
    if (!"x$UCF_FORCE_CONFFMISS" eq "x") {
        setq('force_conffmiss', "$UCF_FORCE_CONFFMISS", "Replace any missing files");
}
    else {
        if (!"x$conf_force_conffmiss" eq "x") {
            setq('force_conffmiss', "$conf_force_conffmiss", "Replace any missing files");
}
        else {
            $force_conffmiss = q{};
        }
    }
}
if ("$opt_old_mdsum_file" ne q{}) {
    setq('old_mdsum_file', "$opt_old_mdsum_file", "The md5sum is found here");
}
else {
    if (!"x$UCF_OLD_MDSUM_FILE" eq "x") {
        setq('old_mdsum_file', "$UCF_OLD_MDSUM_FILE", "The md5sum is found here");
}
    else {
        if (!"x$conf_old_mdsum_file" eq "x") {
            setq('old_mdsum_file', "$conf_old_mdsum_file", "Replace the old file");
}
        else {
            if (!"x${new_file}" eq "x") {
                $old_mdsum_file = "$ENV{source_dir}/" . (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename($new_file); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; }) . ".md5sum";
}
            else {
                $old_mdsum_file = "";
            }
        }
    }
}
if (("X$force_conffold" ne "X" && "X$force_conffnew" ne "X")) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "Error: Only one of force_conffold and force_conffnew should\n";
    };
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "       be set\n";
    };
exit 1;
}
if ("X$VERBOSE" eq "X0") {
    $VERBOSE = q{};
}
if (((-e "$statedir/hashfile") && (!-w "$statedir/hashfile"))) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "ucf: do not have write privilege to the state data\n";
    };
if ("X$docmd" eq "XYES") {
exit 1;
    }
}
if ((!-d $statedir/cache)) {
    $CHILD_ERROR = 0;
}
if ((-e "$statedir/hashfile")) {
if ("X$VERBOSE" ne "X") {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "The hash file exists\n";
        };
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "grep -E" . q{ } . "[[:space:]]" . ${safe_dest_file} . "$" . q{ } . "$statedir/hashfile";
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
my $grep_result_62;
my @grep_lines_62 = ();
my @grep_filtered_62 = grep { /[[:space:]]"\ .\ ${safe_dest_file}\ .\ "$/msx } @grep_lines_62;
$grep_result_62 = join "\n", @grep_filtered_62;
            if (!($grep_result_62 =~ m{\n\z}msx || $grep_result_62 eq q{})) {
                $grep_result_62 .= "\n";
            }
print $grep_result_62;
$CHILD_ERROR = scalar @grep_filtered_62 > 0 ? 0 : 1;
        };
        if ($CHILD_ERROR != 0) {
            1;
        }
    }
    $lastsum = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_64 = q{};
    my $output_printed_64;
    my $output_65 = q{};
    while (my $line = <>) {
        chomp $line;
                if (!($line =~ /"[[:space:]]"\ .\ ${safe_dest_file}\ .\ "$"/msx)) {
            next;
        }
        # awk doesn't support line-by-line processing
    }
    $output_65; };
}; $_pipeline_result; };
}
if (!"x${new_file}" eq "x") {
    $old_mdsum_dir = "$ENV{source_dir}/";
    $CHILD_ERROR = 0;
}
else {
    $old_mdsum_dir = "";
}
$cached_file = (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ($dest_file) . "\n";
    my $set1_67 = q{/};
my $set2_67 = q{:};
my $input_67 = $input_data;
# Expand character ranges for tr command
my $expanded_set1_67 = $set1_67;
my $expanded_set2_67 = $set2_67;
# Handle a-z range in set1
if ($expanded_set1_67 =~ /a-z/msx) {
    $expanded_set1_67 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set1
if ($expanded_set1_67 =~ /A-Z/msx) {
    $expanded_set1_67 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set1
if ($expanded_set1_67 =~ /\[:upper:\]/msx) {
    $expanded_set1_67 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set1
if ($expanded_set1_67 =~ /\[:lower:\]/msx) {
    $expanded_set1_67 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle a-z range in set2
if ($expanded_set2_67 =~ /a-z/msx) {
    $expanded_set2_67 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
}
# Handle A-Z range in set2
if ($expanded_set2_67 =~ /A-Z/msx) {
    $expanded_set2_67 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:upper:] POSIX class in set2
if ($expanded_set2_67 =~ /\[:upper:\]/msx) {
    $expanded_set2_67 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
}
# Handle [:lower:] POSIX class in set2
if ($expanded_set2_67 =~ /\[:lower:\]/msx) {
    $expanded_set2_67 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
}
my $tr_result_66 = q{};
for my $char ( split //msx, $input_67 ) {
    my $pos_67 = index $expanded_set1_67, $char;
    if ( $pos_67 >= 0 && $pos_67 < length $expanded_set2_67 ) {
        $tr_result_66 .= substr $expanded_set2_67, $pos_67, 1;
    } else {
        $tr_result_66 .= $char;
    }
}
$tr_result_66
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; });
if (($DEBUG > 0)) {
print "The new start file is      \\`$new_file\\'
The destination is         \\`$dest_file\\' (\\`$safe_dest_file\\')
The history is kept under  \\'$source_dir\\'
The file may be cached at \\'$statedir/cache/$cached_file\\'
";
if (((-s "$dest_file") > 0)) {
        print "The destination file exists, and has md5sum:\n";
        $main_exit_code = system('md5sum', "$dest_file") >> 8;
}
    else {
        print "The destination file does not exist.\n";
    }
if ("X$lastsum" ne "X") {
        print "The old md5sum exists, and is:\n";
        print $lastsum;
if ( !( ($lastsum) =~ m{\n\z}msx ) ) { print "\n"; }
}
    else {
        print "The old md5sum does not exist.\n";
if (((-d "$old_mdsum_dir") || (-f "$old_mdsum_file"))) {
            print "However, there are historical md5sums around.\n";
        }
    }
if ((-e "$new_file")) {
        print "The new file exists, and has md5sum:\n";
        $main_exit_code = system('md5sum', "$new_file") >> 8;
}
    else {
        print "The new file does not exist.\n";
    }
if ((-d "$old_mdsum_dir")) {
        do {
    my $__echo_line = "The historical md5sum dir $old_mdsum_dir exists";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
}
    else {
        if ((-f "$old_mdsum_file")) {
            do {
    my $__echo_line = "The historical md5sum file $old_mdsum_file exists";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
}
        else {
            print "Historical md5sums are not available\n";
        }
    }
}
if ("X$PURGE" eq "XYES") {
if ("X$VERBOSE" ne "X") {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "Preparing to purge " . ${dest_file};
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
    purge_md5sum();
exit 0;
}
do { my $eval_input = "set" . "--" . $saved; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
if ("$DEBCONF_ALREADY_RUNNING" eq q{}) {
if (("$DEBIAN_HAS_FRONTEND")) {
        $DEBCONF_ALREADY_RUNNING = 'YES';
}
    else {
        $DEBCONF_ALREADY_RUNNING = 'NO';
    }
}
$ENV{DEBCONF_ALREADY_RUNNING} = $DEBCONF_ALREADY_RUNNING;
if ("$DEBCONF_OK" eq q{}) {
if ("$DEBCONF_ALREADY_RUNNING" eq 'YES') {
        $DEBCONF_OK = 'NO';
}
    else {
        $DEBCONF_OK = 'YES';
    }
}
if (("$DEBCONF_ALREADY_RUNNING" eq 'YES' && "$DEBCONF_OK" eq NO)) {
print "*** WARNING: ucf was run from a maintainer script that uses debconf, but
             the script did not pass --debconf-ok to ucf. The maintainer
             script should be fixed to not stop debconf before calling ucf,
             and pass it this parameter. For now, ucf will revert to using
             old-style, non-debconf prompting. Ugh!

             Please inform the package maintainer about this problem.
";
}
if ((-e '/usr/share/debconf/confmodule')) {
if (StringInterpolation(StringInterpolation { parts: [CommandSubstitution(Simple(SimpleCommand { name: Literal("id", None), args: [Literal("-u", None)], redirects: [], env_vars: {}, stdout_used: true, stderr_used: true }))] }, None) eq 0) {
        $main_exit_code = system('.', '/usr/share/debconf/confmodule') >> 8;
if ("$DEBCONF_OK" eq 'YES') {
            $main_exit_code = system('db_x_loadtemplatefile', (do { my $_chomp_temp = do {
    my ($in_68, $out_68);
    my $pid_68 = open3($in_68, $out_68, '>&STDERR', 'dpkg-query', '--control-path', 'ucf', 'templates');
    close $in_68 or croak 'Close failed: $OS_ERROR';
    my $result_68 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_68> };
    close $out_68 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_68, 0;
    $result_68
}; chomp $_chomp_temp; $_chomp_temp; }), 'ucf') >> 8;
        }
}
    else {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "$progname: Not loading confmodule, since we are not running as root.";
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
if ("$DEBCONF_ALREADY_RUNNING" eq 'NO') {
if (!(!(do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
            $main_exit_code = system('db_settitle', 'ucf/title') >> 8;
        };))) {
if (StringInterpolation(StringInterpolation { parts: [CommandSubstitution(Simple(SimpleCommand { name: Literal("id", None), args: [Literal("-u", None)], redirects: [], env_vars: {}, stdout_used: true, stderr_used: true }))] }, None) eq 0) {
                $main_exit_code = system('db_title', "Modified configuration file") >> 8;
}
            else {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    do {
    my $__echo_line = "$progname: Not changing title, since we are not running as root.";
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
        }
    }
}
my $orig_new_file;
my @orig_new_file;
my %orig_new_file;
$orig_new_file = "$new_file";
$newsum = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_69 = q{};
    my $output_printed_69;
    my $pipeline_success_69 = 1;

    my ($in_70, $out_70);
    my $pid_70 = open3($in_70, $out_70, '>&STDERR', 'md5sum', );
    close $in_70 or croak 'Close failed: $OS_ERROR';
    $output_69 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_70> };
    close $out_70 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_70, 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_69 = 0; }
    my @lines = split /\n/msx, $output_69;
    my @result;
    foreach my $line (@lines) {
        chomp $line;
        if ($line =~ /^\s*$/msx) { next; }
        my @fields = split /\s+/msx, $line;
        push @result, ($fields[0] . "\n");
    }
    $output_69 = join "", @result;

    if ( !$pipeline_success_69 ) { $main_exit_code = 1; }
    exit $main_exit_code if $__set_e && $main_exit_code != 0;
    $output_69 =~ s/\n+\z//msx;
    $output_69;
}; $_pipeline_result; };
if ((-e "$dest_file")) {
    $destsum = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_71 = q{};
        my $output_printed_71;
        my $pipeline_success_71 = 1;

        my ($in_72, $out_72);
        my $pid_72 = open3($in_72, $out_72, '>&STDERR', 'md5sum', );
        close $in_72 or croak 'Close failed: $OS_ERROR';
        $output_71 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_72> };
        close $out_72 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_72, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_71 = 0; }
        my @lines = split /\n/msx, $output_71;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\s+/msx, $line;
            push @result, ($fields[0] . "\n");
        }
        $output_71 = join "", @result;

        if ( !$pipeline_success_71 ) { $main_exit_code = 1; }
        exit $main_exit_code if $__set_e && $main_exit_code != 0;
        $output_71 =~ s/\n+\z//msx;
        $output_71;
}; $_pipeline_result; };
if ("X$lastsum" eq "X") {
if (((-d "$old_mdsum_dir") || (-f "$old_mdsum_file"))) {
if ((-d "$old_mdsum_dir")) {
                my $file;
                for my $file ($old_mdsum_dir, '/*') {
                    $oldsum = (do { my $_chomp_temp = do { my @_qx_cmd = (q(awk '{print $1}' $file)); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }; chomp $_chomp_temp; $_chomp_temp; });
if ("$oldsum" eq "$destsum") {
if ("X$force_conffold" eq "X") {
if ("X$VERBOSE" ne "X") {
                                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                                    do {
    my $__echo_line = "Replacing config file $dest_file with new version";
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
                            replace_conf_file();
exit 0;
}
                        else {
                            replace_md5sum();
                            use File::Copy qw(copy);
                            if ( -e q{f} ) {
                                if ( -d "$dest_file." . ${DIST_SUFFIX} ) {
                                    require File::Copy; File::Copy::copy(q{f}, "$dest_file." . ${DIST_SUFFIX} . '/' . (q{f} =~ m|([^/]+)$|)[0]);
                                } else {
                                    require File::Copy; File::Copy::copy(q{f}, "$dest_file." . ${DIST_SUFFIX});
                                }
                            } else {
                                croak "cp: cannot stat '-p': No such file or directory\n";
                            }
                            if ( -e "$orig_new_file" ) {
                                if ( -d "$dest_file." . ${DIST_SUFFIX} ) {
                                    require File::Copy; File::Copy::copy("$orig_new_file", "$dest_file." . ${DIST_SUFFIX} . '/' . ("$orig_new_file" =~ m|([^/]+)$|)[0]);
                                } else {
                                    require File::Copy; File::Copy::copy("$orig_new_file", "$dest_file." . ${DIST_SUFFIX});
                                }
                            } else {
                                croak "cp: cannot stat '-p': No such file or directory\n";
                            }
exit 0;
                        }
                    }
                }
}
            else {
                if ((-f "$old_mdsum_file")) {
                    $oldsum = do {
    local $ENV{destsum} = $destsum;
    local $ENV{old_mdsum_file} = $old_mdsum_file;
    my $command = 'grep -E "^${destsum}" "$old_mdsum_file" || true';
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
};
if ("X$oldsum" ne "X") {
if ("X$force_conffold" eq "X") {
if ("X$VERBOSE" ne "X") {
                                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                                    do {
    my $__echo_line = "Replacing config file $dest_file with new version";
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
                            replace_conf_file();
exit 0;
}
                        else {
                            replace_md5sum();
                            use File::Copy qw(copy);
                            if ( -e q{f} ) {
                                if ( -d "$dest_file." . ${DIST_SUFFIX} ) {
                                    require File::Copy; File::Copy::copy(q{f}, "$dest_file." . ${DIST_SUFFIX} . '/' . (q{f} =~ m|([^/]+)$|)[0]);
                                } else {
                                    require File::Copy; File::Copy::copy(q{f}, "$dest_file." . ${DIST_SUFFIX});
                                }
                            } else {
                                croak "cp: cannot stat '-p': No such file or directory\n";
                            }
                            if ( -e "$orig_new_file" ) {
                                if ( -d "$dest_file." . ${DIST_SUFFIX} ) {
                                    require File::Copy; File::Copy::copy("$orig_new_file", "$dest_file." . ${DIST_SUFFIX} . '/' . ("$orig_new_file" =~ m|([^/]+)$|)[0]);
                                } else {
                                    require File::Copy; File::Copy::copy("$orig_new_file", "$dest_file." . ${DIST_SUFFIX});
                                }
                            } else {
                                croak "cp: cannot stat '-p': No such file or directory\n";
                            }
exit 0;
                        }
                    }
                }
            }
if ("X$VERBOSE" ne "X") {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    print "Historical md5sums did not match.\n";
                };
            }
if ((-d "$old_mdsum_dir")) {
if ((-e "${old_mdsum_dir}/default")) {
if ("X$VERBOSE" ne "X") {
                        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                            print "However, a default entry exists, using it.\n";
                        };
                    }
                    $lastsum = (do { my $_chomp_temp = do { my @_qx_cmd = (q(awk '{print $1;}' $old_mdsum_dir /default)); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }; chomp $_chomp_temp; $_chomp_temp; });
                    $do_replace_md5sum = q{1};
                }
}
            else {
                if ((-f "$old_mdsum_file")) {
                    $oldsum = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_75 = q{};
                    my $output_printed_75;
                    my $output_76 = q{};
                    while (my $line = <>) {
                        chomp $line;
                                                if (!($line =~ /"[[:space:]]default$"/msx)) {
                            next;
                        }
                        # awk doesn't support line-by-line processing
                    }
                    $output_76; };
}; $_pipeline_result; };
if ("X$oldsum" ne "X") {
                        $lastsum = $oldsum;
                        $do_replace_md5sum = q{1};
                    }
                }
            }
        }
if ("X$lastsum" eq "X") {
if ("X$VERBOSE" ne "X") {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    print "No match found, we shall ask.\n";
                };
            }
            $lastsum = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
        }
    }
}
else {
if ("X$lastsum" eq "X") {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "\n";
        };
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "Creating config file $dest_file with new version";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
        replace_conf_file();
exit 0;
}
    else {
        if ("$lastsum" eq "$newsum") {
if ("X$force_conffmiss" ne "X") {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    print "\n";
                };
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    do {
    my $__echo_line = "Recreating deleted config file $dest_file with new version, as asked";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                };
                replace_conf_file();
exit 0;
}
            else {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    do {
    my $__echo_line = "Not replacing deleted config file $dest_file";
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
}
        else {
if ("X$force_conffmiss" ne "X") {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    print "\n";
                };
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    do {
    my $__echo_line = "Recreating deleted config file $dest_file with new version, as asked";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                };
                replace_conf_file();
exit 0;
}
            else {
if ("X$force_conffold" eq "X") {
                    $destsum = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
}
                else {
exit 0;
                }
            }
        }
    }
}
if ("$lastsum" eq "$newsum") {
if ("X$VERBOSE" ne "X") {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "md5sums match, nothing needs be done.\n";
        };
    }
if ("X$do_replace_md5sum" ne "X") {
        replace_md5sum();
    }
exit 0;
}
if ("$destsum" eq "$lastsum") {
if ("X$force_conffold" eq "X") {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "Replacing config file $dest_file with new version";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
        replace_conf_file();
exit 0;
}
    else {
        replace_md5sum();
        use File::Copy qw(copy);
        if ( -e q{f} ) {
            if ( -d "$dest_file." . ${DIST_SUFFIX} ) {
                require File::Copy; File::Copy::copy(q{f}, "$dest_file." . ${DIST_SUFFIX} . '/' . (q{f} =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy(q{f}, "$dest_file." . ${DIST_SUFFIX});
            }
        } else {
            croak "cp: cannot stat '-p': No such file or directory\n";
        }
        if ( -e "$orig_new_file" ) {
            if ( -d "$dest_file." . ${DIST_SUFFIX} ) {
                require File::Copy; File::Copy::copy("$orig_new_file", "$dest_file." . ${DIST_SUFFIX} . '/' . ("$orig_new_file" =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy("$orig_new_file", "$dest_file." . ${DIST_SUFFIX});
            }
        } else {
            croak "cp: cannot stat '-p': No such file or directory\n";
        }
exit 0;
    }
}
else {
if ("X$force_conffnew" ne "X") {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "Replacing config file $dest_file with new version";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        };
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            print "since you asked for it.\n";
        };
if ("$destsum" eq "$newsum") {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                print "The new and the old files are identical, AFAICS\n";
            };
}
        else {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                print "The new and the old files are different\n";
            };
        }
        replace_conf_file();
exit 0;
    }
if ("X$force_conffold" ne "X") {
        replace_md5sum();
        use File::Copy qw(copy);
        if ( -e q{f} ) {
            if ( -d "$dest_file." . ${DIST_SUFFIX} ) {
                require File::Copy; File::Copy::copy(q{f}, "$dest_file." . ${DIST_SUFFIX} . '/' . (q{f} =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy(q{f}, "$dest_file." . ${DIST_SUFFIX});
            }
        } else {
            croak "cp: cannot stat '-p': No such file or directory\n";
        }
        if ( -e "$orig_new_file" ) {
            if ( -d "$dest_file." . ${DIST_SUFFIX} ) {
                require File::Copy; File::Copy::copy("$orig_new_file", "$dest_file." . ${DIST_SUFFIX} . '/' . ("$orig_new_file" =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy("$orig_new_file", "$dest_file." . ${DIST_SUFFIX});
            }
        } else {
            croak "cp: cannot stat '-p': No such file or directory\n";
        }
exit 0;
    }
if ("$newsum" eq "$destsum") {
if ("X$VERBOSE" ne "X") {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                print "md5sums of the file in place matches, nothing needs be done.\n";
            };
        }
        replace_md5sum();
exit 0;
    }
    $main_exit_code = system('done', q{=}, 'NO') >> 8;
while ( "X$done" eq "XNO" ) {
if (("$DEBCONF_OK" eq "YES" && ("$DEBIAN_HAS_FRONTEND"))) {
if (((-e "$statedir/cache/$cached_file") && "X$THREEWAY" ne "X")) {
                my $templ;
                my @templ;
                my %templ;
                $templ = 'ucf/changeprompt_threeway';
}
            else {
                $templ = 'ucf/changeprompt';
            }
if ("X$override_template" ne "X") {
                $choices = (do { my $_chomp_temp = do {
    my ($in_79, $out_79);
    my $pid_79 = open3($in_79, $out_79, '>&STDERR', 'db_metaget', $templ, 'Choices-C');
    close $in_79 or croak 'Close failed: $OS_ERROR';
    my $result_79 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_79> };
    close $out_79 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_79, 0;
    $result_79
}; chomp $_chomp_temp; $_chomp_temp; });
                $choices2 = (do { my $_chomp_temp = do {
    my ($in_80, $out_80);
    my $pid_80 = open3($in_80, $out_80, '>&STDERR', 'db_metaget', $override_template, 'Choices-C');
    close $in_80 or croak 'Close failed: $OS_ERROR';
    my $result_80 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_80> };
    close $out_80 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_80, 0;
    $result_80
}; chomp $_chomp_temp; $_chomp_temp; });
if ("$choices" eq "$choices2") {
                    $templ = $override_template;
                }
            }
            $main_exit_code = system('db_fset', "$templ", 'seen', 'false') >> 8;
            $main_exit_code = system('db_reset', "$templ") >> 8;
            $main_exit_code = system('db_subst', "$templ", 'FILE', "$dest_file") >> 8;
            $main_exit_code = system('db_subst', "$templ", 'NEW', "$new_file") >> 8;
            $main_exit_code = system('db_subst', "$templ", 'BASENAME', (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename($dest_file); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; })) >> 8;
                        $main_exit_code = system('db_input', 'critical', "$templ") >> 8;
            if ($CHILD_ERROR != 0) {
                1;
            }
if (!(!($main_exit_code = system('bash', 'db_go') >> 8;))) {
next;
            }
            $main_exit_code = system('db_get', "$templ") >> 8;
            my $ANSWER;
            my @ANSWER;
            my %ANSWER;
            $ANSWER = "$ENV{RET}";
}
        else {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                print "Need debconf to interact\n";
            };
exit 2;
        }
if ("$ANSWER" =~ /^install_new$/msx or "$ANSWER" =~ /^y$/msx or "$ANSWER" =~ /^Y$/msx or "$ANSWER" =~ /^I$/msx or "$ANSWER" =~ /^i$/msx) {
                        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "Replacing config file $dest_file with new version";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
            };
                        my $RETAIN_OLD;
            my @RETAIN_OLD;
            my %RETAIN_OLD;
            $RETAIN_OLD = 'YES';
                        replace_conf_file();
            exit 0;
        } elsif ("$ANSWER" =~ /^diff$/msx or "$ANSWER" =~ /^D$/msx or "$ANSWER" =~ /^d$/msx) {
                        my $DIFF;
            my @DIFF;
            my %DIFF;
            $DIFF = (do { my $_chomp_temp = do {
    my ($in_82, $out_82);
    my $pid_82 = open3($in_82, $out_82, '>&STDERR', 'run_diff', 'diff', '-u', 'Bbwt', "$dest_file", "$new_file");
    close $in_82 or croak 'Close failed: $OS_ERROR';
    my $result_82 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_82> };
    close $out_82 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_82, 0;
    $result_82
}; chomp $_chomp_temp; $_chomp_temp; });
                        show_diff("$DIFF");
        } elsif ("$ANSWER" =~ /^sdiff$/msx or "$ANSWER" =~ /^S$/msx or "$ANSWER" =~ /^s$/msx) {
                        $DIFF = (do { my $_chomp_temp = do {
    my ($in_83, $out_83);
    my $pid_83 = open3($in_83, $out_83, '>&STDERR', 'run_diff', 'sdiff', '-BbW', "$dest_file", "$new_file");
    close $in_83 or croak 'Close failed: $OS_ERROR';
    my $result_83 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_83> };
    close $out_83 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_83, 0;
    $result_83
}; chomp $_chomp_temp; $_chomp_temp; });
                        show_diff("$DIFF");
        } elsif ("$ANSWER" =~ /^diff_threeway$/msx or "$ANSWER" =~ /^3$/msx or "$ANSWER" =~ /^t$/msx or "$ANSWER" =~ /^T$/msx) {
            if (((-e "$statedir/cache/$cached_file") && "X$THREEWAY" ne "X")) {
if ((-e "$dest_file")) {
                                        $DIFF = (do { my $_chomp_temp = do {
    my ($in_84, $out_84);
    my $pid_84 = open3($in_84, $out_84, '>&STDERR', 'diff3', '-L', 'Current', '-L', 'Older', '-L', 'New', '-A', "$dest_file", "$statedir/cache/$cached_file", "$new_file");
    close $in_84 or croak 'Close failed: $OS_ERROR';
    my $result_84 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_84> };
    close $out_84 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_84, 0;
    $result_84
}; chomp $_chomp_temp; $_chomp_temp; });
                    if ($CHILD_ERROR != 0) {
                        1;
                    }
}
                else {
                                        $DIFF = (do { my $_chomp_temp = do {
    my ($in_86, $out_86);
    my $pid_86 = open3($in_86, $out_86, '>&STDERR', 'diff3', '-L', 'Current', '-L', 'Older', '-L', 'New', '-A', '/dev/null', "$statedir/cache/$cached_file", "$new_file");
    close $in_86 or croak 'Close failed: $OS_ERROR';
    my $result_86 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_86> };
    close $out_86 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_86, 0;
    $result_86
}; chomp $_chomp_temp; $_chomp_temp; });
                    if ($CHILD_ERROR != 0) {
                        1;
                    }
                }
                show_diff("$DIFF");
}
            else {
                $DIFF = (do { my $_chomp_temp = do {
    my ($in_88, $out_88);
    my $pid_88 = open3($in_88, $out_88, '>&STDERR', 'run_diff', 'diff', '-u', 'Bbwt', "$dest_file", "$new_file");
    close $in_88 or croak 'Close failed: $OS_ERROR';
    my $result_88 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_88> };
    close $out_88 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_88, 0;
    $result_88
}; chomp $_chomp_temp; $_chomp_temp; });
                show_diff("$DIFF");
            }
        } elsif ("$ANSWER" =~ /^merge_threeway$/msx or "$ANSWER" =~ /^M$/msx or "$ANSWER" =~ /^m$/msx) {
                        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                print "Merging changes into the new version\n";
            };
            if (((-e "$statedir/cache/$cached_file") && "X$THREEWAY" ne "X")) {
                my $ret;
                my @ret;
                my %ret;
                $ret = q{0};
                                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', "$dest_file." . ${NEW_SUFFIX}
      or die "Cannot access file: $OS_ERROR\n";
                    my $tmp = do {
                    $main_exit_code = system('diff3', '-L', 'Current', '-L', 'Older', '-L', 'New', '-m', "$dest_file", "$statedir/cache/$cached_file", "$new_file") >> 8;
                    };
                    print $tmp;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
                if ($CHILD_ERROR != 0) {
                                        $ret = $?;
                }
if ("$ret" =~ /^0$/msx) {
                                        $new_file = "$dest_file." . ${NEW_SUFFIX};
                                        $RETAIN_OLD = 'YES';
                                        replace_conf_file();
                    if ( -e "$dest_file." . ${NEW_SUFFIX} ) {
                        if ( -d "$dest_file." . ${NEW_SUFFIX} ) {
                            carp "rm: carping: ", "$dest_file." . ${NEW_SUFFIX},
          " is a directory (use -r to remove recursively)\n";
                        }
                        else {
                            if ( unlink "$dest_file." . ${NEW_SUFFIX} ) {
                                                            }
                            else {
                                carp "rm: carping: could not remove ", "$dest_file." . ${NEW_SUFFIX},
              ": $OS_ERROR\n";
                            }
                        }
                    }
                    else {
                        local $CHILD_ERROR = 0;
                    }
                    exit 0;
                } elsif (1) {
                                        my $err;
                    my $force = 0;
                    if ( -e "$dest_file." . ${NEW_SUFFIX} ) {
                        my $dest = "$dest_file." . ${ERR_SUFFIX};
                        if ( -e $dest && -d $dest ) {
                            my $source_name = "$dest_file." . ${NEW_SUFFIX};
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
                        if ( File::Copy::move( "$dest_file." . ${NEW_SUFFIX}, $dest ) ) {
                        } else {
                            croak
  "mv: cannot move "$dest_file." . ${NEW_SUFFIX} to $dest: $ERRNO\n";
                        }
                    } else {
                        croak "mv: "$dest_file." . ${NEW_SUFFIX}: No such file or directory\n";
                    }
                                        $main_exit_code = system('db_subst', 'ucf/conflicts_found', 'dest_file', "$dest_file") >> 8;
                                        $main_exit_code = system('db_subst', 'ucf/conflicts_found', 'ERR_SUFFIX', ${ERR_SUFFIX}) >> 8;
                                                            $main_exit_code = system('db_input', 'critical', 'ucf/conflicts_found') >> 8;
                    if ($CHILD_ERROR != 0) {
                        1;
                    }
                                                            $main_exit_code = system('bash', 'db_go') >> 8;
                    if ($CHILD_ERROR != 0) {
                        1;
                    }
                }
}
            else {
                replace_conf_file();
if ( -e "$dest_file." . ${NEW_SUFFIX} ) {
                    if ( -d "$dest_file." . ${NEW_SUFFIX} ) {
                        carp "rm: carping: ", "$dest_file." . ${NEW_SUFFIX},
          " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink "$dest_file." . ${NEW_SUFFIX} ) {
                                                    }
                        else {
                            carp "rm: carping: could not remove ", "$dest_file." . ${NEW_SUFFIX},
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 0;
                }
exit 0;
            }
        } elsif ("$ANSWER" =~ /^shell$/msx or "$ANSWER" =~ /^Z$/msx or "$ANSWER" =~ /^z$/msx) {
            if (!(            # Original bash: ps -o stat= --ppid $$ | grep -q '+';
{
                my $output_92 = q{};
                my $output_printed_92;
                my $pipeline_success_92 = 1;
                                my ($in_93, $out_93);
                my $pid_93 = open3($in_93, $out_93, '>&STDERR', 'ps', '-o', 'stat', q{=}, '--ppid');
                close $in_93 or croak 'Close failed: $OS_ERROR';
                $output_92 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_93> };
                close $out_93 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_93, 0;

                                my $grep_result_92_1;
                my @grep_lines_92_1 = split /\n/msx, $output_92;
                my @grep_filtered_92_1 = grep { /+/msx } @grep_lines_92_1;
                $grep_result_92_1 = join "\n", @grep_filtered_92_1;
                if (!($grep_result_92_1 =~ m{\n\z}msx || $grep_result_92_1 eq q{})) {
                $grep_result_92_1 .= "\n";
                }
                $CHILD_ERROR = scalar @grep_filtered_92_1 > 0 ? 0 : 1;
                $grep_result_92_1 = q{};
                $output_92 = q{};
                if ((scalar @grep_filtered_92_1) == 0) {
                    $pipeline_success_92 = 0;
                }
                if ($output_92 ne q{} && !defined $output_printed_92) {
                    print $output_92;
                    if (!($output_92 =~ m{\n\z}msx)) {
                        print "\n";
                    }
                }
                if ( !$pipeline_success_92 ) { $main_exit_code = 1; }
                })) {
$ENV{UCF_CONFFILE_OLD} = '';
$ENV{UCF_CONFFILE_NEW} = '';
                open STDIN, '<', '/dev/tty' or croak "Cannot read file: $OS_ERROR\n";
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', '/dev/tty'
      or die "Cannot access file: $OS_ERROR\n";
                    my $tmp = do {
                    $main_exit_code = system('bash', 'bash') >> 8;
                    };
                    print $tmp;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
                if ($CHILD_ERROR != 0) {
                    1;
                }
}
            else {
                if ("$DISPLAY" ne q{}) {
                                        $main_exit_code = system('bash', 'x-terminal-emulator') >> 8;
                    if ($CHILD_ERROR != 0) {
                        1;
                    }
}
                else {
                    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                        print "No terminal, and no DISPLAY set, can't fork shell.\n";
                    };
require Time::HiRes; Time::HiRes::sleep(q{3});
                }
            }
        } elsif ("$ANSWER" =~ /^keep_current$/msx or "$ANSWER" =~ /^n$/msx or "$ANSWER" =~ /^N$/msx or "$ANSWER" =~ /^o$/msx or "$ANSWER" =~ /^O$/msx or "$ANSWER" =~ /^$/msx) {
                        replace_md5sum();
                        use File::Copy qw(copy);
            if ( -e q{f} ) {
                if ( -d "$dest_file." . ${DIST_SUFFIX} ) {
                    require File::Copy; File::Copy::copy(q{f}, "$dest_file." . ${DIST_SUFFIX} . '/' . (q{f} =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy(q{f}, "$dest_file." . ${DIST_SUFFIX});
                }
            } else {
                croak "cp: cannot stat '-p': No such file or directory\n";
            }
            if ( -e "$orig_new_file" ) {
                if ( -d "$dest_file." . ${DIST_SUFFIX} ) {
                    require File::Copy; File::Copy::copy("$orig_new_file", "$dest_file." . ${DIST_SUFFIX} . '/' . ("$orig_new_file" =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy("$orig_new_file", "$dest_file." . ${DIST_SUFFIX});
                }
            } else {
                croak "cp: cannot stat '-p': No such file or directory\n";
            }
            exit 0;
        } elsif (1) {
            if ("$DEBCONF_OK" eq "YES") {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    do {
    my $__echo_line = "Error: unknown response from debconf:'$ENV{RET}'";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                };
exit 1;
}
            else {
                print "\n";
                $CHILD_ERROR = 0;
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    print "Please answer with one of the single letters listed.\n";
                };
                print "\n";
                $CHILD_ERROR = 0;
            }
        }
    }
}
$main_exit_code = system('bash', 'db_stop') >> 8;
exit 0;

exit $main_exit_code;
