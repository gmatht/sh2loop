#!/usr/bin/env perl
use strict;
use warnings;
use feature 'say';
use IPC::Open3;

our $CHILD_ERROR;

my $FB;

my $OPTION = 'FRAMEBUFFER';
my $PREREQ = "udev";

sub prereqs {
    say $PREREQ;
    return;
}
if ($arg1 =~ /^prereqs$/msx) {
        prereqs();
    exit 0;
}

sub parse_video_opts {
    my ($file) = @_;
    my $OPTS = "$_[0]";
    my $IFS = ",";
if ("${OPTS}" eq "${OPTS%%:*}") {
return;
    }
    $OPTS = (${OPTS} =~ s/^.*?://r =~ s/^.*?://r);
    my $opt;
    for my $opt ($OPTS) {
if ("${opt}" ne "${opt#*=}") {
            print "$opt ";
}
        else {
            if ("${opt}" ne "${opt#*:}") {
                print (scalar reverse( (scalar reverse ${opt}) =~ s/^.*?://r ) =~ s/:.*?$//r) . "=" . (${opt} =~ s/^.*?://r =~ s/^.*?://r) . " ";
}
            else {
                if ("${opt}" ne "${opt#[0-9]*x[0-9]}") {
                    print "mode=$opt ";
}
                else {
                    print ${opt} . "=1 ";
                }
            }
        }
    }
;
    return;
}
$FB = "";
my $OPTS = "";
my $x;
for my $x (do { my $cat_chunk = q{}; if ( open my $fh, '<', '/proc/cmdline' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/proc/cmdline' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }) {
if ($x =~ /^vga=.*$/msx) {
                $FB = "vesafb";
                $OPTS = "";
    } elsif ($x =~ /^video=.*$/msx) {
                $FB = ${x} =~ s/^.*?=//r;
                $FB = (${FB} =~ s/:.*$//sr =~ s/:.*$//sr);
                $OPTS = (do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'parse_video_opts', ${x});
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
});
    }
}
if ($FB =~ /^matroxfb$/msx) {
        $FB = 'matroxfb_base';
}
if ("${FB}" ne q{}) {
    $main_exit_code = system('udevadm', 'settle') >> 8;
    my $MODPROBE_OPTIONS = '-q';
    $main_exit_code = system('modprobe', $FB, $OPTS) >> 8;
    $main_exit_code = system('udevadm', 'settle') >> 8;
}
else {
if (        if (!((-d '/sys/class/graphics/fbcon'))) {
        !((-d '/sys/class/graphics/fb0'))
    }
    if ($CHILD_ERROR != 0) {
        !((-d '/sys/class/drm/card0'))
    }) {
        $main_exit_code = system('udevadm', 'settle') >> 8;
    }
if (        if (!((-d '/sys/class/graphics/fbcon'))) {
        !((-d '/sys/class/graphics/fb0'))
    }
    if ($CHILD_ERROR != 0) {
        !((-d '/sys/class/drm/card0'))
    }) {
require Time::HiRes; Time::HiRes::sleep(q{1});
    }
if (        if (!((-d '/sys/class/graphics/fbcon'))) {
        !((-d '/sys/class/graphics/fb0'))
    }
    if ($CHILD_ERROR != 0) {
        !((-d '/sys/class/drm/card0'))
    }) {
        do {
local *STDERR;
open STDERR, '>', '/dev/null' or croak "Cannot access file: $OS_ERROR\n";
            $main_exit_code = system('modprobe', '-q', 'vesafb') >> 8;
        };
        $main_exit_code = system('udevadm', 'settle') >> 8;
    }
}
my $MODE;
for my $x (do { my $cat_chunk = q{}; if ( open my $fh, '<', '/proc/cmdline' ) { local $INPUT_RECORD_SEPARATOR = undef; $cat_chunk = <$fh>; close $fh; } else { carp 'cat: ' . '/proc/cmdline' . ': ' . $OS_ERROR . "\n"; } $cat_chunk; }) {
if ($x =~ /^fbmode=.*$/msx) {
                $MODE = ${x} =~ s/^.*?=//r;
                do {
            open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
            open STDOUT, '>', '/sys/class/graphics/fb0/mode'
      or die "Cannot access file: $OS_ERROR\n";
            my $tmp = do {
            say $MODE;
            };
            print $tmp;
            open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
            close $original_stdout
      or die "Close failed: $OS_ERROR\n";
        };
    }
}
