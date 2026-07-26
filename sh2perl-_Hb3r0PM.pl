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

my $MAGIC_70  = 70;
my $MAGIC_9   = 9;
my $MAGIC_644 = 644;
my $MAGIC_5   = 5;

$main_exit_code = system('.', '/etc/orangepi-release') >> 8;
$main_exit_code = system('.', '/lib/init/vars.sh') >> 8;
$main_exit_code = system('.', '/lib/lsb/init-functions') >> 8;
$main_exit_code = system('.', '/usr/lib/orangepi/orangepi-common') >> 8;

sub do_expand_partition {
if (((-f '/usr/share/initramfs-tools/hooks/growroot') || (-f '/usr/share/initramfs-tools/scripts/local-bottom/growroot'))) {
        print "partition resize skipped: growroot detected.\n";
return q{0};
    }
    my $rootsource = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_0 = q{};
        my $output_printed_0;
        my $pipeline_success_0 = 1;

        my ($in_1, $out_1);
        my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'findmnt', '-n', '-o', 'SOURCE', q{/});
        close $in_1 or croak 'Close failed: $OS_ERROR';
        $output_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
        close $out_1 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_1, 0;
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
    my $roottype = do {
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'lsblk', '-n', '-o', 'TYPE', $rootsource);
    close $in_2 or croak 'Close failed: $OS_ERROR';
    my $result_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    $result_2
};
if ($roottype =~ /^crypt$/msx) {
                my $IS_CRYPTDEVICE;
        my @IS_CRYPTDEVICE;
        my %IS_CRYPTDEVICE;
        $IS_CRYPTDEVICE = 'true';
                my $cryptname = do {
    my ($in_3, $out_3);
    my $pid_3 = open3($in_3, $out_3, '>&STDERR', 'lsblk', '-n', '-o', 'NAME', $rootsource);
    close $in_3 or croak 'Close failed: $OS_ERROR';
    my $result_3 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_3> };
    close $out_3 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_3, 0;
    $result_3
};
                my $parent_uuid = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_4 = q{};
            my $output_printed_4;
            my $pipeline_success_4 = 1;
            $output_4 = do { my $cat_chunk = q{}; if ( open my $fh, '<', '/etc/crypttab' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/etc/crypttab' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
            if ($CHILD_ERROR != 0) { $pipeline_success_4 = 0; }
            my @lines = split /\n/msx, $output_4;
            my @result;
            foreach my $line (@lines) {
                chomp $line;
                if ($line =~ /^\s*$/msx) { next; }
                my @fields = split /\s+/msx, $line;
                if (!("))) { next; }
                push @result, ($fields[1]} . "\n");
            }
            $output_4 = join "", @result;

            my @sed_lines_4 = split /\n/msx, $output_4;
            my @sed_result_4;
            foreach my $line (@sed_lines_4) {
            chomp $line;
            $line =~ s/UUID=//gmsx;
            push @sed_result_4, $line;
            }
            $output_4 = join "\n", @sed_result_4;

            if ( !$pipeline_success_4 ) { $main_exit_code = 1; }
            $output_4 =~ s/\n+\z//msx;
            $output_4;
}; $_pipeline_result; };
                my $rootpart = do {
    my ($in_5, $out_5);
    my $pid_5 = open3($in_5, $out_5, '>&STDERR', 'blkid', '-U', $parent_uuid);
    close $in_5 or croak 'Close failed: $OS_ERROR';
    my $result_5 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_5> };
    close $out_5 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_5, 0;
    $result_5
};
    } elsif ($roottype =~ /^part$/msx) {
                my $rootpart = $rootsource;
    }
    my $rootdevice = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_6 = q{};
        my $output_printed_6;
        my $pipeline_success_6 = 1;

        my ($in_7, $out_7);
        my $pid_7 = open3($in_7, $out_7, '>&STDERR', 'lsblk', '-n', '-o', 'PKNAME');
        close $in_7 or croak 'Close failed: $OS_ERROR';
        $output_6 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_7> };
        close $out_7 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_7, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_6 = 0; }
        my $num_lines       = 1;
        my $head_line_count = 0;
        my $result          = q{};
        my $input           = $output_6;
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
        $output_6 = $result;

        if ( !$pipeline_success_6 ) { $main_exit_code = 1; }
        $output_6 =~ s/\n+\z//msx;
        $output_6;
}; $_pipeline_result; };
    if ($rootdevice eq q{}) {
                $rootdevice = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_8 = q{};
            my $output_printed_8;
            my $pipeline_success_8 = 1;
            $output_8 .= $rootpart . "\n";
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
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    my $rootdevicepath = "/dev/$rootdevice";
    my $partitions = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_9 = q{};
        my $output_printed_9;
        my $pipeline_success_9 = 1;

        my ($in_10, $out_10);
        my $pid_10 = open3($in_10, $out_10, '>&STDERR', 'parted', 'print', '-s', q{m});
        close $in_10 or croak 'Close failed: $OS_ERROR';
        $output_9 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_10> };
        close $out_10 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_10, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_9 = 0; }
        my @lines = split /\n/msx, $output_9;
        my $num_lines = 1;
        if ($num_lines > scalar @lines) {
        $num_lines = scalar @lines;
        }
        my $start_index = scalar @lines - $num_lines;
        if ($start_index < 0) { $start_index = 0; }
        my @result = @lines[$start_index..$#lines];
        $output_9 = join "\n", @result;
        if ($output_9 ne q{} && !($output_9  =~ m{\n\z}msx)) { $output_9 .= "\n"; }

        my @lines = split /\n/msx, $output_9;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /:/msx, $line;
            push @result, ($fields[0] . "\n");
        }
        $output_9 = join "", @result;

        if ( !$pipeline_success_9 ) { $main_exit_code = 1; }
        $output_9 =~ s/\n+\z//msx;
        $output_9;
}; $_pipeline_result; };
    my $partstart = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_11 = q{};
        my $output_printed_11;
        my $pipeline_success_11 = 1;

        my ($in_12, $out_12);
        my $pid_12 = open3($in_12, $out_12, '>&STDERR', 'parted', 'unit', q{s}, 'print', '-s', q{m});
        close $in_12 or croak 'Close failed: $OS_ERROR';
        $output_11 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_12> };
        close $out_12 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_12, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_11 = 0; }
        my @lines = split /\n/msx, $output_11;
        my $num_lines = 1;
        if ($num_lines > scalar @lines) {
        $num_lines = scalar @lines;
        }
        my $start_index = scalar @lines - $num_lines;
        if ($start_index < 0) { $start_index = 0; }
        my @result = @lines[$start_index..$#lines];
        $output_11 = join "\n", @result;
        if ($output_11 ne q{} && !($output_11  =~ m{\n\z}msx)) { $output_11 .= "\n"; }

        my @lines_13 = split /\n/msx, $output_11;
        my @result_13;
        foreach my $line (@lines_13) {
        chomp $line;
        my @fields = split /:/msx, $line;
        if (@fields > 1) {
            push @result_13, $fields[1];
        }
        }
        $output_11 = join "\n", @result_13;
        if ($output_11 ne q{} && !($output_11  =~ m{\n\z}msx)) { $output_11 .= "\n"; }

        my @sed_lines_11 = split /\n/msx, $output_11;
        my @sed_result_11;
        foreach my $line (@sed_lines_11) {
        chomp $line;
        $line =~ s/s//gmsx;
        push @sed_result_11, $line;
        }
        $output_11 = join "\n", @sed_result_11;

        if ( !$pipeline_success_11 ) { $main_exit_code = 1; }
        $output_11 =~ s/\n+\z//msx;
        $output_11;
}; $_pipeline_result; };
    my $partend = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_14 = q{};
        my $output_printed_14;
        my $pipeline_success_14 = 1;

        my ($in_15, $out_15);
        my $pid_15 = open3($in_15, $out_15, '>&STDERR', 'parted', 'unit', q{s}, 'print', '-s', q{m});
        close $in_15 or croak 'Close failed: $OS_ERROR';
        $output_14 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_15> };
        close $out_15 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_15, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_14 = 0; }
        my $num_lines       = 3;
        my $head_line_count = 0;
        my $result          = q{};
        my $input           = $output_14;
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
        $output_14 = $result;

        my @lines = split /\n/msx, $output_14;
        my $num_lines = 1;
        if ($num_lines > scalar @lines) {
        $num_lines = scalar @lines;
        }
        my $start_index = scalar @lines - $num_lines;
        if ($start_index < 0) { $start_index = 0; }
        my @result = @lines[$start_index..$#lines];
        $output_14 = join "\n", @result;
        if ($output_14 ne q{} && !($output_14  =~ m{\n\z}msx)) { $output_14 .= "\n"; }

        my @lines_16 = split /\n/msx, $output_14;
        my @result_16;
        foreach my $line (@lines_16) {
        chomp $line;
        my @fields = split /:/msx, $line;
        if (@fields > 2) {
            push @result_16, $fields[2];
        }
        }
        $output_14 = join "\n", @result_16;
        if ($output_14 ne q{} && !($output_14  =~ m{\n\z}msx)) { $output_14 .= "\n"; }

        my @sed_lines_14 = split /\n/msx, $output_14;
        my @sed_result_14;
        foreach my $line (@sed_lines_14) {
        chomp $line;
        $line =~ s/s//gmsx;
        push @sed_result_14, $line;
        }
        $output_14 = join "\n", @sed_result_14;

        if ( !$pipeline_success_14 ) { $main_exit_code = 1; }
        $output_14 =~ s/\n+\z//msx;
        $output_14;
}; $_pipeline_result; };
    my $startfrom = eval { int( $partend + 1 ) } // "";
    if ($partitions =~ /^1$/msx) {
                $startfrom = $partstart;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    my $capacity = eval { int( do { chomp(my $_r = qx'lsblk -n -b -d -o SIZE $rootdevicepath'); $_r; } / 1024 / 1024 / 1024 ) } // "";
if ((-f '/root/.rootfs_resize')) {
open STDIN, '<', '/root/.rootfs_resize' or croak "Cannot open file: $OS_ERROR\n";
$RESIZE_VALUE = <>;
chomp $RESIZE_VALUE;
$CHILD_ERROR = defined($RESIZE_VALUE) ? 0 : 1;
        my $ResizeLog;
        my @ResizeLog;
        my %ResizeLog;
        $ResizeLog = "Resize rule $ENV{RESIZE_VALUE} defined for root partition";
if ($RESIZE_VALUE =~ /^.*%$/msx) {
                        my $percentage = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ($RESIZE_VALUE) . "\n";
    my $set1_19 = '-c';
my $input_19 = $input_data;
my $tr_result_18 = q{};
for my $char ( split //msx, $input_19 ) {
    if ( (index $set1_19, $char) == -1 ) {
        $tr_result_18 .= $char;
    }
}
$tr_result_18
}; $_pipeline_result; };
                        my $lastsector = eval { int( 32768 * do { chomp(my $_r = qx'parted $rootdevicepath unit s print -sm | grep "^$rootdevicepath" | awk -F":" "{printf (\"%0d\", ( \$2 * $percentage / 3276800))}"'); $_r; } - 1 ) } // "";
                        if (($lastsector < $partend)) {
                undef $lastsector;
delete $ENV{lastsector};
                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
        } elsif ($RESIZE_VALUE =~ /^.*s$/msx) {
                        my $lastsector = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
    my $input_data = ($RESIZE_VALUE) . "\n";
    my $set1_21 = '-c';
my $input_21 = $input_data;
my $tr_result_20 = q{};
for my $char ( split //msx, $input_21 ) {
    if ( (index $set1_21, $char) == -1 ) {
        $tr_result_20 .= $char;
    }
}
$tr_result_20
}; $_pipeline_result; };
                        if (($lastsector < $partend)) {
                undef $lastsector;
delete $ENV{lastsector};
                $CHILD_ERROR = 0;
            } else {
                $CHILD_ERROR = 1;
            }
        }
if (($capacity >= $MAGIC_5)) {
            my $secondpartition = eval { int( 32768 * do { chomp(my $_r = qx'parted $rootdevicepath unit s print -sm | grep "^$rootdevicepath" | awk -F":" "{printf (\"%0d\", ( \$2 * 99 / 3276800))}"'); $_r; } -1 ) } // "";
if (($secondpartition < $partend)) {
undef $secondpartition;
delete $ENV{secondpartition};
            }
        }
}
    else {
if (($capacity < $MAGIC_5)) {
            my $lastsector = eval { int( 32768 * do { chomp(my $_r = qx'parted $rootdevicepath unit s print -sm | grep "^$rootdevicepath" | awk -F":" "{printf (\"%0d\", ( \$2 * 95 / 3276800))}"'); $_r; } -1 ) } // "";
if (($lastsector < $partend)) {
undef $lastsector;
delete $ENV{lastsector};
}
            else {
                $ResizeLog = "4GiB or smaller media - leaving 5% spare area";
            }
}
        else {
            if (($capacity < $MAGIC_9)) {
                my $lastsector = eval { int( 32768 * do { chomp(my $_r = qx'parted $rootdevicepath unit s print -sm | grep "^$rootdevicepath" | awk -F":" "{printf (\"%0d\", ( \$2 * 98 / 3276800))}"'); $_r; } -1 ) } // "";
if (($lastsector < $partend)) {
undef $lastsector;
delete $ENV{lastsector};
}
                else {
                    $ResizeLog = "8GiB or smaller media - leaving 2% spare area";
                }
}
            else {
                my $lastsector = eval { int( 32768 * do { chomp(my $_r = qx'parted $rootdevicepath unit s print -sm | grep "^$rootdevicepath" | awk -F":" "{printf (\"%0d\", ( \$2 * 99 / 3276800))}"'); $_r; } -1 ) } // "";
if (($lastsector < $partend)) {
undef $lastsector;
delete $ENV{lastsector};
}
                else {
                    $ResizeLog = "Leaving 1% spare area";
                }
            }
        }
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $Log
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "\n### [resize2fs] ${ResizeLog}. Start resizing partition $rootsource now:\n";
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
        open STDOUT, '>>', $Log
      or die "Cannot open file: $OS_ERROR\n";
print do { my $cat_chunk = q{}; if ( open my $fh, '<', '/proc/partitions' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/proc/partitions' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $Log
      or die "Cannot open file: $OS_ERROR\n";
        print "\nExecuting fdisk, fsck and partprobe:" . "\n";
        $CHILD_ERROR = 0;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    my $fdisk_version = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_23 = q{};
        my $output_printed_23;
        my $pipeline_success_23 = 1;

        my ($in_24, $out_24);
        my $pid_24 = open3($in_24, $out_24, '>&STDERR', 'fdisk', '--version');
        close $in_24 or croak 'Close failed: $OS_ERROR';
        $output_23 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_24> };
        close $out_24 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_24, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_23 = 0; }
        my @lines = split /\n/msx, $output_23;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\s+/msx, $line;
            push @result, ($scalar(@fields) . "\n");
        }
        $output_23 = join "", @result;

        my $grep_result_23_2;
        my @grep_lines_23_2 = split /\n/msx, $output_23;
        my @grep_filtered_23_2 = grep { /^[[:digit:]][.][[:digit:]]+/msx } @grep_lines_23_2;
        my @grep_matches_23_2;
        foreach my $line (@grep_filtered_23_2) {
            if ($line =~ /(^[[:digit:]][.][[:digit:]]+)/msx) {
                push @grep_matches_23_2, $1;
            }
        }
        $grep_result_23_2 = join "\n", @grep_matches_23_2;
        $CHILD_ERROR = scalar @grep_filtered_23_2 > 0 ? 0 : 1;
        $output_23 = $grep_result_23_2;
        if ((scalar @grep_filtered_23_2) == 0) {
            $pipeline_success_23 = 0;
        }
        if ( !$pipeline_success_23 ) { $main_exit_code = 1; }
        $output_23 =~ s/\n+\z//msx;
        $output_23;
}; $_pipeline_result; };
if (($partitions =~ /^1$/msx && !(my @lines = split /\n/msx, $;
my @result;
foreach my $line (@lines) {
    chomp $line;
    if ($line =~ /^\s*$/msx) { next; }
    my @fields = split /\s+/msx, $line;
    push @result, ($line . "\n");
}
$ = join "", @result))) {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $Log
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = ($main_exit_code = eval { int($ENV{echo} $ENV{d}; $ENV{echo} $ENV{n}; $ENV{echo} $ENV{p}; $ENV{echo} ; $ENV{echo} $startfrom; $ENV{echo} $lastsector ; $ENV{echo} $ENV{w};) | $ENV{fdisk} $rootdevicepath)) } // "") ? 0 : 1;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
}
    else {
        do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $Log
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = ($main_exit_code = eval { int($ENV{echo} $ENV{d}; $ENV{echo} $partitions; $ENV{echo} $ENV{n}; $ENV{echo} $ENV{p}; $ENV{echo} ; $ENV{echo} $startfrom; $ENV{echo} $lastsector ; $ENV{echo} $ENV{w};) | $ENV{fdisk} $rootdevicepath)) } // "") ? 0 : 1;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
    if ($secondpartition ne q{}) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $Log
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $CHILD_ERROR = ($main_exit_code = eval { int($ENV{echo} $ENV{n}; $ENV{echo} $ENV{p}; $ENV{echo} ; $ENV{echo} do { chomp(my $_r = qx'( $lastsector + 1 )'); $_r; }; $ENV{echo} $secondpartition ; $ENV{echo} $ENV{w};) | $ENV{fdisk} $rootdevicepath)) } // "") ? 0 : 1;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    my $s = "0";
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $Log
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('partprobe', $rootdevicepath) >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    if ($CHILD_ERROR != 0) {
                $s = $?;
    }
    my $KERNELID;
    my @KERNELID;
    my %KERNELID;
    $KERNELID = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_26 = q{};
        my $output_printed_26;
        my $pipeline_success_26 = 1;
        do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__rel; $output_26 = join(" ", @__parts) . "\n"; $CHILD_ERROR = 0; };
        if ($CHILD_ERROR != 0) { $pipeline_success_26 = 0; }
        my @lines = split /\n/msx, $output_26;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /./msx, $line;
            push @result, (($fields[0] * 100) + $fields[1] . "\n");
        }
        $output_26 = join "", @result;

        if ( !$pipeline_success_26 ) { $main_exit_code = 1; }
        $output_26 =~ s/\n+\z//msx;
        $output_26;
}; $_pipeline_result; };
    if ((${KERNELID} > $MAGIC_507)) {
                $s = q{0};
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $Log
      or die "Cannot open file: $OS_ERROR\n";
        print "New partition table:\n" . "\n";
        $CHILD_ERROR = 0;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $Log
      or die "Cannot open file: $OS_ERROR\n";
print do { my $cat_chunk = q{}; if ( open my $fh, '<', '/proc/partitions' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/proc/partitions' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; };
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $Log
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "\nNow trying to resize $1 filesystem on $rootsource to the limits:\n";
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
if (($IS_CRYPTDEVICE ne q{})) {
        $main_exit_code = system('do_resize_crypt', $cryptname) >> 8;
    }
if ($arg1 =~ /^ext4$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $Log
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('resize2fs', $rootsource) >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
                my $usedpercent = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
            my $output_28 = q{};
            my $output_printed_28;
            my $pipeline_success_28 = 1;

            my ($in_29, $out_29);
            my $pid_29 = open3($in_29, $out_29, '>&STDERR', 'findmnt', '--target', q{/}, '-n', '-o', 'USE%', '-b');
            close $in_29 or croak 'Close failed: $OS_ERROR';
            $output_28 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_29> };
            close $out_29 or croak 'Close failed: $OS_ERROR';
            waitpid $pid_29, 0;
            if ($CHILD_ERROR != 0) { $pipeline_success_28 = 0; }
            my @sed_lines_28 = split /\n/msx, $output_28;
            my @sed_result_28;
            foreach my $line (@sed_lines_28) {
            chomp $line;
            $line =~ s/[^0-9]*//gmsx;
            push @sed_result_28, $line;
            }
            $output_28 = join "\n", @sed_result_28;

            if ( !$pipeline_success_28 ) { $main_exit_code = 1; }
            $output_28 =~ s/\n+\z//msx;
            $output_28;
}; $_pipeline_result; };
        if (($s ne 0 || ($usedpercent > $MAGIC_70))) {
            if ( -e "/var/run/resize2fs-reboot" ) {
                my $current_time = time;
                utime $current_time, $current_time, "/var/run/resize2fs-reboot";
            }
            else {
                if ( open my $fh, '>', "/var/run/resize2fs-reboot" ) {
                    close $fh or croak "Close failed: $ERRNO";
                }
                else {
                    croak "touch: cannot create ", "/var/run/resize2fs-reboot",
                      ": $ERRNO\n";
                }
            }
            do {
                open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
                open STDOUT, '>>', $Log
      or die "Cannot open file: $OS_ERROR\n";
                print "\n### [resize2fs] Automated reboot needed to finish the resize procedure" . "\n";
                $CHILD_ERROR = 0;
                open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
                close $original_stdout
      or die "Close failed: $OS_ERROR\n";
            };
        }
    } elsif ($arg1 =~ /^btrfs$/msx) {
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>>', $Log
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
            my $tmp = do {
            $main_exit_code = system('btrfs', "file" . "sys" . "tem", 'resize', 'max', q{/}) >> 8;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
    return;
}

sub do_resize_crypt {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $Log
      or die "Cannot open file: $OS_ERROR\n";
        print "\n### [resize2fs] Start resizing LUKS container now\n" . "\n";
        $CHILD_ERROR = 0;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    $main_exit_code = system('cryptsetup', 'resize', $1) >> 8;
    return;
}

sub do_expand_ext4 {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $Log
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "\n### [resize2fs] Start resizing ext4 partition $1 now\n";
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
    my $__echo_line = "Running 'resize2fs " . ($ENV{rootpart} // q{}) . "' now...";
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
        open STDOUT, '>>', $Log
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('resize2fs', $rootpart) >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}

sub do_expand_btrfs {
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $Log
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = "\n### [resize2fs] Start resizing btrfs partition $1 now\n";
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
        open STDOUT, '>>', $Log
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
        my $tmp = do {
        $main_exit_code = system('btrfs', "file" . "sys" . "tem", 'resize', 'max', q{/}) >> 8;
        };
        print $tmp;
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
    return;
}
if ("$_[0]" =~ /^start$/msx) {
    if ((-f '/root/.no_rootfs_resize')) {
        $main_exit_code = system('systemctl', 'disable', "orangepi-resize-file" . "sys" . "tem") >> 8;
exit 0;
    }
        my $CPU_ARCH;
    my @CPU_ARCH;
    my %CPU_ARCH;
    $CPU_ARCH = do { local $CHILD_ERROR = 0; my $_pipeline_result = do {
        my $output_31 = q{};
        my $output_printed_31;
        my $pipeline_success_31 = 1;

        my ($in_32, $out_32);
        my $pid_32 = open3($in_32, $out_32, '>&STDERR', 'lscpu', );
        close $in_32 or croak 'Close failed: $OS_ERROR';
        $output_31 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_32> };
        close $out_32 or croak 'Close failed: $OS_ERROR';
        waitpid $pid_32, 0;
        if ($CHILD_ERROR != 0) { $pipeline_success_31 = 0; }
        my @lines = split /\n/msx, $output_31;
        my @result;
        foreach my $line (@lines) {
            chomp $line;
            if ($line =~ /^\s*$/msx) { next; }
            my @fields = split /\s+/msx, $line;
            if (!(/Architecture/)) { next; }
            push @result, ($fields[1] . "\n");
        }
        $output_31 = join "", @result;

        if ( !$pipeline_success_31 ) { $main_exit_code = 1; }
        $output_31 =~ s/\n+\z//msx;
        $output_31;
}; $_pipeline_result; };
        my $DISTRO_ARCH;
    my @DISTRO_ARCH;
    my %DISTRO_ARCH;
    $DISTRO_ARCH = do {
    my ($in_33, $out_33);
    my $pid_33 = open3($in_33, $out_33, '>&STDERR', 'dpkg', '--print-architecture');
    close $in_33 or croak 'Close failed: $OS_ERROR';
    my $result_33 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_33> };
    close $out_33 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_33, 0;
    $result_33
};
        my $KERNELID;
    my @KERNELID;
    my %KERNELID;
    $KERNELID = do { use POSIX qw(uname); my ($__sys, $__node, $__rel, $__ver, $__mach) = POSIX::uname(); my @__parts; push @__parts, $__rel; join(" ", @__parts) . "\n"; };
        do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>>', $Log
      or die "Cannot open file: $OS_ERROR\n";
        do {
    my $__echo_line = (do { my $_chomp_temp = do {
require POSIX; POSIX::strftime('%a %b %e %H:%M:%S %Z %Y', localtime(time())) . "\n"
}; chomp $_chomp_temp; $_chomp_temp; }) . " | " . ($ENV{BOARD_NAME} // q{}) . " | " . ($ENV{VERSION} // q{}) . " | " . ${DISTRO_ARCH} . " | " . ${CPU_ARCH} . " | " . ${KERNELID};
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
    chmod(oct('644'), ($Log)) or warn "chmod failed: $OS_ERROR\n";
$CHILD_ERROR = 0;
        my $rootfstype;
    my @rootfstype;
    my %rootfstype;
    $rootfstype = do {
    my ($in_35, $out_35);
    my $pid_35 = open3($in_35, $out_35, '>&STDERR', 'findmnt', '-n', '-o', 'FSTYPE', q{/});
    close $in_35 or croak 'Close failed: $OS_ERROR';
    my $result_35 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_35> };
    close $out_35 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_35, 0;
    $result_35
};
        my $rootpart;
    my @rootpart;
    my %rootpart;
    $rootpart = do {
    my ($in_36, $out_36);
    my $pid_36 = open3($in_36, $out_36, '>&STDERR', 'findmnt', '-n', '-o', 'SOURCE', q{/});
    close $in_36 or croak 'Close failed: $OS_ERROR';
    my $result_36 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_36> };
    close $out_36 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_36, 0;
    $result_36
};
    if ($rootfstype =~ /^ext4$/msx) {
                if ((!-f /var/lib/orangepi/resize_second_stage)) {
                        do_expand_partition($rootfstype);
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
                if ((!-f /var/run/resize2fs-reboot)) {
                        do_expand_ext4($rootpart);
            $CHILD_ERROR = 0;
        } else {
            $CHILD_ERROR = 1;
        }
    } elsif ($rootfstype =~ /^btrfs$/msx) {
                if (do {
do_expand_partition($rootfstype);
            $CHILD_ERROR == 0
        }) {
                        $main_exit_code = system('systemctl', 'disable', "orangepi-resize-file" . "sys" . "tem") >> 8;
        }
    }
        if ((!-f /var/run/resize2fs-reboot)) {
                $main_exit_code = system('systemctl', 'disable', "orangepi-resize-file" . "sys" . "tem") >> 8;
        $CHILD_ERROR = 0;
    } else {
        $CHILD_ERROR = 1;
    }
    exit 0;
} elsif (1) {
        do {
    my $__echo_line = "Usage: $PROGRAM_NAME start";
    print $__echo_line;
    if ( !( $__echo_line =~ m{\n\z}msx ) ) {
        print "\n";
        $__echo_line .= "\n";
    }
    $output .= $__echo_line;
};
    $CHILD_ERROR = 0;
    exit 0;
}

exit $main_exit_code;
