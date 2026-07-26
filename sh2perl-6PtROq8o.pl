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

$__set_e = 1;
$ENV{DEB_MAINT_PARAMS} = '';
$ENV{INITRD} = 'Yes';
if (do {
$main_exit_code = system('test', '-d', '/etc/kernel/preinst.d') >> 8;
    $CHILD_ERROR == 0
}) {
        $main_exit_code = system('run-parts', '--arg=6.1.31-sun50iw9', '--arg=/boot/vmlinuz-6.1.31-sun50iw9', '/etc/kernel/preinst.d') >> 8;
}
if ("$(stat -c %d:%i /)" ne "$(stat -c %d:%i /proc/1/root/.)") {
exit 0;
}

sub check_boot_dev {
    my $boot_device;
    my @boot_device;
    my %boot_device;
    $boot_device = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'mountpoint', '-d', '/boot');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
    my $file;
    for my $file ('/dev/*') {
        my $CURRENT_DEVICE;
        my @CURRENT_DEVICE;
        my %CURRENT_DEVICE;
        $CURRENT_DEVICE = sprintf('%d:%d', do {
    my ($in_1, $out_1);
    my $pid_1 = open3($in_1, $out_1, '>&STDERR', 'stat', '--printf=0x%t 0x%T', $file);
    close $in_1 or croak 'Close failed: $OS_ERROR';
    my $result_1 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_1> };
    close $out_1 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_1, 0;
    $result_1
});
;
if ("$CURRENT_DEVICE" eq "$boot_device") {
            my $boot_partition;
            my @boot_partition;
            my %boot_partition;
            $boot_partition = $file;
last;
        }
    }
    my $bootfstype;
    my @bootfstype;
    my %bootfstype;
    $bootfstype = do {
    my ($in_2, $out_2);
    my $pid_2 = open3($in_2, $out_2, '>&STDERR', 'blkid', '-s', 'TYPE', '-o', 'value', $boot_partition);
    close $in_2 or croak 'Close failed: $OS_ERROR';
    my $result_2 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_2> };
    close $out_2 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_2, 0;
    $result_2
};
if ("$bootfstype" eq "vfat") {
my @files_to_remove = glob("/boot/System.map*");
foreach my $file_to_remove (@files_to_remove) {
            if ( -e $file_to_remove ) {
                if ( -d $file_to_remove ) {
                    carp "rm: carping: ", $file_to_remove,
    " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink $file_to_remove ) {
                    }
                    else {
                        local $CHILD_ERROR = 1;
                        carp "rm: carping: could not remove ", $file_to_remove,
    ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
        }
my @files_to_remove = glob("/boot/config*");
foreach my $file_to_remove (@files_to_remove) {
            if ( -e $file_to_remove ) {
                if ( -d $file_to_remove ) {
                    carp "rm: carping: ", $file_to_remove,
    " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink $file_to_remove ) {
                    }
                    else {
                        local $CHILD_ERROR = 1;
                        carp "rm: carping: could not remove ", $file_to_remove,
    ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
        }
my @files_to_remove = glob("/boot/vmlinuz*");
foreach my $file_to_remove (@files_to_remove) {
            if ( -e $file_to_remove ) {
                if ( -d $file_to_remove ) {
                    carp "rm: carping: ", $file_to_remove,
    " is a directory (use -r to remove recursively)\n";
                }
                else {
                    if ( unlink $file_to_remove ) {
                    }
                    else {
                        local $CHILD_ERROR = 1;
                        carp "rm: carping: could not remove ", $file_to_remove,
    ": $OS_ERROR\n";
                    }
                }
            }
            else {
                local $CHILD_ERROR = 0;
            }
        }
if ( -e "/boot/Image" ) {
            if ( -d "/boot/Image" ) {
                carp "rm: carping: ", "/boot/Image",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "/boot/Image" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "/boot/Image",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
if ( -e "/boot/uImage" ) {
            if ( -d "/boot/uImage" ) {
                carp "rm: carping: ", "/boot/uImage",
          " is a directory (use -r to remove recursively)\n";
            }
            else {
                if ( unlink "/boot/uImage" ) {
                                    }
                else {
                    carp "rm: carping: could not remove ", "/boot/uImage",
              ": $OS_ERROR\n";
                }
            }
        }
        else {
            local $CHILD_ERROR = 0;
        }
    }
    return;
}
if (do {
$main_exit_code = system('mountpoint', '-q', '/boot') >> 8;
    $CHILD_ERROR == 0
}) {
        check_boot_dev();
}
exit 0;

exit $main_exit_code;
