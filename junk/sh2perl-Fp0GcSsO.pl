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

my $HOME;
my @HOME;
my %HOME;
my $uid;
my @uid;
my %uid;

if ((!-e /proc/self/fd/0)) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "Won't set ascii mode: Can't determine console type;\n";
    };
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print " Please ensure that /proc is mounted.\n";
    };
exit 1;
}
my $TTY;
my @TTY;
my %TTY;
$TTY = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', '/usr/bin/tty');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
};
if ("$TTY" =~ /^/dev/console$/msx or "$TTY" =~ /^/dev/vc.*$/msx or "$TTY" =~ /^/dev/tty\[0-9\].*$/msx) {
} elsif (1) {
        do {
    my $__echo_line = "unicode_stop skipped on $TTY";
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
$main_exit_code = system('kbd_mode', '-a') >> 8;
if ((-t)) {
printf('033%%@');
}
$main_exit_code = system('stty', '-iutf8') >> 8;
$uid = (do { my $_chomp_temp = do { my @_qx_cmd = ("id -u 2> /dev/null"); chomp(my $result = qx{$_qx_cmd[0]}); $CHILD_ERROR = $? >> 8; $result; }; chomp $_chomp_temp; $_chomp_temp; });
if ($CHILD_ERROR != 0) {
        $main_exit_code = system('bash', ':') >> 8;
}
if ("$uid" eq 0) {
    if (!((!-r "$HOME/.kbd/.keymap_sv"))) {
                $main_exit_code = system('loadkeys', "$HOME/.kbd/.keymap_sv") >> 8;
    }
}

exit $main_exit_code;
