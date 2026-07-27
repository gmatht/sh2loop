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

if ((-d "/cryptroot/gnupghome")) {
$ENV{GNUPGHOME} = '';
}

sub run_gpg {
    $main_exit_code = system('gpg', '--no-options', '--trust-model=always', "@ARGV") >> 8;
    return;
}

sub decrypt_gpg {
    my $console;
    my $_;
if (!(!(my $GPG_TTY;
    my @GPG_TTY;
    my %GPG_TTY;
    $GPG_TTY = (do { my $_chomp_temp = do {
    my ($in_0, $out_0);
    my $pid_0 = open3($in_0, $out_0, '>&STDERR', 'tty');
    close $in_0 or croak 'Close failed: $OS_ERROR';
    my $result_0 = do { local $INPUT_RECORD_SEPARATOR = undef; <$out_0> };
    close $out_0 or croak 'Close failed: $OS_ERROR';
    waitpid $pid_0, 0;
    $result_0
}; chomp $_chomp_temp; $_chomp_temp; });))) {
open STDIN, '<', '/proc/consoles' or croak "Cannot open file: $OS_ERROR\n";
$console = <>;
chomp $console;
$CHILD_ERROR = defined($console) ? 0 : 1;
        $GPG_TTY = "/dev/$console";
    }
$ENV{GPG_TTY} = $GPG_TTY;
if (!(!(run_gpg('--decrypt', '--', "$_[0]");))) {
return q{1};
    }
return q{0};
    return;
}
if (!(!(do {
    open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
    open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
    my $tmp = do {
    run_gpg('--batch', '--quiet', '--no-tty', '--card-status');
    };
    print $tmp;
    open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
    close $original_stdout
      or die "Close failed: $OS_ERROR\n";
};))) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        print "Please insert OpenPGP SmartCard...\n";
    };
    do {
        open my $original_stdout, '>&', STDOUT
      or die "Cannot save STDOUT: $OS_ERROR\n";
        open STDOUT, '>', '/dev/null'
      or die "Cannot open file: $OS_ERROR\n";
local *STDERR;
open STDERR, '>&', STDOUT or die "Cannot dup stderr: $OS_ERROR\n";
until (         run_gpg('--batch', '--quiet', '--no-tty', '--card-status') ) {
require Time::HiRes; Time::HiRes::sleep(q{1});
        }
        open STDOUT, '>&', $original_stdout
      or die "Cannot restore STDOUT: $OS_ERROR\n";
        close $original_stdout
      or die "Close failed: $OS_ERROR\n";
    };
}
if ((!-x /usr/bin/gpg)) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "$PROGRAM_NAME: /usr/bin/gpg is not available";
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
if (("$1" eq q{} || (!-f "$1"))) {
    do {
local *STDERR;
open STDERR, '>&', STDERR or die "Cannot dup stderr: $OS_ERROR\n";
        do {
    my $__echo_line = "$PROGRAM_NAME: missing key as argument";
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
decrypt_gpg("$_[0]");


exit $main_exit_code;
