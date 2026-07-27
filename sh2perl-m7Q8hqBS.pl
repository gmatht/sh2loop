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

my $MAGIC_5     = 5;
my $MAGIC_4     = 4;
my $MAGIC_44100 = 44_100;
my $MAGIC_26    = 26;
my $MAGIC_48000 = 48_000;

my $dev_playback;
my @dev_playback;
my %dev_playback;
$dev_playback = "default";
my $dev_capture;
my @dev_capture;
my %dev_capture;
$dev_capture = "default";
my $bin;
my @bin;
my %bin;
$bin = "alsabat";
my $commands;
my @commands;
my %commands;
$commands = "$bin -P $dev_playback -C $dev_capture";
my $file_sin_mono;
my @file_sin_mono;
my %file_sin_mono;
$file_sin_mono = "default_mono.wav";
my $file_sin_dual;
my @file_sin_dual;
my %file_sin_dual;
$file_sin_dual = "default_dual.wav";
my $logdir;
my @logdir;
my %logdir;
$logdir = "tmp";
my $maxfreq;
my @maxfreq;
my %maxfreq;
$maxfreq = '16547';
my $minfreq;
my @minfreq;
my %minfreq;
$minfreq = '17';
my $sleep_time;
my @sleep_time;
my %sleep_time;
$sleep_time = q{5};
my $pause_time;
my @pause_time;
my %pause_time;
$pause_time = q{2};
my $feature_pass;
my @feature_pass;
my %feature_pass;
$feature_pass = q{0};
my $feature_cnt;
my @feature_cnt;
my %feature_cnt;
$feature_cnt = q{0};

sub init_counter {
    $feature_pass = q{0};
    my $feature_all;
    my @feature_all;
    my %feature_all;
    $feature_all = q{0};
    return;
}

sub evaluate_result {
    $feature_cnt = eval { int($feature_cnt+1) } // "";
if (($1 == 0)) {
        $feature_pass = eval { int($feature_pass+1) } // "";
        print "pass\n";
}
    else {
        print "fail\n";
    }
    return;
}

sub print_result {
    do {
    my $__echo_line = "[$feature_pass/$feature_cnt] features passes.";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    return;
}

sub feature_test {
    my ($file) = @_;
    print "============================================\n";
    do {
    my $__echo_line = "$feature_cnt: ALSA $_[1]";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    print "-------------------------------------------\n";
    do {
    my $__echo_line = "$commands $_[0] --log=$logdir/$feature_cnt.log";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    $CHILD_ERROR = 0;
    evaluate_result($?);
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $logdir
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "$commands $_[0]" . q{ } . q{/} . q{ } . eval { int($feature_cnt-1) } // "" . q{ } . '.log';
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
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
    return;
}

sub feature_test_power {
    my ($file) = @_;
    print "============================================\n";
    do {
    my $__echo_line = "$feature_cnt: ALSA $_[1]";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    print "-------------------------------------------\n";
    do {
    my $__echo_line = "$commands $_[0] --log=$logdir/$feature_cnt.log";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    if (my $pid = fork()) {
        # Parent process continues
    } elsif (defined $pid) {
        # Child process executes the background command
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', $logdir
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
exec($commands, @args);
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
        };
        exit(0);
    } else {
        die "Cannot fork: $ERRNO\n";
    }
require Time::HiRes; Time::HiRes::sleep($pause_time);
    my $pid;
    my @pid;
    my %pid;
    $pid = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_2 = q{};
        my $output_printed_2;
        my $pipeline_success_2 = 1;

        my ($in_3, $out_3);
        my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'ps', '-aux');
        close $in_3 or croak 'Close failed: $OS_ERROR';
        $output_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
        close $out_3 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_3, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_2 = 0; }
        my $grep_result_2_1;
        my @grep_lines_2_1 = split /\n/msx, $output_2;
        my @grep_filtered_2_1 = grep { /alsabat/msx } @grep_lines_2_1;
        $grep_result_2_1 = join "\n", @grep_filtered_2_1;
                if (!($grep_result_2_1 =~ m{\n\z}msx || $grep_result_2_1 eq q{})) {
                    $grep_result_2_1 .= "\n";
                }
        $CHILD_ERROR = scalar @grep_filtered_2_1 > 0 ? 0 : 1;
        $output_2 = $grep_result_2_1;
        my $num_lines       = 1;
        my $head_line_count = 0;
        my $result          = q{};
        my $input           = $output_2;
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
        $output_2 = $result;

        my @lines = split /\n/msx, $output_2;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\ /msx, $line;
            push @result, ($fields[1] . "\n");
        }
        $output_2 = join "", @result;

        if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
        $output_2 =~ s/\n+\z//msx;
        $output_2;
}; $_pipeline_result; };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $signal = 'S';
my @pids = ('TOP', $pid);
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
    };
require Time::HiRes; Time::HiRes::sleep(q{4});
    $main_exit_code = system('rtcwake', '-m', 'mem', '-s', $sleep_time) >> 8;
require Time::HiRes; Time::HiRes::sleep($pause_time);
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
my $signal = 'CONT';
my @pids = ($pid);
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
    };
require Time::HiRes; Time::HiRes::sleep($pause_time);
    # Original bash: cat $logdir/$feature_cnt.log |grep -i "Return value is 0" > /dev/null
{
        my $output_9 = q{};
        my $output_printed_9;
        my $pipeline_success_9 = 1;
                $output_9 = (do { my $cat_chunk = q{}; if ( open my $fh, '<', $logdir ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . $logdir . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', q{/} ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . q{/} . ': ' . $OS_ERROR . "\n"; } $cat_chunk; } . do { my $cat_chunk = q{}; if ( open my $fh, '<', "$feature_cnt.log" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$feature_cnt.log" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; });

                do {
        open my $original_stdout, '>&', STDOUT
        or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
        or die "Cannot open file: $OS_ERROR\n";
        my $tmp = do {
        my $tmp_redirect_10 = q{};
        my $grep_result_11;
        my @grep_lines_11 = split /\n/msx, $output_9;
        my @grep_filtered_11 = grep { /Return\ value\ is\ 0/msxi } @grep_lines_11;
        $grep_result_11 = join "\n", @grep_filtered_11;
        if (!($grep_result_11 =~ m{\n\z}msx || $grep_result_11 eq q{})) {
        $grep_result_11 .= "\n";
        }
        $CHILD_ERROR = scalar @grep_filtered_11 > 0 ? 0 : 1;
        $tmp_redirect_10 = $grep_result_11;
        $tmp_redirect_10;
        };
        print $tmp;
        if ($tmp eq q{}) { print $output_9; }
        $output_printed_9 = 1;
        open STDOUT, '>&', $original_stdout
        or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
        or die "Close failed: $OS_ERROR\n";
        };
        if ( !$pipeline_success_9 ) { $main_exit_code = 1; }
        }
    evaluate_result($?);
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $logdir
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "$commands $_[0]" . q{ } . q{/} . q{ } . eval { int($feature_cnt-1) } // "" . q{ } . '.log';
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
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
    return;
}

sub feature_list_test {
    init_counter();
    $commands = "$bin";
    feature_test("-c1 --saveplay $file_sin_mono", "generate mono wav file with default params");
    feature_test("-c2 --saveplay $file_sin_dual", "generate dual wav file with default params");
require Time::HiRes; Time::HiRes::sleep(q{5});
    feature_test("-P $dev_playback", "single line mode, playback");
    feature_test("-C $dev_capture --standalone", "single line mode, capture");
    $commands = "$bin -P $dev_playback -C $dev_capture";
    feature_test("--file $file_sin_mono", "play mono wav file and detect");
    feature_test("--file $file_sin_dual", "play dual wav file and detect");
    feature_test("-c1", "configurable channel number: 1");
    feature_test("-c2 -F $minfreq:$maxfreq", "configurable channel number: 2");
    feature_test("-r44100", "configurable sample rate: 44100");
    feature_test("-r48000", "configurable sample rate: 48000");
    feature_test("-n10000", "configurable duration: in samples");
    feature_test("-n2.5s", "configurable duration: in seconds");
    feature_test("-f U8", "configurable data format: U8");
    feature_test("-f S16_LE", "configurable data format: S16_LE");
    feature_test("-f S24_3LE", "configurable data format: S24_3LE");
    feature_test("-f S32_LE", "configurable data format: S32_LE");
    feature_test("-f cd", "configurable data format: cd");
    feature_test("-f dat", "configurable data format: dat");
    feature_test("-F $maxfreq --standalone", "standalone mode: play and capture");
    my $latestfile;
    my @latestfile;
    my %latestfile;
    $latestfile = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_13 = q{};
        my $output_printed_13;
        my $pipeline_success_13 = 1;
        $output_13 = do {
            my @ls_files_14 = ();
            my $ls_all_found_15 = 1;
            my @ls_inputs_16 = ();
            my @ls_glob_ls_inputs_16_0 = glob('/tmp/bat.wav.*');
            if ( !@ls_glob_ls_inputs_16_0 ) {
                push @ls_inputs_16, '/tmp/bat.wav.*';
                $ls_all_found_15 = 0;
            } else {
                push @ls_inputs_16, @ls_glob_ls_inputs_16_0;
            }
            my @ls_files_17 = ();
            my @ls_dirs_18 = ();
            my $ls_show_headers_19 = scalar(@ls_inputs_16) > 1;
            for my $ls_item_20 (@ls_inputs_16) {
                if ( -f $ls_item_20 ) {
                    push @ls_files_17, $ls_item_20;
                }
                elsif ( -d $ls_item_20 ) {
                    push @ls_dirs_18, $ls_item_20;
                }
                else {
                    $ls_all_found_15 = 0;
                }
            }
            @ls_files_17 = sort { $a cmp $b } @ls_files_17;
            @ls_dirs_18 = sort { $a cmp $b } @ls_dirs_18;
            if (@ls_files_17) {
                push @ls_files_14, join("\n", @ls_files_17);
            }
            for my $ls_dir_21 (@ls_dirs_18) {
                my @ls_dir_entries_22 = ();
                if ( opendir my $dh, $ls_dir_21 ) {
                    while ( my $file = readdir $dh ) {
                        next if $file eq q{.} || $file eq q{..} || $file =~ /^[.]/msx;
                        push @ls_dir_entries_22, $file;
                    }
                    closedir $dh;
                    @ls_dir_entries_22 = map { $_->[0] } sort { $a->[1] cmp $b->[1] } map { [ $_, do { (my $s = $_) =~ s{/$}{}msx; $s } ] } @ls_dir_entries_22;
                    if ( $ls_show_headers_19 ) {
                        if ( @ls_dir_entries_22 ) {
                            push @ls_files_14, $ls_dir_21 . ":\n" . join("\n", @ls_dir_entries_22);
                        } else {
                            push @ls_files_14, $ls_dir_21 . ':';
                        }
                    }
                    elsif ( @ls_dir_entries_22 ) {
                        push @ls_files_14, join("\n", @ls_dir_entries_22);
                    }
                }
                else {
                    $ls_all_found_15 = 0;
                }
            }
            (@ls_files_14 ? join("\n\n", @ls_files_14) . "\n" : q{});
        };
        ;
        if ($CHILD_ERROR != 0) { $pipeline_success_13 = 0; }
        my $num_lines       = 1;
        my $head_line_count = 0;
        my $result          = q{};
        my $input           = $output_13;
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
        $output_13 = $result;

        if ( !$pipeline_success_13 ) { $main_exit_code = 1; }
        $output_13 =~ s/\n+\z//msx;
        $output_13;
}; $_pipeline_result; };
    feature_test("--local -F $maxfreq --file $latestfile", "local mode: analyze local file");
    feature_test("--roundtriplatency", "round trip latency test");
    feature_test("--snr-db 26", "noise detect threshold in SNR(dB)");
    feature_test("--snr-pc 5", "noise detect threshold in noise percentage(%)");
    feature_test_power("-n5s", "power management: S3 test");
    print_result();
    return;
}
print "*******************************************\n";
print "                BAT Test                   \n";
print "-------------------------------------------\n";
print "usage:\n";
do {
    my $__echo_line = "  $PROGRAM_NAME <sound card>";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
do {
    my $__echo_line = "  $PROGRAM_NAME <device-playback> <device-capture>";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
if ((scalar(@ARGV) == 2)) {
    $dev_playback = $1;
    $dev_capture = $2;
}
else {
    if ((scalar(@ARGV) == 1)) {
        $dev_playback = $1;
        $dev_capture = $1;
    }
}
print "current setting:\n";
do {
    my $__echo_line = "  $PROGRAM_NAME $dev_playback $dev_capture";
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
if ( !-d $logdir ) {
    make_path( $logdir, { error => \$err } );
    if ( @{$err} ) {
        croak "mkdir: cannot create directory " . $logdir . ": $err->[0]\n";
    }
}
feature_list_test();
print "*******************************************\n";

exit $main_exit_code;
