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

my $libext;
my @libext;
my %libext;
$libext = q{a};
my $shrext;
my @shrext;
my %shrext;
$shrext = '.so';
my $host;
my @host;
my %host;
$host = "$_[0]";
my $host_cpu;
my @host_cpu;
my %host_cpu;
$host_cpu = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_0 = q{};
    my $output_printed_0;
    my $pipeline_success_0 = 1;
    $output_0 .= $host . "\n";
    if ( !($output_0 =~ m{\n\z}msx) ) { $output_0 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_0 = 0; }
    my @sed_lines_0 = split /\n/msx, $output_0;
    my @sed_result_0;
    foreach my $line (@sed_lines_0) {
    chomp $line;
    $line =~ s/^\([^-]*\)-\([^-]*\)-\(.*\)$/\1/gmsx;
    push @sed_result_0, $line;
    }
    $output_0 = join "\n", @sed_result_0;

    if ( !$pipeline_success_0 ) { $main_exit_code = 1; }
    $output_0 =~ s/\n+\z//msx;
    $output_0;
}; $_pipeline_result; };
my $host_vendor;
my @host_vendor;
my %host_vendor;
$host_vendor = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_1 = q{};
    my $output_printed_1;
    my $pipeline_success_1 = 1;
    $output_1 .= $host . "\n";
    if ( !($output_1 =~ m{\n\z}msx) ) { $output_1 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_1 = 0; }
    my @sed_lines_1 = split /\n/msx, $output_1;
    my @sed_result_1;
    foreach my $line (@sed_lines_1) {
    chomp $line;
    $line =~ s/^\([^-]*\)-\([^-]*\)-\(.*\)$/\2/gmsx;
    push @sed_result_1, $line;
    }
    $output_1 = join "\n", @sed_result_1;

    if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
    $output_1 =~ s/\n+\z//msx;
    $output_1;
}; $_pipeline_result; };
my $host_os;
my @host_os;
my %host_os;
$host_os = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_2 = q{};
    my $output_printed_2;
    my $pipeline_success_2 = 1;
    $output_2 .= $host . "\n";
    if ( !($output_2 =~ m{\n\z}msx) ) { $output_2 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_2 = 0; }
    my @sed_lines_2 = split /\n/msx, $output_2;
    my @sed_result_2;
    foreach my $line (@sed_lines_2) {
    chomp $line;
    $line =~ s/^\([^-]*\)-\([^-]*\)-\(.*\)$/\3/gmsx;
    push @sed_result_2, $line;
    }
    $output_2 = join "\n", @sed_result_2;

    if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
    $output_2 =~ s/\n+\z//msx;
    $output_2;
}; $_pipeline_result; };
my $cc_temp;
for my $cc_temp ($CC) {
if ($cc_temp =~ /^compile$/msx or $cc_temp =~ /^.*\[\\/\]compile$/msx or $cc_temp =~ /^ccache$/msx or $cc_temp =~ /^.*\[\\/\]ccache$/msx) {
    } elsif ($cc_temp =~ /^distcc$/msx or $cc_temp =~ /^.*\[\\/\]distcc$/msx or $cc_temp =~ /^purify$/msx or $cc_temp =~ /^.*\[\\/\]purify$/msx) {
    } elsif ($cc_temp =~ /^\-.*$/msx) {
    } elsif (1) {
        last;    }
}
my $cc_basename;
my @cc_basename;
my %cc_basename;
$cc_basename = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_3 = q{};
    my $output_printed_3;
    my $pipeline_success_3 = 1;
    $output_3 .= $cc_temp . "\n";
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
my $wl;
my @wl;
my %wl;
$wl = q{};
if (StringInterpolation(StringInterpolation { parts: [Variable("GCC")] }, None) eq yes) {
    $wl = '-Wl,';
}
else {
if ("$host_os" =~ /^aix.*$/msx) {
                $wl = '-Wl,';
    } elsif ("$host_os" =~ /^mingw.*$/msx or "$host_os" =~ /^cygwin.*$/msx or "$host_os" =~ /^pw32.*$/msx or "$host_os" =~ /^os2.*$/msx or "$host_os" =~ /^cegcc.*$/msx) {
    } elsif ("$host_os" =~ /^hpux9.*$/msx or "$host_os" =~ /^hpux10.*$/msx or "$host_os" =~ /^hpux11.*$/msx) {
                $wl = '-Wl,';
    } elsif ("$host_os" =~ /^irix5.*$/msx or "$host_os" =~ /^irix6.*$/msx or "$host_os" =~ /^nonstopux.*$/msx) {
                $wl = '-Wl,';
    } elsif ("$host_os" =~ /^linux.*$/msx or "$host_os" =~ /^k.*bsd.*-gnu$/msx or "$host_os" =~ /^kopensolaris.*-gnu$/msx) {
        if ($cc_basename =~ /^ecc.*$/msx) {
                        $wl = '-Wl,';
        } elsif ($cc_basename =~ /^icc.*$/msx or $cc_basename =~ /^ifort.*$/msx) {
                        $wl = '-Wl,';
        } elsif ($cc_basename =~ /^lf95.*$/msx) {
                        $wl = '-Wl,';
        } elsif ($cc_basename =~ /^nagfor.*$/msx) {
                        $wl = '-Wl,-Wl,,';
        } elsif ($cc_basename =~ /^pgcc.*$/msx or $cc_basename =~ /^pgf77.*$/msx or $cc_basename =~ /^pgf90.*$/msx or $cc_basename =~ /^pgf95.*$/msx or $cc_basename =~ /^pgfortran.*$/msx) {
                        $wl = '-Wl,';
        } elsif ($cc_basename =~ /^ccc.*$/msx) {
                        $wl = '-Wl,';
        } elsif ($cc_basename =~ /^xl.*$/msx or $cc_basename =~ /^bgxl.*$/msx or $cc_basename =~ /^bgf.*$/msx or $cc_basename =~ /^mpixl.*$/msx) {
                        $wl = '-Wl,';
        } elsif ($cc_basename =~ /^como$/msx) {
                        $wl = '-lopt=';
        } elsif (1) {
            if (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_4 = q{};
                my $output_printed_4;
                my $pipeline_success_4 = 1;
                my ($in_5, $out_5);
                my $pid_5 = open3($in_5, $out_5, '>&STDERR', 'unknown_command', '-V');
                close $in_5 or croak 'Close failed: $OS_ERROR';
                $output_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
                close $out_5 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_5, 0;
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
}; $_pipeline_result; } =~ /^.*Sun\ F.*$/msx or do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_6 = q{};
                my $output_printed_6;
                my $pipeline_success_6 = 1;
                my ($in_7, $out_7);
                my $pid_7 = open3($in_7, $out_7, '>&STDERR', 'unknown_command', '-V');
                close $in_7 or croak 'Close failed: $OS_ERROR';
                $output_6 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
                close $out_7 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_7, 0;
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
}; $_pipeline_result; } =~ /^.*Sun.*Fortran.*$/msx) {
                                $wl = q{};
            } elsif (do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_8 = q{};
                my $output_printed_8;
                my $pipeline_success_8 = 1;
                my ($in_9, $out_9);
                my $pid_9 = open3($in_9, $out_9, '>&STDERR', 'unknown_command', '-V');
                close $in_9 or croak 'Close failed: $OS_ERROR';
                $output_8 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_9> };
                close $out_9 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_9, 0;
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
}; $_pipeline_result; } =~ /^.*Sun\ C.*$/msx) {
                                $wl = '-Wl,';
            }
        }
    } elsif ("$host_os" =~ /^newsos6$/msx) {
    } elsif ("$host_os" =~ /^.*nto.*$/msx or "$host_os" =~ /^.*qnx.*$/msx) {
    } elsif ("$host_os" =~ /^osf3.*$/msx or "$host_os" =~ /^osf4.*$/msx or "$host_os" =~ /^osf5.*$/msx) {
                $wl = '-Wl,';
    } elsif ("$host_os" =~ /^rdos.*$/msx) {
    } elsif ("$host_os" =~ /^solaris.*$/msx) {
        if ($cc_basename =~ /^f77.*$/msx or $cc_basename =~ /^f90.*$/msx or $cc_basename =~ /^f95.*$/msx or $cc_basename =~ /^sunf77.*$/msx or $cc_basename =~ /^sunf90.*$/msx or $cc_basename =~ /^sunf95.*$/msx) {
                        $wl = '-Qoption ld ';
        } elsif (1) {
                        $wl = '-Wl,';
        }
    } elsif ("$host_os" =~ /^sunos4.*$/msx) {
                $wl = '-Qoption ld ';
    } elsif ("$host_os" =~ /^sysv4$/msx or "$host_os" =~ /^sysv4.2uw2.*$/msx or "$host_os" =~ /^sysv4.3.*$/msx) {
                $wl = '-Wl,';
    } elsif ("$host_os" =~ /^sysv4.*MP.*$/msx) {
    } elsif ("$host_os" =~ /^sysv5.*$/msx or "$host_os" =~ /^unixware.*$/msx or "$host_os" =~ /^sco3.2v5.*$/msx or "$host_os" =~ /^sco5v6.*$/msx or "$host_os" =~ /^OpenUNIX.*$/msx) {
                $wl = '-Wl,';
    } elsif ("$host_os" =~ /^unicos.*$/msx) {
                $wl = '-Wl,';
    } elsif ("$host_os" =~ /^uts4.*$/msx) {
    }
}
my $hardcode_libdir_flag_spec;
my @hardcode_libdir_flag_spec;
my %hardcode_libdir_flag_spec;
$hardcode_libdir_flag_spec = q{};
my $hardcode_libdir_separator;
my @hardcode_libdir_separator;
my %hardcode_libdir_separator;
$hardcode_libdir_separator = q{};
my $hardcode_direct;
my @hardcode_direct;
my %hardcode_direct;
$hardcode_direct = 'no';
my $hardcode_minus_L;
my @hardcode_minus_L;
my %hardcode_minus_L;
$hardcode_minus_L = 'no';
if ("$host_os" =~ /^cygwin.*$/msx or "$host_os" =~ /^mingw.*$/msx or "$host_os" =~ /^pw32.*$/msx or "$host_os" =~ /^cegcc.*$/msx) {
    if ((!StringInterpolation(StringInterpolation { parts: [Variable("GCC")] }, None) eq yes)) {
        my $with_gnu_ld;
        my @with_gnu_ld;
        my %with_gnu_ld;
        $with_gnu_ld = 'no';
    }
} elsif ("$host_os" =~ /^interix.*$/msx) {
        $with_gnu_ld = 'yes';
} elsif ("$host_os" =~ /^openbsd.*$/msx) {
        $with_gnu_ld = 'no';
}
my $ld_shlibs;
my @ld_shlibs;
my %ld_shlibs;
$ld_shlibs = 'yes';
if (StringInterpolation(StringInterpolation { parts: [Variable("with_gnu_ld")] }, None) eq yes) {
    $hardcode_libdir_flag_spec = '${wl}-rpath ${wl}$libdir';
if ("$host_os" =~ /^aix\[3-9\].*$/msx) {
        if ((!StringInterpolation(StringInterpolation { parts: [Variable("host_cpu")] }, None) eq ia64)) {
            $ld_shlibs = 'no';
        }
    } elsif ("$host_os" =~ /^amigaos.*$/msx) {
        if ("$host_cpu" =~ /^powerpc$/msx) {
        } elsif ("$host_cpu" =~ /^m68k$/msx) {
                        $hardcode_libdir_flag_spec = '-L$libdir';
                        $hardcode_minus_L = 'yes';
        }
    } elsif ("$host_os" =~ /^beos.*$/msx) {
        if (!(        # Original bash: $LD --help 2>&1 | grep ': supported targets:.* elf' > /dev/null;
{
            my $output_10 = q{};
            my $output_printed_10;
            my $pipeline_success_10 = 1;
                        $output = q{};
                        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_11 = q{};

my $cmd_14 = 'unknown_command';
my ($in_13, $out_13);
my $pid_13 = open3($in_13, $out_13, '>&STDERR', $cmd_14, '--help');
print {$in_13} $output_10;
close $in_13 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_11 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_13> };
close $out_13 or croak 'Close failed: $OS_ERROR';
waitpid $pid_13, 0;
$tmp_redirect_11;
            };
            $output_10 = $output;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_15 = q{};
            my $grep_result_16;
            my @grep_lines_16 = split /\n/msx, $output_10;
            my @grep_filtered_16 = grep { /:\ supported\ targets:.*\ elf/msx } @grep_lines_16;
            $grep_result_16 = join "\n", @grep_filtered_16;
            if (!($grep_result_16 =~ m{\n\z}msx || $grep_result_16 eq q{})) {
            $grep_result_16 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_16 > 0 ? 0 : 1;
            $tmp_redirect_15 = $grep_result_16;
            $tmp_redirect_15;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_10; }
            $output_printed_10 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_10 ) { $main_exit_code = 1; }
            })) {
            $main_exit_code = system('bash', ':') >> 8;
}
        else {
            $ld_shlibs = 'no';
        }
    } elsif ("$host_os" =~ /^cygwin.*$/msx or "$host_os" =~ /^mingw.*$/msx or "$host_os" =~ /^pw32.*$/msx or "$host_os" =~ /^cegcc.*$/msx) {
                $hardcode_libdir_flag_spec = '-L$libdir';
        if (!(        # Original bash: $LD --help 2>&1 | grep 'auto-import' > /dev/null;
{
            my $output_17 = q{};
            my $output_printed_17;
            my $pipeline_success_17 = 1;
                        $output = q{};
                        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_18 = q{};

my $cmd_21 = 'unknown_command';
my ($in_20, $out_20);
my $pid_20 = open3($in_20, $out_20, '>&STDERR', $cmd_21, '--help');
print {$in_20} $output_17;
close $in_20 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_18 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> };
close $out_20 or croak 'Close failed: $OS_ERROR';
waitpid $pid_20, 0;
$tmp_redirect_18;
            };
            $output_17 = $output;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_22 = q{};
            my $grep_result_23;
            my @grep_lines_23 = split /\n/msx, $output_17;
            my @grep_filtered_23 = grep { /auto-import/msx } @grep_lines_23;
            $grep_result_23 = join "\n", @grep_filtered_23;
            if (!($grep_result_23 =~ m{\n\z}msx || $grep_result_23 eq q{})) {
            $grep_result_23 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_23 > 0 ? 0 : 1;
            $tmp_redirect_22 = $grep_result_23;
            $tmp_redirect_22;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_17; }
            $output_printed_17 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_17 ) { $main_exit_code = 1; }
            })) {
            $main_exit_code = system('bash', ':') >> 8;
}
        else {
            $ld_shlibs = 'no';
        }
    } elsif ("$host_os" =~ /^haiku.*$/msx) {
    } elsif ("$host_os" =~ /^interix\[3-9\].*$/msx) {
                $hardcode_direct = 'no';
                $hardcode_libdir_flag_spec = '${wl}-rpath,$libdir';
    } elsif ("$host_os" =~ /^gnu.*$/msx or "$host_os" =~ /^linux.*$/msx or "$host_os" =~ /^tpf.*$/msx or "$host_os" =~ /^k.*bsd.*-gnu$/msx or "$host_os" =~ /^kopensolaris.*-gnu$/msx) {
        if (!(        # Original bash: $LD --help 2>&1 | grep ': supported targets:.* elf' > /dev/null;
{
            my $output_24 = q{};
            my $output_printed_24;
            my $pipeline_success_24 = 1;
                        $output = q{};
                        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_25 = q{};

my $cmd_28 = 'unknown_command';
my ($in_27, $out_27);
my $pid_27 = open3($in_27, $out_27, '>&STDERR', $cmd_28, '--help');
print {$in_27} $output_24;
close $in_27 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_25 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_27> };
close $out_27 or croak 'Close failed: $OS_ERROR';
waitpid $pid_27, 0;
$tmp_redirect_25;
            };
            $output_24 = $output;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_29 = q{};
            my $grep_result_30;
            my @grep_lines_30 = split /\n/msx, $output_24;
            my @grep_filtered_30 = grep { /:\ supported\ targets:.*\ elf/msx } @grep_lines_30;
            $grep_result_30 = join "\n", @grep_filtered_30;
            if (!($grep_result_30 =~ m{\n\z}msx || $grep_result_30 eq q{})) {
            $grep_result_30 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_30 > 0 ? 0 : 1;
            $tmp_redirect_29 = $grep_result_30;
            $tmp_redirect_29;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_24; }
            $output_printed_24 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_24 ) { $main_exit_code = 1; }
            })) {
            $main_exit_code = system('bash', ':') >> 8;
}
        else {
            $ld_shlibs = 'no';
        }
    } elsif ("$host_os" =~ /^netbsd.*$/msx) {
    } elsif ("$host_os" =~ /^solaris.*$/msx) {
        if (!(        # Original bash: $LD -v 2>&1 | grep 'BFD 2\.8' > /dev/null;
{
            my $output_31 = q{};
            my $output_printed_31;
            my $pipeline_success_31 = 1;
                        $output = q{};
                        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_32 = q{};

my $cmd_35 = 'unknown_command';
my ($in_34, $out_34);
my $pid_34 = open3($in_34, $out_34, '>&STDERR', $cmd_35, '-v');
print {$in_34} $output_31;
close $in_34 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_32 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_34> };
close $out_34 or croak 'Close failed: $OS_ERROR';
waitpid $pid_34, 0;
$tmp_redirect_32;
            };
            $output_31 = $output;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_36 = q{};
            my $grep_result_37;
            my @grep_lines_37 = split /\n/msx, $output_31;
            my @grep_filtered_37 = grep { /BFD\ 2[.]8/msx } @grep_lines_37;
            $grep_result_37 = join "\n", @grep_filtered_37;
            if (!($grep_result_37 =~ m{\n\z}msx || $grep_result_37 eq q{})) {
            $grep_result_37 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_37 > 0 ? 0 : 1;
            $tmp_redirect_36 = $grep_result_37;
            $tmp_redirect_36;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_31; }
            $output_printed_31 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_31 ) { $main_exit_code = 1; }
            })) {
            $ld_shlibs = 'no';
}
        else {
            if (!(            # Original bash: $LD --help 2>&1 | grep ': supported targets:.* elf' > /dev/null;
{
                my $output_38 = q{};
                my $output_printed_38;
                my $pipeline_success_38 = 1;
                                $output = q{};
                                do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_39 = q{};

my $cmd_42 = 'unknown_command';
my ($in_41, $out_41);
my $pid_41 = open3($in_41, $out_41, '>&STDERR', $cmd_42, '--help');
print {$in_41} $output_38;
close $in_41 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_39 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_41> };
close $out_41 or croak 'Close failed: $OS_ERROR';
waitpid $pid_41, 0;
$tmp_redirect_39;
                };
                $output_38 = $output;

                                do {
                open my $original_stdout, '>&', STDOUT
                or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
                or die "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
                my $tmp_redirect_43 = q{};
                my $grep_result_44;
                my @grep_lines_44 = split /\n/msx, $output_38;
                my @grep_filtered_44 = grep { /:\ supported\ targets:.*\ elf/msx } @grep_lines_44;
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
                $main_exit_code = system('bash', ':') >> 8;
}
            else {
                $ld_shlibs = 'no';
            }
        }
    } elsif ("$host_os" =~ /^sysv5.*$/msx or "$host_os" =~ /^sco3.2v5.*$/msx or "$host_os" =~ /^sco5v6.*$/msx or "$host_os" =~ /^unixware.*$/msx or "$host_os" =~ /^OpenUNIX.*$/msx) {
        if (do { my @_qx_cmd = ("$LD -v 2>&1"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; } =~ /^.*\ \[01\]..*$/msx or do { my @_qx_cmd = ("$LD -v 2>&1"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; } =~ /^.*\ 2.\[0-9\]..*$/msx or do { my @_qx_cmd = ("$LD -v 2>&1"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; } =~ /^.*\ 2.1\[0-5\]..*$/msx) {
                        $ld_shlibs = 'no';
        } elsif (1) {
            if (!(            # Original bash: $LD --help 2>&1 | grep ': supported targets:.* elf' > /dev/null;
{
                my $output_45 = q{};
                my $output_printed_45;
                my $pipeline_success_45 = 1;
                                $output = q{};
                                do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_46 = q{};

my $cmd_49 = 'unknown_command';
my ($in_48, $out_48);
my $pid_48 = open3($in_48, $out_48, '>&STDERR', $cmd_49, '--help');
print {$in_48} $output_45;
close $in_48 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_46 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_48> };
close $out_48 or croak 'Close failed: $OS_ERROR';
waitpid $pid_48, 0;
$tmp_redirect_46;
                };
                $output_45 = $output;

                                do {
                open my $original_stdout, '>&', STDOUT
                or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>', '/dev/null'
                or die "Cannot open file: $OS_ERROR\n";
                my $tmp = do {
                my $tmp_redirect_50 = q{};
                my $grep_result_51;
                my @grep_lines_51 = split /\n/msx, $output_45;
                my @grep_filtered_51 = grep { /:\ supported\ targets:.*\ elf/msx } @grep_lines_51;
                $grep_result_51 = join "\n", @grep_filtered_51;
                if (!($grep_result_51 =~ m{\n\z}msx || $grep_result_51 eq q{})) {
                $grep_result_51 .= "\n";
                }
                $CHILD_ERROR = scalar @grep_filtered_51 > 0 ? 0 : 1;
                $tmp_redirect_50 = $grep_result_51;
                $tmp_redirect_50;
                };
                print $tmp;
                if ($tmp eq q{}) { print $output_45; }
                $output_printed_45 = 1;
                open STDOUT, '>&', $original_stdout
                or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
                or die "Close failed: $OS_ERROR\n";
                };
                if ( !$pipeline_success_45 ) { $main_exit_code = 1; }
                })) {
                $hardcode_libdir_flag_spec = do {
    my $left_result_52 = do {
    my ($in_53, $out_53);
    my $pid_53 = open3($in_53, $out_53, '>&STDERR', 'test', '-z', "$ENV{SCOABSPATH}");
    close $in_53 or croak 'Close failed: $OS_ERROR';
    my $result_53 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_53> };
    close $out_53 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_53, 0;
    $result_53
};
    if ( $CHILD_ERROR == 0 ) {
        my $right_result_52 = do { ($wl . q{ } . '-r' . q{ } . 'path,' . q{ } . $libdir) };
        $left_result_52 . $right_result_52;
    } else {
        q{};
    }
};
}
            else {
                $ld_shlibs = 'no';
            }
        }
    } elsif ("$host_os" =~ /^sunos4.*$/msx) {
                $hardcode_direct = 'yes';
    } elsif (1) {
        if (!(        # Original bash: $LD --help 2>&1 | grep ': supported targets:.* elf' > /dev/null;
{
            my $output_54 = q{};
            my $output_printed_54;
            my $pipeline_success_54 = 1;
                        $output = q{};
                        do {
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
my $tmp_redirect_55 = q{};

my $cmd_58 = 'unknown_command';
my ($in_57, $out_57);
my $pid_57 = open3($in_57, $out_57, '>&STDERR', $cmd_58, '--help');
print {$in_57} $output_54;
close $in_57 or croak 'Close failed: $OS_ERROR';
$tmp_redirect_55 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_57> };
close $out_57 or croak 'Close failed: $OS_ERROR';
waitpid $pid_57, 0;
$tmp_redirect_55;
            };
            $output_54 = $output;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
            or die "Cannot open file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_59 = q{};
            my $grep_result_60;
            my @grep_lines_60 = split /\n/msx, $output_54;
            my @grep_filtered_60 = grep { /:\ supported\ targets:.*\ elf/msx } @grep_lines_60;
            $grep_result_60 = join "\n", @grep_filtered_60;
            if (!($grep_result_60 =~ m{\n\z}msx || $grep_result_60 eq q{})) {
            $grep_result_60 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_60 > 0 ? 0 : 1;
            $tmp_redirect_59 = $grep_result_60;
            $tmp_redirect_59;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_54; }
            $output_printed_54 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_54 ) { $main_exit_code = 1; }
            })) {
            $main_exit_code = system('bash', ':') >> 8;
}
        else {
            $ld_shlibs = 'no';
        }
    }
if (StringInterpolation(StringInterpolation { parts: [Variable("ld_shlibs")] }, None) eq no) {
        $hardcode_libdir_flag_spec = q{};
    }
}
else {
if ("$host_os" =~ /^aix3.*$/msx) {
                $hardcode_minus_L = 'yes';
        if (StringInterpolation(StringInterpolation { parts: [Variable("GCC")] }, None) eq yes) {
            $hardcode_direct = 'unsupported';
        }
    } elsif ("$host_os" =~ /^aix\[4-9\].*$/msx) {
        if (StringInterpolation(StringInterpolation { parts: [Variable("host_cpu")] }, None) eq ia64) {
            my $aix_use_runtimelinking;
            my @aix_use_runtimelinking;
            my %aix_use_runtimelinking;
            $aix_use_runtimelinking = 'no';
}
        else {
            $aix_use_runtimelinking = 'no';
if ($host_os =~ /^aix4.\[23\]$/msx or $host_os =~ /^aix4.\[23\]..*$/msx or $host_os =~ /^aix\[5-9\].*$/msx) {
                                my $ld_flag;
                for my $ld_flag ($LDFLAGS) {
if (!(                    do {
                        local %ENV = %ENV;
                        my $aix_use_runtimelinking = $aix_use_runtimelinking;
                        my $hardcode_minus_L = $hardcode_minus_L;
                        my $hardcode_libdir_flag_spec = $hardcode_libdir_flag_spec;
                        my $with_gnu_ld = $with_gnu_ld;
                        my $ld_flag = $ld_flag;
                        my $host = $host;
                        my $hardcode_libdir_separator = $hardcode_libdir_separator;
                        my $libext = $libext;
                        my $cc_temp = $cc_temp;
                        my $cc_basename = $cc_basename;
                        my $host_os = $host_os;
                        my $hardcode_direct = $hardcode_direct;
                        my $host_vendor = $host_vendor;
                        my $wl = $wl;
                        my $shrext = $shrext;
                        my $host_cpu = $host_cpu;
                        my $ld_shlibs = $ld_shlibs;
                                                $main_exit_code = system('test', $ld_flag, q{=}, "-brtl") >> 8;
                        if ($CHILD_ERROR != 0) {
                                                        $main_exit_code = system('test', $ld_flag, q{=}, "-Wl,-brtl") >> 8;
                        }
                        q{};
                    })) {
                        $aix_use_runtimelinking = 'yes';
last;
                    }
                }
            }
        }
                $hardcode_direct = 'yes';
                $hardcode_libdir_separator = q{:};
        if (StringInterpolation(StringInterpolation { parts: [Variable("GCC")] }, None) eq yes) {
if ($host_os =~ /^aix4.\[012\]$/msx or $host_os =~ /^aix4.\[012\]..*$/msx) {
                                my $collect2name;
                my @collect2name;
                my %collect2name;
                $collect2name = do {
    my ($in_61, $out_61);
    my $pid_61 = open3($in_61, $out_61, '>&STDERR', $CC, '-p', 'rint-prog-name', q{=}, 'collect2');
    close $in_61 or croak 'Close failed: $OS_ERROR';
    my $result_61 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_61> };
    close $out_61 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_61, 0;
    $result_61
};
                if ((!(                $main_exit_code = system('test', '-f', "$collect2name") >> 8) && !({
                    my $output_62 = q{};
                    my $output_printed_62;
                    my $pipeline_success_62 = 1;
                                        my $input_data = $;
                    my @result;
                    while ($input_data =~ /([\x20-\x7E]{4,})/g) {
                    push @result, $1;
                    }
                    my $line = join "\n", @result;
                    if ($line ne q{} && !($line =~ m{\n\z}msx)) { $line .= "\n"; }
                    $output_62 = $line;

                                        do {
                    open my $original_stdout, '>&', STDOUT
                    or die "Cannot save STDOUT: $OS_ERROR\n";
                    open STDOUT, '>', '/dev/null'
                    or die "Cannot open file: $OS_ERROR\n";
                    my $tmp = do {
                    my $tmp_redirect_63 = q{};
                    my $grep_result_64;
                    my @grep_lines_64 = split /\n/msx, $output_62;
                    my @grep_filtered_64 = grep { /resolve_lib_name/msx } @grep_lines_64;
                    $grep_result_64 = join "\n", @grep_filtered_64;
                    if (!($grep_result_64 =~ m{\n\z}msx || $grep_result_64 eq q{})) {
                    $grep_result_64 .= "\n";
                    }
                    $CHILD_ERROR = scalar @grep_filtered_64 > 0 ? 0 : 1;
                    $tmp_redirect_63 = $grep_result_64;
                    $tmp_redirect_63;
                    };
                    print $tmp;
                    if ($tmp eq q{}) { print $output_62; }
                    $output_printed_62 = 1;
                    open STDOUT, '>&', $original_stdout
                    or die "Cannot restore STDOUT: $OS_ERROR\n";
                    close $original_stdout
                    or die "Close failed: $OS_ERROR\n";
                    };
                    if ( !$pipeline_success_62 ) { $main_exit_code = 1; }
                    }))) {
                    $main_exit_code = system('bash', ':') >> 8;
}
                else {
                    $hardcode_direct = 'unsupported';
                    $hardcode_minus_L = 'yes';
                    $hardcode_libdir_flag_spec = '-L$libdir';
                    $hardcode_libdir_separator = q{};
                }
            }
        }
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', 'conftest.c'
      or die "Cannot open file: $OS_ERROR\n";
            print 'int main () { return 0; }' . "\n";
            $CHILD_ERROR = 0;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
                $CHILD_ERROR = 0;
                my $aix_libpath;
        my @aix_libpath;
        my %aix_libpath;
        $aix_libpath = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_65 = q{};
            my $output_printed_65;
            my $pipeline_success_65 = 1;
            my ($in_66, $out_66);
            my $pid_66 = open3($in_66, $out_66, '>&STDERR', 'dump', '-H', 'conftest');
            close $in_66 or croak 'Close failed: $OS_ERROR';
            $output_65 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_66> };
            close $out_66 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_66, 0;
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
        if (StringInterpolation(StringInterpolation { parts: [Variable("aix_libpath")] }, None) eq q{}) {
            $aix_libpath = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_67 = q{};
                my $output_printed_67;
                my $pipeline_success_67 = 1;
                my ($in_68, $out_68);
                my $pid_68 = open3($in_68, $out_68, '>&STDERR', 'dump', '-HX64', 'conftest');
                close $in_68 or croak 'Close failed: $OS_ERROR';
                $output_67 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_68> };
                close $out_68 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_68, 0;
                my @sed_lines_67 = split /\n/msx, $output_67;
                my @sed_result_67;
                foreach my $line (@sed_lines_67) {
                chomp $line;
                push @sed_result_67, $line;
                }
                $output_67 = join "\n", @sed_result_67;
                if ( !$pipeline_success_67 ) { $main_exit_code = 1; }
                $output_67 =~ s/\n+\z//msx;
                $output_67;
}; $_pipeline_result; };
        }
        if (StringInterpolation(StringInterpolation { parts: [Variable("aix_libpath")] }, None) eq q{}) {
            $aix_libpath = "/usr/lib:/lib";
        }
        if ( -e "conftest.c" ) {
            if ( -d "conftest.c" ) {
                carp "rm: carping: ", "conftest.c",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "conftest.c" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "conftest.c",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
if ( -e "conftest" ) {
            if ( -d "conftest" ) {
                carp "rm: carping: ", "conftest",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "conftest" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "conftest",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
        if (StringInterpolation(StringInterpolation { parts: [Variable("aix_use_runtimelinking")] }, None) eq yes) {
            $hardcode_libdir_flag_spec = '${wl}-blibpath:$libdir:';
}
        else {
if (StringInterpolation(StringInterpolation { parts: [Variable("host_cpu")] }, None) eq ia64) {
                $hardcode_libdir_flag_spec = '${wl}-R $libdir:/usr/lib:/lib';
}
            else {
                $hardcode_libdir_flag_spec = '${wl}-blibpath:$libdir:';
            }
        }
    } elsif ("$host_os" =~ /^amigaos.*$/msx) {
        if ("$host_cpu" =~ /^powerpc$/msx) {
        } elsif ("$host_cpu" =~ /^m68k$/msx) {
                        $hardcode_libdir_flag_spec = '-L$libdir';
                        $hardcode_minus_L = 'yes';
        }
    } elsif ("$host_os" =~ /^bsdi\[45\].*$/msx) {
    } elsif ("$host_os" =~ /^cygwin.*$/msx or "$host_os" =~ /^mingw.*$/msx or "$host_os" =~ /^pw32.*$/msx or "$host_os" =~ /^cegcc.*$/msx) {
                $hardcode_libdir_flag_spec = q{ };
                $libext = 'lib';
    } elsif ("$host_os" =~ /^darwin.*$/msx or "$host_os" =~ /^rhapsody.*$/msx) {
                $hardcode_direct = 'no';
        if (!(if ($cc_basename =~ /^ifort.*$/msx) {
                1;
            } elsif (1) {
                                $main_exit_code = system('test', "$ENV{GCC}", q{=}, 'yes') >> 8;
            })) {
            $main_exit_code = system('bash', ':') >> 8;
}
        else {
            $ld_shlibs = 'no';
        }
    } elsif ("$host_os" =~ /^dgux.*$/msx) {
                $hardcode_libdir_flag_spec = '-L$libdir';
    } elsif ("$host_os" =~ /^freebsd2.\[01\].*$/msx) {
                $hardcode_direct = 'yes';
                $hardcode_minus_L = 'yes';
    } elsif ("$host_os" =~ /^freebsd.*$/msx or "$host_os" =~ /^dragonfly.*$/msx) {
                $hardcode_libdir_flag_spec = '-R$libdir';
                $hardcode_direct = 'yes';
    } elsif ("$host_os" =~ /^hpux9.*$/msx) {
                $hardcode_libdir_flag_spec = '${wl}+b ${wl}$libdir';
                $hardcode_libdir_separator = q{:};
                $hardcode_direct = 'yes';
                $hardcode_minus_L = 'yes';
    } elsif ("$host_os" =~ /^hpux10.*$/msx) {
        if (StringInterpolation(StringInterpolation { parts: [Variable("with_gnu_ld")] }, None) eq no) {
            $hardcode_libdir_flag_spec = '${wl}+b ${wl}$libdir';
            $hardcode_libdir_separator = q{:};
            $hardcode_direct = 'yes';
            $hardcode_minus_L = 'yes';
        }
    } elsif ("$host_os" =~ /^hpux11.*$/msx) {
        if (StringInterpolation(StringInterpolation { parts: [Variable("with_gnu_ld")] }, None) eq no) {
            $hardcode_libdir_flag_spec = '${wl}+b ${wl}$libdir';
            $hardcode_libdir_separator = q{:};
if ($host_cpu =~ /^hppa.*64.*$/msx or $host_cpu =~ /^ia64.*$/msx) {
                                $hardcode_direct = 'no';
            } elsif (1) {
                                $hardcode_direct = 'yes';
                                $hardcode_minus_L = 'yes';
            }
        }
    } elsif ("$host_os" =~ /^irix5.*$/msx or "$host_os" =~ /^irix6.*$/msx or "$host_os" =~ /^nonstopux.*$/msx) {
                $hardcode_libdir_flag_spec = '${wl}-rpath ${wl}$libdir';
                $hardcode_libdir_separator = q{:};
    } elsif ("$host_os" =~ /^netbsd.*$/msx) {
                $hardcode_libdir_flag_spec = '-R$libdir';
                $hardcode_direct = 'yes';
    } elsif ("$host_os" =~ /^newsos6$/msx) {
                $hardcode_direct = 'yes';
                $hardcode_libdir_flag_spec = '${wl}-rpath ${wl}$libdir';
                $hardcode_libdir_separator = q{:};
    } elsif ("$host_os" =~ /^.*nto.*$/msx or "$host_os" =~ /^.*qnx.*$/msx) {
    } elsif ("$host_os" =~ /^openbsd.*$/msx) {
        if ((-f '/usr/libexec/ld.so')) {
            $hardcode_direct = 'yes';
if ((!(            $main_exit_code = system('test', '-z', (do { my $_chomp_temp = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                my $output_70 = q{};
                my $output_printed_70;
                my $pipeline_success_70 = 1;
                $output_70 .= '__ELF__' . "\n";
                if ( !($output_70 =~ m{\n\z}msx) ) { $output_70 .= "\n"; }
                $CHILD_ERROR = 0;
                if ($CHILD_ERROR != 0) { $pipeline_success_70 = 0; }

                my $cmd_72 = 'unknown_command';
                my ($in_71, $out_71);
                my $pid_71 = open3($in_71, $out_71, '>&STDERR', $cmd_72, '-E', q{-});
                print {$in_71} $output_70;
                close $in_71 or croak 'Close failed: $OS_ERROR';
                $output_70 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_71> };
                close $out_71 or croak 'Close failed: $OS_ERROR';
                waitpid $pid_71, 0;
                my $grep_result_70_2;
                my @grep_lines_70_2 = split /\n/msx, $output_70;
                my @grep_filtered_70_2 = grep { /__ELF__/msx } @grep_lines_70_2;
                $grep_result_70_2 = join "\n", @grep_filtered_70_2;
                                if (!($grep_result_70_2 =~ m{\n\z}msx || $grep_result_70_2 eq q{})) {
                                    $grep_result_70_2 .= "\n";
                                }
                $CHILD_ERROR = scalar @grep_filtered_70_2 > 0 ? 0 : 1;
                $output_70 = $grep_result_70_2;
                if ((scalar @grep_filtered_70_2) == 0) {
                    $pipeline_success_70 = 0;
                }
                if ( !$pipeline_success_70 ) { $main_exit_code = 1; }
                $output_70 =~ s/\n+\z//msx;
                $output_70;
}; $_pipeline_result; }; chomp $_chomp_temp; $_chomp_temp; })) >> 8) || !(            $main_exit_code = system('test', "$host_os-$host_cpu", q{=}, "openbsd2.8-powerpc") >> 8))) {
                $hardcode_libdir_flag_spec = '${wl}-rpath,$libdir';
}
            else {
if ("$host_os" =~ /^openbsd\[01\]..*$/msx or "$host_os" =~ /^openbsd2.\[0-7\]$/msx or "$host_os" =~ /^openbsd2.\[0-7\]..*$/msx) {
                                        $hardcode_libdir_flag_spec = '-R$libdir';
                } elsif (1) {
                                        $hardcode_libdir_flag_spec = '${wl}-rpath,$libdir';
                }
            }
}
        else {
            $ld_shlibs = 'no';
        }
    } elsif ("$host_os" =~ /^os2.*$/msx) {
                $hardcode_libdir_flag_spec = '-L$libdir';
                $hardcode_minus_L = 'yes';
    } elsif ("$host_os" =~ /^osf3.*$/msx) {
                $hardcode_libdir_flag_spec = '${wl}-rpath ${wl}$libdir';
                $hardcode_libdir_separator = q{:};
    } elsif ("$host_os" =~ /^osf4.*$/msx or "$host_os" =~ /^osf5.*$/msx) {
        if (StringInterpolation(StringInterpolation { parts: [Variable("GCC")] }, None) eq yes) {
            $hardcode_libdir_flag_spec = '${wl}-rpath ${wl}$libdir';
}
        else {
            $hardcode_libdir_flag_spec = '-rpath $libdir';
        }
                $hardcode_libdir_separator = q{:};
    } elsif ("$host_os" =~ /^solaris.*$/msx) {
                $hardcode_libdir_flag_spec = '-R$libdir';
    } elsif ("$host_os" =~ /^sunos4.*$/msx) {
                $hardcode_libdir_flag_spec = '-L$libdir';
                $hardcode_direct = 'yes';
                $hardcode_minus_L = 'yes';
    } elsif ("$host_os" =~ /^sysv4$/msx) {
        if ($host_vendor =~ /^sni$/msx) {
                        $hardcode_direct = 'yes';
        } elsif ($host_vendor =~ /^siemens$/msx) {
                        $hardcode_direct = 'no';
        } elsif ($host_vendor =~ /^motorola$/msx) {
                        $hardcode_direct = 'no';
        }
    } elsif ("$host_os" =~ /^sysv4.3.*$/msx) {
    } elsif ("$host_os" =~ /^sysv4.*MP.*$/msx) {
        if ((-d '/usr/nec')) {
            $ld_shlibs = 'yes';
        }
    } elsif ("$host_os" =~ /^sysv4.*uw2.*$/msx or "$host_os" =~ /^sysv5OpenUNIX.*$/msx or "$host_os" =~ /^sysv5UnixWare7.\[01\].\[10\].*$/msx or "$host_os" =~ /^unixware7.*$/msx or "$host_os" =~ /^sco3.2v5.0.\[024\].*$/msx) {
    } elsif ("$host_os" =~ /^sysv5.*$/msx or "$host_os" =~ /^sco3.2v5.*$/msx or "$host_os" =~ /^sco5v6.*$/msx) {
                $hardcode_libdir_flag_spec = do {
    my $left_result_73 = do {
    my ($in_74, $out_74);
    my $pid_74 = open3($in_74, $out_74, '>&STDERR', 'test', '-z', "$ENV{SCOABSPATH}");
    close $in_74 or croak 'Close failed: $OS_ERROR';
    my $result_74 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_74> };
    close $out_74 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_74, 0;
    $result_74
};
    if ( $CHILD_ERROR == 0 ) {
        my $right_result_73 = do { ($wl . q{ } . '-R,' . q{ } . $libdir) };
        $left_result_73 . $right_result_73;
    } else {
        q{};
    }
};
                $hardcode_libdir_separator = q{:};
    } elsif ("$host_os" =~ /^uts4.*$/msx) {
                $hardcode_libdir_flag_spec = '-L$libdir';
    } elsif (1) {
                $ld_shlibs = 'no';
    }
}
my $library_names_spec;
my @library_names_spec;
my %library_names_spec;
$library_names_spec = q{};
my $libname_spec;
my @libname_spec;
my %libname_spec;
$libname_spec = 'lib$name';
if ("$host_os" =~ /^aix3.*$/msx) {
        $library_names_spec = '$libname.a';
} elsif ("$host_os" =~ /^aix\[4-9\].*$/msx) {
        $library_names_spec = '$libname$shrext';
} elsif ("$host_os" =~ /^amigaos.*$/msx) {
    if ("$host_cpu" =~ /^powerpc.*$/msx) {
                $library_names_spec = '$libname$shrext';
    } elsif ("$host_cpu" =~ /^m68k$/msx) {
                $library_names_spec = '$libname.a';
    }
} elsif ("$host_os" =~ /^beos.*$/msx) {
        $library_names_spec = '$libname$shrext';
} elsif ("$host_os" =~ /^bsdi\[45\].*$/msx) {
        $library_names_spec = '$libname$shrext';
} elsif ("$host_os" =~ /^cygwin.*$/msx or "$host_os" =~ /^mingw.*$/msx or "$host_os" =~ /^pw32.*$/msx or "$host_os" =~ /^cegcc.*$/msx) {
        $shrext = '.dll';
        $library_names_spec = '$libname.dll.a $libname.lib';
} elsif ("$host_os" =~ /^darwin.*$/msx or "$host_os" =~ /^rhapsody.*$/msx) {
        $shrext = '.dylib';
        $library_names_spec = '$libname$shrext';
} elsif ("$host_os" =~ /^dgux.*$/msx) {
        $library_names_spec = '$libname$shrext';
} elsif ("$host_os" =~ /^freebsd\[23\]..*$/msx) {
        $library_names_spec = '$libname$shrext$versuffix';
} elsif ("$host_os" =~ /^freebsd.*$/msx or "$host_os" =~ /^dragonfly.*$/msx) {
        $library_names_spec = '$libname$shrext';
} elsif ("$host_os" =~ /^gnu.*$/msx) {
        $library_names_spec = '$libname$shrext';
} elsif ("$host_os" =~ /^haiku.*$/msx) {
        $library_names_spec = '$libname$shrext';
} elsif ("$host_os" =~ /^hpux9.*$/msx or "$host_os" =~ /^hpux10.*$/msx or "$host_os" =~ /^hpux11.*$/msx) {
    if ($host_cpu =~ /^ia64.*$/msx) {
                $shrext = '.so';
    } elsif ($host_cpu =~ /^hppa.*64.*$/msx) {
                $shrext = '.sl';
    } elsif (1) {
                $shrext = '.sl';
    }
        $library_names_spec = '$libname$shrext';
} elsif ("$host_os" =~ /^interix\[3-9\].*$/msx) {
        $library_names_spec = '$libname$shrext';
} elsif ("$host_os" =~ /^irix5.*$/msx or "$host_os" =~ /^irix6.*$/msx or "$host_os" =~ /^nonstopux.*$/msx) {
        $library_names_spec = '$libname$shrext';
    if ("$host_os" =~ /^irix5.*$/msx or "$host_os" =~ /^nonstopux.*$/msx) {
                my $libsuff;
        my @libsuff;
        my %libsuff;
        $libsuff = q{};
                my $shlibsuff;
        my @shlibsuff;
        my %shlibsuff;
        $shlibsuff = q{};
    } elsif (1) {
        if ($LD =~ /^.*-32$/msx or $LD =~ /^.*"-32 $/msx or $LD =~ /^.*-melf32bsmip$/msx or $LD =~ /^.*"-melf32bsmip $/msx) {
                        $libsuff = q{};
                        $shlibsuff = q{};
        } elsif ($LD =~ /^.*-n32$/msx or $LD =~ /^.*"-n32 $/msx or $LD =~ /^.*-melf32bmipn32$/msx or $LD =~ /^.*"-melf32bmipn32 $/msx) {
                        $libsuff = '32';
                        $shlibsuff = 'N32';
        } elsif ($LD =~ /^.*-64$/msx or $LD =~ /^.*"-64 $/msx or $LD =~ /^.*-melf64bmip$/msx or $LD =~ /^.*"-melf64bmip $/msx) {
                        $libsuff = '64';
                        $shlibsuff = '64';
        } elsif (1) {
                        $libsuff = q{};
                        $shlibsuff = q{};
        }
    }
} elsif ("$host_os" =~ /^linux.*oldld.*$/msx or "$host_os" =~ /^linux.*aout.*$/msx or "$host_os" =~ /^linux.*coff.*$/msx) {
} elsif ("$host_os" =~ /^linux.*$/msx or "$host_os" =~ /^k.*bsd.*-gnu$/msx or "$host_os" =~ /^kopensolaris.*-gnu$/msx) {
        $library_names_spec = '$libname$shrext';
} elsif ("$host_os" =~ /^knetbsd.*-gnu$/msx) {
        $library_names_spec = '$libname$shrext';
} elsif ("$host_os" =~ /^netbsd.*$/msx) {
        $library_names_spec = '$libname$shrext';
} elsif ("$host_os" =~ /^newsos6$/msx) {
        $library_names_spec = '$libname$shrext';
} elsif ("$host_os" =~ /^.*nto.*$/msx or "$host_os" =~ /^.*qnx.*$/msx) {
        $library_names_spec = '$libname$shrext';
} elsif ("$host_os" =~ /^openbsd.*$/msx) {
        $library_names_spec = '$libname$shrext$versuffix';
} elsif ("$host_os" =~ /^os2.*$/msx) {
        $libname_spec = '$name';
        $shrext = '.dll';
        $library_names_spec = '$libname.a';
} elsif ("$host_os" =~ /^osf3.*$/msx or "$host_os" =~ /^osf4.*$/msx or "$host_os" =~ /^osf5.*$/msx) {
        $library_names_spec = '$libname$shrext';
} elsif ("$host_os" =~ /^rdos.*$/msx) {
} elsif ("$host_os" =~ /^solaris.*$/msx) {
        $library_names_spec = '$libname$shrext';
} elsif ("$host_os" =~ /^sunos4.*$/msx) {
        $library_names_spec = '$libname$shrext$versuffix';
} elsif ("$host_os" =~ /^sysv4$/msx or "$host_os" =~ /^sysv4.3.*$/msx) {
        $library_names_spec = '$libname$shrext';
} elsif ("$host_os" =~ /^sysv4.*MP.*$/msx) {
        $library_names_spec = '$libname$shrext';
} elsif ("$host_os" =~ /^sysv5.*$/msx or "$host_os" =~ /^sco3.2v5.*$/msx or "$host_os" =~ /^sco5v6.*$/msx or "$host_os" =~ /^unixware.*$/msx or "$host_os" =~ /^OpenUNIX.*$/msx or "$host_os" =~ /^sysv4.*uw2.*$/msx) {
        $library_names_spec = '$libname$shrext';
} elsif ("$host_os" =~ /^tpf.*$/msx) {
        $library_names_spec = '$libname$shrext';
} elsif ("$host_os" =~ /^uts4.*$/msx) {
        $library_names_spec = '$libname$shrext';
}
my $sed_quote_subst;
my @sed_quote_subst;
my %sed_quote_subst;
$sed_quote_subst = "s/\\([\"" . chr(96) . "$\\\\]\\)/\\\\\\1/g";
my $escaped_wl;
my @escaped_wl;
my %escaped_wl;
$escaped_wl = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_75 = q{};
    my $output_printed_75;
    my $pipeline_success_75 = 1;
    $output_75 .= "X$wl\n";
    if ( !($output_75 =~ m{\n\z}msx) ) { $output_75 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_75 = 0; }
    my @sed_lines_75 = split /\n/msx, $output_75;
    my @sed_result_75;
    foreach my $line (@sed_lines_75) {
    chomp $line;
    push @sed_result_75, $line;
    }
    $output_75 = join "\n", @sed_result_75;

    if ( !$pipeline_success_75 ) { $main_exit_code = 1; }
    $output_75 =~ s/\n+\z//msx;
    $output_75;
}; $_pipeline_result; };
my $shlibext;
my @shlibext;
my %shlibext;
$shlibext = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_76 = q{};
    my $output_printed_76;
    my $pipeline_success_76 = 1;
    $output_76 .= $shrext . "\n";
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
my $escaped_libname_spec;
my @escaped_libname_spec;
my %escaped_libname_spec;
$escaped_libname_spec = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_77 = q{};
    my $output_printed_77;
    my $pipeline_success_77 = 1;
    $output_77 .= "X$libname_spec\n";
    if ( !($output_77 =~ m{\n\z}msx) ) { $output_77 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_77 = 0; }
    my @sed_lines_77 = split /\n/msx, $output_77;
    my @sed_result_77;
    foreach my $line (@sed_lines_77) {
    chomp $line;
    push @sed_result_77, $line;
    }
    $output_77 = join "\n", @sed_result_77;

    if ( !$pipeline_success_77 ) { $main_exit_code = 1; }
    $output_77 =~ s/\n+\z//msx;
    $output_77;
}; $_pipeline_result; };
my $escaped_library_names_spec;
my @escaped_library_names_spec;
my %escaped_library_names_spec;
$escaped_library_names_spec = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_78 = q{};
    my $output_printed_78;
    my $pipeline_success_78 = 1;
    $output_78 .= "X$library_names_spec\n";
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
my $escaped_hardcode_libdir_flag_spec;
my @escaped_hardcode_libdir_flag_spec;
my %escaped_hardcode_libdir_flag_spec;
$escaped_hardcode_libdir_flag_spec = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_79 = q{};
    my $output_printed_79;
    my $pipeline_success_79 = 1;
    $output_79 .= "X$hardcode_libdir_flag_spec\n";
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
    my $LC_ALL = q{C};
my $temp_content = '
# How to pass a linker flag through the compiler.
wl="$escaped_wl"

# Static library suffix (normally "a").
libext="$libext"

# Shared library suffix (normally "so").
shlibext="$shlibext"

# Format of library name prefix.
libname_spec="$escaped_libname_spec"

# Library names that the linker finds when passed -lNAME.
library_names_spec="$escaped_library_names_spec"

# Flag to hardcode \$libdir into a binary during linking.
# This must work even if \$libdir does not exist.
hardcode_libdir_flag_spec="$escaped_hardcode_libdir_flag_spec"

# Whether we need a single -rpath flag with a separated argument.
hardcode_libdir_separator="$hardcode_libdir_separator"

# Set to yes if using DIR/libNAME.so during linking hardcodes DIR into the
# resulting binary.
hardcode_direct="$hardcode_direct"

# Set to yes if using the -LDIR flag during linking hardcodes DIR into the
# resulting binary.
hardcode_minus_L="$hardcode_minus_L"

';
use File::Path qw(make_path);
if (!-d q{/tmp}) { make_path(q{/tmp}); }
open my $fh_1, '>', q{/tmp} . '/heredoc_temp' or croak "Cannot create temp file: $OS_ERROR\n";
print $fh_1 $temp_content;
close $fh_1 or croak "Close failed: $OS_ERROR\n";
open STDIN, '<', q{/tmp} . '/heredoc_temp' or croak "Cannot open temp file: $OS_ERROR\n";
my @sed_lines_80 = split /\n/msx, $;
my @sed_result_80;
foreach my $line (@sed_lines_80) {
chomp $line;
push @sed_result_80, $line;
}
$ = join "\n", @sed_result_80;


exit $main_exit_code;
