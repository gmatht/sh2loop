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

my $previous;
my @previous;
my %previous;
my $LMT_CONTROL_HD_POWERMGMT;
my @LMT_CONTROL_HD_POWERMGMT;
my %LMT_CONTROL_HD_POWERMGMT;
my $runlevel;
my @runlevel;
my %runlevel;

if (!(my $grep_result_0;
my @grep_lines_0 = ();
my @grep_filenames_0 = ();
if (-e "/proc/cmdline") {
    open my $fh, '<', "/proc/cmdline" or croak "Cannot open file: $ERRNO";
    while (my $line = <$fh>) {
        chomp $line;
        push @grep_lines_0, $line;
        push @grep_filenames_0, "/proc/cmdline";
    }
    close $fh
        or croak "Close failed: $OS_ERROR";
}
else { print {*STDERR} "grep: /proc/cmdline: No such file or directory\n"; }
my @grep_filtered_0 = grep { /q/msx } @grep_lines_0;
$grep_result_0 = join "\n", @grep_filtered_0;
if (!($grep_result_0 =~ m{\n\z}msx || $grep_result_0 eq q{})) {
    $grep_result_0 .= "\n";
}
print $grep_result_0;
$CHILD_ERROR = scalar @grep_filtered_0 > 0 ? 0 : 1)) {
exit 0;
}
if ((!(do {
    local %ENV = %ENV;
    if (("$previous")) {
        ("$runlevel")        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    q{};
}) || "$runlevel" eq S)) {
exit 0;
}
if ((-e '/usr/sbin/laptop_mode')) {
    $LMT_CONTROL_HD_POWERMGMT = do {
    my $left_result_1 = do {
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', q{.}, '/etc/laptop-mode/laptop-mode.conf');
    close $in_2 or croak 'Close failed: $OS_ERROR';
    my $result_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    $result_2
};
    if ( $CHILD_ERROR == 0 ) {
        my $right_result_1 = do { ("$ENV{CONTROL_HD_POWERMGMT}") };
        $left_result_1 . $right_result_1;
    } else {
        q{};
    }
};
if (("$LMT_CONTROL_HD_POWERMGMT" ne 0 && (-e '/var/run/laptop-mode-tools/enabled'))) {
exit 0;
    }
}
$main_exit_code = system('.', '/lib/hdparm/hdparm-functions') >> 8;

sub resume_hdparm_apm {
    my $dev;
    for my $dev ('/dev/sd?', '/dev/hd?') {
        my $apm_opt;
        my @apm_opt;
        my %apm_opt;
        $apm_opt = q{};
if ((( -b $dev) && !(        $main_exit_code = system('hdparm_try_apm', $dev) >> 8))) {
            my $option;
            for my $option (do {
    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'hdparm_options', $dev);
    close $in_3 or croak 'Close failed: $OS_ERROR';
    my $result_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;
    $result_3
}) {
if ($option =~ /^-B.*$/msx) {
                                        $apm_opt = $option;
                } elsif (1) {
                }
            }
if ("$apm_opt" ne q{}) {
                $main_exit_code = system('hdparm', $apm_opt, $dev) >> 8;
            }
        }
    }
    return;
}

sub resume_hdparm_spindown {
    my $dev;
    for my $dev ('/dev/sd?', '/dev/hd?') {
        my $ignore_apm;
        my @ignore_apm;
        my %ignore_apm;
        $ignore_apm = q{};
        my $options;
        my @options;
        my %options;
        $options = do {
    my ($in_4, $out_4);
    my $pid_4 = open3($in_4, $out_4, '>&STDERR', 'hdparm_options', $dev);
    close $in_4 or croak 'Close failed: $OS_ERROR';
    my $result_4 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_4> };
    close $out_4 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_4, 0;
    $result_4
};
if ($options =~ /^.*'force_spindown_time'.*$/msx) {
                        $ignore_apm = 'true';
        }
        my $apm_opt;
        my @apm_opt;
        my %apm_opt;
        $apm_opt = q{};
if (( -b $dev)) {
if ((!(            $main_exit_code = system('hdparm_try_apm', $dev) >> 8) || "$ignore_apm" eq true)) {
                my $option;
                for my $option (do {
    my ($in_5, $out_5);
    my $pid_5 = open3($in_5, $out_5, '>&STDERR', 'hdparm_options', $dev);
    close $in_5 or croak 'Close failed: $OS_ERROR';
    my $result_5 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
    close $out_5 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_5, 0;
    $result_5
}) {
                    $option = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
                        my $output_6 = q{};
                        my $output_printed_6;
                        my $pipeline_success_6 = 1;
                        $output_6 .= $option . "\n";
                        if ( !($output_6 =~ m{\n\z}msx) ) { $output_6 .= "\n"; }
                        $CHILD_ERROR = 0;
                        if ($CHILD_ERROR != 0) { $pipeline_success_6 = 0; }
                        my @sed_lines_6 = split /\n/msx, $output_6;
                        my @sed_result_6;
                        foreach my $line (@sed_lines_6) {
                        chomp $line;
                        $line =~ s/force_spindown_time/-S/gmsx;
                        push @sed_result_6, $line;
                        }
                        $output_6 = join "\n", @sed_result_6;

                        if ( !$pipeline_success_6 ) { $main_exit_code = 1; }
                        $output_6 =~ s/\n+\z//msx;
                        $output_6;
}; $_pipeline_result; };
if ($option =~ /^-S.*$/msx) {
                                                $apm_opt = $option;
                    } elsif (1) {
                    }
                }
if ("$apm_opt" ne q{}) {
                    $main_exit_code = system('hdparm', $apm_opt, $dev) >> 8;
                }
            }
        }
    }
    return;
}
if ("$_[0]" =~ /^true$/msx or "$_[0]" =~ /^false$/msx) {
        resume_hdparm_apm();
} elsif ("$_[0]" =~ /^thaw$/msx or "$_[0]" =~ /^resume$/msx) {
        resume_hdparm_apm();
        resume_hdparm_spindown();
} elsif (1) {
    exit 254;
}

exit $main_exit_code;
