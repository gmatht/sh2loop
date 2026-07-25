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

my $NCPORT;
my @NCPORT;
my %NCPORT;
$NCPORT = '23457';
my $WAIT;
my @WAIT;
my %WAIT;
$WAIT = q{1};
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
if (((scalar(@ARGV) != 0) && (scalar(@ARGV) != 2))) {
    print "Usage:\n";
    print "\n";
    $CHILD_ERROR = 0;
    print "  On the transmitter side:\n";
    do {
    my $__echo_line = "    $me <receivers ip-address> <amount of data>";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    print "\n";
    $CHILD_ERROR = 0;
    print "  The <amount of data> is to be given in byte but you\n";
    print "  also can supply M or K for MegaByte and KiloByte.\n";
    do {
    my $__echo_line = "  Example: $me 10.1.1.3 20M";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    print "\n";
    $CHILD_ERROR = 0;
    print "  On the receiver side:\n";
    do {
    my $__echo_line = "    $me";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    print "\n";
    $CHILD_ERROR = 0;
    do {
    my $__echo_line = "  Start $me on the receiver side before starting it";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    print "  on the transmitter side. Stop the receiver by pressing\n";
    print "  and holding Ctrl-C.\n";
exit 1;
}
if ((scalar(@ARGV) == 0)) {
while ( 1 ) {
        print "waiting to receive data... (quit: press and hold Ctrl-C)\n";
        my $AMOUNT;
        my @AMOUNT;
        my %AMOUNT;
        $AMOUNT = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_2 = q{};
            my $output_printed_2;
            my $pipeline_success_2 = 1;

            my ($in_3, $out_3);
            my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'nc', '-v', '-w', '120', '-l', '-p');
            close $in_3 or croak 'Close failed: $OS_ERROR';
            $output_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
            close $out_3 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_3, 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_2 = 0; }
            $output_2 = do {
                            my $_wc_data = $output_2;
                            my $_wc_bytes = length($_wc_data);
                            my $_wc_result = q{};
                            $_wc_result .= sprintf q{%d}, $_wc_bytes;
                            $_wc_result .= "\n";
                            $_wc_result;
                        };
            my @lines = split /\n/msx, $output_2;
            my @result;
            foreach my $line (@lines) {
                chomp $line;
                if ($line =~ /^\s*$/msx) { next; }
                my @fields = split /\s+/msx, $line;
                push @result, ($fields[0] . "\n");
            }
            $output_2 = join "", @result;

            if ( !$pipeline_success_2 ) { $main_exit_code = 1; }
            $output_2 =~ s/\n+\z//msx;
            $output_2;
}; $_pipeline_result; };
        do {
    my $__echo_line = $AMOUNT . q{ } . 'byte' . q{ } . 'of' . q{ } . 'data' . q{ } . 'received';
    print $__echo_line;
    if (!($__echo_line =~ /\n$/msx)) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
        $CHILD_ERROR = 0;
        print "\n";
        $CHILD_ERROR = 0;
require Time::HiRes; Time::HiRes::sleep(q{1});
    }
}
print "sending data...\n";
$AMOUNT = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_5 = q{};
    my $output_printed_5;
    my $pipeline_success_5 = 1;
    $output_5 .= $2 . "\n";
    if ( !($output_5 =~ m{\n\z}msx) ) { $output_5 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_5 = 0; }
    my @sed_lines_5 = split /\n/msx, $output_5;
    my @sed_result_5;
    foreach my $line (@sed_lines_5) {
    chomp $line;
    $line =~ s//[mM]/gmsx;
    push @sed_result_5, $line;
    }
    $output_5 = join "\n", @sed_result_5;

    my @sed_lines_5 = split /\n/msx, $output_5;
    my @sed_result_5;
    foreach my $line (@sed_lines_5) {
    chomp $line;
    $line =~ s//[kK]/gmsx;
    push @sed_result_5, $line;
    }
    $output_5 = join "\n", @sed_result_5;


    my $cmd_7 = 'bc';
    my ($in_6, $out_6);
    my $pid_6 = open3($in_6, $out_6, '>&STDERR', $cmd_7, );
    print {$in_6} $output_5;
    close $in_6 or croak 'Close failed: $OS_ERROR';
    $output_5 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_6> };
    close $out_6 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_6, 0;
    if ( !$pipeline_success_5 ) { $main_exit_code = 1; }
    $output_5 =~ s/\n+\z//msx;
    $output_5;
}; $_pipeline_result; };
my $TEMP;
my @TEMP;
my %TEMP;
$TEMP = '/tmp/';
$CHILD_ERROR = 0;
do {
local *STDERR;
open STDERR, '>', "$TEMP" or croak "Cannot open file: $OS_ERROR\n";
    do {
        local %ENV = %ENV;
        my $me = $me;
        my $WAIT = $WAIT;
        my $AMOUNT = $AMOUNT;
        my $NCPORT = $NCPORT;
        my $TEMP = $TEMP;
        # Original bash: time -p dd if=/dev/zero bs=$AMOUNT count=1 2>/dev/null | nc -v -w $WAIT $1 $NCPORT )
{
            my $output_8 = q{};
            my $output_printed_8;
            my $pipeline_success_8 = 1;
                        $output = q{};
                        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot open file: $OS_ERROR\n";
my $tmp_redirect_9 = q{};
use Time::HiRes qw(gettimeofday tv_interval);
my $start_time = [gettimeofday];
system '-p' 'dd' 'if' q{=} '/dev/zero' 'bs' q{=} $AMOUNT 'count' q{=} q{1};
my $end_time = [gettimeofday];
my $elapsed = tv_interval($start_time, $end_time);
printf "real\t%.3fs\n", $elapsed;
$tmp_redirect_9;
            };
            $output_8 = $output;

                        my $cmd_12 = 'nc';
            my ($in_11, $out_11);
            my $pid_11 = open3($in_11, $out_11, '>&STDERR', $cmd_12, '-v', '-w');
            print {$in_11} $output_8;
            close $in_11 or croak 'Close failed: $OS_ERROR';
            $output_8 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_11> };
            close $out_11 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_11, 0;
            if ($output_8 ne q{} && !defined $output_printed_8) {
                print $output_8;
                if (!($output_8 =~ m{\n\z}msx)) {
                    print "\n";
                }
            }
            if ( !$pipeline_success_8 ) { $main_exit_code = 1; }
            }
        q{};
    };
};
if ($CHILD_ERROR != 0) {
    print do { my $cat_chunk = q{}; if ( open my $fh, '<', "$TEMP" ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . "$TEMP" . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
}
my $REAL;
my @REAL;
my %REAL;
$REAL = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    do { my $output_14 = q{};
my $output_printed_14;
my $output_15 = q{};
while (my $line = <>) {
    chomp $line;
        if (!($line =~ /^real/msx)) {
        next;
    }
    # awk doesn't support line-by-line processing
}
$output_15; };
}; $_pipeline_result; };
if ( -e "$TEMP" ) {
    if ( -d "$TEMP" ) {
        croak "rm: ", "$TEMP",
          " is a directory (use -r to remove recursively)\n";
    }
    else {
        if ( unlink "$TEMP" ) {
                    }
        else {
            croak "rm: cannot remove ", "$TEMP",
              ": $OS_ERROR\n";
        }
    }
}
else {
    local $CHILD_ERROR = 1;
    croak "rm: ", "$TEMP", ": No such file or directory\n";
}
my $DOUBLEWAIT;
my @DOUBLEWAIT;
my %DOUBLEWAIT;
$DOUBLEWAIT = eval { int($WAIT * 2) } // "";
my $NEEDED;
my @NEEDED;
my %NEEDED;
$NEEDED = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_16 = q{};
    my $output_printed_16;
    my $pipeline_success_16 = 1;
    $output_16 .= $REAL . q{ } . q{-} . q{ } . $DOUBLEWAIT . "\n";
    if ( !($output_16 =~ m{\n\z}msx) ) { $output_16 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_16 = 0; }

    my $cmd_18 = 'bc';
    my ($in_17, $out_17);
    my $pid_17 = open3($in_17, $out_17, '>&STDERR', $cmd_18, );
    print {$in_17} $output_16;
    close $in_17 or croak 'Close failed: $OS_ERROR';
    $output_16 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_17> };
    close $out_17 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_17, 0;
    if ( !$pipeline_success_16 ) { $main_exit_code = 1; }
    $output_16 =~ s/\n+\z//msx;
    $output_16;
}; $_pipeline_result; };
my $BPS;
my @BPS;
my %BPS;
$BPS = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_19 = q{};
    my $output_printed_19;
    my $pipeline_success_19 = 1;
    $output_19 .= "scale=3;$AMOUNT / $NEEDED\n";
    if ( !($output_19 =~ m{\n\z}msx) ) { $output_19 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_19 = 0; }

    my $cmd_21 = 'bc';
    my ($in_20, $out_20);
    my $pid_20 = open3($in_20, $out_20, '>&STDERR', $cmd_21, );
    print {$in_20} $output_19;
    close $in_20 or croak 'Close failed: $OS_ERROR';
    $output_19 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_20> };
    close $out_20 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_20, 0;
    if ( !$pipeline_success_19 ) { $main_exit_code = 1; }
    $output_19 =~ s/\n+\z//msx;
    $output_19;
}; $_pipeline_result; };
my $KBPS;
my @KBPS;
my %KBPS;
$KBPS = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_22 = q{};
    my $output_printed_22;
    my $pipeline_success_22 = 1;
    $output_22 .= "scale=3;$AMOUNT / $NEEDED / 1024\n";
    if ( !($output_22 =~ m{\n\z}msx) ) { $output_22 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_22 = 0; }

    my $cmd_24 = 'bc';
    my ($in_23, $out_23);
    my $pid_23 = open3($in_23, $out_23, '>&STDERR', $cmd_24, );
    print {$in_23} $output_22;
    close $in_23 or croak 'Close failed: $OS_ERROR';
    $output_22 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_23> };
    close $out_23 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_23, 0;
    if ( !$pipeline_success_22 ) { $main_exit_code = 1; }
    $output_22 =~ s/\n+\z//msx;
    $output_22;
}; $_pipeline_result; };
my $MBPS;
my @MBPS;
my %MBPS;
$MBPS = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $output_25 = q{};
    my $output_printed_25;
    my $pipeline_success_25 = 1;
    $output_25 .= "scale=3;$AMOUNT / $NEEDED / 1048576\n";
    if ( !($output_25 =~ m{\n\z}msx) ) { $output_25 .= "\n"; }
    $CHILD_ERROR = 0;
    if ($CHILD_ERROR != 0) { $pipeline_success_25 = 0; }

    my $cmd_27 = 'bc';
    my ($in_26, $out_26);
    my $pid_26 = open3($in_26, $out_26, '>&STDERR', $cmd_27, );
    print {$in_26} $output_25;
    close $in_26 or croak 'Close failed: $OS_ERROR';
    $output_25 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_26> };
    close $out_26 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_26, 0;
    if ( !$pipeline_success_25 ) { $main_exit_code = 1; }
    $output_25 =~ s/\n+\z//msx;
    $output_25;
}; $_pipeline_result; };
do {
    my $__echo_line = "time needed:      " . ${NEEDED} . "s";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
do {
    my $__echo_line = "byte per second:  $BPS";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
do {
    my $__echo_line = "KByte per second: $KBPS";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;
do {
    my $__echo_line = "MByte per second: $MBPS";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
$CHILD_ERROR = 0;

exit $main_exit_code;
