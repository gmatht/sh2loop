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

my $MAGIC_3 = 3;

my $progname;
my @progname;
my %progname;
$progname = $PROGRAM_NAME;
my $package;
my @package;
my %package;
$package = 'gettext-tools';
my $version;
my @version;
my %version;
$version = '0.21';
my $archive_version;
my @archive_version;
my %archive_version;
$archive_version = '0.21';
my $prefix;
my @prefix;
my %prefix;
$prefix = "/usr";
my $datarootdir;
my @datarootdir;
my %datarootdir;
$datarootdir = ${prefix} . "/share";
$main_exit_code = system(':', $gettext_datadir="${datarootdir}/gettext") >> 8;
$main_exit_code = system(':', $AUTOM4TE=autom4te) >> 8;

sub func_tmpdir {
    $main_exit_code = system(':', $TMPDIR=/tmp) >> 8;
                if (do {
if (do {
my $tmp;
my @tmp;
my %tmp;
$tmp = do { my @_qx_cmd = ("(umask 077 && mktemp -d \"$TMPDIR/gtXXXXXX\") 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('test', '-n', "$tmp") >> 8;
}
            $CHILD_ERROR == 0
        }) {
                        $main_exit_code = system('test', '-d', "$tmp") >> 8;
        }
    if ($CHILD_ERROR != 0) {
                    $tmp = $TMPDIR;
            $main_exit_code = system('/gt', $$, q{-}, $RANDOM) >> 8;
            do {
                local %ENV = %ENV;
                my $datarootdir = $datarootdir;
                my $package = $package;
                my $tmp = $tmp;
                my $progname = $progname;
                my $version = $version;
                my $archive_version = $archive_version;
                my $prefix = $prefix;
                if (do {
$main_exit_code = system('umask', '077') >> 8;
                    $CHILD_ERROR == 0
                }) {
                                        use File::Path qw(make_path);
                    my $err;
                    if ( mkdir "$tmp" ) {
                        }
                    else {
                        croak "mkdir: cannot create directory " . "$tmp" . ": File exists\n";
                    }
                }
                q{};
            };
    }
    if ($CHILD_ERROR != 0) {
                    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "$PROGRAM_NAME: cannot create a temporary directory in $ENV{TMPDIR}";
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
                    local %ENV = %ENV;
                    my $archive_version = $archive_version;
                    my $prefix = $prefix;
                    my $datarootdir = $datarootdir;
                    my $package = $package;
                    my $err = $err;
                    my $progname = $progname;
                    my $version = $version;
                    my $tmp = $tmp;
exit 1;
                    q{};
                };
exit 1;
    }
    return;
}

sub func_find_curr_installdir {
    my $curr_executable;
    my @curr_executable;
    my %curr_executable;
    $curr_executable = "$PROGRAM_NAME";
if ("$curr_executable" =~ /^.*/.*$/msx or "$curr_executable" =~ /^.*\\.*$/msx) {
    } elsif (1) {
                my $save_IFS;
        my @save_IFS;
        my %save_IFS;
        $save_IFS = "$ENV{IFS}";
                my $IFS;
        my @IFS;
        my %IFS;
        $IFS = substr($ENV{PATH_SEPARATOR='}, ');
                my $dir;
        for my $dir ($PATH) {
            $IFS = "$save_IFS";
            if (do {
$main_exit_code = system('test', '-z', "$dir") >> 8;
                $CHILD_ERROR == 0
            }) {
                                $dir = q{.};
            }
            my $exec_ext;
            for my $exec_ext (q{}) {
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("dir"), Literal("/"), Variable("curr_executable"), Variable("exec_ext")] }, None)')) {
                    $curr_executable = "$dir/$curr_executable$exec_ext";
last LABEL2;
                }
            }
        }
                $IFS = "$save_IFS";
    }
if ("$curr_executable" =~ /^/.*$/msx or "$curr_executable" =~ /^.:/.*$/msx or "$curr_executable" =~ /^.:\\.*$/msx) {
    } elsif (1) {
                $curr_executable = do { use Cwd; getcwd(); };
                $main_exit_code = system('/', "$curr_executable") >> 8;
    }
    my $sed_dirname;
    my @sed_dirname;
    my %sed_dirname;
    $sed_dirname = 's,/[^/]*$,,';
    my $sed_linkdest;
    my @sed_linkdest;
    my %sed_linkdest;
    $sed_linkdest = "s,^.* -> \\(.*\\),\\1,p";
while (     $main_exit_code = system('bash', ':') >> 8 ) {
        my $lsline;
        my @lsline;
        my %lsline;
        $lsline = do { my @_qx_cmd = ('ls -l "$curr_executable"'); my $result = qx{$_qx_cmd[0]}; $CHILD_ERROR = $? >> 8; $result; };
if ("$lsline" =~ /^.*" -> ".*$/msx) {
                        my $linkdest;
            my @linkdest;
            my %linkdest;
            $linkdest = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_1 = q{};
                my $output_printed_1;
                my $pipeline_success_1 = 1;
                $output_1 .= $lsline . "\n";
                if ( !($output_1 =~ m{\n\z}msx) ) { $output_1 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_1 = 0; }
                my @sed_lines_1 = split /\n/msx, $output_1;
                my @sed_result_1;
                foreach my $line (@sed_lines_1) {
                chomp $line;
                push @sed_result_1, $line;
                }
                $output_1 = join "\n", @sed_result_1;

                if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
                $output_1 =~ s/\n+\z//msx;
                $output_1;
}; $_pipeline_result; };
            if ("$linkdest" =~ /^/.*$/msx or "$linkdest" =~ /^.:/.*$/msx or "$linkdest" =~ /^.:\\.*$/msx) {
                                $curr_executable = "$linkdest";
            } elsif (1) {
                                $curr_executable = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                    my $output_2 = q{};
                    my $output_printed_2;
                    my $pipeline_success_2 = 1;
                    $output_2 .= $curr_executable . "\n";
                    if ( !($output_2 =~ m{\n\z}msx) ) { $output_2 .= "\n"; }
                    $CHILD_ERROR = 0;
                    if ($CHILD_ERROR != 0) { $pipeline_success_2 = 0; }
                    my @sed_lines_2 = split /\n/msx, $output_2;
                    my @sed_result_2;
                    foreach my $line (@sed_lines_2) {
                    chomp $line;
                    push @sed_result_2, $line;
                    }
                    $output_2 = join "\n", @sed_result_2;

                    if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
                    $output_2 =~ s/\n+\z//msx;
                    $output_2;
}; $_pipeline_result; };
                                $main_exit_code = system('/', "$linkdest") >> 8;
            }
        } elsif (1) {
            last;        }
    }
    my $curr_installdir;
    my @curr_installdir;
    my %curr_installdir;
    $curr_installdir = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_3 = q{};
        my $output_printed_3;
        my $pipeline_success_3 = 1;
        $output_3 .= $curr_executable . "\n";
        if ( !($output_3 =~ m{\n\z}msx) ) { $output_3 .= "\n"; }
        $CHILD_ERROR = 0;
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
    $curr_installdir = do {
    my $left_result_4 = do { chdir("$curr_installdir"); q{} };
;
    if ( $CHILD_ERROR == 0 ) {
        my $right_result_4 = do { use Cwd; getcwd(); };
        $left_result_4 . $right_result_4;
    } else {
        q{};
    }
};
    return;
}

sub func_find_prefixes {
    my $orig_installprefix;
    my @orig_installprefix;
    my %orig_installprefix;
    $orig_installprefix = "$ENV{orig_installdir}";
    my $curr_installprefix;
    my @curr_installprefix;
    my %curr_installprefix;
    $curr_installprefix = "$ENV{curr_installdir}";
while ( 1 ) {
        my $orig_last;
        my @orig_last;
        my %orig_last;
        $orig_last = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_6 = q{};
            my $output_printed_6;
            my $pipeline_success_6 = 1;
            $output_6 .= $orig_installprefix . "\n";
            if ( !($output_6 =~ m{\n\z}msx) ) { $output_6 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_6 = 0; }
            my @sed_lines_6 = split /\n/msx, $output_6;
            my @sed_result_6;
            foreach my $line (@sed_lines_6) {
            chomp $line;
            push @sed_result_6, $line;
            }
            $output_6 = join "\n", @sed_result_6;

            if ( !$pipeline_success_6 ) { $main_exit_code = 1; }
            $output_6 =~ s/\n+\z//msx;
            $output_6;
}; $_pipeline_result; };
        my $curr_last;
        my @curr_last;
        my %curr_last;
        $curr_last = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_7 = q{};
            my $output_printed_7;
            my $pipeline_success_7 = 1;
            $output_7 .= $curr_installprefix . "\n";
            if ( !($output_7 =~ m{\n\z}msx) ) { $output_7 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_7 = 0; }
            my @sed_lines_7 = split /\n/msx, $output_7;
            my @sed_result_7;
            foreach my $line (@sed_lines_7) {
            chomp $line;
            push @sed_result_7, $line;
            }
            $output_7 = join "\n", @sed_result_7;

            if ( !$pipeline_success_7 ) { $main_exit_code = 1; }
            $output_7 =~ s/\n+\z//msx;
            $output_7;
}; $_pipeline_result; };
if ((!(        $main_exit_code = system('test', '-z', "$orig_last") >> 8) || !(        $main_exit_code = system('test', '-z', "$curr_last") >> 8))) {
last;
        }
if ((!StringInterpolation(StringInterpolation { parts: [Variable("orig_last")] }, None) eq StringInterpolation(StringInterpolation { parts: [Variable("curr_last")] }, None))) {
last;
        }
        $orig_installprefix = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_8 = q{};
            my $output_printed_8;
            my $pipeline_success_8 = 1;
            $output_8 .= $orig_installprefix . "\n";
            if ( !($output_8 =~ m{\n\z}msx) ) { $output_8 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_8 = 0; }
            my @sed_lines_8 = split /\n/msx, $output_8;
            my @sed_result_8;
            foreach my $line (@sed_lines_8) {
            chomp $line;
            push @sed_result_8, $line;
            }
            $output_8 = join "\n", @sed_result_8;

            if ( !$pipeline_success_8 ) { $main_exit_code = 1; }
            $output_8 =~ s/\n+\z//msx;
            $output_8;
}; $_pipeline_result; };
        $curr_installprefix = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_9 = q{};
            my $output_printed_9;
            my $pipeline_success_9 = 1;
            $output_9 .= $curr_installprefix . "\n";
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
    }
    return;
}
if (StringInterpolation(StringInterpolation { parts: [Literal("no")] }, None) eq yes) {
    my $exec_prefix;
    my @exec_prefix;
    my %exec_prefix;
    $exec_prefix = ${prefix};
    my $bindir;
    my @bindir;
    my %bindir;
    $bindir = ${exec_prefix} . "/bin";
    my $orig_installdir;
    my @orig_installdir;
    my %orig_installdir;
    $orig_installdir = "$bindir";
    func_find_curr_installdir();
    func_find_prefixes();
    my $gettext_datadir;
    my @gettext_datadir;
    my %gettext_datadir;
    $gettext_datadir = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_10 = q{};
        my $output_printed_10;
        my $pipeline_success_10 = 1;
        $output_10 .= "$gettext_datadir/\n";
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
}

sub func_trace_autoconf {
    # Original bash: echo '\
{
        my $output_11 = q{};
        my $output_printed_11;
        my $pipeline_success_11 = 1;
        $output_11 .= "\ndnl replace macros which may abort autom4te with a no-op variant\nm4_pushdef([m4_assert])\nm4_pushdef([m4_fatal])\nm4_pushdef([m4_warn])\nm4_pushdef([m4_errprintn])\nm4_pushdef([m4_exit])\nm4_pushdef([m4_include])\nm4_pushdef([m4_esyscmd])\n";
if ( !($output_11 =~ m{\n\z}msx) ) { $output_11 .= "\n"; }
$CHILD_ERROR = 0;

                my $cmd_13 = 'unknown_command';
        my ($in_12, $out_12);
        my $pid_12 = open3($in_12, $out_12, '>&STDERR', $cmd_13, '--no-cache', '--language=Autoconf-without-aclocal-m4', '--trace=$1', ":\\$%", q{-});
        print {$in_12} $output_11;
        close $in_12 or croak 'Close failed: $OS_ERROR';
        $output_11 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_12> };
        close $out_12 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_12, 0;
        if ($output_11 ne q{} && !defined $output_printed_11) {
            print $output_11;
            if (!($output_11 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_11 ) { $main_exit_code = 1; }
        }
    return;
}

sub func_trace_sed {
    my ($file) = @_;
    my $sed_extract_arguments;
    my @sed_extract_arguments;
    my %sed_extract_arguments;
    $sed_extract_arguments = "
s,#.*$,,; s,^dnl .*$,,; s, dnl .*$,,;
/(/ {
  ta
  :a
    s/)/)/
    tb
    s/\\\\$//
    N
    ba
  :b
  s,^.*([[ ]*\\([^]\"$" . chr(96) . "\\\\)]*\\).*$,\\1,p
}
d";
my @sed_lines_14 = split /\n/msx, $;
my @sed_result_14;
foreach my $line (@sed_lines_14) {
chomp $line;
push @sed_result_14, $line;
}
$ = join "\n", @sed_result_14;

    return;
}

sub func_usage {
    print "\
Usage: gettextize [OPTION]... [package-dir]

Prepares a source package to use gettext.

Options:
      --help           print this help and exit
      --version        print version information and exit
  -f, --force          force writing of new files even if old exist
      --po-dir=DIR     specify directory with PO files
      --no-changelog   don't update or create ChangeLog files
      --symlink        make symbolic links instead of copying files
  -n, --dry-run        print modifications but don't perform them

Report bugs in the bug tracker at <https://savannah.gnu.org/projects/gettext>
or by email to <bug-gettext@gnu.org>.\n";
    return;
}

sub func_version {
    do {
    my $__echo_line = "$progname (GNU $package) $version";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    print "Copyright (C) 1995-2020 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <https://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.\n";
    print "Written by" . q{ } . "Ulrich Drepper" . "\n";
    $CHILD_ERROR = 0;
    return;
}

sub func_fatal_error {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "gettextize: *** $_[0]";
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
        print "gettextize: *** Stop.\n";
    };
exit 1;
    return;
}
if (do {
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        do {
            local %ENV = %ENV;
            my $orig_installdir = $orig_installdir;
            my $archive_version = $archive_version;
            my $prefix = $prefix;
            my $gettext_datadir = $gettext_datadir;
            my $datarootdir = $datarootdir;
            my $package = $package;
            my $progname = $progname;
            my $version = $version;
            my $exec_prefix = $exec_prefix;
            my $bindir = $bindir;
delete $ENV{CDPATH};
            q{};
        };
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
} == 0) {
    delete $ENV{CDPATH};
}
my $CLICOLOR_FORCE;
my @CLICOLOR_FORCE;
my %CLICOLOR_FORCE;
$CLICOLOR_FORCE = q{};
my $GREP_OPTIONS;
my @GREP_OPTIONS;
my %GREP_OPTIONS;
$GREP_OPTIONS = q{};
undef $CLICOLOR_FORCE;
delete $ENV{CLICOLOR_FORCE};
undef $GREP_OPTIONS;
delete $ENV{GREP_OPTIONS};
    my $force;
    my @force;
    my %force;
    $force = q{0};
    my $intldir;
    my @intldir;
    my %intldir;
    $intldir = q{};
    my $podirs;
    my @podirs;
    my %podirs;
    $podirs = q{};
    my $try_ln_s;
    my @try_ln_s;
    my %try_ln_s;
    $try_ln_s = 'false';
    my $do_changelog;
    my @do_changelog;
    my %do_changelog;
    $do_changelog = q{:};
    my $doit;
    my @doit;
    my %doit;
    $doit = q{:};
    my $# = 0;
while ( (Variable("#", false, None) > 0) ) {
if ("$_[0]" =~ /^-c$/msx or "$_[0]" =~ /^--copy$/msx or "$_[0]" =~ /^--cop$/msx or "$_[0]" =~ /^--co$/msx or "$_[0]" =~ /^--c$/msx) {
            # Builtin command 'shift' not implemented
        } elsif ("$_[0]" =~ /^-n$/msx or "$_[0]" =~ /^--dry-run$/msx or "$_[0]" =~ /^--dry-ru$/msx or "$_[0]" =~ /^--dry-r$/msx or "$_[0]" =~ /^--dry-$/msx or "$_[0]" =~ /^--dry$/msx or "$_[0]" =~ /^--dr$/msx or "$_[0]" =~ /^--d$/msx) {
            # Builtin command 'shift' not implemented
                        $doit = 'false';
        } elsif ("$_[0]" =~ /^-f$/msx or "$_[0]" =~ /^--force$/msx or "$_[0]" =~ /^--forc$/msx or "$_[0]" =~ /^--for$/msx or "$_[0]" =~ /^--fo$/msx or "$_[0]" =~ /^--f$/msx) {
            # Builtin command 'shift' not implemented
                        $force = q{1};
        } elsif ("$_[0]" =~ /^--help$/msx or "$_[0]" =~ /^--hel$/msx or "$_[0]" =~ /^--he$/msx or "$_[0]" =~ /^--h$/msx) {
                        func_usage();
            exit 0;
        } elsif ("$_[0]" =~ /^--intl$/msx or "$_[0]" =~ /^--int$/msx or "$_[0]" =~ /^--in$/msx or "$_[0]" =~ /^--i$/msx) {
            # Builtin command 'shift' not implemented
                        $intldir = 'yes';
        } elsif ("$_[0]" =~ /^--po-dir$/msx or "$_[0]" =~ /^--po-di$/msx or "$_[0]" =~ /^--po-d$/msx or "$_[0]" =~ /^--po-$/msx or "$_[0]" =~ /^--po$/msx or "$_[0]" =~ /^--p$/msx) {
            # Builtin command 'shift' not implemented
            if (Variable("#", false, None) eq 0) {
                func_fatal_error("missing argument for --po-dir");
            }
            if ("$_[0]" =~ /^-.*$/msx) {
                                func_fatal_error("missing argument for --po-dir");
            }
                        $podirs = "$podirs $_[0]";
            # Builtin command 'shift' not implemented
        } elsif ("$_[0]" =~ /^--po-dir=.*$/msx) {
                        my $arg;
            my @arg;
            my %arg;
            $arg = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_15 = q{};
                my $output_printed_15;
                my $pipeline_success_15 = 1;
                $output_15 .= "X$_[0]\n";
                if ( !($output_15 =~ m{\n\z}msx) ) { $output_15 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_15 = 0; }
                my @sed_lines_15 = split /\n/msx, $output_15;
                my @sed_result_15;
                foreach my $line (@sed_lines_15) {
                chomp $line;
                push @sed_result_15, $line;
                }
                $output_15 = join "\n", @sed_result_15;

                if ( !$pipeline_success_15 ) { $main_exit_code = 1; }
                $output_15 =~ s/\n+\z//msx;
                $output_15;
}; $_pipeline_result; };
                        $podirs = "$podirs $arg";
            # Builtin command 'shift' not implemented
        } elsif ("$_[0]" =~ /^--no-changelog$/msx or "$_[0]" =~ /^--no-changelo$/msx or "$_[0]" =~ /^--no-changel$/msx or "$_[0]" =~ /^--no-change$/msx or "$_[0]" =~ /^--no-chang$/msx or "$_[0]" =~ /^--no-chan$/msx or "$_[0]" =~ /^--no-cha$/msx or "$_[0]" =~ /^--no-ch$/msx or "$_[0]" =~ /^--no-c$/msx) {
            # Builtin command 'shift' not implemented
                        $do_changelog = 'false';
        } elsif ("$_[0]" =~ /^--symlink$/msx or "$_[0]" =~ /^--symlin$/msx or "$_[0]" =~ /^--symli$/msx or "$_[0]" =~ /^--syml$/msx or "$_[0]" =~ /^--sym$/msx or "$_[0]" =~ /^--sy$/msx or "$_[0]" =~ /^--s$/msx) {
            # Builtin command 'shift' not implemented
                        $try_ln_s = q{:};
        } elsif ("$_[0]" =~ /^--version$/msx or "$_[0]" =~ /^--versio$/msx or "$_[0]" =~ /^--versi$/msx or "$_[0]" =~ /^--vers$/msx or "$_[0]" =~ /^--ver$/msx or "$_[0]" =~ /^--ve$/msx or "$_[0]" =~ /^--v$/msx) {
                        func_version();
            exit 0;
        } elsif ("$_[0]" =~ /^--$/msx) {
            # Builtin command 'shift' not implemented
            last;        } elsif ("$_[0]" =~ /^-.*$/msx) {
                        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "gettextize: unknown option $_[0]";
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
                print "Try 'gettextize --help' for more information.\n";
            };
            exit 1;
        } elsif (1) {
            last;        }
    }
        $main_exit_code = system('test', '-n', "$podirs") >> 8;
    if ($CHILD_ERROR != 0) {
                $podirs = "po";
    }
if (StringInterpolation(StringInterpolation { parts: [Variable("intldir")] }, None) ne q{}) {
    func_fatal_error("The option '--intl' is no longer available.");
}
my $have_automake19;
my @have_automake19;
my %have_automake19;
$have_automake19 = q{};
if (!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
    do {
        local %ENV = %ENV;
        my $# = $#;
        my $do_changelog = $do_changelog;
        my $archive_version = $archive_version;
        my $prefix = $prefix;
        my $gettext_datadir = $gettext_datadir;
        my $package = $package;
        my $force = $force;
        my $version = $version;
        my $bindir = $bindir;
        my $have_automake19 = $have_automake19;
        my $podirs = $podirs;
        my $orig_installdir = $orig_installdir;
        my $try_ln_s = $try_ln_s;
        my $arg = $arg;
        my $CLICOLOR_FORCE = $CLICOLOR_FORCE;
        my $datarootdir = $datarootdir;
        my $GREP_OPTIONS = $GREP_OPTIONS;
        my $intldir = $intldir;
        my $progname = $progname;
        my $exec_prefix = $exec_prefix;
        my $doit = $doit;
        $main_exit_code = system('aclocal', '--version') >> 8;
        q{};
    };
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
})) {
    my $aclocal_version;
    my @aclocal_version;
    my %aclocal_version;
    $aclocal_version = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_16 = q{};
        my $output_printed_16;
        my $pipeline_success_16 = 1;

        my ($in_17, $out_17);
        my $pid_17 = open3($in_17, $out_17, '>&STDERR', 'aclocal', '--version');
        close $in_17 or croak 'Close failed: $OS_ERROR';
        $output_16 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_17> };
        close $out_17 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_17, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_16 = 0; }
        my @sed_lines_16 = split /\n/msx, $output_16;
        my @sed_result_16;
        foreach my $line (@sed_lines_16) {
        chomp $line;
        push @sed_result_16, $line;
        }
        $output_16 = join "\n", @sed_result_16;

        my @sed_lines_16 = split /\n/msx, $output_16;
        my @sed_result_16;
        foreach my $line (@sed_lines_16) {
        chomp $line;
        push @sed_result_16, $line;
        }
        $output_16 = join "\n", @sed_result_16;

        if ( !$pipeline_success_16 ) { $main_exit_code = 1; }
        $output_16 =~ s/\n+\z//msx;
        $output_16;
}; $_pipeline_result; };
if ($aclocal_version =~ /^1.9.*$/msx or $aclocal_version =~ /^1.\[1-9\]\[0-9\].*$/msx or $aclocal_version =~ /^\[2-9\].*$/msx) {
                $have_automake19 = 'yes';
    }
}
if (StringInterpolation(StringInterpolation { parts: [Variable("have_automake19")] }, None) eq q{}) {
    func_fatal_error("You need the 'aclocal' program from automake 1.9 or newer.");
}
my $min_automake_version;
my @min_automake_version;
my %min_automake_version;
$min_automake_version = '1.9';
if ((Variable("#", false, None) > 1)) {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            func_usage();
        };
exit 1;
    }
    my $origdir;
    my @origdir;
    my %origdir;
    $origdir = do { use Cwd; getcwd(); };
if ((Variable("#", false, None) == 1)) {
        my $srcdir;
        my @srcdir;
        my %srcdir;
        $srcdir = $1;
if (!(        chdir("$srcdir");
        $CHILD_ERROR = 0)) {
            $srcdir = do { use Cwd; getcwd(); };
}
        else {
            func_fatal_error("Cannot change directory to '$srcdir'.");
        }
}
    else {
        $srcdir = $origdir;
    }
$main_exit_code = system('test', '-f', 'configure.', 'in') >> 8;
if ($CHILD_ERROR != 0) {
        $main_exit_code = system('test', '-f', 'configure.ac') >> 8;
}
if ($CHILD_ERROR != 0) {
        func_fatal_error("Missing configure.in or configure.ac, please cd to your package first.");
}
my $configure_in;
my @configure_in;
my %configure_in;
$configure_in = 'NONE';
if ((-f 'configure. in')) {
    $configure_in = 'configure.';
    $main_exit_code = system('bash', 'in') >> 8;
}
else {
if ((-f 'configure.ac')) {
        $configure_in = 'configure.ac';
    }
}
if ((Variable("force", false, None) == 0)) {
if ((-d 'intl')) {
        func_fatal_error("intl/ subdirectory exists: use option -f if you really want to delete it.");
    }
    my $podir;
    for my $podir ($podirs) {
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("podir"), Literal("/Makefile.in.in")] }, None)')) {
            func_fatal_error("$podir/Makefile.in.in exists: use option -f if you really want to delete it.");
        }
    }
if ((-f 'ABOUT-NLS')) {
        func_fatal_error("ABOUT-NLS exists: use option -f if you really want to delete it.");
    }
}
if (!(# Original bash: echo "AC_PREREQ([2.69])" \
{
    my $output_18 = q{};
    my $output_printed_18;
    my $pipeline_success_18 = 1;
    $output_18 .= 'AC_PREREQ([2.69])' . "\n";
if ( !($output_18 =~ m{\n\z}msx) ) { $output_18 .= "\n"; }
$CHILD_ERROR = 0;

        my $cmd_20 = 'unknown_command';
    my ($in_19, $out_19);
    my $pid_19 = open3($in_19, $out_19, '>&STDERR', $cmd_20, '--no-cache', '--language=Autoconf-without-aclocal-m4', q{-});
    print {$in_19} $output_18;
    close $in_19 or croak 'Close failed: $OS_ERROR';
    $output_18 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_19> };
    close $out_19 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_19, 0;
    if ($output_18 ne q{} && !defined $output_printed_18) {
        print $output_18;
        if (!($output_18 =~ m{\n\z}msx)) {
            print "\n";
        }
    }
    if ( !$pipeline_success_18 ) { $main_exit_code = 1; }
    })) {
    my $func_trace;
    my @func_trace;
    my %func_trace;
    $func_trace = 'func_trace_autoconf';
}
else {
    $func_trace = 'func_trace_sed';
}
my $auxdir;
my @auxdir;
my %auxdir;
$auxdir = do {
    my ($in_21, $out_21);
    my $pid_21 = open3($in_21, $out_21, '>&STDERR', "$func_trace", 'AC_CONFIG_AUX_DIR', "$configure_in");
    close $in_21 or croak 'Close failed: $OS_ERROR';
    my $result_21 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_21> };
    close $out_21 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_21, 0;
    $result_21
};
if (StringInterpolation(StringInterpolation { parts: [Variable("auxdir")] }, None) ne q{}) {
    $auxdir = "$auxdir/";
}
my $macrodirs;
my @macrodirs;
my %macrodirs;
$macrodirs = do {
    my ($in_22, $out_22);
    my $pid_22 = open3($in_22, $out_22, '>&STDERR', "$func_trace", 'AC_CONFIG_MACRO_DIR_TRACE', "$configure_in");
    close $in_22 or croak 'Close failed: $OS_ERROR';
    my $result_22 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_22> };
    close $out_22 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_22, 0;
    $result_22
};
if (StringInterpolation(StringInterpolation { parts: [Variable("macrodirs")] }, None) eq q{}) {
    $macrodirs = do {
    my ($in_23, $out_23);
    my $pid_23 = open3($in_23, $out_23, '>&STDERR', "$func_trace", 'AC_CONFIG_MACRO_DIR', "$configure_in");
    close $in_23 or croak 'Close failed: $OS_ERROR';
    my $result_23 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_23> };
    close $out_23 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_23, 0;
    $result_23
};
}
for my $arg ($macrodirs) {
    my $m4dir;
    my @m4dir;
    my %m4dir;
    $m4dir = "$arg";
last;
}
chdir("$gettext_datadir");
$CHILD_ERROR = 0;
if ($CHILD_ERROR != 0) {
        func_fatal_error("gettext source directory '" . ${gettext_datadir} . "' doesn't exist");
}
my $added_directories;
my @added_directories;
my %added_directories;
$added_directories = q{};
my $removed_directory;
my @removed_directory;
my %removed_directory;
$removed_directory = q{};
my $added_extradist;
my @added_extradist;
my %added_extradist;
$added_extradist = q{};
my $added_acoutput;
my @added_acoutput;
my %added_acoutput;
$added_acoutput = q{};
my $removed_acoutput;
my @removed_acoutput;
my %removed_acoutput;
$removed_acoutput = " intl/intlh.inst";
my $please;
my @please;
my %please;
$please = q{};
my $date;
my @date;
my %date;
$date = do {
require POSIX; POSIX::strftime('%Y-%m-%d', localtime(time())) . "\n"
};

sub func_copy {
    my ($file) = @_;
if (!(    $CHILD_ERROR = 0)) {
if ( -e "$srcdir/$_[1]" ) {
            if ( -d "$srcdir/$_[1]" ) {
                carp "rm: carping: ", "$srcdir/$_[1]",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$srcdir/$_[1]" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$srcdir/$_[1]",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
        do {
    my $__echo_line = "Copying file $_[1]";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        use File::Copy qw(copy);
        if ( -e "$_[0]" ) {
            if ( -d "$srcdir/$_[1]" ) {
                require File::Copy; File::Copy::copy("$_[0]", "$srcdir/$_[1]" . '/' . ("$_[0]" =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy("$_[0]", "$srcdir/$_[1]");
            }
        } else {
            croak "cp: cannot stat '$1': No such file or directory\n";
        }
}
    else {
        do {
    my $__echo_line = "Copy file $_[1]";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
    return;
}

sub func_linkorcopy {
    my ($file) = @_;
if (!(    $CHILD_ERROR = 0)) {
if ( -e "$srcdir/$_[2]" ) {
            if ( -d "$srcdir/$_[2]" ) {
                carp "rm: carping: ", "$srcdir/$_[2]",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$srcdir/$_[2]" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$srcdir/$_[2]",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
            do {
                local %ENV = %ENV;
                my $archive_version = $archive_version;
                my $added_directories = $added_directories;
                my $force = $force;
                my $configure_in = $configure_in;
                my $added_extradist = $added_extradist;
                my $have_automake19 = $have_automake19;
                my $func_trace = $func_trace;
                my $arg = $arg;
                my $datarootdir = $datarootdir;
                my $GREP_OPTIONS = $GREP_OPTIONS;
                my $intldir = $intldir;
                my $m4dir = $m4dir;
                my $macrodirs = $macrodirs;
                my $progname = $progname;
                my $# = $#;
                my $srcdir = $srcdir;
                my $doit = $doit;
                my $please = $please;
                my $do_changelog = $do_changelog;
                my $prefix = $prefix;
                my $gettext_datadir = $gettext_datadir;
                my $removed_directory = $removed_directory;
                my $added_acoutput = $added_acoutput;
                my $package = $package;
                my $date = $date;
                my $version = $version;
                my $bindir = $bindir;
                my $podir = $podir;
                my $podirs = $podirs;
                my $orig_installdir = $orig_installdir;
                my $try_ln_s = $try_ln_s;
                my $CLICOLOR_FORCE = $CLICOLOR_FORCE;
                my $min_automake_version = $min_automake_version;
                my $auxdir = $auxdir;
                my $removed_acoutput = $removed_acoutput;
                my $origdir = $origdir;
                my $exec_prefix = $exec_prefix;
                my $aclocal_version = $aclocal_version;
                if (do {
if (do {
$CHILD_ERROR = 0;
    $CHILD_ERROR == 0
}) {
    symlink "$_[1]", "$srcdir/$_[2]" or warn "symlink failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
}
                    $CHILD_ERROR == 0
                }) {
                                        do {
    my $__echo_line = "Symlinking file $_[2]";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                }
                q{};
            };
        };
        if ($CHILD_ERROR != 0) {
                            do {
    my $__echo_line = "Copying file $_[2]";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                use File::Copy qw(copy);
                if ( -e "$_[0]" ) {
                    if ( -d "$srcdir/$_[2]" ) {
                        require File::Copy; File::Copy::copy("$_[0]", "$srcdir/$_[2]" . '/' . ("$_[0]" =~ m|([^/]+)$|)[0]);
                    } else {
                        require File::Copy; File::Copy::copy("$_[0]", "$srcdir/$_[2]");
                    }
                } else {
                    croak "cp: cannot stat '$1': No such file or directory\n";
                }
        }
}
    else {
if (!(        $CHILD_ERROR = 0)) {
            do {
    my $__echo_line = "Symlink file $_[2]";
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
            do {
    my $__echo_line = "Copy file $_[2]";
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
    return;
}

sub func_backup {
    my ($file) = @_;
if (!(    $CHILD_ERROR = 0)) {
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("srcdir"), Literal("/"), Variable("1")] }, None)')) {
if ( -e "$srcdir/$_[0]~" ) {
                if ( -d "$srcdir/$_[0]~" ) {
                    carp "rm: carping: ", "$srcdir/$_[0]~",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$srcdir/$_[0]~" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "$srcdir/$_[0]~",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
            use File::Copy qw(copy);
            if ( -e "$srcdir/$_[0]" ) {
                if ( -d "$srcdir/$_[0]~" ) {
                    require File::Copy; File::Copy::copy("$srcdir/$_[0]", "$srcdir/$_[0]~" . '/' . ("$srcdir/$_[0]" =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy("$srcdir/$_[0]", "$srcdir/$_[0]~");
                }
            } else {
                croak "cp: cannot stat '-p': No such file or directory\n";
            }
        }
    }
    return;
}

sub func_remove {
    my ($file) = @_;
if (!(    $CHILD_ERROR = 0)) {
        do {
    my $__echo_line = "Removing $_[0]";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
if ( -e "$srcdir/$_[0]" ) {
            if ( -d "$srcdir/$_[0]" ) {
                carp "rm: carping: ", "$srcdir/$_[0]",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$srcdir/$_[0]" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$srcdir/$_[0]",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
}
    else {
        do {
    my $__echo_line = "Remove $_[0]";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
    }
    return;
}

sub func_ChangeLog_init {
    my $modified_ChangeLog;
    my @modified_ChangeLog;
    my %modified_ChangeLog;
    $modified_ChangeLog = q{};
    return;
}

sub func_ChangeLog_add_entry {
if (!(    $CHILD_ERROR = 0)) {
if (StringInterpolation(StringInterpolation { parts: [Variable("modified_ChangeLog")] }, None) eq q{}) {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', "$srcdir/ChangeLog.tmp"
      or die "Cannot open file: $OS_ERROR\n";
                do {
    my $__echo_line = "$date  gettextize  <bug-gnu-gettext@gnu.org>";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "$srcdir/ChangeLog.tmp"
      or die "Cannot open file: $OS_ERROR\n";
                print "\n";
                $CHILD_ERROR = 0;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            my $modified_ChangeLog;
            my @modified_ChangeLog;
            my %modified_ChangeLog;
            $modified_ChangeLog = 'yes';
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', "$srcdir/ChangeLog.tmp"
      or die "Cannot open file: $OS_ERROR\n";
            print $1;
if ( !( ($1) =~ m{\n\z}msx ) ) { print "\n"; }
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
}
    else {
        $modified_ChangeLog = 'yes';
    }
    return;
}

sub func_ChangeLog_finish {
if (StringInterpolation(StringInterpolation { parts: [Variable("modified_ChangeLog")] }, None) ne q{}) {
if (!(        $CHILD_ERROR = 0)) {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "$srcdir/ChangeLog.tmp"
      or die "Cannot open file: $OS_ERROR\n";
                print "\n";
                $CHILD_ERROR = 0;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("srcdir"), Literal("/ChangeLog")] }, None)')) {
                print "Adding an entry to ChangeLog (backup is in ChangeLog~)\n";
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>>', "$srcdir/ChangeLog.tmp"
      or die "Cannot open file: $OS_ERROR\n";
print do { my $cat_chunk = q{}; if ( open my $fh, '<', "$srcdir/ChangeLog" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$srcdir/ChangeLog" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
if ( -e "$srcdir/ChangeLog~" ) {
                    if ( -d "$srcdir/ChangeLog~" ) {
                        carp "rm: carping: ", "$srcdir/ChangeLog~",
          " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink "$srcdir/ChangeLog~" ) {
                                                    }
                        else {
                            carp "rm: carping: could not remove ", "$srcdir/ChangeLog~",
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 0;
                }
                use File::Copy qw(copy);
                if ( -e "$srcdir/ChangeLog" ) {
                    if ( -d "$srcdir/ChangeLog~" ) {
                        require File::Copy; File::Copy::copy("$srcdir/ChangeLog", "$srcdir/ChangeLog~" . '/' . ("$srcdir/ChangeLog" =~ m|([^/]+)$|)[0]);
                    } else {
                        require File::Copy; File::Copy::copy("$srcdir/ChangeLog", "$srcdir/ChangeLog~");
                    }
                } else {
                    croak "cp: cannot stat '-p': No such file or directory\n";
                }
}
            else {
                print "Creating ChangeLog\n";
            }
            use File::Copy qw(copy);
            if ( -e "$srcdir/ChangeLog.tmp" ) {
                if ( -d "$srcdir/ChangeLog" ) {
                    require File::Copy; File::Copy::copy("$srcdir/ChangeLog.tmp", "$srcdir/ChangeLog" . '/' . ("$srcdir/ChangeLog.tmp" =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy("$srcdir/ChangeLog.tmp", "$srcdir/ChangeLog");
                }
            } else {
                croak "cp: cannot stat '$srcdir/ChangeLog.tmp': No such file or directory\n";
            }
if ( -e "$srcdir/ChangeLog.tmp" ) {
                if ( -d "$srcdir/ChangeLog.tmp" ) {
                    carp "rm: carping: ", "$srcdir/ChangeLog.tmp",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$srcdir/ChangeLog.tmp" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "$srcdir/ChangeLog.tmp",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
}
        else {
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("srcdir"), Literal("/ChangeLog")] }, None)')) {
                print "Add an entry to ChangeLog\n";
}
            else {
                print "Create ChangeLog\n";
            }
        }
    }
    return;
}

sub func_poChangeLog_init {
    my $modified_poChangeLog;
    my @modified_poChangeLog;
    my %modified_poChangeLog;
    $modified_poChangeLog = q{};
    return;
}

sub func_poChangeLog_add_entry {
if (!(    $CHILD_ERROR = 0)) {
if (StringInterpolation(StringInterpolation { parts: [Variable("modified_poChangeLog")] }, None) eq q{}) {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', "$srcdir/$podir/ChangeLog.tmp"
      or die "Cannot open file: $OS_ERROR\n";
                do {
    my $__echo_line = "$date  gettextize  <bug-gnu-gettext@gnu.org>";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "$srcdir/$podir/ChangeLog.tmp"
      or die "Cannot open file: $OS_ERROR\n";
                print "\n";
                $CHILD_ERROR = 0;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            my $modified_poChangeLog;
            my @modified_poChangeLog;
            my %modified_poChangeLog;
            $modified_poChangeLog = 'yes';
        }
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', "$srcdir/$podir/ChangeLog.tmp"
      or die "Cannot open file: $OS_ERROR\n";
            print $1;
if ( !( ($1) =~ m{\n\z}msx ) ) { print "\n"; }
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
}
    else {
        $modified_poChangeLog = 'yes';
    }
    return;
}

sub func_poChangeLog_finish {
if (StringInterpolation(StringInterpolation { parts: [Variable("modified_poChangeLog")] }, None) ne q{}) {
if (!(        $CHILD_ERROR = 0)) {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "$srcdir/$podir/ChangeLog.tmp"
      or die "Cannot open file: $OS_ERROR\n";
                print "\n";
                $CHILD_ERROR = 0;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("srcdir"), Literal("/"), Variable("podir"), Literal("/ChangeLog")] }, None)')) {
                do {
    my $__echo_line = "Adding an entry to $podir/ChangeLog (backup is in $podir/ChangeLog~)";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>>', "$srcdir/$podir/ChangeLog.tmp"
      or die "Cannot open file: $OS_ERROR\n";
print do { my $cat_chunk = q{}; if ( open my $fh, '<', "$srcdir/$podir/ChangeLog" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$srcdir/$podir/ChangeLog" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
if ( -e "$srcdir/$podir/ChangeLog~" ) {
                    if ( -d "$srcdir/$podir/ChangeLog~" ) {
                        carp "rm: carping: ", "$srcdir/$podir/ChangeLog~",
          " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink "$srcdir/$podir/ChangeLog~" ) {
                                                    }
                        else {
                            carp "rm: carping: could not remove ", "$srcdir/$podir/ChangeLog~",
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 0;
                }
                use File::Copy qw(copy);
                if ( -e "$srcdir/$podir/ChangeLog" ) {
                    if ( -d "$srcdir/$podir/ChangeLog~" ) {
                        require File::Copy; File::Copy::copy("$srcdir/$podir/ChangeLog", "$srcdir/$podir/ChangeLog~" . '/' . ("$srcdir/$podir/ChangeLog" =~ m|([^/]+)$|)[0]);
                    } else {
                        require File::Copy; File::Copy::copy("$srcdir/$podir/ChangeLog", "$srcdir/$podir/ChangeLog~");
                    }
                } else {
                    croak "cp: cannot stat '-p': No such file or directory\n";
                }
}
            else {
                do {
    my $__echo_line = "Creating $podir/ChangeLog";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
            }
            use File::Copy qw(copy);
            if ( -e "$srcdir/$podir/ChangeLog.tmp" ) {
                if ( -d "$srcdir/$podir/ChangeLog" ) {
                    require File::Copy; File::Copy::copy("$srcdir/$podir/ChangeLog.tmp", "$srcdir/$podir/ChangeLog" . '/' . ("$srcdir/$podir/ChangeLog.tmp" =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy("$srcdir/$podir/ChangeLog.tmp", "$srcdir/$podir/ChangeLog");
                }
            } else {
                croak "cp: cannot stat '$srcdir/$podir/ChangeLog.tmp': No such file or directory\n";
            }
if ( -e "$srcdir/$podir/ChangeLog.tmp" ) {
                if ( -d "$srcdir/$podir/ChangeLog.tmp" ) {
                    carp "rm: carping: ", "$srcdir/$podir/ChangeLog.tmp",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$srcdir/$podir/ChangeLog.tmp" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "$srcdir/$podir/ChangeLog.tmp",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
}
        else {
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("srcdir"), Literal("/"), Variable("podir"), Literal("/ChangeLog")] }, None)')) {
                do {
    my $__echo_line = "Add an entry to $podir/ChangeLog";
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
                do {
    my $__echo_line = "Create $podir/ChangeLog";
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
    }
    return;
}

sub func_m4ChangeLog_init {
if (StringInterpolation(StringInterpolation { parts: [Variable("using_m4ChangeLog")] }, None) ne q{}) {
        my $modified_m4ChangeLog;
        my @modified_m4ChangeLog;
        my %modified_m4ChangeLog;
        $modified_m4ChangeLog = q{};
        my $created_m4ChangeLog;
        my @created_m4ChangeLog;
        my %created_m4ChangeLog;
        $created_m4ChangeLog = q{};
    }
    return;
}

sub func_m4ChangeLog_add_entry {
if (StringInterpolation(StringInterpolation { parts: [Variable("using_m4ChangeLog")] }, None) ne q{}) {
if (!(        $CHILD_ERROR = 0)) {
if (StringInterpolation(StringInterpolation { parts: [Variable("modified_m4ChangeLog")] }, None) eq q{}) {
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', "$srcdir/$m4dir/ChangeLog.tmp"
      or die "Cannot open file: $OS_ERROR\n";
                    do {
    my $__echo_line = "$date  gettextize  <bug-gnu-gettext@gnu.org>";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>>', "$srcdir/$m4dir/ChangeLog.tmp"
      or die "Cannot open file: $OS_ERROR\n";
                    print "\n";
                    $CHILD_ERROR = 0;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
                my $modified_m4ChangeLog;
                my @modified_m4ChangeLog;
                my %modified_m4ChangeLog;
                $modified_m4ChangeLog = 'yes';
            }
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', "$srcdir/$m4dir/ChangeLog.tmp"
      or die "Cannot open file: $OS_ERROR\n";
                print $1;
if ( !( ($1) =~ m{\n\z}msx ) ) { print "\n"; }
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
}
        else {
            $modified_m4ChangeLog = 'yes';
        }
}
    else {
        my $line;
        my @line;
        my %line;
        $line = "$_[0]";
        $line = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_34 = q{};
            my $output_printed_34;
            my $pipeline_success_34 = 1;
            $output_34 .= $line . "\n";
            if ( !($output_34 =~ m{\n\z}msx) ) { $output_34 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_34 = 0; }
            my @sed_lines_34 = split /\n/msx, $output_34;
            my @sed_result_34;
            foreach my $line (@sed_lines_34) {
            chomp $line;
            push @sed_result_34, $line;
            }
            $output_34 = join "\n", @sed_result_34;

            if ( !$pipeline_success_34 ) { $main_exit_code = 1; }
            $output_34 =~ s/\n+\z//msx;
            $output_34;
}; $_pipeline_result; };
        func_ChangeLog_add_entry("$line");
    }
    return;
}

sub func_m4ChangeLog_finish {
if (StringInterpolation(StringInterpolation { parts: [Variable("using_m4ChangeLog")] }, None) ne q{}) {
if (StringInterpolation(StringInterpolation { parts: [Variable("modified_m4ChangeLog")] }, None) ne q{}) {
if (!(            $CHILD_ERROR = 0)) {
                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>>', "$srcdir/$m4dir/ChangeLog.tmp"
      or die "Cannot open file: $OS_ERROR\n";
                    print "\n";
                    $CHILD_ERROR = 0;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                };
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("srcdir"), Literal("/"), Variable("m4dir"), Literal("/ChangeLog")] }, None)')) {
                    do {
    my $__echo_line = "Adding an entry to $m4dir/ChangeLog (backup is in $m4dir/ChangeLog~)";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                    do {
                        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>>', "$srcdir/$m4dir/ChangeLog.tmp"
      or die "Cannot open file: $OS_ERROR\n";
print do { my $cat_chunk = q{}; if ( open my $fh, '<', "$srcdir/$m4dir/ChangeLog" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$srcdir/$m4dir/ChangeLog" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
                        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                    };
if ( -e "$srcdir/$m4dir/ChangeLog~" ) {
                        if ( -d "$srcdir/$m4dir/ChangeLog~" ) {
                            carp "rm: carping: ", "$srcdir/$m4dir/ChangeLog~",
          " is a directory (use -r to remove recursively)\n";
                        }
                        else {
                            if ( unlink "$srcdir/$m4dir/ChangeLog~" ) {
                                                            }
                            else {
                                carp "rm: carping: could not remove ", "$srcdir/$m4dir/ChangeLog~",
              ": $OS_ERROR\n";
                            }
                        }
                    }
                    else {
                        local $CHILD_ERROR = 0;
                    }
                    use File::Copy qw(copy);
                    if ( -e "$srcdir/$m4dir/ChangeLog" ) {
                        if ( -d "$srcdir/$m4dir/ChangeLog~" ) {
                            require File::Copy; File::Copy::copy("$srcdir/$m4dir/ChangeLog", "$srcdir/$m4dir/ChangeLog~" . '/' . ("$srcdir/$m4dir/ChangeLog" =~ m|([^/]+)$|)[0]);
                        } else {
                            require File::Copy; File::Copy::copy("$srcdir/$m4dir/ChangeLog", "$srcdir/$m4dir/ChangeLog~");
                        }
                    } else {
                        croak "cp: cannot stat '-p': No such file or directory\n";
                    }
}
                else {
                    do {
    my $__echo_line = "Creating $m4dir/ChangeLog";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                    my $created_m4ChangeLog;
                    my @created_m4ChangeLog;
                    my %created_m4ChangeLog;
                    $created_m4ChangeLog = 'yes';
                }
                use File::Copy qw(copy);
                if ( -e "$srcdir/$m4dir/ChangeLog.tmp" ) {
                    if ( -d "$srcdir/$m4dir/ChangeLog" ) {
                        require File::Copy; File::Copy::copy("$srcdir/$m4dir/ChangeLog.tmp", "$srcdir/$m4dir/ChangeLog" . '/' . ("$srcdir/$m4dir/ChangeLog.tmp" =~ m|([^/]+)$|)[0]);
                    } else {
                        require File::Copy; File::Copy::copy("$srcdir/$m4dir/ChangeLog.tmp", "$srcdir/$m4dir/ChangeLog");
                    }
                } else {
                    croak "cp: cannot stat '$srcdir/$m4dir/ChangeLog.tmp': No such file or directory\n";
                }
if ( -e "$srcdir/$m4dir/ChangeLog.tmp" ) {
                    if ( -d "$srcdir/$m4dir/ChangeLog.tmp" ) {
                        carp "rm: carping: ", "$srcdir/$m4dir/ChangeLog.tmp",
          " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink "$srcdir/$m4dir/ChangeLog.tmp" ) {
                                                    }
                        else {
                            carp "rm: carping: could not remove ", "$srcdir/$m4dir/ChangeLog.tmp",
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 0;
                }
}
            else {
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("srcdir"), Literal("/"), Variable("m4dir"), Literal("/ChangeLog")] }, None)')) {
                    do {
    my $__echo_line = "Add an entry to $m4dir/ChangeLog";
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
                    do {
    my $__echo_line = "Create $m4dir/ChangeLog";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                    $created_m4ChangeLog = 'yes';
                }
            }
        }
    }
    return;
}
my $using_m4ChangeLog;
my @using_m4ChangeLog;
my %using_m4ChangeLog;
$using_m4ChangeLog = 'yes';
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("srcdir"), Literal("/intl/Makefile.in")] }, None)')) {
    $removed_acoutput = "$removed_acoutput intl/Makefile";
}
if ((-d 'StringInterpolation(StringInterpolation { parts: [Variable("srcdir"), Literal("/intl")] }, None)')) {
if (!(    $CHILD_ERROR = 0)) {
        print "Wiping out intl/ subdirectory\n";
        do {
            local %ENV = %ENV;
            my $archive_version = $archive_version;
            my $added_directories = $added_directories;
            my $force = $force;
            my $configure_in = $configure_in;
            my $added_extradist = $added_extradist;
            my $have_automake19 = $have_automake19;
            my $func_trace = $func_trace;
            my $arg = $arg;
            my $datarootdir = $datarootdir;
            my $GREP_OPTIONS = $GREP_OPTIONS;
            my $intldir = $intldir;
            my $m4dir = $m4dir;
            my $macrodirs = $macrodirs;
            my $progname = $progname;
            my $# = $#;
            my $srcdir = $srcdir;
            my $doit = $doit;
            my $please = $please;
            my $do_changelog = $do_changelog;
            my $prefix = $prefix;
            my $gettext_datadir = $gettext_datadir;
            my $removed_directory = $removed_directory;
            my $added_acoutput = $added_acoutput;
            my $package = $package;
            my $date = $date;
            my $version = $version;
            my $bindir = $bindir;
            my $using_m4ChangeLog = $using_m4ChangeLog;
            my $podir = $podir;
            my $podirs = $podirs;
            my $orig_installdir = $orig_installdir;
            my $try_ln_s = $try_ln_s;
            my $CLICOLOR_FORCE = $CLICOLOR_FORCE;
            my $min_automake_version = $min_automake_version;
            my $auxdir = $auxdir;
            my $removed_acoutput = $removed_acoutput;
            my $origdir = $origdir;
            my $exec_prefix = $exec_prefix;
            my $aclocal_version = $aclocal_version;
            if (do {
chdir("$srcdir/intl");
$CHILD_ERROR = 0;
                $CHILD_ERROR == 0
            }) {
                                my $f;
                for my $f (q{*}) {
if ((!(                    $main_exit_code = system('test', 'CVS', q{!}, q{=}, "$f") >> 8) && !(                    $main_exit_code = system('test', 'RCS', q{!}, q{=}, "$f") >> 8))) {
if ( -e "$f" ) {
                            if ( -d "$f" ) {
                                my $err;
                                require File::Path;
                                File::Path::remove_tree("$f", {error => \$err});
                                if (@{$err}) {
                                    carp "rm: carping: could not remove ", "$f", ": $err->[0]\n";
                                }
                                else {
                                                                    }
                            }
                            else {
                                if ( unlink "$f" ) {
                                                                    }
                                else {
                                    carp "rm: carping: could not remove ", "$f",
              ": $OS_ERROR\n";
                                }
                            }
                        }
                        else {
                            local $CHILD_ERROR = 0;
                        }
                    }
                }
            }
            q{};
        };
}
    else {
        print "Wipe out intl/ subdirectory\n";
    }
    $removed_directory = 'intl';
}
if (do {
$CHILD_ERROR = 0;
    $CHILD_ERROR == 0
}) {
        func_ChangeLog_init();
}
for my $podir ($podirs) {
        $main_exit_code = system('test', '-d', "$srcdir/$podir") >> 8;
    if ($CHILD_ERROR != 0) {
        if (!(            $CHILD_ERROR = 0)) {
                do {
    my $__echo_line = "Creating $podir/ subdirectory";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                                use File::Path qw(make_path);
                my $err;
                if ( mkdir "$srcdir/$podir" ) {
                    }
                else {
                    croak "mkdir: cannot create directory " . "$srcdir/$podir" . ": File exists\n";
                }
                if ($CHILD_ERROR != 0) {
                                        func_fatal_error("failed to create $podir/ subdirectory");
                }
}
            else {
                do {
    my $__echo_line = "Create $podir/ subdirectory";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
            }
            $added_directories = "$added_directories $podir";
    }
}
$main_exit_code = system('test', '-d', "$srcdir/$auxdir") >> 8;
if ($CHILD_ERROR != 0) {
    if (!(        $CHILD_ERROR = 0)) {
            do {
    my $__echo_line = "Creating $auxdir subdirectory";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
                        use File::Path qw(make_path);
            if ( mkdir "$srcdir/$auxdir" ) {
                }
            else {
                croak "mkdir: cannot create directory " . "$srcdir/$auxdir" . ": File exists\n";
            }
            if ($CHILD_ERROR != 0) {
                                func_fatal_error("failed to create $auxdir subdirectory");
            }
}
        else {
            do {
    my $__echo_line = "Create $auxdir subdirectory";
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
my $file;
for my $file (q{*}) {
if ($file =~ /^ABOUT-NLS$/msx) {
                func_linkorcopy($file, "$gettext_datadir/$file", $file);
    } elsif ($file =~ /^config.rpath$/msx) {
                func_linkorcopy($file, "$gettext_datadir/$file", "$auxdir$file");
    }
}
my $external;
my @external;
my %external;
$external = q{};
my $xargs;
my @xargs;
my %xargs;
$xargs = do {
    my ($in_40, $out_40);
    my $pid_40 = open3($in_40, $out_40, '>&STDERR', 'func_trace_sed', 'AM_GNU_GETTEXT', "$srcdir/$configure_in");
    close $in_40 or croak 'Close failed: $OS_ERROR';
    my $result_40 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_40> };
    close $out_40 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_40, 0;
    $result_40
};
my $save_IFS;
my @save_IFS;
my %save_IFS;
$save_IFS = "$ENV{IFS}";
my $IFS;
my @IFS;
my %IFS;
$IFS = q{:};
for my $arg ($xargs) {
if (external eq StringInterpolation(StringInterpolation { parts: [Variable("arg")] }, None)) {
        $external = 'yes';
last;
    }
}
$IFS = "$save_IFS";
if (StringInterpolation(StringInterpolation { parts: [Variable("external")] }, None) eq q{}) {
    $please = "$please
Please use AM_GNU_GETTEXT([external]) in order to cause autoconfiguration
to look for an external libintl.
";
}
if (!(# Original bash: sed -e 's,#.*$,,; s,^dnl .*$,,; s, dnl .*$,,' "$srcdir/$configure_in" | grep AM_GNU_GETTEXT_INTL_SUBDIR >/dev/null;
{
    my $output_41 = q{};
    my $output_printed_41;
    my $pipeline_success_41 = 1;
        my @sed_lines_41 = split /\n/msx, $;
    my @sed_result_41;
    foreach my $line (@sed_lines_41) {
    chomp $line;
    push @sed_result_41, $line;
    }
    $ = join "\n", @sed_result_41;

        do {
    open my $original_stdout, '>&', STDOUT
    or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
    or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    my $tmp_redirect_42 = q{};
    my $grep_result_43;
    my @grep_lines_43 = split /\n/msx, $output_41;
    my @grep_filtered_43 = grep { /AM_GNU_GETTEXT_INTL_SUBDIR/msx } @grep_lines_43;
    $grep_result_43 = join "\n", @grep_filtered_43;
    if (!($grep_result_43 =~ m{\n\z}msx || $grep_result_43 eq q{})) {
    $grep_result_43 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_43 > 0 ? 0 : 1;
    $tmp_redirect_42 = $grep_result_43;
    $tmp_redirect_42;
    };
    print $tmp;
    if ($tmp eq q{}) { print $output_41; }
    $output_printed_41 = 1;
    open STDOUT, '>&', $original_stdout
    or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
    or die "Close failed: $OS_ERROR\n";
    };
    if ( !$pipeline_success_41 ) { $main_exit_code = 1; }
    })) {
    $please = "$please
Please remove the invocation of AM_GNU_GETTEXT_INTL_SUBDIR.
";
}
chdir('po');
$CHILD_ERROR = 0;
for my $podir ($podirs) {
    if (do {
$CHILD_ERROR = 0;
        $CHILD_ERROR == 0
    }) {
                func_poChangeLog_init();
    }
    for my $file ('Makefile.', 'in', q{.}, 'in') {
        my $same;
        my @same;
        my %same;
        $same = 'no';
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("srcdir"), Literal("/"), Variable("podir"), Literal("/"), Variable("file")] }, None)')) {
if (!(            $main_exit_code = system('cmp', '-s', $file, "$srcdir/$podir/$file") >> 8)) {
                $same = 'yes';
            }
}
        else {
            $added_acoutput = "$added_acoutput $podir/Makefile.in";
        }
if ((!(        $CHILD_ERROR = 0) && !(        $main_exit_code = system('test', $same, q{=}, 'no') >> 8))) {
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("srcdir"), Literal("/"), Variable("podir"), Literal("/"), Variable("file")] }, None)')) {
                func_poChangeLog_add_entry("	* $file: Upgrade to gettext-" . ${version} . ".");
}
            else {
                func_poChangeLog_add_entry("	* $file: New file, from gettext-" . ${version} . ".");
            }
        }
        func_backup("$podir/$file");
        func_linkorcopy($file, "$gettext_datadir/po/$file", "$podir/$file");
    }
    for my $file (q{*}) {
if ($file =~ /^Makefile.in.in$/msx) {
        } elsif ($file =~ /^Makevars.template$/msx) {
                        func_linkorcopy('Makevars.template', "$gettext_datadir/po/Makevars.template", "$podir/Makevars.template");
            if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("srcdir"), Literal("/po/Makevars")] }, None)')) {
                    my $LC_ALL = q{C};
                    # Original bash: sed -n -e 's/[ 	]*\([A-Za-z0-9_]*\)[ 	]*=.*/\1/p' < "$srcdir/$podir/Makevars" | LC_ALL=C sort > "$srcdir/$podir/Makevars.tmp1"
{
                        my $output_44 = q{};
                        my $output_printed_44;
                        my $pipeline_success_44 = 1;
                                                $output = q{};
                        open STDIN, '<', "$srcdir/$podir/Makevars" or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_45 = q{};
my @sed_lines_46 = split /\n/msx, $output_44;
my @sed_result_46;
foreach my $line (@sed_lines_46) {
chomp $line;
push @sed_result_46, $line;
}
$output_44 = join "\n", @sed_result_46;

$tmp_redirect_45;
                        $output_44 = $output;

                                                do {
                        open my $original_stdout, '>&', STDOUT
                        or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>', "$srcdir/$podir/Makevars.tmp1"
                        or die "Cannot open file: $OS_ERROR\n";
                        my $tmp = do {
                        my $tmp_redirect_47 = q{};
                        my @sort_lines_48 = split /\n/msx, $output_44;
                        my @sort_sorted_48 = sort @sort_lines_48;
                        $tmp_redirect_47 = join "\n", @sort_sorted_48;
                        if ($tmp_redirect_47 ne q{} && !($tmp_redirect_47 =~ m{\n\z}msx)) {
                        $tmp_redirect_47 .= "\n";
                        }
                        $output_44 = $tmp_redirect_47;
                        $tmp_redirect_47;
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
                        }
                    $LC_ALL = q{C};
                    # Original bash: sed -n -e 's/[ 	]*\([A-Za-z0-9_]*\)[ 	]*=.*/\1/p' < "$gettext_datadir/po/Makevars.template" | LC_ALL=C sort > "$srcdir/$podir/Makevars.tmp2"
{
                        my $output_49 = q{};
                        my $output_printed_49;
                        my $pipeline_success_49 = 1;
                                                $output = q{};
                        open STDIN, '<', "$gettext_datadir/po/Makevars.template" or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_50 = q{};
my @sed_lines_51 = split /\n/msx, $output_49;
my @sed_result_51;
foreach my $line (@sed_lines_51) {
chomp $line;
push @sed_result_51, $line;
}
$output_49 = join "\n", @sed_result_51;

$tmp_redirect_50;
                        $output_49 = $output;

                                                do {
                        open my $original_stdout, '>&', STDOUT
                        or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>', "$srcdir/$podir/Makevars.tmp2"
                        or die "Cannot open file: $OS_ERROR\n";
                        my $tmp = do {
                        my $tmp_redirect_52 = q{};
                        my @sort_lines_53 = split /\n/msx, $output_49;
                        my @sort_sorted_53 = sort @sort_lines_53;
                        $tmp_redirect_52 = join "\n", @sort_sorted_53;
                        if ($tmp_redirect_52 ne q{} && !($tmp_redirect_52 =~ m{\n\z}msx)) {
                        $tmp_redirect_52 .= "\n";
                        }
                        $output_49 = $tmp_redirect_52;
                        $tmp_redirect_52;
                        };
                        print $tmp;
                        if ($tmp eq q{}) { print $output_49; }
                        $output_printed_49 = 1;
                        open STDOUT, '>&', $original_stdout
                        or die "Cannot restore STDOUT: $OS_ERROR\n";
                        close $original_stdout
                        or die "Close failed: $OS_ERROR\n";
                        };
                        if ( !$pipeline_success_49 ) { $main_exit_code = 1; }
                        }
                my $missingvars;
                my @missingvars;
                my %missingvars;
                $missingvars = do { q{} };
if ( -e "$srcdir/$podir/Makevars.tmp1" ) {
                    if ( -d "$srcdir/$podir/Makevars.tmp1" ) {
                        carp "rm: carping: ", "$srcdir/$podir/Makevars.tmp1",
          " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink "$srcdir/$podir/Makevars.tmp1" ) {
                                                    }
                        else {
                            carp "rm: carping: could not remove ", "$srcdir/$podir/Makevars.tmp1",
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 0;
                }
if ( -e "$srcdir/$podir/Makevars.tmp2" ) {
                    if ( -d "$srcdir/$podir/Makevars.tmp2" ) {
                        carp "rm: carping: ", "$srcdir/$podir/Makevars.tmp2",
          " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink "$srcdir/$podir/Makevars.tmp2" ) {
                                                    }
                        else {
                            carp "rm: carping: could not remove ", "$srcdir/$podir/Makevars.tmp2",
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 0;
                }
if (StringInterpolation(StringInterpolation { parts: [Variable("missingvars")] }, None) ne q{}) {
                    $please = "$please
Please update $podir/Makevars so that it defines all the variables mentioned
in $podir/Makevars.template.
You can then remove $podir/Makevars.template.
";
                }
}
            else {
                $please = "$please
Please create $podir/Makevars from the template in $podir/Makevars.template.
You can then remove $podir/Makevars.template.
";
            }
        } elsif (1) {
                        $same = 'no';
            if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("srcdir"), Literal("/"), Variable("podir"), Literal("/"), Variable("file")] }, None)')) {
if (!(                $main_exit_code = system('cmp', '-s', $file, "$srcdir/$podir/$file") >> 8)) {
                    $same = 'yes';
                }
            }
            if ((!(            $CHILD_ERROR = 0) && !(            $main_exit_code = system('test', $same, q{=}, 'no') >> 8))) {
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("srcdir"), Literal("/"), Variable("podir"), Literal("/"), Variable("file")] }, None)')) {
                    func_poChangeLog_add_entry("	* $file: Upgrade to gettext-" . ${version} . ".");
}
                else {
                    func_poChangeLog_add_entry("	* $file: New file, from gettext-" . ${version} . ".");
                }
            }
                        func_backup("$podir/$file");
                        func_linkorcopy($file, "$gettext_datadir/po/$file", "$podir/$file");
        }
    }
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("srcdir"), Literal("/"), Variable("podir"), Literal("/cat-id-tbl.c")] }, None)')) {
        func_remove("$podir/cat-id-tbl.c");
        if (do {
$CHILD_ERROR = 0;
            $CHILD_ERROR == 0
        }) {
                        func_poChangeLog_add_entry("	* cat-id-tbl.c: Remove file.");
        }
    }
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("srcdir"), Literal("/"), Variable("podir"), Literal("/stamp-cat-id")] }, None)')) {
        func_remove("$podir/stamp-cat-id");
        if (do {
$CHILD_ERROR = 0;
            $CHILD_ERROR == 0
        }) {
                        func_poChangeLog_add_entry("	* stamp-cat-id: Remove file.");
        }
    }
if ((-f '! StringInterpolation(StringInterpolation { parts: [Variable("srcdir"), Literal("/"), Variable("podir"), Literal("/POTFILES.in")] }, None)')) {
if (!(        $CHILD_ERROR = 0)) {
            do {
    my $__echo_line = "Creating initial $podir/POTFILES.in";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', "$srcdir/$podir/POTFILES.in"
      or die "Cannot open file: $OS_ERROR\n";
                print '# List of source files which contain translatable strings.' . "\n";
                $CHILD_ERROR = 0;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
}
        else {
            do {
    my $__echo_line = "Create initial $podir/POTFILES.in";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        }
        if (do {
$CHILD_ERROR = 0;
            $CHILD_ERROR == 0
        }) {
                        func_poChangeLog_add_entry("	* POTFILES.in: New file.");
        }
        $please = "$please
Please fill $podir/POTFILES.in as described in the documentation.
";
    }
    if (do {
$CHILD_ERROR = 0;
        $CHILD_ERROR == 0
    }) {
                func_poChangeLog_finish();
    }
}
my $m4filelist;
my @m4filelist;
my %m4filelist;
$m4filelist = "\n  gettext.m4\n  host-cpu-c-abi.m4\n  iconv.m4\n  intlmacosx.m4\n  lib-ld.m4 lib-link.m4 lib-prefix.m4\n  nls.m4\n  po.m4 progtest.m4";
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("srcdir"), Literal("/Makefile.am")] }, None)')) {
    my $have_automake18;
    my @have_automake18;
    my %have_automake18;
    $have_automake18 = q{};
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
        do {
            local %ENV = %ENV;
            my $IFS = $IFS;
            my $added_directories = $added_directories;
            my $force = $force;
            my $configure_in = $configure_in;
            my $err = $err;
            my $f = $f;
            my $added_extradist = $added_extradist;
            my $func_trace = $func_trace;
            my $same = $same;
            my $save_IFS = $save_IFS;
            my $datarootdir = $datarootdir;
            my $intldir = $intldir;
            my $LC_ALL = $LC_ALL;
            my $progname = $progname;
            my $doit = $doit;
            my $please = $please;
            my $prefix = $prefix;
            my $removed_directory = $removed_directory;
            my $have_automake18 = $have_automake18;
            my $added_acoutput = $added_acoutput;
            my $package = $package;
            my $date = $date;
            my $bindir = $bindir;
            my $podirs = $podirs;
            my $orig_installdir = $orig_installdir;
            my $try_ln_s = $try_ln_s;
            my $min_automake_version = $min_automake_version;
            my $auxdir = $auxdir;
            my $removed_acoutput = $removed_acoutput;
            my $origdir = $origdir;
            my $aclocal_version = $aclocal_version;
            my $missingvars = $missingvars;
            my $archive_version = $archive_version;
            my $m4filelist = $m4filelist;
            my $have_automake19 = $have_automake19;
            my $arg = $arg;
            my $GREP_OPTIONS = $GREP_OPTIONS;
            my $m4dir = $m4dir;
            my $macrodirs = $macrodirs;
            my $# = $#;
            my $srcdir = $srcdir;
            my $external = $external;
            my $do_changelog = $do_changelog;
            my $gettext_datadir = $gettext_datadir;
            my $version = $version;
            my $using_m4ChangeLog = $using_m4ChangeLog;
            my $xargs = $xargs;
            my $podir = $podir;
            my $CLICOLOR_FORCE = $CLICOLOR_FORCE;
            my $file = $file;
            my $exec_prefix = $exec_prefix;
            $main_exit_code = system('aclocal', '--version') >> 8;
            q{};
        };
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
        $aclocal_version = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_54 = q{};
            my $output_printed_54;
            my $pipeline_success_54 = 1;

            my ($in_55, $out_55);
            my $pid_55 = open3($in_55, $out_55, '>&STDERR', 'aclocal', '--version');
            close $in_55 or croak 'Close failed: $OS_ERROR';
            $output_54 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_55> };
            close $out_55 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_55, 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_54 = 0; }
            my @sed_lines_54 = split /\n/msx, $output_54;
            my @sed_result_54;
            foreach my $line (@sed_lines_54) {
            chomp $line;
            push @sed_result_54, $line;
            }
            $output_54 = join "\n", @sed_result_54;

            my @sed_lines_54 = split /\n/msx, $output_54;
            my @sed_result_54;
            foreach my $line (@sed_lines_54) {
            chomp $line;
            push @sed_result_54, $line;
            }
            $output_54 = join "\n", @sed_result_54;

            if ( !$pipeline_success_54 ) { $main_exit_code = 1; }
            $output_54 =~ s/\n+\z//msx;
            $output_54;
}; $_pipeline_result; };
if ($aclocal_version =~ /^1.\[8-9\].*$/msx or $aclocal_version =~ /^1.\[1-9\]\[0-9\].*$/msx or $aclocal_version =~ /^\[2-9\].*$/msx) {
                        $have_automake18 = 'yes';
        }
    }
if (StringInterpolation(StringInterpolation { parts: [Variable("m4dir")] }, None) eq q{}) {
        my $aclocal_amflags;
        my @aclocal_amflags;
        my %aclocal_amflags;
        $aclocal_amflags = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_56 = q{};
        my $output_printed_56;
        my $output_57 = q{};
        while (my $line = <>) {
            chomp $line;
                        if (!($line =~ /^ACLOCAL_AMFLAGS[\ \t]*=/msx)) {
                next;
            }
            $line =~ "s/^ACLOCAL_AMFLAGS[ \t]*=\\(.*\\)$/\\1/";
        }
        $output_57; };
}; $_pipeline_result; };
        my $m4dir_is_next;
        my @m4dir_is_next;
        my %m4dir_is_next;
        $m4dir_is_next = q{};
        for my $arg ($aclocal_amflags) {
if (StringInterpolation(StringInterpolation { parts: [Variable("m4dir_is_next")] }, None) ne q{}) {
if ("$arg" =~ /^/.*$/msx) {
                } elsif (1) {
                                                            $main_exit_code = system('test', '-z', "$m4dir") >> 8;
                    if ($CHILD_ERROR != 0) {
                                                $m4dir = "$arg";
                    }
                                        $macrodirs = "$macrodirs $arg";
                }
                $m4dir_is_next = q{};
}
            else {
if (StringInterpolation(StringInterpolation { parts: [Literal("X"), Variable("arg")] }, None) eq StringInterpolation(StringInterpolation { parts: [Literal("X-I")] }, None)) {
                    $m4dir_is_next = 'yes';
}
                else {
                    $m4dir_is_next = q{};
                }
            }
        }
        for my $arg ($macrodirs) {
            $m4dir = "$arg";
last;
        }
    }
if (StringInterpolation(StringInterpolation { parts: [Variable("m4dir")] }, None) eq q{}) {
        $m4dir = 'm4';
        my $m4dir_defaulted;
        my @m4dir_defaulted;
        my %m4dir_defaulted;
        $m4dir_defaulted = 'yes';
    }
if (((!(    $main_exit_code = system('test', '-d', "$srcdir/$m4dir") >> 8) && !(    $main_exit_code = system('test', '-f', "$srcdir/ChangeLog") >> 8)) && !(    $main_exit_code = system('test', q{!}, '-f', "$srcdir/$m4dir/ChangeLog") >> 8))) {
        $using_m4ChangeLog = q{};
    }
    if (do {
$CHILD_ERROR = 0;
        $CHILD_ERROR == 0
    }) {
                func_m4ChangeLog_init();
    }
    my $added_m4dir;
    my @added_m4dir;
    my %added_m4dir;
    $added_m4dir = q{};
    my $added_m4files;
    my @added_m4files;
    my %added_m4files;
    $added_m4files = q{};
if ((-d 'StringInterpolation(StringInterpolation { parts: [Variable("srcdir"), Literal("/"), Variable("m4dir")] }, None)')) {
        $main_exit_code = system('bash', ':') >> 8;
}
    else {
if (!(        $CHILD_ERROR = 0)) {
            do {
    my $__echo_line = "Creating directory $m4dir";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
            use File::Path qw(make_path);
            if ( mkdir "$srcdir/$m4dir" ) {
                }
            else {
                croak "mkdir: cannot create directory " . "$srcdir/$m4dir" . ": File exists\n";
            }
}
        else {
            do {
    my $__echo_line = "Create directory $m4dir";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
        }
        $added_m4dir = 'yes';
    }
    for my $file ($m4filelist) {
        $same = 'no';
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("srcdir"), Literal("/"), Variable("m4dir"), Literal("/"), Variable("file")] }, None)')) {
if (!(            $main_exit_code = system('cmp', '-s', ${datarootdir} . "/aclocal/$file", "$srcdir/$m4dir/$file") >> 8)) {
                $same = 'yes';
            }
}
        else {
            $added_m4files = "$added_m4files $file";
        }
if ((!(        $CHILD_ERROR = 0) && !(        $main_exit_code = system('test', $same, q{=}, 'no') >> 8))) {
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("srcdir"), Literal("/"), Variable("m4dir"), Literal("/"), Variable("file")] }, None)')) {
                func_m4ChangeLog_add_entry("	* $file: Upgrade to gettext-" . ${version} . ".");
}
            else {
                func_m4ChangeLog_add_entry("	* $file: New file, from gettext-" . ${version} . ".");
            }
        }
        func_backup("$m4dir/$file");
        func_linkorcopy(${datarootdir} . "/aclocal/$file", ${datarootdir} . "/aclocal/$file", "$m4dir/$file");
    }
    my $missing_m4Makefileam;
    my @missing_m4Makefileam;
    my %missing_m4Makefileam;
    $missing_m4Makefileam = q{};
if (StringInterpolation(StringInterpolation { parts: [Variable("added_m4files")] }, None) ne q{}) {
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("srcdir"), Literal("/"), Variable("m4dir"), Literal("/Makefile.am")] }, None)')) {
if (!(            $CHILD_ERROR = 0)) {
                do {
    my $__echo_line = "Updating EXTRA_DIST in $m4dir/Makefile.am (backup is in $m4dir/Makefile.am~)";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                func_backup("$m4dir/Makefile.am");
if ( -e "$srcdir/$m4dir/Makefile.am" ) {
                    if ( -d "$srcdir/$m4dir/Makefile.am" ) {
                        carp "rm: carping: ", "$srcdir/$m4dir/Makefile.am",
          " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink "$srcdir/$m4dir/Makefile.am" ) {
                                                    }
                        else {
                            carp "rm: carping: could not remove ", "$srcdir/$m4dir/Makefile.am",
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 0;
                }
if (!(                do {
                    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $grep_result_59;
my @grep_lines_59 = ();
my @grep_filtered_59 = grep { /^EXTRA_DIST[\ \t]*=/msx } @grep_lines_59;
$grep_result_59 = join "\n", @grep_filtered_59;
                    if (!($grep_result_59 =~ m{\n\z}msx || $grep_result_59 eq q{})) {
                        $grep_result_59 .= "\n";
                    }
print $grep_result_59;
$CHILD_ERROR = scalar @grep_filtered_59 > 0 ? 0 : 1;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                })) {
open STDIN, '<', "$srcdir/$m4dir/Makefile.am~" or croak "Cannot open file: $OS_ERROR\n";
                    do {
                        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>', "$srcdir/$m4dir/Makefile.am"
      or die "Cannot open file: $OS_ERROR\n";
                        my $tmp = do {
my @sed_lines_60 = split /\n/msx, $;
my @sed_result_60;
foreach my $line (@sed_lines_60) {
chomp $line;
push @sed_result_60, $line;
}
$ = join "\n", @sed_result_60;

                        };
                        print $tmp;
                        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                    };
                    if (do {
$CHILD_ERROR = 0;
                        $CHILD_ERROR == 0
                    }) {
                                                func_m4ChangeLog_add_entry("	* Makefile.am (EXTRA_DIST): Add the new files.");
                    }
}
                else {
                    do {
                        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>', "$srcdir/$m4dir/Makefile.am"
      or die "Cannot open file: $OS_ERROR\n";
                        do {
                            local %ENV = %ENV;
                            my $IFS = $IFS;
                            my $added_directories = $added_directories;
                            my $force = $force;
                            my $configure_in = $configure_in;
                            my $err = $err;
                            my $f = $f;
                            my $added_extradist = $added_extradist;
                            my $func_trace = $func_trace;
                            my $same = $same;
                            my $save_IFS = $save_IFS;
                            my $datarootdir = $datarootdir;
                            my $intldir = $intldir;
                            my $LC_ALL = $LC_ALL;
                            my $progname = $progname;
                            my $added_m4dir = $added_m4dir;
                            my $doit = $doit;
                            my $please = $please;
                            my $prefix = $prefix;
                            my $removed_directory = $removed_directory;
                            my $have_automake18 = $have_automake18;
                            my $added_acoutput = $added_acoutput;
                            my $package = $package;
                            my $date = $date;
                            my $bindir = $bindir;
                            my $podirs = $podirs;
                            my $orig_installdir = $orig_installdir;
                            my $try_ln_s = $try_ln_s;
                            my $min_automake_version = $min_automake_version;
                            my $auxdir = $auxdir;
                            my $removed_acoutput = $removed_acoutput;
                            my $origdir = $origdir;
                            my $aclocal_version = $aclocal_version;
                            my $missingvars = $missingvars;
                            my $archive_version = $archive_version;
                            my $m4filelist = $m4filelist;
                            my $aclocal_amflags = $aclocal_amflags;
                            my $added_m4files = $added_m4files;
                            my $have_automake19 = $have_automake19;
                            my $arg = $arg;
                            my $m4dir_defaulted = $m4dir_defaulted;
                            my $GREP_OPTIONS = $GREP_OPTIONS;
                            my $m4dir = $m4dir;
                            my $macrodirs = $macrodirs;
                            my $# = $#;
                            my $srcdir = $srcdir;
                            my $external = $external;
                            my $do_changelog = $do_changelog;
                            my $gettext_datadir = $gettext_datadir;
                            my $version = $version;
                            my $using_m4ChangeLog = $using_m4ChangeLog;
                            my $xargs = $xargs;
                            my $podir = $podir;
                            my $CLICOLOR_FORCE = $CLICOLOR_FORCE;
                            my $m4dir_is_next = $m4dir_is_next;
                            my $file = $file;
                            my $missing_m4Makefileam = $missing_m4Makefileam;
                            my $exec_prefix = $exec_prefix;
print do { my $cat_chunk = q{}; if ( open my $fh, '<', "$srcdir/$m4dir/Makefile.am~" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$srcdir/$m4dir/Makefile.am~" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
                                print "\n";
                                $CHILD_ERROR = 0;
                                do {
    my $__echo_line = "EXTRA_DIST =$added_m4files";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                                $CHILD_ERROR = 0;
                            q{};
                        };
                        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                    };
                    if (do {
$CHILD_ERROR = 0;
                        $CHILD_ERROR == 0
                    }) {
                                                func_m4ChangeLog_add_entry("	* Makefile.am (EXTRA_DIST): New variable.");
                    }
                }
}
            else {
                do {
    my $__echo_line = "Update EXTRA_DIST in $m4dir/Makefile.am";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                if (do {
$CHILD_ERROR = 0;
                    $CHILD_ERROR == 0
                }) {
                                        func_m4ChangeLog_add_entry("	* Makefile.am (EXTRA_DIST).");
                }
            }
}
        else {
if (StringInterpolation(StringInterpolation { parts: [Variable("have_automake18")] }, None) eq q{}) {
if (!(                $CHILD_ERROR = 0)) {
                    do {
    my $__echo_line = "Creating $m4dir/Makefile.am";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                    do {
                        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>', "$srcdir/$m4dir/Makefile.am"
      or die "Cannot open file: $OS_ERROR\n";
                        do {
    my $__echo_line = "EXTRA_DIST =$added_m4files";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                        $CHILD_ERROR = 0;
                        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                    };
}
                else {
                    do {
    my $__echo_line = "Create $m4dir/Makefile.am";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                    $CHILD_ERROR = 0;
                }
                if (do {
$CHILD_ERROR = 0;
                    $CHILD_ERROR == 0
                }) {
                                        func_m4ChangeLog_add_entry("	* Makefile.am: New file.");
                }
                $added_acoutput = "$added_acoutput $m4dir/Makefile";
}
            else {
                $missing_m4Makefileam = 'yes';
            }
        }
    }
if ((!(    $main_exit_code = system('test', '-n', "$added_m4dir") >> 8) && !(    $main_exit_code = system('test', '-z', "$missing_m4Makefileam") >> 8))) {
        $added_directories = "$added_directories $m4dir";
    }
    if (do {
$CHILD_ERROR = 0;
        $CHILD_ERROR == 0
    }) {
                func_m4ChangeLog_finish();
    }
if ((!(    $main_exit_code = system('test', '-n', "$ENV{created_m4ChangeLog}") >> 8) && !(    $main_exit_code = system('test', '-n', "$missing_m4Makefileam") >> 8))) {
        $added_extradist = "$added_extradist $m4dir/ChangeLog";
    }
    my $modified_Makefile_am;
    my @modified_Makefile_am;
    my %modified_Makefile_am;
    $modified_Makefile_am = q{};

sub func_modify_Makefile_am {
        my ($file) = @_;
if (!(        $main_exit_code = system('cmp', '-s', "$srcdir/Makefile.am", "$srcdir/Makefile.am.tmp") >> 8)) {
            $main_exit_code = system('bash', ':') >> 8;
}
        else {
if (StringInterpolation(StringInterpolation { parts: [Variable("modified_Makefile_am")] }, None) eq q{}) {
if (!(                $CHILD_ERROR = 0)) {
                    print "Updating Makefile.am (backup is in Makefile.am~)\n";
                    func_backup('Makefile.am');
}
                else {
                    print "Update Makefile.am\n";
                }
            }
if (!(            $CHILD_ERROR = 0)) {
if ( -e "$srcdir/Makefile.am" ) {
                    if ( -d "$srcdir/Makefile.am" ) {
                        carp "rm: carping: ", "$srcdir/Makefile.am",
          " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink "$srcdir/Makefile.am" ) {
                                                    }
                        else {
                            carp "rm: carping: could not remove ", "$srcdir/Makefile.am",
              ": $OS_ERROR\n";
                        }
                    }
                }
                else {
                    local $CHILD_ERROR = 0;
                }
                use File::Copy qw(copy);
                if ( -e "$srcdir/Makefile.am.tmp" ) {
                    if ( -d "$srcdir/Makefile.am" ) {
                        require File::Copy; File::Copy::copy("$srcdir/Makefile.am.tmp", "$srcdir/Makefile.am" . '/' . ("$srcdir/Makefile.am.tmp" =~ m|([^/]+)$|)[0]);
                    } else {
                        require File::Copy; File::Copy::copy("$srcdir/Makefile.am.tmp", "$srcdir/Makefile.am");
                    }
                } else {
                    croak "cp: cannot stat '$srcdir/Makefile.am.tmp': No such file or directory\n";
                }
            }
if (!(            $CHILD_ERROR = 0)) {
if (StringInterpolation(StringInterpolation { parts: [Variable("modified_Makefile_am")] }, None) eq q{}) {
                    func_ChangeLog_add_entry("	* Makefile.am $_[0]");
}
                else {
                    func_ChangeLog_add_entry("	$_[0]");
                }
            }
            $modified_Makefile_am = 'yes';
        }
if ( -e "$srcdir/Makefile.am.tmp" ) {
            if ( -d "$srcdir/Makefile.am.tmp" ) {
                carp "rm: carping: ", "$srcdir/Makefile.am.tmp",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "$srcdir/Makefile.am.tmp" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "$srcdir/Makefile.am.tmp",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
        return;
}
if (StringInterpolation(StringInterpolation { parts: [Variable("added_directories")] }, None) ne q{}) {
if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $grep_result_63;
my @grep_lines_63 = ();
my @grep_filtered_63 = grep { /^SUBDIRS[\ \t]*=/msx } @grep_lines_63;
$grep_result_63 = join "\n", @grep_filtered_63;
            if (!($grep_result_63 =~ m{\n\z}msx || $grep_result_63 eq q{})) {
                $grep_result_63 .= "\n";
            }
print $grep_result_63;
$CHILD_ERROR = scalar @grep_filtered_63 > 0 ? 0 : 1;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
open STDIN, '<', "$srcdir/Makefile.am" or croak "Cannot open file: $OS_ERROR\n";
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', "$srcdir/Makefile.am.tmp"
      or die "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
my @sed_lines_64 = split /\n/msx, $;
my @sed_result_64;
foreach my $line (@sed_lines_64) {
chomp $line;
push @sed_result_64, $line;
}
$ = join "\n", @sed_result_64;

                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            my $added_directories_pretty;
            my @added_directories_pretty;
            my %added_directories_pretty;
            $added_directories_pretty = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_65 = q{};
                my $output_printed_65;
                my $pipeline_success_65 = 1;
                $output_65 .= $added_directories . "\n";
                if ( !($output_65 =~ m{\n\z}msx) ) { $output_65 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_65 = 0; }
                my @sed_lines_65 = split /\n/msx, $output_65;
                my @sed_result_65;
                foreach my $line (@sed_lines_65) {
                chomp $line;
                push @sed_result_65, $line;
                }
                $output_65 = join "\n", @sed_result_65;

                if ( !$pipeline_success_65 ) { $main_exit_code = 1; }
                $output_65 =~ s/\n+\z//msx;
                $output_65;
}; $_pipeline_result; };
            func_modify_Makefile_am("(SUBDIRS): Add $added_directories_pretty.");
}
        else {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', "$srcdir/Makefile.am.tmp"
      or die "Cannot open file: $OS_ERROR\n";
                do {
                    local %ENV = %ENV;
                    my $IFS = $IFS;
                    my $added_directories = $added_directories;
                    my $force = $force;
                    my $configure_in = $configure_in;
                    my $err = $err;
                    my $f = $f;
                    my $added_extradist = $added_extradist;
                    my $func_trace = $func_trace;
                    my $same = $same;
                    my $save_IFS = $save_IFS;
                    my $datarootdir = $datarootdir;
                    my $intldir = $intldir;
                    my $LC_ALL = $LC_ALL;
                    my $progname = $progname;
                    my $added_m4dir = $added_m4dir;
                    my $doit = $doit;
                    my $please = $please;
                    my $prefix = $prefix;
                    my $removed_directory = $removed_directory;
                    my $have_automake18 = $have_automake18;
                    my $added_acoutput = $added_acoutput;
                    my $package = $package;
                    my $date = $date;
                    my $bindir = $bindir;
                    my $podirs = $podirs;
                    my $orig_installdir = $orig_installdir;
                    my $try_ln_s = $try_ln_s;
                    my $min_automake_version = $min_automake_version;
                    my $auxdir = $auxdir;
                    my $removed_acoutput = $removed_acoutput;
                    my $origdir = $origdir;
                    my $aclocal_version = $aclocal_version;
                    my $missingvars = $missingvars;
                    my $modified_Makefile_am = $modified_Makefile_am;
                    my $archive_version = $archive_version;
                    my $m4filelist = $m4filelist;
                    my $aclocal_amflags = $aclocal_amflags;
                    my $added_m4files = $added_m4files;
                    my $have_automake19 = $have_automake19;
                    my $arg = $arg;
                    my $m4dir_defaulted = $m4dir_defaulted;
                    my $GREP_OPTIONS = $GREP_OPTIONS;
                    my $m4dir = $m4dir;
                    my $macrodirs = $macrodirs;
                    my $# = $#;
                    my $srcdir = $srcdir;
                    my $external = $external;
                    my $do_changelog = $do_changelog;
                    my $gettext_datadir = $gettext_datadir;
                    my $version = $version;
                    my $using_m4ChangeLog = $using_m4ChangeLog;
                    my $xargs = $xargs;
                    my $podir = $podir;
                    my $added_directories_pretty = $added_directories_pretty;
                    my $CLICOLOR_FORCE = $CLICOLOR_FORCE;
                    my $m4dir_is_next = $m4dir_is_next;
                    my $file = $file;
                    my $missing_m4Makefileam = $missing_m4Makefileam;
                    my $exec_prefix = $exec_prefix;
print do { my $cat_chunk = q{}; if ( open my $fh, '<', "$srcdir/Makefile.am" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$srcdir/Makefile.am" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
                        print "\n";
                        $CHILD_ERROR = 0;
                        do {
    my $__echo_line = "SUBDIRS =$added_directories";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                        $CHILD_ERROR = 0;
                    q{};
                };
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            func_modify_Makefile_am("(SUBDIRS): New variable.");
        }
    }
if (StringInterpolation(StringInterpolation { parts: [Variable("removed_directory")] }, None) ne q{}) {
open STDIN, '<', "$srcdir/Makefile.am" or croak "Cannot open file: $OS_ERROR\n";
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$srcdir/Makefile.am.tmp"
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
my @sed_lines_67 = split /\n/msx, $;
my @sed_result_67;
foreach my $line (@sed_lines_67) {
chomp $line;
push @sed_result_67, $line;
}
$ = join "\n", @sed_result_67;

            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        func_modify_Makefile_am("(SUBDIRS): Remove $removed_directory.");
    }
if (StringInterpolation(StringInterpolation { parts: [Variable("added_directories")] }, None) ne q{}) {
if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $grep_result_68;
my @grep_lines_68 = ();
my @grep_filtered_68 = grep { /^DIST_SUBDIRS[\ \t]*=/msx } @grep_lines_68;
$grep_result_68 = join "\n", @grep_filtered_68;
            if (!($grep_result_68 =~ m{\n\z}msx || $grep_result_68 eq q{})) {
                $grep_result_68 .= "\n";
            }
print $grep_result_68;
$CHILD_ERROR = scalar @grep_filtered_68 > 0 ? 0 : 1;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
open STDIN, '<', "$srcdir/Makefile.am" or croak "Cannot open file: $OS_ERROR\n";
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', "$srcdir/Makefile.am.tmp"
      or die "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
my @sed_lines_69 = split /\n/msx, $;
my @sed_result_69;
foreach my $line (@sed_lines_69) {
chomp $line;
push @sed_result_69, $line;
}
$ = join "\n", @sed_result_69;

                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            $added_directories_pretty = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_70 = q{};
                my $output_printed_70;
                my $pipeline_success_70 = 1;
                $output_70 .= $added_directories . "\n";
                if ( !($output_70 =~ m{\n\z}msx) ) { $output_70 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_70 = 0; }
                my @sed_lines_70 = split /\n/msx, $output_70;
                my @sed_result_70;
                foreach my $line (@sed_lines_70) {
                chomp $line;
                push @sed_result_70, $line;
                }
                $output_70 = join "\n", @sed_result_70;

                if ( !$pipeline_success_70 ) { $main_exit_code = 1; }
                $output_70 =~ s/\n+\z//msx;
                $output_70;
}; $_pipeline_result; };
            func_modify_Makefile_am("(DIST_SUBDIRS): Add $added_directories_pretty.");
        }
    }
if (StringInterpolation(StringInterpolation { parts: [Variable("removed_directory")] }, None) ne q{}) {
open STDIN, '<', "$srcdir/Makefile.am" or croak "Cannot open file: $OS_ERROR\n";
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$srcdir/Makefile.am.tmp"
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
my @sed_lines_71 = split /\n/msx, $;
my @sed_result_71;
foreach my $line (@sed_lines_71) {
chomp $line;
push @sed_result_71, $line;
}
$ = join "\n", @sed_result_71;

            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        func_modify_Makefile_am("(DIST_SUBDIRS): Remove $removed_directory.");
    }
if (StringInterpolation(StringInterpolation { parts: [Variable("m4dir_defaulted")] }, None) ne q{}) {
if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $grep_result_72;
my @grep_lines_72 = ();
my @grep_filtered_72 = grep { /^ACLOCAL_AMFLAGS[\ \t]*=/msx } @grep_lines_72;
$grep_result_72 = join "\n", @grep_filtered_72;
            if (!($grep_result_72 =~ m{\n\z}msx || $grep_result_72 eq q{})) {
                $grep_result_72 .= "\n";
            }
print $grep_result_72;
$CHILD_ERROR = scalar @grep_filtered_72 > 0 ? 0 : 1;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
open STDIN, '<', "$srcdir/Makefile.am" or croak "Cannot open file: $OS_ERROR\n";
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', "$srcdir/Makefile.am.tmp"
      or die "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
my @sed_lines_73 = split /\n/msx, $;
my @sed_result_73;
foreach my $line (@sed_lines_73) {
chomp $line;
push @sed_result_73, $line;
}
$ = join "\n", @sed_result_73;

                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            func_modify_Makefile_am("(ACLOCAL_AMFLAGS): Add -I $m4dir.");
}
        else {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', "$srcdir/Makefile.am.tmp"
      or die "Cannot open file: $OS_ERROR\n";
                do {
                    local %ENV = %ENV;
                    my $IFS = $IFS;
                    my $added_directories = $added_directories;
                    my $force = $force;
                    my $configure_in = $configure_in;
                    my $err = $err;
                    my $f = $f;
                    my $added_extradist = $added_extradist;
                    my $func_trace = $func_trace;
                    my $same = $same;
                    my $save_IFS = $save_IFS;
                    my $datarootdir = $datarootdir;
                    my $intldir = $intldir;
                    my $LC_ALL = $LC_ALL;
                    my $progname = $progname;
                    my $added_m4dir = $added_m4dir;
                    my $doit = $doit;
                    my $please = $please;
                    my $prefix = $prefix;
                    my $removed_directory = $removed_directory;
                    my $have_automake18 = $have_automake18;
                    my $added_acoutput = $added_acoutput;
                    my $package = $package;
                    my $date = $date;
                    my $bindir = $bindir;
                    my $podirs = $podirs;
                    my $orig_installdir = $orig_installdir;
                    my $try_ln_s = $try_ln_s;
                    my $min_automake_version = $min_automake_version;
                    my $auxdir = $auxdir;
                    my $removed_acoutput = $removed_acoutput;
                    my $origdir = $origdir;
                    my $aclocal_version = $aclocal_version;
                    my $missingvars = $missingvars;
                    my $modified_Makefile_am = $modified_Makefile_am;
                    my $archive_version = $archive_version;
                    my $m4filelist = $m4filelist;
                    my $aclocal_amflags = $aclocal_amflags;
                    my $added_m4files = $added_m4files;
                    my $have_automake19 = $have_automake19;
                    my $arg = $arg;
                    my $m4dir_defaulted = $m4dir_defaulted;
                    my $GREP_OPTIONS = $GREP_OPTIONS;
                    my $m4dir = $m4dir;
                    my $macrodirs = $macrodirs;
                    my $# = $#;
                    my $srcdir = $srcdir;
                    my $external = $external;
                    my $do_changelog = $do_changelog;
                    my $gettext_datadir = $gettext_datadir;
                    my $version = $version;
                    my $using_m4ChangeLog = $using_m4ChangeLog;
                    my $xargs = $xargs;
                    my $podir = $podir;
                    my $added_directories_pretty = $added_directories_pretty;
                    my $CLICOLOR_FORCE = $CLICOLOR_FORCE;
                    my $m4dir_is_next = $m4dir_is_next;
                    my $file = $file;
                    my $missing_m4Makefileam = $missing_m4Makefileam;
                    my $exec_prefix = $exec_prefix;
print do { my $cat_chunk = q{}; if ( open my $fh, '<', "$srcdir/Makefile.am" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$srcdir/Makefile.am" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
                        print "\n";
                        $CHILD_ERROR = 0;
                        do {
    my $__echo_line = "ACLOCAL_AMFLAGS = -I $m4dir";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                        $CHILD_ERROR = 0;
                    q{};
                };
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            func_modify_Makefile_am("(ACLOCAL_AMFLAGS): New variable.");
        }
if (!(        $CHILD_ERROR = 0)) {
            for my $file ('Makefile.', 'in', 'Makefile') {
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("srcdir"), Literal("/"), Variable("file")] }, None)')) {
                    func_backup($file);
if ( -e "$srcdir/$file" ) {
                        if ( -d "$srcdir/$file" ) {
                            carp "rm: carping: ", "$srcdir/$file",
          " is a directory (use -r to remove recursively)\n";
                        }
                        else {
                            if ( unlink "$srcdir/$file" ) {
                                                            }
                            else {
                                carp "rm: carping: could not remove ", "$srcdir/$file",
              ": $OS_ERROR\n";
                            }
                        }
                    }
                    else {
                        local $CHILD_ERROR = 0;
                    }
open STDIN, '<', "$srcdir/$file~" or croak "Cannot open file: $OS_ERROR\n";
                    do {
                        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                        open STDOUT, '>', "$srcdir/$file"
      or die "Cannot open file: $OS_ERROR\n";
                        my $tmp = do {
my @sed_lines_75 = split /\n/msx, $;
my @sed_result_75;
foreach my $line (@sed_lines_75) {
chomp $line;
push @sed_result_75, $line;
}
$ = join "\n", @sed_result_75;

                        };
                        print $tmp;
                        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                    };
                }
            }
        }
    }
if (StringInterpolation(StringInterpolation { parts: [Variable("added_extradist")] }, None) ne q{}) {
if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $grep_result_76;
my @grep_lines_76 = ();
my @grep_filtered_76 = grep { /^EXTRA_DIST[\ \t]*=/msx } @grep_lines_76;
$grep_result_76 = join "\n", @grep_filtered_76;
            if (!($grep_result_76 =~ m{\n\z}msx || $grep_result_76 eq q{})) {
                $grep_result_76 .= "\n";
            }
print $grep_result_76;
$CHILD_ERROR = scalar @grep_filtered_76 > 0 ? 0 : 1;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
open STDIN, '<', "$srcdir/Makefile.am" or croak "Cannot open file: $OS_ERROR\n";
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', "$srcdir/Makefile.am.tmp"
      or die "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
my @sed_lines_77 = split /\n/msx, $;
my @sed_result_77;
foreach my $line (@sed_lines_77) {
chomp $line;
push @sed_result_77, $line;
}
$ = join "\n", @sed_result_77;

                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            my $added_extradist_pretty;
            my @added_extradist_pretty;
            my %added_extradist_pretty;
            $added_extradist_pretty = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_78 = q{};
                my $output_printed_78;
                my $pipeline_success_78 = 1;
                $output_78 .= $added_extradist . "\n";
                if ( !($output_78 =~ m{\n\z}msx) ) { $output_78 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_78 = 0; }
                my @sed_lines_78 = split /\n/msx, $output_78;
                my @sed_result_78;
                foreach my $line (@sed_lines_78) {
                chomp $line;
                push @sed_result_78, $line;
                }
                $output_78 = join "\n", @sed_result_78;

                if ( !$pipeline_success_78 ) { $main_exit_code = 1; }
                $output_78 =~ s/\n+\z//msx;
                $output_78;
}; $_pipeline_result; };
            func_modify_Makefile_am("(EXTRA_DIST): Add $added_extradist_pretty.");
}
        else {
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', "$srcdir/Makefile.am.tmp"
      or die "Cannot open file: $OS_ERROR\n";
                do {
                    local %ENV = %ENV;
                    my $IFS = $IFS;
                    my $added_directories = $added_directories;
                    my $force = $force;
                    my $configure_in = $configure_in;
                    my $err = $err;
                    my $f = $f;
                    my $added_extradist = $added_extradist;
                    my $func_trace = $func_trace;
                    my $same = $same;
                    my $save_IFS = $save_IFS;
                    my $datarootdir = $datarootdir;
                    my $intldir = $intldir;
                    my $LC_ALL = $LC_ALL;
                    my $progname = $progname;
                    my $added_m4dir = $added_m4dir;
                    my $doit = $doit;
                    my $please = $please;
                    my $prefix = $prefix;
                    my $removed_directory = $removed_directory;
                    my $have_automake18 = $have_automake18;
                    my $added_acoutput = $added_acoutput;
                    my $package = $package;
                    my $date = $date;
                    my $bindir = $bindir;
                    my $podirs = $podirs;
                    my $orig_installdir = $orig_installdir;
                    my $try_ln_s = $try_ln_s;
                    my $min_automake_version = $min_automake_version;
                    my $auxdir = $auxdir;
                    my $removed_acoutput = $removed_acoutput;
                    my $origdir = $origdir;
                    my $aclocal_version = $aclocal_version;
                    my $missingvars = $missingvars;
                    my $modified_Makefile_am = $modified_Makefile_am;
                    my $archive_version = $archive_version;
                    my $m4filelist = $m4filelist;
                    my $aclocal_amflags = $aclocal_amflags;
                    my $added_m4files = $added_m4files;
                    my $have_automake19 = $have_automake19;
                    my $arg = $arg;
                    my $m4dir_defaulted = $m4dir_defaulted;
                    my $GREP_OPTIONS = $GREP_OPTIONS;
                    my $m4dir = $m4dir;
                    my $macrodirs = $macrodirs;
                    my $# = $#;
                    my $srcdir = $srcdir;
                    my $external = $external;
                    my $added_extradist_pretty = $added_extradist_pretty;
                    my $do_changelog = $do_changelog;
                    my $gettext_datadir = $gettext_datadir;
                    my $version = $version;
                    my $using_m4ChangeLog = $using_m4ChangeLog;
                    my $xargs = $xargs;
                    my $podir = $podir;
                    my $added_directories_pretty = $added_directories_pretty;
                    my $CLICOLOR_FORCE = $CLICOLOR_FORCE;
                    my $m4dir_is_next = $m4dir_is_next;
                    my $file = $file;
                    my $missing_m4Makefileam = $missing_m4Makefileam;
                    my $exec_prefix = $exec_prefix;
print do { my $cat_chunk = q{}; if ( open my $fh, '<', "$srcdir/Makefile.am" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$srcdir/Makefile.am" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
                        print "\n";
                        $CHILD_ERROR = 0;
                        do {
    my $__echo_line = "EXTRA_DIST =$added_extradist";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                        $CHILD_ERROR = 0;
                    q{};
                };
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            func_modify_Makefile_am("(EXTRA_DIST): New variable.");
        }
    }
    my $aclocal_options;
    my @aclocal_options;
    my %aclocal_options;
    $aclocal_options = q{};
    for my $arg ($macrodirs) {
        $aclocal_options = "$aclocal_options -I $arg";
    }
    $please = "$please
Please run 'aclocal$aclocal_options' to regenerate the aclocal.m4 file.
You need aclocal from GNU automake $min_automake_version (or newer) to do this.
Then run 'autoconf' to regenerate the configure file.
";
if (!(    $CHILD_ERROR = 0)) {
if ("$added_acoutput" =~ /^.*" $m4dir/Makefile$/msx) {
                                    do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                do {
                    local %ENV = %ENV;
                    my $IFS = $IFS;
                    my $added_directories = $added_directories;
                    my $force = $force;
                    my $configure_in = $configure_in;
                    my $err = $err;
                    my $f = $f;
                    my $added_extradist = $added_extradist;
                    my $func_trace = $func_trace;
                    my $same = $same;
                    my $save_IFS = $save_IFS;
                    my $datarootdir = $datarootdir;
                    my $intldir = $intldir;
                    my $LC_ALL = $LC_ALL;
                    my $progname = $progname;
                    my $added_m4dir = $added_m4dir;
                    my $doit = $doit;
                    my $please = $please;
                    my $prefix = $prefix;
                    my $removed_directory = $removed_directory;
                    my $have_automake18 = $have_automake18;
                    my $added_acoutput = $added_acoutput;
                    my $package = $package;
                    my $date = $date;
                    my $bindir = $bindir;
                    my $podirs = $podirs;
                    my $orig_installdir = $orig_installdir;
                    my $try_ln_s = $try_ln_s;
                    my $min_automake_version = $min_automake_version;
                    my $auxdir = $auxdir;
                    my $removed_acoutput = $removed_acoutput;
                    my $origdir = $origdir;
                    my $aclocal_version = $aclocal_version;
                    my $missingvars = $missingvars;
                    my $modified_Makefile_am = $modified_Makefile_am;
                    my $archive_version = $archive_version;
                    my $m4filelist = $m4filelist;
                    my $aclocal_amflags = $aclocal_amflags;
                    my $added_m4files = $added_m4files;
                    my $have_automake19 = $have_automake19;
                    my $arg = $arg;
                    my $m4dir_defaulted = $m4dir_defaulted;
                    my $GREP_OPTIONS = $GREP_OPTIONS;
                    my $m4dir = $m4dir;
                    my $macrodirs = $macrodirs;
                    my $# = $#;
                    my $srcdir = $srcdir;
                    my $external = $external;
                    my $added_extradist_pretty = $added_extradist_pretty;
                    my $do_changelog = $do_changelog;
                    my $gettext_datadir = $gettext_datadir;
                    my $aclocal_options = $aclocal_options;
                    my $version = $version;
                    my $using_m4ChangeLog = $using_m4ChangeLog;
                    my $xargs = $xargs;
                    my $podir = $podir;
                    my $added_directories_pretty = $added_directories_pretty;
                    my $CLICOLOR_FORCE = $CLICOLOR_FORCE;
                    my $m4dir_is_next = $m4dir_is_next;
                    my $file = $file;
                    my $missing_m4Makefileam = $missing_m4Makefileam;
                    my $exec_prefix = $exec_prefix;
                    if (do {
chdir("$srcdir");
$CHILD_ERROR = 0;
                        $CHILD_ERROR == 0
                    }) {
                                                $main_exit_code = system('automake', "$m4dir/Makefile") >> 8;
                    }
                    q{};
                };
            };
            if ($CHILD_ERROR != 0) {
                                $please = "$please
Please run 'automake $m4dir/Makefile' to create $m4dir/Makefile.in
";
            }
        }
    }
}
else {
    $please = "$please
Please add the files
$m4filelist
from the " . ${datarootdir} . "/aclocal directory to your aclocal.m4 file.
";
}
my $modified_configure_in;
my @modified_configure_in;
my %modified_configure_in;
$modified_configure_in = q{};

sub func_modify_configure_in {
    my ($file) = @_;
if (!(    $main_exit_code = system('cmp', '-s', "$srcdir/$configure_in", "$srcdir/$configure_in.tmp") >> 8)) {
        $main_exit_code = system('bash', ':') >> 8;
}
    else {
if (StringInterpolation(StringInterpolation { parts: [Variable("modified_configure_in")] }, None) eq q{}) {
if (!(            $CHILD_ERROR = 0)) {
                do {
    my $__echo_line = "Updating $configure_in (backup is in $configure_in~)";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                $CHILD_ERROR = 0;
                func_backup($configure_in);
}
            else {
                do {
    my $__echo_line = "Update $configure_in";
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
if (!(        $CHILD_ERROR = 0)) {
if ( -e "$srcdir/$configure_in" ) {
                if ( -d "$srcdir/$configure_in" ) {
                    carp "rm: carping: ", "$srcdir/$configure_in",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$srcdir/$configure_in" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "$srcdir/$configure_in",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
            use File::Copy qw(copy);
            if ( -e "$srcdir/$configure_in.tmp" ) {
                if ( -d "$srcdir/$configure_in" ) {
                    require File::Copy; File::Copy::copy("$srcdir/$configure_in.tmp", "$srcdir/$configure_in" . '/' . ("$srcdir/$configure_in.tmp" =~ m|([^/]+)$|)[0]);
                } else {
                    require File::Copy; File::Copy::copy("$srcdir/$configure_in.tmp", "$srcdir/$configure_in");
                }
            } else {
                croak "cp: cannot stat '$srcdir/$configure_in.tmp': No such file or directory\n";
            }
        }
if (!(        $CHILD_ERROR = 0)) {
if (StringInterpolation(StringInterpolation { parts: [Variable("modified_configure_in")] }, None) eq q{}) {
                func_ChangeLog_add_entry("	* $configure_in $_[0]");
}
            else {
                func_ChangeLog_add_entry("	$_[0]");
            }
        }
        $modified_configure_in = 'yes';
    }
if ( -e "$srcdir/$configure_in.tmp" ) {
        if ( -d "$srcdir/$configure_in.tmp" ) {
            carp "rm: carping: ", "$srcdir/$configure_in.tmp",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$srcdir/$configure_in.tmp" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "$srcdir/$configure_in.tmp",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
    return;
}
if (StringInterpolation(StringInterpolation { parts: [Variable("added_acoutput")] }, None) ne q{}) {
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $grep_result_81;
my @grep_lines_81 = ();
my @grep_filtered_81 = grep { /^AC_CONFIG_FILES(/msx } @grep_lines_81;
$grep_result_81 = join "\n", @grep_filtered_81;
        if (!($grep_result_81 =~ m{\n\z}msx || $grep_result_81 eq q{})) {
            $grep_result_81 .= "\n";
        }
print $grep_result_81;
$CHILD_ERROR = scalar @grep_filtered_81 > 0 ? 0 : 1;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
        my $sedprog;
        my @sedprog;
        my %sedprog;
        $sedprog = "\nta\nb\n:a\nn\nba";
open STDIN, '<', "$srcdir/$configure_in" or croak "Cannot open file: $OS_ERROR\n";
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$srcdir/$configure_in.tmp"
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
my @sed_lines_82 = split /\n/msx, $;
my @sed_result_82;
foreach my $line (@sed_lines_82) {
chomp $line;
push @sed_result_82, $line;
}
$ = join "\n", @sed_result_82;

            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        my $added_acoutput_pretty;
        my @added_acoutput_pretty;
        my %added_acoutput_pretty;
        $added_acoutput_pretty = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_83 = q{};
            my $output_printed_83;
            my $pipeline_success_83 = 1;
            $output_83 .= $added_acoutput . "\n";
            if ( !($output_83 =~ m{\n\z}msx) ) { $output_83 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_83 = 0; }
            my @sed_lines_83 = split /\n/msx, $output_83;
            my @sed_result_83;
            foreach my $line (@sed_lines_83) {
            chomp $line;
            push @sed_result_83, $line;
            }
            $output_83 = join "\n", @sed_result_83;

            if ( !$pipeline_success_83 ) { $main_exit_code = 1; }
            $output_83 =~ s/\n+\z//msx;
            $output_83;
}; $_pipeline_result; };
        func_modify_configure_in("(AC_CONFIG_FILES): Add $added_acoutput_pretty.");
}
    else {
if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $grep_result_84;
my @grep_lines_84 = ();
my @grep_filtered_84 = grep { /^AC_OUTPUT(/msx } @grep_lines_84;
$grep_result_84 = join "\n", @grep_filtered_84;
            if (!($grep_result_84 =~ m{\n\z}msx || $grep_result_84 eq q{})) {
                $grep_result_84 .= "\n";
            }
print $grep_result_84;
$CHILD_ERROR = scalar @grep_filtered_84 > 0 ? 0 : 1;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
open STDIN, '<', "$srcdir/$configure_in" or croak "Cannot open file: $OS_ERROR\n";
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', "$srcdir/$configure_in.tmp"
      or die "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
my @sed_lines_85 = split /\n/msx, $;
my @sed_result_85;
foreach my $line (@sed_lines_85) {
chomp $line;
push @sed_result_85, $line;
}
$ = join "\n", @sed_result_85;

                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
            $added_acoutput_pretty = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_86 = q{};
                my $output_printed_86;
                my $pipeline_success_86 = 1;
                $output_86 .= $added_acoutput . "\n";
                if ( !($output_86 =~ m{\n\z}msx) ) { $output_86 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_86 = 0; }
                my @sed_lines_86 = split /\n/msx, $output_86;
                my @sed_result_86;
                foreach my $line (@sed_lines_86) {
                chomp $line;
                push @sed_result_86, $line;
                }
                $output_86 = join "\n", @sed_result_86;

                if ( !$pipeline_success_86 ) { $main_exit_code = 1; }
                $output_86 =~ s/\n+\z//msx;
                $output_86;
}; $_pipeline_result; };
            func_modify_configure_in("(AC_OUTPUT): Add $added_acoutput_pretty.");
}
        else {
            $please = "$please
Please add$added_acoutput to the AC_OUTPUT or AC_CONFIG_FILES invocation in the $configure_in file.
";
        }
    }
}
if (StringInterpolation(StringInterpolation { parts: [Variable("removed_acoutput")] }, None) ne q{}) {
    for my $file ($removed_acoutput) {
        my $tag;
        my @tag;
        my %tag;
        $tag = q{};
        $sedprog = "{
      s%\([[ 	]\)[ 	]%\1%
      s%\([[ 	]\)\([]),]\)%\1\2%
      s%[[ 	]$%%
        :a
        tb
        :b
        s%\\$%\\%
        tc
        bd
        :c
        n
        s%\([ 	]\)[ 	]%\1%
        s%\([ 	]\)\([]),]\)%\1\2%
        s%[ 	]$%%
        ba
      :d
    }";
open STDIN, '<', "$srcdir/$configure_in" or croak "Cannot open file: $OS_ERROR\n";
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$srcdir/$configure_in.tmp"
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
my @sed_lines_87 = split /\n/msx, $;
my @sed_result_87;
foreach my $line (@sed_lines_87) {
chomp $line;
push @sed_result_87, $line;
}
$ = join "\n", @sed_result_87;

            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
if (!(        $main_exit_code = system('cmp', '-s', "$srcdir/$configure_in", "$srcdir/$configure_in.tmp") >> 8)) {
open STDIN, '<', "$srcdir/$configure_in" or croak "Cannot open file: $OS_ERROR\n";
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', "$srcdir/$configure_in.tmp"
      or die "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
my @sed_lines_88 = split /\n/msx, $;
my @sed_result_88;
foreach my $line (@sed_lines_88) {
chomp $line;
push @sed_result_88, $line;
}
$ = join "\n", @sed_result_88;

                };
                print $tmp;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
if (!(            $main_exit_code = system('cmp', '-s', "$srcdir/$configure_in", "$srcdir/$configure_in.tmp") >> 8)) {
                $main_exit_code = system('bash', ':') >> 8;
}
            else {
                $tag = 'AC_OUTPUT';
            }
}
        else {
            $tag = 'AC_CONFIG_FILES';
        }
if (StringInterpolation(StringInterpolation { parts: [Variable("tag")] }, None) ne q{}) {
            func_modify_configure_in("($tag): Remove $file.");
}
        else {
if ( -e "$srcdir/$configure_in.tmp" ) {
                if ( -d "$srcdir/$configure_in.tmp" ) {
                    carp "rm: carping: ", "$srcdir/$configure_in.tmp",
          " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink "$srcdir/$configure_in.tmp" ) {
                                            }
                    else {
                        carp "rm: carping: could not remove ", "$srcdir/$configure_in.tmp",
              ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
if ((!StringInterpolation(StringInterpolation { parts: [Variable("file")] }, None) eq intl/intlh.inst)) {
                $please = "$please
Please remove $file from the AC_OUTPUT or AC_CONFIG_FILES invocation
in the $configure_in file.
";
            }
        }
    }
}
open STDIN, '<', "$srcdir/$configure_in" or croak "Cannot open file: $OS_ERROR\n";
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', "$srcdir/$configure_in.tmp"
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
my @sed_lines_89 = split /\n/msx, $;
my @sed_result_89;
foreach my $line (@sed_lines_89) {
chomp $line;
push @sed_result_89, $line;
}
$ = join "\n", @sed_result_89;

    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
func_modify_configure_in("(AC_OUTPUT): Remove command that created po/Makefile.");
open STDIN, '<', "$srcdir/$configure_in" or croak "Cannot open file: $OS_ERROR\n";
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', "$srcdir/$configure_in.tmp"
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
my @sed_lines_90 = split /\n/msx, $;
my @sed_result_90;
foreach my $line (@sed_lines_90) {
chomp $line;
push @sed_result_90, $line;
}
$ = join "\n", @sed_result_90;

    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
func_modify_configure_in("(AC_LINK_FILES): Remove invocation.");
if (!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $grep_result_91;
my @grep_lines_91 = ();
my @grep_filtered_91 = grep { /^AM_GNU_GETTEXT_VERSION(/msx } @grep_lines_91;
$grep_result_91 = join "\n", @grep_filtered_91;
    if (!($grep_result_91 =~ m{\n\z}msx || $grep_result_91 eq q{})) {
        $grep_result_91 .= "\n";
    }
print $grep_result_91;
$CHILD_ERROR = scalar @grep_filtered_91 > 0 ? 0 : 1;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
})) {
open STDIN, '<', "$srcdir/$configure_in" or croak "Cannot open file: $OS_ERROR\n";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$srcdir/$configure_in.tmp"
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
my @sed_lines_92 = split /\n/msx, $;
my @sed_result_92;
foreach my $line (@sed_lines_92) {
chomp $line;
push @sed_result_92, $line;
}
$ = join "\n", @sed_result_92;

        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    func_modify_configure_in("(AM_GNU_GETTEXT_VERSION): Bump to $archive_version.");
}
if (do {
$CHILD_ERROR = 0;
    $CHILD_ERROR == 0
}) {
        func_ChangeLog_finish();
}
my $use_libtool;
my @use_libtool;
my %use_libtool;
$use_libtool = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_93 = q{};
    my $output_printed_93;
    my $pipeline_success_93 = 1;
    $output_93 = do { my $cat_chunk = q{}; if ( open my $fh, '<', "$srcdir/$configure_in" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$srcdir/$configure_in" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
    if ($CHILD_ERROR != 0) { $pipeline_success_93 = 0; }
    my $grep_result_93_1;
    my @grep_lines_93_1 = split /\n/msx, $output_93;
    my @grep_filtered_93_1 = grep { /^A[CM]_PROG_LIBTOOL/msx } @grep_lines_93_1;
    $grep_result_93_1 = join "\n", @grep_filtered_93_1;
        if (!($grep_result_93_1 =~ m{\n\z}msx || $grep_result_93_1 eq q{})) {
            $grep_result_93_1 .= "\n";
        }
    $CHILD_ERROR = scalar @grep_filtered_93_1 > 0 ? 0 : 1;
    $output_93 = $grep_result_93_1;
    if ((scalar @grep_filtered_93_1) == 0) {
        $pipeline_success_93 = 0;
    }
    if ( !$pipeline_success_93 ) { $main_exit_code = 1; }
    $output_93 =~ s/\n+\z//msx;
    $output_93;
}; $_pipeline_result; };
for my $file (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_94 = q{};
    my $output_printed_94;
    my $pipeline_success_94 = 1;
    $output_94 = q{};
    my @_pcmd_96 = ('sh', '-c', 'cd "$srcdir"');
    my ($in_95, $out_95);
    my $pid_95 = open3($in_95, $out_95, '>&STDERR', @_pcmd_96);
    close $in_95 or croak 'Close failed: $OS_ERROR';
    $output_94 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_95> };
    close $out_95 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_95, 0;
    my @_pcmd_98 = ('sh', '-c', 'find . -name Makefile.am -p rint');
    my ($in_97, $out_97);
    my $pid_97 = open3($in_97, $out_97, '>&STDERR', @_pcmd_98);
    close $in_97 or croak 'Close failed: $OS_ERROR';
    $output_94 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_97> };
    close $out_97 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_97, 0;
    my @_pcmd_100 = ('sh', '-c', 'find . -name Makefile. in -p rint');
    my ($in_99, $out_99);
    my $pid_99 = open3($in_99, $out_99, '>&STDERR', @_pcmd_100);
    close $in_99 or croak 'Close failed: $OS_ERROR';
    $output_94 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_99> };
    close $out_99 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_99, 0;
    my @sed_lines_94 = split /\n/msx, $output_94;
    my @sed_result_94;
    foreach my $line (@sed_lines_94) {
    chomp $line;
    push @sed_result_94, $line;
    }
    $output_94 = join "\n", @sed_result_94;
    if ( !$pipeline_success_94 ) { $main_exit_code = 1; }
    $output_94 =~ s/\n+\z//msx;
    $output_94;
}; $_pipeline_result; }) {
if ((-f 'StringInterpolation(StringInterpolation { parts: [Variable("srcdir"), Literal("/"), Variable("file")] }, None)')) {
if ((!(        $main_exit_code = system('test', do { do {
            my $output_101 = q{};
            my $output_printed_101;
            my $pipeline_success_101 = 1;
            $output_101 .= $file . "\n";
            if ( !($output_101 =~ m{\n\z}msx) ) { $output_101 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_101 = 0; }
            my @sed_lines_101 = split /\n/msx, $output_101;
            my @sed_result_101;
            foreach my $line (@sed_lines_101) {
            chomp $line;
            push @sed_result_101, $line;
            }
            $output_101 = join "\n", @sed_result_101;

            if ( !$pipeline_success_101 ) { $main_exit_code = 1; }
            $output_101 =~ s/\n+\z//msx;
            $output_101;
} }, q{=}, 'Makefile.', 'in') >> 8) && !(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $grep_result_102;
my @grep_lines_102 = ();
my @grep_filtered_102 = grep { /automake/msx } @grep_lines_102;
$grep_result_102 = join "\n", @grep_filtered_102;
            if (!($grep_result_102 =~ m{\n\z}msx || $grep_result_102 eq q{})) {
                $grep_result_102 .= "\n";
            }
print $grep_result_102;
$CHILD_ERROR = scalar @grep_filtered_102 > 0 ? 0 : 1;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        }))) {
next;
        }
if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $grep_result_103;
my @grep_lines_103 = ();
my @grep_filenames_103 = ();
if (-e "INTLLIBS") {
    open my $fh, '<', "INTLLIBS" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_103, $line;
        push @grep_filenames_103, "INTLLIBS";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: INTLLIBS: No such file or directory\n"; }
my @grep_filtered_103 = grep { /@/msx } @grep_lines_103;
$grep_result_103 = join "\n", @grep_filtered_103;
            if (!($grep_result_103 =~ m{\n\z}msx || $grep_result_103 eq q{})) {
                $grep_result_103 .= "\n";
            }
print $grep_result_103;
$CHILD_ERROR = scalar @grep_filtered_103 > 0 ? 0 : 1;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
if (StringInterpolation(StringInterpolation { parts: [Variable("use_libtool")] }, None) ne q{}) {
                $please = "$please
Please change $file to use @LTLIBINTL@ or @LIBINTL@ instead of
@INTLLIBS@. Which one, depends whether it is used with libtool or not.
@INTLLIBS@ will go away.
";
}
            else {
                $please = "$please
Please change $file to use @LIBINTL@ instead of @INTLLIBS@.
@INTLLIBS@ will go away.
";
            }
        }
if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $grep_result_104;
my @grep_lines_104 = ();
my @grep_filenames_104 = ();
if (-e "DATADIRNAME") {
    open my $fh, '<', "DATADIRNAME" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_104, $line;
        push @grep_filenames_104, "DATADIRNAME";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: DATADIRNAME: No such file or directory\n"; }
my @grep_filtered_104 = grep { /@/msx } @grep_lines_104;
$grep_result_104 = join "\n", @grep_filtered_104;
            if (!($grep_result_104 =~ m{\n\z}msx || $grep_result_104 eq q{})) {
                $grep_result_104 .= "\n";
            }
print $grep_result_104;
$CHILD_ERROR = scalar @grep_filtered_104 > 0 ? 0 : 1;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
            $please = "$please
Please change $file to use the constant string \"share\" instead of
@DATADIRNAME@. @DATADIRNAME@ will go away.
";
        }
if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $grep_result_105;
my @grep_lines_105 = ();
my @grep_filenames_105 = ();
if (-e "INSTOBJEXT") {
    open my $fh, '<', "INSTOBJEXT" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_105, $line;
        push @grep_filenames_105, "INSTOBJEXT";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: INSTOBJEXT: No such file or directory\n"; }
my @grep_filtered_105 = grep { /@/msx } @grep_lines_105;
$grep_result_105 = join "\n", @grep_filtered_105;
            if (!($grep_result_105 =~ m{\n\z}msx || $grep_result_105 eq q{})) {
                $grep_result_105 .= "\n";
            }
print $grep_result_105;
$CHILD_ERROR = scalar @grep_filtered_105 > 0 ? 0 : 1;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
            $please = "$please
Please change $file to use the constant string \".mo\" instead of
@INSTOBJEXT@. @INSTOBJEXT@ will go away.
";
        }
if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $grep_result_106;
my @grep_lines_106 = ();
my @grep_filenames_106 = ();
if (-e "GENCAT") {
    open my $fh, '<', "GENCAT" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_106, $line;
        push @grep_filenames_106, "GENCAT";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: GENCAT: No such file or directory\n"; }
my @grep_filtered_106 = grep { /@/msx } @grep_lines_106;
$grep_result_106 = join "\n", @grep_filtered_106;
            if (!($grep_result_106 =~ m{\n\z}msx || $grep_result_106 eq q{})) {
                $grep_result_106 .= "\n";
            }
print $grep_result_106;
$CHILD_ERROR = scalar @grep_filtered_106 > 0 ? 0 : 1;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
            $please = "$please
Please change $file to use the constant string \"gencat\" instead of
@GENCAT@. @GENCAT@ will go away. Maybe you don't even need it any more?
";
        }
if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $grep_result_107;
my @grep_lines_107 = ();
my @grep_filenames_107 = ();
if (-e "POSUB") {
    open my $fh, '<', "POSUB" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_107, $line;
        push @grep_filenames_107, "POSUB";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: POSUB: No such file or directory\n"; }
my @grep_filtered_107 = grep { /@/msx } @grep_lines_107;
$grep_result_107 = join "\n", @grep_filtered_107;
            if (!($grep_result_107 =~ m{\n\z}msx || $grep_result_107 eq q{})) {
                $grep_result_107 .= "\n";
            }
print $grep_result_107;
$CHILD_ERROR = scalar @grep_filtered_107 > 0 ? 0 : 1;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
            $please = "$please
Please change $file to use the constant string \"po\" instead of
@POSUB@. @POSUB@ will go away.
";
        }
    }
}
if (!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $grep_result_108;
my @grep_lines_108 = ();
my @grep_filtered_108 = grep { /[$]nls_cv_header_/msx } @grep_lines_108;
$grep_result_108 = join "\n", @grep_filtered_108;
    if (!($grep_result_108 =~ m{\n\z}msx || $grep_result_108 eq q{})) {
        $grep_result_108 .= "\n";
    }
print $grep_result_108;
$CHILD_ERROR = scalar @grep_filtered_108 > 0 ? 0 : 1;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
})) {
    $please = "$please
Please stop using $nls_cv_header_intl or $nls_cv_header_libgt in the
$configure_in file. Both will go away. Use <libintl.h> or \"gettext.h\" instead.
";
}
if ((!($main_exit_code = system('test', '-f', "$srcdir/$auxdir", 'config.guess') >> 8) && !($main_exit_code = system('test', '-f', "$srcdir/$auxdir", 'config.sub') >> 8))) {
    $main_exit_code = system('bash', ':') >> 8;
}
else {
    $please = "$please
You will also need config.guess and config.sub, which you can get from the CVS
of the 'config' project at https://savannah.gnu.org/. The commands to fetch them
are
$ wget 'https://savannah.gnu.org/cgi-bin/viewcvs/*checkout*/config/config/config.guess'
$ wget 'https://savannah.gnu.org/cgi-bin/viewcvs/*checkout*/config/config/config.sub'
";
}
if (!($CHILD_ERROR = 0)) {
    print $please;
if ( !( ($please) =~ m{\n\z}msx ) ) { print "\n"; }
    print "You might also want to copy the convenience header file gettext.h\n";
    do {
    my $__echo_line = "from the $gettext_datadir directory into your package.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    print "It is a wrapper around <libintl.h> that implements the configure --disable-nls\n";
    print "option.\n";
    print "\n";
    $CHILD_ERROR = 0;
    my $count;
    my @count;
    my %count;
    $count = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_109 = q{};
        my $output_printed_109;
        my $pipeline_success_109 = 1;
        $output_109 .= $please . "\n";
        if ( !($output_109 =~ m{\n\z}msx) ) { $output_109 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_109 = 0; }
        my $grep_result_109_1;
        my @grep_lines_109_1 = split /\n/msx, $output_109;
        my @grep_filtered_109_1 = grep { /^$/msx } @grep_lines_109_1;
        $grep_result_109_1 = join "\n", @grep_filtered_109_1;
                if (!($grep_result_109_1 =~ m{\n\z}msx || $grep_result_109_1 eq q{})) {
                    $grep_result_109_1 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_109_1 > 0 ? 0 : 1;
        $output_109 = $grep_result_109_1;
        $output_109 = do {
                    my $_wc_data = $output_109;
                    my $_wc_lines = () = $_wc_data =~ /\n/gsxm;
                    my $_wc_result = q{};
                    $_wc_result .= sprintf q{%d}, $_wc_lines;
                    $_wc_result .= "\n";
                    $_wc_result;
                };
        if ( !$pipeline_success_109 ) { $main_exit_code = 1; }
        $output_109 =~ s/\n+\z//msx;
        $output_109;
}; $_pipeline_result; };
    $count = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_110 = q{};
        my $output_printed_110;
        my $pipeline_success_110 = 1;
        $output_110 .= $count . "\n";
        if ( !($output_110 =~ m{\n\z}msx) ) { $output_110 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_110 = 0; }
        my @sed_lines_110 = split /\n/msx, $output_110;
        my @sed_result_110;
        foreach my $line (@sed_lines_110) {
        chomp $line;
        push @sed_result_110, $line;
        }
        $output_110 = join "\n", @sed_result_110;

        if ( !$pipeline_success_110 ) { $main_exit_code = 1; }
        $output_110 =~ s/\n+\z//msx;
        $output_110;
}; $_pipeline_result; };
if ("$count" =~ /^1$/msx) {
                $count = "paragraph";
    } elsif ("$count" =~ /^2$/msx) {
                $count = "two paragraphs";
    } elsif ("$count" =~ /^3$/msx) {
                $count = "three paragraphs";
    } elsif ("$count" =~ /^4$/msx) {
                $count = "four paragraphs";
    } elsif ("$count" =~ /^5$/msx) {
                $count = "five paragraphs";
    } elsif (1) {
                $count = "$count paragraphs";
    }
    do {
    my $__echo_line = "Press Return to acknowledge the previous $count.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
open STDIN, '<', '/dev/tty' or croak "Cannot open file: $OS_ERROR\n";
$dummy = <>;
chomp $dummy;
$CHILD_ERROR = defined($dummy) ? 0 : 1;
}
exit 0;

exit $main_exit_code;
