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

my $progname;
my @progname;
my %progname;
$progname = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;
    $output_0 .= $0 . "\n";
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
my $PROGRAM;
my @PROGRAM;
my %PROGRAM;
$PROGRAM = 'intltoolize';
my $PACKAGE;
my @PACKAGE;
my %PACKAGE;
$PACKAGE = 'intltool';
my $VERSION;
my @VERSION;
my %VERSION;
$VERSION = '0.51.0';
my $prefix;
my @prefix;
my %prefix;
$prefix = '/usr';
if ((do { my $_chomp_temp = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__sys; join(" ", @__parts) . "\n"; }; chomp $_chomp_temp; $_chomp_temp; }) =~ /^MINGW32.*$/msx) {
        $prefix = do { use File::Basename qw(dirname); my $dirname_output = dirname($PROGRAM_NAME); $CHILD_ERROR = 0; $dirname_output; };
        $prefix = do { use File::Basename qw(dirname); my $dirname_output = dirname($prefix); $CHILD_ERROR = 0; $dirname_output; };
}
my $datarootdir;
my @datarootdir;
my %datarootdir;
$datarootdir = $prefix;
$main_exit_code = system('bash', '/share') >> 8;
my $datadir;
my @datadir;
my %datadir;
$datadir = $datarootdir;
my $pkgdatadir;
my @pkgdatadir;
my %pkgdatadir;
$pkgdatadir = $datadir;
$main_exit_code = system('bash', '/intltool') >> 8;
my $aclocaldir;
my @aclocaldir;
my %aclocaldir;
$aclocaldir = $datadir;
$main_exit_code = system('bash', '/aclocal') >> 8;
my $intltool_m4;
my @intltool_m4;
my %intltool_m4;
$intltool_m4 = ${aclocaldir} . "/intltool.m4";
my $dry_run;
my @dry_run;
my %dry_run;
$dry_run = 'no';
my $help;
my @help;
my %help;
$help = "Try '$progname --help' for more information.";
my $rm;
my @rm;
my %rm;
$rm = "rm -f";
my $rm_rec;
my @rm_rec;
my %rm_rec;
$rm_rec = "rm -rf";
my $ln_s;
my @ln_s;
my %ln_s;
$ln_s = "ln -s";
my $cp;
my @cp;
my %cp;
$cp = "cp -f";
my $mkdir;
my @mkdir;
my %mkdir;
$mkdir = "mkdir";
my $mkinstalldirs;
my @mkinstalldirs;
my %mkinstalldirs;
$mkinstalldirs = "mkinstalldirs";
my $automake;
my @automake;
my %automake;
$automake = q{};
my $copy;
my @copy;
my %copy;
$copy = q{};
my $force;
my @force;
my %force;
$force = q{};
my $status;
my @status;
my %status;
$status = q{0};
my $arg;
for my $arg () {
if ("$arg" =~ /^--help$/msx) {
        print "Usage: $progname [OPTION]...

Prepare a package to use intltool.

    --automake        work silently, and assume that Automake is in use
-c, --copy            copy files rather than symlinking them
    --debug           enable verbose shell tracing
-n, --dry-run         print commands rather than running them
-f, --force           replace existing files
    --help            display this message and exit
    --version         print version information and exit

You must 'cd' to the top directory of your package before you run
'$progname'.
";
        exit 0;
    } elsif ("$arg" =~ /^--version$/msx) {
                do {
    my $__echo_line = "$PROGRAM (GNU $PACKAGE) $VERSION";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        exit 0;
    } elsif ("$arg" =~ /^--automake$/msx) {
                $automake = 'yes';
    } elsif ("$arg" =~ /^-c$/msx or "$arg" =~ /^--copy$/msx) {
                $ln_s = q{};
    } elsif ("$arg" =~ /^--debug$/msx) {
                do {
    my $__echo_line = "$progname: enabling shell trace mode";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        # set -x not implemented
    } elsif ("$arg" =~ /^-n$/msx or "$arg" =~ /^--dry-run$/msx) {
        if ((!StringInterpolation(StringInterpolation { parts: [Variable("dry_run")] }, None) eq yes)) {
            $dry_run = 'yes';
            $rm = "echo $rm";
            $rm_rec = "echo $rm_rec";
            if (do {
$main_exit_code = system('test', '-n', "$ln_s") >> 8;
                $CHILD_ERROR == 0
            }) {
                                $ln_s = "echo $ln_s";
            }
            $cp = "echo $cp";
            $mkdir = "echo mkdir";
            $mkinstalldirs = "echo $mkinstalldirs";
        }
    } elsif ("$arg" =~ /^-f$/msx or "$arg" =~ /^--force$/msx) {
                $force = 'yes';
    } elsif ("$arg" =~ /^-.*$/msx) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "$progname: unrecognized option '$arg'";
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
            print $help;
if ( !( ($help) =~ m{\n\z}msx ) ) { print "\n"; }
        };
        exit 1;
    } elsif (1) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "$progname: too many arguments";
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
            print $help;
if ( !( ($help) =~ m{\n\z}msx ) ) { print "\n"; }
        };
        exit 1;
    }
}
if ((-f 'configure.ac')) {
    my $configure;
    my @configure;
    my %configure;
    $configure = "configure.ac";
}
else {
if ((-f 'configure. in')) {
        $configure = "configure.in";
}
    else {
        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "$progname: neither 'configure.ac' nor 'configure.in' exists";
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
            print $help;
if ( !( ($help) =~ m{\n\z}msx ) ) { print "\n"; }
        };
exit 1;
    }
}
my $files;
my @files;
my %files;
$files = 'po/Makefile.in.in';
if (StringInterpolation(StringInterpolation { parts: [Variable("automake")] }, None) eq q{}) {
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('egrep', '^(AC|IT)_PROG_INTLTOOL', $configure) >> 8;
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
        do {
    my $__echo_line = "ERROR: 'IT_PROG_INTLTOOL' must appear in $configure for intltool to work.";
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
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $grep_result_1;
my @grep_lines_1 = ();
my @grep_filenames_1 = ();
if (-e "aclocal.m4") {
    open my $fh, '<', "aclocal.m4" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_1, $line;
        push @grep_filenames_1, "aclocal.m4";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: aclocal.m4: No such file or directory\n"; }
my @grep_filtered_1 = grep { /generated\ automatically\ by\ aclocal/msx } @grep_lines_1;
$grep_result_1 = join "\n", @grep_filtered_1;
        if (!($grep_result_1 =~ m{\n\z}msx || $grep_result_1 eq q{})) {
            $grep_result_1 .= "\n";
        }
print $grep_result_1;
$CHILD_ERROR = scalar @grep_filtered_1 > 0 ? 0 : 1;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
        my $updatemsg;
        my @updatemsg;
        my %updatemsg;
        $updatemsg = "update your 'aclocal.m4' by running aclocal";
}
    else {
        $updatemsg = "add the contents of '$intltool_m4' to 'aclocal.m4'";
    }
if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('egrep', "^AC_DEFUN\\(\\[IT_PROG_INTLTOOL\\]", 'aclocal.m4') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
        my $instserial;
        my @instserial;
        my %instserial;
        $instserial = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_2 = q{};
        my $output_printed_2;
        my $output_3 = q{};
        while (my $line = <>) {
            chomp $line;
                        if (!($line =~ /^\#\ serial\ /msx)) {
                next;
            }
                        if (!($line =~ /IT_PROG_INTLTOOL/msx)) {
                next;
            }
            $line =~ "s/^# serial \\([0-9][0-9]*\\).*$/\\1/; q";
        }
        $output_3; };
}; $_pipeline_result; };
if (StringInterpolation(StringInterpolation { parts: [Variable("instserial")] }, None) eq q{}) {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "$progname: warning: no serial number on '$intltool_m4'";
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
            my $localserial;
            my @localserial;
            my %localserial;
            $localserial = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_4 = q{};
                my $output_printed_4;
                my $pipeline_success_4 = 1;
                my $grep_result_4_0;
                my @grep_lines_4_0 = ();
                my @grep_filenames_4_0 = ();
                if (-e "aclocal.m4") {
                    open my $fh, '<', "aclocal.m4" or croak "Cannot open file: $ERRNO";
                    while (my $line = <$fh>) {
                        chomp $line;
                        push @grep_lines_4_0, $line;
                        push @grep_filenames_4_0, "aclocal.m4";
                    }
                    close $fh
                        or croak "Close failed: $OS_ERROR";
                }
                else { print {*STDERR} "grep: aclocal.m4: No such file or directory\n"; }
                my @grep_filtered_4_0 = grep { /^\#\ serial\ /msx } @grep_lines_4_0;
                $grep_result_4_0 = join "\n", @grep_filtered_4_0;
                                if (!($grep_result_4_0 =~ m{\n\z}msx || $grep_result_4_0 eq q{})) {
                                    $grep_result_4_0 .= "\n";
                                }
                $CHILD_ERROR = scalar @grep_filtered_4_0 > 0 ? 0 : 1;
                $output_4 = $grep_result_4_0;
                if ($CHILD_ERROR != 0) { $pipeline_success_4 = 0; }
                my $grep_result_4_1;
                my @grep_lines_4_1 = split /\n/msx, $output_4;
                my @grep_filtered_4_1 = grep { /IT_PROG_INTLTOOL/msx } @grep_lines_4_1;
                $grep_result_4_1 = join "\n", @grep_filtered_4_1;
                                if (!($grep_result_4_1 =~ m{\n\z}msx || $grep_result_4_1 eq q{})) {
                                    $grep_result_4_1 .= "\n";
                                }
                $CHILD_ERROR = scalar @grep_filtered_4_1 > 0 ? 0 : 1;
                $output_4 = $grep_result_4_1;
                my @sed_lines_4 = split /\n/msx, $output_4;
                my @sed_result_4;
                foreach my $line (@sed_lines_4) {
                chomp $line;
                push @sed_result_4, $line;
                }
                $output_4 = join "\n", @sed_result_4;

                if ( !$pipeline_success_4 ) { $main_exit_code = 1; }
                $output_4 =~ s/\n+\z//msx;
                $output_4;
}; $_pipeline_result; };
            if (do {
$main_exit_code = system('test', '-z', "$localserial") >> 8;
                $CHILD_ERROR == 0
            }) {
                                $localserial = q{0};
            }
if ((StringInterpolation(StringInterpolation { parts: [Variable("localserial")] }, None) < StringInterpolation(StringInterpolation { parts: [Variable("instserial")] }, None))) {
                do {
    my $__echo_line = "You should $updatemsg.";
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
                if ((StringInterpolation(StringInterpolation { parts: [Variable("localserial")] }, None) > StringInterpolation(StringInterpolation { parts: [Variable("instserial")] }, None))) {
                    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                        do {
    my $__echo_line = "$progname: '$intltool_m4' is serial $instserial, less than $localserial in 'aclocal.m4'";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                        $CHILD_ERROR = 0;
                    };
if (StringInterpolation(StringInterpolation { parts: [Variable("force")] }, None) eq q{}) {
                        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                            print "Use '--force' to replace newer intltool files with this version.\n";
                        };
exit 1;
                    }
                    do {
    my $__echo_line = "To remain compatible, you should $updatemsg.";
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
}
    else {
        do {
    my $__echo_line = "You should $updatemsg.";
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
do {
    local %ENV = %ENV;
    my $mkdir = $mkdir;
    my $updatemsg = $updatemsg;
    my $help = $help;
    my $arg = $arg;
    my $progname = $progname;
    my $mkinstalldirs = $mkinstalldirs;
    my $datarootdir = $datarootdir;
    my $PACKAGE = $PACKAGE;
    my $VERSION = $VERSION;
    my $ln_s = $ln_s;
    my $files = $files;
    my $instserial = $instserial;
    my $rm_rec = $rm_rec;
    my $intltool_m4 = $intltool_m4;
    my $automake = $automake;
    my $PROGRAM = $PROGRAM;
    my $dry_run = $dry_run;
    my $cp = $cp;
    my $copy = $copy;
    my $localserial = $localserial;
    my $rm = $rm;
    my $prefix = $prefix;
    my $aclocaldir = $aclocaldir;
    my $datadir = $datadir;
    my $force = $force;
    my $pkgdatadir = $pkgdatadir;
    my $status = $status;
    my $configure = $configure;
        my $file;
        for my $file ($files) {
if ((!(            $main_exit_code = system('test', '-f', "$file") >> 8) && !(            $main_exit_code = system('test', '-z', "$force") >> 8))) {
                if (do {
$main_exit_code = system('test', '-z', "$automake") >> 8;
                    $CHILD_ERROR == 0
                }) {
                                        do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                        do {
    my $__echo_line = "$progname: '$file' exists: use '--force' to overwrite";
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
next;
            }
            $CHILD_ERROR = 0;
if ((!(            $main_exit_code = system('test', '-n', "$ln_s") >> 8) && !(            $CHILD_ERROR = 0))) {
                $main_exit_code = system('bash', ':') >> 8;
}
            else {
                if (!(                $CHILD_ERROR = 0)) {
                    $main_exit_code = system('bash', ':') >> 8;
}
                else {
                    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                        do {
    my $__echo_line = "$progname: cannot copy '$pkgdatadir/" . (do { my $_chomp_temp = do { use File::Basename qw(basename); my $basename_output = basename($file); $CHILD_ERROR = 0; $basename_output; }; chomp $_chomp_temp; $_chomp_temp; }) . "' to '$file'";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
                        $CHILD_ERROR = 0;
                    };
                    $status = q{1};
                }
            }
            my $script;
            for my $script ('intltool-extract.', 'in', 'intltool-merge.', 'in', 'intltool-update.', 'in') {
if ( -e "$script" ) {
                    if ( -d "$script" ) {
                        carp "rm: carping: ", $script,
          " is a directory (use -r to remove recursively)\n";
                    }
                    else {
                        if ( unlink "$script" ) {
                                                    }
                        else {
                            carp "rm: carping: could not remove ", $script,
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
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                    my $tmp = do {
                    $main_exit_code = system('egrep', $script, 'Makefile.am') >> 8;
                    };
                    print $tmp;
                    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
                })) {
                    if ( -e "$script" ) {
                        my $current_time = time;
                        utime $current_time, $current_time, "$script";
                    }
                    else {
                        if ( open my $fh, '>', "$script" ) {
                            close $fh or croak "Close failed: $ERRNO";
                        }
                        else {
                            croak "touch: cannot create ", "$script",
                              ": $ERRNO\n";
                        }
                    }
                }
            }
        }
    q{};
};
if ($CHILD_ERROR != 0) {
    }
my $m4dir;
my @m4dir;
my %m4dir;
$m4dir = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_6 = q{};
    my $output_printed_6;
    my $pipeline_success_6 = 1;
    $output_6 = do { my $cat_chunk = q{}; if ( open my $fh, '<', "$configure" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$configure" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
    if ($CHILD_ERROR != 0) { $pipeline_success_6 = 0; }
    my $grep_result_6_1;
    my @grep_lines_6_1 = split /\n/msx, $output_6;
    my @grep_filtered_6_1 = grep { /^AC_CONFIG_MACRO_DIR/msx } @grep_lines_6_1;
    $grep_result_6_1 = join "\n", @grep_filtered_6_1;
        if (!($grep_result_6_1 =~ m{\n\z}msx || $grep_result_6_1 eq q{})) {
            $grep_result_6_1 .= "\n";
        }
    $CHILD_ERROR = scalar @grep_filtered_6_1 > 0 ? 0 : 1;
    $output_6 = $grep_result_6_1;
    my @sed_lines_6 = split /\n/msx, $output_6;
    my @sed_result_6;
    foreach my $line (@sed_lines_6) {
    chomp $line;
    push @sed_result_6, $line;
    }
    $output_6 = join "\n", @sed_result_6;

    my @sed_lines_6 = split /\n/msx, $output_6;
    my @sed_result_6;
    foreach my $line (@sed_lines_6) {
    chomp $line;
    push @sed_result_6, $line;
    }
    $output_6 = join "\n", @sed_result_6;

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
if (StringInterpolation(StringInterpolation { parts: [Variable("m4dir")] }, None) ne q{}) {
if ( -e "$m4dir" ) {
        if ( -d "$m4dir" ) {
            carp "rm: carping: ", $m4dir,
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "$m4dir" ) {
                            }
            else {
                carp "rm: carping: could not remove ", $m4dir,
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ( -e "/intltool.m4" ) {
        if ( -d "/intltool.m4" ) {
            carp "rm: carping: ", "/intltool.m4",
          " is a directory (use -r to remove recursively)\n";
        }
        else {
            if ( unlink "/intltool.m4" ) {
                            }
            else {
                carp "rm: carping: could not remove ", "/intltool.m4",
              ": $OS_ERROR\n";
            }
        }
    }
    else {
        local $CHILD_ERROR = 0;
    }
if ((!(    $main_exit_code = system('test', '-n', "$ln_s") >> 8) && !(    $CHILD_ERROR = 0))) {
        $main_exit_code = system('bash', ':') >> 8;
}
    else {
        if (!(        $CHILD_ERROR = 0)) {
            $main_exit_code = system('bash', ':') >> 8;
}
        else {
            do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "$progname: cannot copy '$intltool_m4' to '$m4dir/intltool.m4'";
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
}
do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $grep_result_7;
my @grep_lines_7 = ();
my @grep_filenames_7 = ();
if (-e "po/Makefile.") {
    open my $fh, '<', "po/Makefile." or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_7, $line;
        push @grep_filenames_7, "po/Makefile.";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: po/Makefile.: No such file or directory\n"; }
if (-e "in") {
    open my $fh, '<', "in" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_7, $line;
        push @grep_filenames_7, "in";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: in: No such file or directory\n"; }
if (-e ".") {
    open my $fh, '<', "." or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_7, $line;
        push @grep_filenames_7, ".";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: .: No such file or directory\n"; }
if (-e "in") {
    open my $fh, '<', "in" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_7, $line;
        push @grep_filenames_7, "in";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: in: No such file or directory\n"; }
my @grep_filtered_7 = grep { /INTLTOOL_MAKEFILE/msx } @grep_lines_7;
$grep_result_7 = join "\n", @grep_filtered_7;
    if (!($grep_result_7 =~ m{\n\z}msx || $grep_result_7 eq q{})) {
        $grep_result_7 .= "\n";
    }
print $grep_result_7;
$CHILD_ERROR = scalar @grep_filtered_7 > 0 ? 0 : 1;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};
if ($CHILD_ERROR != 0) {
            do {
    my $__echo_line = "$progname: 'po/Makefile.in.in' is out of date: use '--force' to overwrite";
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
