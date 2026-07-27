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

my $LIBC;
my @LIBC;
my %LIBC;

my $MAGIC_386 = 386;
my $MAGIC_3   = 3;

my $timestamp;
my @timestamp;
my %timestamp;
$timestamp = '2022-01-09';
my $me;
my @me;
my %me;
$me = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
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
my $usage;
my @usage;
my %usage;
$usage = "\\\nUsage: $PROGRAM_NAME [OPTION]\n\nOutput the configuration name of the " . "sys" . "tem" . " \\" . chr(96) . "$me' is run on.

Options:
  -h, --help         print this help, then exit
  -t, --time-stamp   print date of last modification, then exit
  -v, --version      print version number, then exit

Report bugs and patches to <config-patches@gnu.org>.";
my $version;
my @version;
my %version;
$version = "\
GNU config.guess ($timestamp)

Originally written by Per Bothner.
Copyright 1992-2022 Free Software Foundation, Inc.

This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.";
my $help;
my @help;
my %help;
$help = "
Try \\" . chr(96) . "$me --help' for more information.";
my $# = 0;
while ( (Variable("#", false, None) > 0) ) {
if ($arg1 =~ /^--time-stamp$/msx or $arg1 =~ /^--time.*$/msx or $arg1 =~ /^-t$/msx) {
                print $timestamp;
if ( !( ($timestamp) =~ m{\n\z}msx ) ) { print "\n"; }
        exit $main_exit_code;
    } elsif ($arg1 =~ /^--version$/msx or $arg1 =~ /^-v$/msx) {
                print $version;
if ( !( ($version) =~ m{\n\z}msx ) ) { print "\n"; }
        exit $main_exit_code;
    } elsif ($arg1 =~ /^--help$/msx or $arg1 =~ /^--h.*$/msx or $arg1 =~ /^-h$/msx) {
                print $usage;
if ( !( ($usage) =~ m{\n\z}msx ) ) { print "\n"; }
        exit $main_exit_code;
    } elsif ($arg1 =~ /^--$/msx) {
        # Builtin command 'shift' not implemented
        last;    } elsif ($arg1 =~ /^-$/msx) {
        last;    } elsif ($arg1 =~ /^-.*$/msx) {
                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
            do {
    my $__echo_line = "$me: invalid option $_[0]$help";
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
    } elsif (1) {
        last;    }
}
if ((!Variable("#", false, None) eq 0)) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "$me: too many arguments$help";
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
my $GUESS;
my @GUESS;
my %GUESS;
$GUESS = q{};
my $tmp;
my @tmp;
my %tmp;
$tmp = q{};
END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx'test -z "$tmp" || rm -fr "$tmp" 2>&1'; print $end_out if $end_out ne q{}; }

sub set_cc_for_build {
    if (do {
$main_exit_code = system('test', "$tmp") >> 8;
        $CHILD_ERROR == 0
    }) {
        return q{0};    }
    $main_exit_code = system(':', ($ENV{TMPDIR=/tmp} // q{})) >> 8;
                    if (do {
if (do {
$tmp = do { my @_qx_cmd = ("(umask 077 && mktemp -d \"$TMPDIR/cgXXXXXX\") 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('test', '-n', "$tmp") >> 8;
}
            $CHILD_ERROR == 0
        }) {
                        $main_exit_code = system('test', '-d', "$tmp") >> 8;
        }
    if ($CHILD_ERROR != 0) {
                    if (do {
if (do {
$main_exit_code = system('test', '-n', "$ENV{RANDOM}") >> 8;
    $CHILD_ERROR == 0
}) {
        $tmp = $TMPDIR;
    $main_exit_code = system('/cg', $$, q{-}, $RANDOM) >> 8;
}
                $CHILD_ERROR == 0
            }) {
                                do {
                    local %ENV = %ENV;
                    my $# = $#;
                    my $usage = $usage;
                    my $timestamp = $timestamp;
                    my $help = $help;
                    my $tmp = $tmp;
                    my $version = $version;
                    my $me = $me;
                    my $GUESS = $GUESS;
                    if (do {
$main_exit_code = system('umask', '077') >> 8;
                        $CHILD_ERROR == 0
                    }) {
                                                do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                            use File::Path qw(make_path);
                            my $err;
                            if ( mkdir "$tmp" ) {
                                }
                            else {
                                croak "mkdir: cannot create directory " . "$tmp" . ": File exists\n";
                            }
                        };
                    }
                    q{};
                };
            }
    }
    if ($CHILD_ERROR != 0) {
                    $tmp = $TMPDIR;
            if (do {
if (do {
$main_exit_code = system('/cg-', $$) >> 8;
    $CHILD_ERROR == 0
}) {
        do {
        local %ENV = %ENV;
        my $# = $#;
        my $usage = $usage;
        my $timestamp = $timestamp;
        my $help = $help;
        my $tmp = $tmp;
        my $version = $version;
        my $err = $err;
        my $me = $me;
        my $GUESS = $GUESS;
        if (do {
$main_exit_code = system('umask', '077') >> 8;
            $CHILD_ERROR == 0
        }) {
                        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
                use File::Path qw(make_path);
                if ( mkdir "$tmp" ) {
                    }
                else {
                    croak "mkdir: cannot create directory " . "$tmp" . ": File exists\n";
                }
            };
        }
        q{};
    };
}
                $CHILD_ERROR == 0
            }) {
                                do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                    print "Warning: creating insecure temp directory\n";
                };
            }
    }
    if ($CHILD_ERROR != 0) {
                    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
                do {
    my $__echo_line = "$me: cannot create a temporary directory in $ENV{TMPDIR}";
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
    my $dummy;
    my @dummy;
    my %dummy;
    $dummy = $tmp;
    $main_exit_code = system('bash', '/dummy') >> 8;
if ("$ENV{CC_FOR_BUILD-},$ENV{HOST_CC-},$ENV{CC-}" =~ /^,,$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$dummy.c"
      or die "Cannot open file: $OS_ERROR\n";
            print "int x;\n";
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
                my $driver;
        for my $driver ('cc', 'gcc', 'c89', 'c99') {
if (!(            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
                do {
                    local %ENV = %ENV;
                    my $# = $#;
                    my $usage = $usage;
                    my $timestamp = $timestamp;
                    my $help = $help;
                    my $tmp = $tmp;
                    my $version = $version;
                    my $dummy = $dummy;
                    my $err = $err;
                    my $driver = $driver;
                    my $me = $me;
                    my $GUESS = $GUESS;
                    $CHILD_ERROR = 0;
                    q{};
                };
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            })) {
                my $CC_FOR_BUILD;
                my @CC_FOR_BUILD;
                my %CC_FOR_BUILD;
                $CC_FOR_BUILD = $driver;
last;
            }
        }
        if (x StringInterpolation(StringInterpolation { parts: [Variable("CC_FOR_BUILD")] }, None) eq x) {
            $CC_FOR_BUILD = 'no_compiler_found';
        }
    } elsif ("$ENV{CC_FOR_BUILD-},$ENV{HOST_CC-},$ENV{CC-}" =~ /^,,.*$/msx) {
                $CC_FOR_BUILD = $CC;
    } elsif ("$ENV{CC_FOR_BUILD-},$ENV{HOST_CC-},$ENV{CC-}" =~ /^,.*,.*$/msx) {
                $CC_FOR_BUILD = $HOST_CC;
    }
    return;
}
if ((-f '/.attbin/uname')) {
    my $PATH;
    my @PATH;
    my %PATH;
    $PATH = $PATH;
    $main_exit_code = system('bash', ':/.attbin') >> 8;
$ENV{PATH} = $PATH;
}
my $UNAME_MACHINE;
my @UNAME_MACHINE;
my %UNAME_MACHINE;
$UNAME_MACHINE = do { my @_qx_cmd = ("uname -m 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if ($CHILD_ERROR != 0) {
        $UNAME_MACHINE = 'unknown';
}
my $UNAME_RELEASE;
my @UNAME_RELEASE;
my %UNAME_RELEASE;
$UNAME_RELEASE = do { my @_qx_cmd = ("uname -r 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if ($CHILD_ERROR != 0) {
        $UNAME_RELEASE = 'unknown';
}
my $UNAME_SYSTEM;
my @UNAME_SYSTEM;
my %UNAME_SYSTEM;
$UNAME_SYSTEM = do { my @_qx_cmd = ("uname -s 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if ($CHILD_ERROR != 0) {
        $UNAME_SYSTEM = 'unknown';
}
my $UNAME_VERSION;
my @UNAME_VERSION;
my %UNAME_VERSION;
$UNAME_VERSION = do { my @_qx_cmd = ("uname -v 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if ($CHILD_ERROR != 0) {
        $UNAME_VERSION = 'unknown';
}
if ($UNAME_SYSTEM =~ /^Linux$/msx or $UNAME_SYSTEM =~ /^GNU$/msx or $UNAME_SYSTEM =~ /^GNU/.*$/msx) {
        $LIBC = 'unknown';
        set_cc_for_build();
    open my $fh_cat, '>', "\"$ENV{dummy}.c\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "\t#include <features.h>
\t#if defined(__UCLIBC__)
\tLIBC=uclibc
\t#elif defined(__dietlibc__)
\tLIBC=dietlibc
\t#elif defined(__GLIBC__)
\tLIBC=gnu
\t#else
\t#include <stdarg.h>
\t/* First heuristic to detect musl libc.  */
\t#ifdef __DEFINED_va_list
\tLIBC=musl
\t#endif
\t#endif
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
        my $cc_set_libc;
    my @cc_set_libc;
    my %cc_set_libc;
    $cc_set_libc = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_3 = q{};
        my $output_printed_3;
        my $pipeline_success_3 = 1;
        my ($in_4, $out_4);
        my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'unknown_command', '-E');
        close $in_4 or croak 'Close failed: $OS_ERROR';
        $output_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
        close $out_4 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_4, 0;
        my $grep_result_3_1;
        my @grep_lines_3_1 = split /\n/msx, $output_3;
        my @grep_filtered_3_1 = grep { /^LIBC/msx } @grep_lines_3_1;
        $grep_result_3_1 = join "\n", @grep_filtered_3_1;
        if (!($grep_result_3_1 =~ m{\n\z}msx || $grep_result_3_1 eq q{})) {
        $grep_result_3_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_3_1 > 0 ? 0 : 1;
        $output_3 = $grep_result_3_1;
        $output_3 = $grep_result_3_1;
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
    do { my $eval_input = $cc_set_libc; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
    if ((("$LIBC" eq unknown && !(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('command', '-v', 'ldd') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) && !({
        my $output_5 = q{};
        my $output_printed_5;
        my $pipeline_success_5 = 1;
                $output = q{};
                do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_6 = q{};

my $cmd_9 = 'ldd';
my ($in_8, $out_8);
my $pid_8 = open3($in_8, $out_8, '>&STDERR', $cmd_9, '--version');
print {$in_8} $output_5;
close $in_8 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_6 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_8> };
close $out_8 or croak 'Close failed: $OS_ERROR';
waitpid $pid_8, 0;
$tmp_redirect_6;
        };
        $output_5 = $output;

                my $grep_result_5_1;
        my @grep_lines_5_1 = split /\n/msx, $output_5;
        my @grep_filtered_5_1 = grep { /^musl/msx } @grep_lines_5_1;
        $grep_result_5_1 = join "\n", @grep_filtered_5_1;
        if (!($grep_result_5_1 =~ m{\n\z}msx || $grep_result_5_1 eq q{})) {
        $grep_result_5_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_5_1 > 0 ? 0 : 1;
        $grep_result_5_1 = q{};
        $output_5 = q{};
        if ((scalar @grep_filtered_5_1) == 0) {
            $pipeline_success_5 = 0;
        }
        if ($output_5 ne q{} && !defined $output_printed_5) {
            print $output_5;
            if (!($output_5 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_5 ) { $main_exit_code = 1; }
        }))) {
        $LIBC = 'musl';
    }
    if ("$LIBC" eq unknown) {
        $LIBC = 'gnu';
    }
}
if ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:NetBSD:.*:.*$/msx) {
        my $UNAME_MACHINE_ARCH;
    my @UNAME_MACHINE_ARCH;
    my %UNAME_MACHINE_ARCH;
    $UNAME_MACHINE_ARCH = do {
    my $command = '(uname -p 2> /dev/null || /sbin/sysctl -n hw.machine_arch 2> /dev/null || /usr/sbin/sysctl -n hw.machine_arch 2> /dev/null || echo unknown)';
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
};
    if ($UNAME_MACHINE_ARCH =~ /^aarch64eb$/msx) {
                my $machine;
        my @machine;
        my %machine;
        $machine = 'aarch64_be-unknown';
    } elsif ($UNAME_MACHINE_ARCH =~ /^armeb$/msx) {
                $machine = 'armeb-unknown';
    } elsif ($UNAME_MACHINE_ARCH =~ /^arm.*$/msx) {
                $machine = 'arm-unknown';
    } elsif ($UNAME_MACHINE_ARCH =~ /^sh3el$/msx) {
                $machine = 'shl-unknown';
    } elsif ($UNAME_MACHINE_ARCH =~ /^sh3eb$/msx) {
                $machine = 'sh-unknown';
    } elsif ($UNAME_MACHINE_ARCH =~ /^sh5el$/msx) {
                $machine = 'sh5le-unknown';
    } elsif ($UNAME_MACHINE_ARCH =~ /^earmv.*$/msx) {
                my $arch;
        my @arch;
        my %arch;
        $arch = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_10 = q{};
            my $output_printed_10;
            my $pipeline_success_10 = 1;
            $output_10 .= $UNAME_MACHINE_ARCH . "\n";
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
                my $endian;
        my @endian;
        my %endian;
        $endian = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_11 = q{};
            my $output_printed_11;
            my $pipeline_success_11 = 1;
            $output_11 .= $UNAME_MACHINE_ARCH . "\n";
            if ( !($output_11 =~ m{\n\z}msx) ) { $output_11 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_11 = 0; }
            my @sed_lines_11 = split /\n/msx, $output_11;
            my @sed_result_11;
            foreach my $line (@sed_lines_11) {
            chomp $line;
            push @sed_result_11, $line;
            }
            $output_11 = join "\n", @sed_result_11;

            if ( !$pipeline_success_11 ) { $main_exit_code = 1; }
            $output_11 =~ s/\n+\z//msx;
            $output_11;
}; $_pipeline_result; };
                $machine = $arch;
                $CHILD_ERROR = 0;
    } elsif (1) {
                $machine = $UNAME_MACHINE_ARCH;
                $main_exit_code = system('bash', '-unknown') >> 8;
    }
    if ($UNAME_MACHINE_ARCH =~ /^earm.*$/msx) {
                my $os;
        my @os;
        my %os;
        $os = 'netbsdelf';
    } elsif ($UNAME_MACHINE_ARCH =~ /^arm.*$/msx or $UNAME_MACHINE_ARCH =~ /^i386$/msx or $UNAME_MACHINE_ARCH =~ /^m68k$/msx or $UNAME_MACHINE_ARCH =~ /^ns32k$/msx or $UNAME_MACHINE_ARCH =~ /^sh3.*$/msx or $UNAME_MACHINE_ARCH =~ /^sparc$/msx or $UNAME_MACHINE_ARCH =~ /^vax$/msx) {
                set_cc_for_build();
        if (!(        # Original bash: echo __ELF__ | $CC_FOR_BUILD -E - 2>/dev/null \
{
            my $output_12 = q{};
            my $output_printed_12;
            my $pipeline_success_12 = 1;
            $output_12 .= '__ELF__' . "\n";
if ( !($output_12 =~ m{\n\z}msx) ) { $output_12 .= "\n"; }
$CHILD_ERROR = 0;

                        my $cmd_14 = 'unknown_command';
            my ($in_13, $out_13);
            my $pid_13 = open3($in_13, $out_13, '>&STDERR', $cmd_14, '-E', q{-});
            print {$in_13} $output_12;
            close $in_13 or croak 'Close failed: $OS_ERROR';
            $output_12 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_13> };
            close $out_13 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_13, 0;

                        my $grep_result_12_2;
            my @grep_lines_12_2 = split /\n/msx, $output_12;
            my @grep_filtered_12_2 = grep { /__ELF__/msx } @grep_lines_12_2;
            $grep_result_12_2 = join "\n", @grep_filtered_12_2;
            if (!($grep_result_12_2 =~ m{\n\z}msx || $grep_result_12_2 eq q{})) {
            $grep_result_12_2 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_12_2 > 0 ? 0 : 1;
            $grep_result_12_2 = q{};
            $output_12 = q{};
            if ((scalar @grep_filtered_12_2) == 0) {
                $pipeline_success_12 = 0;
            }
            if ($output_12 ne q{} && !defined $output_printed_12) {
                print $output_12;
                if (!($output_12 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_12 ) { $main_exit_code = 1; }
            })) {
            $os = 'netbsd';
}
        else {
            $os = 'netbsdelf';
        }
    } elsif (1) {
                $os = 'netbsd';
    }
    if ($UNAME_MACHINE_ARCH =~ /^earm.*$/msx) {
                my $expr;
        my @expr;
        my %expr;
        $expr = 's/^earmv[0-9]/-eabi/;s/eb$//';
                my $abi;
        my @abi;
        my %abi;
        $abi = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_15 = q{};
            my $output_printed_15;
            my $pipeline_success_15 = 1;
            $output_15 .= $UNAME_MACHINE_ARCH . "\n";
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
    }
    if ($UNAME_VERSION =~ /^Debian.*$/msx) {
                my $release;
        my @release;
        my %release;
        $release = '-gnu';
    } elsif (1) {
                $release = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_16 = q{};
            my $output_printed_16;
            my $pipeline_success_16 = 1;
            $output_16 .= $UNAME_RELEASE . "\n";
            if ( !($output_16 =~ m{\n\z}msx) ) { $output_16 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_16 = 0; }
            my @sed_lines_16 = split /\n/msx, $output_16;
            my @sed_result_16;
            foreach my $line (@sed_lines_16) {
            chomp $line;
            push @sed_result_16, $line;
            }
            $output_16 = join "\n", @sed_result_16;

            my @lines_17 = split /\n/msx, $output_16;
            my @result_17;
            foreach my $line (@lines_17) {
            chomp $line;
            my @fields = split /./msx, $line;
            my @sel = ();
            if (@fields > 0) { push @sel, $fields[0]; }
            if (@fields > 1) { push @sel, $fields[1]; }
            push @result_17, join(q{.}, @sel);
            }
            $output_16 = join "\n", @result_17;
            if ($output_16 ne q{} && !($output_16  =~ m{\n\z}msx)) { $output_16 .= "\n"; }

            if ( !$pipeline_success_16 ) { $main_exit_code = 1; }
            $output_16 =~ s/\n+\z//msx;
            $output_16;
}; $_pipeline_result; };
    }
        $GUESS = $machine;
        $main_exit_code = system('-', $os, $release, $abi-) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:Bitrig:.*:.*$/msx) {
        $UNAME_MACHINE_ARCH = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_18 = q{};
        my $output_printed_18;
        my $pipeline_success_18 = 1;

        my ($in_19, $out_19);
        my $pid_19 = open3($in_19, $out_19, '>&STDERR', 'arch', );
        close $in_19 or croak 'Close failed: $OS_ERROR';
        $output_18 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_19> };
        close $out_19 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_19, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_18 = 0; }
        my @sed_lines_18 = split /\n/msx, $output_18;
        my @sed_result_18;
        foreach my $line (@sed_lines_18) {
        chomp $line;
        $line =~ s/Bitrig.//gmsx;
        push @sed_result_18, $line;
        }
        $output_18 = join "\n", @sed_result_18;

        if ( !$pipeline_success_18 ) { $main_exit_code = 1; }
        $output_18 =~ s/\n+\z//msx;
        $output_18;
}; $_pipeline_result; };
        $GUESS = $UNAME_MACHINE_ARCH;
        $main_exit_code = system('-unknown-bitrig', $UNAME_RELEASE) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:OpenBSD:.*:.*$/msx) {
        $UNAME_MACHINE_ARCH = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_20 = q{};
        my $output_printed_20;
        my $pipeline_success_20 = 1;

        my ($in_21, $out_21);
        my $pid_21 = open3($in_21, $out_21, '>&STDERR', 'arch', );
        close $in_21 or croak 'Close failed: $OS_ERROR';
        $output_20 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_21> };
        close $out_21 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_21, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_20 = 0; }
        my @sed_lines_20 = split /\n/msx, $output_20;
        my @sed_result_20;
        foreach my $line (@sed_lines_20) {
        chomp $line;
        $line =~ s/OpenBSD.//gmsx;
        push @sed_result_20, $line;
        }
        $output_20 = join "\n", @sed_result_20;

        if ( !$pipeline_success_20 ) { $main_exit_code = 1; }
        $output_20 =~ s/\n+\z//msx;
        $output_20;
}; $_pipeline_result; };
        $GUESS = $UNAME_MACHINE_ARCH;
        $main_exit_code = system('-unknown-openbsd', $UNAME_RELEASE) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:SecBSD:.*:.*$/msx) {
        $UNAME_MACHINE_ARCH = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_22 = q{};
        my $output_printed_22;
        my $pipeline_success_22 = 1;

        my ($in_23, $out_23);
        my $pid_23 = open3($in_23, $out_23, '>&STDERR', 'arch', );
        close $in_23 or croak 'Close failed: $OS_ERROR';
        $output_22 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_23> };
        close $out_23 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_23, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_22 = 0; }
        my @sed_lines_22 = split /\n/msx, $output_22;
        my @sed_result_22;
        foreach my $line (@sed_lines_22) {
        chomp $line;
        $line =~ s/SecBSD.//gmsx;
        push @sed_result_22, $line;
        }
        $output_22 = join "\n", @sed_result_22;

        if ( !$pipeline_success_22 ) { $main_exit_code = 1; }
        $output_22 =~ s/\n+\z//msx;
        $output_22;
}; $_pipeline_result; };
        $GUESS = $UNAME_MACHINE_ARCH;
        $main_exit_code = system('-unknown-secbsd', $UNAME_RELEASE) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:LibertyBSD:.*:.*$/msx) {
        $UNAME_MACHINE_ARCH = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_24 = q{};
        my $output_printed_24;
        my $pipeline_success_24 = 1;

        my ($in_25, $out_25);
        my $pid_25 = open3($in_25, $out_25, '>&STDERR', 'arch', );
        close $in_25 or croak 'Close failed: $OS_ERROR';
        $output_24 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_25> };
        close $out_25 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_25, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_24 = 0; }
        my @sed_lines_24 = split /\n/msx, $output_24;
        my @sed_result_24;
        foreach my $line (@sed_lines_24) {
        chomp $line;
        $line =~ s/^.*BSD\.//gmsx;
        push @sed_result_24, $line;
        }
        $output_24 = join "\n", @sed_result_24;

        if ( !$pipeline_success_24 ) { $main_exit_code = 1; }
        $output_24 =~ s/\n+\z//msx;
        $output_24;
}; $_pipeline_result; };
        $GUESS = $UNAME_MACHINE_ARCH;
        $main_exit_code = system('-unknown-libertybsd', $UNAME_RELEASE) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:MidnightBSD:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-midnightbsd', $UNAME_RELEASE) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:ekkoBSD:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-ekkobsd', $UNAME_RELEASE) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:SolidBSD:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-solidbsd', $UNAME_RELEASE) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:OS108:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-os108_', $UNAME_RELEASE) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^macppc:MirBSD:.*:.*$/msx) {
        $GUESS = 'powerpc-unknown-mirbsd';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:MirBSD:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-mirbsd', $UNAME_RELEASE) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:Sortix:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-unknown-sortix') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:Twizzler:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-unknown-twizzler') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:Redox:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-unknown-redox') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^mips:OSF1:.*..*$/msx) {
        $GUESS = 'mips-dec-osf1';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^alpha:OSF1:.*:.*$/msx) {
    END { local $INPUT_RECORD_SEPARATOR = undef; my $end_out = qx' 2>&1'; print $end_out if $end_out ne q{}; }
    if ($UNAME_RELEASE =~ /^.*4.0$/msx) {
                $UNAME_RELEASE = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_26 = q{};
            my $output_printed_26;
            my $pipeline_success_26 = 1;

            my ($in_27, $out_27);
            my $pid_27 = open3($in_27, $out_27, '>&STDERR', '/usr/sbin/sizer', '-v');
            close $in_27 or croak 'Close failed: $OS_ERROR';
            $output_26 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_27> };
            close $out_27 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_27, 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_26 = 0; }
            my @lines = split /\n/msx, $output_26;
            my @result;
            foreach my $line (@lines) {
                chomp $line;
                if ($line =~ /^\s*$/msx) { next; }
                my @fields = split /\s+/msx, $line;
                push @result, ($fields[2] . "\n");
            }
            $output_26 = join "", @result;

            if ( !$pipeline_success_26 ) { $main_exit_code = 1; }
            $output_26 =~ s/\n+\z//msx;
            $output_26;
}; $_pipeline_result; };
    } elsif ($UNAME_RELEASE =~ /^.*5..*$/msx) {
                $UNAME_RELEASE = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_28 = q{};
            my $output_printed_28;
            my $pipeline_success_28 = 1;

            my ($in_29, $out_29);
            my $pid_29 = open3($in_29, $out_29, '>&STDERR', '/usr/sbin/sizer', '-v');
            close $in_29 or croak 'Close failed: $OS_ERROR';
            $output_28 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_29> };
            close $out_29 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_29, 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_28 = 0; }
            my @lines = split /\n/msx, $output_28;
            my @result;
            foreach my $line (@lines) {
                chomp $line;
                if ($line =~ /^\s*$/msx) { next; }
                my @fields = split /\s+/msx, $line;
                push @result, ($fields[3] . "\n");
            }
            $output_28 = join "", @result;

            if ( !$pipeline_success_28 ) { $main_exit_code = 1; }
            $output_28 =~ s/\n+\z//msx;
            $output_28;
}; $_pipeline_result; };
    }
        my $ALPHA_CPU_TYPE;
    my @ALPHA_CPU_TYPE;
    my %ALPHA_CPU_TYPE;
    $ALPHA_CPU_TYPE = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_30 = q{};
        my $output_printed_30;
        my $pipeline_success_30 = 1;

        my ($in_31, $out_31);
        my $pid_31 = open3($in_31, $out_31, '>&STDERR', '/usr/sbin/psrinfo', '-v');
        close $in_31 or croak 'Close failed: $OS_ERROR';
        $output_30 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_31> };
        close $out_31 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_31, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_30 = 0; }
        my @sed_lines_30 = split /\n/msx, $output_30;
        my @sed_result_30;
        foreach my $line (@sed_lines_30) {
        chomp $line;
        push @sed_result_30, $line;
        }
        $output_30 = join "\n", @sed_result_30;

        my $num_lines       = 1;
        my $head_line_count = 0;
        my $result          = q{};
        my $input           = $output_30;
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
        $output_30 = $result;

        if ( !$pipeline_success_30 ) { $main_exit_code = 1; }
        $output_30 =~ s/\n+\z//msx;
        $output_30;
}; $_pipeline_result; };
    if ($ALPHA_CPU_TYPE =~ /^EV4 (21064)$/msx) {
                $UNAME_MACHINE = 'alpha';
    } elsif ($ALPHA_CPU_TYPE =~ /^EV4.5 (21064)$/msx) {
                $UNAME_MACHINE = 'alpha';
    } elsif ($ALPHA_CPU_TYPE =~ /^LCA4 (21066/21068)$/msx) {
                $UNAME_MACHINE = 'alpha';
    } elsif ($ALPHA_CPU_TYPE =~ /^EV5 (21164)$/msx) {
                $UNAME_MACHINE = 'alphaev5';
    } elsif ($ALPHA_CPU_TYPE =~ /^EV5.6 (21164A)$/msx) {
                $UNAME_MACHINE = 'alphaev56';
    } elsif ($ALPHA_CPU_TYPE =~ /^EV5.6 (21164PC)$/msx) {
                $UNAME_MACHINE = 'alphapca56';
    } elsif ($ALPHA_CPU_TYPE =~ /^EV5.7 (21164PC)$/msx) {
                $UNAME_MACHINE = 'alphapca57';
    } elsif ($ALPHA_CPU_TYPE =~ /^EV6 (21264)$/msx) {
                $UNAME_MACHINE = 'alphaev6';
    } elsif ($ALPHA_CPU_TYPE =~ /^EV6.7 (21264A)$/msx) {
                $UNAME_MACHINE = 'alphaev67';
    } elsif ($ALPHA_CPU_TYPE =~ /^EV6.8CB (21264C)$/msx) {
                $UNAME_MACHINE = 'alphaev68';
    } elsif ($ALPHA_CPU_TYPE =~ /^EV6.8AL (21264B)$/msx) {
                $UNAME_MACHINE = 'alphaev68';
    } elsif ($ALPHA_CPU_TYPE =~ /^EV6.8CX (21264D)$/msx) {
                $UNAME_MACHINE = 'alphaev68';
    } elsif ($ALPHA_CPU_TYPE =~ /^EV6.9A (21264/EV69A)$/msx) {
                $UNAME_MACHINE = 'alphaev69';
    } elsif ($ALPHA_CPU_TYPE =~ /^EV7 (21364)$/msx) {
                $UNAME_MACHINE = 'alphaev7';
    } elsif ($ALPHA_CPU_TYPE =~ /^EV7.9 (21364A)$/msx) {
                $UNAME_MACHINE = 'alphaev79';
    }
        my $OSF_REL;
    my @OSF_REL;
    my %OSF_REL;
    $OSF_REL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_32 = q{};
        my $output_printed_32;
        my $pipeline_success_32 = 1;
        $output_32 .= $UNAME_RELEASE . "\n";
        if ( !($output_32 =~ m{\n\z}msx) ) { $output_32 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_32 = 0; }
        my @sed_lines_32 = split /\n/msx, $output_32;
        my @sed_result_32;
        foreach my $line (@sed_lines_32) {
        chomp $line;
        push @sed_result_32, $line;
        }
        $output_32 = join "\n", @sed_result_32;

        my $set1_33 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        my $set2_33 = 'abcdefghijklmnopqrstuvwxyz';
        my $input_33 = $output_32;
        # Expand character ranges for tr command
        my $expanded_set1_33 = $set1_33;
        my $expanded_set2_33 = $set2_33;
        # Handle a-z range in set1
        if ($expanded_set1_33 =~ /a-z/msx) {
            $expanded_set1_33 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set1
        if ($expanded_set1_33 =~ /A-Z/msx) {
            $expanded_set1_33 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set1
        if ($expanded_set1_33 =~ /\[:upper:\]/msx) {
            $expanded_set1_33 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set1
        if ($expanded_set1_33 =~ /\[:lower:\]/msx) {
            $expanded_set1_33 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle a-z range in set2
        if ($expanded_set2_33 =~ /a-z/msx) {
            $expanded_set2_33 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set2
        if ($expanded_set2_33 =~ /A-Z/msx) {
            $expanded_set2_33 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set2
        if ($expanded_set2_33 =~ /\[:upper:\]/msx) {
            $expanded_set2_33 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set2
        if ($expanded_set2_33 =~ /\[:lower:\]/msx) {
            $expanded_set2_33 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        my $tr_result_32_2 = q{};
        for my $char ( split //msx, $input_33 ) {
            my $pos_33 = index $expanded_set1_33, $char;
            if ( $pos_33 >= 0 && $pos_33 < length $expanded_set2_33 ) {
                $tr_result_32_2 .= substr $expanded_set2_33, $pos_33, 1;
            } else {
                $tr_result_32_2 .= $char;
            }
        }
                if (!($tr_result_32_2 =~ m{\n\z}msx || $tr_result_32_2 eq q{})) {
                    $tr_result_32_2 .= "\n";
                }
                $output_32 = $tr_result_32_2;
        if ( !$pipeline_success_32 ) { $main_exit_code = 1; }
        $output_32 =~ s/\n+\z//msx;
        $output_32;
}; $_pipeline_result; };
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-dec-osf', $OSF_REL) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^Amiga.*:UNIX_System_V:4.0:.*$/msx) {
        $GUESS = 'm68k-unknown-sysv4';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:\[Aa\]miga\[Oo\]\[Ss\]:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-unknown-amigaos') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:\[Mm\]orph\[Oo\]\[Ss\]:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-unknown-morphos') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:OS/390:.*:.*$/msx) {
        $GUESS = 'i370-ibm-openedition';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:z/VM:.*:.*$/msx) {
        $GUESS = 's390-ibm-zvmoe';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:OS400:.*:.*$/msx) {
        $GUESS = 'powerpc-ibm-os400';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^arm:RISC.*:1.\[012\].*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^arm:riscix:1.\[012\].*:.*$/msx) {
        $GUESS = 'arm-acorn-riscix';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^arm.*:riscos:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^arm.*:RISCOS:.*:.*$/msx) {
        $GUESS = 'arm-unknown-riscos';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^SR2.01:HI-UX/MPP:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^SR8000:HI-UX/MPP:.*:.*$/msx) {
        $GUESS = 'hppa1.1';
        $main_exit_code = system('-h', 'itachi-hiuxmpp') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^Pyramid.*:OSx.*:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^MIS.*:OSx.*:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^MIS.*:SMP_DC-OSx.*:.*:.*$/msx) {
    if (do { my @_qx_cmd = ("/bin/universe 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; } =~ /^att$/msx) {
                $GUESS = 'pyramid-pyramid-sysv3';
    } elsif (1) {
                $GUESS = 'pyramid-pyramid-bsd';
    }
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^NILE.*:.*:.*:dcosx$/msx) {
        $GUESS = 'pyramid-pyramid-svr4';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^DRS.6000:unix:4.0:6.*$/msx) {
        $GUESS = 'sparc-icl-nx6';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^DRS.6000:UNIX_SV:4.2.*:7.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^DRS.6000:isis:4.2.*:7.*$/msx) {
    if (do {
    my ($in_34, $out_34);
    my $pid_34 = open3($in_34, $out_34, '>&STDERR', '/usr/bin/uname', '-p');
    close $in_34 or croak 'Close failed: $OS_ERROR';
    my $result_34 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_34> };
    close $out_34 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_34, 0;
    $result_34
} =~ /^sparc$/msx) {
                $GUESS = 'sparc-icl-nx7';
    }
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^s390x:SunOS:.*:.*$/msx) {
        my $SUN_REL;
    my @SUN_REL;
    my %SUN_REL;
    $SUN_REL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_35 = q{};
        my $output_printed_35;
        my $pipeline_success_35 = 1;
        $output_35 .= $UNAME_RELEASE . "\n";
        if ( !($output_35 =~ m{\n\z}msx) ) { $output_35 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_35 = 0; }
        my @sed_lines_35 = split /\n/msx, $output_35;
        my @sed_result_35;
        foreach my $line (@sed_lines_35) {
        chomp $line;
        push @sed_result_35, $line;
        }
        $output_35 = join "\n", @sed_result_35;

        if ( !$pipeline_success_35 ) { $main_exit_code = 1; }
        $output_35 =~ s/\n+\z//msx;
        $output_35;
}; $_pipeline_result; };
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-ibm-solaris2', $SUN_REL) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^sun4H:SunOS:5..*:.*$/msx) {
        $SUN_REL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_36 = q{};
        my $output_printed_36;
        my $pipeline_success_36 = 1;
        $output_36 .= $UNAME_RELEASE . "\n";
        if ( !($output_36 =~ m{\n\z}msx) ) { $output_36 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_36 = 0; }
        my @sed_lines_36 = split /\n/msx, $output_36;
        my @sed_result_36;
        foreach my $line (@sed_lines_36) {
        chomp $line;
        push @sed_result_36, $line;
        }
        $output_36 = join "\n", @sed_result_36;

        if ( !$pipeline_success_36 ) { $main_exit_code = 1; }
        $output_36 =~ s/\n+\z//msx;
        $output_36;
}; $_pipeline_result; };
        $GUESS = 'sparc-hal-solaris2';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^sun4.*:SunOS:5..*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^tadpole.*:SunOS:5..*:.*$/msx) {
        $SUN_REL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_37 = q{};
        my $output_printed_37;
        my $pipeline_success_37 = 1;
        $output_37 .= $UNAME_RELEASE . "\n";
        if ( !($output_37 =~ m{\n\z}msx) ) { $output_37 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_37 = 0; }
        my @sed_lines_37 = split /\n/msx, $output_37;
        my @sed_result_37;
        foreach my $line (@sed_lines_37) {
        chomp $line;
        push @sed_result_37, $line;
        }
        $output_37 = join "\n", @sed_result_37;

        if ( !$pipeline_success_37 ) { $main_exit_code = 1; }
        $output_37 =~ s/\n+\z//msx;
        $output_37;
}; $_pipeline_result; };
        $GUESS = 'sparc-sun-solaris2';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i86pc:AuroraUX:5..*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i86xen:AuroraUX:5..*:.*$/msx) {
        $GUESS = 'i386-pc-auroraux';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i86pc:SunOS:5..*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i86xen:SunOS:5..*:.*$/msx) {
        set_cc_for_build();
        my $SUN_ARCH;
    my @SUN_ARCH;
    my %SUN_ARCH;
    $SUN_ARCH = 'i386';
    if ((!StringInterpolation(StringInterpolation { parts: [Variable("CC_FOR_BUILD")] }, None) eq no_compiler_found)) {
if (!(        # Original bash: #! /bin/sh
{
            my $output_38 = q{};
            my $output_printed_38;
            my $pipeline_success_38 = 1;
                        $output_38 = q{};
            $output_38 .= '#ifdef __amd64' . "\n";
            if ( !($output_38 =~ m{\n\z}msx) ) { $output_38 .= "\n"; }
            $CHILD_ERROR = 0;
            $output_38 .= 'IS_64BIT_ARCH' . "\n";
            if ( !($output_38 =~ m{\n\z}msx) ) { $output_38 .= "\n"; }
            $CHILD_ERROR = 0;
            $output_38 .= '#endif' . "\n";
            if ( !($output_38 =~ m{\n\z}msx) ) { $output_38 .= "\n"; }
            $CHILD_ERROR = 0;

                        $output_38 = q{};
            my @_pcmd_40 = ('sh', '-c', ': "Complex command cannot be converted to shell command"');
            my ($in_39, $out_39);
            my $pid_39 = open3($in_39, $out_39, '>&STDERR', @_pcmd_40);
            close $in_39 or croak 'Close failed: $OS_ERROR';
            $output_38 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_39> };
            close $out_39 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_39, 0;
            my @_pcmd_42 = ('sh', '-c', '$CC_FOR_BUILD -m64 -E - 2> /dev/null');
            my ($in_41, $out_41);
            my $pid_41 = open3($in_41, $out_41, '>&STDERR', @_pcmd_42);
            close $in_41 or croak 'Close failed: $OS_ERROR';
            $output_38 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_41> };
            close $out_41 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_41, 0;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_43 = q{};
            my $grep_result_44;
            my @grep_lines_44 = split /\n/msx, $output_38;
            my @grep_filtered_44 = grep { /IS_64BIT_ARCH/msx } @grep_lines_44;
            $grep_result_44 = join "\n", @grep_filtered_44;
            if (!($grep_result_44 =~ m{\n\z}msx || $grep_result_44 eq q{})) {
            $grep_result_44 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_44 > 0 ? 0 : 1;
            $tmp_redirect_43 = $grep_result_44;
            $tmp_redirect_43;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_38; }
            $output_printed_38 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_38 ) { $main_exit_code = 1; }
            })) {
            $SUN_ARCH = 'x86_64';
        }
    }
        $SUN_REL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_45 = q{};
        my $output_printed_45;
        my $pipeline_success_45 = 1;
        $output_45 .= $UNAME_RELEASE . "\n";
        if ( !($output_45 =~ m{\n\z}msx) ) { $output_45 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_45 = 0; }
        my @sed_lines_45 = split /\n/msx, $output_45;
        my @sed_result_45;
        foreach my $line (@sed_lines_45) {
        chomp $line;
        push @sed_result_45, $line;
        }
        $output_45 = join "\n", @sed_result_45;

        if ( !$pipeline_success_45 ) { $main_exit_code = 1; }
        $output_45 =~ s/\n+\z//msx;
        $output_45;
}; $_pipeline_result; };
        $GUESS = $SUN_ARCH;
        $main_exit_code = system('-pc-solaris2', $SUN_REL) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^sun4.*:SunOS:6.*:.*$/msx) {
        $SUN_REL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_46 = q{};
        my $output_printed_46;
        my $pipeline_success_46 = 1;
        $output_46 .= $UNAME_RELEASE . "\n";
        if ( !($output_46 =~ m{\n\z}msx) ) { $output_46 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_46 = 0; }
        my @sed_lines_46 = split /\n/msx, $output_46;
        my @sed_result_46;
        foreach my $line (@sed_lines_46) {
        chomp $line;
        push @sed_result_46, $line;
        }
        $output_46 = join "\n", @sed_result_46;

        if ( !$pipeline_success_46 ) { $main_exit_code = 1; }
        $output_46 =~ s/\n+\z//msx;
        $output_46;
}; $_pipeline_result; };
        $GUESS = 'sparc-sun-solaris3';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^sun4.*:SunOS:.*:.*$/msx) {
    if (do {
    my ($in_47, $out_47);
    my $pid_47 = open3($in_47, $out_47, '>&STDERR', '/usr/bin/arch', '-k');
    close $in_47 or croak 'Close failed: $OS_ERROR';
    my $result_47 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_47> };
    close $out_47 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_47, 0;
    $result_47
} =~ /^Series.*$/msx or do {
    my ($in_48, $out_48);
    my $pid_48 = open3($in_48, $out_48, '>&STDERR', '/usr/bin/arch', '-k');
    close $in_48 or croak 'Close failed: $OS_ERROR';
    my $result_48 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_48> };
    close $out_48 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_48, 0;
    $result_48
} =~ /^S4.*$/msx) {
                $UNAME_RELEASE = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__ver; join(" ", @__parts) . "\n"; };
    }
        $SUN_REL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_49 = q{};
        my $output_printed_49;
        my $pipeline_success_49 = 1;
        $output_49 .= $UNAME_RELEASE . "\n";
        if ( !($output_49 =~ m{\n\z}msx) ) { $output_49 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_49 = 0; }
        my @sed_lines_49 = split /\n/msx, $output_49;
        my @sed_result_49;
        foreach my $line (@sed_lines_49) {
        chomp $line;
        push @sed_result_49, $line;
        }
        $output_49 = join "\n", @sed_result_49;

        if ( !$pipeline_success_49 ) { $main_exit_code = 1; }
        $output_49 =~ s/\n+\z//msx;
        $output_49;
}; $_pipeline_result; };
        $GUESS = 'sparc-sun-sunos';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^sun3.*:SunOS:.*:.*$/msx) {
        $GUESS = 'm68k-sun-sunos';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^sun.*:.*:4.2BSD:.*$/msx) {
        $UNAME_RELEASE = do { my @_qx_cmd = ("(sed 1q /etc/motd | awk '{print substr($5,1,3)}') 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
        if (do {
$main_exit_code = system('test', "x$UNAME_RELEASE", q{=}, q{x}) >> 8;
        $CHILD_ERROR == 0
    }) {
                $UNAME_RELEASE = q{3};
    }
    if (do {
    my ($in_50, $out_50);
    my $pid_50 = open3($in_50, $out_50, '>&STDERR', '/bin/arch');
    close $in_50 or croak 'Close failed: $OS_ERROR';
    my $result_50 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_50> };
    close $out_50 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_50, 0;
    $result_50
} =~ /^sun3$/msx) {
                $GUESS = 'm68k-sun-sunos';
                $CHILD_ERROR = 0;
    } elsif (do {
    my ($in_51, $out_51);
    my $pid_51 = open3($in_51, $out_51, '>&STDERR', '/bin/arch');
    close $in_51 or croak 'Close failed: $OS_ERROR';
    my $result_51 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_51> };
    close $out_51 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_51, 0;
    $result_51
} =~ /^sun4$/msx) {
                $GUESS = 'sparc-sun-sunos';
                $CHILD_ERROR = 0;
    }
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^aushp:SunOS:.*:.*$/msx) {
        $GUESS = 'sparc-auspex-sunos';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^atarist\[e\]:.*MiNT:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^atarist\[e\]:.*mint:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^atarist\[e\]:.*TOS:.*:.*$/msx) {
        $GUESS = 'm68k-atari-mint';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^atari.*:.*MiNT:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^atari.*:.*mint:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^atarist\[e\]:.*TOS:.*:.*$/msx) {
        $GUESS = 'm68k-atari-mint';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*falcon.*:.*MiNT:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*falcon.*:.*mint:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*falcon.*:.*TOS:.*:.*$/msx) {
        $GUESS = 'm68k-atari-mint';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^milan.*:.*MiNT:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^milan.*:.*mint:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*milan.*:.*TOS:.*:.*$/msx) {
        $GUESS = 'm68k-milan-mint';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^hades.*:.*MiNT:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^hades.*:.*mint:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*hades.*:.*TOS:.*:.*$/msx) {
        $GUESS = 'm68k-hades-mint';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:.*MiNT:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:.*mint:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:.*TOS:.*:.*$/msx) {
        $GUESS = 'm68k-unknown-mint';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^m68k:machten:.*:.*$/msx) {
        $GUESS = 'm68k-apple-machten';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^powerpc:machten:.*:.*$/msx) {
        $GUESS = 'powerpc-apple-machten';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^RISC.*:Mach:.*:.*$/msx) {
        $GUESS = 'mips-dec-mach_bsd4.3';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^RISC.*:ULTRIX:.*:.*$/msx) {
        $GUESS = 'mips-dec-ultrix';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^VAX.*:ULTRIX.*:.*:.*$/msx) {
        $GUESS = 'vax-dec-ultrix';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^2020:CLIX:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^2430:CLIX:.*:.*$/msx) {
        $GUESS = 'clipper-intergraph-clix';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^mips:.*:.*:UMIPS$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^mips:.*:.*:RISCos$/msx) {
        set_cc_for_build();
    my $temp_content = '#ifdef __cplusplus
#include <stdio.h>  /* for printf() prototype */
	int main (int argc, char *argv[]) {
#else
	int main (argc, argv) int argc; char *argv[]; {
#endif
	#if defined (host_mips) && defined (MIPSEB)
	#if defined (SYSTYPE_SYSV)
	  printf ("mips-mips-riscos%ssysv\\n", argv[1]); exit (0);
	#endif
	#if defined (SYSTYPE_SVR4)
	  printf ("mips-mips-riscos%ssvr4\\n", argv[1]); exit (0);
	#endif
	#if defined (SYSTYPE_BSD43) || defined(SYSTYPE_BSD)
	  printf ("mips-mips-riscos%sbsd\\n", argv[1]); exit (0);
	#endif
	#endif
	  exit (-1);
	}
';
use File::Path qw(make_path);
if (!-d q{/tmp}) { make_path(q{/tmp}); }
open my $fh_1, '>', q{/tmp} . '/heredoc_temp' or croak "Cannot create temp file: $OS_ERROR\n";
print $fh_1 $temp_content;
close $fh_1 or croak "Close failed: $OS_ERROR\n";
open STDIN, '<', q{/tmp} . '/heredoc_temp' or croak "Cannot open temp file: $OS_ERROR\n";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$ENV{dummy}.c"
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
my @sed_lines_52 = split /\n/msx, $;
my @sed_result_52;
foreach my $line (@sed_lines_52) {
chomp $line;
$line =~ s/^	//gmsx;
push @sed_result_52, $line;
}
$ = join "\n", @sed_result_52;

        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
        if (do {
if (do {
if (do {
$CHILD_ERROR = 0;
    $CHILD_ERROR == 0
}) {
        my $dummyarg;
    my @dummyarg;
    my %dummyarg;
    $dummyarg = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_53 = q{};
        my $output_printed_53;
        my $pipeline_success_53 = 1;
        $output_53 .= $UNAME_RELEASE . "\n";
        if ( !($output_53 =~ m{\n\z}msx) ) { $output_53 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_53 = 0; }
        my @sed_lines_53 = split /\n/msx, $output_53;
        my @sed_result_53;
        foreach my $line (@sed_lines_53) {
        chomp $line;
        push @sed_result_53, $line;
        }
        $output_53 = join "\n", @sed_result_53;

        if ( !$pipeline_success_53 ) { $main_exit_code = 1; }
        $output_53 =~ s/\n+\z//msx;
        $output_53;
}; $_pipeline_result; };
}
    $CHILD_ERROR == 0
}) {
        my $SYSTEM_NAME;
    my @SYSTEM_NAME;
    my %SYSTEM_NAME;
    $SYSTEM_NAME = do {
    my ($in_54, $out_54);
    my $pid_54 = open3($in_54, $out_54, '>&STDERR', "$ENV{dummy}", "$dummyarg");
    close $in_54 or croak 'Close failed: $OS_ERROR';
    my $result_54 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_54> };
    close $out_54 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_54, 0;
    $result_54
};
}
        $CHILD_ERROR == 0
    }) {
                    print $SYSTEM_NAME;
if ( !( ($SYSTEM_NAME) =~ m{\n\z}msx ) ) { print "\n"; }
exit $main_exit_code;
    }
        $GUESS = 'mips-mips-riscos';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^Motorola:PowerMAX_OS:.*:.*$/msx) {
        $GUESS = 'powerpc-motorola-powermax';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^Motorola:.*:4.3:PL8-.*$/msx) {
        $GUESS = 'powerpc-harris-powermax';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^Night_Hawk:.*:.*:PowerMAX_OS$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^Synergy:PowerMAX_OS:.*:.*$/msx) {
        $GUESS = 'powerpc-harris-powermax';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^Night_Hawk:Power_UNIX:.*:.*$/msx) {
        $GUESS = 'powerpc-harris-powerunix';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^m88k:CX/UX:7.*:.*$/msx) {
        $GUESS = 'm88k-harris-cxux7';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^m88k:.*:4.*:R4.*$/msx) {
        $GUESS = 'm88k-motorola-sysv4';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^m88k:.*:3.*:R3.*$/msx) {
        $GUESS = 'm88k-motorola-sysv3';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^AViiON:dgux:.*:.*$/msx) {
        my $UNAME_PROCESSOR;
    my @UNAME_PROCESSOR;
    my %UNAME_PROCESSOR;
    $UNAME_PROCESSOR = do {
    my ($in_55, $out_55);
    my $pid_55 = open3($in_55, $out_55, '>&STDERR', '/usr/bin/uname', '-p');
    close $in_55 or croak 'Close failed: $OS_ERROR';
    my $result_55 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_55> };
    close $out_55 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_55, 0;
    $result_55
};
    if ((!(    $main_exit_code = system('test', "$UNAME_PROCESSOR", q{=}, 'mc88100') >> 8) || !(    $main_exit_code = system('test', "$UNAME_PROCESSOR", q{=}, 'mc88110') >> 8))) {
if ((!(        $main_exit_code = system('test', "$ENV{TARGET_BINARY_INTERFACE}", q{x}, q{=}, 'm88kdguxelfx') >> 8) || !(        $main_exit_code = system('test', "$ENV{TARGET_BINARY_INTERFACE}", q{x}, q{=}, q{x}) >> 8))) {
            $GUESS = 'm88k-dg-dgux';
            $CHILD_ERROR = 0;
}
        else {
            $GUESS = 'm88k-dg-dguxbcs';
            $CHILD_ERROR = 0;
        }
}
    else {
        $GUESS = 'i586-dg-dgux';
        $CHILD_ERROR = 0;
    }
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^M88.*:DolphinOS:.*:.*$/msx) {
        $GUESS = 'm88k-dolphin-sysv3';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^M88.*:.*:R3.*:.*$/msx) {
        $GUESS = 'm88k-motorola-sysv3';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^XD88.*:.*:.*:.*$/msx) {
        $GUESS = 'm88k-tektronix-sysv3';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^Tek43\[0-9\]\[0-9\]:UTek:.*:.*$/msx) {
        $GUESS = 'm68k-tektronix-bsd';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:IRIX.*:.*:.*$/msx) {
        my $IRIX_REL;
    my @IRIX_REL;
    my %IRIX_REL;
    $IRIX_REL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_56 = q{};
        my $output_printed_56;
        my $pipeline_success_56 = 1;
        $output_56 .= $UNAME_RELEASE . "\n";
        if ( !($output_56 =~ m{\n\z}msx) ) { $output_56 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_56 = 0; }
        my @sed_lines_56 = split /\n/msx, $output_56;
        my @sed_result_56;
        foreach my $line (@sed_lines_56) {
        chomp $line;
        push @sed_result_56, $line;
        }
        $output_56 = join "\n", @sed_result_56;

        if ( !$pipeline_success_56 ) { $main_exit_code = 1; }
        $output_56 =~ s/\n+\z//msx;
        $output_56;
}; $_pipeline_result; };
        $GUESS = 'mips-sgi-irix';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^........:AIX.:\[12\].1:2$/msx) {
        $GUESS = 'romp-ibm-aix';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*86:AIX:.*:.*$/msx) {
        $GUESS = 'i386-ibm-aix';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^ia64:AIX:.*:.*$/msx) {
    if ((-x '/usr/bin/oslevel')) {
        my $IBM_REV;
        my @IBM_REV;
        my %IBM_REV;
        $IBM_REV = do {
    my ($in_57, $out_57);
    my $pid_57 = open3($in_57, $out_57, '>&STDERR', '/usr/bin/oslevel');
    close $in_57 or croak 'Close failed: $OS_ERROR';
    my $result_57 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_57> };
    close $out_57 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_57, 0;
    $result_57
};
}
    else {
        $IBM_REV = "$UNAME_VERSION.";
        $CHILD_ERROR = 0;
    }
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-ibm-aix', $IBM_REV) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:AIX:2:3$/msx) {
    if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $grep_result_58;
my @grep_lines_58 = ();
my @grep_filenames_58 = ();
if (-e "/usr/include/stdio.h") {
    open my $fh, '<', "/usr/include/stdio.h" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_58, $line;
        push @grep_filenames_58, "/usr/include/stdio.h";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /usr/include/stdio.h: No such file or directory\n"; }
my @grep_filtered_58 = grep { /bos325/msx } @grep_lines_58;
$grep_result_58 = join "\n", @grep_filtered_58;
        if (!($grep_result_58 =~ m{\n\z}msx || $grep_result_58 eq q{})) {
            $grep_result_58 .= "\n";
        }
print $grep_result_58;
$CHILD_ERROR = scalar @grep_filtered_58 > 0 ? 0 : 1;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
        set_cc_for_build();
my $temp_content = '		#include <sys/systemcfg.h>

		main()
			{
			if (!__power_pc())
				exit(1);
			puts("powerpc-ibm-aix3.2.5");
			exit(0);
			}
';
use File::Path qw(make_path);
if (!-d q{/tmp}) { make_path(q{/tmp}); }
open my $fh_2, '>', q{/tmp} . '/heredoc_temp' or croak "Cannot create temp file: $OS_ERROR\n";
print $fh_2 $temp_content;
close $fh_2 or croak "Close failed: $OS_ERROR\n";
open STDIN, '<', q{/tmp} . '/heredoc_temp' or croak "Cannot open temp file: $OS_ERROR\n";
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$ENV{dummy}.c"
      or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
my @sed_lines_59 = split /\n/msx, $;
my @sed_result_59;
foreach my $line (@sed_lines_59) {
chomp $line;
$line =~ s/^		//gmsx;
push @sed_result_59, $line;
}
$ = join "\n", @sed_result_59;

            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
if ((!(        $CHILD_ERROR = 0) && !(        $SYSTEM_NAME = do {
    my ($in_60, $out_60);
    my $pid_60 = open3($in_60, $out_60, '>&STDERR', "$ENV{dummy}");
    close $in_60 or croak 'Close failed: $OS_ERROR';
    my $result_60 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_60> };
    close $out_60 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_60, 0;
    $result_60
}))) {
            $GUESS = $SYSTEM_NAME;
}
        else {
            $GUESS = 'rs6000-ibm-aix3.2.5';
        }
}
    else {
        if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $grep_result_61;
my @grep_lines_61 = ();
my @grep_filenames_61 = ();
if (-e "/usr/include/stdio.h") {
    open my $fh, '<', "/usr/include/stdio.h" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_61, $line;
        push @grep_filenames_61, "/usr/include/stdio.h";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /usr/include/stdio.h: No such file or directory\n"; }
my @grep_filtered_61 = grep { /bos324/msx } @grep_lines_61;
$grep_result_61 = join "\n", @grep_filtered_61;
            if (!($grep_result_61 =~ m{\n\z}msx || $grep_result_61 eq q{})) {
                $grep_result_61 .= "\n";
            }
print $grep_result_61;
$CHILD_ERROR = scalar @grep_filtered_61 > 0 ? 0 : 1;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
            $GUESS = 'rs6000-ibm-aix3.2.4';
}
        else {
            $GUESS = 'rs6000-ibm-aix3.2';
        }
    }
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:AIX:.*:\[4567\]$/msx) {
        my $IBM_CPU_ID;
    my @IBM_CPU_ID;
    my %IBM_CPU_ID;
    $IBM_CPU_ID = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_62 = q{};
        my $output_printed_62;
        my $pipeline_success_62 = 1;

        my ($in_63, $out_63);
        my $pid_63 = open3($in_63, $out_63, '>&STDERR', '/usr/sbin/lsdev', '-C', '-c', 'processor', '-S', 'available');
        close $in_63 or croak 'Close failed: $OS_ERROR';
        $output_62 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_63> };
        close $out_63 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_63, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_62 = 0; }
        my @sed_lines_62 = split /\n/msx, $output_62;
        my @sed_result_62;
        foreach my $line (@sed_lines_62) {
        chomp $line;
        push @sed_result_62, $line;
        }
        $output_62 = join "\n", @sed_result_62;

        my @lines = split /\n/msx, $output_62;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\s+/msx, $line;
            push @result, ($fields[0] . "\n");
        }
        $output_62 = join "", @result;

        if ( !$pipeline_success_62 ) { $main_exit_code = 1; }
        $output_62 =~ s/\n+\z//msx;
        $output_62;
}; $_pipeline_result; };
    if (!(    # Original bash: /usr/sbin/lsattr -El "$IBM_CPU_ID" | grep ' POWER' >/dev/null 2>&1;
{
        my $output_64 = q{};
        my $output_printed_64;
        my $pipeline_success_64 = 1;
                my ($in_65, $out_65);
        my $pid_65 = open3($in_65, $out_65, '>&STDERR', '/usr/sbin/lsattr', '-El');
        close $in_65 or croak 'Close failed: $OS_ERROR';
        $output_64 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_65> };
        close $out_65 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_65, 0;

                my $grep_result_64_1;
        my @grep_lines_64_1 = split /\n/msx, $output_64;
        my @grep_filtered_64_1 = grep { /\ POWER/msx } @grep_lines_64_1;
        $grep_result_64_1 = join "\n", @grep_filtered_64_1;
        if (!($grep_result_64_1 =~ m{\n\z}msx || $grep_result_64_1 eq q{})) {
        $grep_result_64_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_64_1 > 0 ? 0 : 1;
        $output_64 = $grep_result_64_1;
        if ( !$pipeline_success_64 ) { $main_exit_code = 1; }
        })) {
        my $IBM_ARCH;
        my @IBM_ARCH;
        my %IBM_ARCH;
        $IBM_ARCH = 'rs6000';
}
    else {
        $IBM_ARCH = 'powerpc';
    }
    if ((-x '/usr/bin/lslpp')) {
        $IBM_REV = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_66 = q{};
            my $output_printed_66;
            my $pipeline_success_66 = 1;

            my ($in_67, $out_67);
            my $pid_67 = open3($in_67, $out_67, '>&STDERR', '/usr/bin/lslpp', '-L', 'qc', 'bos.rte.libc');
            close $in_67 or croak 'Close failed: $OS_ERROR';
            $output_66 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_67> };
            close $out_67 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_67, 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_66 = 0; }
            my @lines = split /\n/msx, $output_66;
            my @result;
            foreach my $line (@lines) {
                chomp $line;
                if ($line =~ /^\s*$/msx) { next; }
                my @fields = split /:/msx, $line;
                push @result, ($fields[2] . "\n");
            }
            $output_66 = join "", @result;

            my @sed_lines_66 = split /\n/msx, $output_66;
            my @sed_result_66;
            foreach my $line (@sed_lines_66) {
            chomp $line;
            $line =~ s/[0-9]*/$/gmsx;
            push @sed_result_66, $line;
            }
            $output_66 = join "\n", @sed_result_66;

            if ( !$pipeline_success_66 ) { $main_exit_code = 1; }
            $output_66 =~ s/\n+\z//msx;
            $output_66;
}; $_pipeline_result; };
}
    else {
        $IBM_REV = "$UNAME_VERSION.";
        $CHILD_ERROR = 0;
    }
        $GUESS = $IBM_ARCH;
        $main_exit_code = system('-ibm-aix', $IBM_REV) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:AIX:.*:.*$/msx) {
        $GUESS = 'rs6000-ibm-aix';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^ibmrt:4.4BSD:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^romp-ibm:4.4BSD:.*$/msx) {
        $GUESS = 'romp-ibm-bsd4.4';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^ibmrt:.*BSD:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^romp-ibm:BSD:.*$/msx) {
        $GUESS = 'romp-ibm-bsd';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:BOSX:.*:.*$/msx) {
        $GUESS = 'rs6000-bull-bosx';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^DPX/2.00:B.O.S.:.*:.*$/msx) {
        $GUESS = 'm68k-bull-sysv3';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^9000/\[34\]..:4.3bsd:1..*:.*$/msx) {
        $GUESS = 'm68k-hp-bsd';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^hp300:4.4BSD:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^9000/\[34\]..:4.3bsd:2..*:.*$/msx) {
        $GUESS = 'm68k-hp-bsd4.4';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^9000/\[34678\]..:HP-UX:.*:.*$/msx) {
        my $HPUX_REV;
    my @HPUX_REV;
    my %HPUX_REV;
    $HPUX_REV = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_68 = q{};
        my $output_printed_68;
        my $pipeline_success_68 = 1;
        $output_68 .= $UNAME_RELEASE . "\n";
        if ( !($output_68 =~ m{\n\z}msx) ) { $output_68 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_68 = 0; }
        my @sed_lines_68 = split /\n/msx, $output_68;
        my @sed_result_68;
        foreach my $line (@sed_lines_68) {
        chomp $line;
        push @sed_result_68, $line;
        }
        $output_68 = join "\n", @sed_result_68;

        if ( !$pipeline_success_68 ) { $main_exit_code = 1; }
        $output_68 =~ s/\n+\z//msx;
        $output_68;
}; $_pipeline_result; };
    if ($UNAME_MACHINE =~ /^9000/31.$/msx) {
                my $HP_ARCH;
        my @HP_ARCH;
        my %HP_ARCH;
        $HP_ARCH = 'm68000';
    } elsif ($UNAME_MACHINE =~ /^9000/\[34\]..$/msx) {
                $HP_ARCH = 'm68k';
    } elsif ($UNAME_MACHINE =~ /^9000/\[678\]\[0-9\]\[0-9\]$/msx) {
        if ((-x '/usr/bin/getconf')) {
            my $sc_cpu_version;
            my @sc_cpu_version;
            my %sc_cpu_version;
            $sc_cpu_version = do { my @_qx_cmd = ("/usr/bin/getconf SC_CPU_VERSION 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
            my $sc_kernel_bits;
            my @sc_kernel_bits;
            my %sc_kernel_bits;
            $sc_kernel_bits = do { my @_qx_cmd = ("/usr/bin/getconf SC_KERNEL_BITS 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if ($sc_cpu_version =~ /^523$/msx) {
                                $HP_ARCH = 'hppa1.0';
            } elsif ($sc_cpu_version =~ /^528$/msx) {
                                $HP_ARCH = 'hppa1.1';
            } elsif ($sc_cpu_version =~ /^532$/msx) {
                if ($sc_kernel_bits =~ /^32$/msx) {
                                        $HP_ARCH = 'hppa2.0n';
                } elsif ($sc_kernel_bits =~ /^64$/msx) {
                                        $HP_ARCH = 'hppa2.0w';
                } elsif ($sc_kernel_bits =~ /^$/msx) {
                                        $HP_ARCH = 'hppa2.0';
                }
            }
        }
        if (StringInterpolation(StringInterpolation { parts: [Variable("HP_ARCH")] }, None) eq StringInterpolation(StringInterpolation { parts: [Literal("")] }, None)) {
            set_cc_for_build();
my $temp_content = '
		#define _HPUX_SOURCE
		#include <stdlib.h>
		#include <unistd.h>

		int main ()
		{
		#if defined(_SC_KERNEL_BITS)
		    long bits = sysconf(_SC_KERNEL_BITS);
		#endif
		    long cpu  = sysconf (_SC_CPU_VERSION);

		    switch (cpu)
			{
			case CPU_PA_RISC1_0: puts ("hppa1.0"); break;
			case CPU_PA_RISC1_1: puts ("hppa1.1"); break;
			case CPU_PA_RISC2_0:
		#if defined(_SC_KERNEL_BITS)
			    switch (bits)
				{
				case 64: puts ("hppa2.0w"); break;
				case 32: puts ("hppa2.0n"); break;
				default: puts ("hppa2.0"); break;
				} break;
		#else  /* !defined(_SC_KERNEL_BITS) */
			    puts ("hppa2.0"); break;
		#endif
			default: puts ("hppa1.0"); break;
			}
		    exit (0);
		}
';
use File::Path qw(make_path);
if (!-d q{/tmp}) { make_path(q{/tmp}); }
open my $fh_3, '>', q{/tmp} . '/heredoc_temp' or croak "Cannot create temp file: $OS_ERROR\n";
print $fh_3 $temp_content;
close $fh_3 or croak "Close failed: $OS_ERROR\n";
open STDIN, '<', q{/tmp} . '/heredoc_temp' or croak "Cannot open temp file: $OS_ERROR\n";
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', "$ENV{dummy}.c"
      or die "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
my @sed_lines_69 = split /\n/msx, $;
my @sed_result_69;
foreach my $line (@sed_lines_69) {
chomp $line;
$line =~ s/^		//gmsx;
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
            if (do {
do {
    local %ENV = %ENV;
    my $me = $me;
    my $tmp = $tmp;
    my $UNAME_MACHINE = $UNAME_MACHINE;
    my $help = $help;
    my $GUESS = $GUESS;
    my $dummyarg = $dummyarg;
    my $UNAME_SYSTEM = $UNAME_SYSTEM;
    my $HP_ARCH = $HP_ARCH;
    my $IBM_ARCH = $IBM_ARCH;
    my $timestamp = $timestamp;
    my $sc_kernel_bits = $sc_kernel_bits;
    my $IRIX_REL = $IRIX_REL;
    my $sc_cpu_version = $sc_cpu_version;
    my $machine = $machine;
    my $abi = $abi;
    my $PATH = $PATH;
    my $arch = $arch;
    my $endian = $endian;
    my $UNAME_PROCESSOR = $UNAME_PROCESSOR;
    my $ALPHA_CPU_TYPE = $ALPHA_CPU_TYPE;
    my $# = $#;
    my $IBM_CPU_ID = $IBM_CPU_ID;
    my $UNAME_MACHINE_ARCH = $UNAME_MACHINE_ARCH;
    my $usage = $usage;
    my $expr = $expr;
    my $SUN_ARCH = $SUN_ARCH;
    my $HPUX_REV = $HPUX_REV;
    my $OSF_REL = $OSF_REL;
    my $cc_set_libc = $cc_set_libc;
    my $UNAME_VERSION = $UNAME_VERSION;
    my $UNAME_RELEASE = $UNAME_RELEASE;
    my $os = $os;
    my $SUN_REL = $SUN_REL;
    my $IBM_REV = $IBM_REV;
    my $version = $version;
    my $release = $release;
    my $SYSTEM_NAME = $SYSTEM_NAME;
        my $CCOPTS;
        my @CCOPTS;
        my %CCOPTS;
        $CCOPTS = "";
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
            $CHILD_ERROR = 0;
        };
    q{};
};
                $CHILD_ERROR == 0
            }) {
                                $HP_ARCH = do {
    my ($in_70, $out_70);
    my $pid_70 = open3($in_70, $out_70, '>&STDERR', "$ENV{dummy}");
    close $in_70 or croak 'Close failed: $OS_ERROR';
    my $result_70 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_70> };
    close $out_70 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_70, 0;
    $result_70
};
            }
            if (do {
$main_exit_code = system('test', '-z', "$HP_ARCH") >> 8;
                $CHILD_ERROR == 0
            }) {
                                $HP_ARCH = 'hppa';
            }
        }
    }
    if (StringInterpolation(StringInterpolation { parts: [Variable("HP_ARCH")] }, None) eq hppa2.0w) {
        set_cc_for_build();
if (!(        # Original bash: echo __LP64__ | (CCOPTS="" $CC_FOR_BUILD -E - 2>/dev/null) |
{
            my $output_71 = q{};
            my $output_printed_71;
            my $pipeline_success_71 = 1;
            $output_71 .= '__LP64__' . "\n";
if ( !($output_71 =~ m{\n\z}msx) ) { $output_71 .= "\n"; }
$CHILD_ERROR = 0;

                        $output_71 = q{};
            my @_pcmd_73 = ('sh', '-c', ': "Complex command cannot be converted to shell command"');
            my ($in_72, $out_72);
            my $pid_72 = open3($in_72, $out_72, '>&STDERR', @_pcmd_73);
            close $in_72 or croak 'Close failed: $OS_ERROR';
            $output_71 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_72> };
            close $out_72 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_72, 0;
            my @_pcmd_75 = ('sh', '-c', '$CC_FOR_BUILD -E - 2> /dev/null');
            my ($in_74, $out_74);
            my $pid_74 = open3($in_74, $out_74, '>&STDERR', @_pcmd_75);
            close $in_74 or croak 'Close failed: $OS_ERROR';
            $output_71 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_74> };
            close $out_74 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_74, 0;

                        my $grep_result_71_2;
            my @grep_lines_71_2 = split /\n/msx, $output_71;
            my @grep_filtered_71_2 = grep { /__LP64__/msx } @grep_lines_71_2;
            $grep_result_71_2 = join "\n", @grep_filtered_71_2;
            if (!($grep_result_71_2 =~ m{\n\z}msx || $grep_result_71_2 eq q{})) {
            $grep_result_71_2 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_71_2 > 0 ? 0 : 1;
            $grep_result_71_2 = q{};
            $output_71 = q{};
            if ((scalar @grep_filtered_71_2) == 0) {
                $pipeline_success_71 = 0;
            }
            if ($output_71 ne q{} && !defined $output_printed_71) {
                print $output_71;
                if (!($output_71 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_71 ) { $main_exit_code = 1; }
            })) {
            $HP_ARCH = 'hppa2.0w';
}
        else {
            $HP_ARCH = 'hppa64';
        }
    }
        $GUESS = $HP_ARCH;
        $main_exit_code = system('-hp-hpux', $HPUX_REV) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^ia64:HP-UX:.*:.*$/msx) {
        $HPUX_REV = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_76 = q{};
        my $output_printed_76;
        my $pipeline_success_76 = 1;
        $output_76 .= $UNAME_RELEASE . "\n";
        if ( !($output_76 =~ m{\n\z}msx) ) { $output_76 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_76 = 0; }
        my @sed_lines_76 = split /\n/msx, $output_76;
        my @sed_result_76;
        foreach my $line (@sed_lines_76) {
        chomp $line;
        push @sed_result_76, $line;
        }
        $output_76 = join "\n", @sed_result_76;

        if ( !$pipeline_success_76 ) { $main_exit_code = 1; }
        $output_76 =~ s/\n+\z//msx;
        $output_76;
}; $_pipeline_result; };
        $GUESS = 'ia64-hp-hpux';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^3050.*:HI-UX:.*:.*$/msx) {
        set_cc_for_build();
    my $temp_content = '	#include <unistd.h>
	int
	main ()
	{
	  long cpu = sysconf (_SC_CPU_VERSION);
	  /* The order matters, because CPU_IS_HP_MC68K erroneously returns
	     true for CPU_PA_RISC1_0.  CPU_IS_PA_RISC returns correct
	     results, however.  */
	  if (CPU_IS_PA_RISC (cpu))
	    {
	      switch (cpu)
		{
		  case CPU_PA_RISC1_0: puts ("hppa1.0-hitachi-hiuxwe2"); break;
		  case CPU_PA_RISC1_1: puts ("hppa1.1-hitachi-hiuxwe2"); break;
		  case CPU_PA_RISC2_0: puts ("hppa2.0-hitachi-hiuxwe2"); break;
		  default: puts ("hppa-hitachi-hiuxwe2"); break;
		}
	    }
	  else if (CPU_IS_HP_MC68K (cpu))
	    puts ("m68k-hitachi-hiuxwe2");
	  else puts ("unknown-hitachi-hiuxwe2");
	  exit (0);
	}
';
use File::Path qw(make_path);
if (!-d q{/tmp}) { make_path(q{/tmp}); }
open my $fh_4, '>', q{/tmp} . '/heredoc_temp' or croak "Cannot create temp file: $OS_ERROR\n";
print $fh_4 $temp_content;
close $fh_4 or croak "Close failed: $OS_ERROR\n";
open STDIN, '<', q{/tmp} . '/heredoc_temp' or croak "Cannot open temp file: $OS_ERROR\n";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$ENV{dummy}.c"
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
my @sed_lines_77 = split /\n/msx, $;
my @sed_result_77;
foreach my $line (@sed_lines_77) {
chomp $line;
$line =~ s/^	//gmsx;
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
        if (do {
if (do {
$CHILD_ERROR = 0;
    $CHILD_ERROR == 0
}) {
        $SYSTEM_NAME = do {
    my ($in_78, $out_78);
    my $pid_78 = open3($in_78, $out_78, '>&STDERR', "$ENV{dummy}");
    close $in_78 or croak 'Close failed: $OS_ERROR';
    my $result_78 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_78> };
    close $out_78 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_78, 0;
    $result_78
};
}
        $CHILD_ERROR == 0
    }) {
                    print $SYSTEM_NAME;
if ( !( ($SYSTEM_NAME) =~ m{\n\z}msx ) ) { print "\n"; }
exit $main_exit_code;
    }
        $GUESS = 'unknown-hitachi-hiuxwe2';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^9000/7..:4.3bsd:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^9000/8.\[79\]:4.3bsd:.*:.*$/msx) {
        $GUESS = 'hppa1.1';
        $main_exit_code = system('-h', 'p-bsd') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^9000/8..:4.3bsd:.*:.*$/msx) {
        $GUESS = 'hppa1.0';
        $main_exit_code = system('-h', 'p-bsd') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*9...*:MPE/iX:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*3000.*:MPE/iX:.*:.*$/msx) {
        $GUESS = 'hppa1.0';
        $main_exit_code = system('-h', 'p-mpeix') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^hp7..:OSF1:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^hp8.\[79\]:OSF1:.*:.*$/msx) {
        $GUESS = 'hppa1.1';
        $main_exit_code = system('-h', 'p-osf') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^hp8..:OSF1:.*:.*$/msx) {
        $GUESS = 'hppa1.0';
        $main_exit_code = system('-h', 'p-osf') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*86:OSF1:.*:.*$/msx) {
    if ((-x '/usr/sbin/sysversion')) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-unknown-osf1mk') >> 8;
}
    else {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-unknown-osf1') >> 8;
    }
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^parisc.*:Lites.*:.*:.*$/msx) {
        $GUESS = 'hppa1.1';
        $main_exit_code = system('-h', 'p-lites') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^C1.*:ConvexOS:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^convex:ConvexOS:C1.*:.*$/msx) {
        $GUESS = 'c1-convex-bsd';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^C2.*:ConvexOS:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^convex:ConvexOS:C2.*:.*$/msx) {
    if (!(    $main_exit_code = system('getsysinfo', '-f', 'scalar_acc') >> 8)) {
        print 'c32-convex-bsd' . "\n";
        $CHILD_ERROR = 0;
}
    else {
        print 'c2-convex-bsd' . "\n";
        $CHILD_ERROR = 0;
    }
    exit $main_exit_code;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^C34.*:ConvexOS:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^convex:ConvexOS:C34.*:.*$/msx) {
        $GUESS = 'c34-convex-bsd';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^C38.*:ConvexOS:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^convex:ConvexOS:C38.*:.*$/msx) {
        $GUESS = 'c38-convex-bsd';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^C4.*:ConvexOS:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^convex:ConvexOS:C4.*:.*$/msx) {
        $GUESS = 'c4-convex-bsd';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^CRAY.*Y-MP:.*:.*:.*$/msx) {
        my $CRAY_REL;
    my @CRAY_REL;
    my %CRAY_REL;
    $CRAY_REL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_79 = q{};
        my $output_printed_79;
        my $pipeline_success_79 = 1;
        $output_79 .= $UNAME_RELEASE . "\n";
        if ( !($output_79 =~ m{\n\z}msx) ) { $output_79 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_79 = 0; }
        my @sed_lines_79 = split /\n/msx, $output_79;
        my @sed_result_79;
        foreach my $line (@sed_lines_79) {
        chomp $line;
        push @sed_result_79, $line;
        }
        $output_79 = join "\n", @sed_result_79;

        if ( !$pipeline_success_79 ) { $main_exit_code = 1; }
        $output_79 =~ s/\n+\z//msx;
        $output_79;
}; $_pipeline_result; };
        $GUESS = 'ymp-cray-unicos';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^CRAY.*\[A-Z\]90:.*:.*:.*$/msx) {
        # Original bash: echo "$UNAME_MACHINE"-cray-unicos"$UNAME_RELEASE" \
{
        my $output_80 = q{};
        my $output_printed_80;
        my $pipeline_success_80 = 1;
        $output_80 .= $UNAME_MACHINE . q{ } . '-c' . q{ } . 'ray-unicos' . q{ } . $UNAME_RELEASE . "\n";
if ( !($output_80 =~ m{\n\z}msx) ) { $output_80 .= "\n"; }
$CHILD_ERROR = 0;

                my @sed_lines_80 = split /\n/msx, $output_80;
        my @sed_result_80;
        foreach my $line (@sed_lines_80) {
        chomp $line;
        push @sed_result_80, $line;
        }
        $output_80 = join "\n", @sed_result_80;
        if ($output_80 ne q{} && !defined $output_printed_80) {
            print $output_80;
            if (!($output_80 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_80 ) { $main_exit_code = 1; }
        }
    exit $main_exit_code;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^CRAY.*TS:.*:.*:.*$/msx) {
        $CRAY_REL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_81 = q{};
        my $output_printed_81;
        my $pipeline_success_81 = 1;
        $output_81 .= $UNAME_RELEASE . "\n";
        if ( !($output_81 =~ m{\n\z}msx) ) { $output_81 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_81 = 0; }
        my @sed_lines_81 = split /\n/msx, $output_81;
        my @sed_result_81;
        foreach my $line (@sed_lines_81) {
        chomp $line;
        push @sed_result_81, $line;
        }
        $output_81 = join "\n", @sed_result_81;

        if ( !$pipeline_success_81 ) { $main_exit_code = 1; }
        $output_81 =~ s/\n+\z//msx;
        $output_81;
}; $_pipeline_result; };
        $GUESS = 't90-cray-unicos';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^CRAY.*T3E:.*:.*:.*$/msx) {
        $CRAY_REL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_82 = q{};
        my $output_printed_82;
        my $pipeline_success_82 = 1;
        $output_82 .= $UNAME_RELEASE . "\n";
        if ( !($output_82 =~ m{\n\z}msx) ) { $output_82 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_82 = 0; }
        my @sed_lines_82 = split /\n/msx, $output_82;
        my @sed_result_82;
        foreach my $line (@sed_lines_82) {
        chomp $line;
        push @sed_result_82, $line;
        }
        $output_82 = join "\n", @sed_result_82;

        if ( !$pipeline_success_82 ) { $main_exit_code = 1; }
        $output_82 =~ s/\n+\z//msx;
        $output_82;
}; $_pipeline_result; };
        $GUESS = 'alphaev5-cray-unicosmk';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^CRAY.*SV1:.*:.*:.*$/msx) {
        $CRAY_REL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_83 = q{};
        my $output_printed_83;
        my $pipeline_success_83 = 1;
        $output_83 .= $UNAME_RELEASE . "\n";
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
        $GUESS = 'sv1-cray-unicos';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:UNICOS/mp:.*:.*$/msx) {
        $CRAY_REL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_84 = q{};
        my $output_printed_84;
        my $pipeline_success_84 = 1;
        $output_84 .= $UNAME_RELEASE . "\n";
        if ( !($output_84 =~ m{\n\z}msx) ) { $output_84 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_84 = 0; }
        my @sed_lines_84 = split /\n/msx, $output_84;
        my @sed_result_84;
        foreach my $line (@sed_lines_84) {
        chomp $line;
        push @sed_result_84, $line;
        }
        $output_84 = join "\n", @sed_result_84;

        if ( !$pipeline_success_84 ) { $main_exit_code = 1; }
        $output_84 =~ s/\n+\z//msx;
        $output_84;
}; $_pipeline_result; };
        $GUESS = 'craynv-cray-unicosmp';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^F30\[01\]:UNIX_System_V:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^F700:UNIX_System_V:.*:.*$/msx) {
        my $FUJITSU_PROC;
    my @FUJITSU_PROC;
    my %FUJITSU_PROC;
    $FUJITSU_PROC = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_85 = q{};
        my $output_printed_85;
        my $pipeline_success_85 = 1;
        do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__mach; $output_85 = join(" ", @__parts) . "\n"; $CHILD_ERROR = 0; };
        if ($CHILD_ERROR != 0) { $pipeline_success_85 = 0; }
        my $set1_86 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        my $set2_86 = 'abcdefghijklmnopqrstuvwxyz';
        my $input_86 = $output_85;
        # Expand character ranges for tr command
        my $expanded_set1_86 = $set1_86;
        my $expanded_set2_86 = $set2_86;
        # Handle a-z range in set1
        if ($expanded_set1_86 =~ /a-z/msx) {
            $expanded_set1_86 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set1
        if ($expanded_set1_86 =~ /A-Z/msx) {
            $expanded_set1_86 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set1
        if ($expanded_set1_86 =~ /\[:upper:\]/msx) {
            $expanded_set1_86 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set1
        if ($expanded_set1_86 =~ /\[:lower:\]/msx) {
            $expanded_set1_86 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle a-z range in set2
        if ($expanded_set2_86 =~ /a-z/msx) {
            $expanded_set2_86 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set2
        if ($expanded_set2_86 =~ /A-Z/msx) {
            $expanded_set2_86 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set2
        if ($expanded_set2_86 =~ /\[:upper:\]/msx) {
            $expanded_set2_86 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set2
        if ($expanded_set2_86 =~ /\[:lower:\]/msx) {
            $expanded_set2_86 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        my $tr_result_85_1 = q{};
        for my $char ( split //msx, $input_86 ) {
            my $pos_86 = index $expanded_set1_86, $char;
            if ( $pos_86 >= 0 && $pos_86 < length $expanded_set2_86 ) {
                $tr_result_85_1 .= substr $expanded_set2_86, $pos_86, 1;
            } else {
                $tr_result_85_1 .= $char;
            }
        }
                if (!($tr_result_85_1 =~ m{\n\z}msx || $tr_result_85_1 eq q{})) {
                    $tr_result_85_1 .= "\n";
                }
                $output_85 = $tr_result_85_1;
        if ( !$pipeline_success_85 ) { $main_exit_code = 1; }
        $output_85 =~ s/\n+\z//msx;
        $output_85;
}; $_pipeline_result; };
        my $FUJITSU_SYS;
    my @FUJITSU_SYS;
    my %FUJITSU_SYS;
    $FUJITSU_SYS = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_87 = q{};
        my $output_printed_87;
        my $pipeline_success_87 = 1;
        do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; $output_87 = join(" ", @__parts) . "\n"; $CHILD_ERROR = 0; };
        if ($CHILD_ERROR != 0) { $pipeline_success_87 = 0; }
        my $set1_88 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        my $set2_88 = 'abcdefghijklmnopqrstuvwxyz';
        my $input_88 = $output_87;
        # Expand character ranges for tr command
        my $expanded_set1_88 = $set1_88;
        my $expanded_set2_88 = $set2_88;
        # Handle a-z range in set1
        if ($expanded_set1_88 =~ /a-z/msx) {
            $expanded_set1_88 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set1
        if ($expanded_set1_88 =~ /A-Z/msx) {
            $expanded_set1_88 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set1
        if ($expanded_set1_88 =~ /\[:upper:\]/msx) {
            $expanded_set1_88 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set1
        if ($expanded_set1_88 =~ /\[:lower:\]/msx) {
            $expanded_set1_88 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle a-z range in set2
        if ($expanded_set2_88 =~ /a-z/msx) {
            $expanded_set2_88 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set2
        if ($expanded_set2_88 =~ /A-Z/msx) {
            $expanded_set2_88 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set2
        if ($expanded_set2_88 =~ /\[:upper:\]/msx) {
            $expanded_set2_88 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set2
        if ($expanded_set2_88 =~ /\[:lower:\]/msx) {
            $expanded_set2_88 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        my $tr_result_87_1 = q{};
        for my $char ( split //msx, $input_88 ) {
            my $pos_88 = index $expanded_set1_88, $char;
            if ( $pos_88 >= 0 && $pos_88 < length $expanded_set2_88 ) {
                $tr_result_87_1 .= substr $expanded_set2_88, $pos_88, 1;
            } else {
                $tr_result_87_1 .= $char;
            }
        }
                if (!($tr_result_87_1 =~ m{\n\z}msx || $tr_result_87_1 eq q{})) {
                    $tr_result_87_1 .= "\n";
                }
                $output_87 = $tr_result_87_1;
        my @sed_lines_87 = split /\n/msx, $output_87;
        my @sed_result_87;
        foreach my $line (@sed_lines_87) {
        chomp $line;
        push @sed_result_87, $line;
        }
        $output_87 = join "\n", @sed_result_87;

        if ( !$pipeline_success_87 ) { $main_exit_code = 1; }
        $output_87 =~ s/\n+\z//msx;
        $output_87;
}; $_pipeline_result; };
        my $FUJITSU_REL;
    my @FUJITSU_REL;
    my %FUJITSU_REL;
    $FUJITSU_REL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_89 = q{};
        my $output_printed_89;
        my $pipeline_success_89 = 1;
        $output_89 .= $UNAME_RELEASE . "\n";
        if ( !($output_89 =~ m{\n\z}msx) ) { $output_89 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_89 = 0; }
        my @sed_lines_89 = split /\n/msx, $output_89;
        my @sed_result_89;
        foreach my $line (@sed_lines_89) {
        chomp $line;
        push @sed_result_89, $line;
        }
        $output_89 = join "\n", @sed_result_89;

        if ( !$pipeline_success_89 ) { $main_exit_code = 1; }
        $output_89 =~ s/\n+\z//msx;
        $output_89;
}; $_pipeline_result; };
        $GUESS = $FUJITSU_PROC;
        $main_exit_code = system('-f', 'ujitsu-', $FUJITSU_SYS, $FUJITSU_REL) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^5000:UNIX_System_V:4..*:.*$/msx) {
        $FUJITSU_SYS = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_90 = q{};
        my $output_printed_90;
        my $pipeline_success_90 = 1;
        do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; $output_90 = join(" ", @__parts) . "\n"; $CHILD_ERROR = 0; };
        if ($CHILD_ERROR != 0) { $pipeline_success_90 = 0; }
        my $set1_91 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        my $set2_91 = 'abcdefghijklmnopqrstuvwxyz';
        my $input_91 = $output_90;
        # Expand character ranges for tr command
        my $expanded_set1_91 = $set1_91;
        my $expanded_set2_91 = $set2_91;
        # Handle a-z range in set1
        if ($expanded_set1_91 =~ /a-z/msx) {
            $expanded_set1_91 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set1
        if ($expanded_set1_91 =~ /A-Z/msx) {
            $expanded_set1_91 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set1
        if ($expanded_set1_91 =~ /\[:upper:\]/msx) {
            $expanded_set1_91 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set1
        if ($expanded_set1_91 =~ /\[:lower:\]/msx) {
            $expanded_set1_91 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle a-z range in set2
        if ($expanded_set2_91 =~ /a-z/msx) {
            $expanded_set2_91 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set2
        if ($expanded_set2_91 =~ /A-Z/msx) {
            $expanded_set2_91 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set2
        if ($expanded_set2_91 =~ /\[:upper:\]/msx) {
            $expanded_set2_91 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set2
        if ($expanded_set2_91 =~ /\[:lower:\]/msx) {
            $expanded_set2_91 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        my $tr_result_90_1 = q{};
        for my $char ( split //msx, $input_91 ) {
            my $pos_91 = index $expanded_set1_91, $char;
            if ( $pos_91 >= 0 && $pos_91 < length $expanded_set2_91 ) {
                $tr_result_90_1 .= substr $expanded_set2_91, $pos_91, 1;
            } else {
                $tr_result_90_1 .= $char;
            }
        }
                if (!($tr_result_90_1 =~ m{\n\z}msx || $tr_result_90_1 eq q{})) {
                    $tr_result_90_1 .= "\n";
                }
                $output_90 = $tr_result_90_1;
        my @sed_lines_90 = split /\n/msx, $output_90;
        my @sed_result_90;
        foreach my $line (@sed_lines_90) {
        chomp $line;
        push @sed_result_90, $line;
        }
        $output_90 = join "\n", @sed_result_90;

        if ( !$pipeline_success_90 ) { $main_exit_code = 1; }
        $output_90 =~ s/\n+\z//msx;
        $output_90;
}; $_pipeline_result; };
        $FUJITSU_REL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_92 = q{};
        my $output_printed_92;
        my $pipeline_success_92 = 1;
        $output_92 .= $UNAME_RELEASE . "\n";
        if ( !($output_92 =~ m{\n\z}msx) ) { $output_92 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_92 = 0; }
        my $set1_93 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        my $set2_93 = 'abcdefghijklmnopqrstuvwxyz';
        my $input_93 = $output_92;
        # Expand character ranges for tr command
        my $expanded_set1_93 = $set1_93;
        my $expanded_set2_93 = $set2_93;
        # Handle a-z range in set1
        if ($expanded_set1_93 =~ /a-z/msx) {
            $expanded_set1_93 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set1
        if ($expanded_set1_93 =~ /A-Z/msx) {
            $expanded_set1_93 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set1
        if ($expanded_set1_93 =~ /\[:upper:\]/msx) {
            $expanded_set1_93 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set1
        if ($expanded_set1_93 =~ /\[:lower:\]/msx) {
            $expanded_set1_93 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle a-z range in set2
        if ($expanded_set2_93 =~ /a-z/msx) {
            $expanded_set2_93 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set2
        if ($expanded_set2_93 =~ /A-Z/msx) {
            $expanded_set2_93 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set2
        if ($expanded_set2_93 =~ /\[:upper:\]/msx) {
            $expanded_set2_93 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set2
        if ($expanded_set2_93 =~ /\[:lower:\]/msx) {
            $expanded_set2_93 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        my $tr_result_92_1 = q{};
        for my $char ( split //msx, $input_93 ) {
            my $pos_93 = index $expanded_set1_93, $char;
            if ( $pos_93 >= 0 && $pos_93 < length $expanded_set2_93 ) {
                $tr_result_92_1 .= substr $expanded_set2_93, $pos_93, 1;
            } else {
                $tr_result_92_1 .= $char;
            }
        }
                if (!($tr_result_92_1 =~ m{\n\z}msx || $tr_result_92_1 eq q{})) {
                    $tr_result_92_1 .= "\n";
                }
                $output_92 = $tr_result_92_1;
        my @sed_lines_92 = split /\n/msx, $output_92;
        my @sed_result_92;
        foreach my $line (@sed_lines_92) {
        chomp $line;
        push @sed_result_92, $line;
        }
        $output_92 = join "\n", @sed_result_92;

        if ( !$pipeline_success_92 ) { $main_exit_code = 1; }
        $output_92 =~ s/\n+\z//msx;
        $output_92;
}; $_pipeline_result; };
        $GUESS = 'sparc-fujitsu-';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*86:BSD/386:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*86:BSD/OS:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:Ascend\ Embedded/OS:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-pc-bsdi', $UNAME_RELEASE) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^sparc.*:BSD/OS:.*:.*$/msx) {
        $GUESS = 'sparc-unknown-bsdi';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:BSD/OS:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-bsdi', $UNAME_RELEASE) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^arm:FreeBSD:.*:.*$/msx) {
        $UNAME_PROCESSOR = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; join(" ", @__parts) . "\n"; };
        set_cc_for_build();
    if (!(    # Original bash: echo __ARM_PCS_VFP | $CC_FOR_BUILD -E - 2>/dev/null \
{
        my $output_94 = q{};
        my $output_printed_94;
        my $pipeline_success_94 = 1;
        $output_94 .= '__ARM_PCS_VFP' . "\n";
if ( !($output_94 =~ m{\n\z}msx) ) { $output_94 .= "\n"; }
$CHILD_ERROR = 0;

                my $cmd_96 = 'unknown_command';
        my ($in_95, $out_95);
        my $pid_95 = open3($in_95, $out_95, '>&STDERR', $cmd_96, '-E', q{-});
        print {$in_95} $output_94;
        close $in_95 or croak 'Close failed: $OS_ERROR';
        $output_94 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_95> };
        close $out_95 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_95, 0;

                my $grep_result_94_2;
        my @grep_lines_94_2 = split /\n/msx, $output_94;
        my @grep_filtered_94_2 = grep { /__ARM_PCS_VFP/msx } @grep_lines_94_2;
        $grep_result_94_2 = join "\n", @grep_filtered_94_2;
        if (!($grep_result_94_2 =~ m{\n\z}msx || $grep_result_94_2 eq q{})) {
        $grep_result_94_2 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_94_2 > 0 ? 0 : 1;
        $grep_result_94_2 = q{};
        $output_94 = q{};
        if ((scalar @grep_filtered_94_2) == 0) {
            $pipeline_success_94 = 0;
        }
        if ($output_94 ne q{} && !defined $output_printed_94) {
            print $output_94;
            if (!($output_94 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_94 ) { $main_exit_code = 1; }
        })) {
        my $FREEBSD_REL;
        my @FREEBSD_REL;
        my %FREEBSD_REL;
        $FREEBSD_REL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_97 = q{};
            my $output_printed_97;
            my $pipeline_success_97 = 1;
            $output_97 .= $UNAME_RELEASE . "\n";
            if ( !($output_97 =~ m{\n\z}msx) ) { $output_97 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_97 = 0; }
            my @sed_lines_97 = split /\n/msx, $output_97;
            my @sed_result_97;
            foreach my $line (@sed_lines_97) {
            chomp $line;
            push @sed_result_97, $line;
            }
            $output_97 = join "\n", @sed_result_97;

            if ( !$pipeline_success_97 ) { $main_exit_code = 1; }
            $output_97 =~ s/\n+\z//msx;
            $output_97;
}; $_pipeline_result; };
        $GUESS = $UNAME_PROCESSOR;
        $main_exit_code = system('-unknown-freebsd', $FREEBSD_REL, '-gnueabi') >> 8;
}
    else {
        $FREEBSD_REL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_98 = q{};
            my $output_printed_98;
            my $pipeline_success_98 = 1;
            $output_98 .= $UNAME_RELEASE . "\n";
            if ( !($output_98 =~ m{\n\z}msx) ) { $output_98 .= "\n"; }
            $CHILD_ERROR = 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_98 = 0; }
            my @sed_lines_98 = split /\n/msx, $output_98;
            my @sed_result_98;
            foreach my $line (@sed_lines_98) {
            chomp $line;
            push @sed_result_98, $line;
            }
            $output_98 = join "\n", @sed_result_98;

            if ( !$pipeline_success_98 ) { $main_exit_code = 1; }
            $output_98 =~ s/\n+\z//msx;
            $output_98;
}; $_pipeline_result; };
        $GUESS = $UNAME_PROCESSOR;
        $main_exit_code = system('-unknown-freebsd', $FREEBSD_REL, '-gnueabihf') >> 8;
    }
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:FreeBSD:.*:.*$/msx) {
        $UNAME_PROCESSOR = do {
    my ($in_99, $out_99);
    my $pid_99 = open3($in_99, $out_99, '>&STDERR', '/usr/bin/uname', '-p');
    close $in_99 or croak 'Close failed: $OS_ERROR';
    my $result_99 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_99> };
    close $out_99 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_99, 0;
    $result_99
};
    if ($UNAME_PROCESSOR =~ /^amd64$/msx) {
                $UNAME_PROCESSOR = 'x86_64';
    } elsif ($UNAME_PROCESSOR =~ /^i386$/msx) {
                $UNAME_PROCESSOR = 'i586';
    }
        $FREEBSD_REL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_100 = q{};
        my $output_printed_100;
        my $pipeline_success_100 = 1;
        $output_100 .= $UNAME_RELEASE . "\n";
        if ( !($output_100 =~ m{\n\z}msx) ) { $output_100 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_100 = 0; }
        my @sed_lines_100 = split /\n/msx, $output_100;
        my @sed_result_100;
        foreach my $line (@sed_lines_100) {
        chomp $line;
        push @sed_result_100, $line;
        }
        $output_100 = join "\n", @sed_result_100;

        if ( !$pipeline_success_100 ) { $main_exit_code = 1; }
        $output_100 =~ s/\n+\z//msx;
        $output_100;
}; $_pipeline_result; };
        $GUESS = $UNAME_PROCESSOR;
        $main_exit_code = system('-unknown-freebsd', $FREEBSD_REL) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*:CYGWIN.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-pc-cygwin') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:MINGW64.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-pc-mingw64') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:MINGW.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-pc-mingw32') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:MSYS.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-pc-msys') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*:PW.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-pc-pw32') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:SerenityOS:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-pc-serenity') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:Interix.*:.*$/msx) {
    if ($UNAME_MACHINE =~ /^x86$/msx) {
                $GUESS = 'i586-pc-interix';
                $CHILD_ERROR = 0;
    } elsif ($UNAME_MACHINE =~ /^authenticamd$/msx or $UNAME_MACHINE =~ /^genuineintel$/msx or $UNAME_MACHINE =~ /^EM64T$/msx) {
                $GUESS = 'x86_64-unknown-interix';
                $CHILD_ERROR = 0;
    } elsif ($UNAME_MACHINE =~ /^IA64$/msx) {
                $GUESS = 'ia64-unknown-interix';
                $CHILD_ERROR = 0;
    }
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*:UWIN.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-pc-uwin') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^amd64:CYGWIN.*:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^x86_64:CYGWIN.*:.*:.*$/msx) {
        $GUESS = 'x86_64-pc-cygwin';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^prep.*:SunOS:5..*:.*$/msx) {
        $SUN_REL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_101 = q{};
        my $output_printed_101;
        my $pipeline_success_101 = 1;
        $output_101 .= $UNAME_RELEASE . "\n";
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
}; $_pipeline_result; };
        $GUESS = 'powerpcle-unknown-solaris2';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:GNU:.*:.*$/msx) {
        my $GNU_ARCH;
    my @GNU_ARCH;
    my %GNU_ARCH;
    $GNU_ARCH = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_102 = q{};
        my $output_printed_102;
        my $pipeline_success_102 = 1;
        $output_102 .= $UNAME_MACHINE . "\n";
        if ( !($output_102 =~ m{\n\z}msx) ) { $output_102 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_102 = 0; }
        my @sed_lines_102 = split /\n/msx, $output_102;
        my @sed_result_102;
        foreach my $line (@sed_lines_102) {
        chomp $line;
        push @sed_result_102, $line;
        }
        $output_102 = join "\n", @sed_result_102;

        if ( !$pipeline_success_102 ) { $main_exit_code = 1; }
        $output_102 =~ s/\n+\z//msx;
        $output_102;
}; $_pipeline_result; };
        my $GNU_REL;
    my @GNU_REL;
    my %GNU_REL;
    $GNU_REL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_103 = q{};
        my $output_printed_103;
        my $pipeline_success_103 = 1;
        $output_103 .= $UNAME_RELEASE . "\n";
        if ( !($output_103 =~ m{\n\z}msx) ) { $output_103 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_103 = 0; }
        my @sed_lines_103 = split /\n/msx, $output_103;
        my @sed_result_103;
        foreach my $line (@sed_lines_103) {
        chomp $line;
        push @sed_result_103, $line;
        }
        $output_103 = join "\n", @sed_result_103;

        if ( !$pipeline_success_103 ) { $main_exit_code = 1; }
        $output_103 =~ s/\n+\z//msx;
        $output_103;
}; $_pipeline_result; };
        $GUESS = $GNU_ARCH;
        $main_exit_code = system('-unknown-', $LIBC, $GNU_REL) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:GNU/.*:.*:.*$/msx) {
        my $GNU_SYS;
    my @GNU_SYS;
    my %GNU_SYS;
    $GNU_SYS = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_104 = q{};
        my $output_printed_104;
        my $pipeline_success_104 = 1;
        $output_104 .= $UNAME_SYSTEM . "\n";
        if ( !($output_104 =~ m{\n\z}msx) ) { $output_104 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_104 = 0; }
        my @sed_lines_104 = split /\n/msx, $output_104;
        my @sed_result_104;
        foreach my $line (@sed_lines_104) {
        chomp $line;
        push @sed_result_104, $line;
        }
        $output_104 = join "\n", @sed_result_104;

        my $set1_105 = "[:upper:]";
        my $set2_105 = "[:lower:]";
        my $input_105 = $output_104;
        # Expand character ranges for tr command
        my $expanded_set1_105 = $set1_105;
        my $expanded_set2_105 = $set2_105;
        # Handle a-z range in set1
        if ($expanded_set1_105 =~ /a-z/msx) {
            $expanded_set1_105 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set1
        if ($expanded_set1_105 =~ /A-Z/msx) {
            $expanded_set1_105 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set1
        if ($expanded_set1_105 =~ /\[:upper:\]/msx) {
            $expanded_set1_105 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set1
        if ($expanded_set1_105 =~ /\[:lower:\]/msx) {
            $expanded_set1_105 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle a-z range in set2
        if ($expanded_set2_105 =~ /a-z/msx) {
            $expanded_set2_105 =~ s/a-z/abcdefghijklmnopqrstuvwxyz/msx;
        }
        # Handle A-Z range in set2
        if ($expanded_set2_105 =~ /A-Z/msx) {
            $expanded_set2_105 =~ s/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:upper:] POSIX class in set2
        if ($expanded_set2_105 =~ /\[:upper:\]/msx) {
            $expanded_set2_105 =~ s/\[:upper:\]/ABCDEFGHIJKLMNOPQRSTUVWXYZ/msx;
        }
        # Handle [:lower:] POSIX class in set2
        if ($expanded_set2_105 =~ /\[:lower:\]/msx) {
            $expanded_set2_105 =~ s/\[:lower:\]/abcdefghijklmnopqrstuvwxyz/msx;
        }
        my $tr_result_104_2 = q{};
        for my $char ( split //msx, $input_105 ) {
            my $pos_105 = index $expanded_set1_105, $char;
            if ( $pos_105 >= 0 && $pos_105 < length $expanded_set2_105 ) {
                $tr_result_104_2 .= substr $expanded_set2_105, $pos_105, 1;
            } else {
                $tr_result_104_2 .= $char;
            }
        }
                if (!($tr_result_104_2 =~ m{\n\z}msx || $tr_result_104_2 eq q{})) {
                    $tr_result_104_2 .= "\n";
                }
                $output_104 = $tr_result_104_2;
        if ( !$pipeline_success_104 ) { $main_exit_code = 1; }
        $output_104 =~ s/\n+\z//msx;
        $output_104;
}; $_pipeline_result; };
        $GNU_REL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_106 = q{};
        my $output_printed_106;
        my $pipeline_success_106 = 1;
        $output_106 .= $UNAME_RELEASE . "\n";
        if ( !($output_106 =~ m{\n\z}msx) ) { $output_106 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_106 = 0; }
        my @sed_lines_106 = split /\n/msx, $output_106;
        my @sed_result_106;
        foreach my $line (@sed_lines_106) {
        chomp $line;
        push @sed_result_106, $line;
        }
        $output_106 = join "\n", @sed_result_106;

        if ( !$pipeline_success_106 ) { $main_exit_code = 1; }
        $output_106 =~ s/\n+\z//msx;
        $output_106;
}; $_pipeline_result; };
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-', $GNU_SYS, $GNU_REL, q{-}, $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:Minix:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-unknown-minix') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^aarch64:Linux:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^aarch64_be:Linux:.*:.*$/msx) {
        $UNAME_MACHINE = 'aarch64_be';
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^alpha:Linux:.*:.*$/msx) {
    if (do { my @_qx_cmd = ("sed -n \"/^cpu model/s/^.*: \\\\(.*\\\\)/\\\\1/p\" /proc/cpuinfo 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; } =~ /^EV5$/msx) {
                $UNAME_MACHINE = 'alphaev5';
    } elsif (do { my @_qx_cmd = ("sed -n \"/^cpu model/s/^.*: \\\\(.*\\\\)/\\\\1/p\" /proc/cpuinfo 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; } =~ /^EV56$/msx) {
                $UNAME_MACHINE = 'alphaev56';
    } elsif (do { my @_qx_cmd = ("sed -n \"/^cpu model/s/^.*: \\\\(.*\\\\)/\\\\1/p\" /proc/cpuinfo 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; } =~ /^PCA56$/msx) {
                $UNAME_MACHINE = 'alphapca56';
    } elsif (do { my @_qx_cmd = ("sed -n \"/^cpu model/s/^.*: \\\\(.*\\\\)/\\\\1/p\" /proc/cpuinfo 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; } =~ /^PCA57$/msx) {
                $UNAME_MACHINE = 'alphapca56';
    } elsif (do { my @_qx_cmd = ("sed -n \"/^cpu model/s/^.*: \\\\(.*\\\\)/\\\\1/p\" /proc/cpuinfo 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; } =~ /^EV6$/msx) {
                $UNAME_MACHINE = 'alphaev6';
    } elsif (do { my @_qx_cmd = ("sed -n \"/^cpu model/s/^.*: \\\\(.*\\\\)/\\\\1/p\" /proc/cpuinfo 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; } =~ /^EV67$/msx) {
                $UNAME_MACHINE = 'alphaev67';
    } elsif (do { my @_qx_cmd = ("sed -n \"/^cpu model/s/^.*: \\\\(.*\\\\)/\\\\1/p\" /proc/cpuinfo 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; } =~ /^EV68.*$/msx) {
                $UNAME_MACHINE = 'alphaev68';
    }
        # Original bash: objdump --private-headers /bin/sh | grep -q ld.so.1
{
        my $output_107 = q{};
        my $output_printed_107;
        my $pipeline_success_107 = 1;
                my ($in_108, $out_108);
        my $pid_108 = open3($in_108, $out_108, '>&STDERR', 'objdump', '--private-headers', '/bin/sh');
        close $in_108 or croak 'Close failed: $OS_ERROR';
        $output_107 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_108> };
        close $out_108 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_108, 0;

                my $grep_result_107_1;
        my @grep_lines_107_1 = split /\n/msx, $output_107;
        my @grep_filtered_107_1 = grep { /ld.so.1/msx } @grep_lines_107_1;
        $grep_result_107_1 = join "\n", @grep_filtered_107_1;
        if (!($grep_result_107_1 =~ m{\n\z}msx || $grep_result_107_1 eq q{})) {
        $grep_result_107_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_107_1 > 0 ? 0 : 1;
        $grep_result_107_1 = q{};
        $output_107 = q{};
        if ((scalar @grep_filtered_107_1) == 0) {
            $pipeline_success_107 = 0;
        }
        if ($output_107 ne q{} && !defined $output_printed_107) {
            print $output_107;
            if (!($output_107 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_107 ) { $main_exit_code = 1; }
        }
    if (StringInterpolation(StringInterpolation { parts: [Variable("?")] }, None) eq 0) {
        $LIBC = 'gnulibc1';
    }
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^arc:Linux:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^arceb:Linux:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^arc32:Linux:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^arc64:Linux:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^arm.*:Linux:.*:.*$/msx) {
        set_cc_for_build();
    if (!(    # Original bash: echo __ARM_EABI__ | $CC_FOR_BUILD -E - 2>/dev/null \
{
        my $output_109 = q{};
        my $output_printed_109;
        my $pipeline_success_109 = 1;
        $output_109 .= '__ARM_EABI__' . "\n";
if ( !($output_109 =~ m{\n\z}msx) ) { $output_109 .= "\n"; }
$CHILD_ERROR = 0;

                my $cmd_111 = 'unknown_command';
        my ($in_110, $out_110);
        my $pid_110 = open3($in_110, $out_110, '>&STDERR', $cmd_111, '-E', q{-});
        print {$in_110} $output_109;
        close $in_110 or croak 'Close failed: $OS_ERROR';
        $output_109 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_110> };
        close $out_110 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_110, 0;

                my $grep_result_109_2;
        my @grep_lines_109_2 = split /\n/msx, $output_109;
        my @grep_filtered_109_2 = grep { /__ARM_EABI__/msx } @grep_lines_109_2;
        $grep_result_109_2 = join "\n", @grep_filtered_109_2;
        if (!($grep_result_109_2 =~ m{\n\z}msx || $grep_result_109_2 eq q{})) {
        $grep_result_109_2 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_109_2 > 0 ? 0 : 1;
        $grep_result_109_2 = q{};
        $output_109 = q{};
        if ((scalar @grep_filtered_109_2) == 0) {
            $pipeline_success_109 = 0;
        }
        if ($output_109 ne q{} && !defined $output_printed_109) {
            print $output_109;
            if (!($output_109 =~ m{\n\z}msx)) {
                print "\n";
            }
        }
        if ( !$pipeline_success_109 ) { $main_exit_code = 1; }
        })) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-linux-', $LIBC) >> 8;
}
    else {
if (!(        # Original bash: echo __ARM_PCS_VFP | $CC_FOR_BUILD -E - 2>/dev/null \
{
            my $output_112 = q{};
            my $output_printed_112;
            my $pipeline_success_112 = 1;
            $output_112 .= '__ARM_PCS_VFP' . "\n";
if ( !($output_112 =~ m{\n\z}msx) ) { $output_112 .= "\n"; }
$CHILD_ERROR = 0;

                        my $cmd_114 = 'unknown_command';
            my ($in_113, $out_113);
            my $pid_113 = open3($in_113, $out_113, '>&STDERR', $cmd_114, '-E', q{-});
            print {$in_113} $output_112;
            close $in_113 or croak 'Close failed: $OS_ERROR';
            $output_112 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_113> };
            close $out_113 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_113, 0;

                        my $grep_result_112_2;
            my @grep_lines_112_2 = split /\n/msx, $output_112;
            my @grep_filtered_112_2 = grep { /__ARM_PCS_VFP/msx } @grep_lines_112_2;
            $grep_result_112_2 = join "\n", @grep_filtered_112_2;
            if (!($grep_result_112_2 =~ m{\n\z}msx || $grep_result_112_2 eq q{})) {
            $grep_result_112_2 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_112_2 > 0 ? 0 : 1;
            $grep_result_112_2 = q{};
            $output_112 = q{};
            if ((scalar @grep_filtered_112_2) == 0) {
                $pipeline_success_112 = 0;
            }
            if ($output_112 ne q{} && !defined $output_printed_112) {
                print $output_112;
                if (!($output_112 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_112 ) { $main_exit_code = 1; }
            })) {
            $GUESS = $UNAME_MACHINE;
            $main_exit_code = system('-unknown-linux-', $LIBC, 'eabi') >> 8;
}
        else {
            $GUESS = $UNAME_MACHINE;
            $main_exit_code = system('-unknown-linux-', $LIBC, 'eabihf') >> 8;
        }
    }
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^avr32.*:Linux:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^cris:Linux:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-axis-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^crisv32:Linux:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-axis-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^e2k:Linux:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^frv:Linux:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^hexagon:Linux:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*86:Linux:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-pc-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^ia64:Linux:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^k1om:Linux:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^loongarch32:Linux:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^loongarch64:Linux:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^loongarchx32:Linux:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^m32r.*:Linux:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^m68.*:Linux:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^mips:Linux:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^mips64:Linux:.*:.*$/msx) {
        set_cc_for_build();
        my $IS_GLIBC;
    my @IS_GLIBC;
    my %IS_GLIBC;
    $IS_GLIBC = q{0};
        if (do {
$main_exit_code = system('test', q{x}, ${LIBC}, q{=}, 'xgnu') >> 8;
        $CHILD_ERROR == 0
    }) {
                $IS_GLIBC = q{1};
    }
    my $temp_content = '	#undef CPU
	#undef mips
	#undef mipsel
	#undef mips64
	#undef mips64el
	#if ${IS_GLIBC} && defined(_ABI64)
	LIBCABI=gnuabi64
	#else
	#if ${IS_GLIBC} && defined(_ABIN32)
	LIBCABI=gnuabin32
	#else
	LIBCABI=${LIBC}
	#endif
	#endif

	#if ${IS_GLIBC} && defined(__mips64) && defined(__mips_isa_rev) && __mips_isa_rev>=6
	CPU=mipsisa64r6
	#else
	#if ${IS_GLIBC} && !defined(__mips64) && defined(__mips_isa_rev) && __mips_isa_rev>=6
	CPU=mipsisa32r6
	#else
	#if defined(__mips64)
	CPU=mips64
	#else
	CPU=mips
	#endif
	#endif
	#endif

	#if defined(__MIPSEL__) || defined(__MIPSEL) || defined(_MIPSEL) || defined(MIPSEL)
	MIPS_ENDIAN=el
	#else
	#if defined(__MIPSEB__) || defined(__MIPSEB) || defined(_MIPSEB) || defined(MIPSEB)
	MIPS_ENDIAN=
	#else
	MIPS_ENDIAN=
	#endif
	#endif
';
use File::Path qw(make_path);
if (!-d q{/tmp}) { make_path(q{/tmp}); }
open my $fh_5, '>', q{/tmp} . '/heredoc_temp' or croak "Cannot create temp file: $OS_ERROR\n";
print $fh_5 $temp_content;
close $fh_5 or croak "Close failed: $OS_ERROR\n";
open STDIN, '<', q{/tmp} . '/heredoc_temp' or croak "Cannot open temp file: $OS_ERROR\n";
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', "$ENV{dummy}.c"
      or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
my @sed_lines_115 = split /\n/msx, $;
my @sed_result_115;
foreach my $line (@sed_lines_115) {
chomp $line;
$line =~ s/^	//gmsx;
push @sed_result_115, $line;
}
$ = join "\n", @sed_result_115;

        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
        my $cc_set_vars;
    my @cc_set_vars;
    my %cc_set_vars;
    $cc_set_vars = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_116 = q{};
        my $output_printed_116;
        my $pipeline_success_116 = 1;
        my ($in_117, $out_117);
        my $pid_117 = open3($in_117, $out_117, '>&STDERR', 'unknown_command', '-E');
        close $in_117 or croak 'Close failed: $OS_ERROR';
        $output_116 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_117> };
        close $out_117 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_117, 0;
        my $grep_result_116_1;
        my @grep_lines_116_1 = split /\n/msx, $output_116;
        my @grep_filtered_116_1 = grep { /^CPU|^MIPS_ENDIAN|^LIBCABI/msx } @grep_lines_116_1;
        $grep_result_116_1 = join "\n", @grep_filtered_116_1;
        if (!($grep_result_116_1 =~ m{\n\z}msx || $grep_result_116_1 eq q{})) {
        $grep_result_116_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_116_1 > 0 ? 0 : 1;
        $output_116 = $grep_result_116_1;
        $output_116 = $grep_result_116_1;
        if ((scalar @grep_filtered_116_1) == 0) {
            $pipeline_success_116 = 0;
        }
        if ( !$pipeline_success_116 ) { $main_exit_code = 1; }
        $output_116 =~ s/\n+\z//msx;
        $output_116;
}; $_pipeline_result; };
    do { my $eval_input = $cc_set_vars; system('bash', '-c', "eval \"$eval_input\""); $CHILD_ERROR = $? >> 8; };
        if (do {
$main_exit_code = system('test', "x$ENV{CPU}", q{!}, q{=}, q{x}) >> 8;
        $CHILD_ERROR == 0
    }) {
                    do {
    my $__echo_line = "$ENV{CPU}" . ($ENV{MIPS_ENDIAN} // q{}) . "-unknown-linux-$ENV{LIBCABI}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
exit $main_exit_code;
    }
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^mips64el:Linux:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^openrisc.*:Linux:.*:.*$/msx) {
        $GUESS = 'or1k-unknown-linux-';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^or32:Linux:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^or1k.*:Linux:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^padre:Linux:.*:.*$/msx) {
        $GUESS = 'sparc-unknown-linux-';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^parisc64:Linux:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^hppa64:Linux:.*:.*$/msx) {
        $GUESS = 'hppa64-unknown-linux-';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^parisc:Linux:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^hppa:Linux:.*:.*$/msx) {
    if (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_118 = q{};
        my $output_printed_118;
        my $pipeline_success_118 = 1;
        my $grep_result_118_0;
        my @grep_lines_118_0 = ();
        my @grep_filenames_118_0 = ();
        if (-e "/proc/cpuinfo") {
        open my $fh, '<', "/proc/cpuinfo" or croak "Cannot open file: $ERRNO";
        while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_118_0, $line;
        push @grep_filenames_118_0, "/proc/cpuinfo";
        }
        close $fh
        or croak "Close failed: $OS_ERROR";
        }
        else { print {*STDERR} "grep: /proc/cpuinfo: No such file or directory\n"; }
        my @grep_filtered_118_0 = grep { /^cpu[^a-z]*:/msx } @grep_lines_118_0;
        $grep_result_118_0 = join "\n", @grep_filtered_118_0;
        if (!($grep_result_118_0 =~ m{\n\z}msx || $grep_result_118_0 eq q{})) {
        $grep_result_118_0 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_118_0 > 0 ? 0 : 1;
        $output_118 = $grep_result_118_0;
        my @lines_119 = split /\n/msx, $output_118;
        my @result_119;
        foreach my $line (@lines_119) {
        chomp $line;
        my @fields = split /\ /msx, $line;
        if (@fields > 1) {
        push @result_119, $fields[1];
        }
        }
        $output_118 = join "\n", @result_119;
        if ($output_118 ne q{} && !($output_118  =~ m{\n\z}msx)) { $output_118 .= "\n"; }
        if ( !$pipeline_success_118 ) { $main_exit_code = 1; }
        $output_118 =~ s/\n+\z//msx;
        $output_118;
}; $_pipeline_result; } =~ /^PA7.*$/msx) {
                $GUESS = 'hppa1.1';
                $main_exit_code = system('-u', 'nknown-linux-', $LIBC) >> 8;
    } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_120 = q{};
        my $output_printed_120;
        my $pipeline_success_120 = 1;
        my $grep_result_120_0;
        my @grep_lines_120_0 = ();
        my @grep_filenames_120_0 = ();
        if (-e "/proc/cpuinfo") {
        open my $fh, '<', "/proc/cpuinfo" or croak "Cannot open file: $ERRNO";
        while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_120_0, $line;
        push @grep_filenames_120_0, "/proc/cpuinfo";
        }
        close $fh
        or croak "Close failed: $OS_ERROR";
        }
        else { print {*STDERR} "grep: /proc/cpuinfo: No such file or directory\n"; }
        my @grep_filtered_120_0 = grep { /^cpu[^a-z]*:/msx } @grep_lines_120_0;
        $grep_result_120_0 = join "\n", @grep_filtered_120_0;
        if (!($grep_result_120_0 =~ m{\n\z}msx || $grep_result_120_0 eq q{})) {
        $grep_result_120_0 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_120_0 > 0 ? 0 : 1;
        $output_120 = $grep_result_120_0;
        my @lines_121 = split /\n/msx, $output_120;
        my @result_121;
        foreach my $line (@lines_121) {
        chomp $line;
        my @fields = split /\ /msx, $line;
        if (@fields > 1) {
        push @result_121, $fields[1];
        }
        }
        $output_120 = join "\n", @result_121;
        if ($output_120 ne q{} && !($output_120  =~ m{\n\z}msx)) { $output_120 .= "\n"; }
        if ( !$pipeline_success_120 ) { $main_exit_code = 1; }
        $output_120 =~ s/\n+\z//msx;
        $output_120;
}; $_pipeline_result; } =~ /^PA8.*$/msx) {
                $GUESS = 'hppa2.0';
                $main_exit_code = system('-u', 'nknown-linux-', $LIBC) >> 8;
    } elsif (1) {
                $GUESS = 'hppa-unknown-linux-';
                $CHILD_ERROR = 0;
    }
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^ppc64:Linux:.*:.*$/msx) {
        $GUESS = 'powerpc64-unknown-linux-';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^ppc:Linux:.*:.*$/msx) {
        $GUESS = 'powerpc-unknown-linux-';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^ppc64le:Linux:.*:.*$/msx) {
        $GUESS = 'powerpc64le-unknown-linux-';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^ppcle:Linux:.*:.*$/msx) {
        $GUESS = 'powerpcle-unknown-linux-';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^riscv32:Linux:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^riscv32be:Linux:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^riscv64:Linux:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^riscv64be:Linux:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^s390:Linux:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^s390x:Linux:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-ibm-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^sh64.*:Linux:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^sh.*:Linux:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^sparc:Linux:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^sparc64:Linux:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^tile.*:Linux:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^vax:Linux:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-dec-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^x86_64:Linux:.*:.*$/msx) {
        set_cc_for_build();
        my $LIBCABI;
    my @LIBCABI;
    my %LIBCABI;
    $LIBCABI = $LIBC;
    if ((!StringInterpolation(StringInterpolation { parts: [Variable("CC_FOR_BUILD")] }, None) eq no_compiler_found)) {
if (!(        # Original bash: #! /bin/sh
{
            my $output_122 = q{};
            my $output_printed_122;
            my $pipeline_success_122 = 1;
                        $output_122 = q{};
            $output_122 .= '#ifdef __ILP32__' . "\n";
            if ( !($output_122 =~ m{\n\z}msx) ) { $output_122 .= "\n"; }
            $CHILD_ERROR = 0;
            $output_122 .= 'IS_X32' . "\n";
            if ( !($output_122 =~ m{\n\z}msx) ) { $output_122 .= "\n"; }
            $CHILD_ERROR = 0;
            $output_122 .= '#endif' . "\n";
            if ( !($output_122 =~ m{\n\z}msx) ) { $output_122 .= "\n"; }
            $CHILD_ERROR = 0;

                        $output_122 = q{};
            my @_pcmd_124 = ('sh', '-c', ': "Complex command cannot be converted to shell command"');
            my ($in_123, $out_123);
            my $pid_123 = open3($in_123, $out_123, '>&STDERR', @_pcmd_124);
            close $in_123 or croak 'Close failed: $OS_ERROR';
            $output_122 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_123> };
            close $out_123 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_123, 0;
            my @_pcmd_126 = ('sh', '-c', '$CC_FOR_BUILD -E - 2> /dev/null');
            my ($in_125, $out_125);
            my $pid_125 = open3($in_125, $out_125, '>&STDERR', @_pcmd_126);
            close $in_125 or croak 'Close failed: $OS_ERROR';
            $output_122 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_125> };
            close $out_125 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_125, 0;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_127 = q{};
            my $grep_result_128;
            my @grep_lines_128 = split /\n/msx, $output_122;
            my @grep_filtered_128 = grep { /IS_X32/msx } @grep_lines_128;
            $grep_result_128 = join "\n", @grep_filtered_128;
            if (!($grep_result_128 =~ m{\n\z}msx || $grep_result_128 eq q{})) {
            $grep_result_128 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_128 > 0 ? 0 : 1;
            $tmp_redirect_127 = $grep_result_128;
            $tmp_redirect_127;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_122; }
            $output_printed_122 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_122 ) { $main_exit_code = 1; }
            })) {
            $LIBCABI = $LIBC;
            $main_exit_code = system('bash', 'x32') >> 8;
        }
    }
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-pc-linux-', $LIBCABI) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^xtensa.*:Linux:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-linux-', $LIBC) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*86:DYNIX/ptx:4.*:.*$/msx) {
        $GUESS = 'i386-sequent-sysv4';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*86:UNIX_SV:4.2MP:2..*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-pc-sysv4.2uw', $UNAME_VERSION) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*86:OS/2:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-pc-os2-emx') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*86:XTS-300:.*:STOP$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-unknown-stop') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*86:atheos:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-unknown-atheos') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*86:syllable:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-pc-syllable') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*86:LynxOS:2..*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*86:LynxOS:3.\[01\].*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*86:LynxOS:4.\[02\].*:.*$/msx) {
        $GUESS = 'i386-unknown-lynxos';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*86:.*DOS:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-pc-msdosdjgpp') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*86:.*:4..*:.*$/msx) {
        my $UNAME_REL;
    my @UNAME_REL;
    my %UNAME_REL;
    $UNAME_REL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_129 = q{};
        my $output_printed_129;
        my $pipeline_success_129 = 1;
        $output_129 .= $UNAME_RELEASE . "\n";
        if ( !($output_129 =~ m{\n\z}msx) ) { $output_129 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_129 = 0; }
        my @sed_lines_129 = split /\n/msx, $output_129;
        my @sed_result_129;
        foreach my $line (@sed_lines_129) {
        chomp $line;
        $line =~ s/\/MP$/gmsx;
        push @sed_result_129, $line;
        }
        $output_129 = join "\n", @sed_result_129;

        if ( !$pipeline_success_129 ) { $main_exit_code = 1; }
        $output_129 =~ s/\n+\z//msx;
        $output_129;
}; $_pipeline_result; };
    if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $grep_result_130;
my @grep_lines_130 = ();
my @grep_filenames_130 = ();
if (-e "/usr/include/link.h") {
    open my $fh, '<', "/usr/include/link.h" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_130, $line;
        push @grep_filenames_130, "/usr/include/link.h";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /usr/include/link.h: No such file or directory\n"; }
my @grep_filtered_130 = grep { /Novell/msx } @grep_lines_130;
$grep_result_130 = join "\n", @grep_filtered_130;
        if (!($grep_result_130 =~ m{\n\z}msx || $grep_result_130 eq q{})) {
            $grep_result_130 .= "\n";
        }
print $grep_result_130;
$CHILD_ERROR = scalar @grep_filtered_130 > 0 ? 0 : 1;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-univel-sysv', $UNAME_REL) >> 8;
}
    else {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-pc-sysv', $UNAME_REL) >> 8;
    }
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*86:.*:5:\[678\].*$/msx) {
    if (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_131 = q{};
        my $output_printed_131;
        my $pipeline_success_131 = 1;

        my ($in_132, $out_132);
        my $pid_132 = open3($in_132, $out_132, '>&STDERR', '/bin/uname', '-X');
        close $in_132 or croak 'Close failed: $OS_ERROR';
        $output_131 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_132> };
        close $out_132 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_132, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_131 = 0; }
        my $grep_result_131_1;
        my @grep_lines_131_1 = split /\n/msx, $output_131;
        my @grep_filtered_131_1 = grep { /^Machine/msx } @grep_lines_131_1;
        $grep_result_131_1 = join "\n", @grep_filtered_131_1;
                if (!($grep_result_131_1 =~ m{\n\z}msx || $grep_result_131_1 eq q{})) {
                    $grep_result_131_1 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_131_1 > 0 ? 0 : 1;
        $output_131 = $grep_result_131_1;
        if ((scalar @grep_filtered_131_1) == 0) {
            $pipeline_success_131 = 0;
        }
        if ( !$pipeline_success_131 ) { $main_exit_code = 1; }
        $output_131 =~ s/\n+\z//msx;
        $output_131;
}; $_pipeline_result; } =~ /^.*486.*$/msx) {
                $UNAME_MACHINE = 'i486';
    } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_133 = q{};
        my $output_printed_133;
        my $pipeline_success_133 = 1;

        my ($in_134, $out_134);
        my $pid_134 = open3($in_134, $out_134, '>&STDERR', '/bin/uname', '-X');
        close $in_134 or croak 'Close failed: $OS_ERROR';
        $output_133 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_134> };
        close $out_134 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_134, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_133 = 0; }
        my $grep_result_133_1;
        my @grep_lines_133_1 = split /\n/msx, $output_133;
        my @grep_filtered_133_1 = grep { /^Machine/msx } @grep_lines_133_1;
        $grep_result_133_1 = join "\n", @grep_filtered_133_1;
                if (!($grep_result_133_1 =~ m{\n\z}msx || $grep_result_133_1 eq q{})) {
                    $grep_result_133_1 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_133_1 > 0 ? 0 : 1;
        $output_133 = $grep_result_133_1;
        if ((scalar @grep_filtered_133_1) == 0) {
            $pipeline_success_133 = 0;
        }
        if ( !$pipeline_success_133 ) { $main_exit_code = 1; }
        $output_133 =~ s/\n+\z//msx;
        $output_133;
}; $_pipeline_result; } =~ /^.*Pentium$/msx) {
                $UNAME_MACHINE = 'i586';
    } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_135 = q{};
        my $output_printed_135;
        my $pipeline_success_135 = 1;

        my ($in_136, $out_136);
        my $pid_136 = open3($in_136, $out_136, '>&STDERR', '/bin/uname', '-X');
        close $in_136 or croak 'Close failed: $OS_ERROR';
        $output_135 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_136> };
        close $out_136 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_136, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_135 = 0; }
        my $grep_result_135_1;
        my @grep_lines_135_1 = split /\n/msx, $output_135;
        my @grep_filtered_135_1 = grep { /^Machine/msx } @grep_lines_135_1;
        $grep_result_135_1 = join "\n", @grep_filtered_135_1;
                if (!($grep_result_135_1 =~ m{\n\z}msx || $grep_result_135_1 eq q{})) {
                    $grep_result_135_1 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_135_1 > 0 ? 0 : 1;
        $output_135 = $grep_result_135_1;
        if ((scalar @grep_filtered_135_1) == 0) {
            $pipeline_success_135 = 0;
        }
        if ( !$pipeline_success_135 ) { $main_exit_code = 1; }
        $output_135 =~ s/\n+\z//msx;
        $output_135;
}; $_pipeline_result; } =~ /^.*Pent.*$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_137 = q{};
        my $output_printed_137;
        my $pipeline_success_137 = 1;

        my ($in_138, $out_138);
        my $pid_138 = open3($in_138, $out_138, '>&STDERR', '/bin/uname', '-X');
        close $in_138 or croak 'Close failed: $OS_ERROR';
        $output_137 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_138> };
        close $out_138 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_138, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_137 = 0; }
        my $grep_result_137_1;
        my @grep_lines_137_1 = split /\n/msx, $output_137;
        my @grep_filtered_137_1 = grep { /^Machine/msx } @grep_lines_137_1;
        $grep_result_137_1 = join "\n", @grep_filtered_137_1;
                if (!($grep_result_137_1 =~ m{\n\z}msx || $grep_result_137_1 eq q{})) {
                    $grep_result_137_1 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_137_1 > 0 ? 0 : 1;
        $output_137 = $grep_result_137_1;
        if ((scalar @grep_filtered_137_1) == 0) {
            $pipeline_success_137 = 0;
        }
        if ( !$pipeline_success_137 ) { $main_exit_code = 1; }
        $output_137 =~ s/\n+\z//msx;
        $output_137;
}; $_pipeline_result; } =~ /^.*Celeron$/msx) {
                $UNAME_MACHINE = 'i686';
    }
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-sysv', $UNAME_RELEASE, $UNAME_SYSTEM, $UNAME_VERSION) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*86:.*:3.2:.*$/msx) {
    if ((-f '/usr/options/cb.name')) {
        $UNAME_REL = do { my @_qx_cmd = ("sed -n 's/.*Version //p' < /usr/options/cb.name"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-pc-isc', $UNAME_REL) >> 8;
}
    else {
        if (!(        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('/bin/uname', '-X') >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        })) {
            $UNAME_REL = do {
    my $command = q{(/bin/uname -X | grep Release | sed -e 's/.*= //')};
    my ($in, $out, $err);
    my $pid = open3($in, $out, $err, 'bash', '-c', $command);
    close $in or croak 'Close failed: $OS_ERROR';
    my $result = do { local $INPUT_RECORD_SEPARATOR = undef; <$out> };
    close $out or croak 'Close failed: $OS_ERROR';
    waitpid $pid, 0;
    $CHILD_ERROR = $? >> 8;
    $result;
};
            if (do {
do {
    local %ENV = %ENV;
    my $CRAY_REL = $CRAY_REL;
    my $dummyarg = $dummyarg;
    my $tmp = $tmp;
    my $help = $help;
    my $UNAME_SYSTEM = $UNAME_SYSTEM;
    my $HP_ARCH = $HP_ARCH;
    my $CCOPTS = $CCOPTS;
    my $FUJITSU_REL = $FUJITSU_REL;
    my $timestamp = $timestamp;
    my $sc_kernel_bits = $sc_kernel_bits;
    my $IRIX_REL = $IRIX_REL;
    my $machine = $machine;
    my $FUJITSU_PROC = $FUJITSU_PROC;
    my $PATH = $PATH;
    my $ALPHA_CPU_TYPE = $ALPHA_CPU_TYPE;
    my $GNU_REL = $GNU_REL;
    my $IBM_CPU_ID = $IBM_CPU_ID;
    my $expr = $expr;
    my $HPUX_REV = $HPUX_REV;
    my $OSF_REL = $OSF_REL;
    my $SUN_REL = $SUN_REL;
    my $UNAME_VERSION = $UNAME_VERSION;
    my $IBM_REV = $IBM_REV;
    my $LIBCABI = $LIBCABI;
    my $FUJITSU_SYS = $FUJITSU_SYS;
    my $cc_set_vars = $cc_set_vars;
    my $SYSTEM_NAME = $SYSTEM_NAME;
    my $FREEBSD_REL = $FREEBSD_REL;
    my $UNAME_REL = $UNAME_REL;
    my $me = $me;
    my $GUESS = $GUESS;
    my $UNAME_MACHINE = $UNAME_MACHINE;
    my $GNU_ARCH = $GNU_ARCH;
    my $IBM_ARCH = $IBM_ARCH;
    my $sc_cpu_version = $sc_cpu_version;
    my $abi = $abi;
    my $arch = $arch;
    my $endian = $endian;
    my $UNAME_PROCESSOR = $UNAME_PROCESSOR;
    my $# = $#;
    my $UNAME_MACHINE_ARCH = $UNAME_MACHINE_ARCH;
    my $usage = $usage;
    my $SUN_ARCH = $SUN_ARCH;
    my $cc_set_libc = $cc_set_libc;
    my $UNAME_RELEASE = $UNAME_RELEASE;
    my $os = $os;
    my $version = $version;
    my $GNU_SYS = $GNU_SYS;
    my $release = $release;
    my $IS_GLIBC = $IS_GLIBC;
    # Original bash: /bin/uname -X|grep i80486 >/dev/null)
{
        my $output_139 = q{};
        my $output_printed_139;
        my $pipeline_success_139 = 1;
                my ($in_140, $out_140);
        my $pid_140 = open3($in_140, $out_140, '>&STDERR', '/bin/uname', '-X');
        close $in_140 or croak 'Close failed: $OS_ERROR';
        $output_139 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_140> };
        close $out_140 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_140, 0;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_141 = q{};
        my $grep_result_142;
        my @grep_lines_142 = split /\n/msx, $output_139;
        my @grep_filtered_142 = grep { /i80486/msx } @grep_lines_142;
        $grep_result_142 = join "\n", @grep_filtered_142;
        if (!($grep_result_142 =~ m{\n\z}msx || $grep_result_142 eq q{})) {
        $grep_result_142 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_142 > 0 ? 0 : 1;
        $tmp_redirect_141 = $grep_result_142;
        $tmp_redirect_141;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_139; }
        $output_printed_139 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_139 ) { $main_exit_code = 1; }
        }
    q{};
};
                $CHILD_ERROR == 0
            }) {
                                $UNAME_MACHINE = 'i486';
            }
            if (do {
do {
    local %ENV = %ENV;
    my $CRAY_REL = $CRAY_REL;
    my $dummyarg = $dummyarg;
    my $tmp = $tmp;
    my $help = $help;
    my $UNAME_SYSTEM = $UNAME_SYSTEM;
    my $HP_ARCH = $HP_ARCH;
    my $CCOPTS = $CCOPTS;
    my $FUJITSU_REL = $FUJITSU_REL;
    my $timestamp = $timestamp;
    my $sc_kernel_bits = $sc_kernel_bits;
    my $IRIX_REL = $IRIX_REL;
    my $machine = $machine;
    my $FUJITSU_PROC = $FUJITSU_PROC;
    my $PATH = $PATH;
    my $ALPHA_CPU_TYPE = $ALPHA_CPU_TYPE;
    my $GNU_REL = $GNU_REL;
    my $IBM_CPU_ID = $IBM_CPU_ID;
    my $expr = $expr;
    my $HPUX_REV = $HPUX_REV;
    my $OSF_REL = $OSF_REL;
    my $SUN_REL = $SUN_REL;
    my $UNAME_VERSION = $UNAME_VERSION;
    my $IBM_REV = $IBM_REV;
    my $LIBCABI = $LIBCABI;
    my $FUJITSU_SYS = $FUJITSU_SYS;
    my $cc_set_vars = $cc_set_vars;
    my $SYSTEM_NAME = $SYSTEM_NAME;
    my $FREEBSD_REL = $FREEBSD_REL;
    my $UNAME_REL = $UNAME_REL;
    my $me = $me;
    my $GUESS = $GUESS;
    my $UNAME_MACHINE = $UNAME_MACHINE;
    my $GNU_ARCH = $GNU_ARCH;
    my $IBM_ARCH = $IBM_ARCH;
    my $sc_cpu_version = $sc_cpu_version;
    my $abi = $abi;
    my $arch = $arch;
    my $endian = $endian;
    my $UNAME_PROCESSOR = $UNAME_PROCESSOR;
    my $# = $#;
    my $UNAME_MACHINE_ARCH = $UNAME_MACHINE_ARCH;
    my $usage = $usage;
    my $SUN_ARCH = $SUN_ARCH;
    my $cc_set_libc = $cc_set_libc;
    my $UNAME_RELEASE = $UNAME_RELEASE;
    my $os = $os;
    my $version = $version;
    my $GNU_SYS = $GNU_SYS;
    my $release = $release;
    my $IS_GLIBC = $IS_GLIBC;
    # Original bash: /bin/uname -X|grep '^Machine.*Pentium' >/dev/null)
{
        my $output_143 = q{};
        my $output_printed_143;
        my $pipeline_success_143 = 1;
                my ($in_144, $out_144);
        my $pid_144 = open3($in_144, $out_144, '>&STDERR', '/bin/uname', '-X');
        close $in_144 or croak 'Close failed: $OS_ERROR';
        $output_143 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_144> };
        close $out_144 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_144, 0;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_145 = q{};
        my $grep_result_146;
        my @grep_lines_146 = split /\n/msx, $output_143;
        my @grep_filtered_146 = grep { /^Machine.*Pentium/msx } @grep_lines_146;
        $grep_result_146 = join "\n", @grep_filtered_146;
        if (!($grep_result_146 =~ m{\n\z}msx || $grep_result_146 eq q{})) {
        $grep_result_146 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_146 > 0 ? 0 : 1;
        $tmp_redirect_145 = $grep_result_146;
        $tmp_redirect_145;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_143; }
        $output_printed_143 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_143 ) { $main_exit_code = 1; }
        }
    q{};
};
                $CHILD_ERROR == 0
            }) {
                                $UNAME_MACHINE = 'i586';
            }
            if (do {
do {
    local %ENV = %ENV;
    my $CRAY_REL = $CRAY_REL;
    my $dummyarg = $dummyarg;
    my $tmp = $tmp;
    my $help = $help;
    my $UNAME_SYSTEM = $UNAME_SYSTEM;
    my $HP_ARCH = $HP_ARCH;
    my $CCOPTS = $CCOPTS;
    my $FUJITSU_REL = $FUJITSU_REL;
    my $timestamp = $timestamp;
    my $sc_kernel_bits = $sc_kernel_bits;
    my $IRIX_REL = $IRIX_REL;
    my $machine = $machine;
    my $FUJITSU_PROC = $FUJITSU_PROC;
    my $PATH = $PATH;
    my $ALPHA_CPU_TYPE = $ALPHA_CPU_TYPE;
    my $GNU_REL = $GNU_REL;
    my $IBM_CPU_ID = $IBM_CPU_ID;
    my $expr = $expr;
    my $HPUX_REV = $HPUX_REV;
    my $OSF_REL = $OSF_REL;
    my $SUN_REL = $SUN_REL;
    my $UNAME_VERSION = $UNAME_VERSION;
    my $IBM_REV = $IBM_REV;
    my $LIBCABI = $LIBCABI;
    my $FUJITSU_SYS = $FUJITSU_SYS;
    my $cc_set_vars = $cc_set_vars;
    my $SYSTEM_NAME = $SYSTEM_NAME;
    my $FREEBSD_REL = $FREEBSD_REL;
    my $UNAME_REL = $UNAME_REL;
    my $me = $me;
    my $GUESS = $GUESS;
    my $UNAME_MACHINE = $UNAME_MACHINE;
    my $GNU_ARCH = $GNU_ARCH;
    my $IBM_ARCH = $IBM_ARCH;
    my $sc_cpu_version = $sc_cpu_version;
    my $abi = $abi;
    my $arch = $arch;
    my $endian = $endian;
    my $UNAME_PROCESSOR = $UNAME_PROCESSOR;
    my $# = $#;
    my $UNAME_MACHINE_ARCH = $UNAME_MACHINE_ARCH;
    my $usage = $usage;
    my $SUN_ARCH = $SUN_ARCH;
    my $cc_set_libc = $cc_set_libc;
    my $UNAME_RELEASE = $UNAME_RELEASE;
    my $os = $os;
    my $version = $version;
    my $GNU_SYS = $GNU_SYS;
    my $release = $release;
    my $IS_GLIBC = $IS_GLIBC;
    # Original bash: /bin/uname -X|grep '^Machine.*Pent *II' >/dev/null)
{
        my $output_147 = q{};
        my $output_printed_147;
        my $pipeline_success_147 = 1;
                my ($in_148, $out_148);
        my $pid_148 = open3($in_148, $out_148, '>&STDERR', '/bin/uname', '-X');
        close $in_148 or croak 'Close failed: $OS_ERROR';
        $output_147 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_148> };
        close $out_148 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_148, 0;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_149 = q{};
        my $grep_result_150;
        my @grep_lines_150 = split /\n/msx, $output_147;
        my @grep_filtered_150 = grep { /^Machine.*Pent\ *II/msx } @grep_lines_150;
        $grep_result_150 = join "\n", @grep_filtered_150;
        if (!($grep_result_150 =~ m{\n\z}msx || $grep_result_150 eq q{})) {
        $grep_result_150 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_150 > 0 ? 0 : 1;
        $tmp_redirect_149 = $grep_result_150;
        $tmp_redirect_149;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_147; }
        $output_printed_147 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_147 ) { $main_exit_code = 1; }
        }
    q{};
};
                $CHILD_ERROR == 0
            }) {
                                $UNAME_MACHINE = 'i686';
            }
            if (do {
do {
    local %ENV = %ENV;
    my $CRAY_REL = $CRAY_REL;
    my $dummyarg = $dummyarg;
    my $tmp = $tmp;
    my $help = $help;
    my $UNAME_SYSTEM = $UNAME_SYSTEM;
    my $HP_ARCH = $HP_ARCH;
    my $CCOPTS = $CCOPTS;
    my $FUJITSU_REL = $FUJITSU_REL;
    my $timestamp = $timestamp;
    my $sc_kernel_bits = $sc_kernel_bits;
    my $IRIX_REL = $IRIX_REL;
    my $machine = $machine;
    my $FUJITSU_PROC = $FUJITSU_PROC;
    my $PATH = $PATH;
    my $ALPHA_CPU_TYPE = $ALPHA_CPU_TYPE;
    my $GNU_REL = $GNU_REL;
    my $IBM_CPU_ID = $IBM_CPU_ID;
    my $expr = $expr;
    my $HPUX_REV = $HPUX_REV;
    my $OSF_REL = $OSF_REL;
    my $SUN_REL = $SUN_REL;
    my $UNAME_VERSION = $UNAME_VERSION;
    my $IBM_REV = $IBM_REV;
    my $LIBCABI = $LIBCABI;
    my $FUJITSU_SYS = $FUJITSU_SYS;
    my $cc_set_vars = $cc_set_vars;
    my $SYSTEM_NAME = $SYSTEM_NAME;
    my $FREEBSD_REL = $FREEBSD_REL;
    my $UNAME_REL = $UNAME_REL;
    my $me = $me;
    my $GUESS = $GUESS;
    my $UNAME_MACHINE = $UNAME_MACHINE;
    my $GNU_ARCH = $GNU_ARCH;
    my $IBM_ARCH = $IBM_ARCH;
    my $sc_cpu_version = $sc_cpu_version;
    my $abi = $abi;
    my $arch = $arch;
    my $endian = $endian;
    my $UNAME_PROCESSOR = $UNAME_PROCESSOR;
    my $# = $#;
    my $UNAME_MACHINE_ARCH = $UNAME_MACHINE_ARCH;
    my $usage = $usage;
    my $SUN_ARCH = $SUN_ARCH;
    my $cc_set_libc = $cc_set_libc;
    my $UNAME_RELEASE = $UNAME_RELEASE;
    my $os = $os;
    my $version = $version;
    my $GNU_SYS = $GNU_SYS;
    my $release = $release;
    my $IS_GLIBC = $IS_GLIBC;
    # Original bash: /bin/uname -X|grep '^Machine.*Pentium Pro' >/dev/null)
{
        my $output_151 = q{};
        my $output_printed_151;
        my $pipeline_success_151 = 1;
                my ($in_152, $out_152);
        my $pid_152 = open3($in_152, $out_152, '>&STDERR', '/bin/uname', '-X');
        close $in_152 or croak 'Close failed: $OS_ERROR';
        $output_151 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_152> };
        close $out_152 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_152, 0;

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_153 = q{};
        my $grep_result_154;
        my @grep_lines_154 = split /\n/msx, $output_151;
        my @grep_filtered_154 = grep { /^Machine.*Pentium\ Pro/msx } @grep_lines_154;
        $grep_result_154 = join "\n", @grep_filtered_154;
        if (!($grep_result_154 =~ m{\n\z}msx || $grep_result_154 eq q{})) {
        $grep_result_154 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_154 > 0 ? 0 : 1;
        $tmp_redirect_153 = $grep_result_154;
        $tmp_redirect_153;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_151; }
        $output_printed_151 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_151 ) { $main_exit_code = 1; }
        }
    q{};
};
                $CHILD_ERROR == 0
            }) {
                                $UNAME_MACHINE = 'i686';
            }
            $GUESS = $UNAME_MACHINE;
            $main_exit_code = system('-pc-sco', $UNAME_REL) >> 8;
}
        else {
            $GUESS = $UNAME_MACHINE;
            $main_exit_code = system('bash', '-pc-sysv32') >> 8;
        }
    }
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^pc:.*:.*:.*$/msx) {
        $GUESS = 'i586-pc-msdosdjgpp';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^Intel:Mach:3.*:.*$/msx) {
        $GUESS = 'i386-pc-mach3';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^paragon:.*:.*:.*$/msx) {
        $GUESS = 'i860-intel-osf1';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i860:.*:4..*:.*$/msx) {
    if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $grep_result_155;
my @grep_lines_155 = ();
my @grep_filenames_155 = ();
if (-e "/usr/include/sys/uadmin.h") {
    open my $fh, '<', "/usr/include/sys/uadmin.h" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_155, $line;
        push @grep_filenames_155, "/usr/include/sys/uadmin.h";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /usr/include/sys/uadmin.h: No such file or directory\n"; }
my @grep_filtered_155 = grep { /Stardent/msx } @grep_lines_155;
$grep_result_155 = join "\n", @grep_filtered_155;
        if (!($grep_result_155 =~ m{\n\z}msx || $grep_result_155 eq q{})) {
            $grep_result_155 .= "\n";
        }
print $grep_result_155;
$CHILD_ERROR = scalar @grep_filtered_155 > 0 ? 0 : 1;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
        $GUESS = 'i860-stardent-sysv';
        $CHILD_ERROR = 0;
}
    else {
        $GUESS = 'i860-unknown-sysv';
        $CHILD_ERROR = 0;
    }
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^mini.*:CTIX:SYS.*5:.*$/msx) {
        $GUESS = 'm68010-convergent-sysv';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^mc68k:UNIX:SYSTEM5:3.51m$/msx) {
        $GUESS = 'm68k-convergent-sysv';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^M680.0:D-NIX:5.3:.*$/msx) {
        $GUESS = 'm68k-diab-dnix';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^M68.*:.*:R3V\[5678\].*:.*$/msx) {
        if (do {
$main_exit_code = system('test', '-r', '/sysV68') >> 8;
        $CHILD_ERROR == 0
    }) {
                    print 'm68k-motorola-sysv' . "\n";
            $CHILD_ERROR = 0;
exit $main_exit_code;
    }
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^3\[345\]..:.*:4.0:3.0$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^3\[34\]..A:.*:4.0:3.0$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^3\[34\]..,.*:.*:4.0:3.0$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^3\[34\]../.*:.*:4.0:3.0$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^4400:.*:4.0:3.0$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^4850:.*:4.0:3.0$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^SKA40:.*:4.0:3.0$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^SDS2:.*:4.0:3.0$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^SHG2:.*:4.0:3.0$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^S7501.*:.*:4.0:3.0$/msx) {
        my $OS_REL;
    my @OS_REL;
    my %OS_REL;
    $OS_REL = q{};
        if (do {
$main_exit_code = system('test', '-r', '/etc/.relid') >> 8;
        $CHILD_ERROR == 0
    }) {
                $OS_REL = q{.};
        $CHILD_ERROR = 0;
    }
        if (do {
{
    my $output_156 = q{};
    my $output_printed_156;
    my $pipeline_success_156 = 1;
        $output = q{};
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_157 = q{};

my $cmd_160 = '/bin/uname';
my ($in_159, $out_159);
my $pid_159 = open3($in_159, $out_159, '>&STDERR', $cmd_160, '-p');
print {$in_159} $output_156;
close $in_159 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_157 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_159> };
close $out_159 or croak 'Close failed: $OS_ERROR';
waitpid $pid_159, 0;
$tmp_redirect_157;
    };
    $output_156 = $output;

        do {
    open my $original_stdout, '>&', STDOUT
    or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
    or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    my $tmp_redirect_161 = q{};
    my $grep_result_162;
    my @grep_lines_162 = split /\n/msx, $output_156;
    my @grep_filtered_162 = grep { /86/msx } @grep_lines_162;
    $grep_result_162 = join "\n", @grep_filtered_162;
    if (!($grep_result_162 =~ m{\n\z}msx || $grep_result_162 eq q{})) {
    $grep_result_162 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_162 > 0 ? 0 : 1;
    $tmp_redirect_161 = $grep_result_162;
    $tmp_redirect_161;
    };
    print $tmp;
    if ($tmp eq q{}) { print $output_156; }
    $output_printed_156 = 1;
    open STDOUT, '>&', $original_stdout
    or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
    or die "Close failed: $OS_ERROR\n";
    };
    if ( !$pipeline_success_156 ) { $main_exit_code = 1; }
    }
        $CHILD_ERROR == 0
    }) {
                    do {
    my $__echo_line = 'i486-ncr-sysv4.3' . q{ } . $OS_REL;
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
exit $main_exit_code;
    }
        if (do {
{
    my $output_163 = q{};
    my $output_printed_163;
    my $pipeline_success_163 = 1;
        $output = q{};
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_164 = q{};

my $cmd_167 = '/bin/uname';
my ($in_166, $out_166);
my $pid_166 = open3($in_166, $out_166, '>&STDERR', $cmd_167, '-p');
print {$in_166} $output_163;
close $in_166 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_164 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_166> };
close $out_166 or croak 'Close failed: $OS_ERROR';
waitpid $pid_166, 0;
$tmp_redirect_164;
    };
    $output_163 = $output;

        do {
    open my $original_stdout, '>&', STDOUT
    or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
    or die "Cannot open file: $OS_ERROR\n";
    my $tmp_redirect_168 = q{};
    my $cmd_171 = '/bin/grep';
    my ($in_170, $out_170);
    my $pid_170 = open3($in_170, $out_170, '>&STDERR', $cmd_171, 'entium');
    print {$in_170} $output_163;
    close $in_170 or croak 'Close failed: $OS_ERROR';
    $tmp_redirect_168 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_170> };
    close $out_170 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_170, 0;
    $tmp_redirect_168;
    $output_printed_163 = 1;
    open STDOUT, '>&', $original_stdout
    or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
    or die "Close failed: $OS_ERROR\n";
    };
    if ( !$pipeline_success_163 ) { $main_exit_code = 1; }
    }
        $CHILD_ERROR == 0
    }) {
                    do {
    my $__echo_line = 'i586-ncr-sysv4.3' . q{ } . $OS_REL;
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
exit $main_exit_code;
    }
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^3\[34\]..:.*:4.0:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^3\[34\]..,.*:.*:4.0:.*$/msx) {
        if (do {
{
    my $output_172 = q{};
    my $output_printed_172;
    my $pipeline_success_172 = 1;
        $output = q{};
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_173 = q{};

my $cmd_176 = '/bin/uname';
my ($in_175, $out_175);
my $pid_175 = open3($in_175, $out_175, '>&STDERR', $cmd_176, '-p');
print {$in_175} $output_172;
close $in_175 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_173 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_175> };
close $out_175 or croak 'Close failed: $OS_ERROR';
waitpid $pid_175, 0;
$tmp_redirect_173;
    };
    $output_172 = $output;

        do {
    open my $original_stdout, '>&', STDOUT
    or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
    or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    my $tmp_redirect_177 = q{};
    my $grep_result_178;
    my @grep_lines_178 = split /\n/msx, $output_172;
    my @grep_filtered_178 = grep { /86/msx } @grep_lines_178;
    $grep_result_178 = join "\n", @grep_filtered_178;
    if (!($grep_result_178 =~ m{\n\z}msx || $grep_result_178 eq q{})) {
    $grep_result_178 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_178 > 0 ? 0 : 1;
    $tmp_redirect_177 = $grep_result_178;
    $tmp_redirect_177;
    };
    print $tmp;
    if ($tmp eq q{}) { print $output_172; }
    $output_printed_172 = 1;
    open STDOUT, '>&', $original_stdout
    or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
    or die "Close failed: $OS_ERROR\n";
    };
    if ( !$pipeline_success_172 ) { $main_exit_code = 1; }
    }
        $CHILD_ERROR == 0
    }) {
                    print 'i486-ncr-sysv4' . "\n";
            $CHILD_ERROR = 0;
exit $main_exit_code;
    }
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^NCR.*:.*:4.2:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^MPRAS.*:.*:4.2:.*$/msx) {
        $OS_REL = '.3';
        if (do {
$main_exit_code = system('test', '-r', '/etc/.relid') >> 8;
        $CHILD_ERROR == 0
    }) {
                $OS_REL = q{.};
        $CHILD_ERROR = 0;
    }
        if (do {
{
    my $output_179 = q{};
    my $output_printed_179;
    my $pipeline_success_179 = 1;
        $output = q{};
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_180 = q{};

my $cmd_183 = '/bin/uname';
my ($in_182, $out_182);
my $pid_182 = open3($in_182, $out_182, '>&STDERR', $cmd_183, '-p');
print {$in_182} $output_179;
close $in_182 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_180 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_182> };
close $out_182 or croak 'Close failed: $OS_ERROR';
waitpid $pid_182, 0;
$tmp_redirect_180;
    };
    $output_179 = $output;

        do {
    open my $original_stdout, '>&', STDOUT
    or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
    or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    my $tmp_redirect_184 = q{};
    my $grep_result_185;
    my @grep_lines_185 = split /\n/msx, $output_179;
    my @grep_filtered_185 = grep { /86/msx } @grep_lines_185;
    $grep_result_185 = join "\n", @grep_filtered_185;
    if (!($grep_result_185 =~ m{\n\z}msx || $grep_result_185 eq q{})) {
    $grep_result_185 .= "\n";
    }
    $CHILD_ERROR = scalar @grep_filtered_185 > 0 ? 0 : 1;
    $tmp_redirect_184 = $grep_result_185;
    $tmp_redirect_184;
    };
    print $tmp;
    if ($tmp eq q{}) { print $output_179; }
    $output_printed_179 = 1;
    open STDOUT, '>&', $original_stdout
    or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
    or die "Close failed: $OS_ERROR\n";
    };
    if ( !$pipeline_success_179 ) { $main_exit_code = 1; }
    }
        $CHILD_ERROR == 0
    }) {
                    do {
    my $__echo_line = 'i486-ncr-sysv4.3' . q{ } . $OS_REL;
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
exit $main_exit_code;
    }
        if (do {
{
    my $output_186 = q{};
    my $output_printed_186;
    my $pipeline_success_186 = 1;
        $output = q{};
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_187 = q{};

my $cmd_190 = '/bin/uname';
my ($in_189, $out_189);
my $pid_189 = open3($in_189, $out_189, '>&STDERR', $cmd_190, '-p');
print {$in_189} $output_186;
close $in_189 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_187 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_189> };
close $out_189 or croak 'Close failed: $OS_ERROR';
waitpid $pid_189, 0;
$tmp_redirect_187;
    };
    $output_186 = $output;

        do {
    open my $original_stdout, '>&', STDOUT
    or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
    or die "Cannot open file: $OS_ERROR\n";
    my $tmp_redirect_191 = q{};
    my $cmd_194 = '/bin/grep';
    my ($in_193, $out_193);
    my $pid_193 = open3($in_193, $out_193, '>&STDERR', $cmd_194, 'entium');
    print {$in_193} $output_186;
    close $in_193 or croak 'Close failed: $OS_ERROR';
    $tmp_redirect_191 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_193> };
    close $out_193 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_193, 0;
    $tmp_redirect_191;
    $output_printed_186 = 1;
    open STDOUT, '>&', $original_stdout
    or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
    or die "Close failed: $OS_ERROR\n";
    };
    if ( !$pipeline_success_186 ) { $main_exit_code = 1; }
    }
        $CHILD_ERROR == 0
    }) {
                    do {
    my $__echo_line = 'i586-ncr-sysv4.3' . q{ } . $OS_REL;
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
exit $main_exit_code;
    }
        if (do {
{
    my $output_195 = q{};
    my $output_printed_195;
    my $pipeline_success_195 = 1;
        $output = q{};
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_196 = q{};

my $cmd_199 = '/bin/uname';
my ($in_198, $out_198);
my $pid_198 = open3($in_198, $out_198, '>&STDERR', $cmd_199, '-p');
print {$in_198} $output_195;
close $in_198 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_196 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_198> };
close $out_198 or croak 'Close failed: $OS_ERROR';
waitpid $pid_198, 0;
$tmp_redirect_196;
    };
    $output_195 = $output;

        do {
    open my $original_stdout, '>&', STDOUT
    or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
    or die "Cannot open file: $OS_ERROR\n";
    my $tmp_redirect_200 = q{};
    my $cmd_203 = '/bin/grep';
    my ($in_202, $out_202);
    my $pid_202 = open3($in_202, $out_202, '>&STDERR', $cmd_203, 'pteron');
    print {$in_202} $output_195;
    close $in_202 or croak 'Close failed: $OS_ERROR';
    $tmp_redirect_200 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_202> };
    close $out_202 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_202, 0;
    $tmp_redirect_200;
    $output_printed_195 = 1;
    open STDOUT, '>&', $original_stdout
    or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
    or die "Close failed: $OS_ERROR\n";
    };
    if ( !$pipeline_success_195 ) { $main_exit_code = 1; }
    }
        $CHILD_ERROR == 0
    }) {
                    do {
    my $__echo_line = 'i586-ncr-sysv4.3' . q{ } . $OS_REL;
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
            $CHILD_ERROR = 0;
exit $main_exit_code;
    }
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^m68.*:LynxOS:2..*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^m68.*:LynxOS:3.0.*:.*$/msx) {
        $GUESS = 'm68k-unknown-lynxos';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^mc68030:UNIX_System_V:4..*:.*$/msx) {
        $GUESS = 'm68k-atari-sysv4';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^TSUNAMI:LynxOS:2..*:.*$/msx) {
        $GUESS = 'sparc-unknown-lynxos';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^rs6000:LynxOS:2..*:.*$/msx) {
        $GUESS = 'rs6000-unknown-lynxos';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^PowerPC:LynxOS:2..*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^PowerPC:LynxOS:3.\[01\].*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^PowerPC:LynxOS:4.\[02\].*:.*$/msx) {
        $GUESS = 'powerpc-unknown-lynxos';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^SM\[BE\]S:UNIX_SV:.*:.*$/msx) {
        $GUESS = 'mips-dde-sysv';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^RM.*:ReliantUNIX-.*:.*:.*$/msx) {
        $GUESS = 'mips-sni-sysv4';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^RM.*:SINIX-.*:.*:.*$/msx) {
        $GUESS = 'mips-sni-sysv4';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:SINIX-.*:.*:.*$/msx) {
    if (!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('/bin/uname', '-p') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    })) {
        $UNAME_MACHINE = do { my @_qx_cmd = ("uname -p 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-sni-sysv4') >> 8;
}
    else {
        $GUESS = 'ns32k-sni-sysv';
    }
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^PENTIUM:.*:4.0.*:.*$/msx) {
        $GUESS = 'i586-unisys-sysv4';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:UNIX_System_V:4.*:FTX.*$/msx) {
        $GUESS = 'hppa1.1';
        $main_exit_code = system('-s', 'tratus-sysv4') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:.*:.*:FTX.*$/msx) {
        $GUESS = 'i860-stratus-sysv4';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*86:VOS:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-stratus-vos') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:VOS:.*:.*$/msx) {
        $GUESS = 'hppa1.1';
        $main_exit_code = system('-s', 'tratus-vos') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^mc68.*:A/UX:.*:.*$/msx) {
        $GUESS = 'm68k-apple-aux';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^news.*:NEWS-OS:6.*:.*$/msx) {
        $GUESS = 'mips-sony-newsos6';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^R\[34\]000:.*System_V.*:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^R4000:UNIX_SYSV:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^R.*000:UNIX_SV:.*:.*$/msx) {
    if ((-d '/usr/nec')) {
        $GUESS = 'mips-nec-sysv';
        $CHILD_ERROR = 0;
}
    else {
        $GUESS = 'mips-unknown-sysv';
        $CHILD_ERROR = 0;
    }
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^BeBox:BeOS:.*:.*$/msx) {
        $GUESS = 'powerpc-be-beos';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^BeMac:BeOS:.*:.*$/msx) {
        $GUESS = 'powerpc-apple-beos';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^BePC:BeOS:.*:.*$/msx) {
        $GUESS = 'i586-pc-beos';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^BePC:Haiku:.*:.*$/msx) {
        $GUESS = 'i586-pc-haiku';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^x86_64:Haiku:.*:.*$/msx) {
        $GUESS = 'x86_64-unknown-haiku';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^SX-4:SUPER-UX:.*:.*$/msx) {
        $GUESS = 'sx4-nec-superux';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^SX-5:SUPER-UX:.*:.*$/msx) {
        $GUESS = 'sx5-nec-superux';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^SX-6:SUPER-UX:.*:.*$/msx) {
        $GUESS = 'sx6-nec-superux';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^SX-7:SUPER-UX:.*:.*$/msx) {
        $GUESS = 'sx7-nec-superux';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^SX-8:SUPER-UX:.*:.*$/msx) {
        $GUESS = 'sx8-nec-superux';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^SX-8R:SUPER-UX:.*:.*$/msx) {
        $GUESS = 'sx8r-nec-superux';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^SX-ACE:SUPER-UX:.*:.*$/msx) {
        $GUESS = 'sxace-nec-superux';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^Power.*:Rhapsody:.*:.*$/msx) {
        $GUESS = 'powerpc-apple-rhapsody';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:Rhapsody:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-apple-rhapsody', $UNAME_RELEASE) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^arm64:Darwin:.*:.*$/msx) {
        $GUESS = 'aarch64-apple-darwin';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:Darwin:.*:.*$/msx) {
        $UNAME_PROCESSOR = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; join(" ", @__parts) . "\n"; };
    if ($UNAME_PROCESSOR =~ /^unknown$/msx) {
                $UNAME_PROCESSOR = 'powerpc';
    }
    if ((!(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('command', '-v', 'xcode-select') >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    }) && !(    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
!($main_exit_code = system('xcode-select', '--print-path') >> 8;)
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    }))) {
        my $CC_FOR_BUILD;
        my @CC_FOR_BUILD;
        my %CC_FOR_BUILD;
        $CC_FOR_BUILD = 'no_compiler_found';
}
    else {
        set_cc_for_build();
    }
    if ((!StringInterpolation(StringInterpolation { parts: [Variable("CC_FOR_BUILD")] }, None) eq no_compiler_found)) {
if (!(        # Original bash: #! /bin/sh
{
            my $output_204 = q{};
            my $output_printed_204;
            my $pipeline_success_204 = 1;
                        $output_204 = q{};
            $output_204 .= '#ifdef __LP64__' . "\n";
            if ( !($output_204 =~ m{\n\z}msx) ) { $output_204 .= "\n"; }
            $CHILD_ERROR = 0;
            $output_204 .= 'IS_64BIT_ARCH' . "\n";
            if ( !($output_204 =~ m{\n\z}msx) ) { $output_204 .= "\n"; }
            $CHILD_ERROR = 0;
            $output_204 .= '#endif' . "\n";
            if ( !($output_204 =~ m{\n\z}msx) ) { $output_204 .= "\n"; }
            $CHILD_ERROR = 0;

                        $output_204 = q{};
            my @_pcmd_206 = ('sh', '-c', ': "Complex command cannot be converted to shell command"');
            my ($in_205, $out_205);
            my $pid_205 = open3($in_205, $out_205, '>&STDERR', @_pcmd_206);
            close $in_205 or croak 'Close failed: $OS_ERROR';
            $output_204 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_205> };
            close $out_205 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_205, 0;
            my @_pcmd_208 = ('sh', '-c', '$CC_FOR_BUILD -E - 2> /dev/null');
            my ($in_207, $out_207);
            my $pid_207 = open3($in_207, $out_207, '>&STDERR', @_pcmd_208);
            close $in_207 or croak 'Close failed: $OS_ERROR';
            $output_204 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_207> };
            close $out_207 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_207, 0;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_209 = q{};
            my $grep_result_210;
            my @grep_lines_210 = split /\n/msx, $output_204;
            my @grep_filtered_210 = grep { /IS_64BIT_ARCH/msx } @grep_lines_210;
            $grep_result_210 = join "\n", @grep_filtered_210;
            if (!($grep_result_210 =~ m{\n\z}msx || $grep_result_210 eq q{})) {
            $grep_result_210 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_210 > 0 ? 0 : 1;
            $tmp_redirect_209 = $grep_result_210;
            $tmp_redirect_209;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_204; }
            $output_printed_204 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_204 ) { $main_exit_code = 1; }
            })) {
if ($UNAME_PROCESSOR =~ /^i386$/msx) {
                                $UNAME_PROCESSOR = 'x86_64';
            } elsif ($UNAME_PROCESSOR =~ /^powerpc$/msx) {
                                $UNAME_PROCESSOR = 'powerpc64';
            }
        }
if (!(        # Original bash: #! /bin/sh
{
            my $output_211 = q{};
            my $output_printed_211;
            my $pipeline_success_211 = 1;
                        $output_211 = q{};
            $output_211 .= '#ifdef __POWERPC__' . "\n";
            if ( !($output_211 =~ m{\n\z}msx) ) { $output_211 .= "\n"; }
            $CHILD_ERROR = 0;
            $output_211 .= 'IS_PPC' . "\n";
            if ( !($output_211 =~ m{\n\z}msx) ) { $output_211 .= "\n"; }
            $CHILD_ERROR = 0;
            $output_211 .= '#endif' . "\n";
            if ( !($output_211 =~ m{\n\z}msx) ) { $output_211 .= "\n"; }
            $CHILD_ERROR = 0;

                        $output_211 = q{};
            my @_pcmd_213 = ('sh', '-c', ': "Complex command cannot be converted to shell command"');
            my ($in_212, $out_212);
            my $pid_212 = open3($in_212, $out_212, '>&STDERR', @_pcmd_213);
            close $in_212 or croak 'Close failed: $OS_ERROR';
            $output_211 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_212> };
            close $out_212 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_212, 0;
            my @_pcmd_215 = ('sh', '-c', '$CC_FOR_BUILD -E - 2> /dev/null');
            my ($in_214, $out_214);
            my $pid_214 = open3($in_214, $out_214, '>&STDERR', @_pcmd_215);
            close $in_214 or croak 'Close failed: $OS_ERROR';
            $output_211 .= do { local $INPUT_RECORD_SEPARATOR = undef; <$out_214> };
            close $out_214 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_214, 0;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_216 = q{};
            my $grep_result_217;
            my @grep_lines_217 = split /\n/msx, $output_211;
            my @grep_filtered_217 = grep { /IS_PPC/msx } @grep_lines_217;
            $grep_result_217 = join "\n", @grep_filtered_217;
            if (!($grep_result_217 =~ m{\n\z}msx || $grep_result_217 eq q{})) {
            $grep_result_217 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_217 > 0 ? 0 : 1;
            $tmp_redirect_216 = $grep_result_217;
            $tmp_redirect_216;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_211; }
            $output_printed_211 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_211 ) { $main_exit_code = 1; }
            })) {
            $UNAME_PROCESSOR = 'powerpc';
        }
}
    else {
        if (StringInterpolation(StringInterpolation { parts: [Variable("UNAME_PROCESSOR")] }, None) eq i386) {
            $UNAME_PROCESSOR = $UNAME_MACHINE;
        }
    }
        $GUESS = $UNAME_PROCESSOR;
        $main_exit_code = system('-apple-darwin', $UNAME_RELEASE) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:procnto.*:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:QNX:\[0123456789\].*:.*$/msx) {
        $UNAME_PROCESSOR = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; join(" ", @__parts) . "\n"; };
    if (StringInterpolation(StringInterpolation { parts: [Variable("UNAME_PROCESSOR")] }, None) eq x86) {
        $UNAME_PROCESSOR = 'i386';
        $UNAME_MACHINE = 'pc';
    }
        $GUESS = $UNAME_PROCESSOR;
        $main_exit_code = system('-', $UNAME_MACHINE, '-nto-qnx', $UNAME_RELEASE) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:QNX:.*:4.*$/msx) {
        $GUESS = 'i386-pc-qnx';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^NEO-.*:NONSTOP_KERNEL:.*:.*$/msx) {
        $GUESS = 'neo-tandem-nsk';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^NSE-.*:NONSTOP_KERNEL:.*:.*$/msx) {
        $GUESS = 'nse-tandem-nsk';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^NSR-.*:NONSTOP_KERNEL:.*:.*$/msx) {
        $GUESS = 'nsr-tandem-nsk';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^NSV-.*:NONSTOP_KERNEL:.*:.*$/msx) {
        $GUESS = 'nsv-tandem-nsk';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^NSX-.*:NONSTOP_KERNEL:.*:.*$/msx) {
        $GUESS = 'nsx-tandem-nsk';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:NonStop-UX:.*:.*$/msx) {
        $GUESS = 'mips-compaq-nonstopux';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^BS2000:POSIX.*:.*:.*$/msx) {
        $GUESS = 'bs2000-siemens-sysv';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^DS/.*:UNIX_System_V:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-', $UNAME_SYSTEM, q{-}, $UNAME_RELEASE) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:Plan9:.*:.*$/msx) {
    if (StringInterpolation(StringInterpolation { parts: [ParameterExpansion(ParameterExpansion { variable: "cputype", operator: DefaultValue(""), is_mutable: true })] }, None) eq 386) {
        $UNAME_MACHINE = 'i386';
}
    else {
        if ((!StringInterpolation(StringInterpolation { parts: [Literal("x"), ParameterExpansion(ParameterExpansion { variable: "cputype", operator: DefaultValue(""), is_mutable: true })] }, None) eq x)) {
            $UNAME_MACHINE = $cputype;
        }
    }
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-unknown-plan9') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:TOPS-10:.*:.*$/msx) {
        $GUESS = 'pdp10-unknown-tops10';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:TENEX:.*:.*$/msx) {
        $GUESS = 'pdp10-unknown-tenex';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^KS10:TOPS-20:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^KL10:TOPS-20:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^TYPE4:TOPS-20:.*:.*$/msx) {
        $GUESS = 'pdp10-dec-tops20';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^XKL-1:TOPS-20:.*:.*$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^TYPE5:TOPS-20:.*:.*$/msx) {
        $GUESS = 'pdp10-xkl-tops20';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:TOPS-20:.*:.*$/msx) {
        $GUESS = 'pdp10-unknown-tops20';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:ITS:.*:.*$/msx) {
        $GUESS = 'pdp10-unknown-its';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^SEI:.*:.*:SEIUX$/msx) {
        $GUESS = 'mips-sei-seiux';
        $CHILD_ERROR = 0;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:DragonFly:.*:.*$/msx) {
        my $DRAGONFLY_REL;
    my @DRAGONFLY_REL;
    my %DRAGONFLY_REL;
    $DRAGONFLY_REL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_218 = q{};
        my $output_printed_218;
        my $pipeline_success_218 = 1;
        $output_218 .= $UNAME_RELEASE . "\n";
        if ( !($output_218 =~ m{\n\z}msx) ) { $output_218 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_218 = 0; }
        my @sed_lines_218 = split /\n/msx, $output_218;
        my @sed_result_218;
        foreach my $line (@sed_lines_218) {
        chomp $line;
        push @sed_result_218, $line;
        }
        $output_218 = join "\n", @sed_result_218;

        if ( !$pipeline_success_218 ) { $main_exit_code = 1; }
        $output_218 =~ s/\n+\z//msx;
        $output_218;
}; $_pipeline_result; };
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-dragonfly', $DRAGONFLY_REL) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:.*VMS:.*:.*$/msx) {
        $UNAME_MACHINE = do { my @_qx_cmd = ("uname -p 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
    if ($UNAME_MACHINE =~ /^A.*$/msx) {
                $GUESS = 'alpha-dec-vms';
    } elsif ($UNAME_MACHINE =~ /^I.*$/msx) {
                $GUESS = 'ia64-dec-vms';
    } elsif ($UNAME_MACHINE =~ /^V.*$/msx) {
                $GUESS = 'vax-dec-vms';
    }
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:XENIX:.*:SysV$/msx) {
        $GUESS = 'i386-pc-xenix';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*86:skyos:.*:.*$/msx) {
        my $SKYOS_REL;
    my @SKYOS_REL;
    my %SKYOS_REL;
    $SKYOS_REL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_219 = q{};
        my $output_printed_219;
        my $pipeline_success_219 = 1;
        $output_219 .= $UNAME_RELEASE . "\n";
        if ( !($output_219 =~ m{\n\z}msx) ) { $output_219 .= "\n"; }
        $CHILD_ERROR = 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_219 = 0; }
        my @sed_lines_219 = split /\n/msx, $output_219;
        my @sed_result_219;
        foreach my $line (@sed_lines_219) {
        chomp $line;
        push @sed_result_219, $line;
        }
        $output_219 = join "\n", @sed_result_219;

        if ( !$pipeline_success_219 ) { $main_exit_code = 1; }
        $output_219 =~ s/\n+\z//msx;
        $output_219;
}; $_pipeline_result; };
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-pc-skyos', $SKYOS_REL) >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*86:rdos:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-pc-rdos') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^i.*86:Fiwix:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-pc-fiwix') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:AROS:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-unknown-aros') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^x86_64:VMkernel:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('bash', '-unknown-esx') >> 8;
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^amd64:Isilon\ OneFS:.*:.*$/msx) {
        $GUESS = 'x86_64-unknown-onefs';
} elsif ("$UNAME_MACHINE:$UNAME_SYSTEM:$UNAME_RELEASE:$UNAME_VERSION" =~ /^.*:Unleashed:.*:.*$/msx) {
        $GUESS = $UNAME_MACHINE;
        $main_exit_code = system('-unknown-unleashed', $UNAME_RELEASE) >> 8;
}
if ((!StringInterpolation(StringInterpolation { parts: [Literal("x"), Variable("GUESS")] }, None) eq x)) {
    print $GUESS;
if ( !( ($GUESS) =~ m{\n\z}msx ) ) { print "\n"; }
exit $main_exit_code;
}
set_cc_for_build();
open my $fh_cat, '>', "\"$ENV{dummy}.c\"" or croak "Cannot open file: $OS_ERROR\n";
print {$fh_cat} "#ifdef _SEQUENT_
#include <sys/types.h>
#include <sys/utsname.h>
#endif
#if defined(ultrix) || defined(_ultrix) || defined(__ultrix) || defined(__ultrix__)
#if defined (vax) || defined (__vax) || defined (__vax__) || defined(mips) || defined(__mips) || defined(__mips__) || defined(MIPS) || defined(__MIPS__)
#include <signal.h>
#if defined(_SIZE_T_) || defined(SIGLOST)
#include <sys/utsname.h>
#endif
#endif
#endif
main ()
{
#if defined (sony)
#if defined (MIPSEB)
  /* BFD wants \"bsd\" instead of \"newsos\".  Perhaps BFD should be changed,
     I don't know....  */
  printf (\"mips-sony-bsd\\n\"); exit (0);
#else
#include <sys/param.h>
  printf (\"m68k-sony-newsos%s\\n\",
#ifdef NEWSOS4
  \"4\"
#else
  \"\"
#endif
  ); exit (0);
#endif
#endif

#if defined (NeXT)
#if !defined (__ARCHITECTURE__)
#define __ARCHITECTURE__ \"m68k\"
#endif
  int version;
  version=`(hostinfo | sed -n 's/.*NeXT Mach \\([0-9]*\\).*/\\1/p') 2>/dev/null`;
  if (version < 4)
    printf (\"%s-next-nextstep%d\\n\", __ARCHITECTURE__, version);
  else
    printf (\"%s-next-openstep%d\\n\", __ARCHITECTURE__, version);
  exit (0);
#endif

#if defined (MULTIMAX) || defined (n16)
#if defined (UMAXV)
  printf (\"ns32k-encore-sysv\\n\"); exit (0);
#else
#if defined (CMU)
  printf (\"ns32k-encore-mach\\n\"); exit (0);
#else
  printf (\"ns32k-encore-bsd\\n\"); exit (0);
#endif
#endif
#endif

#if defined (__386BSD__)
  printf (\"i386-pc-bsd\\n\"); exit (0);
#endif

#if defined (sequent)
#if defined (i386)
  printf (\"i386-sequent-dynix\\n\"); exit (0);
#endif
#if defined (ns32000)
  printf (\"ns32k-sequent-dynix\\n\"); exit (0);
#endif
#endif

#if defined (_SEQUENT_)
  struct utsname un;

  uname(&un);
  if (strncmp(un.version, \"V2\", 2) == 0) {
    printf (\"i386-sequent-ptx2\\n\"); exit (0);
  }
  if (strncmp(un.version, \"V1\", 2) == 0) { /* XXX is V1 correct? */
    printf (\"i386-sequent-ptx1\\n\"); exit (0);
  }
  printf (\"i386-sequent-ptx\\n\"); exit (0);
#endif

#if defined (vax)
#if !defined (ultrix)
#include <sys/param.h>
#if defined (BSD)
#if BSD == 43
  printf (\"vax-dec-bsd4.3\\n\"); exit (0);
#else
#if BSD == 199006
  printf (\"vax-dec-bsd4.3reno\\n\"); exit (0);
#else
  printf (\"vax-dec-bsd\\n\"); exit (0);
#endif
#endif
#else
  printf (\"vax-dec-bsd\\n\"); exit (0);
#endif
#else
#if defined(_SIZE_T_) || defined(SIGLOST)
  struct utsname un;
  uname (&un);
  printf (\"vax-dec-ultrix%s\\n\", un.release); exit (0);
#else
  printf (\"vax-dec-ultrix\\n\"); exit (0);
#endif
#endif
#endif
#if defined(ultrix) || defined(_ultrix) || defined(__ultrix) || defined(__ultrix__)
#if defined(mips) || defined(__mips) || defined(__mips__) || defined(MIPS) || defined(__MIPS__)
#if defined(_SIZE_T_) || defined(SIGLOST)
  struct utsname *un;
  uname (&un);
  printf (\"mips-dec-ultrix%s\\n\", un.release); exit (0);
#else
  printf (\"mips-dec-ultrix\\n\"); exit (0);
#endif
#endif
#endif

#if defined (alliant) && defined (i860)
  printf (\"i860-alliant-bsd\\n\"); exit (0);
#endif

  exit (1);
}
";
close $fh_cat or croak "Close failed: $OS_ERROR\n";
if (do {
if (do {
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
        $CHILD_ERROR = 0;
    };
} == 0) {
        $SYSTEM_NAME = do {
    my ($in_220, $out_220);
    my $pid_220 = open3($in_220, $out_220, '>&STDERR', "$ENV{dummy}");
    close $in_220 or croak 'Close failed: $OS_ERROR';
    my $result_220 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_220> };
    close $out_220 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_220, 0;
    $result_220
};
}
    $CHILD_ERROR == 0
}) {
            print $SYSTEM_NAME;
if ( !( ($SYSTEM_NAME) =~ m{\n\z}msx ) ) { print "\n"; }
exit $main_exit_code;
}
if (do {
$main_exit_code = system('test', '-d', '/usr/apollo') >> 8;
    $CHILD_ERROR == 0
}) {
            do {
    my $__echo_line = "$ENV{ISP}-apollo-$ENV{SYSTYPE}";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
exit $main_exit_code;
}
do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
    do {
    my $__echo_line = "$PROGRAM_NAME: unable to guess " . "sys" . "tem" . " type";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
};
if ("$UNAME_MACHINE:$UNAME_SYSTEM" =~ /^mips:Linux$/msx or "$UNAME_MACHINE:$UNAME_SYSTEM" =~ /^mips64:Linux$/msx) {
    print "
NOTE: MIPS GNU/Linux systems require a C compiler to fully recognize
the system type. Please install a C compiler and try again.
";
}
print "
This script (version $timestamp), has failed to recognize the
operating system you are using. If your script is old, overwrite *all*
copies of config.guess and config.sub with the latest versions from:

  https://git.savannah.gnu.org/cgit/config.git/plain/config.guess
and
  https://git.savannah.gnu.org/cgit/config.git/plain/config.sub
";
my $our_year;
my @our_year;
my %our_year;
$our_year = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_221 = q{};
    my $output_printed_221;
    my $pipeline_success_221 = 1;
    $output_221 .= $timestamp . "\n";
    if ( !($output_221 =~ m{\n\z}msx) ) { $output_221 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_221 = 0; }
    my @sed_lines_221 = split /\n/msx, $output_221;
    my @sed_result_221;
    foreach my $line (@sed_lines_221) {
    chomp $line;
    push @sed_result_221, $line;
    }
    $output_221 = join "\n", @sed_result_221;

    if ( !$pipeline_success_221 ) { $main_exit_code = 1; }
    $output_221 =~ s/\n+\z//msx;
    $output_221;
}; $_pipeline_result; };
my $thisyear;
my @thisyear;
my %thisyear;
$thisyear = do {
require POSIX; POSIX::strftime('%Y', localtime(time())) . "\n"
};
my $script_age;
my @script_age;
my %script_age;
$script_age = do {
    my ($in_222, $out_222);
    my $pid_222 = open3($in_222, $out_222, '>&STDERR', 'expr', "$thisyear", q{-}, "$our_year");
    close $in_222 or croak 'Close failed: $OS_ERROR';
    my $result_222 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_222> };
    close $out_222 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_222, 0;
    $result_222
};
if ((StringInterpolation(StringInterpolation { parts: [Variable("script_age")] }, None) < $MAGIC_3)) {
print "
If $0 has already been updated, send the following data and any
information you think might be pertinent to config-patches@gnu.org to
provide the necessary information to handle your system.

config.guess timestamp = $timestamp

uname -m = `(uname -m) 2>/dev/null || echo unknown`
uname -r = `(uname -r) 2>/dev/null || echo unknown`
uname -s = `(uname -s) 2>/dev/null || echo unknown`
uname -v = `(uname -v) 2>/dev/null || echo unknown`

/usr/bin/uname -p = `(/usr/bin/uname -p) 2>/dev/null`
/bin/uname -X     = `(/bin/uname -X) 2>/dev/null`

hostinfo               = `(hostinfo) 2>/dev/null`
/bin/universe          = `(/bin/universe) 2>/dev/null`
/usr/bin/arch -k       = `(/usr/bin/arch -k) 2>/dev/null`
/bin/arch              = `(/bin/arch) 2>/dev/null`
/usr/bin/oslevel       = `(/usr/bin/oslevel) 2>/dev/null`
/usr/convex/getsysinfo = `(/usr/convex/getsysinfo) 2>/dev/null`

UNAME_MACHINE = \"$UNAME_MACHINE\"
UNAME_RELEASE = \"$UNAME_RELEASE\"
UNAME_SYSTEM  = \"$UNAME_SYSTEM\"
UNAME_VERSION = \"$UNAME_VERSION\"
";
}
exit 1;

exit $main_exit_code;
