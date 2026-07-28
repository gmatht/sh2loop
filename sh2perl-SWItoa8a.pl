#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

delete $ENV{LC_ALL};
my $LC_TIME = q{C};
$ENV{LC_TIME} = $LC_TIME;
my $RPM;
if (!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot access file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
    my $tmp = do {
    $main_exit_code = system('rpm', '--nosignature', '--version') >> 8;
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};)) {
    $RPM = "rpm --nosignature";
}
else {
    $RPM = "rpm";
}

sub mcrpmfs_list {
    my ($file) = @_;
    my $MCFASTRPM_DFLT = q{0};
    my $MCFASTRPM;
if (StringInterpolation(StringInterpolation { parts: [Variable("MCFASTRPM")] }, None) eq q{}) {
        $MCFASTRPM = $MCFASTRPM_DFLT;
    }
;
    my $FILEPREF = "-r--r--r--   1 root     root    ";
    my $DESC = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', $RPM, '-qi', '--', "$_[0]");
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
    my $DATE = do {
    do { do {
        my $output_1 = q{};
        my $output_printed_1;
        my $pipeline_success_1 = 1;

        my ($in_2, $out_2);
        my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'unknown_command', '-q', '--qf', '--');
        close $in_2 or croak 'Close failed: $OS_ERROR';
        $output_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
        close $out_2 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_2, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_1 = 0; }
        my @lines_3 = split /\n/, $output_1;
        my @result_3;
        foreach my $line (@lines_3) {
        chomp $line;
        my @fields = split /\t/msx, $line;
        if (@fields > 0) {
            push @result_3, $fields[0];
        }
        }
        $output_1 = join "\n", @result_3;
        if ($output_1 ne q{} && !($output_1  =~ m{\n\z})) { $output_1 .= "\n"; }

        if ( !$pipeline_success_1 ) { $main_exit_code = 1; }
        $output_1 =~ s/\n+\z//msx;
        $output_1;
}; };
};
    my $HEADERSIZE = do {
    do { do {
        my $output_4 = q{};
        my $output_printed_4;
        my $pipeline_success_4 = 1;
        $output_4 .= $DESC . "\n";
        if ( !($output_4 =~ m{\n\z}) ) { $output_4 .= "\n"; }
        if ($CHILD_ERROR != 0) { $pipeline_success_4 = 0; }
        $output_4 = do {
                    my $_wc_data = $output_4;
                    my $_wc_bytes = length($_wc_data);
                    my $_wc_result = sprintf("%d \n", $_wc_bytes);
                    $_wc_result;
                };
        if ( !$pipeline_success_4 ) { $main_exit_code = 1; }
        $output_4 =~ s/\n+\z//msx;
        $output_4;
}; };
};
    say "-r--r--r--   1 root     root  $HEADERSIZE $DATE HEADER";
    say "-r-xr-xr-x   1 root     root    40 $DATE UNINSTALL";
    say "dr-xr-xr-x   3 root     root	   0 $DATE INFO";
    say "$FILEPREF 0 $DATE INFO/NAME-VERSION-RELEASE";
    say "$FILEPREF 0 $DATE INFO/GROUP";
    say "$FILEPREF 0 $DATE INFO/BUILDHOST";
    say "$FILEPREF 0 $DATE INFO/SOURCERPM";
if (StringInterpolation(StringInterpolation { parts: [Variable("MCFASTRPM")] }, None) eq 0) {
                $main_exit_code = system('test', (do {
    my ($in_5, $out_5);
    my $pid_5 = open3($in_5, $out_5, '>&STDERR', $RPM, '-q', '--qf', "%{DISTRIBUTION}", '--', "$_[0]");
    close $in_5 or croak 'Close failed: $OS_ERROR';
    my $result_5 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
    close $out_5 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_5, 0;
    $result_5
}), q{=}, "(none)") >> 8;
        if ($CHILD_ERROR != 0) {
                        say "$FILEPREF 0 $DATE INFO/DISTRIBUTION";
        }
;
                $main_exit_code = system('test', (do {
    my ($in_6, $out_6);
    my $pid_6 = open3($in_6, $out_6, '>&STDERR', $RPM, '-q', '--qf', "%{VENDOR}", '--', "$_[0]");
    close $in_6 or croak 'Close failed: $OS_ERROR';
    my $result_6 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> };
    close $out_6 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_6, 0;
    $result_6
}), q{=}, "(none)") >> 8;
        if ($CHILD_ERROR != 0) {
                        say "$FILEPREF 0 $DATE INFO/VENDOR";
        }
;
                $main_exit_code = system('test', (do {
    my ($in_7, $out_7);
    my $pid_7 = open3($in_7, $out_7, '>&STDERR', $RPM, '-q', '--qf', "%{DESCRIPTION}", '--', "$_[0]");
    close $in_7 or croak 'Close failed: $OS_ERROR';
    my $result_7 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
    close $out_7 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_7, 0;
    $result_7
}), q{=}, "(none)") >> 8;
        if ($CHILD_ERROR != 0) {
                        say "$FILEPREF 0 $DATE INFO/DESCRIPTION";
        }
;
                $main_exit_code = system('test', (do {
    my ($in_8, $out_8);
    my $pid_8 = open3($in_8, $out_8, '>&STDERR', $RPM, '-q', '--qf', "%{SUMMARY}", '--', "$_[0]");
    close $in_8 or croak 'Close failed: $OS_ERROR';
    my $result_8 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_8> };
    close $out_8 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_8, 0;
    $result_8
}), q{=}, "(none)") >> 8;
        if ($CHILD_ERROR != 0) {
                        say "$FILEPREF 0 $DATE INFO/SUMMARY";
        }
;
if ((!StringInterpolation(StringInterpolation { parts: [CommandSubstitution(Simple(SimpleCommand { name: Variable("RPM", false, None), args: [Literal("-q", None), Literal("--qf", None), StringInterpolation(StringInterpolation { parts: [Literal("%{RPMTAG_PREIN}%{RPMTAG_POSTIN}%{RPMTAG_PREUN}%{RPMTAG_POSTUN}%{VERIFYSCRIPT}")] }, None), Literal("--", None), StringInterpolation(StringInterpolation { parts: [Variable("1")] }, None)], redirects: [], env_vars: {}, stdout_used: true, stderr_used: true }))] }, None) eq StringInterpolation(StringInterpolation { parts: [Literal("(none)(none)(none)(none)(none)")] }, None))) {
            say "dr-xr-xr-x   1 root     root     0 $DATE INFO/SCRIPTS";
                        $main_exit_code = system('test', (do {
    my ($in_9, $out_9);
    my $pid_9 = open3($in_9, $out_9, '>&STDERR', $RPM, '-q', '--qf', "%{RPMTAG_PREIN}", '--', "$_[0]");
    close $in_9 or croak 'Close failed: $OS_ERROR';
    my $result_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_9> };
    close $out_9 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_9, 0;
    $result_9
}), q{=}, '(none)') >> 8;
            if ($CHILD_ERROR != 0) {
                                say "$FILEPREF 0 $DATE INFO/SCRIPTS/PREIN";
            }
;
                        $main_exit_code = system('test', (do {
    my ($in_10, $out_10);
    my $pid_10 = open3($in_10, $out_10, '>&STDERR', $RPM, '-q', '--qf', "%{RPMTAG_POSTIN}", '--', "$_[0]");
    close $in_10 or croak 'Close failed: $OS_ERROR';
    my $result_10 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_10> };
    close $out_10 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_10, 0;
    $result_10
}), q{=}, '(none)') >> 8;
            if ($CHILD_ERROR != 0) {
                                say "$FILEPREF 0 $DATE INFO/SCRIPTS/POSTIN";
            }
;
                        $main_exit_code = system('test', (do {
    my ($in_11, $out_11);
    my $pid_11 = open3($in_11, $out_11, '>&STDERR', $RPM, '-q', '--qf', "%{RPMTAG_PREUN}", '--', "$_[0]");
    close $in_11 or croak 'Close failed: $OS_ERROR';
    my $result_11 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_11> };
    close $out_11 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_11, 0;
    $result_11
}), q{=}, '(none)') >> 8;
            if ($CHILD_ERROR != 0) {
                                say "$FILEPREF 0 $DATE INFO/SCRIPTS/PREUN";
            }
;
                        $main_exit_code = system('test', (do {
    my ($in_12, $out_12);
    my $pid_12 = open3($in_12, $out_12, '>&STDERR', $RPM, '-q', '--qf', "%{RPMTAG_POSTUN}", '--', "$_[0]");
    close $in_12 or croak 'Close failed: $OS_ERROR';
    my $result_12 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_12> };
    close $out_12 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_12, 0;
    $result_12
}), q{=}, '(none)') >> 8;
            if ($CHILD_ERROR != 0) {
                                say "$FILEPREF 0 $DATE INFO/SCRIPTS/POSTUN";
            }
;
                        $main_exit_code = system('test', (do {
    my ($in_13, $out_13);
    my $pid_13 = open3($in_13, $out_13, '>&STDERR', $RPM, '-q', '--qf', "%{VERIFYSCRIPT}", '--', "$_[0]");
    close $in_13 or croak 'Close failed: $OS_ERROR';
    my $result_13 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_13> };
    close $out_13 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_13, 0;
    $result_13
}), q{=}, '(none)') >> 8;
            if ($CHILD_ERROR != 0) {
                                say "$FILEPREF 0 $DATE INFO/SCRIPTS/VERIFYSCRIPT";
            }
;
            say "$FILEPREF 0 $DATE INFO/SCRIPTS/ALL";
        }
}
    else {
        say "$FILEPREF 0 $DATE INFO/DISTRIBUTION";
        say "$FILEPREF 0 $DATE INFO/VENDOR";
        say "$FILEPREF 0 $DATE INFO/DESCRIPTION";
        say "$FILEPREF 0 $DATE INFO/SUMMARY";
        say "dr-xr-xr-x   1 root     root     0 $DATE INFO/SCRIPTS";
        say "$FILEPREF 0 $DATE INFO/SCRIPTS/PREIN";
        say "$FILEPREF 0 $DATE INFO/SCRIPTS/POSTIN";
        say "$FILEPREF 0 $DATE INFO/SCRIPTS/PREUN";
        say "$FILEPREF 0 $DATE INFO/SCRIPTS/POSTUN";
        say "$FILEPREF 0 $DATE INFO/SCRIPTS/VERIFYSCRIPT";
        say "$FILEPREF 0 $DATE INFO/SCRIPTS/ALL";
    }
if (StringInterpolation(StringInterpolation { parts: [Variable("MCFASTRPM")] }, None) eq 0) {
                $main_exit_code = system('test', (do {
    my ($in_14, $out_14);
    my $pid_14 = open3($in_14, $out_14, '>&STDERR', $RPM, '-q', '--qf', "%{PACKAGER}", '--', "$_[0]");
    close $in_14 or croak 'Close failed: $OS_ERROR';
    my $result_14 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_14> };
    close $out_14 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_14, 0;
    $result_14
}), q{=}, "(none)") >> 8;
        if ($CHILD_ERROR != 0) {
                        say "$FILEPREF 0 $DATE INFO/PACKAGER";
        }
;
                $main_exit_code = system('test', (do {
    my ($in_15, $out_15);
    my $pid_15 = open3($in_15, $out_15, '>&STDERR', $RPM, '-q', '--qf', "%{URL}", '--', "$_[0]");
    close $in_15 or croak 'Close failed: $OS_ERROR';
    my $result_15 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_15> };
    close $out_15 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_15, 0;
    $result_15
}), q{=}, "(none)") >> 8;
        if ($CHILD_ERROR != 0) {
                        say "$FILEPREF 0 $DATE INFO/URL";
        }
;
                $main_exit_code = system('test', (do {
    my ($in_16, $out_16);
    my $pid_16 = open3($in_16, $out_16, '>&STDERR', $RPM, '-q', '--qf', "%{EPOCH}", '--', "$_[0]");
    close $in_16 or croak 'Close failed: $OS_ERROR';
    my $result_16 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_16> };
    close $out_16 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_16, 0;
    $result_16
}), q{=}, "(none)") >> 8;
        if ($CHILD_ERROR != 0) {
                        say "$FILEPREF 0 $DATE INFO/EPOCH";
        }
;
                $main_exit_code = system('test', (do {
    my ($in_17, $out_17);
    my $pid_17 = open3($in_17, $out_17, '>&STDERR', $RPM, '-q', '--qf', "%{LICENSE}", '--', "$_[0]");
    close $in_17 or croak 'Close failed: $OS_ERROR';
    my $result_17 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_17> };
    close $out_17 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_17, 0;
    $result_17
}), q{=}, "(none)") >> 8;
        if ($CHILD_ERROR != 0) {
                        say "$FILEPREF 0 $DATE INFO/LICENSE";
        }
;
}
    else {
        say "$FILEPREF 0 $DATE INFO/PACKAGER";
        say "$FILEPREF 0 $DATE INFO/URL";
        say "$FILEPREF 0 $DATE INFO/EPOCH";
        say "$FILEPREF 0 $DATE INFO/LICENSE";
    }
    say "$FILEPREF 0 $DATE INFO/BUILDTIME";
    say "$FILEPREF 0 $DATE INFO/RPMVERSION";
    say "$FILEPREF 0 $DATE INFO/OS";
    say "$FILEPREF 0 $DATE INFO/SIZE";
if ((!StringInterpolation(StringInterpolation { parts: [Variable("MCFASTRPM")] }, None) eq 0)) {
        do {
            my $output_18 = q{};
            my $output_printed_18;
            my $pipeline_success_18 = 1;
                        my ($in_19, $out_19);
            my $pid_19 = open3($in_19, $out_19, '>&STDERR', 'unknown_command', '-q', '--qf', '--');
            close $in_19 or croak 'Close failed: $OS_ERROR';
            $output_18 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_19> };
            close $out_19 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_19, 0;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
            or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_20 = q{};
            my $grep_result_21;
            my @grep_lines_21 = split /\n/msx, $output_18;
            my @grep_filtered_21 = grep { /(none)/msx } @grep_lines_21;
            $grep_result_21 = join "\n", @grep_filtered_21;
            if (!($grep_result_21 =~ m{\n\z} || $grep_result_21 eq q{})) {
            $grep_result_21 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_21 > 0 ? 0 : 1;
            $tmp_redirect_20 = $grep_result_21;
            $tmp_redirect_20;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_18; }
            $output_printed_18 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_18 ) { $main_exit_code = 1; }
            }
        if ($CHILD_ERROR != 0) {
                        say "$FILEPREF 0 $DATE INFO/REQUIRENAME";
        }
;
        do {
            my $output_22 = q{};
            my $output_printed_22;
            my $pipeline_success_22 = 1;
                        my ($in_23, $out_23);
            my $pid_23 = open3($in_23, $out_23, '>&STDERR', 'unknown_command', '-q', '--qf', '--');
            close $in_23 or croak 'Close failed: $OS_ERROR';
            $output_22 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_23> };
            close $out_23 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_23, 0;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
            or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_24 = q{};
            my $grep_result_25;
            my @grep_lines_25 = split /\n/msx, $output_22;
            my @grep_filtered_25 = grep { /(none)/msx } @grep_lines_25;
            $grep_result_25 = join "\n", @grep_filtered_25;
            if (!($grep_result_25 =~ m{\n\z} || $grep_result_25 eq q{})) {
            $grep_result_25 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_25 > 0 ? 0 : 1;
            $tmp_redirect_24 = $grep_result_25;
            $tmp_redirect_24;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_22; }
            $output_printed_22 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_22 ) { $main_exit_code = 1; }
            }
        if ($CHILD_ERROR != 0) {
                        say "$FILEPREF 0 $DATE INFO/OBSOLETES";
        }
;
        do {
            my $output_26 = q{};
            my $output_printed_26;
            my $pipeline_success_26 = 1;
                        my ($in_27, $out_27);
            my $pid_27 = open3($in_27, $out_27, '>&STDERR', 'unknown_command', '-q', '--qf', '--');
            close $in_27 or croak 'Close failed: $OS_ERROR';
            $output_26 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_27> };
            close $out_27 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_27, 0;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
            or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_28 = q{};
            my $grep_result_29;
            my @grep_lines_29 = split /\n/msx, $output_26;
            my @grep_filtered_29 = grep { /(none)/msx } @grep_lines_29;
            $grep_result_29 = join "\n", @grep_filtered_29;
            if (!($grep_result_29 =~ m{\n\z} || $grep_result_29 eq q{})) {
            $grep_result_29 .= "\n";
            }
            $CHILD_ERROR = scalar @grep_filtered_29 > 0 ? 0 : 1;
            $tmp_redirect_28 = $grep_result_29;
            $tmp_redirect_28;
            };
            print $tmp;
            if ($tmp eq q{}) { print $output_26; }
            $output_printed_26 = 1;
            open STDOUT, '>&', $original_stdout
            or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
            or die "Close failed: $OS_ERROR\n";
            };
            if ( !$pipeline_success_26 ) { $main_exit_code = 1; }
            }
        if ($CHILD_ERROR != 0) {
                        say "$FILEPREF 0 $DATE INFO/PROVIDES";
        }
;
        do {
            my $output_30 = q{};
            my $output_printed_30;
            my $pipeline_success_30 = 1;
                        my ($in_31, $out_31);
            my $pid_31 = open3($in_31, $out_31, '>&STDERR', 'unknown_command', '-q', '--qf', '--');
            close $in_31 or croak 'Close failed: $OS_ERROR';
            $output_30 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_31> };
            close $out_31 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_31, 0;

                        do {
            open my $original_stdout, '>&', STDOUT
            or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/dev/null'
            or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            my $tmp_redirect_32 = q{};
            my $grep_result_33;
            my @grep_lines_33 = split /\n/msx, $output_30;
            my @grep_filtered_33 = grep { /(none)/msx } @grep_lines_33;
            $grep_result_33 = join "\n", @grep_filtered_33;
            if (!($grep_result_33 =~ m{\n\z} || $grep_result_33 eq q{})) {
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
            }
        if ($CHILD_ERROR != 0) {
                        say "$FILEPREF 0 $DATE INFO/CONFLICTS";
        }
;
                $main_exit_code = system('test', (do {
    my ($in_34, $out_34);
    my $pid_34 = open3($in_34, $out_34, '>&STDERR', $RPM, '-q', '--qf', "%{CHANGELOGTEXT}", '--', "$_[0]");
    close $in_34 or croak 'Close failed: $OS_ERROR';
    my $result_34 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_34> };
    close $out_34 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_34, 0;
    $result_34
}), q{=}, "(none)") >> 8;
        if ($CHILD_ERROR != 0) {
                        say "$FILEPREF 0 $DATE INFO/CHANGELOG";
        }
;
}
    else {
        say "$FILEPREF 0 $DATE INFO/REQUIRENAME";
        say "$FILEPREF 0 $DATE INFO/OBSOLETES";
        say "$FILEPREF 0 $DATE INFO/PROVIDES";
        say "$FILEPREF 0 $DATE INFO/CONFLICTS";
        say "$FILEPREF 0 $DATE INFO/CHANGELOG";
    }
    # Original bash: $RPM -qlv -- "$_[0]" | grep '^[A-Za-z0-9-]'
do {
        my $output_35 = q{};
        my $output_printed_35;
        my $pipeline_success_35 = 1;
                my ($in_36, $out_36);
        my $pid_36 = open3($in_36, $out_36, '>&STDERR', 'unknown_command', '-qlv', '--');
        close $in_36 or croak 'Close failed: $OS_ERROR';
        $output_35 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_36> };
        close $out_36 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_36, 0;

                my $grep_result_35_1;
        my @grep_lines_35_1 = split /\n/msx, $output_35;
        my @grep_filtered_35_1 = grep { /^[A-Za-z0-9-]/msx } @grep_lines_35_1;
        $grep_result_35_1 = join "\n", @grep_filtered_35_1;
        if (!($grep_result_35_1 =~ m{\n\z} || $grep_result_35_1 eq q{})) {
        $grep_result_35_1 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_35_1 > 0 ? 0 : 1;
        $output_35 = $grep_result_35_1;
        $output_35 = $grep_result_35_1;
        if ((scalar @grep_filtered_35_1) == 0) {
            $pipeline_success_35 = 0;
        }
        if ($output_35 ne q{} && !defined $output_printed_35) {
            print $output_35;
            if (!($output_35 =~ m{\n\z})) {
                print "\n";
            }
        }
        if ( !$pipeline_success_35 ) { $main_exit_code = 1; }
        }
;
    return;
}

sub mcrpmfs_copyout {
    my ($file) = @_;
if ("$_[1]" =~ /^HEADER$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^UNINSTALL$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            say "# Run this to uninstall this RPM package";
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/NAME-VERSION-RELEASE$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/RELEASE$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/GROUP$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/DISTRIBUTION$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/VENDOR$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/BUILDHOST$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/SOURCERPM$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/DESCRIPTION$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/PACKAGER$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/URL$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/BUILDTIME$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/EPOCH$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/LICENSE$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/RPMVERSION$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/REQUIRENAME$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/OBSOLETES$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/PROVIDES$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/CONFLICTS$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/SCRIPTS/PREIN$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/SCRIPTS/POSTIN$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/SCRIPTS/PREUN$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/SCRIPTS/POSTUN$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/SCRIPTS/VERIFYSCRIPT$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/SCRIPTS/ALL$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/SUMMARY$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/OS$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/CHANGELOG$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif ("$_[1]" =~ /^INFO/SIZE$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', "$_[2]"
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = 0;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        exit 0;
    } elsif (1) {
                use File::Copy qw(copy);
        if ( -e "/$_[1]" ) {
            if ( -d "$_[2]" ) {
                require File::Copy; File::Copy::copy("/$_[1]", "$_[2]" . '/' . ("/$_[1]" =~ m|([^/]+)$|)[0]);
            } else {
                require File::Copy; File::Copy::copy("/$_[1]", "$_[2]");
            }
        } else {
            croak "cp: cannot stat '/$_[1]': No such file or directory\n";
        }
    }
    return;
}

sub mcrpmfs_run {
    my ($file) = @_;
if ("$_[1]" =~ /^UNINSTALL$/msx) {
                say "Uninstalling $_[0]";
                $main_exit_code = system('rpm', '-e', '--', "$_[0]") >> 8;
        exit 0;
    }
    return;
}
my $name = do { my @_qx_cmd = ('sed "s/.*\\\\///;s/\\\\.trpm\\$//" "$2"'); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; };
if ("$_[0]" =~ /^list$/msx) {
        mcrpmfs_list("$name");
    exit 0;
} elsif ("$_[0]" =~ /^copyout$/msx) {
        mcrpmfs_copyout("$name", "$_[2]", "$_[3]");
    exit 0;
} elsif ("$_[0]" =~ /^run$/msx) {
        mcrpmfs_run("$name", "$_[2]");
    exit 1;
}
exit 1;
